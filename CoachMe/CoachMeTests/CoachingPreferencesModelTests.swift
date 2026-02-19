//
//  CoachingPreferencesModelTests.swift
//  CoachMeTests
//
//  Story 8.8: Enhanced Profile — Learned Knowledge Display
//  Tests for CoachingPreferences model types: encode/decode, optional fields, empty object decode
//

import XCTest
@testable import CoachMe

final class CoachingPreferencesModelTests: XCTestCase {

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    // MARK: - InferredPattern Tests

    func testInferredPatternRoundTrip() throws {
        let pattern = InferredPattern(
            id: UUID(),
            patternText: "Sets clear boundaries at work",
            category: "boundary",
            confidence: 0.85,
            sourceCount: 3,
            lastObserved: nil
        )

        let data = try encoder.encode(pattern)
        let decoded = try decoder.decode(InferredPattern.self, from: data)

        XCTAssertEqual(pattern, decoded)
    }

    func testInferredPatternSnakeCaseCodingKeys() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "pattern_text": "Avoids conflict",
            "category": "relationship",
            "confidence": 0.72,
            "source_count": 5
        }
        """.data(using: .utf8)!

        let pattern = try decoder.decode(InferredPattern.self, from: json)

        XCTAssertEqual(pattern.patternText, "Avoids conflict")
        XCTAssertEqual(pattern.category, "relationship")
        XCTAssertEqual(pattern.confidence, 0.72)
        XCTAssertEqual(pattern.sourceCount, 5)
        XCTAssertNil(pattern.lastObserved)
    }

    // MARK: - CoachingStyleInfo Tests

    func testCoachingStyleInfoRoundTrip() throws {
        let style = CoachingStyleInfo(
            inferredStyle: "Exploratory",
            confidence: 0.9,
            lastInferred: nil
        )

        let data = try encoder.encode(style)
        let decoded = try decoder.decode(CoachingStyleInfo.self, from: data)

        XCTAssertEqual(style, decoded)
    }

    func testCoachingStyleInfoSnakeCaseCodingKeys() throws {
        let json = """
        {
            "inferred_style": "Direct",
            "confidence": 0.88,
            "last_inferred": "2026-02-09T12:00:00Z"
        }
        """.data(using: .utf8)!

        let style = try decoder.decode(CoachingStyleInfo.self, from: json)

        XCTAssertEqual(style.inferredStyle, "Direct")
        XCTAssertEqual(style.confidence, 0.88)
        XCTAssertNotNil(style.lastInferred)
    }

    func testCoachingStyleInfoAllNils() throws {
        let json = "{}".data(using: .utf8)!
        let style = try decoder.decode(CoachingStyleInfo.self, from: json)

        XCTAssertNil(style.inferredStyle)
        XCTAssertNil(style.confidence)
        XCTAssertNil(style.lastInferred)
    }

    // MARK: - ManualOverrides Tests

    func testManualOverridesRoundTrip() throws {
        let overrides = ManualOverrides(style: "Challenging", setAt: Date())

        let data = try encoder.encode(overrides)
        let decoded = try decoder.decode(ManualOverrides.self, from: data)

        XCTAssertEqual(overrides.style, decoded.style)
    }

    func testManualOverridesSnakeCaseKeys() throws {
        let json = """
        {
            "style": "Supportive",
            "set_at": "2026-02-09T10:00:00Z"
        }
        """.data(using: .utf8)!

        let overrides = try decoder.decode(ManualOverrides.self, from: json)

        XCTAssertEqual(overrides.style, "Supportive")
        XCTAssertNotNil(overrides.setAt)
    }

    func testManualOverridesEmptyObject() throws {
        let json = "{}".data(using: .utf8)!
        let overrides = try decoder.decode(ManualOverrides.self, from: json)

        XCTAssertNil(overrides.style)
        XCTAssertNil(overrides.setAt)
    }

    // MARK: - DomainUsageStats Tests

    func testDomainUsageStatsRoundTrip() throws {
        let stats = DomainUsageStats(
            domains: ["career": 0.45, "relationships": 0.30, "growth": 0.25],
            lastCalculated: nil
        )

        let data = try encoder.encode(stats)
        let decoded = try decoder.decode(DomainUsageStats.self, from: data)

        XCTAssertEqual(stats, decoded)
    }

    func testDomainUsageStatsSnakeCaseKeys() throws {
        let json = """
        {
            "domains": {"career": 0.6, "health": 0.4},
            "last_calculated": "2026-02-09T08:00:00Z"
        }
        """.data(using: .utf8)!

        let stats = try decoder.decode(DomainUsageStats.self, from: json)

        XCTAssertEqual(stats.domains["career"], 0.6)
        XCTAssertEqual(stats.domains["health"], 0.4)
        XCTAssertNotNil(stats.lastCalculated)
    }

    func testDomainUsageStatsDefaultInit() {
        let stats = DomainUsageStats()

        XCTAssertTrue(stats.domains.isEmpty)
        XCTAssertNil(stats.lastCalculated)
    }

    // MARK: - ProgressNote Tests

    func testProgressNoteRoundTrip() throws {
        let note = ProgressNote(
            id: UUID(),
            goal: "Run a marathon",
            progressText: "Completed first 10K",
            lastUpdated: nil
        )

        let data = try encoder.encode(note)
        let decoded = try decoder.decode(ProgressNote.self, from: data)

        XCTAssertEqual(note, decoded)
    }

    func testProgressNoteSnakeCaseKeys() throws {
        let json = """
        {
            "id": "22222222-2222-2222-2222-222222222222",
            "goal": "Get promoted",
            "progress_text": "Had the conversation with manager",
            "last_updated": "2026-02-09T14:00:00Z"
        }
        """.data(using: .utf8)!

        let note = try decoder.decode(ProgressNote.self, from: json)

        XCTAssertEqual(note.goal, "Get promoted")
        XCTAssertEqual(note.progressText, "Had the conversation with manager")
        XCTAssertNotNil(note.lastUpdated)
    }

    // MARK: - DismissedInsights Tests

    func testDismissedInsightsRoundTrip() throws {
        let id1 = UUID()
        let id2 = UUID()
        let dismissed = DismissedInsights(insightIds: [id1, id2], lastDismissed: Date())

        let data = try encoder.encode(dismissed)
        let decoded = try decoder.decode(DismissedInsights.self, from: data)

        XCTAssertEqual(decoded.insightIds.count, 2)
        XCTAssertTrue(decoded.insightIds.contains(id1))
        XCTAssertTrue(decoded.insightIds.contains(id2))
    }

    func testDismissedInsightsSnakeCaseKeys() throws {
        let json = """
        {
            "insight_ids": ["33333333-3333-3333-3333-333333333333"],
            "last_dismissed": "2026-02-09T16:00:00Z"
        }
        """.data(using: .utf8)!

        let dismissed = try decoder.decode(DismissedInsights.self, from: json)

        XCTAssertEqual(dismissed.insightIds.count, 1)
        XCTAssertNotNil(dismissed.lastDismissed)
    }

    func testDismissedInsightsDefaultInit() {
        let dismissed = DismissedInsights()

        XCTAssertTrue(dismissed.insightIds.isEmpty)
        XCTAssertNil(dismissed.lastDismissed)
    }

    // MARK: - CoachingPreferences Integration Tests

    func testCoachingPreferencesEmptyObjectDecode() throws {
        // DB default is '{}'::jsonb — literally no keys at all
        let json = "{}".data(using: .utf8)!

        let prefs = try decoder.decode(CoachingPreferences.self, from: json)

        XCTAssertTrue(prefs.domainUsage.isEmpty)
        XCTAssertTrue(prefs.sessionPatterns.isEmpty)
        XCTAssertNil(prefs.inferredPatterns)
        XCTAssertNil(prefs.coachingStyle)
        XCTAssertNil(prefs.manualOverrides)
        XCTAssertNil(prefs.domainUsageStats)
        XCTAssertNil(prefs.progressNotes)
        XCTAssertNil(prefs.dismissedInsights)
    }

    func testCoachingPreferencesWithExplicitEmptyCollections() throws {
        // When app writes CoachingPreferences.empty, it includes these keys
        let json = """
        {
            "domain_usage": {},
            "session_patterns": {}
        }
        """.data(using: .utf8)!

        let prefs = try decoder.decode(CoachingPreferences.self, from: json)

        XCTAssertTrue(prefs.domainUsage.isEmpty)
        XCTAssertTrue(prefs.sessionPatterns.isEmpty)
        XCTAssertNil(prefs.inferredPatterns)
    }

    func testCoachingPreferencesWithLearnedKnowledge() throws {
        let json = """
        {
            "domain_usage": {},
            "session_patterns": {},
            "inferred_patterns": [
                {
                    "id": "44444444-4444-4444-4444-444444444444",
                    "pattern_text": "Values work-life balance",
                    "category": "growth",
                    "confidence": 0.92,
                    "source_count": 7
                }
            ],
            "coaching_style": {
                "inferred_style": "Exploratory",
                "confidence": 0.85
            },
            "manual_overrides": {
                "style": "Direct",
                "set_at": "2026-02-09T12:00:00Z"
            },
            "domain_usage_stats": {
                "domains": {"career": 0.5, "relationships": 0.3, "growth": 0.2}
            },
            "progress_notes": [
                {
                    "id": "55555555-5555-5555-5555-555555555555",
                    "goal": "Run a marathon",
                    "progress_text": "Completed first 10K"
                }
            ],
            "dismissed_insights": {
                "insight_ids": ["66666666-6666-6666-6666-666666666666"]
            }
        }
        """.data(using: .utf8)!

        let prefs = try decoder.decode(CoachingPreferences.self, from: json)

        XCTAssertEqual(prefs.inferredPatterns?.count, 1)
        XCTAssertEqual(prefs.inferredPatterns?.first?.patternText, "Values work-life balance")
        XCTAssertEqual(prefs.coachingStyle?.inferredStyle, "Exploratory")
        XCTAssertEqual(prefs.manualOverrides?.style, "Direct")
        XCTAssertEqual(prefs.domainUsageStats?.domains.count, 3)
        XCTAssertEqual(prefs.progressNotes?.count, 1)
        XCTAssertEqual(prefs.dismissedInsights?.insightIds.count, 1)
    }

    func testManualOverrideWinsOverInferred() throws {
        // When both inferred and manual exist, manual should be used
        var prefs = CoachingPreferences.empty
        prefs.coachingStyle = CoachingStyleInfo(inferredStyle: "Exploratory", confidence: 0.9, lastInferred: nil)
        prefs.manualOverrides = ManualOverrides(style: "Direct", setAt: Date())

        // Manual override should take precedence
        let effectiveStyle = prefs.manualOverrides?.style ?? prefs.coachingStyle?.inferredStyle
        XCTAssertEqual(effectiveStyle, "Direct")
    }

    func testInferredStyleUsedWhenNoManualOverride() throws {
        var prefs = CoachingPreferences.empty
        prefs.coachingStyle = CoachingStyleInfo(inferredStyle: "Supportive", confidence: 0.75, lastInferred: nil)

        let effectiveStyle = prefs.manualOverrides?.style ?? prefs.coachingStyle?.inferredStyle
        XCTAssertEqual(effectiveStyle, "Supportive")
    }

    func testCoachingPreferencesRoundTripWithAllFields() throws {
        var prefs = CoachingPreferences.empty
        prefs.inferredPatterns = [
            InferredPattern(id: UUID(), patternText: "Test pattern", category: "growth", confidence: 0.8, sourceCount: 3, lastObserved: nil)
        ]
        prefs.coachingStyle = CoachingStyleInfo(inferredStyle: "Balanced", confidence: 0.7, lastInferred: nil)
        prefs.manualOverrides = ManualOverrides(style: "Challenging", setAt: nil)
        prefs.domainUsageStats = DomainUsageStats(domains: ["career": 0.6], lastCalculated: nil)
        prefs.progressNotes = [
            ProgressNote(id: UUID(), goal: "Test goal", progressText: "Progress", lastUpdated: nil)
        ]
        prefs.dismissedInsights = DismissedInsights(insightIds: [UUID()])

        let data = try encoder.encode(prefs)
        let decoded = try decoder.decode(CoachingPreferences.self, from: data)

        XCTAssertEqual(decoded.inferredPatterns?.count, 1)
        XCTAssertEqual(decoded.coachingStyle?.inferredStyle, "Balanced")
        XCTAssertEqual(decoded.manualOverrides?.style, "Challenging")
        XCTAssertEqual(decoded.domainUsageStats?.domains["career"], 0.6)
        XCTAssertEqual(decoded.progressNotes?.count, 1)
        XCTAssertEqual(decoded.dismissedInsights?.insightIds.count, 1)
    }
}
