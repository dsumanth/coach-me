//
//  ChatStreamService.swift
//  CoachMe
//
//  Created by Dev Agent on 2/6/26.
//
//  Story 2.4: Updated to parse memory_moment flag from SSE events (AC #4)
//  Story 3.4: Updated to parse pattern_insight flag from SSE events
//  Story 4.1: Updated to parse crisis_detected flag from SSE events
//  Story 8.5: Updated to parse reflection_offered and reflection_accepted flags
//

import Foundation

/// Service for streaming chat responses via Server-Sent Events
/// Per architecture.md: Use URLSession AsyncBytes for SSE
/// Story 2.4: Parses memory_moment flag for context injection detection
@MainActor
final class ChatStreamService {
    // MARK: - Types

    /// Events received from the SSE stream
    /// Story 2.4: Token event includes hasMemoryMoment flag for context injection
    /// Story 3.4: Token event includes hasPatternInsight flag for pattern recognition
    /// Story 4.1: Token event includes hasCrisisFlag for crisis detection
    /// Story 8.5: Token event includes reflectionOffered flag; done event includes reflectionAccepted
    enum StreamEvent: Decodable, Equatable {
        /// Token with content, memory moment indicator, pattern insight indicator, crisis flag, and reflection flag
        /// Story 2.4: hasMemoryMoment indicates if accumulated content contains [MEMORY:...] tags
        /// Story 3.4: hasPatternInsight indicates if accumulated content contains [PATTERN:...] tags
        /// Story 4.1: hasCrisisFlag indicates if crisis indicators were detected in user message
        /// Story 8.5: reflectionOffered indicates if a coaching reflection was injected in this session
        case token(content: String, hasMemoryMoment: Bool, hasPatternInsight: Bool, hasCrisisFlag: Bool, reflectionOffered: Bool)

        /// Stream completed with message ID, usage stats, reflection acceptance, discovery completion, and discovery profile
        /// Story 8.5: reflectionAccepted indicates if user engaged with the offered reflection
        /// Story 11.3: discoveryComplete indicates that the discovery conversation is finished
        /// Story 11.5: discoveryProfile contains extracted context fields for personalized paywall
        case done(messageId: UUID, usage: TokenUsage, reflectionAccepted: Bool, discoveryComplete: Bool, discoveryProfile: DiscoveryProfileData?)

        /// Error occurred during streaming
        case error(message: String)

        /// Story 11.5: Discovery profile data from SSE response for paywall personalization
        struct DiscoveryProfileData: Decodable, Equatable {
            let coachingDomains: [String]?
            let ahaInsight: String?
            let keyThemes: [String]?

            enum CodingKeys: String, CodingKey {
                case coachingDomains = "coaching_domains"
                case ahaInsight = "aha_insight"
                case keyThemes = "key_themes"
            }
        }

        struct TokenUsage: Decodable, Equatable {
            let promptTokens: Int
            let completionTokens: Int
            let totalTokens: Int

            enum CodingKeys: String, CodingKey {
                case promptTokens = "prompt_tokens"
                case completionTokens = "completion_tokens"
                case totalTokens = "total_tokens"
            }
        }

        enum CodingKeys: String, CodingKey {
            case type
            case content
            case memoryMoment = "memory_moment"
            case patternInsight = "pattern_insight"
            case crisisDetected = "crisis_detected"  // Story 4.1
            case reflectionOffered = "reflection_offered"  // Story 8.5
            case reflectionAccepted = "reflection_accepted"  // Story 8.5
            case discoveryComplete = "discovery_complete"  // Story 11.3
            case discoveryProfile = "discovery_profile"  // Story 11.5
            case messageId = "message_id"
            case usage
            case message
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)

            switch type {
            case "token":
                let content = try container.decode(String.self, forKey: .content)
                // Story 2.4: Parse memory_moment flag (defaults to false if not present)
                let memoryMoment = try container.decodeIfPresent(Bool.self, forKey: .memoryMoment) ?? false
                // Story 3.4: Parse pattern_insight flag (defaults to false for backward compatibility)
                let patternInsight = try container.decodeIfPresent(Bool.self, forKey: .patternInsight) ?? false
                // Story 4.1: Parse crisis_detected flag (defaults to false for backward compatibility)
                let crisisDetected = try container.decodeIfPresent(Bool.self, forKey: .crisisDetected) ?? false
                // Story 8.5: Parse reflection_offered flag (defaults to false for backward compatibility)
                let reflectionOffered = try container.decodeIfPresent(Bool.self, forKey: .reflectionOffered) ?? false
                self = .token(content: content, hasMemoryMoment: memoryMoment, hasPatternInsight: patternInsight, hasCrisisFlag: crisisDetected, reflectionOffered: reflectionOffered)
            case "done":
                let messageId = try container.decode(UUID.self, forKey: .messageId)
                let usage = try container.decode(TokenUsage.self, forKey: .usage)
                // Story 8.5: Parse reflection_accepted flag (defaults to false for backward compatibility)
                let reflectionAccepted = try container.decodeIfPresent(Bool.self, forKey: .reflectionAccepted) ?? false
                // Story 11.3: Parse discovery_complete flag (defaults to false for backward compatibility)
                let discoveryComplete = try container.decodeIfPresent(Bool.self, forKey: .discoveryComplete) ?? false
                // Story 11.5: Parse discovery_profile (nil if not present or malformed)
                let discoveryProfile = try container.decodeIfPresent(DiscoveryProfileData.self, forKey: .discoveryProfile)
                self = .done(messageId: messageId, usage: usage, reflectionAccepted: reflectionAccepted, discoveryComplete: discoveryComplete, discoveryProfile: discoveryProfile)
            case "error":
                let message = try container.decode(String.self, forKey: .message)
                self = .error(message: message)
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .type,
                    in: container,
                    debugDescription: "Unknown event type: \(type)"
                )
            }
        }
    }

    /// Request body for chat stream
    struct ChatRequest: Encodable {
        let message: String
        let conversationId: UUID
        /// Story 11.3: When true, the coach speaks first (discovery mode opening message)
        let firstMessage: Bool

        enum CodingKeys: String, CodingKey {
            case message
            case conversationId = "conversation_id"
            case firstMessage = "first_message"
        }
    }

    // MARK: - Private Properties

    private let chatStreamURL: URL
    private let supabaseKey: String
    private let session: URLSession
    private var authToken: String?

    /// Request timeout in seconds (longer than default to tolerate server prep + cold starts)
    private let requestTimeout: TimeInterval = 90

    /// One automatic reconnect for transient network drops before any stream tokens arrive
    private let maxConnectionAttempts = 2

    // MARK: - Initialization

    /// Creates a ChatStreamService with the given configuration.
    /// - Parameters:
    ///   - supabaseURL: Base Supabase URL (defaults to Configuration.supabaseURL)
    ///   - supabaseKey: Supabase anon key (defaults to Configuration.supabasePublishableKey)
    ///   - session: URLSession to use for requests (defaults to .shared)
    /// - Note: Uses a validated URL; logs error and uses placeholder if URL is invalid
    init(
        supabaseURL: String = Configuration.supabaseURL,
        supabaseKey: String = Configuration.supabasePublishableKey,
        session: URLSession? = nil
    ) {
        // Gracefully handle invalid URL instead of crashing
        if let url = URL(string: "\(supabaseURL)/functions/v1/chat-stream") {
            self.chatStreamURL = url
        } else {
            // Log error but don't crash - stream requests will fail gracefully
            #if DEBUG
            print("ChatStreamService: ERROR - Invalid Supabase URL: \(supabaseURL)")
            #endif
            // Use a placeholder URL - requests will fail with proper error handling
            self.chatStreamURL = URL(string: "https://invalid.supabase.co/functions/v1/chat-stream")!
        }
        self.supabaseKey = supabaseKey
        self.session = session ?? Self.makeDefaultSession()
    }

    // MARK: - Public Methods

    /// Sets the auth token for authenticated requests
    func setAuthToken(_ token: String?) {
        self.authToken = token
    }

    /// Streams chat completion from the Edge Function
    /// - Parameters:
    ///   - message: User message to send
    ///   - conversationId: Current conversation ID
    ///   - firstMessage: When true, coach speaks first (Story 11.3 discovery mode)
    /// - Returns: AsyncThrowingStream of StreamEvents
    func streamChat(
        message: String,
        conversationId: UUID,
        firstMessage: Bool = false
    ) -> AsyncThrowingStream<StreamEvent, Error> {
        AsyncThrowingStream { continuation in
            // Track the inner task for cancellation propagation
            let streamTask = Task {
                var attempt = 1

                while attempt <= maxConnectionAttempts {
                    var didReceiveStreamData = false
                    do {
                        didReceiveStreamData = try await streamOnce(
                            message: message,
                            conversationId: conversationId,
                            firstMessage: firstMessage,
                            continuation: continuation
                        )
                        continuation.finish()
                        return
                    } catch is CancellationError {
                        continuation.finish()
                        return
                    } catch {
                        let shouldRetry = shouldRetryAfter(error: error)

                        #if DEBUG
                        print("ChatStreamService: Stream attempt \(attempt) failed: \(error.localizedDescription)")
                        #endif

                        // Only retry if transient, no data was received yet, and we have attempts left.
                        // Mid-stream disconnects are non-retriable to prevent duplicate tokens.
                        if shouldRetry, !didReceiveStreamData, attempt < maxConnectionAttempts {
                            attempt += 1
                            try? await Task.sleep(nanoseconds: 400_000_000)
                            continue
                        }

                        continuation.finish(throwing: error)
                        return
                    }
                }
            }

            // Cancel the inner task when the stream is terminated
            continuation.onTermination = { @Sendable _ in
                streamTask.cancel()
            }
        }
    }

    // MARK: - Internal Streaming

    private func streamOnce(
        message: String,
        conversationId: UUID,
        firstMessage: Bool,
        continuation: AsyncThrowingStream<StreamEvent, Error>.Continuation
    ) async throws -> Bool {
        try Task.checkCancellation()

        var request = URLRequest(url: chatStreamURL)
        request.httpMethod = "POST"
        request.timeoutInterval = requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")

        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            #if DEBUG
            print("ChatStreamService: Auth token set (length: \(token.count))")
            #endif
        } else {
            #if DEBUG
            print("ChatStreamService: WARNING - No auth token!")
            #endif
        }

        let body = ChatRequest(message: message, conversationId: conversationId, firstMessage: firstMessage)
        request.httpBody = try JSONEncoder().encode(body)

        #if DEBUG
        print("ChatStreamService: POST \(self.chatStreamURL)")
        #endif

        let (bytes, response) = try await session.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChatStreamError.invalidResponse
        }

        #if DEBUG
        print("ChatStreamService: HTTP \(httpResponse.statusCode)")
        #endif

        guard httpResponse.statusCode == 200 else {
            // Read error body for details (needed for 429 parsing and debug logging)
            var errorBody = ""
            for try await line in bytes.lines {
                errorBody += line
                if errorBody.count > 500 { break }
            }

            #if DEBUG
            print("ChatStreamService: Error response: \(errorBody)")
            #endif

            // Story 10.1: Parse 429 rate limit response for rich error details (AC #5)
            if httpResponse.statusCode == 429, let data = errorBody.data(using: .utf8) {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let isTrial = json["is_trial"] as? Bool ?? false
                    var resetDate: Date?
                    if let resetStr = json["remaining_until_reset"] as? String {
                        let formatter = ISO8601DateFormatter()
                        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        resetDate = formatter.date(from: resetStr)
                        // Fallback without fractional seconds
                        if resetDate == nil {
                            formatter.formatOptions = [.withInternetDateTime]
                            resetDate = formatter.date(from: resetStr)
                        }
                    }
                    throw ChatStreamError.rateLimited(isTrial: isTrial, resetDate: resetDate)
                }
            }

            throw ChatStreamError.httpError(statusCode: httpResponse.statusCode)
        }

        var didReceiveStreamData = false

        for try await line in bytes.lines {
            // Check for cancellation on each line
            try Task.checkCancellation()

            if line.hasPrefix("data: ") {
                let jsonString = String(line.dropFirst(6))
                if let data = jsonString.data(using: .utf8) {
                    do {
                        let event = try JSONDecoder().decode(StreamEvent.self, from: data)
                        didReceiveStreamData = true
                        continuation.yield(event)

                        // Check if stream is done
                        if case .done = event {
                            break
                        }
                    } catch {
                        // Skip malformed JSON, continue with stream
                        #if DEBUG
                        print("ChatStreamService: Failed to decode event: \(error)")
                        #endif
                    }
                }
            }
        }

        return didReceiveStreamData
    }

    // MARK: - Network Resilience

    private func shouldRetryAfter(error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .networkConnectionLost, .timedOut, .cannotConnectToHost, .dnsLookupFailed:
                return true
            default:
                return false
            }
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return nsError.code == NSURLErrorNetworkConnectionLost ||
                nsError.code == NSURLErrorTimedOut ||
                nsError.code == NSURLErrorCannotConnectToHost ||
                nsError.code == NSURLErrorDNSLookupFailed
        }

        return false
    }

    private static func makeDefaultSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 90
        configuration.timeoutIntervalForResource = 120
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }
}

// MARK: - Errors

enum ChatStreamError: LocalizedError, Equatable {
    case invalidResponse
    case httpError(statusCode: Int)
    case streamInterrupted
    case authenticationRequired
    /// Story 10.1: Rate limited — user has exceeded message quota for their billing period
    case rateLimited(isTrial: Bool, resetDate: Date?)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "I had trouble connecting. Let's try again."
        case .httpError(let statusCode):
            if statusCode == 401 {
                return "I had trouble remembering you. Please sign in again."
            }
            return "Coach is taking a moment. Let's try again."
        case .streamInterrupted:
            return "Our connection was interrupted. Let's try again."
        case .authenticationRequired:
            return "Please sign in to continue our conversation."
        case .rateLimited(let isTrial, let resetDate):
            if isTrial {
                return "You've used your trial sessions — ready to continue?"
            } else {
                let dateStr = resetDate.map { DateFormatter.localizedString(from: $0, dateStyle: .medium, timeStyle: .none) } ?? "soon"
                return "We've had a lot of great conversations this month! Your next session refreshes on \(dateStr)."
            }
        }
    }

    static func == (lhs: ChatStreamError, rhs: ChatStreamError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidResponse, .invalidResponse): return true
        case (.httpError(let a), .httpError(let b)): return a == b
        case (.streamInterrupted, .streamInterrupted): return true
        case (.authenticationRequired, .authenticationRequired): return true
        case (.rateLimited(let a1, let a2), .rateLimited(let b1, let b2)): return a1 == b1 && a2 == b2
        default: return false
        }
    }
}
