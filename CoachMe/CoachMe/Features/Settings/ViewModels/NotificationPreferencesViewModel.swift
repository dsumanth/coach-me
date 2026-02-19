//
//  NotificationPreferencesViewModel.swift
//  CoachMe
//
//  Story 8.3: Push Permission Timing & Notification Preferences
//  ViewModel for the notification preferences settings screen.
//

import Foundation
import UserNotifications

/// ViewModel for notification preference management.
/// Per architecture.md: Use @Observable for ViewModels (not @ObservableObject)
@MainActor
@Observable
final class NotificationPreferencesViewModel {
    // MARK: - Published State

    /// Whether check-in notifications are enabled
    var checkInsEnabled: Bool = false

    /// Selected check-in frequency
    var frequency: NotificationPreference.CheckInFrequency = .fewTimesAWeek

    /// Whether saving is in progress
    var isSaving = false

    /// Whether initial load has completed (prevents onChange auto-save during load)
    @ObservationIgnored
    var hasLoaded = false

    /// Whether the OS-level push permission is denied
    var isSystemPermissionDenied = false

    /// Current error
    var error: NotificationPreferencesError?

    /// Whether to show the error alert
    var showError = false

    // MARK: - Types

    enum NotificationPreferencesError: LocalizedError, Equatable {
        case loadFailed(String)
        case saveFailed(String)

        var errorDescription: String? {
            switch self {
            case .loadFailed(let reason):
                return "I couldn't load your notification preferences. \(reason)"
            case .saveFailed(let reason):
                return "I couldn't save your notification preferences. \(reason)"
            }
        }
    }

    // MARK: - Dependencies

    private let contextRepository: ContextRepositoryProtocol
    private var userId: UUID?

    // MARK: - Initialization

    init(contextRepository: ContextRepositoryProtocol = ContextRepository.shared) {
        self.contextRepository = contextRepository
    }

    // MARK: - Actions

    /// Loads current notification preferences for the user
    func load(userId: UUID) async {
        self.userId = userId
        hasLoaded = false

        // Check system-level authorization
        let status = await PushPermissionService.shared.currentAuthorizationStatus()
        isSystemPermissionDenied = (status == .denied)

        do {
            let profile = try await contextRepository.fetchProfile(userId: userId)
            if let prefs = profile.notificationPreferences {
                checkInsEnabled = prefs.checkInsEnabled
                frequency = prefs.frequency
            } else {
                // No preferences saved yet — show defaults (off)
                checkInsEnabled = false
                frequency = .fewTimesAWeek
            }
            hasLoaded = true
        } catch {
            self.error = .loadFailed(error.localizedDescription)
            showError = true
            // hasLoaded remains false — save() should not proceed with stale data
        }
    }

    /// Saves the current preferences to the user's profile
    func save() async {
        guard let userId, hasLoaded else { return }

        isSaving = true
        defer { isSaving = false }

        do {
            var profile = try await contextRepository.fetchProfile(userId: userId)
            profile.notificationPreferences = NotificationPreference(
                checkInsEnabled: checkInsEnabled,
                frequency: frequency
            )
            try await contextRepository.updateProfile(profile)

            #if DEBUG
            print("NotificationPreferencesViewModel: Preferences saved — enabled: \(checkInsEnabled), frequency: \(frequency.rawValue)")
            #endif
        } catch {
            self.error = .saveFailed(error.localizedDescription)
            showError = true
        }
    }

    /// Dismisses the current error
    func dismissError() {
        showError = false
        error = nil
    }
}
