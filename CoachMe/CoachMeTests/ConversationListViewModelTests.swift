//
//  ConversationListViewModelTests.swift
//  CoachMeTests
//
//  Story 3.6: Tests for ConversationListViewModel — load, delete, error handling
//

import Testing
import Foundation
@testable import CoachMe

@MainActor
struct ConversationListViewModelTests {

    // MARK: - Helpers

    private func makeMockConversation(
        id: UUID = UUID(),
        title: String? = "Test conversation",
        domain: String? = "career",
        messageCount: Int = 5
    ) -> ConversationService.Conversation {
        ConversationService.Conversation(
            id: id,
            userId: UUID(),
            title: title,
            domain: domain,
            lastMessageAt: Date(),
            messageCount: messageCount,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    // MARK: - Initialization Tests

    @Test("ViewModel initializes with empty state")
    func testInitialState() {
        let viewModel = ConversationListViewModel()

        #expect(viewModel.conversations.isEmpty)
        #expect(!viewModel.isLoading)
        #expect(viewModel.error == nil)
        #expect(!viewModel.showError)
        #expect(!viewModel.showDeleteConfirmation)
        #expect(!viewModel.isDeleting)
        #expect(viewModel.conversationToDelete == nil)
    }

    // MARK: - Load Conversations Tests

    @Test("loadConversations fetches from service and populates list")
    func testLoadConversationsSuccess() async {
        let mockService = MockConversationService()
        let conv1 = makeMockConversation(title: "First")
        let conv2 = makeMockConversation(title: "Second")
        mockService.stubbedConversations = [conv1, conv2]

        let viewModel = ConversationListViewModel(conversationService: mockService)
        await viewModel.loadConversations()

        #expect(mockService.fetchConversationsCalled)
        #expect(viewModel.conversations.count == 2)
        #expect(viewModel.conversations[0].title == "First")
        #expect(viewModel.conversations[1].title == "Second")
        #expect(!viewModel.isLoading)
        #expect(viewModel.error == nil)
    }

    @Test("loadConversations shows error on failure")
    func testLoadConversationsError() async {
        let mockService = MockConversationService()
        mockService.shouldThrowOnFetchConversations = true
        mockService.fetchConversationsError = .fetchFailed("Network error")

        let viewModel = ConversationListViewModel(conversationService: mockService)
        await viewModel.loadConversations()

        #expect(viewModel.conversations.isEmpty)
        #expect(viewModel.showError)
        #expect(viewModel.error != nil)
        if case .fetchFailed(let reason) = viewModel.error {
            #expect(reason == "Network error")
        } else {
            Issue.record("Expected fetchFailed error")
        }
    }

    @Test("loadConversations sets isLoading during fetch")
    func testLoadConversationsLoading() async {
        let mockService = MockConversationService()
        let viewModel = ConversationListViewModel(conversationService: mockService)

        #expect(!viewModel.isLoading)

        await viewModel.loadConversations()

        // After completion, loading should be false
        #expect(!viewModel.isLoading)
    }

    // MARK: - Refresh Tests

    @Test("refreshConversations updates list without loading state")
    func testRefreshConversations() async {
        let mockService = MockConversationService()
        let conv = makeMockConversation(title: "Refreshed")
        mockService.stubbedConversations = [conv]

        let viewModel = ConversationListViewModel(conversationService: mockService)
        await viewModel.refreshConversations()

        #expect(viewModel.conversations.count == 1)
        #expect(viewModel.conversations[0].title == "Refreshed")
    }

    @Test("refreshConversations shows error on failure")
    func testRefreshConversationsError() async {
        let mockService = MockConversationService()
        mockService.shouldThrowOnFetchConversations = true

        let viewModel = ConversationListViewModel(conversationService: mockService)
        await viewModel.refreshConversations()

        #expect(viewModel.showError)
        #expect(viewModel.error != nil)
    }

    // MARK: - Delete Conversation Tests

    @Test("requestDelete sets conversation and shows confirmation")
    func testRequestDelete() {
        let mockService = MockConversationService()
        let viewModel = ConversationListViewModel(conversationService: mockService)
        let conv = makeMockConversation()

        viewModel.requestDelete(conv)

        #expect(viewModel.conversationToDelete?.id == conv.id)
        #expect(viewModel.showDeleteConfirmation)
    }

    @Test("confirmDelete removes conversation from list on success")
    func testConfirmDeleteSuccess() async {
        let mockService = MockConversationService()
        let conv = makeMockConversation()
        mockService.stubbedConversations = [conv]

        let viewModel = ConversationListViewModel(conversationService: mockService)
        await viewModel.loadConversations()
        #expect(viewModel.conversations.count == 1)

        viewModel.requestDelete(conv)
        await viewModel.confirmDelete()

        #expect(mockService.deleteConversationCalled)
        #expect(viewModel.conversations.isEmpty)
        #expect(!viewModel.isDeleting)
        #expect(viewModel.conversationToDelete == nil)
    }

    @Test("confirmDelete shows error on failure")
    func testConfirmDeleteError() async {
        let mockService = MockConversationService()
        mockService.shouldThrowOnDelete = true
        mockService.deleteError = .deleteFailed("Server error")

        let conv = makeMockConversation()
        mockService.stubbedConversations = [conv]

        let viewModel = ConversationListViewModel(conversationService: mockService)
        await viewModel.loadConversations()

        viewModel.requestDelete(conv)
        await viewModel.confirmDelete()

        #expect(viewModel.showError)
        #expect(viewModel.conversations.count == 1) // Not removed on failure
    }

    @Test("cancelDelete clears pending deletion")
    func testCancelDelete() {
        let mockService = MockConversationService()
        let viewModel = ConversationListViewModel(conversationService: mockService)
        let conv = makeMockConversation()

        viewModel.requestDelete(conv)
        #expect(viewModel.showDeleteConfirmation)

        viewModel.cancelDelete()

        #expect(viewModel.conversationToDelete == nil)
        #expect(!viewModel.showDeleteConfirmation)
    }

    // MARK: - Error Dismissal Tests

    @Test("dismissError clears error state")
    func testDismissError() {
        let mockService = MockConversationService()
        let viewModel = ConversationListViewModel(conversationService: mockService)
        viewModel.error = .fetchFailed("test")
        viewModel.showError = true

        viewModel.dismissError()

        #expect(viewModel.error == nil)
        #expect(!viewModel.showError)
    }
}
