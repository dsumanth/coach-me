//
//  CachedMessage.swift
//  CoachMe
//
//  Story 7.1: Offline Data Caching with SwiftData
//  SwiftData model for caching messages locally
//

import Foundation
import SwiftData

/// SwiftData model for caching chat messages locally
/// Enables offline access to past conversation messages
@Model
final class CachedMessage {
    /// Remote message ID from Supabase — unique constraint for upsert behavior
    @Attribute(.unique) var remoteId: UUID

    /// The conversation this message belongs to
    var conversationId: UUID

    /// Message role as String ("user" or "assistant")
    /// Stored as String because SwiftData doesn't support custom enums natively
    var role: String

    /// Message text content
    var content: String

    /// When the message was created remotely
    var createdAt: Date

    /// When this cache entry was last written
    var cachedAt: Date

    /// Story 7.4: Sync status — "synced", "pending", or "conflict"
    var syncStatus: String = "synced"

    init(
        remoteId: UUID,
        conversationId: UUID,
        role: String,
        content: String,
        createdAt: Date,
        cachedAt: Date = Date(),
        syncStatus: String = "synced"
    ) {
        self.remoteId = remoteId
        self.conversationId = conversationId
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.cachedAt = cachedAt
        self.syncStatus = syncStatus
    }

    // MARK: - Conversion Methods

    /// Create a CachedMessage from a ChatMessage model
    convenience init(from message: ChatMessage) {
        self.init(
            remoteId: message.id,
            conversationId: message.conversationId,
            role: message.role.rawValue,
            content: message.content,
            createdAt: message.createdAt
        )
    }

    /// Convert back to the ChatMessage model used by ViewModels
    func toChatMessage() -> ChatMessage {
        ChatMessage(
            id: remoteId,
            conversationId: conversationId,
            role: ChatMessage.Role(rawValue: role) ?? .assistant,
            content: content,
            createdAt: createdAt
        )
    }

    /// Update this cache entry from a ChatMessage
    func update(from message: ChatMessage) {
        self.conversationId = message.conversationId
        self.role = message.role.rawValue
        self.content = message.content
        self.createdAt = message.createdAt
        self.cachedAt = Date()
    }
}
