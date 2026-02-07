//
//  ConversationListViewModel.swift
//  CoachMe
//
//  Story 3.6: ViewModel for conversation list/history screen
//

import Foundation

/// ViewModel for the conversation list screen
/// Per architecture.md: Use @Observable for ViewModels (not @ObservableObject)
@MainActor
@Observable
final class ConversationListViewModel {
    // MARK: - Published State

    /// All conversations for the current user, sorted by most recent
    var conversations: [ConversationService.Conversation] = []

    /// Whether conversations are being loaded
    var isLoading = false

    /// Current error (if any)
    var error: ConversationService.ConversationError?

    /// Whether to show the error alert
    var showError = false

    /// Conversation pending deletion (for confirmation)
    var conversationToDelete: ConversationService.Conversation?

    /// Whether to show the delete confirmation alert
    var showDeleteConfirmation = false

    /// Whether a deletion is in progress
    var isDeleting = false

    // MARK: - Dependencies

    private let conversationService: any ConversationServiceProtocol

    // MARK: - Initialization

    init(conversationService: any ConversationServiceProtocol = ConversationService.shared) {
        self.conversationService = conversationService
    }

    // MARK: - Actions

    /// Loads all conversations for the current user
    func loadConversations() async {
        isLoading = true
        defer { isLoading = false }

        do {
            conversations = try await conversationService.fetchConversations()
            error = nil
        } catch let convError as ConversationService.ConversationError {
            self.error = convError
            showError = true
        } catch {
            self.error = .fetchFailed(error.localizedDescription)
            showError = true
        }
    }

    /// Refreshes conversations (pull-to-refresh)
    func refreshConversations() async {
        do {
            conversations = try await conversationService.fetchConversations()
            error = nil
        } catch let convError as ConversationService.ConversationError {
            self.error = convError
            showError = true
        } catch {
            self.error = .fetchFailed(error.localizedDescription)
            showError = true
        }
    }

    /// Requests deletion of a conversation (shows confirmation first)
    /// - Parameter conversation: The conversation to delete
    func requestDelete(_ conversation: ConversationService.Conversation) {
        conversationToDelete = conversation
        showDeleteConfirmation = true
    }

    /// Confirms and executes the pending deletion
    func confirmDelete() async {
        guard let conversation = conversationToDelete else { return }

        isDeleting = true
        defer {
            isDeleting = false
            conversationToDelete = nil
        }

        do {
            try await conversationService.deleteConversation(id: conversation.id)
            conversations.removeAll { $0.id == conversation.id }
        } catch let convError as ConversationService.ConversationError {
            self.error = convError
            showError = true
        } catch {
            self.error = .deleteFailed(error.localizedDescription)
            showError = true
        }
    }

    /// Cancels the pending deletion
    func cancelDelete() {
        conversationToDelete = nil
        showDeleteConfirmation = false
    }

    /// Dismisses the current error
    func dismissError() {
        showError = false
        error = nil
    }
}
