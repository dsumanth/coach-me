//
//  StyleDimensionsTests.swift
//  CoachMeTests
//
//  Story 8.6: Coaching Style Adaptation
//  Tests for StyleDimensions and CoachingPreferences style-related fields
//

import XCTest
@testable import CoachMe

@MainActor
final class StyleDimensionsTests: XCTestCase {

    // MARK: - StyleDimensions Balanced Factory

    func testBalancedReturnsAllHalf() {
        let dims = StyleDimensions.balanced()
        XCTAssertEqual(dims.directVsExploratory, 0.5)
        XCTAssertEqual(dims.briefVsDetailed, 0.5)
        XCTAssertEqual(dims.actionVsReflective, 0.5)
        XCTAssertEqual(dims.challengingVsSupportive, 0.5)
    }

    // MARK: - Encode / Decode Round-Trip

    func testStyleDimensionsRoundTrip() throws {
        let original = StyleDimensions(
            directVsExploratory: 0.8,
            briefVsDetailed: 0.3,
            actionVsReflective: 0.7,
            challengingVsSupportive: 0.4
        )
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(StyleDimensions.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testStyleDimensionsSnakeCaseKeys() throws {
        let dims = StyleDimensions(
            directVsExploratory: 0.9,
            briefVsDetailed: 0.1,
            actionVsReflective: 0.6,
            challengingVsSupportive: 0.2
        )
        let encoder = JSONEncoder()
        let data = try encoder.encode(dims)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertNotNil(dict["direct_vs_exploratory"])
        XCTAssertNotNil(dict["brief_vs_detailed"])
        XCTAssertNotNil(dict["action_vs_reflective"])
        XCTAssertNotNil(dict["challenging_vs_supportive"])

        // Verify camelCase keys are NOT present
        XCTAssertNil(dict["directVsExploratory"])
        XCTAssertNil(dict["briefVsDetailed"])
    }

    func testStyleDimensionsDecodesFromSnakeCase() throws {
        let json = """
        {
            "direct_vs_exploratory": 0.75,
            "brief_vs_detailed": 0.25,
            "action_vs_reflective": 0.6,
            "challenging_vs_supportive": 0.4
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let dims = try decoder.decode(StyleDimensions.self, from: json)
        XCTAssertEqual(dims.directVsExploratory, 0.75)
        XCTAssertEqual(dims.briefVsDetailed, 0.25)
        XCTAssertEqual(dims.actionVsReflective, 0.6)
        XCTAssertEqual(dims.challengingVsSupportive, 0.4)
    }

    // MARK: - Equatable

    func testStyleDimensionsEquatable() {
        let a = StyleDimensions(
            directVsExploratory: 0.8,
            briefVsDetailed: 0.3,
            actionVsReflective: 0.7,
            challengingVsSupportive: 0.4
        )
        let b = StyleDimensions(
            directVsExploratory: 0.8,
            briefVsDetailed: 0.3,
            actionVsReflective: 0.7,
            challengingVsSupportive: 0.4
        )
        XCTAssertEqual(a, b)
    }

    func testStyleDimensionsNotEqualWhenDifferent() {
        let a = StyleDimensions.balanced()
        let b = StyleDimensions(
            directVsExploratory: 0.9,
            briefVsDetailed: 0.5,
            actionVsReflective: 0.5,
            challengingVsSupportive: 0.5
        )
        XCTAssertNotEqual(a, b)
    }

    // MARK: - CoachingPreferences with Style Fields

    func testCoachingPreferencesEmptyHasNilStyleFields() {
        let prefs = CoachingPreferences.empty
        XCTAssertNil(prefs.styleDimensions)
        XCTAssertNil(prefs.domainStyles)
        XCTAssertNil(prefs.sessionCount)
        XCTAssertNil(prefs.lastStyleAnalysisAt)
        XCTAssertNil(prefs.manualOverride)
    }

    func testCoachingPreferencesStyleRoundTrip() throws {
        var prefs = CoachingPreferences.empty
        prefs.styleDimensions = StyleDimensions(
            directVsExploratory: 0.8,
            briefVsDetailed: 0.3,
            actionVsReflective: 0.7,
            challengingVsSupportive: 0.4
        )
        prefs.domainStyles = [
            "career": StyleDimensions(
                directVsExploratory: 0.9,
                briefVsDetailed: 0.2,
                actionVsReflective: 0.8,
                challengingVsSupportive: 0.3
            )
        ]
        prefs.sessionCount = 15
        prefs.lastStyleAnalysisAt = Date(timeIntervalSince1970: 1_700_000_000)
        prefs.manualOverride = "direct"

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(prefs)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(CoachingPreferences.self, from: data)

        XCTAssertEqual(decoded.styleDimensions, prefs.styleDimensions)
        XCTAssertEqual(decoded.domainStyles?["career"], prefs.domainStyles?["career"])
        XCTAssertEqual(decoded.sessionCount, 15)
        XCTAssertEqual(decoded.manualOverride, "direct")
        XCTAssertNotNil(decoded.lastStyleAnalysisAt)
    }

    func testCoachingPreferencesStyleCodingKeysSnakeCase() throws {
        var prefs = CoachingPreferences.empty
        prefs.styleDimensions = StyleDimensions.balanced()
        prefs.sessionCount = 10

        let encoder = JSONEncoder()
        let data = try encoder.encode(prefs)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertNotNil(dict["style_dimensions"])
        XCTAssertNotNil(dict["session_count"])
        XCTAssertNotNil(dict["domain_usage"])

        // Verify camelCase keys are NOT present
        XCTAssertNil(dict["styleDimensions"])
        XCTAssertNil(dict["sessionCount"])
    }

    func testCoachingPreferencesBackwardCompatibilityWithoutStyleFields() throws {
        // Simulate a JSON payload from before Story 8.6 (no style fields)
        let json = """
        {
            "domain_usage": {"career": 5},
            "session_patterns": {}
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let prefs = try decoder.decode(CoachingPreferences.self, from: json)

        // Existing fields decode correctly
        XCTAssertEqual(prefs.domainUsage["career"], 5)

        // New style fields default to nil
        XCTAssertNil(prefs.styleDimensions)
        XCTAssertNil(prefs.domainStyles)
        XCTAssertNil(prefs.sessionCount)
        XCTAssertNil(prefs.lastStyleAnalysisAt)
        XCTAssertNil(prefs.manualOverride)
    }
}
