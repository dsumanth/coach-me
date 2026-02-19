//
//  NotificationPreferenceTests.swift
//  CoachMeTests
//
//  Story 8.3: Push Permission Timing & Notification Preferences
//  Tests for NotificationPreference model encoding/decoding with snake_case
//

import XCTest
@testable import CoachMe

@MainActor
final class NotificationPreferenceTests: XCTestCase {

    // MARK: - Encoding Tests

    func testEncodesToSnakeCase() throws {
        let pref = NotificationPreference(checkInsEnabled: true, frequency: .fewTimesAWeek)

        let data = try JSONEncoder().encode(pref)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(dict["check_ins_enabled"] as? Bool, true)
        XCTAssertEqual(dict["frequency"] as? String, "few_times_a_week")
        XCTAssertNil(dict["checkInsEnabled"], "Should use snake_case, not camelCase")
    }

    func testEncodesAllFrequencies() throws {
        for freq in NotificationPreference.CheckInFrequency.allCases {
            let pref = NotificationPreference(checkInsEnabled: true, frequency: freq)
            let data = try JSONEncoder().encode(pref)
            let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]

            XCTAssertEqual(dict["frequency"] as? String, freq.rawValue)
        }
    }

    // MARK: - Decoding Tests

    func testDecodesFromSnakeCase() throws {
        let json = """
        {"check_ins_enabled": true, "frequency": "daily"}
        """.data(using: .utf8)!

        let pref = try JSONDecoder().decode(NotificationPreference.self, from: json)

        XCTAssertTrue(pref.checkInsEnabled)
        XCTAssertEqual(pref.frequency, .daily)
    }

    func testDecodesFewTimesAWeek() throws {
        let json = """
        {"check_ins_enabled": false, "frequency": "few_times_a_week"}
        """.data(using: .utf8)!

        let pref = try JSONDecoder().decode(NotificationPreference.self, from: json)

        XCTAssertFalse(pref.checkInsEnabled)
        XCTAssertEqual(pref.frequency, .fewTimesAWeek)
    }

    func testDecodesWeekly() throws {
        let json = """
        {"check_ins_enabled": true, "frequency": "weekly"}
        """.data(using: .utf8)!

        let pref = try JSONDecoder().decode(NotificationPreference.self, from: json)

        XCTAssertTrue(pref.checkInsEnabled)
        XCTAssertEqual(pref.frequency, .weekly)
    }

    // MARK: - Roundtrip Tests

    func testRoundtripEncodeDecode() throws {
        let original = NotificationPreference(checkInsEnabled: true, frequency: .fewTimesAWeek)

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(NotificationPreference.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    // MARK: - Default Factory Tests

    func testDefaultFactory() {
        let pref = NotificationPreference.default()

        XCTAssertTrue(pref.checkInsEnabled)
        XCTAssertEqual(pref.frequency, .fewTimesAWeek)
    }

    // MARK: - Display Name Tests

    func testFrequencyDisplayNames() {
        XCTAssertEqual(NotificationPreference.CheckInFrequency.daily.displayName, "Daily")
        XCTAssertEqual(NotificationPreference.CheckInFrequency.fewTimesAWeek.displayName, "Few times a week")
        XCTAssertEqual(NotificationPreference.CheckInFrequency.weekly.displayName, "Weekly")
    }

    // MARK: - Equatable Tests

    func testEquatable() {
        let a = NotificationPreference(checkInsEnabled: true, frequency: .daily)
        let b = NotificationPreference(checkInsEnabled: true, frequency: .daily)
        let c = NotificationPreference(checkInsEnabled: false, frequency: .daily)

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }
}
