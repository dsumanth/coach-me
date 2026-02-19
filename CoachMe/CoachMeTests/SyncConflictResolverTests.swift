//
//  SyncConflictResolverTests.swift
//  CoachMeTests
//
//  Story 7.4: Sync Conflict Resolution
//  Tests for SyncConflictResolver — server-wins for conversations/messages,
//  timestamp-wins for context profiles, and error handling
//

import XCTest
import SwiftData
@testable import CoachMe

@MainActor
final class SyncConflictResolverTests: XCTestCase {

    private var modelContainer: ModelContainer!
    private var modelContext: ModelContext!
    private var logger: SyncConflictLogger!
    private var resolver: SyncConflictResolver!

    override func setUp() async throws {
        try await super.setUp()
        let schema = Schema([
            CachedConversation.self,
            CachedMessage.self,
            CachedContextProfile.self
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        modelContext = modelContainer.mainContext
        logger = SyncConflictLogger(supabase: AppEnvironment.shared.supabase)
        resolver = SyncConflictResolver(logger: logger)
    }

    override func tearDown() async throws {
        resolver = nil
        logger = nil
        modelContainer = nil
        modelContext = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    private let testUserId = UUID()

    private func makeCachedConversation(
        remoteId: UUID = UUID(),
        updatedAt: Date = Date()
    ) -> CachedConversation {
        let cached = CachedConversation(
            remoteId: remoteId,
            userId: testUserId,
            title: "Test Conversation",
            domain: "career",
            lastMessageAt: Date(),
            messageCount: 5,
            createdAt: Date(),
            updatedAt: updatedAt
        )
        modelContext.insert(cached)
        try? modelContext.save()
        return cached
    }

    private func makeRemoteConversation(
        id: UUID = UUID(),
        updatedAt: Date = Date()
    ) -> ConversationService.Conversation {
        ConversationService.Conversation(
            id: id,
            userId: testUserId,
            title: "Test Conversation",
            domain: "career",
            lastMessageAt: Date(),
            messageCount: 5,
            createdAt: Date(),
            updatedAt: updatedAt
        )
    }

    private func makeCachedMessage(
        remoteId: UUID = UUID(),
        conversationId: UUID = UUID(),
        content: String = "Hello",
        createdAt: Date = Date()
    ) -> CachedMessage {
        let cached = CachedMessage(
            remoteId: remoteId,
            conversationId: conversationId,
            role: "user",
            content: content,
            createdAt: createdAt
        )
        modelContext.insert(cached)
        try? modelContext.save()
        return cached
    }

    private func makeRemoteMessage(
        id: UUID = UUID(),
        conversationId: UUID = UUID(),
        content: String = "Hello",
        createdAt: Date = Date()
    ) -> ChatMessage {
        ChatMessage(
            id: id,
            conversationId: conversationId,
            role: .user,
            content: content,
            createdAt: createdAt
        )
    }

    private func makeCachedContextProfile(
        userId: UUID? = nil,
        localUpdatedAt: Date? = nil,
        syncStatus: String = "synced"
    ) -> CachedContextProfile {
        let uid = userId ?? testUserId
        let profile = ContextProfile.empty(userId: uid)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try! encoder.encode(profile)
        let cached = CachedContextProfile(
            userId: uid,
            profileData: data,
            lastSyncedAt: Date(),
            localUpdatedAt: localUpdatedAt,
            syncStatus: syncStatus
        )
        modelContext.insert(cached)
        try? modelContext.save()
        return cached
    }

    private func makeRemoteContextProfile(
        userId: UUID? = nil,
        updatedAt: Date = Date()
    ) -> ContextProfile {
        let uid = userId ?? testUserId
        return ContextProfile(
            id: UUID(),
            userId: uid,
            values: [],
            goals: [],
            situation: .empty,
            extractedInsights: [],
            contextVersion: 1,
            firstSessionComplete: false,
            promptDismissedCount: 0,
            createdAt: Date(),
            updatedAt: updatedAt
        )
    }

    // MARK: - Conversation Conflict Tests

    func testConversation_serverWins_whenTimestampsDiffer() {
        let convId = UUID()
        let localTime = Date().addingTimeInterval(-3600)
        let remoteTime = Date()

        let local = makeCachedConversation(remoteId: convId, updatedAt: localTime)
        let remote = makeRemoteConversation(id: convId, updatedAt: remoteTime)

        let result = resolver.resolveConversationConflict(local: local, remote: remote)

        if case .serverWins = result.resolution {
            // Expected
        } else {
            XCTFail("Expected serverWins, got \(result.resolution)")
        }
        XCTAssertEqual(result.recordType, "conversation")
        XCTAssertEqual(result.recordId, convId)
    }

    func testConversation_noConflict_whenTimestampsMatch() {
        let convId = UUID()
        let sameTime = Date()

        let local = makeCachedConversation(remoteId: convId, updatedAt: sameTime)
        let remote = makeRemoteConversation(id: convId, updatedAt: sameTime)

        let result = resolver.resolveConversationConflict(local: local, remote: remote)

        if case .noConflict = result.resolution {
            // Expected
        } else {
            XCTFail("Expected noConflict, got \(result.resolution)")
        }
    }

    func testConversation_serverWins_evenWhenLocalIsNewer() {
        let convId = UUID()
        let local = makeCachedConversation(remoteId: convId, updatedAt: Date())
        let remote = makeRemoteConversation(id: convId, updatedAt: Date().addingTimeInterval(-3600))

        let result = resolver.resolveConversationConflict(local: local, remote: remote)

        // Server always wins for conversations, regardless of which is newer
        if case .serverWins = result.resolution {
            // Expected
        } else {
            XCTFail("Expected serverWins, got \(result.resolution)")
        }
    }

    // MARK: - Message Conflict Tests

    func testMessage_serverWins_whenContentDiffers() {
        let msgId = UUID()
        let convId = UUID()
        let sameTime = Date()

        let local = makeCachedMessage(remoteId: msgId, conversationId: convId, content: "Old content", createdAt: sameTime)
        let remote = makeRemoteMessage(id: msgId, conversationId: convId, content: "New content", createdAt: sameTime)

        let result = resolver.resolveMessageConflict(local: local, remote: remote)

        if case .serverWins = result.resolution {
            // Expected
        } else {
            XCTFail("Expected serverWins, got \(result.resolution)")
        }
        XCTAssertEqual(result.recordType, "message")
    }

    func testMessage_noConflict_whenIdentical() {
        let msgId = UUID()
        let convId = UUID()
        let sameTime = Date()
        let content = "Same content"

        let local = makeCachedMessage(remoteId: msgId, conversationId: convId, content: content, createdAt: sameTime)
        let remote = makeRemoteMessage(id: msgId, conversationId: convId, content: content, createdAt: sameTime)

        let result = resolver.resolveMessageConflict(local: local, remote: remote)

        if case .noConflict = result.resolution {
            // Expected
        } else {
            XCTFail("Expected noConflict, got \(result.resolution)")
        }
    }

    func testMessage_serverWins_whenTimestampsDiffer() {
        let msgId = UUID()
        let convId = UUID()

        let local = makeCachedMessage(remoteId: msgId, conversationId: convId, createdAt: Date().addingTimeInterval(-60))
        let remote = makeRemoteMessage(id: msgId, conversationId: convId, createdAt: Date())

        let result = resolver.resolveMessageConflict(local: local, remote: remote)

        if case .serverWins = result.resolution {
            // Expected
        } else {
            XCTFail("Expected serverWins, got \(result.resolution)")
        }
    }

    // MARK: - Context Profile Conflict Tests

    func testContextProfile_serverWins_whenNoLocalEdits() {
        let local = makeCachedContextProfile(localUpdatedAt: nil)
        let remote = makeRemoteContextProfile()

        let result = resolver.resolveContextProfileConflict(local: local, remote: remote)

        if case .serverWins = result.resolution {
            // Expected — no localUpdatedAt means server wins by default
        } else {
            XCTFail("Expected serverWins, got \(result.resolution)")
        }
        XCTAssertEqual(result.recordType, "context_profile")
    }

    func testContextProfile_localWins_whenLocalIsNewer() {
        let remoteTime = Date().addingTimeInterval(-3600)
        let localTime = Date()

        let local = makeCachedContextProfile(localUpdatedAt: localTime)
        let remote = makeRemoteContextProfile(updatedAt: remoteTime)

        let result = resolver.resolveContextProfileConflict(local: local, remote: remote)

        if case .localWins = result.resolution {
            // Expected
        } else {
            XCTFail("Expected localWins, got \(result.resolution)")
        }
    }

    func testContextProfile_serverWins_whenRemoteIsNewer() {
        let localTime = Date().addingTimeInterval(-3600)
        let remoteTime = Date()

        let local = makeCachedContextProfile(localUpdatedAt: localTime)
        let remote = makeRemoteContextProfile(updatedAt: remoteTime)

        let result = resolver.resolveContextProfileConflict(local: local, remote: remote)

        if case .serverWins = result.resolution {
            // Expected
        } else {
            XCTFail("Expected serverWins, got \(result.resolution)")
        }
    }

    func testContextProfile_noConflict_whenTimestampsEqual() {
        let sameTime = Date()

        let local = makeCachedContextProfile(localUpdatedAt: sameTime)
        let remote = makeRemoteContextProfile(updatedAt: sameTime)

        let result = resolver.resolveContextProfileConflict(local: local, remote: remote)

        if case .noConflict = result.resolution {
            // Expected
        } else {
            XCTFail("Expected noConflict, got \(result.resolution)")
        }
    }

    // MARK: - Resolution Result Tests

    func testResolutionResult_containsCorrectRecordType() {
        let convId = UUID()
        let local = makeCachedConversation(remoteId: convId)
        let remote = makeRemoteConversation(id: convId, updatedAt: Date().addingTimeInterval(60))

        let result = resolver.resolveConversationConflict(local: local, remote: remote)
        XCTAssertEqual(result.recordType, "conversation")
        XCTAssertEqual(result.recordId, convId)
    }

    func testResolutionResult_contextProfile_containsRemoteId() {
        let remote = makeRemoteContextProfile()
        let local = makeCachedContextProfile(localUpdatedAt: Date())

        let result = resolver.resolveContextProfileConflict(local: local, remote: remote)
        XCTAssertEqual(result.recordType, "context_profile")
        XCTAssertEqual(result.recordId, remote.id)
    }

    // MARK: - Independent Resolution Tests (AC #5)

    func testMultipleConflicts_resolvedIndependently() {
        let conv1Id = UUID()
        let conv2Id = UUID()

        let local1 = makeCachedConversation(remoteId: conv1Id, updatedAt: Date().addingTimeInterval(-60))
        let remote1 = makeRemoteConversation(id: conv1Id, updatedAt: Date())

        let local2 = makeCachedConversation(remoteId: conv2Id, updatedAt: Date())
        let remote2 = makeRemoteConversation(id: conv2Id, updatedAt: Date())

        let result1 = resolver.resolveConversationConflict(local: local1, remote: remote1)
        let result2 = resolver.resolveConversationConflict(local: local2, remote: remote2)

        // First has conflict (timestamps differ)
        if case .serverWins = result1.resolution {
            // Expected
        } else {
            XCTFail("Expected serverWins for result1")
        }

        // Second has no conflict (timestamps match)
        if case .noConflict = result2.resolution {
            // Expected
        } else {
            XCTFail("Expected noConflict for result2")
        }
    }
}
