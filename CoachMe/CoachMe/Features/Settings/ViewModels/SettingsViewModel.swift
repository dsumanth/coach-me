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

        var errorDescription: String? {
            switch self {
            case .deleteFailed(let reason):
                return "I couldn't clear your conversations. \(reason)"
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

    /// Dismisses the current error
    func dismissError() {
        showError = false
        error = nil
    }
}
