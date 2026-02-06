//
//  ChatStreamService.swift
//  CoachMe
//
//  Created by Dev Agent on 2/6/26.
//

import Foundation

/// Service for streaming chat responses via Server-Sent Events
/// Per architecture.md: Use URLSession AsyncBytes for SSE
@MainActor
final class ChatStreamService {
    // MARK: - Types

    /// Events received from the SSE stream
    enum StreamEvent: Decodable {
        case token(String)
        case done(messageId: UUID, usage: TokenUsage)
        case error(message: String)

        struct TokenUsage: Decodable {
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
                self = .token(content)
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

    /// Request timeout in seconds (30s default for streaming)
    private let requestTimeout: TimeInterval = 30

    // MARK: - Initialization

    init(
        supabaseURL: String = Configuration.supabaseURL,
        supabaseKey: String = Configuration.supabasePublishableKey,
        session: URLSession = .shared
    ) {
        guard let url = URL(string: "\(supabaseURL)/functions/v1/chat-stream") else {
            fatalError("Invalid Supabase URL configuration: \(supabaseURL)")
        }
        self.chatStreamURL = url
        self.supabaseKey = supabaseKey
        self.session = session
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
            Task {
                do {
                    var request = URLRequest(url: chatStreamURL)
                    request.httpMethod = "POST"
                    request.timeoutInterval = requestTimeout
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    request.setValue(supabaseKey, forHTTPHeaderField: "apikey")

                    if let token = authToken {
                        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    }

                    let body = ChatRequest(message: message, conversationId: conversationId)
                    request.httpBody = try JSONEncoder().encode(body)

                    let (bytes, response) = try await session.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw ChatStreamError.invalidResponse
                    }

                    guard httpResponse.statusCode == 200 else {
                        throw ChatStreamError.httpError(statusCode: httpResponse.statusCode)
                    }

                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))
                            if let data = jsonString.data(using: .utf8) {
                                do {
                                    let event = try JSONDecoder().decode(StreamEvent.self, from: data)
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
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
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
