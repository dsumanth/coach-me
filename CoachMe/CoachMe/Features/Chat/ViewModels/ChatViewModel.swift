//
//  ChatViewModel.swift
//  CoachMe
//
//  Created by Sumanth Daggubati on 2/6/26.
//
//  Story 2.4: Updated to track memory moments from streaming responses (AC #4)
//  Story 3.4: Updated to track pattern insights from streaming responses
//  Story 4.1: Updated to track crisis detection flag from streaming responses
//

import Foundation
import UIKit  // For UIAccessibility announcements

/// ViewModel for chat screen
/// Per architecture.md: Use @Observable for ViewModels (not @ObservableObject)
/// Story 2.4: Tracks memory moments detected during streaming
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

    /// Story 2.4: Whether the current streaming response contains memory moments
    /// Note: Currently tracked for state consistency. Can be used in future to:
    /// - Show a "personalized response" indicator in the UI
    /// - Track analytics on memory moment frequency
    /// - Trigger haptic feedback when memory is referenced
    var currentResponseHasMemoryMoments = false

    /// Story 3.4: Whether the current streaming response contains pattern insights
    var currentResponseHasPatternInsights = false

    /// Story 4.1: Whether the current streaming response has a crisis detection flag
    /// Consumed by Story 4.2 (CrisisResourceSheet) to present crisis resources
    var currentResponseHasCrisisFlag = false

    /// Story 4.2: Controls presentation of the crisis resource sheet
    /// Set when streaming ends with crisis flag; dismissed by user
    var showCrisisResources = false

    /// Current error (if any)
    var error: ChatError?

    /// Whether to show the error alert
    var showError = false

    /// Whether to show the delete confirmation alert (Story 2.6)
    var showDeleteConfirmation = false

    /// Whether a deletion is in progress (Story 2.6)
    var isDeleting = false

    /// Whether retry is available (partial content exists from failed stream)
    var canRetry: Bool {
        return !streamingContent.isEmpty && !isStreaming && !isLoading
    }

    // MARK: - Private State

    /// Current conversation identifier
    private(set) var currentConversationId: UUID?

    /// Whether the current conversation has been persisted to DB
    private var isConversationPersisted = false

    /// Current in-flight send task (for cancellation)
    private var currentSendTask: Task<Void, Never>?

    /// Token buffer for smooth rendering
    private var tokenBuffer: StreamingTokenBuffer?

    /// Partial message ID (for retry support)
    private var currentStreamMessageId: UUID?

    /// Last user message content (for retry)
    private var lastUserMessageContent: String?

    /// User message IDs that failed to send and should show inline retry UI
    private var failedUserMessageIDs: Set<UUID> = []

    // MARK: - Dependencies

    /// Chat stream service for SSE communication
    private let chatStreamService: ChatStreamService

    /// Conversation service for database operations
    private let conversationService: any ConversationServiceProtocol

    // MARK: - Initialization

    init(
        chatStreamService: ChatStreamService = ChatStreamService(),
        conversationService: any ConversationServiceProtocol = ConversationService.shared
    ) {
        self.chatStreamService = chatStreamService
        self.conversationService = conversationService
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
        persistCurrentConversationCache()
        failedUserMessageIDs.remove(userMessage.id)
        inputText = ""

        // Start streaming state
        isLoading = true
        isStreaming = false
        streamingContent = ""
        currentResponseHasMemoryMoments = false  // Story 2.4: Reset memory moment tracking
        currentResponseHasPatternInsights = false  // Story 3.4: Reset pattern insight tracking
        currentResponseHasCrisisFlag = false  // Story 4.1: Reset crisis flag tracking
        showError = false
        tokenBuffer?.reset()

        // Create a tracked task for cancellation support
        let task = Task {
            defer {
                isLoading = false
            }

            do {
                // Refresh auth token before streaming (handles token refresh during session)
                await refreshAuthToken()

                // Ensure conversation exists in database before sending (P0 fix)
                if !isConversationPersisted {
                    _ = try await conversationService.ensureConversationExists(id: conversationId)
                    isConversationPersisted = true

                    // Set conversation title from first user message
                    let title = String(trimmedInput.prefix(50))
                    await conversationService.updateConversation(id: conversationId, title: title)
                }

                // Start streaming after brief delay for typing indicator UX
                isStreaming = true

                for try await event in chatStreamService.streamChat(
                    message: trimmedInput,
                    conversationId: conversationId
                ) {
                    try Task.checkCancellation()

                    switch event {
                    case .token(let content, let hasMemoryMoment, let hasPatternInsight, let hasCrisisFlag):
                        tokenBuffer?.addToken(content)
                        // Story 2.4: Track if response contains memory moments (AC #4)
                        if hasMemoryMoment {
                            currentResponseHasMemoryMoments = true
                        }
                        // Story 3.4: Track if response contains pattern insights
                        if hasPatternInsight {
                            currentResponseHasPatternInsights = true
                        }
                        // Story 4.1: Track if crisis was detected in user message
                        if hasCrisisFlag {
                            currentResponseHasCrisisFlag = true
                        }

                    case .done(let messageId, _):
                        tokenBuffer?.flush()
                        currentStreamMessageId = messageId

                        // Only create assistant message if we received actual content
                        // Prevents blank bubbles from empty LLM responses
                        if !streamingContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            let assistantMessage = ChatMessage(
                                id: messageId,
                                conversationId: conversationId,
                                role: .assistant,
                                content: streamingContent,
                                createdAt: Date()
                            )
                            messages.append(assistantMessage)
                            persistCurrentConversationCache()
                            lastUserMessageContent = nil  // Clear retry state on success
                            error = nil
                        } else {
                            // Empty response — treat as a retryable failure
                            #if DEBUG
                            print("ChatViewModel: Empty assistant response, treating as failure")
                            #endif
                            self.error = .streamError("Coach's response was empty. Let's try again.")
                            markUserMessageFailed(userMessage.id)
                        }
                        streamingContent = ""
                        isStreaming = false

                    case .error(let message):
                        tokenBuffer?.flush()
                        isStreaming = false
                        streamingContent = ""
                        self.error = .streamError(message)
                        markUserMessageFailed(userMessage.id)
                    }
                }

                // Safety: ensure isStreaming is reset if stream ended without .done event
                // This handles edge cases like malformed done events or unexpected stream termination
                if isStreaming {
                    tokenBuffer?.flush()
                    isStreaming = false

                    // If we have meaningful partial content, create a message from it
                    // Short fragments (< 20 chars) are likely incomplete words/tokens, not useful to display
                    if streamingContent.count > 20 {
                        let assistantMessage = ChatMessage(
                            id: currentStreamMessageId ?? UUID(),
                            conversationId: conversationId,
                            role: .assistant,
                            content: streamingContent + "…",
                            createdAt: Date()
                        )
                        messages.append(assistantMessage)
                        persistCurrentConversationCache()
                        streamingContent = ""
                        lastUserMessageContent = nil
                    } else {
                        // Discard fragment; allow retry of original message
                        streamingContent = ""
                    }
                }
            } catch is CancellationError {
                tokenBuffer?.flush()
                isStreaming = false
                #if DEBUG
                print("ChatViewModel: Stream cancelled")
                #endif
            } catch let convError as ConversationService.ConversationError {
                // Handle conversation-specific errors
                tokenBuffer?.flush()
                isStreaming = false
                if case .notAuthenticated = convError {
                    self.error = .sessionExpired
                    showError = true
                } else {
                    self.error = .messageFailed(convError)
                    markUserMessageFailed(userMessage.id)
                }
                streamingContent = ""
            } catch let streamError as ChatStreamError {
                // Handle stream-specific errors with proper mapping
                tokenBuffer?.flush()
                isStreaming = false
                if case .httpError(let statusCode) = streamError, statusCode == 401 {
                    self.error = .sessionExpired
                    showError = true
                } else {
                    self.error = .messageFailed(streamError)
                    markUserMessageFailed(userMessage.id)
                }
                streamingContent = ""
            } catch {
                tokenBuffer?.flush()
                isStreaming = false
                self.error = .messageFailed(error)
                markUserMessageFailed(userMessage.id)
                streamingContent = ""
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
            persistCurrentConversationCache()
        }

        // Re-send
        inputText = lastMessage
        await sendMessage()
    }

    /// Returns true when a specific user message failed delivery and should show retry UI.
    func isMessageDeliveryFailed(_ messageID: UUID) -> Bool {
        failedUserMessageIDs.contains(messageID)
    }

    /// Retries sending a specific failed user message (iMessage-style inline retry).
    func retryFailedMessage(_ messageID: UUID) async {
        guard let failedMessage = messages.first(where: { $0.id == messageID && $0.role == .user }) else {
            return
        }

        guard failedUserMessageIDs.contains(messageID) else { return }

        failedUserMessageIDs.remove(messageID)
        messages.removeAll { $0.id == messageID }
        persistCurrentConversationCache()
        inputText = failedMessage.content
        await sendMessage()
    }

    /// Dismisses the current error
    func dismissError() {
        showError = false
        error = nil
    }

    /// Starts a new conversation, clearing all messages
    func startNewConversation() {
        resetStateForConversation(id: UUID(), isPersisted: false)
        messages = []
    }

    /// Loads an existing conversation by fetching its messages (Story 3.6)
    /// - Parameter id: The conversation ID to load
    func loadConversation(id: UUID, alreadyPrimedFromCache: Bool = false) async {
        resetStateForConversation(id: id, isPersisted: true)

        var hasCachedMessages = alreadyPrimedFromCache && !messages.isEmpty

        if !alreadyPrimedFromCache {
            isLoading = true

            // Instant render path: load local cache first.
            let cachedMessages = ChatMessageCache.load(conversationId: id) ?? []
            hasCachedMessages = !cachedMessages.isEmpty
            messages = cachedMessages
            if hasCachedMessages {
                // Keep thread interactive while cloud sync runs in background.
                isLoading = false
            }
        } else {
            // Already showing cache-preloaded content from caller.
            isLoading = false
        }

        defer { isLoading = false }

        do {
            messages = try await conversationService.fetchMessages(conversationId: id)
            persistCurrentConversationCache()
        } catch let convError as ConversationService.ConversationError {
            // If cache is already shown, avoid interrupting with an alert.
            if !hasCachedMessages {
                self.error = .messageFailed(convError)
                showError = true
            }
        } catch {
            if !hasCachedMessages {
                self.error = .messageFailed(error)
                showError = true
            }
        }
    }

    /// Preloads a conversation from local cache synchronously for push transition smoothness.
    /// - Returns: true when cached messages were found and applied.
    @discardableResult
    func primeConversationFromCache(id: UUID) -> Bool {
        resetStateForConversation(id: id, isPersisted: true)

        let cachedMessages = ChatMessageCache.load(conversationId: id) ?? []
        messages = cachedMessages
        return !cachedMessages.isEmpty
    }

    /// Preloads a conversation from caller-provided messages for zero-latency route opens.
    /// - Returns: true when non-empty messages were applied.
    @discardableResult
    func primeConversationFromPreloaded(id: UUID, messages preloadedMessages: [ChatMessage]) -> Bool {
        resetStateForConversation(id: id, isPersisted: true)

        messages = preloadedMessages
        if !preloadedMessages.isEmpty {
            persistCurrentConversationCache()
            return true
        }

        return false
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

    // MARK: - Conversation Deletion (Story 2.6)

    /// Deletes the current conversation and resets to empty state
    /// - Returns: true if deletion succeeded, false otherwise
    @discardableResult
    func deleteConversation() async -> Bool {
        guard let conversationId = currentConversationId, isConversationPersisted else {
            // Conversation was never saved to DB, just start fresh
            if let conversationId = currentConversationId {
                ChatMessageCache.remove(conversationId: conversationId)
            }
            startNewConversation()
            // Announce for VoiceOver users
            UIAccessibility.post(notification: .announcement, argument: "Conversation removed")
            return true
        }

        isDeleting = true
        defer { isDeleting = false }

        do {
            try await conversationService.deleteConversation(id: conversationId)
            ChatMessageCache.remove(conversationId: conversationId)

            #if DEBUG
            print("ChatViewModel: Conversation deleted, starting fresh")
            #endif

            // Reset to empty state (Task 2.3)
            startNewConversation()

            // Announce deletion completion for VoiceOver users (Story 2.6 - Accessibility)
            UIAccessibility.post(notification: .announcement, argument: "Conversation removed")

            return true
        } catch let convError as ConversationService.ConversationError {
            // Handle conversation-specific errors with warm messages (Task 2.4)
            self.error = .messageFailed(convError)
            showError = true
            return false
        } catch {
            self.error = .messageFailed(error)
            showError = true
            return false
        }
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

        #if DEBUG
        if let token = token {
            print("ChatViewModel: Auth token refreshed (length: \(token.count))")
        } else {
            print("ChatViewModel: WARNING - No auth token available!")
        }
        #endif

        chatStreamService.setAuthToken(token)
    }

    /// Resets all chat state for loading a new or existing conversation.
    private func resetStateForConversation(id: UUID, isPersisted: Bool) {
        currentSendTask?.cancel()
        currentStreamMessageId = nil
        currentConversationId = id
        isConversationPersisted = isPersisted
        inputText = ""
        streamingContent = ""
        isStreaming = false
        isLoading = false
        currentResponseHasMemoryMoments = false
        currentResponseHasPatternInsights = false
        currentResponseHasCrisisFlag = false
        showCrisisResources = false
        tokenBuffer?.reset()
        lastUserMessageContent = nil
        failedUserMessageIDs.removeAll()
        error = nil
        showError = false
    }

    /// Marks a user message as failed so UI can show inline retry instead of an alert popup.
    private func markUserMessageFailed(_ messageID: UUID) {
        failedUserMessageIDs.insert(messageID)
        showError = false
        isLoading = false
        isStreaming = false
    }

    /// Persists in-memory messages for the current conversation so thread opens instantly next time.
    private func persistCurrentConversationCache() {
        guard let conversationId = currentConversationId else { return }
        ChatMessageCache.save(messages: messages, conversationId: conversationId)
    }
}
