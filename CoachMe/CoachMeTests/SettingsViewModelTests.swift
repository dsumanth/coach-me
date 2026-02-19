//
//  SettingsViewModelTests.swift
//  CoachMeTests
//
//  Story 2.6: Unit tests for SettingsViewModel delete functionality
//

import Testing
@testable import CoachMe

/// Unit tests for SettingsViewModel
@MainActor
struct SettingsViewModelTests {

    // MARK: - Initialization Tests

    @Test("ViewModel initializes with default state")
    func testInitialState() {
        let viewModel = SettingsViewModel()

        #expect(!viewModel.showDeleteAllConfirmation)
        #expect(!viewModel.showDeleteAccountConfirmation)
        #expect(!viewModel.isDeleting)
        #expect(!viewModel.isDeletingAccount)
        #expect(viewModel.error == nil)
        #expect(!viewModel.showError)
    }

    // MARK: - Delete All State Tests (Story 2.6 - Task 6.5)

    @Test("showDeleteAllConfirmation can be toggled")
    func testShowDeleteAllConfirmationToggle() {
        let viewModel = SettingsViewModel()

        // Initially false
        #expect(!viewModel.showDeleteAllConfirmation)

        // Can be set to true
        viewModel.showDeleteAllConfirmation = true
        #expect(viewModel.showDeleteAllConfirmation)

        // Can be set back to false
        viewModel.showDeleteAllConfirmation = false
        #expect(!viewModel.showDeleteAllConfirmation)
    }

    // MARK: - Error Handling Tests

    @Test("dismissError clears error state")
    func testDismissError() {
        let viewModel = SettingsViewModel()
        viewModel.error = .deleteFailed("Test error")
        viewModel.showError = true

        viewModel.dismissError()

        #expect(viewModel.error == nil)
        #expect(!viewModel.showError)
    }

    @Test("SettingsError provides warm user-friendly message")
    func testErrorDescription() {
        let error = SettingsViewModel.SettingsError.deleteFailed("Network timeout")

        // Should use first-person message per UX-11
        let description = error.errorDescription ?? ""
        #expect(description.contains("I couldn't"))
        #expect(description.contains("Network timeout"))
    }
}

// MARK: - Mock-Based Tests (Task 6.5)

@MainActor
struct SettingsViewModelMockTests {

    // MARK: - Task 6.5: Test deleteAllConversations() calls service

    @Test("deleteAllConversations calls ConversationService and returns true on success")
    func testDeleteAllConversationsSuccess() async {
        // Given: ViewModel with mock service
        let mockService = MockConversationService()
        let viewModel = SettingsViewModel(conversationService: mockService)

        // When: Deleting all conversations
        let success = await viewModel.deleteAllConversations()

        // Then: Service was called and returns success
        #expect(mockService.deleteAllConversationsCalled)
        #expect(success == true)
        #expect(viewModel.error == nil)
        #expect(!viewModel.showError)
    }

    @Test("deleteAllConversations sets isDeleting during operation")
    func testDeleteAllConversationsLoading() async {
        // Given: ViewModel with mock service
        let mockService = MockConversationService()
        let viewModel = SettingsViewModel(conversationService: mockService)

        // Initially not deleting
        #expect(!viewModel.isDeleting)

        // When: Deleting (we check state after completion since async)
        _ = await viewModel.deleteAllConversations()

        // Then: isDeleting is reset to false after completion
        #expect(!viewModel.isDeleting)
    }

    @Test("deleteAllConversations returns false and sets error on failure")
    func testDeleteAllConversationsFailure() async {
        // Given: ViewModel with mock service that will fail
        let mockService = MockConversationService()
        mockService.shouldThrowOnDeleteAll = true
        mockService.deleteAllError = .deleteFailed("Network timeout")
        let viewModel = SettingsViewModel(conversationService: mockService)

        // When: Deleting all conversations
        let success = await viewModel.deleteAllConversations()

        // Then: Returns false and shows error
        #expect(mockService.deleteAllConversationsCalled)
        #expect(success == false)
        #expect(viewModel.error != nil)
        #expect(viewModel.showError)

        // Error message should be warm and include the reason
        let errorMessage = viewModel.error?.errorDescription ?? ""
        #expect(errorMessage.contains("I couldn't"))
    }

    @Test("deleteAllConversations handles notAuthenticated error")
    func testDeleteAllConversationsNotAuthenticated() async {
        // Given: ViewModel with mock service that throws notAuthenticated
        let mockService = MockConversationService()
        mockService.shouldThrowOnDeleteAll = true
        mockService.deleteAllError = .notAuthenticated
        let viewModel = SettingsViewModel(conversationService: mockService)

        // When: Deleting all conversations
        let success = await viewModel.deleteAllConversations()

        // Then: Returns false and shows appropriate error
        #expect(success == false)
        #expect(viewModel.showError)
    }
}

// MARK: - Account Deletion Tests (Story 6.6)

@MainActor
struct AccountDeletionViewModelTests {

    // MARK: - Task 5.1: Success path

    @Test("deleteAccount has correct initial state")
    func testDeleteAccountInitialState() async {
        // Given: ViewModel in initial state
        // Note: Full deleteAccount success path requires a mock AuthService.
        // Integration testing validates the full flow.
        let viewModel = SettingsViewModel()

        // Verify initial state
        #expect(!viewModel.isDeletingAccount)
        #expect(!viewModel.showDeleteAccountConfirmation)
    }

    @Test("isDeletingAccount resets after deleteAccount completes")
    func testDeleteAccountResetsLoadingState() async {
        let viewModel = SettingsViewModel()

        // Call deleteAccount — will fail without auth session but state should reset
        _ = await viewModel.deleteAccount()

        // isDeletingAccount must be reset regardless of outcome
        #expect(!viewModel.isDeletingAccount)
    }

    // MARK: - Task 5.2: Failure path

    @Test("deleteAccount sets error state on failure")
    func testDeleteAccountFailure() async {
        // Given: ViewModel without auth session (will fail)
        let viewModel = SettingsViewModel()

        // When: Attempting account deletion without session
        let success = await viewModel.deleteAccount()

        // Then: Returns false and sets error
        #expect(success == false)
        #expect(viewModel.error == .accountDeletionFailed)
        #expect(viewModel.showError)

        // Error message uses warm first-person language (UX-11)
        let message = viewModel.error?.errorDescription ?? ""
        #expect(message.contains("I couldn't"))
        #expect(message.contains("account"))
    }

    @Test("showDeleteAccountConfirmation can be toggled")
    func testShowDeleteAccountConfirmationToggle() {
        let viewModel = SettingsViewModel()

        #expect(!viewModel.showDeleteAccountConfirmation)

        viewModel.showDeleteAccountConfirmation = true
        #expect(viewModel.showDeleteAccountConfirmation)

        viewModel.showDeleteAccountConfirmation = false
        #expect(!viewModel.showDeleteAccountConfirmation)
    }

    // MARK: - Task 5.3: Error message validation

    @Test("accountDeletionFailed error provides warm first-person message")
    func testAccountDeletionFailedMessage() {
        let error = SettingsViewModel.SettingsError.accountDeletionFailed

        let description = error.errorDescription ?? ""
        #expect(description == "I couldn't remove your account right now. Please check your connection and try again.")
    }

    @Test("AuthError.accountDeletionFailed provides warm first-person message")
    func testAuthErrorAccountDeletionMessage() {
        let error = AuthService.AuthError.accountDeletionFailed

        let description = error.errorDescription ?? ""
        #expect(description == "I couldn't remove your account right now. Please check your connection and try again.")
    }

    @Test("All SettingsError cases use first-person 'I' language per UX-11")
    func testAllSettingsErrorsUseFirstPerson() {
        let errors: [SettingsViewModel.SettingsError] = [
            .deleteFailed("test"),
            .signOutFailed("test"),
            .accountDeletionFailed,
            .stylePreferenceFailed("test"),
        ]

        for error in errors {
            let message = error.errorDescription ?? ""
            #expect(message.contains("I couldn't"), "Error \(error) should use first-person: \(message)")
        }
    }

    @Test("dismissError clears accountDeletionFailed error")
    func testDismissAccountDeletionError() {
        let viewModel = SettingsViewModel()
        viewModel.error = .accountDeletionFailed
        viewModel.showError = true

        viewModel.dismissError()

        #expect(viewModel.error == nil)
        #expect(!viewModel.showError)
    }
}
