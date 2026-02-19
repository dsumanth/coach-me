//
//  MessageFeedbackService.swift
//  CoachMe
//
//  Sprint 2: Assistant message feedback collection (thumbs up/down).
//

import Foundation
import Supabase

enum MessageFeedbackSentiment: String, Codable, Sendable {
    case up
    case down
}

enum MessageFeedbackError: LocalizedError, Equatable {
    case notAuthenticated
    case submitFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in before sharing feedback."
        case .submitFailed(let reason):
            return "I couldn't save your feedback. \(reason)"
        }
    }
}

private struct MessageFeedbackUpsert: Encodable {
    let userId: UUID
    let conversationId: UUID
    let messageId: UUID
    let sentiment: String
    let feedbackText: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case conversationId = "conversation_id"
        case messageId = "message_id"
        case sentiment
        case feedbackText = "feedback_text"
    }
}

private struct ProductEventInsert: Encodable {
    let userId: UUID
    let conversationId: UUID
    let messageId: UUID
    let eventName: String
    let properties: [String: AnyJSON]

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case conversationId = "conversation_id"
        case messageId = "message_id"
        case eventName = "event_name"
        case properties
    }
}

@MainActor
final class MessageFeedbackService {
    static let shared = MessageFeedbackService()

    private let supabase: SupabaseClient

    private init() {
        self.supabase = AppEnvironment.shared.supabase
    }

    init(supabase: SupabaseClient) {
        self.supabase = supabase
    }

    func submitFeedback(
        conversationId: UUID,
        messageId: UUID,
        sentiment: MessageFeedbackSentiment,
        feedbackText: String? = nil
    ) async throws {
        let userId = try await currentUserId()

        let upsert = MessageFeedbackUpsert(
            userId: userId,
            conversationId: conversationId,
            messageId: messageId,
            sentiment: sentiment.rawValue,
            feedbackText: feedbackText
        )

        do {
            try await supabase
                .from("message_feedback")
                .upsert(upsert, onConflict: "user_id,message_id")
                .execute()
        } catch {
            throw MessageFeedbackError.submitFailed(error.localizedDescription)
        }

        // Best-effort analytics signal for product iteration.
        let event = ProductEventInsert(
            userId: userId,
            conversationId: conversationId,
            messageId: messageId,
            eventName: "assistant_message_feedback_submitted",
            properties: [
                "sentiment": .string(sentiment.rawValue)
            ]
        )
        try? await supabase
            .from("product_events")
            .insert(event)
            .execute()
    }

    private func currentUserId() async throws -> UUID {
        do {
            let session = try await supabase.auth.session
            return session.user.id
        } catch {
            throw MessageFeedbackError.notAuthenticated
        }
    }
}
