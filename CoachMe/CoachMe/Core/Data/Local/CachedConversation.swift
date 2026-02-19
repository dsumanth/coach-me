//
//  CachedConversation.swift
//  CoachMe
//
//  Story 7.1: Offline Data Caching with SwiftData
//  SwiftData model for caching conversations locally
//

import Foundation
import SwiftData

/// SwiftData model for caching conversations locally
/// Enables offline access to conversation history
@Model
final class CachedConversation {
    /// Remote conversation ID from Supabase — unique constraint for upsert behavior
    @Attribute(.unique) var remoteId: UUID

    /// Owner user ID
    var userId: UUID

    /// Conversation title (typically first user message, truncated)
    var title: String?

    /// Coaching domain (e.g. "career", "relationships")
    var domain: String?

    /// Timestamp of last message in the conversation
    var lastMessageAt: Date?

    /// Number of messages in the conversation
    var messageCount: Int

    /// When the conversation was created remotely
    var createdAt: Date

    /// When the conversation was last updated remotely
    var updatedAt: Date

    /// When this cache entry was last written
    var cachedAt: Date

    /// Story 7.4: Sync status — "synced", "pending", or "conflict"
    var syncStatus: String = "synced"

    init(
        remoteId: UUID,
        userId: UUID,
        title: String? = nil,
        domain: String? = nil,
        lastMessageAt: Date? = nil,
        messageCount: Int = 0,
        createdAt: Date,
        updatedAt: Date,
        cachedAt: Date = Date(),
        syncStatus: String = "synced"
    ) {
        self.remoteId = remoteId
        self.userId = userId
        self.title = title
        self.domain = domain
        self.lastMessageAt = lastMessageAt
        self.messageCount = messageCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.cachedAt = cachedAt
        self.syncStatus = syncStatus
    }

    // MARK: - Conversion Methods

    /// Create a CachedConversation from a remote Conversation model
    convenience init(from conversation: ConversationService.Conversation) {
        self.init(
            remoteId: conversation.id,
            userId: conversation.userId,
            title: conversation.title,
            domain: conversation.domain,
            lastMessageAt: conversation.lastMessageAt,
            messageCount: conversation.messageCount,
            createdAt: conversation.createdAt,
            updatedAt: conversation.updatedAt
        )
    }

    /// Convert back to the Conversation model used by ViewModels
    func toConversation() -> ConversationService.Conversation {
        ConversationService.Conversation(
            id: remoteId,
            userId: userId,
            title: title,
            domain: domain,
            lastMessageAt: lastMessageAt,
            messageCount: messageCount,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    /// Update this cache entry from a remote Conversation
    func update(from conversation: ConversationService.Conversation) {
        self.userId = conversation.userId
        self.title = conversation.title
        self.domain = conversation.domain
        self.lastMessageAt = conversation.lastMessageAt
        self.messageCount = conversation.messageCount
        self.updatedAt = conversation.updatedAt
        self.cachedAt = Date()
    }
}
