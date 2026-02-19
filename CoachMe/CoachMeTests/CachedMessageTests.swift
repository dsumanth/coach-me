//
//  CachedMessageTests.swift
//  CoachMeTests
//
//  Story 7.1: Offline Data Caching with SwiftData
//  Tests for CachedMessage model, conversions, and ordering
//

import XCTest
import SwiftData
@testable import CoachMe

@MainActor
final class CachedMessageTests: XCTestCase {

    private var modelContainer: ModelContainer!
    private var modelContext: ModelContext!

    override func setUp() async throws {
        try await super.setUp()
        let schema = Schema([CachedMessage.self])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        modelContext = modelContainer.mainContext
    }

    override func tearDown() async throws {
        modelContainer = nil
        modelContext = nil
        try await super.tearDown()
    }

    // MARK: - Model Creation Tests

    func testInit_setsAllProperties() {
        let id = UUID()
        let convId = UUID()
        let now = Date()

        let cached = CachedMessage(
            remoteId: id,
            conversationId: convId,
            role: "user",
            content: "Hello coach",
            createdAt: now
        )

        XCTAssertEqual(cached.remoteId, id)
        XCTAssertEqual(cached.conversationId, convId)
        XCTAssertEqual(cached.role, "user")
        XCTAssertEqual(cached.content, "Hello coach")
        XCTAssertEqual(cached.createdAt, now)
        XCTAssertNotNil(cached.cachedAt)
    }

    // MARK: - Conversion Tests

    func testInitFromChatMessage_userRole() {
        let message = ChatMessage.userMessage(
            content: "Help me with my career",
            conversationId: UUID()
        )

        let cached = CachedMessage(from: message)

        XCTAssertEqual(cached.remoteId, message.id)
        XCTAssertEqual(cached.conversationId, message.conversationId)
        XCTAssertEqual(cached.role, "user")
        XCTAssertEqual(cached.content, "Help me with my career")
    }

    func testInitFromChatMessage_assistantRole() {
        let message = ChatMessage.assistantMessage(
            content: "I'd be happy to help with your career goals.",
            conversationId: UUID()
        )

        let cached = CachedMessage(from: message)

        XCTAssertEqual(cached.role, "assistant")
        XCTAssertEqual(cached.content, "I'd be happy to help with your career goals.")
    }

    func testToChatMessage_userRole() {
        let convId = UUID()
        let cached = CachedMessage(
            remoteId: UUID(),
            conversationId: convId,
            role: "user",
            content: "Test content",
            createdAt: Date()
        )

        let message = cached.toChatMessage()

        XCTAssertEqual(message.id, cached.remoteId)
        XCTAssertEqual(message.conversationId, convId)
        XCTAssertEqual(message.role, .user)
        XCTAssertEqual(message.content, "Test content")
    }

    func testToChatMessage_assistantRole() {
        let cached = CachedMessage(
            remoteId: UUID(),
            conversationId: UUID(),
            role: "assistant",
            content: "Response",
            createdAt: Date()
        )

        let message = cached.toChatMessage()
        XCTAssertEqual(message.role, .assistant)
    }

    func testToChatMessage_unknownRoleDefaultsToAssistant() {
        let cached = CachedMessage(
            remoteId: UUID(),
            conversationId: UUID(),
            role: "system",
            content: "Unknown role",
            createdAt: Date()
        )

        let message = cached.toChatMessage()
        XCTAssertEqual(message.role, .assistant, "Unknown role should default to assistant")
    }

    func testRoundTripConversion() {
        let original = ChatMessage(
            id: UUID(),
            conversationId: UUID(),
            role: .user,
            content: "Round trip test",
            createdAt: Date()
        )

        let cached = CachedMessage(from: original)
        let roundTripped = cached.toChatMessage()

        XCTAssertEqual(roundTripped.id, original.id)
        XCTAssertEqual(roundTripped.conversationId, original.conversationId)
        XCTAssertEqual(roundTripped.role, original.role)
        XCTAssertEqual(roundTripped.content, original.content)
    }

    // MARK: - Update Tests

    func testUpdate_updatesAllFields() {
        let cached = CachedMessage(
            remoteId: UUID(),
            conversationId: UUID(),
            role: "user",
            content: "Original",
            createdAt: Date()
        )

        let originalCachedAt = cached.cachedAt
        Thread.sleep(forTimeInterval: 0.01)

        let newConvId = UUID()
        let updated = ChatMessage(
            id: cached.remoteId,
            conversationId: newConvId,
            role: .assistant,
            content: "Updated content",
            createdAt: Date()
        )

        cached.update(from: updated)

        XCTAssertEqual(cached.conversationId, newConvId)
        XCTAssertEqual(cached.role, "assistant")
        XCTAssertEqual(cached.content, "Updated content")
        XCTAssertTrue(cached.cachedAt > originalCachedAt)
    }

    // MARK: - SwiftData Persistence Tests

    func testSwiftDataPersistence() throws {
        let cached = CachedMessage(
            remoteId: UUID(),
            conversationId: UUID(),
            role: "user",
            content: "Persisted message",
            createdAt: Date()
        )

        modelContext.insert(cached)
        try modelContext.save()

        let descriptor = FetchDescriptor<CachedMessage>()
        let results = try modelContext.fetch(descriptor)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.content, "Persisted message")
    }

    func testSwiftDataUniqueConstraintOnRemoteId() throws {
        let remoteId = UUID()
        let convId = UUID()

        let cached1 = CachedMessage(
            remoteId: remoteId,
            conversationId: convId,
            role: "user",
            content: "First",
            createdAt: Date()
        )
        modelContext.insert(cached1)
        try modelContext.save()

        let cached2 = CachedMessage(
            remoteId: remoteId,
            conversationId: convId,
            role: "user",
            content: "Second",
            createdAt: Date()
        )
        modelContext.insert(cached2)
        try modelContext.save()

        let descriptor = FetchDescriptor<CachedMessage>()
        let results = try modelContext.fetch(descriptor)
        let matching = results.filter { $0.remoteId == remoteId }

        XCTAssertEqual(matching.count, 1, "Unique constraint should ensure one entry per remoteId")
    }

    func testSwiftDataDeletion() throws {
        let cached = CachedMessage(
            remoteId: UUID(),
            conversationId: UUID(),
            role: "assistant",
            content: "To Delete",
            createdAt: Date()
        )

        modelContext.insert(cached)
        try modelContext.save()

        modelContext.delete(cached)
        try modelContext.save()

        let descriptor = FetchDescriptor<CachedMessage>()
        let results = try modelContext.fetch(descriptor)
        XCTAssertEqual(results.count, 0)
    }

    // MARK: - Ordering Tests

    func testMessages_sortByCreatedAt() throws {
        let convId = UUID()
        let earlier = CachedMessage(
            remoteId: UUID(),
            conversationId: convId,
            role: "user",
            content: "First",
            createdAt: Date().addingTimeInterval(-120)
        )
        let middle = CachedMessage(
            remoteId: UUID(),
            conversationId: convId,
            role: "assistant",
            content: "Second",
            createdAt: Date().addingTimeInterval(-60)
        )
        let latest = CachedMessage(
            remoteId: UUID(),
            conversationId: convId,
            role: "user",
            content: "Third",
            createdAt: Date()
        )

        modelContext.insert(latest)
        modelContext.insert(earlier)
        modelContext.insert(middle)
        try modelContext.save()

        let descriptor = FetchDescriptor<CachedMessage>()
        let all = try modelContext.fetch(descriptor)
        let sorted = all
            .filter { $0.conversationId == convId }
            .sorted { $0.createdAt < $1.createdAt }

        XCTAssertEqual(sorted[0].content, "First")
        XCTAssertEqual(sorted[1].content, "Second")
        XCTAssertEqual(sorted[2].content, "Third")
    }
}
