//
//  ConversationService.swift
//  CoachMe
//
//  Created by Claude Code on 2/6/26.
//

import Foundation
import Supabase

// MARK: - Protocol for Testability

/// Protocol defining conversation service operations for dependency injection and testing
protocol ConversationServiceProtocol: Sendable {
    func createConversation(id: UUID?) async throws -> UUID
    func ensureConversationExists(id: UUID) async throws -> UUID
    func conversationExists(id: UUID) async -> Bool
    func updateConversation(id: UUID, title: String?) async
    func deleteConversation(id: UUID) async throws
    func deleteAllConversations() async throws
    func fetchConversations() async throws -> [ConversationService.Conversation]
    func fetchMessages(conversationId: UUID) async throws -> [ChatMessage]
}

/// Service for managing conversation lifecycle in the database
/// Required because chat-stream edge function validates conversation ownership
@MainActor
final class ConversationService: ConversationServiceProtocol {
    // MARK: - Singleton

    static let shared = ConversationService()

    // MARK: - Types

    /// Errors specific to conversation operations
    enum ConversationError: LocalizedError, Equatable {
        case notAuthenticated
        case creationFailed(String)
        case notFound
        case deleteFailed(String)
        case fetchFailed(String)

        var errorDescription: String? {
            switch self {
            case .notAuthenticated:
                return "Please sign in to start a conversation."
            case .creationFailed(let reason):
                return "Couldn't start our conversation. \(reason)"
            case .notFound:
                return "Couldn't find that conversation."
            case .deleteFailed(let reason):
                return "I couldn't remove that conversation. \(reason)"
            case .fetchFailed(let reason):
                return "I couldn't load your conversations right now. \(reason)"
            }
        }
    }

    /// Conversation model matching database schema
    struct Conversation: Codable, Identifiable, Sendable, Hashable {
        let id: UUID
        let userId: UUID
        var title: String?
        var domain: String?
        var lastMessageAt: Date?
        var messageCount: Int
        let createdAt: Date
        var updatedAt: Date

        enum CodingKeys: String, CodingKey {
            case id
            case userId = "user_id"
            case title
            case domain
            case lastMessageAt = "last_message_at"
            case messageCount = "message_count"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
        }
    }

    /// Minimal insert model (only required fields)
    private struct ConversationInsert: Encodable {
        let id: UUID
        let userId: UUID

        enum CodingKeys: String, CodingKey {
            case id
            case userId = "user_id"
        }
    }

    // MARK: - Properties

    private let supabase: SupabaseClient

    // MARK: - Initialization

    private init() {
        self.supabase = AppEnvironment.shared.supabase
    }

    // For testing
    init(supabase: SupabaseClient) {
        self.supabase = supabase
    }

    // MARK: - Public Methods

    /// Creates a new conversation in the database
    /// - Parameter id: Optional UUID for the conversation (generated if nil)
    /// - Returns: The created conversation ID
    /// - Throws: ConversationError if creation fails
    func createConversation(id: UUID? = nil) async throws -> UUID {
        // Get current user ID from session
        guard let userId = try? await getCurrentUserId() else {
            throw ConversationError.notAuthenticated
        }

        let conversationId = id ?? UUID()
        let insert = ConversationInsert(id: conversationId, userId: userId)

        do {
            try await supabase
                .from("conversations")
                .insert(insert)
                .execute()

            #if DEBUG
            print("ConversationService: Created conversation \(conversationId)")
            #endif

            return conversationId
        } catch {
            #if DEBUG
            print("ConversationService: Failed to create conversation: \(error)")
            #endif
            throw ConversationError.creationFailed(error.localizedDescription)
        }
    }

    /// Ensures a conversation exists, creating it if necessary
    /// - Parameter id: The conversation ID to ensure exists
    /// - Returns: The conversation ID (same as input if it existed, or newly created)
    /// - Throws: ConversationError if creation fails
    func ensureConversationExists(id: UUID) async throws -> UUID {
        // Check if conversation already exists
        if await conversationExists(id: id) {
            return id
        }

        // Create the conversation with the specified ID
        return try await createConversation(id: id)
    }

    /// Checks if a conversation exists for the current user
    /// - Parameter id: The conversation ID to check
    /// - Returns: true if the conversation exists and belongs to current user
    func conversationExists(id: UUID) async -> Bool {
        guard let userId = try? await getCurrentUserId() else {
            return false
        }

        do {
            struct IdOnly: Decodable { let id: UUID }
            let result: [IdOnly] = try await supabase
                .from("conversations")
                .select("id")
                .eq("id", value: id.uuidString)
                .eq("user_id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value

            return !result.isEmpty
        } catch {
            #if DEBUG
            print("ConversationService: Error checking conversation existence: \(error)")
            #endif
            return false
        }
    }

    /// Updates conversation metadata after a message is sent
    /// - Parameters:
    ///   - id: The conversation ID
    ///   - title: Optional title to set (typically from first user message)
    func updateConversation(id: UUID, title: String? = nil) async {
        do {
            var updates: [String: AnyEncodable] = [
                "last_message_at": AnyEncodable(ISO8601DateFormatter().string(from: Date()))
            ]

            if let title = title {
                updates["title"] = AnyEncodable(title)
            }

            try await supabase
                .from("conversations")
                .update(updates)
                .eq("id", value: id.uuidString)
                .execute()
        } catch {
            // Non-fatal: metadata update failure shouldn't break chat
            #if DEBUG
            print("ConversationService: Failed to update conversation metadata: \(error)")
            #endif
        }
    }

    /// Deletes a conversation from the database
    /// Messages are automatically deleted via CASCADE constraint in schema
    /// - Parameter id: The conversation ID to delete
    /// - Throws: ConversationError if deletion fails or user doesn't own conversation
    func deleteConversation(id: UUID) async throws {
        // Ensure user is authenticated (Task 1.5)
        guard let userId = try? await getCurrentUserId() else {
            throw ConversationError.notAuthenticated
        }

        do {
            // RLS policy "Users can delete own conversations" already enforces ownership
            // but we verify locally for better error messaging
            struct IdOnly: Decodable { let id: UUID }
            let existing: [IdOnly] = try await supabase
                .from("conversations")
                .select("id")
                .eq("id", value: id.uuidString)
                .eq("user_id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value

            guard !existing.isEmpty else {
                throw ConversationError.notFound
            }

            try await supabase
                .from("conversations")
                .delete()
                .eq("id", value: id.uuidString)
                .eq("user_id", value: userId.uuidString)
                .execute()

            #if DEBUG
            print("ConversationService: Deleted conversation \(id)")
            #endif
        } catch let error as ConversationError {
            throw error
        } catch {
            #if DEBUG
            print("ConversationService: Failed to delete conversation: \(error)")
            #endif
            throw ConversationError.deleteFailed(error.localizedDescription)
        }
    }

    /// Deletes all conversations for the current user
    /// Messages are automatically deleted via CASCADE constraint in schema
    /// - Throws: ConversationError if deletion fails
    func deleteAllConversations() async throws {
        // Ensure user is authenticated (Task 1.5)
        guard let userId = try? await getCurrentUserId() else {
            throw ConversationError.notAuthenticated
        }

        do {
            // RLS policy ensures only user's own conversations are deleted
            try await supabase
                .from("conversations")
                .delete()
                .eq("user_id", value: userId.uuidString)
                .execute()

            #if DEBUG
            print("ConversationService: Deleted all conversations for user \(userId)")
            #endif
        } catch {
            #if DEBUG
            print("ConversationService: Failed to delete all conversations: \(error)")
            #endif
            throw ConversationError.deleteFailed(error.localizedDescription)
        }
    }

    // MARK: - Fetch Methods (Story 3.6)

    /// Fetches all conversations for the current user, ordered by most recent first
    /// - Returns: Array of conversations sorted by last_message_at DESC
    /// - Throws: ConversationError if user is not authenticated or fetch fails
    func fetchConversations() async throws -> [Conversation] {
        guard (try? await getCurrentUserId()) != nil else {
            throw ConversationError.notAuthenticated
        }

        do {
            let conversations: [Conversation] = try await supabase
                .from("conversations")
                .select()
                .order("last_message_at", ascending: false)
                .execute()
                .value

            #if DEBUG
            print("ConversationService: Fetched \(conversations.count) conversations")
            #endif

            return conversations
        } catch {
            #if DEBUG
            print("ConversationService: Failed to fetch conversations: \(error)")
            #endif
            throw ConversationError.fetchFailed(error.localizedDescription)
        }
    }

    /// Fetches all messages for a given conversation, ordered by creation time
    /// - Parameter conversationId: The conversation to fetch messages for
    /// - Returns: Array of messages sorted by created_at ASC
    /// - Throws: ConversationError if user is not authenticated or fetch fails
    func fetchMessages(conversationId: UUID) async throws -> [ChatMessage] {
        guard (try? await getCurrentUserId()) != nil else {
            throw ConversationError.notAuthenticated
        }

        do {
            let messages: [ChatMessage] = try await supabase
                .from("messages")
                .select()
                .eq("conversation_id", value: conversationId.uuidString)
                .order("created_at")
                .execute()
                .value

            #if DEBUG
            print("ConversationService: Fetched \(messages.count) messages for conversation \(conversationId)")
            #endif

            return messages
        } catch {
            #if DEBUG
            print("ConversationService: Failed to fetch messages: \(error)")
            #endif
            throw ConversationError.fetchFailed(error.localizedDescription)
        }
    }

    // MARK: - Private Helpers

    private func getCurrentUserId() async throws -> UUID {
        let session = try await supabase.auth.session
        return session.user.id
    }
}

// MARK: - AnyEncodable Helper

/// Type-erased Encodable wrapper for dynamic update dictionaries
private struct AnyEncodable: Encodable {
    private let encode: (Encoder) throws -> Void

    init<T: Encodable>(_ wrapped: T) {
        self.encode = wrapped.encode(to:)
    }

    func encode(to encoder: Encoder) throws {
        try encode(encoder)
    }
}
