//
//  ChatViewModel.swift
//  CoachMe
//
//  Created by Sumanth Daggubati on 2/6/26.
//

import Foundation

/// ViewModel for chat screen
/// Per architecture.md: Use @Observable for ViewModels (not @ObservableObject)
@MainActor
@Observable
final class ChatViewModel {
    // MARK: - Published State

    /// All messages in the current conversation
    var messages: [ChatMessage] = []

    /// Current text in the input field
    var inputText: String = ""

    /// Whether a response is being generated (initial loading before streaming)
    var isLoading = false

    /// Whether currently streaming a response
    var isStreaming = false

    /// Content being streamed (for in-progress message)
    var streamingContent: String = ""

    /// Current error (if any)
    var error: ChatError?

    /// Whether to show the error alert
    var showError = false

    /// Whether retry is available (partial content exists from failed stream)
    var canRetry: Bool {
        return !streamingContent.isEmpty && !isStreaming && !isLoading
    }

    // MARK: - Private State

    /// Current conversation identifier
    private var currentConversationId: UUID?

    /// Current in-flight send task (for cancellation)
    private var currentSendTask: Task<Void, Never>?

    /// Token buffer for smooth rendering
    private var tokenBuffer: StreamingTokenBuffer?

    /// Partial message ID (for retry support)
    private var currentStreamMessageId: UUID?

    /// Last user message content (for retry)
    private var lastUserMessageContent: String?

    // MARK: - Dependencies

    /// Chat stream service for SSE communication
    private let chatStreamService: ChatStreamService

    // MARK: - Initialization

    init(chatStreamService: ChatStreamService = ChatStreamService()) {
        self.chatStreamService = chatStreamService
        self.tokenBuffer = StreamingTokenBuffer()
        self.currentConversationId = UUID()

        setupTokenBuffer()
    }

    // MARK: - Setup

    private func setupTokenBuffer() {
        tokenBuffer?.onFlush = { [weak self] tokens in
            self?.streamingContent += tokens
        }
    }

    // MARK: - Actions

    /// Sends the current input text as a message
    func sendMessage() async {
        let trimmedInput = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return }

        guard let conversationId = currentConversationId else { return }

        // Cancel any in-flight request before starting a new one
        currentSendTask?.cancel()

        // Store for retry
        lastUserMessageContent = trimmedInput

        // Add user message immediately
        let userMessage = ChatMessage.userMessage(content: trimmedInput, conversationId: conversationId)
        messages.append(userMessage)
        inputText = ""

        // Start streaming state
        isLoading = true
        isStreaming = false
        streamingContent = ""
        tokenBuffer?.reset()

        // Create a tracked task for cancellation support
        let task = Task {
            defer {
                isLoading = false
            }

            do {
                // Refresh auth token before streaming (handles token refresh during session)
                await refreshAuthToken()

                // Start streaming after brief delay for typing indicator UX
                isStreaming = true

                for try await event in chatStreamService.streamChat(
                    message: trimmedInput,
                    conversationId: conversationId
                ) {
                    try Task.checkCancellation()

                    switch event {
                    case .token(let content):
                        tokenBuffer?.addToken(content)

                    case .done(let messageId, _):
                        tokenBuffer?.flush()
                        currentStreamMessageId = messageId

                        // Finalize message
                        let assistantMessage = ChatMessage(
                            id: messageId,
                            conversationId: conversationId,
                            role: .assistant,
                            content: streamingContent,
                            createdAt: Date()
                        )
                        messages.append(assistantMessage)
                        streamingContent = ""
                        isStreaming = false
                        lastUserMessageContent = nil  // Clear retry state on success

                    case .error(let message):
                        // Keep partial content for retry
                        tokenBuffer?.flush()
                        isStreaming = false
                        self.error = .streamError(message)
                        showError = true
                    }
                }
            } catch is CancellationError {
                tokenBuffer?.flush()
                isStreaming = false
                #if DEBUG
                print("ChatViewModel: Stream cancelled")
                #endif
            } catch {
                tokenBuffer?.flush()
                isStreaming = false
                self.error = .messageFailed(error)
                showError = true
            }
        }
        currentSendTask = task
        await task.value
    }

    /// Sends a message with the provided text (used for conversation starters)
    /// - Parameter text: The text to send
    func sendMessage(_ text: String) async {
        inputText = text
        await sendMessage()
    }

    /// Retries the last failed message
    func retryLastMessage() async {
        guard canRetry, let lastMessage = lastUserMessageContent else { return }

        // Clear the partial streaming content
        streamingContent = ""

        // Remove the last user message and re-send
        if let lastUserMessage = messages.last(where: { $0.role == .user }) {
            messages.removeAll { $0.id == lastUserMessage.id }
        }

        // Re-send
        inputText = lastMessage
        await sendMessage()
    }

    /// Dismisses the current error
    func dismissError() {
        showError = false
        error = nil
    }

    /// Starts a new conversation, clearing all messages
    func startNewConversation() {
        currentSendTask?.cancel()
        messages = []
        currentConversationId = UUID()
        inputText = ""
        streamingContent = ""
        isStreaming = false
        tokenBuffer?.reset()
        lastUserMessageContent = nil
        error = nil
        showError = false
    }

    /// Refreshes the conversation (pull-to-refresh)
    /// Will integrate with sync service in Story 7.3
    func refresh() async {
        // Placeholder for sync functionality
        // Will fetch any missed messages from server in Story 7.3
        #if DEBUG
        print("ChatViewModel: Refresh triggered - sync will be implemented in Story 7.3")
        #endif

        // Simulate a brief refresh delay for UX feedback
        try? await Task.sleep(nanoseconds: 500_000_000)
    }

    // MARK: - Auth Token Management

    /// Sets the auth token on the chat stream service
    /// - Parameter token: The JWT auth token
    func setAuthToken(_ token: String?) {
        chatStreamService.setAuthToken(token)
    }

    /// Refreshes auth token from AuthService before API calls
    /// Ensures token is current even after refresh during session
    private func refreshAuthToken() async {
        let token = await AuthService.shared.currentAccessToken
        chatStreamService.setAuthToken(token)
    }
}
