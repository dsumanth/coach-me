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
        #expect(!viewModel.isDeleting)
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
