//
//  DeviceFingerprintServiceTests.swift
//  CoachMeTests
//
//  Story 10.2: Device Fingerprint Tracking & Trial Abuse Prevention
//  Tests for DeviceFingerprint models, CodingKeys, TrialEligibility,
//  and DeviceFingerprintService initialization.
//

import XCTest
@testable import CoachMe

@MainActor
final class DeviceFingerprintServiceTests: XCTestCase {

    // MARK: - DeviceFingerprint Model Encoding Tests

    func testDeviceFingerprintEncodesWithSnakeCaseKeys() throws {
        let id = UUID()
        let userId = UUID()
        let now = Date()

        let fingerprint = DeviceFingerprint(
            id: id,
            userId: userId,
            deviceId: "ABCD1234-5678-90EF-GHIJ-KLMNOPQRSTUV",
            firstSeenAt: now,
            lastSeenAt: now,
            trialUsed: false
        )

        let data = try JSONEncoder().encode(fingerprint)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // Verify snake_case keys
        XCTAssertNotNil(dict["user_id"], "Should encode userId as 'user_id'")
        XCTAssertNotNil(dict["device_id"], "Should encode deviceId as 'device_id'")
        XCTAssertNotNil(dict["first_seen_at"], "Should encode firstSeenAt as 'first_seen_at'")
        XCTAssertNotNil(dict["last_seen_at"], "Should encode lastSeenAt as 'last_seen_at'")
        XCTAssertNotNil(dict["trial_used"], "Should encode trialUsed as 'trial_used'")

        // Verify camelCase keys are NOT present
        XCTAssertNil(dict["userId"], "Should not use camelCase 'userId'")
        XCTAssertNil(dict["deviceId"], "Should not use camelCase 'deviceId'")
        XCTAssertNil(dict["firstSeenAt"], "Should not use camelCase 'firstSeenAt'")
        XCTAssertNil(dict["lastSeenAt"], "Should not use camelCase 'lastSeenAt'")
        XCTAssertNil(dict["trialUsed"], "Should not use camelCase 'trialUsed'")
    }

    // MARK: - DeviceFingerprintUpsert Encoding Tests

    func testDeviceFingerprintUpsertEncodesCorrectly() throws {
        let userId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let upsert = DeviceFingerprintUpsert(
            userId: userId,
            deviceId: "AAAA-BBBB-CCCC-DDDD"
        )

        let data = try JSONEncoder().encode(upsert)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(dict["user_id"] as? String, userId.uuidString)
        XCTAssertEqual(dict["device_id"] as? String, "AAAA-BBBB-CCCC-DDDD")
        XCTAssertNil(dict["userId"], "Should use snake_case, not camelCase")
        XCTAssertNil(dict["deviceId"], "Should use snake_case, not camelCase")
    }

    // MARK: - TrialEligibilityResponse Decoding Tests

    func testTrialEligibilityResponseDecodesEligible() throws {
        let json = """
        {"eligible": true, "reason": "new_device"}
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(TrialEligibilityResponse.self, from: json)

        XCTAssertTrue(response.eligible)
        XCTAssertEqual(response.reason, "new_device")
    }

    func testTrialEligibilityResponseDecodesDenied() throws {
        let json = """
        {"eligible": false, "reason": "trial_already_used"}
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(TrialEligibilityResponse.self, from: json)

        XCTAssertFalse(response.eligible)
        XCTAssertEqual(response.reason, "trial_already_used")
    }

    func testTrialEligibilityResponseDecodesSameAccount() throws {
        let json = """
        {"eligible": true, "reason": "same_account"}
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(TrialEligibilityResponse.self, from: json)

        XCTAssertTrue(response.eligible)
        XCTAssertEqual(response.reason, "same_account")
    }

    func testTrialEligibilityResponseDecodesDeviceTransferred() throws {
        let json = """
        {"eligible": true, "reason": "device_transferred"}
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(TrialEligibilityResponse.self, from: json)

        XCTAssertTrue(response.eligible)
        XCTAssertEqual(response.reason, "device_transferred")
    }

    // MARK: - TrialEligibility Enum Equality Tests

    func testTrialEligibilityEligibleEquality() {
        XCTAssertEqual(TrialEligibility.eligible, TrialEligibility.eligible)
    }

    func testTrialEligibilityDeniedEquality() {
        XCTAssertEqual(
            TrialEligibility.denied(reason: "trial_already_used"),
            TrialEligibility.denied(reason: "trial_already_used")
        )
    }

    func testTrialEligibilityDeniedInequalityDifferentReasons() {
        XCTAssertNotEqual(
            TrialEligibility.denied(reason: "trial_already_used"),
            TrialEligibility.denied(reason: "other_reason")
        )
    }

    func testTrialEligibilityEligibleNotEqualToDenied() {
        XCTAssertNotEqual(
            TrialEligibility.eligible,
            TrialEligibility.denied(reason: "trial_already_used")
        )
    }

    // MARK: - Service Initialization Tests

    func testServiceInitializesWithInjectedSupabaseClient() {
        // Uses the test-injectable init
        let client = AppEnvironment.shared.supabase
        let service = DeviceFingerprintService(supabase: client)

        // If we get here without crashing, the init works
        XCTAssertNotNil(service, "Service should initialize with injected Supabase client")
    }

    // MARK: - DeviceFingerprint Decoding Tests

    func testDeviceFingerprintDecodesFromSnakeCaseJSON() throws {
        let id = UUID()
        let userId = UUID()
        let json = """
        {
            "id": "\(id.uuidString)",
            "user_id": "\(userId.uuidString)",
            "device_id": "TEST-DEVICE-ID",
            "first_seen_at": "2026-02-10T12:00:00Z",
            "last_seen_at": "2026-02-10T12:00:00Z",
            "trial_used": true
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let fingerprint = try decoder.decode(DeviceFingerprint.self, from: json)

        XCTAssertEqual(fingerprint.id, id)
        XCTAssertEqual(fingerprint.userId, userId)
        XCTAssertEqual(fingerprint.deviceId, "TEST-DEVICE-ID")
        XCTAssertTrue(fingerprint.trialUsed)
    }
}
