//
//  SyncConflictLoggerTests.swift
//  CoachMeTests
//
//  Story 7.4: Sync Conflict Resolution
//  Tests for SyncConflictLogger — verifies conflict logging with correct metadata
//

import XCTest
@testable import CoachMe

@MainActor
final class SyncConflictLoggerTests: XCTestCase {

    private var logger: SyncConflictLogger!

    override func setUp() async throws {
        try await super.setUp()
        // Use real Supabase client — fire-and-forget logging won't affect test results
        logger = SyncConflictLogger(supabase: AppEnvironment.shared.supabase)
    }

    override func tearDown() async throws {
        logger = nil
        try await super.tearDown()
    }

    // MARK: - Logger Initialization Tests

    func testLoggerInitializes() {
        XCTAssertNotNil(logger)
    }

    // MARK: - Conflict Logging Tests

    func testLogConflict_doesNotCrash_forConversation() {
        let recordId = UUID()
        let localTime = Date().addingTimeInterval(-3600)
        let remoteTime = Date()

        // Should not crash — fire-and-forget Supabase insert may fail silently
        logger.logConflict(
            type: "conversation",
            conflictType: "timestamp_mismatch",
            resolution: "server_wins",
            localTimestamp: localTime,
            remoteTimestamp: remoteTime,
            recordId: recordId
        )
    }

    func testLogConflict_doesNotCrash_forMessage() {
        logger.logConflict(
            type: "message",
            conflictType: "data_mismatch",
            resolution: "server_wins",
            localTimestamp: Date(),
            remoteTimestamp: Date(),
            recordId: UUID()
        )
    }

    func testLogConflict_doesNotCrash_forContextProfile() {
        logger.logConflict(
            type: "context_profile",
            conflictType: "timestamp_mismatch",
            resolution: "local_wins",
            localTimestamp: Date(),
            remoteTimestamp: Date().addingTimeInterval(-3600),
            recordId: UUID()
        )
    }

    func testLogConflict_doesNotCrash_forSkippedResolution() {
        logger.logConflict(
            type: "context_profile",
            conflictType: "timestamp_mismatch",
            resolution: "skipped",
            localTimestamp: Date(),
            remoteTimestamp: Date(),
            recordId: UUID()
        )
    }

    // MARK: - SyncConflictLogInsert Model Tests

    func testSyncConflictLogInsert_encoding() throws {
        let insert = SyncConflictLogInsert(
            userId: UUID(),
            recordType: "conversation",
            recordId: UUID(),
            conflictType: "timestamp_mismatch",
            resolution: "server_wins",
            localTimestamp: Date(),
            remoteTimestamp: Date()
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(insert)
        XCTAssertNotNil(data)

        // Verify snake_case keys
        let jsonString = String(data: data, encoding: .utf8)!
        XCTAssertTrue(jsonString.contains("user_id"))
        XCTAssertTrue(jsonString.contains("record_type"))
        XCTAssertTrue(jsonString.contains("record_id"))
        XCTAssertTrue(jsonString.contains("conflict_type"))
        XCTAssertTrue(jsonString.contains("local_timestamp"))
        XCTAssertTrue(jsonString.contains("remote_timestamp"))
    }

    func testSyncConflictLogInsert_encodingWithNilTimestamps() throws {
        let insert = SyncConflictLogInsert(
            userId: UUID(),
            recordType: "message",
            recordId: UUID(),
            conflictType: "missing_local",
            resolution: "server_wins",
            localTimestamp: nil,
            remoteTimestamp: nil
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(insert)
        XCTAssertNotNil(data)
    }
}
