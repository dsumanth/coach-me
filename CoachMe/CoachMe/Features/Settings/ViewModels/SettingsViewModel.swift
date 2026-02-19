//
//  SettingsViewModel.swift
//  CoachMe
//
//  Created by Claude Code on 2/7/26.
//
//  Story 2.6: ViewModel for Settings screen with bulk delete functionality
//

import Foundation

/// ViewModel for the Settings screen
/// Per architecture.md: Use @Observable for ViewModels (not @ObservableObject)
@MainActor
@Observable
final class SettingsViewModel {
    // MARK: - Published State

    /// Whether to show the delete all confirmation alert
    var showDeleteAllConfirmation = false

    /// Whether to show the sign out confirmation alert
    var showSignOutConfirmation = false

    /// Whether to show the delete account confirmation alert
    var showDeleteAccountConfirmation = false

    /// Whether a bulk deletion is in progress
    var isDeleting = false

    /// Whether account deletion is in progress
    var isDeletingAccount = false

    /// Current error (if any)
    var error: SettingsError?

    /// Whether to show the error alert
    var showError = false

    /// User-selected coaching style preference
    var selectedCoachingStyle: CoachingStyleOption = .automatic

    /// Whether coaching style preference is being saved
    var isSavingCoachingStyle = false

    // MARK: - Types

    /// Errors specific to settings operations
    enum SettingsError: LocalizedError, Equatable {
        case deleteFailed(String)
        case signOutFailed(String)
        case accountDeletionFailed
        case stylePreferenceFailed(String)

        var errorDescription: String? {
            switch self {
            case .deleteFailed(let reason):
                return "I couldn't clear your conversations. \(reason)"
            case .signOutFailed(let reason):
                return "I couldn't sign you out. \(reason)"
            case .accountDeletionFailed:
                return "I couldn't remove your account right now. Please check your connection and try again."
            case .stylePreferenceFailed(let reason):
                return "I couldn't save your coaching style. \(reason)"
            }
        }
    }

    /// User-selectable coaching styles.
    enum CoachingStyleOption: String, CaseIterable, Identifiable {
        case automatic
        case direct
        case compassionate
        case challenging
        case exploratory
        case playful
        case balanced

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .automatic: return "Automatic"
            case .direct: return "Direct"
            case .compassionate: return "Compassionate"
            case .challenging: return "Challenging"
            case .exploratory: return "Exploratory"
            case .playful: return "Playful"
            case .balanced: return "Balanced"
            }
        }

        var subtitle: String {
            switch self {
            case .automatic:
                return "Use learned style from your conversation patterns."
            case .direct:
                return "Clear and action-first guidance."
            case .compassionate:
                return "Gentle, validating, and supportive guidance."
            case .challenging:
                return "Respectful pushback to stretch your thinking."
            case .exploratory:
                return "Question-led reflection and discovery."
            case .playful:
                return "Human, lightly humorous coaching with relatable examples."
            case .balanced:
                return "Even mix of support, challenge, and direction."
            }
        }

        var serverValue: String? {
            switch self {
            case .automatic:
                return nil
            case .direct:
                return "Direct"
            case .compassionate:
                return "Compassionate"
            case .challenging:
                return "Challenging"
            case .exploratory:
                return "Exploratory"
            case .playful:
                return "Playful"
            case .balanced:
                return "Balanced"
            }
        }

        static func fromServerStyle(_ value: String?) -> CoachingStyleOption {
            guard let value else { return .automatic }
            switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "":
                return .automatic
            case "direct":
                return .direct
            case "compassionate", "supportive":
                return .compassionate
            case "challenging":
                return .challenging
            case "exploratory":
                return .exploratory
            case "playful", "humorous", "human":
                return .playful
            case "balanced":
                return .balanced
            default:
                return .automatic
            }
        }
    }

    // MARK: - Dependencies

    private let conversationService: any ConversationServiceProtocol
    private let contextRepository: ContextRepositoryProtocol

    // MARK: - Initialization

    init(
        conversationService: any ConversationServiceProtocol = ConversationService.shared,
        contextRepository: ContextRepositoryProtocol = ContextRepository.shared
    ) {
        self.conversationService = conversationService
        self.contextRepository = contextRepository
    }

    // MARK: - Actions

    /// Deletes all conversations for the current user (Task 5.3)
    /// - Returns: true if deletion succeeded, false otherwise
    @discardableResult
    func deleteAllConversations() async -> Bool {
        isDeleting = true
        defer { isDeleting = false }

        do {
            try await conversationService.deleteAllConversations()
            ConversationListCache.clear()
            ChatMessageCache.clearAll()

            #if DEBUG
            print("SettingsViewModel: All conversations deleted")
            #endif

            return true
        } catch let convError as ConversationService.ConversationError {
            self.error = .deleteFailed(convError.errorDescription ?? "Please try again.")
            showError = true
            return false
        } catch {
            self.error = .deleteFailed(error.localizedDescription)
            showError = true
            return false
        }
    }

    /// Signs the user out
    /// - Returns: true if sign out succeeded, false otherwise
    @discardableResult
    func signOut() async -> Bool {
        do {
            try await AuthService.shared.signOut()

            #if DEBUG
            print("SettingsViewModel: User signed out")
            #endif

            return true
        } catch {
            self.error = .signOutFailed(error.localizedDescription)
            showError = true

            #if DEBUG
            print("SettingsViewModel: Sign out error: \(error)")
            #endif

            return false
        }
    }

    /// Deletes the user's account and all data
    /// - Returns: true if account deletion succeeded, false otherwise
    @discardableResult
    func deleteAccount() async -> Bool {
        isDeletingAccount = true
        defer { isDeletingAccount = false }

        do {
            try await AuthService.shared.deleteAccount()

            #if DEBUG
            print("SettingsViewModel: Account deleted")
            #endif

            return true
        } catch {
            self.error = .accountDeletionFailed
            showError = true

            #if DEBUG
            print("SettingsViewModel: Account deletion error: \(error)")
            #endif

            return false
        }
    }

    /// Dismisses the current error
    func dismissError() {
        showError = false
        error = nil
    }

    /// Loads the current manual coaching style override from context profile.
    func loadCoachingStylePreference() async {
        guard let userId = await AuthService.shared.currentUserId else {
            selectedCoachingStyle = .automatic
            return
        }

        do {
            let profile = try await contextRepository.fetchProfile(userId: userId)
            let manualStyle = profile.coachingPreferences.manualOverride
                ?? profile.coachingPreferences.manualOverrides?.style
            selectedCoachingStyle = CoachingStyleOption.fromServerStyle(manualStyle)
        } catch {
            // Keep UI usable; default to automatic without blocking Settings.
            selectedCoachingStyle = .automatic
        }
    }

    /// Sets a manual coaching style override, or clears it when Automatic is selected.
    @discardableResult
    func setCoachingStyle(_ style: CoachingStyleOption) async -> Bool {
        guard let userId = await AuthService.shared.currentUserId else {
            self.error = .stylePreferenceFailed("Please sign in again and retry.")
            showError = true
            return false
        }

        isSavingCoachingStyle = true
        defer { isSavingCoachingStyle = false }

        do {
            var profile = try await contextRepository.fetchProfile(userId: userId)
            profile.coachingPreferences.preferredStyle = style.serverValue
            profile.coachingPreferences.manualOverride = style.serverValue
            profile.coachingPreferences.manualOverrides = style.serverValue == nil
                ? nil
                : ManualOverrides(style: style.serverValue, setAt: Date())

            try await contextRepository.updateProfile(profile)
            selectedCoachingStyle = style
            return true
        } catch {
            self.error = .stylePreferenceFailed(error.localizedDescription)
            showError = true
            return false
        }
    }
}
