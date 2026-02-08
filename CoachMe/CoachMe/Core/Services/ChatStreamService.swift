//
//  ChatStreamService.swift
//  CoachMe
//
//  Created by Dev Agent on 2/6/26.
//
//  Story 2.4: Updated to parse memory_moment flag from SSE events (AC #4)
//  Story 3.4: Updated to parse pattern_insight flag from SSE events
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
    enum StreamEvent: Decodable, Equatable {
        /// Token with content, memory moment indicator, and pattern insight indicator
        /// Story 2.4: hasMemoryMoment indicates if accumulated content contains [MEMORY:...] tags
        /// Story 3.4: hasPatternInsight indicates if accumulated content contains [PATTERN:...] tags
        case token(content: String, hasMemoryMoment: Bool, hasPatternInsight: Bool)

        /// Stream completed with message ID and usage stats
        case done(messageId: UUID, usage: TokenUsage)

        /// Error occurred during streaming
        case error(message: String)

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
                self = .token(content: content, hasMemoryMoment: memoryMoment, hasPatternInsight: patternInsight)
            case "done":
                let messageId = try container.decode(UUID.self, forKey: .messageId)
                let usage = try container.decode(TokenUsage.self, forKey: .usage)
                self = .done(messageId: messageId, usage: usage)
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

        enum CodingKeys: String, CodingKey {
            case message
            case conversationId = "conversation_id"
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
    /// - Returns: AsyncThrowingStream of StreamEvents
    func streamChat(
        message: String,
        conversationId: UUID
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

        let body = ChatRequest(message: message, conversationId: conversationId)
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
            #if DEBUG
            // Try to read error body for more details
            var errorBody = ""
            for try await line in bytes.lines {
                errorBody += line
                if errorBody.count > 500 { break }
            }
            print("ChatStreamService: Error response: \(errorBody)")
            #endif
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
        }
    }
}
