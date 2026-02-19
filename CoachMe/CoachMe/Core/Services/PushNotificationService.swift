//
//  PushNotificationService.swift
//  CoachMe
//
//  Story 8.2 — APNs push infrastructure
//

import Foundation
import UIKit
import UserNotifications
import Supabase

/// Manages APNs device-token registration and removal.
///
/// **Design constraints (Story 8.2):**
/// - `@MainActor` singleton matching the project service pattern.
/// - Does NOT prompt for push permission (that is Story 8.3).
/// - Token registration is fire-and-forget — never blocks the UI.
/// - Uses Supabase upsert on (`user_id`, `device_token`) for idempotent writes.
@MainActor
final class PushNotificationService {
    // MARK: - Singleton

    static let shared = PushNotificationService()

    // MARK: - Types

    enum PushError: LocalizedError {
        case notAuthenticated
        case registrationFailed(String)
        case removalFailed(String)

        var errorDescription: String? {
            switch self {
            case .notAuthenticated:
                return "You'll need to sign in before I can set up notifications."
            case .registrationFailed(let reason):
                return "I couldn't register for notifications right now. \(reason)"
            case .removalFailed(let reason):
                return "I couldn't remove your notification registration. \(reason)"
            }
        }
    }

    /// Minimal insert/upsert model for the `push_tokens` table.
    private struct PushTokenUpsert: Encodable {
        let userId: UUID
        let deviceToken: String
        let platform: String

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case deviceToken = "device_token"
            case platform
        }
    }

    // MARK: - Properties

    private let supabase: SupabaseClient

    /// Hex-encoded device token from the most recent registration.
    private(set) var currentDeviceToken: String?

    // MARK: - Initialization

    private init() {
        self.supabase = AppEnvironment.shared.supabase
    }

    /// Test-injectable initializer.
    init(supabase: SupabaseClient) {
        self.supabase = supabase
    }

    // MARK: - Public API

    /// Converts raw APNs token data to a hex string and upserts it into Supabase.
    ///
    /// Called from `AppDelegate.application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`.
    func registerDeviceToken(_ tokenData: Data) async {
        let hexToken = tokenData.map { String(format: "%02x", $0) }.joined()
        currentDeviceToken = hexToken

        guard let userId = try? await supabase.auth.session.user.id else {
            #if DEBUG
            print("PushNotificationService: No auth session — skipping token registration")
            #endif
            return
        }

        let row = PushTokenUpsert(userId: userId, deviceToken: hexToken, platform: "ios")

        do {
            try await supabase
                .from("push_tokens")
                .upsert(row, onConflict: "user_id,device_token")
                .execute()

            #if DEBUG
            print("PushNotificationService: Token registered (\(hexToken.prefix(8))…)")
            #endif
        } catch {
            #if DEBUG
            print("PushNotificationService: Token registration failed — \(error.localizedDescription)")
            #endif
        }
    }

    /// Returns the current push-notification authorization status without prompting.
    func checkCurrentAuthorization() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    /// Calls `UIApplication.registerForRemoteNotifications()` **only** if the user
    /// has already granted push permission. Does nothing otherwise.
    func registerForRemoteNotificationsIfAuthorized() async {
        let status = await checkCurrentAuthorization()
        guard status == .authorized else {
            #if DEBUG
            print("PushNotificationService: Not authorized (\(status.rawValue)) — skipping registration")
            #endif
            return
        }
        UIApplication.shared.registerForRemoteNotifications()
    }

    /// Logs a registration failure. Non-fatal by design.
    func handleRegistrationError(_ error: Error) {
        #if DEBUG
        print("PushNotificationService: Remote notification registration failed — \(error.localizedDescription)")
        #endif
    }

    /// Deletes this device's push token from Supabase.
    /// Call on sign-out so the server stops sending pushes to this device.
    /// If no current token is known (e.g., token was never registered in this
    /// session), falls back to removing all tokens for the user.
    func removeDeviceToken() async {
        guard let userId = try? await supabase.auth.session.user.id else {
            #if DEBUG
            print("PushNotificationService: No auth session — skipping token removal")
            #endif
            return
        }

        do {
            if let token = currentDeviceToken {
                // Remove only this device's token — preserves tokens on other devices
                try await supabase
                    .from("push_tokens")
                    .delete()
                    .eq("user_id", value: userId.uuidString)
                    .eq("device_token", value: token)
                    .execute()

                currentDeviceToken = nil

                #if DEBUG
                print("PushNotificationService: Device token removed for user \(userId)")
                #endif
            } else {
                // No known token for this session — log and skip
                // Avoids accidentally deleting tokens from other devices
                #if DEBUG
                print("PushNotificationService: No current device token — skipping removal for user \(userId)")
                #endif
            }
        } catch {
            #if DEBUG
            print("PushNotificationService: Token removal failed — \(error.localizedDescription)")
            #endif
        }
    }
}
