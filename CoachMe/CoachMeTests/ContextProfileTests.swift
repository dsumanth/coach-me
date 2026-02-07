//
//  ContextProfileTests.swift
//  CoachMeTests
//
//  Story 2.1: Context Profile Data Model & Storage
//  Tests for ContextProfile, related models, and caching functionality
//

import XCTest
@testable import CoachMe

@MainActor
final class ContextProfileTests: XCTestCase {

    // MARK: - Test 6.1: ContextProfile Encoding/Decoding with CodingKeys

    func testContextProfileEncoding() throws {
        let userId = UUID()
        let profileId = UUID()
        let now = Date()

        let profile = ContextProfile(
            id: profileId,
            userId: userId,
            values: [ContextValue.userValue("honesty")],
            goals: [ContextGoal.userGoal("get promoted", domain: "career")],
            situation: ContextSituation(
                lifeStage: "mid-career",
                occupation: "software engineer",
                relationships: nil,
                challenges: "work-life balance",
                freeform: nil
            ),
            extractedInsights: [],
            contextVersion: 1,
            firstSessionComplete: false,
            promptDismissedCount: 0,
            createdAt: now,
            updatedAt: now
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(profile)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Verify snake_case keys are used
        XCTAssertNotNil(json?["user_id"], "Should encode userId as user_id")
        XCTAssertNotNil(json?["extracted_insights"], "Should encode extractedInsights as extracted_insights")
        XCTAssertNotNil(json?["context_version"], "Should encode contextVersion as context_version")
        XCTAssertNotNil(json?["first_session_complete"], "Should encode firstSessionComplete as first_session_complete")
        XCTAssertNotNil(json?["prompt_dismissed_count"], "Should encode promptDismissedCount as prompt_dismissed_count")
        XCTAssertNotNil(json?["created_at"], "Should encode createdAt as created_at")
        XCTAssertNotNil(json?["updated_at"], "Should encode updatedAt as updated_at")

        // Verify camelCase keys are NOT used
        XCTAssertNil(json?["userId"], "Should NOT use camelCase userId")
        XCTAssertNil(json?["extractedInsights"], "Should NOT use camelCase extractedInsights")
    }

    func testContextProfileDecoding() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "user_id": "22222222-2222-2222-2222-222222222222",
            "values": [],
            "goals": [],
            "situation": {},
            "extracted_insights": [],
            "context_version": 2,
            "first_session_complete": true,
            "prompt_dismissed_count": 3,
            "created_at": "2026-02-06T10:00:00Z",
            "updated_at": "2026-02-06T12:00:00Z"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let profile = try decoder.decode(ContextProfile.self, from: json)

        XCTAssertEqual(profile.id.uuidString.lowercased(), "11111111-1111-1111-1111-111111111111")
        XCTAssertEqual(profile.userId.uuidString.lowercased(), "22222222-2222-2222-2222-222222222222")
        XCTAssertEqual(profile.contextVersion, 2)
        XCTAssertTrue(profile.firstSessionComplete)
        XCTAssertEqual(profile.promptDismissedCount, 3)
    }

    func testContextProfileRoundTrip() throws {
        let userId = UUID()
        let original = ContextProfile.empty(userId: userId)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ContextProfile.self, from: data)

        // Compare key fields (dates may have slight precision differences)
        XCTAssertEqual(original.id, decoded.id)
        XCTAssertEqual(original.userId, decoded.userId)
        XCTAssertEqual(original.values.count, decoded.values.count)
        XCTAssertEqual(original.goals.count, decoded.goals.count)
        XCTAssertEqual(original.contextVersion, decoded.contextVersion)
        XCTAssertEqual(original.firstSessionComplete, decoded.firstSessionComplete)
        XCTAssertEqual(original.promptDismissedCount, decoded.promptDismissedCount)
    }

    // MARK: - Test 6.4: Empty Profile Factory Method

    func testEmptyProfileFactoryMethod() {
        let userId = UUID()
        let profile = ContextProfile.empty(userId: userId)

        // Verify correct userId
        XCTAssertEqual(profile.userId, userId)

        // Verify empty collections
        XCTAssertTrue(profile.values.isEmpty, "Values should be empty")
        XCTAssertTrue(profile.goals.isEmpty, "Goals should be empty")
        XCTAssertTrue(profile.extractedInsights.isEmpty, "ExtractedInsights should be empty")

        // Verify default values
        XCTAssertEqual(profile.contextVersion, 1, "Context version should default to 1")
        XCTAssertFalse(profile.firstSessionComplete, "First session should not be complete")
        XCTAssertEqual(profile.promptDismissedCount, 0, "Prompt dismissed count should be 0")

        // Verify empty situation
        XCTAssertFalse(profile.situation.hasContent, "Situation should have no content")

        // Verify UUID was generated
        XCTAssertNotEqual(profile.id, UUID(uuidString: "00000000-0000-0000-0000-000000000000"))

        // Verify dates are set
        XCTAssertNotNil(profile.createdAt)
        XCTAssertNotNil(profile.updatedAt)
    }

    func testEmptyProfileHasNoContext() {
        let userId = UUID()
        let profile = ContextProfile.empty(userId: userId)

        XCTAssertFalse(profile.hasContext, "Empty profile should have no context")
        XCTAssertEqual(profile.totalContextItems, 0, "Total context items should be 0")
        XCTAssertTrue(profile.activeGoals.isEmpty, "Active goals should be empty")
    }

    // MARK: - ContextProfile Mutation Tests

    func testAddValue() {
        let userId = UUID()
        var profile = ContextProfile.empty(userId: userId)
        let originalUpdatedAt = profile.updatedAt

        // Small delay to ensure time difference
        Thread.sleep(forTimeInterval: 0.01)

        let value = ContextValue.userValue("integrity")
        profile.addValue(value)

        XCTAssertEqual(profile.values.count, 1)
        XCTAssertEqual(profile.values.first?.content, "integrity")
        XCTAssertTrue(profile.updatedAt > originalUpdatedAt, "UpdatedAt should be updated")
    }

    func testAddGoal() {
        let userId = UUID()
        var profile = ContextProfile.empty(userId: userId)

        let goal = ContextGoal.userGoal("learn Swift", domain: "career")
        profile.addGoal(goal)

        XCTAssertEqual(profile.goals.count, 1)
        XCTAssertEqual(profile.goals.first?.content, "learn Swift")
        XCTAssertEqual(profile.goals.first?.domain, "career")
    }

    func testRemoveValue() {
        let userId = UUID()
        var profile = ContextProfile.empty(userId: userId)

        let value1 = ContextValue.userValue("honesty")
        let value2 = ContextValue.userValue("integrity")
        profile.addValue(value1)
        profile.addValue(value2)

        XCTAssertEqual(profile.values.count, 2)

        profile.removeValue(id: value1.id)

        XCTAssertEqual(profile.values.count, 1)
        XCTAssertEqual(profile.values.first?.content, "integrity")
    }

    func testRemoveGoal() {
        let userId = UUID()
        var profile = ContextProfile.empty(userId: userId)

        let goal1 = ContextGoal.userGoal("goal1")
        let goal2 = ContextGoal.userGoal("goal2")
        profile.addGoal(goal1)
        profile.addGoal(goal2)

        XCTAssertEqual(profile.goals.count, 2)

        profile.removeGoal(id: goal1.id)

        XCTAssertEqual(profile.goals.count, 1)
        XCTAssertEqual(profile.goals.first?.content, "goal2")
    }

    func testActiveGoalsFilter() {
        let userId = UUID()
        var profile = ContextProfile.empty(userId: userId)

        let activeGoal = ContextGoal.userGoal("active goal")
        var achievedGoal = ContextGoal.userGoal("achieved goal")
        achievedGoal.markAchieved()

        profile.addGoal(activeGoal)
        profile.addGoal(achievedGoal)

        XCTAssertEqual(profile.goals.count, 2)
        XCTAssertEqual(profile.activeGoals.count, 1)
        XCTAssertEqual(profile.activeGoals.first?.content, "active goal")
    }

    func testHasContextWithValues() {
        let userId = UUID()
        var profile = ContextProfile.empty(userId: userId)

        XCTAssertFalse(profile.hasContext)

        profile.addValue(ContextValue.userValue("test"))

        XCTAssertTrue(profile.hasContext, "Profile with values should have context")
    }

    func testHasContextWithGoals() {
        let userId = UUID()
        var profile = ContextProfile.empty(userId: userId)

        XCTAssertFalse(profile.hasContext)

        profile.addGoal(ContextGoal.userGoal("test"))

        XCTAssertTrue(profile.hasContext, "Profile with goals should have context")
    }

    func testHasContextWithSituation() {
        let userId = UUID()
        let profile = ContextProfile(
            id: UUID(),
            userId: userId,
            values: [],
            goals: [],
            situation: ContextSituation(
                lifeStage: "mid-career",
                occupation: nil,
                relationships: nil,
                challenges: nil,
                freeform: nil
            ),
            extractedInsights: [],
            contextVersion: 1,
            firstSessionComplete: false,
            promptDismissedCount: 0,
            createdAt: Date(),
            updatedAt: Date()
        )

        XCTAssertTrue(profile.hasContext, "Profile with situation should have context")
    }

    // MARK: - ContextValue Tests

    func testContextValueUserFactory() {
        let value = ContextValue.userValue("honesty")

        XCTAssertEqual(value.content, "honesty")
        XCTAssertEqual(value.source, .user)
        XCTAssertNil(value.confidence, "User values should have no confidence score")
    }

    func testContextValueExtractedFactory() {
        let value = ContextValue.extractedValue("family-oriented", confidence: 0.85)

        XCTAssertEqual(value.content, "family-oriented")
        XCTAssertEqual(value.source, .extracted)
        XCTAssertEqual(value.confidence, 0.85)
    }

    func testContextValueEncoding() throws {
        let value = ContextValue.userValue("test")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Verify snake_case
        XCTAssertNotNil(json?["added_at"], "Should encode addedAt as added_at")
    }

    // MARK: - ContextGoal Tests

    func testContextGoalUserFactory() {
        let goal = ContextGoal.userGoal("get promoted", domain: "career")

        XCTAssertEqual(goal.content, "get promoted")
        XCTAssertEqual(goal.domain, "career")
        XCTAssertEqual(goal.source, .user)
        XCTAssertEqual(goal.status, .active)
    }

    func testContextGoalExtractedFactory() {
        let goal = ContextGoal.extractedGoal("improve health")

        XCTAssertEqual(goal.content, "improve health")
        XCTAssertEqual(goal.source, .extracted)
        XCTAssertEqual(goal.status, .active)
    }

    func testContextGoalStatusTransitions() {
        var goal = ContextGoal.userGoal("test goal")

        XCTAssertEqual(goal.status, .active)

        goal.markAchieved()
        XCTAssertEqual(goal.status, .achieved)

        goal.archive()
        XCTAssertEqual(goal.status, .archived)

        goal.reactivate()
        XCTAssertEqual(goal.status, .active)
    }

    func testContextGoalEncoding() throws {
        let goal = ContextGoal.userGoal("test")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(goal)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Verify snake_case
        XCTAssertNotNil(json?["added_at"], "Should encode addedAt as added_at")
    }

    // MARK: - ContextSituation Tests

    func testContextSituationEmpty() {
        let situation = ContextSituation.empty

        XCTAssertNil(situation.lifeStage)
        XCTAssertNil(situation.occupation)
        XCTAssertNil(situation.relationships)
        XCTAssertNil(situation.challenges)
        XCTAssertNil(situation.freeform)
        XCTAssertFalse(situation.hasContent)
        XCTAssertEqual(situation.filledFieldCount, 0)
        XCTAssertNil(situation.summary)
    }

    func testContextSituationWithContent() {
        let situation = ContextSituation(
            lifeStage: "mid-career",
            occupation: "engineer",
            relationships: nil,
            challenges: "stress",
            freeform: nil
        )

        XCTAssertTrue(situation.hasContent)
        XCTAssertEqual(situation.filledFieldCount, 3)
        XCTAssertEqual(situation.summary, "engineer", "Summary should be occupation (first priority after lifeStage)")
    }

    func testContextSituationSummaryPriority() {
        // Test that summary returns occupation first if available
        let withOccupation = ContextSituation(
            lifeStage: nil,
            occupation: "teacher",
            relationships: nil,
            challenges: nil,
            freeform: nil
        )
        XCTAssertEqual(withOccupation.summary, "teacher")

        // Test fallback to lifeStage
        let withLifeStage = ContextSituation(
            lifeStage: "retirement",
            occupation: nil,
            relationships: nil,
            challenges: nil,
            freeform: nil
        )
        XCTAssertEqual(withLifeStage.summary, "retirement")
    }

    func testContextSituationEncoding() throws {
        let situation = ContextSituation(
            lifeStage: "test",
            occupation: nil,
            relationships: nil,
            challenges: nil,
            freeform: nil
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(situation)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Verify snake_case
        XCTAssertNotNil(json?["life_stage"], "Should encode lifeStage as life_stage")
    }

    // MARK: - ExtractedInsight Tests

    func testExtractedInsightPendingFactory() {
        let conversationId = UUID()
        let insight = ExtractedInsight.pending(
            content: "User values honesty",
            category: .value,
            confidence: 0.9,
            conversationId: conversationId
        )

        XCTAssertEqual(insight.content, "User values honesty")
        XCTAssertEqual(insight.category, .value)
        XCTAssertEqual(insight.confidence, 0.9)
        XCTAssertEqual(insight.sourceConversationId, conversationId)
        XCTAssertFalse(insight.confirmed, "Pending insight should not be confirmed")
    }

    func testExtractedInsightConfirm() {
        var insight = ExtractedInsight.pending(
            content: "test",
            category: .goal,
            confidence: 0.8
        )

        XCTAssertFalse(insight.confirmed)

        insight.confirm()

        XCTAssertTrue(insight.confirmed)
    }

    func testExtractedInsightEncoding() throws {
        // Provide a conversationId to test snake_case encoding
        let conversationId = UUID()
        let insight = ExtractedInsight.pending(
            content: "test",
            category: .pattern,
            confidence: 0.7,
            conversationId: conversationId
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(insight)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Verify snake_case
        XCTAssertNotNil(json?["extracted_at"], "Should encode extractedAt as extracted_at")
        XCTAssertNotNil(json?["source_conversation_id"], "Should encode sourceConversationId as source_conversation_id")
    }

    // MARK: - ContextProfileInsert Tests

    func testContextProfileInsertEncoding() throws {
        let userId = UUID()
        let insert = ContextProfileInsert(userId: userId)

        let encoder = JSONEncoder()
        let data = try encoder.encode(insert)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Verify only user_id is encoded
        XCTAssertNotNil(json?["user_id"], "Should encode userId as user_id")
        XCTAssertEqual(json?.count, 1, "Insert should only contain user_id")
    }

    // MARK: - ContextError Tests

    func testContextErrorMessages() {
        let errors: [ContextError] = [
            .notFound,
            .notAuthenticated,
            .saveFailed("test reason"),
            .cacheError("cache reason"),
            .encodingError("encoding reason")
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error should have description")
            // Verify warm, first-person messages (per UX-11)
            XCTAssertTrue(
                error.errorDescription?.contains("I") ?? false,
                "Error '\(error)' should use first-person language"
            )
        }
    }

    func testContextErrorEquatable() {
        XCTAssertEqual(ContextError.notFound, ContextError.notFound)
        XCTAssertEqual(ContextError.notAuthenticated, ContextError.notAuthenticated)
        XCTAssertEqual(ContextError.saveFailed("test"), ContextError.saveFailed("test"))
        XCTAssertNotEqual(ContextError.saveFailed("a"), ContextError.saveFailed("b"))
        XCTAssertNotEqual(ContextError.notFound, ContextError.notAuthenticated)
    }
}
