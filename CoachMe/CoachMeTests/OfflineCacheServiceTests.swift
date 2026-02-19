//
//  OfflineCacheServiceTests.swift
//  CoachMeTests
//
//  Story 7.1: Offline Data Caching with SwiftData
//  Tests for OfflineCacheService CRUD, bulk operations, cascade delete, and clear all
//

import XCTest
import SwiftData
@testable import CoachMe

@MainActor
final class OfflineCacheServiceTests: XCTestCase {

    private var modelContainer: ModelContainer!
    private var modelContext: ModelContext!
    private var service: OfflineCacheService!

    override func setUp() async throws {
        try await super.setUp()
        let schema = Schema([
            CachedConversation.self,
            CachedMessage.self
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        modelContext = modelContainer.mainContext
        service = OfflineCacheService(modelContext: modelContext)
    }

    override func tearDown() async throws {
        service = nil
        modelContainer = nil
        modelContext = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func makeConversation(
        id: UUID = UUID(),
        userId: UUID = UUID(),
        title: String? = "Test Conversation",
        messageCount: Int = 5
    ) -> ConversationService.Conversation {
        ConversationService.Conversation(
            id: id,
            userId: userId,
            title: title,
            domain: "career",
            lastMessageAt: Date(),
            messageCount: messageCount,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    private func makeMessage(
        id: UUID = UUID(),
        conversationId: UUID,
        role: ChatMessage.Role = .user,
        content: String = "Test message"
    ) -> ChatMessage {
        ChatMessage(
            id: id,
            conversationId: conversationId,
            role: role,
            content: content,
            createdAt: Date()
        )
    }

    // MARK: - Conversation Caching Tests

    func testCacheConversations_insertsNewConversations() {
        let conversations = [
            makeConversation(),
            makeConversation(),
            makeConversation()
        ]

        service.cacheConversations(conversations)

        let cached = service.getCachedConversations()
        XCTAssertEqual(cached.count, 3)
    }

    func testCacheConversations_updatesExistingConversation() {
        let id = UUID()
        let userId = UUID()
        let conv1 = makeConversation(id: id, userId: userId, title: "Original", messageCount: 1)
        service.cacheConversations([conv1])

        let conv2 = makeConversation(id: id, userId: userId, title: "Updated", messageCount: 10)
        service.cacheConversations([conv2])

        let cached = service.getCachedConversations()
        XCTAssertEqual(cached.count, 1)
        XCTAssertEqual(cached.first?.title, "Updated")
        XCTAssertEqual(cached.first?.messageCount, 10)
    }

    func testCacheConversations_bulkUpsertMixed() {
        let existingId = UUID()
        let userId = UUID()
        let existing = makeConversation(id: existingId, userId: userId, title: "Existing")
        service.cacheConversations([existing])

        let updated = makeConversation(id: existingId, userId: userId, title: "Updated Existing")
        let brand_new = makeConversation(title: "Brand New")
        service.cacheConversations([updated, brand_new])

        let cached = service.getCachedConversations()
        XCTAssertEqual(cached.count, 2)
        let titles = Set(cached.map { $0.title })
        XCTAssertTrue(titles.contains("Updated Existing"))
        XCTAssertTrue(titles.contains("Brand New"))
    }

    func testGetCachedConversations_sortedByLastMessageAtDescending() {
        let userId = UUID()
        let old = ConversationService.Conversation(
            id: UUID(), userId: userId, title: "Old",
            lastMessageAt: Date().addingTimeInterval(-3600),
            messageCount: 1, createdAt: Date(), updatedAt: Date()
        )
        let recent = ConversationService.Conversation(
            id: UUID(), userId: userId, title: "Recent",
            lastMessageAt: Date(),
            messageCount: 1, createdAt: Date(), updatedAt: Date()
        )
        service.cacheConversations([old, recent])

        let cached = service.getCachedConversations()
        XCTAssertEqual(cached.first?.title, "Recent")
        XCTAssertEqual(cached.last?.title, "Old")
    }

    // MARK: - Message Caching Tests

    func testCacheMessages_insertsNewMessages() {
        let convId = UUID()
        let messages = [
            makeMessage(conversationId: convId, role: .user, content: "Hello"),
            makeMessage(conversationId: convId, role: .assistant, content: "Hi there")
        ]

        service.cacheMessages(messages, forConversation: convId)

        let cached = service.getCachedMessages(conversationId: convId)
        XCTAssertEqual(cached.count, 2)
    }

    func testCacheMessages_updatesExistingMessage() {
        let convId = UUID()
        let msgId = UUID()
        let msg1 = ChatMessage(id: msgId, conversationId: convId, role: .user, content: "Draft", createdAt: Date())
        service.cacheMessages([msg1], forConversation: convId)

        let msg2 = ChatMessage(id: msgId, conversationId: convId, role: .user, content: "Final version", createdAt: Date())
        service.cacheMessages([msg2], forConversation: convId)

        let cached = service.getCachedMessages(conversationId: convId)
        XCTAssertEqual(cached.count, 1)
        XCTAssertEqual(cached.first?.content, "Final version")
    }

    func testGetCachedMessages_sortedByCreatedAtAscending() {
        let convId = UUID()
        let older = ChatMessage(
            id: UUID(), conversationId: convId, role: .user,
            content: "First", createdAt: Date().addingTimeInterval(-60)
        )
        let newer = ChatMessage(
            id: UUID(), conversationId: convId, role: .assistant,
            content: "Second", createdAt: Date()
        )
        service.cacheMessages([newer, older], forConversation: convId)

        let cached = service.getCachedMessages(conversationId: convId)
        XCTAssertEqual(cached.first?.content, "First")
        XCTAssertEqual(cached.last?.content, "Second")
    }

    func testGetCachedMessages_filtersToConversation() {
        let convA = UUID()
        let convB = UUID()
        service.cacheMessages([makeMessage(conversationId: convA, content: "A msg")], forConversation: convA)
        service.cacheMessages([makeMessage(conversationId: convB, content: "B msg")], forConversation: convB)

        let cachedA = service.getCachedMessages(conversationId: convA)
        XCTAssertEqual(cachedA.count, 1)
        XCTAssertEqual(cachedA.first?.content, "A msg")

        let cachedB = service.getCachedMessages(conversationId: convB)
        XCTAssertEqual(cachedB.count, 1)
        XCTAssertEqual(cachedB.first?.content, "B msg")
    }

    // MARK: - Cascade Delete Tests

    func testDeleteCachedConversation_cascadeDeletesMessages() {
        let convId = UUID()
        service.cacheConversations([makeConversation(id: convId)])
        service.cacheMessages([
            makeMessage(conversationId: convId, content: "msg1"),
            makeMessage(conversationId: convId, content: "msg2")
        ], forConversation: convId)

        service.deleteCachedConversation(id: convId)

        XCTAssertEqual(service.getCachedConversations().count, 0)
        XCTAssertEqual(service.getCachedMessages(conversationId: convId).count, 0)
    }

    func testDeleteCachedConversation_doesNotAffectOtherConversations() {
        let convA = UUID()
        let convB = UUID()
        service.cacheConversations([makeConversation(id: convA), makeConversation(id: convB)])
        service.cacheMessages([makeMessage(conversationId: convA)], forConversation: convA)
        service.cacheMessages([makeMessage(conversationId: convB)], forConversation: convB)

        service.deleteCachedConversation(id: convA)

        XCTAssertEqual(service.getCachedConversations().count, 1)
        XCTAssertEqual(service.getCachedConversations().first?.remoteId, convB)
        XCTAssertEqual(service.getCachedMessages(conversationId: convB).count, 1)
    }

    // MARK: - Clear All Tests

    func testClearAllCachedData_removesEverything() {
        let convA = UUID()
        let convB = UUID()
        service.cacheConversations([makeConversation(id: convA), makeConversation(id: convB)])
        service.cacheMessages([makeMessage(conversationId: convA)], forConversation: convA)
        service.cacheMessages([makeMessage(conversationId: convB)], forConversation: convB)

        service.clearAllCachedData()

        XCTAssertEqual(service.getCachedConversations().count, 0)
        XCTAssertEqual(service.getCachedMessages(conversationId: convA).count, 0)
        XCTAssertEqual(service.getCachedMessages(conversationId: convB).count, 0)
    }

    func testClearAllCachedData_onEmptyStore() {
        // Should not crash on empty store
        service.clearAllCachedData()

        XCTAssertEqual(service.getCachedConversations().count, 0)
    }

    // MARK: - Edge Cases

    func testCacheEmptyConversationsList() {
        service.cacheConversations([])
        XCTAssertEqual(service.getCachedConversations().count, 0)
    }

    func testCacheEmptyMessagesList() {
        let convId = UUID()
        service.cacheMessages([], forConversation: convId)
        XCTAssertEqual(service.getCachedMessages(conversationId: convId).count, 0)
    }

    func testGetCachedMessages_nonexistentConversation() {
        let cached = service.getCachedMessages(conversationId: UUID())
        XCTAssertEqual(cached.count, 0)
    }

    func testDeleteNonexistentConversation() {
        // Should not crash
        service.deleteCachedConversation(id: UUID())
        XCTAssertEqual(service.getCachedConversations().count, 0)
    }
}
