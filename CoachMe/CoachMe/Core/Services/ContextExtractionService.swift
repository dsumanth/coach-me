//
//  ContextExtractionService.swift
//  CoachMe
//
//  Story 2.3: Progressive Context Extraction
//  Service for extracting context from conversations via Edge Function
//

import Foundation

/// Errors specific to context extraction operations
/// Per UX-11: Use warm, first-person error messages
enum ContextExtractionError: LocalizedError, Equatable {
    case notAuthenticated
    case networkError(String)
    case invalidResponse
    case extractionFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "I need you to sign in first."
        case .networkError(let reason):
            return "I had trouble connecting. \(reason)"
        case .invalidResponse:
            return "I had trouble understanding the response."
        case .extractionFailed(let reason):
            return "I couldn't analyze our conversation. \(reason)"
        }
    }

    static func == (lhs: ContextExtractionError, rhs: ContextExtractionError) -> Bool {
        switch (lhs, rhs) {
        case (.notAuthenticated, .notAuthenticated):
            return true
        case (.invalidResponse, .invalidResponse):
            return true
        case (.networkError(let a), .networkError(let b)):
            return a == b
        case (.extractionFailed(let a), .extractionFailed(let b)):
            return a == b
        default:
            return false
        }
    }
}

/// Message structure for extraction request
struct ExtractionMessage: Encodable {
    let role: String
    let content: String
}

/// Protocol for context extraction operations (enables testing)
@MainActor
protocol ContextExtractionServiceProtocol {
    func setAuthToken(_ token: String?)
    func extractFromConversation(conversationId: UUID, messages: [ExtractionMessage]) async throws -> [ExtractedInsight]
    func extractFromConversation(conversationId: UUID, chatMessages: [ChatMessage]) async throws -> [ExtractedInsight]
}

/// Service for extracting context insights from conversations
/// Per architecture.md: Use @MainActor singleton pattern for services
@MainActor
final class ContextExtractionService: ContextExtractionServiceProtocol {
    // MARK: - Singleton

    static let shared = ContextExtractionService()

    // MARK: - Types

    /// Request body for extraction Edge Function
    private struct ExtractionRequest: Encodable {
        let conversationId: UUID
        let messages: [ExtractionMessage]

        enum CodingKeys: String, CodingKey {
            case conversationId = "conversation_id"
            case messages
        }
    }

    /// Response from extraction Edge Function
    private struct ExtractionResponse: Decodable {
        let insights: [InsightDTO]

        struct InsightDTO: Decodable {
            let id: String
            let content: String
            let category: String
            let confidence: Double
            let sourceConversationId: String
            let confirmed: Bool
            let extractedAt: String

            enum CodingKeys: String, CodingKey {
                case id
                case content
                case category
                case confidence
                case sourceConversationId = "source_conversation_id"
                case confirmed
                case extractedAt = "extracted_at"
            }
        }
    }

    // MARK: - Properties

    private let extractURL: URL?
    private let supabaseKey: String
    private let session: URLSession
    private var authToken: String?

    /// Request timeout in seconds
    private let requestTimeout: TimeInterval = 30

    // MARK: - Initialization

    private init(
        supabaseURL: String = Configuration.supabaseURL,
        supabaseKey: String = Configuration.supabasePublishableKey,
        session: URLSession = .shared
    ) {
        let url = URL(string: "\(supabaseURL)/functions/v1/extract-context")
        #if DEBUG
        if url == nil {
            assertionFailure("Invalid Supabase URL configuration: \(supabaseURL)")
        }
        #endif
        self.extractURL = url
        self.supabaseKey = supabaseKey
        self.session = session
    }

    // MARK: - Auth Token Management

    /// Sets the auth token for authenticated requests
    /// - Parameter token: The JWT auth token, or nil to clear
    func setAuthToken(_ token: String?) {
        self.authToken = token
    }

    // MARK: - Extraction

    /// Extracts context insights from conversation messages
    /// - Parameters:
    ///   - conversationId: The conversation to analyze
    ///   - messages: Array of messages to analyze
    /// - Returns: Array of extracted insights (unconfirmed)
    func extractFromConversation(
        conversationId: UUID,
        messages: [ExtractionMessage]
    ) async throws -> [ExtractedInsight] {
        guard let token = authToken else {
            throw ContextExtractionError.notAuthenticated
        }

        guard let extractURL else {
            throw ContextExtractionError.extractionFailed("Service configuration is invalid.")
        }

        // Build request
        var request = URLRequest(url: extractURL)
        request.httpMethod = "POST"
        request.timeoutInterval = requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")

        let requestBody = ExtractionRequest(
            conversationId: conversationId,
            messages: messages
        )
        request.httpBody = try JSONEncoder().encode(requestBody)

        // Make request
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ContextExtractionError.networkError(error.localizedDescription)
        }

        // Check HTTP status
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ContextExtractionError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 401:
            throw ContextExtractionError.notAuthenticated
        case 400..<500:
            let errorMessage = String(data: data, encoding: .utf8) ?? "Bad request"
            throw ContextExtractionError.extractionFailed(errorMessage)
        default:
            throw ContextExtractionError.extractionFailed("Server error")
        }

        // Parse response
        let decoder = JSONDecoder()
        let extractionResponse: ExtractionResponse
        do {
            extractionResponse = try decoder.decode(ExtractionResponse.self, from: data)
        } catch {
            #if DEBUG
            print("ContextExtractionService: Failed to decode response: \(error)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("Response: \(responseString)")
            }
            #endif
            throw ContextExtractionError.invalidResponse
        }

        // Map DTOs to domain models
        let insights = extractionResponse.insights.compactMap { dto -> ExtractedInsight? in
            guard let category = InsightCategory(rawValue: dto.category),
                  let uuid = UUID(uuidString: dto.id),
                  let sourceId = UUID(uuidString: dto.sourceConversationId) else {
                return nil
            }

            // Parse ISO8601 date
            let dateFormatter = ISO8601DateFormatter()
            let extractedAt = dateFormatter.date(from: dto.extractedAt) ?? Date()

            return ExtractedInsight(
                id: uuid,
                content: dto.content,
                category: category,
                confidence: dto.confidence,
                sourceConversationId: sourceId,
                confirmed: dto.confirmed,
                extractedAt: extractedAt
            )
        }

        #if DEBUG
        print("ContextExtractionService: Extracted \(insights.count) insights")
        #endif

        return insights
    }

    /// Convenience method to extract from ChatMessage array
    /// - Parameters:
    ///   - conversationId: The conversation to analyze
    ///   - chatMessages: Array of ChatMessage from the conversation
    /// - Returns: Array of extracted insights
    func extractFromConversation(
        conversationId: UUID,
        chatMessages: [ChatMessage]
    ) async throws -> [ExtractedInsight] {
        let messages = chatMessages.map { message in
            ExtractionMessage(
                role: message.role == .user ? "user" : "assistant",
                content: message.content
            )
        }
        return try await extractFromConversation(conversationId: conversationId, messages: messages)
    }
}
