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

    /// Whether a bulk deletion is in progress
    var isDeleting = false

    /// Current error (if any)
    var error: SettingsError?

    /// Whether to show the error alert
    var showError = false

    // MARK: - Types

    /// Errors specific to settings operations
    enum SettingsError: LocalizedError, Equatable {
        case deleteFailed(String)
        case signOutFailed(String)

        var errorDescription: String? {
            switch self {
            case .deleteFailed(let reason):
                return "I couldn't clear your conversations. \(reason)"
            case .signOutFailed(let reason):
                return "I couldn't sign you out. \(reason)"
            }
        }
    }

    // MARK: - Dependencies

    private let conversationService: any ConversationServiceProtocol

    // MARK: - Initialization

    init(conversationService: any ConversationServiceProtocol = ConversationService.shared) {
        self.conversationService = conversationService
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

    /// Dismisses the current error
    func dismissError() {
        showError = false
        error = nil
    }
}
