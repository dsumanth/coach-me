//
//  DeviceFingerprintService.swift
//  CoachMe
//
//  Story 10.2 — Device Fingerprint Tracking & Trial Abuse Prevention
//

import Foundation
import UIKit
import Supabase

// MARK: - Models

/// Full device fingerprint record from the database.
struct DeviceFingerprint: Codable, Sendable, Equatable {
    let id: UUID
    let userId: UUID
    let deviceId: String
    let firstSeenAt: Date
    let lastSeenAt: Date
    let trialUsed: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case deviceId = "device_id"
        case firstSeenAt = "first_seen_at"
        case lastSeenAt = "last_seen_at"
        case trialUsed = "trial_used"
    }
}

/// Minimal upsert model for device registration.
struct DeviceFingerprintUpsert: Codable, Sendable {
    let userId: UUID
    let deviceId: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case deviceId = "device_id"
    }
}

/// Update payload for marking trial as used.
private struct TrialUsedUpdate: Codable {
    let trialUsed: Bool

    enum CodingKeys: String, CodingKey {
        case trialUsed = "trial_used"
    }
}

/// Whether the device is eligible for a free trial.
enum TrialEligibility: Sendable, Equatable {
    case eligible
    case denied(reason: String)
}

/// JSON response shape from the `check_device_trial_eligibility` RPC.
struct TrialEligibilityResponse: Codable {
    let eligible: Bool
    let reason: String
}

// MARK: - Service

/// Tracks device identifiers (IDFV) alongside user IDs to detect trial abuse.
///
/// **Design constraints (Story 10.2):**
/// - `@MainActor` singleton matching the project service pattern.
/// - Device registration is fire-and-forget — never blocks auth.
/// - IDFV can be nil on simulators — fail gracefully.
/// - RPC call bypasses RLS via `SECURITY DEFINER`.
@MainActor
final class DeviceFingerprintService {
    // MARK: - Singleton

    static let shared = DeviceFingerprintService()

    // MARK: - Properties

    private let supabase: SupabaseClient

    // MARK: - Initialization

    private init() {
        self.supabase = AppEnvironment.shared.supabase
    }

    /// Test-injectable initializer.
    init(supabase: SupabaseClient) {
        self.supabase = supabase
    }

    // MARK: - Public API

    /// Registers the current device for the given user.
    ///
    /// Uses `identifierForVendor` (IDFV). If IDFV is nil (simulator),
    /// logs and returns silently — never throws.
    func registerDevice(userId: UUID) async throws {
        guard let idfv = UIDevice.current.identifierForVendor?.uuidString else {
            #if DEBUG
            print("DeviceFingerprintService: IDFV unavailable (simulator?) — skipping registration")
            #endif
            return
        }

        let row = DeviceFingerprintUpsert(userId: userId, deviceId: idfv)

        try await supabase
            .from("device_fingerprints")
            .upsert(row, onConflict: "device_id")
            .execute()

        #if DEBUG
        print("DeviceFingerprintService: Device registered (\(idfv.prefix(8))…)")
        #endif
    }

    /// Checks whether this device is eligible for a free trial.
    ///
    /// - Returns `.eligible` if no prior trial abuse detected (or IDFV is nil).
    /// - Returns `.denied(reason:)` if the device was previously used for a trial
    ///   under a different Apple ID.
    func checkTrialEligibility(userId: UUID) async throws -> TrialEligibility {
        guard let idfv = UIDevice.current.identifierForVendor?.uuidString else {
            #if DEBUG
            print("DeviceFingerprintService: IDFV unavailable — returning eligible (simulator)")
            #endif
            return .eligible
        }

        let response: TrialEligibilityResponse = try await supabase
            .rpc("check_device_trial_eligibility", params: [
                "p_device_id": idfv,
                "p_user_id": userId.uuidString
            ])
            .execute()
            .value

        if response.eligible {
            return .eligible
        } else {
            return .denied(reason: response.reason)
        }
    }

    /// Marks the current device's trial as used.
    ///
    /// Call this when the user activates their paid trial so that
    /// future signups on this device are denied a free trial.
    func markTrialUsed(userId: UUID) async throws {
        guard let idfv = UIDevice.current.identifierForVendor?.uuidString else {
            #if DEBUG
            print("DeviceFingerprintService: IDFV unavailable — skipping markTrialUsed")
            #endif
            return
        }

        try await supabase
            .from("device_fingerprints")
            .update(TrialUsedUpdate(trialUsed: true))
            .eq("device_id", value: idfv)
            .eq("user_id", value: userId.uuidString)
            .execute()

        #if DEBUG
        print("DeviceFingerprintService: Trial marked as used for device \(idfv.prefix(8))…")
        #endif
    }
}
