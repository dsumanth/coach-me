//
//  CachedConversationTests.swift
//  CoachMeTests
//
//  Story 7.1: Offline Data Caching with SwiftData
//  Tests for CachedConversation model, conversions, and unique constraints
//

import XCTest
import SwiftData
@testable import CoachMe

@MainActor
final class CachedConversationTests: XCTestCase {

    private var modelContainer: ModelContainer!
    private var modelContext: ModelContext!

    override func setUp() async throws {
        try await super.setUp()
        let schema = Schema([CachedConversation.self])
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
        let userId = UUID()
        let now = Date()

        let cached = CachedConversation(
            remoteId: id,
            userId: userId,
            title: "Test Title",
            domain: "career",
            lastMessageAt: now,
            messageCount: 5,
            createdAt: now,
            updatedAt: now
        )

        XCTAssertEqual(cached.remoteId, id)
        XCTAssertEqual(cached.userId, userId)
        XCTAssertEqual(cached.title, "Test Title")
        XCTAssertEqual(cached.domain, "career")
        XCTAssertEqual(cached.lastMessageAt, now)
        XCTAssertEqual(cached.messageCount, 5)
        XCTAssertEqual(cached.createdAt, now)
        XCTAssertEqual(cached.updatedAt, now)
        XCTAssertNotNil(cached.cachedAt)
    }

    func testInit_handlesOptionalFields() {
        let cached = CachedConversation(
            remoteId: UUID(),
            userId: UUID(),
            title: nil,
            domain: nil,
            lastMessageAt: nil,
            messageCount: 0,
            createdAt: Date(),
            updatedAt: Date()
        )

        XCTAssertNil(cached.title)
        XCTAssertNil(cached.domain)
        XCTAssertNil(cached.lastMessageAt)
    }

    // MARK: - Conversion Tests

    func testInitFromConversation() {
        let id = UUID()
        let userId = UUID()
        let now = Date()

        let conversation = ConversationService.Conversation(
            id: id,
            userId: userId,
            title: "Coaching Session",
            domain: "relationships",
            lastMessageAt: now,
            messageCount: 12,
            createdAt: now,
            updatedAt: now
        )

        let cached = CachedConversation(from: conversation)

        XCTAssertEqual(cached.remoteId, id)
        XCTAssertEqual(cached.userId, userId)
        XCTAssertEqual(cached.title, "Coaching Session")
        XCTAssertEqual(cached.domain, "relationships")
        XCTAssertEqual(cached.messageCount, 12)
    }

    func testToConversation() {
        let id = UUID()
        let userId = UUID()
        let now = Date()

        let cached = CachedConversation(
            remoteId: id,
            userId: userId,
            title: "Round Trip",
            domain: "career",
            lastMessageAt: now,
            messageCount: 3,
            createdAt: now,
            updatedAt: now
        )

        let conversation = cached.toConversation()

        XCTAssertEqual(conversation.id, id)
        XCTAssertEqual(conversation.userId, userId)
        XCTAssertEqual(conversation.title, "Round Trip")
        XCTAssertEqual(conversation.domain, "career")
        XCTAssertEqual(conversation.messageCount, 3)
    }

    func testRoundTripConversion() {
        let original = ConversationService.Conversation(
            id: UUID(),
            userId: UUID(),
            title: "Original Title",
            domain: "health",
            lastMessageAt: Date(),
            messageCount: 7,
            createdAt: Date(),
            updatedAt: Date()
        )

        let cached = CachedConversation(from: original)
        let roundTripped = cached.toConversation()

        XCTAssertEqual(roundTripped.id, original.id)
        XCTAssertEqual(roundTripped.userId, original.userId)
        XCTAssertEqual(roundTripped.title, original.title)
        XCTAssertEqual(roundTripped.domain, original.domain)
        XCTAssertEqual(roundTripped.messageCount, original.messageCount)
    }

    // MARK: - Update Tests

    func testUpdate_updatesAllFields() {
        let id = UUID()
        let userId = UUID()

        let cached = CachedConversation(
            remoteId: id,
            userId: userId,
            title: "Old Title",
            domain: "career",
            messageCount: 1,
            createdAt: Date(),
            updatedAt: Date()
        )

        let originalCachedAt = cached.cachedAt
        Thread.sleep(forTimeInterval: 0.01)

        let updated = ConversationService.Conversation(
            id: id,
            userId: userId,
            title: "New Title",
            domain: "relationships",
            lastMessageAt: Date(),
            messageCount: 10,
            createdAt: Date(),
            updatedAt: Date()
        )

        cached.update(from: updated)

        XCTAssertEqual(cached.title, "New Title")
        XCTAssertEqual(cached.domain, "relationships")
        XCTAssertEqual(cached.messageCount, 10)
        XCTAssertTrue(cached.cachedAt > originalCachedAt)
    }

    // MARK: - SwiftData Persistence Tests

    func testSwiftDataPersistence() throws {
        let cached = CachedConversation(
            remoteId: UUID(),
            userId: UUID(),
            title: "Persisted",
            messageCount: 0,
            createdAt: Date(),
            updatedAt: Date()
        )

        modelContext.insert(cached)
        try modelContext.save()

        let descriptor = FetchDescriptor<CachedConversation>()
        let results = try modelContext.fetch(descriptor)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Persisted")
    }

    func testSwiftDataUniqueConstraintOnRemoteId() throws {
        let remoteId = UUID()
        let userId = UUID()

        let cached1 = CachedConversation(
            remoteId: remoteId,
            userId: userId,
            title: "First",
            messageCount: 0,
            createdAt: Date(),
            updatedAt: Date()
        )
        modelContext.insert(cached1)
        try modelContext.save()

        let cached2 = CachedConversation(
            remoteId: remoteId,
            userId: userId,
            title: "Second",
            messageCount: 0,
            createdAt: Date(),
            updatedAt: Date()
        )
        modelContext.insert(cached2)

        // SwiftData in-memory stores may upsert instead of throwing on unique constraint,
        // so we verify the constraint is enforced by checking only one record exists per remoteId
        do {
            try modelContext.save()
            // If save succeeds, SwiftData performed an upsert — verify only one record per remoteId
            let descriptor = FetchDescriptor<CachedConversation>()
            let results = try modelContext.fetch(descriptor)
            let matching = results.filter { $0.remoteId == remoteId }
            XCTAssertEqual(matching.count, 1, "Unique constraint should ensure one entry per remoteId")
        } catch {
            // Save threw — unique constraint violation was enforced at the store level
            XCTAssertTrue(
                "\(error)".lowercased().contains("unique") || "\(error)".lowercased().contains("constraint"),
                "Expected unique constraint error, got: \(error)"
            )
        }
    }

    func testSwiftDataDeletion() throws {
        let cached = CachedConversation(
            remoteId: UUID(),
            userId: UUID(),
            title: "To Delete",
            messageCount: 0,
            createdAt: Date(),
            updatedAt: Date()
        )

        modelContext.insert(cached)
        try modelContext.save()

        modelContext.delete(cached)
        try modelContext.save()

        let descriptor = FetchDescriptor<CachedConversation>()
        let results = try modelContext.fetch(descriptor)
        XCTAssertEqual(results.count, 0)
    }
}
