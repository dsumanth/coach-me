//
//  OfflineCacheService.swift
//  CoachMe
//
//  Story 7.1: Offline Data Caching with SwiftData
//  Provides SwiftData-backed caching for conversations and messages
//

import Foundation
import SwiftData

/// Service for managing offline cache of conversations and messages via SwiftData.
/// Follows @MainActor singleton pattern consistent with other services.
/// Uses fetch-all-and-filter pattern for Swift 6 Sendable compliance.
@MainActor
final class OfflineCacheService {
    static let shared = OfflineCacheService()

    private var modelContext: ModelContext {
        AppEnvironment.shared.modelContext
    }

    private init() {}

    // For testing with custom container
    init(modelContext: ModelContext) {
        self._testModelContext = modelContext
    }

    private var _testModelContext: ModelContext?

    private var activeContext: ModelContext {
        _testModelContext ?? modelContext
    }

    // MARK: - Conversation Caching

    /// Bulk upsert conversations to SwiftData cache
    func cacheConversations(_ conversations: [ConversationService.Conversation]) {
        let context = activeContext
        do {
            // Fetch all existing cached conversations (fetch-all-and-filter pattern)
            let descriptor = FetchDescriptor<CachedConversation>()
            let existing = try context.fetch(descriptor)
            let existingByRemoteId = Dictionary(uniqueKeysWithValues: existing.map { ($0.remoteId, $0) })

            for conversation in conversations {
                if let cached = existingByRemoteId[conversation.id] {
                    cached.update(from: conversation)
                } else {
                    let cached = CachedConversation(from: conversation)
                    context.insert(cached)
                }
            }

            try context.save()
        } catch {
            #if DEBUG
            print("OfflineCacheService: Failed to cache conversations: \(error.localizedDescription)")
            #endif
        }
    }

    /// Bulk upsert messages to SwiftData cache for a conversation
    func cacheMessages(_ messages: [ChatMessage], forConversation conversationId: UUID) {
        let context = activeContext
        do {
            // Fetch all existing cached messages (fetch-all-and-filter pattern)
            let descriptor = FetchDescriptor<CachedMessage>()
            let existing = try context.fetch(descriptor)
            let forConversation = existing.filter { $0.conversationId == conversationId }
            let existingByRemoteId = Dictionary(uniqueKeysWithValues: forConversation.map { ($0.remoteId, $0) })

            for message in messages {
                if let cached = existingByRemoteId[message.id] {
                    cached.update(from: message)
                } else {
                    let cached = CachedMessage(from: message)
                    context.insert(cached)
                }
            }

            try context.save()
        } catch {
            #if DEBUG
            print("OfflineCacheService: Failed to cache messages: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Retrieval

    /// Get all cached conversations, sorted by lastMessageAt descending
    func getCachedConversations() -> [CachedConversation] {
        let context = activeContext
        do {
            let descriptor = FetchDescriptor<CachedConversation>()
            let all = try context.fetch(descriptor)
            return all.sorted { ($0.lastMessageAt ?? .distantPast) > ($1.lastMessageAt ?? .distantPast) }
        } catch {
            #if DEBUG
            print("OfflineCacheService: Failed to fetch cached conversations: \(error.localizedDescription)")
            #endif
            return []
        }
    }

    /// Get cached messages for a specific conversation, sorted by createdAt ascending
    func getCachedMessages(conversationId: UUID) -> [CachedMessage] {
        let context = activeContext
        do {
            let descriptor = FetchDescriptor<CachedMessage>()
            let all = try context.fetch(descriptor)
            let matching = all.filter { $0.conversationId == conversationId }
            return matching.sorted { $0.createdAt < $1.createdAt }
        } catch {
            #if DEBUG
            print("OfflineCacheService: Failed to fetch cached messages: \(error.localizedDescription)")
            #endif
            return []
        }
    }

    // MARK: - Deletion

    /// Delete a cached conversation and all its cached messages (cascade)
    func deleteCachedConversation(id: UUID) {
        let context = activeContext
        do {
            // Delete messages first
            let messageDescriptor = FetchDescriptor<CachedMessage>()
            let allMessages = try context.fetch(messageDescriptor)
            let conversationMessages = allMessages.filter { $0.conversationId == id }
            for message in conversationMessages {
                context.delete(message)
            }

            // Delete conversation
            let convDescriptor = FetchDescriptor<CachedConversation>()
            let allConversations = try context.fetch(convDescriptor)
            let matching = allConversations.filter { $0.remoteId == id }
            for conversation in matching {
                context.delete(conversation)
            }

            try context.save()
        } catch {
            #if DEBUG
            print("OfflineCacheService: Failed to delete cached conversation: \(error.localizedDescription)")
            #endif
        }
    }

    /// Save any pending changes to the SwiftData context (Story 7.4)
    func saveContext() throws {
        try activeContext.save()
    }

    /// Clear all cached conversations and messages (for sign-out)
    func clearAllCachedData() {
        let context = activeContext
        do {
            let messageDescriptor = FetchDescriptor<CachedMessage>()
            let allMessages = try context.fetch(messageDescriptor)
            for message in allMessages {
                context.delete(message)
            }

            let convDescriptor = FetchDescriptor<CachedConversation>()
            let allConversations = try context.fetch(convDescriptor)
            for conversation in allConversations {
                context.delete(conversation)
            }

            try context.save()
        } catch {
            #if DEBUG
            print("OfflineCacheService: Failed to clear cached data: \(error.localizedDescription)")
            #endif
        }
    }
}
