//
//  PushPermissionService.swift
//  CoachMe
//
//  Story 8.3: Push Permission Timing & Notification Preferences
//  Manages when to ask for push permission and the native iOS authorization flow.
//

import Foundation
import UIKit
import UserNotifications

/// Manages push permission timing and authorization requests.
///
/// **Design (Story 8.3):**
/// - `@MainActor` singleton matching project service pattern.
/// - Does NOT prompt on first launch (AC #1).
/// - Prompts after first session complete (AC #2).
/// - Stores permission-requested flag in UserDefaults to avoid re-prompting after denial.
@MainActor
final class PushPermissionService {
    // MARK: - Singleton

    static let shared = PushPermissionService()

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let permissionRequested = "pushPermissionRequested"
        static let promptDismissedThisSession = "pushPromptDismissedThisSession"
    }

    // MARK: - Properties

    private let defaults: UserDefaults

    // MARK: - Initialization

    private init() {
        self.defaults = .standard
    }

    /// Test-injectable initializer
    init(defaults: sending UserDefaults) {
        self.defaults = defaults
    }

    // MARK: - Public API

    /// Whether the app should show the push permission prompt.
    /// Returns true only when:
    /// 1. The user's first session is complete
    /// 2. Permission has not been requested before (UserDefaults flag)
    /// 3. The prompt hasn't been dismissed this session
    func shouldRequestPermission(firstSessionComplete: Bool) -> Bool {
        guard firstSessionComplete else { return false }
        guard !defaults.bool(forKey: Keys.permissionRequested) else { return false }
        guard !defaults.bool(forKey: Keys.promptDismissedThisSession) else { return false }
        return true
    }

    /// Requests push notification authorization from the OS.
    /// Sets the permissionRequested flag so we don't re-prompt after denial.
    /// - Returns: Whether the user granted authorization
    @discardableResult
    func requestPermissionIfNeeded() async -> Bool {
        // Mark as requested regardless of outcome
        defaults.set(true, forKey: Keys.permissionRequested)

        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])

            #if DEBUG
            print("PushPermissionService: Authorization \(granted ? "granted" : "denied")")
            #endif

            if granted {
                await registerForRemoteNotificationsIfAuthorized()
            }

            return granted
        } catch {
            #if DEBUG
            print("PushPermissionService: Authorization request failed — \(error.localizedDescription)")
            #endif
            return false
        }
    }

    /// Calls `UIApplication.registerForRemoteNotifications()` only when authorized.
    func registerForRemoteNotificationsIfAuthorized() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional
                || settings.authorizationStatus == .ephemeral else {
            #if DEBUG
            print("PushPermissionService: Not authorized (\(settings.authorizationStatus)) — skipping remote notification registration")
            #endif
            return
        }
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    /// Returns the current push authorization status.
    func currentAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    /// Marks the prompt as dismissed for this session (user tapped "Not now").
    func markPromptDismissedThisSession() {
        defaults.set(true, forKey: Keys.promptDismissedThisSession)
    }

    /// Resets the session-scoped dismissal flag.
    /// Called on app launch or new session so the prompt can appear again later.
    func resetSessionDismissal() {
        defaults.set(false, forKey: Keys.promptDismissedThisSession)
    }

    /// Repairs local request-tracking state when it drifted from system state.
    /// This can happen after account deletion/re-signin flows where local defaults
    /// survive but iOS permission is still `notDetermined`.
    func reconcileRequestedFlagWithSystem() async {
        let status = await currentAuthorizationStatus()
        guard status == .notDetermined,
              defaults.bool(forKey: Keys.permissionRequested) else {
            return
        }
        defaults.set(false, forKey: Keys.permissionRequested)
        #if DEBUG
        print("PushPermissionService: Reconciled stale permissionRequested flag to false")
        #endif
    }

    /// Whether the user has ever been asked for push permission.
    var hasBeenRequested: Bool {
        defaults.bool(forKey: Keys.permissionRequested)
    }
}
