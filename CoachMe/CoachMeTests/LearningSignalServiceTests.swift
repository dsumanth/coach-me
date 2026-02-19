//
//  LearningSignalServiceTests.swift
//  CoachMeTests
//
//  Story 8.1: Learning Signals Infrastructure
//  Tests for LearningSignal models, LearningSignalService aggregate computation,
//  CoachingPreferences, and ContextProfile backward compatibility
//

import XCTest
import Supabase
@testable import CoachMe

@MainActor
final class LearningSignalServiceTests: XCTestCase {

    // MARK: - Model Tests

    func testLearningSignalDecodesFromJSON() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "user_id": "22222222-2222-2222-2222-222222222222",
            "signal_type": "insight_confirmed",
            "signal_data": {"insight_id": "abc", "category": "values"},
            "created_at": "2026-02-10T12:00:00Z",
            "updated_at": "2026-02-10T12:00:00Z"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let signal = try decoder.decode(LearningSignal.self, from: json)

        XCTAssertEqual(signal.id, UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        XCTAssertEqual(signal.userId, UUID(uuidString: "22222222-2222-2222-2222-222222222222"))
        XCTAssertEqual(signal.signalType, "insight_confirmed")
        XCTAssertEqual(signal.signalData["category"], .string("values"))
        XCTAssertEqual(signal.signalData["insight_id"], .string("abc"))
        XCTAssertNotNil(signal.updatedAt)
    }

    func testLearningSignalInsertEncodesToJSON() throws {
        let userId = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let insert = LearningSignalInsert(
            userId: userId,
            signalType: "session_completed",
            signalData: [
                "conversation_id": .string("conv-1"),
                "message_count": .integer(10),
                "duration_seconds": .integer(300)
            ]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(insert)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(dict["user_id"] as? String, userId.uuidString)
        XCTAssertEqual(dict["signal_type"] as? String, "session_completed")
        XCTAssertNotNil(dict["signal_data"])
    }

    func testLearningSignalEquatable() {
        let id = UUID()
        let userId = UUID()
        let now = Date()

        let signal1 = LearningSignal(
            id: id, userId: userId, signalType: "insight_confirmed",
            signalData: ["category": .string("values")], createdAt: now, updatedAt: now
        )
        let signal2 = LearningSignal(
            id: id, userId: userId, signalType: "insight_confirmed",
            signalData: ["category": .string("values")], createdAt: now, updatedAt: now
        )

        XCTAssertEqual(signal1, signal2)
    }

    // MARK: - InsightFeedbackAction Tests

    func testInsightFeedbackActionRawValues() {
        XCTAssertEqual(InsightFeedbackAction.confirmed.rawValue, "insight_confirmed")
        XCTAssertEqual(InsightFeedbackAction.dismissed.rawValue, "insight_dismissed")
    }

    // MARK: - CoachingPreferences Tests

    func testCoachingPreferencesEmpty() {
        let prefs = CoachingPreferences.empty

        XCTAssertNil(prefs.preferredStyle)
        XCTAssertTrue(prefs.domainUsage.isEmpty)
        XCTAssertTrue(prefs.sessionPatterns.isEmpty)
        XCTAssertNil(prefs.lastReflectionAt)
    }

    func testCoachingPreferencesDecodesFromEmptyJSON() throws {
        let json = "{}".data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let prefs = try decoder.decode(CoachingPreferences.self, from: json)

        XCTAssertNil(prefs.preferredStyle)
        XCTAssertTrue(prefs.domainUsage.isEmpty)
        XCTAssertTrue(prefs.sessionPatterns.isEmpty)
        XCTAssertNil(prefs.lastReflectionAt)
    }

    func testCoachingPreferencesDecodesFullJSON() throws {
        let json = """
        {
            "preferred_style": "direct",
            "domain_usage": {"career": 5, "relationships": 3},
            "session_patterns": {"avg_time": "evening"},
            "last_reflection_at": "2026-02-10T12:00:00Z"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let prefs = try decoder.decode(CoachingPreferences.self, from: json)

        XCTAssertEqual(prefs.preferredStyle, "direct")
        XCTAssertEqual(prefs.domainUsage["career"], 5)
        XCTAssertEqual(prefs.domainUsage["relationships"], 3)
        XCTAssertEqual(prefs.sessionPatterns["avg_time"], "evening")
        XCTAssertNotNil(prefs.lastReflectionAt)
    }

    func testCoachingPreferencesEquatable() {
        let prefs1 = CoachingPreferences.empty
        let prefs2 = CoachingPreferences.empty

        XCTAssertEqual(prefs1, prefs2)
    }

    // MARK: - ContextProfile Backward Compatibility Tests

    func testContextProfileDecodesWithoutCoachingPreferences() throws {
        // Simulates loading a cached profile from before Story 8.1
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "user_id": "22222222-2222-2222-2222-222222222222",
            "values": [],
            "goals": [],
            "situation": {"freeform": null},
            "extracted_insights": [],
            "context_version": 1,
            "first_session_complete": false,
            "prompt_dismissed_count": 0,
            "created_at": "2026-02-10T12:00:00Z",
            "updated_at": "2026-02-10T12:00:00Z"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let profile = try decoder.decode(ContextProfile.self, from: json)

        // coachingPreferences should default to .empty when key is missing
        XCTAssertEqual(profile.coachingPreferences, CoachingPreferences.empty)
        XCTAssertEqual(profile.contextVersion, 1)
    }

    func testContextProfileDecodesWithCoachingPreferences() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "user_id": "22222222-2222-2222-2222-222222222222",
            "values": [],
            "goals": [],
            "situation": {"freeform": null},
            "extracted_insights": [],
            "context_version": 1,
            "first_session_complete": false,
            "prompt_dismissed_count": 0,
            "coaching_preferences": {"preferred_style": "socratic", "domain_usage": {}, "session_patterns": {}, "last_reflection_at": null},
            "created_at": "2026-02-10T12:00:00Z",
            "updated_at": "2026-02-10T12:00:00Z"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let profile = try decoder.decode(ContextProfile.self, from: json)

        XCTAssertEqual(profile.coachingPreferences.preferredStyle, "socratic")
    }

    func testContextProfileEmptyFactory() {
        let userId = UUID()
        let profile = ContextProfile.empty(userId: userId)

        XCTAssertEqual(profile.userId, userId)
        XCTAssertEqual(profile.coachingPreferences, CoachingPreferences.empty)
    }

    // MARK: - Aggregate Computation Tests

    func testAggregatesFromEmptySignals() {
        let aggregates = LearningSignalAggregates.compute(from: [])

        XCTAssertTrue(aggregates.domainPreferences.isEmpty)
        XCTAssertEqual(aggregates.sessionCount, 0)
        XCTAssertEqual(aggregates.averageSessionDurationSeconds, 0)
        XCTAssertEqual(aggregates.averageMessagesPerSession, 0)
        XCTAssertEqual(aggregates.insightsConfirmed, 0)
        XCTAssertEqual(aggregates.insightsDismissed, 0)
    }

    func testAggregatesFromSessionSignals() {
        let userId = UUID()
        let now = Date()

        let signals = [
            LearningSignal(
                id: UUID(), userId: userId, signalType: "session_completed",
                signalData: [
                    "conversation_id": .string(UUID().uuidString),
                    "message_count": .integer(10),
                    "duration_seconds": .integer(600),
                    "domain": .string("career")
                ],
                createdAt: now, updatedAt: now
            ),
            LearningSignal(
                id: UUID(), userId: userId, signalType: "session_completed",
                signalData: [
                    "conversation_id": .string(UUID().uuidString),
                    "message_count": .integer(6),
                    "duration_seconds": .integer(300),
                    "domain": .string("career")
                ],
                createdAt: now, updatedAt: now
            ),
            LearningSignal(
                id: UUID(), userId: userId, signalType: "session_completed",
                signalData: [
                    "conversation_id": .string(UUID().uuidString),
                    "message_count": .integer(4),
                    "duration_seconds": .integer(200),
                    "domain": .string("relationships")
                ],
                createdAt: now, updatedAt: now
            )
        ]

        let aggregates = LearningSignalAggregates.compute(from: signals)

        XCTAssertEqual(aggregates.sessionCount, 3)
        XCTAssertEqual(aggregates.domainPreferences["career"], 2)
        XCTAssertEqual(aggregates.domainPreferences["relationships"], 1)
        // Average: (600 + 300 + 200) / 3 = 366 (integer division)
        XCTAssertEqual(aggregates.averageSessionDurationSeconds, 366)
        // Average messages: (10 + 6 + 4) / 3 = 6 (integer division)
        XCTAssertEqual(aggregates.averageMessagesPerSession, 6)
    }

    func testAggregatesFromInsightSignals() {
        let userId = UUID()
        let now = Date()

        let signals = [
            LearningSignal(
                id: UUID(), userId: userId, signalType: "insight_confirmed",
                signalData: ["insight_id": .string(UUID().uuidString), "category": .string("values")],
                createdAt: now, updatedAt: now
            ),
            LearningSignal(
                id: UUID(), userId: userId, signalType: "insight_confirmed",
                signalData: ["insight_id": .string(UUID().uuidString), "category": .string("goals")],
                createdAt: now, updatedAt: now
            ),
            LearningSignal(
                id: UUID(), userId: userId, signalType: "insight_dismissed",
                signalData: ["insight_id": .string(UUID().uuidString), "category": .string("situation")],
                createdAt: now, updatedAt: now
            )
        ]

        let aggregates = LearningSignalAggregates.compute(from: signals)

        XCTAssertEqual(aggregates.insightsConfirmed, 2)
        XCTAssertEqual(aggregates.insightsDismissed, 1)
    }

    func testAggregatesFromMixedSignals() {
        let userId = UUID()
        let now = Date()

        let signals = [
            LearningSignal(
                id: UUID(), userId: userId, signalType: "session_completed",
                signalData: [
                    "message_count": .integer(8),
                    "duration_seconds": .integer(400),
                    "domain": .string("career")
                ],
                createdAt: now, updatedAt: now
            ),
            LearningSignal(
                id: UUID(), userId: userId, signalType: "insight_confirmed",
                signalData: ["insight_id": .string(UUID().uuidString), "category": .string("values")],
                createdAt: now, updatedAt: now
            ),
            LearningSignal(
                id: UUID(), userId: userId, signalType: "insight_dismissed",
                signalData: ["insight_id": .string(UUID().uuidString), "category": .string("goals")],
                createdAt: now, updatedAt: now
            )
        ]

        let aggregates = LearningSignalAggregates.compute(from: signals)

        XCTAssertEqual(aggregates.sessionCount, 1)
        XCTAssertEqual(aggregates.domainPreferences["career"], 1)
        XCTAssertEqual(aggregates.averageSessionDurationSeconds, 400)
        XCTAssertEqual(aggregates.averageMessagesPerSession, 8)
        XCTAssertEqual(aggregates.insightsConfirmed, 1)
        XCTAssertEqual(aggregates.insightsDismissed, 1)
    }

    // MARK: - LearningSignalError Tests

    func testLearningSignalErrorDescriptions() {
        XCTAssertEqual(
            LearningSignalError.notAuthenticated.errorDescription,
            "I need you to sign in before I can track your progress."
        )
        XCTAssertEqual(
            LearningSignalError.recordFailed("timeout").errorDescription,
            "I couldn't save that learning signal. timeout"
        )
        XCTAssertEqual(
            LearningSignalError.fetchFailed("network").errorDescription,
            "I couldn't load your learning data. network"
        )
    }

    func testLearningSignalErrorEquatable() {
        XCTAssertEqual(LearningSignalError.notAuthenticated, LearningSignalError.notAuthenticated)
        XCTAssertEqual(LearningSignalError.recordFailed("a"), LearningSignalError.recordFailed("a"))
        XCTAssertNotEqual(LearningSignalError.recordFailed("a"), LearningSignalError.recordFailed("b"))
        XCTAssertNotEqual(LearningSignalError.notAuthenticated, LearningSignalError.recordFailed("a"))
    }

    // MARK: - Non-Blocking Pattern Tests

    func testSignalRecordingFailureDoesNotThrowInFireAndForget() async {
        // Verify the non-blocking pattern: Task { try? await ... } swallows errors
        // This simulates what happens in ContextRepository when signal recording fails
        let expectation = XCTestExpectation(description: "Fire-and-forget completes without crash")

        Task {
            // This mirrors the pattern used in ContextRepository.confirmInsight
            // try? swallows any error — the app should never crash
            try? await {
                throw LearningSignalError.recordFailed("simulated failure")
            }()
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 2.0)
    }

    func testLearningSignalAggregatesEquatable() {
        let agg1 = LearningSignalAggregates(
            domainPreferences: ["career": 5],
            sessionCount: 3,
            averageSessionDurationSeconds: 300,
            averageMessagesPerSession: 8,
            insightsConfirmed: 2,
            insightsDismissed: 1
        )
        let agg2 = LearningSignalAggregates(
            domainPreferences: ["career": 5],
            sessionCount: 3,
            averageSessionDurationSeconds: 300,
            averageMessagesPerSession: 8,
            insightsConfirmed: 2,
            insightsDismissed: 1
        )

        XCTAssertEqual(agg1, agg2)
    }

}
