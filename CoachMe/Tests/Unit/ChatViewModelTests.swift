//
//  ChatViewModelTests.swift
//  CoachMeTests
//
//  Created by Code Review on 2/6/26.
//

import Testing
@testable import CoachMe

/// Unit tests for ChatViewModel
@MainActor
struct ChatViewModelTests {

    // MARK: - Initialization Tests

    @Test("ViewModel initializes with empty state")
    func testInitialState() {
        let viewModel = ChatViewModel()

        #expect(viewModel.messages.isEmpty)
        #expect(viewModel.inputText.isEmpty)
        #expect(!viewModel.isLoading)
        #expect(viewModel.error == nil)
        #expect(!viewModel.showError)
    }

    // MARK: - Send Message Tests

    @Test("sendMessage does nothing with empty input")
    func testSendMessageEmptyInput() async {
        let viewModel = ChatViewModel()
        viewModel.inputText = "   "

        await viewModel.sendMessage()

        #expect(viewModel.messages.isEmpty)
    }

    @Test("sendMessage adds user message immediately")
    func testSendMessageAddsUserMessage() async {
        let viewModel = ChatViewModel()
        viewModel.inputText = "Hello coach"

        // Start the task but don't wait for mock response
        let task = Task {
            await viewModel.sendMessage()
        }

        // Give it a moment to add the user message
        try? await Task.sleep(nanoseconds: 100_000_000)

        #expect(viewModel.messages.count >= 1)
        #expect(viewModel.messages.first?.content == "Hello coach")
        #expect(viewModel.messages.first?.role == .user)
        #expect(viewModel.inputText.isEmpty)

        task.cancel()
    }

    @Test("sendMessage clears input text")
    func testSendMessageClearsInput() async {
        let viewModel = ChatViewModel()
        viewModel.inputText = "Test message"

        let task = Task {
            await viewModel.sendMessage()
        }

        try? await Task.sleep(nanoseconds: 100_000_000)

        #expect(viewModel.inputText.isEmpty)

        task.cancel()
    }

    // MARK: - New Conversation Tests

    @Test("startNewConversation clears all state")
    func testStartNewConversation() async {
        let viewModel = ChatViewModel()
        viewModel.inputText = "Test"

        // Add a message first
        await viewModel.sendMessage()

        // Now start new conversation
        viewModel.startNewConversation()

        #expect(viewModel.messages.isEmpty)
        #expect(viewModel.inputText.isEmpty)
        #expect(viewModel.error == nil)
        #expect(!viewModel.showError)
    }

    // MARK: - Error Handling Tests

    @Test("dismissError clears error state")
    func testDismissError() {
        let viewModel = ChatViewModel()
        viewModel.error = .networkUnavailable
        viewModel.showError = true

        viewModel.dismissError()

        #expect(viewModel.error == nil)
        #expect(!viewModel.showError)
    }

    // MARK: - Conversation Starter Tests

    @Test("sendMessage with text parameter works")
    func testSendMessageWithText() async {
        let viewModel = ChatViewModel()

        let task = Task {
            await viewModel.sendMessage("I've been feeling stuck lately...")
        }

        try? await Task.sleep(nanoseconds: 100_000_000)

        #expect(viewModel.messages.count >= 1)
        #expect(viewModel.messages.first?.content == "I've been feeling stuck lately...")

        task.cancel()
    }
}
