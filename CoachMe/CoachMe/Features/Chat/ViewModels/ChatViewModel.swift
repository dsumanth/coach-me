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

    /// Story 10.1: Whether the user is rate limited (send button disabled, warm message shown)
    var isRateLimited = false

    /// Whether to show the paywall sheet (Story 6.3 — Task 4.2)
    /// Set when a gated user attempts to send a message.
    var showPaywall = false

    /// Message content queued for sending after a successful purchase (Story 6.3 — Task 4.4)
    var pendingMessage: String?

    /// Story 11.3: Whether this chat is in discovery mode (onboarding conversation)
    var isDiscoveryMode = false

    /// Story 11.3: Whether the discovery conversation has been completed (server signaled)
    var discoveryComplete = false

    /// Story 11.5: Discovery context for personalized paywall copy generation
    var discoveryPaywallContext: DiscoveryPaywallContext?

    /// Story 11.5: Whether the user has dismissed the personalized paywall without subscribing
    var discoveryPaywallDismissed = false

    /// Story 8.3: Whether to show the push permission prompt
    var showPushPermissionPrompt = false

    /// Whether to show the delete confirmation alert (Story 2.6)
    var showDeleteConfirmation = false

    /// Whether a deletion is in progress (Story 2.6)
    var isDeleting = false

    /// Story 10.3: Whether the user is blocked (discovery complete, no subscription, no trial)
    /// When blocked, messages are read-only and input is disabled.
    var isTrialBlocked: Bool {
        TrialManager.shared.isBlocked
    }

    /// Story 11.5: Whether to show the personalized paywall overlay (Task 4.3)
    /// True when discovery is complete, user is not subscribed, and hasn't dismissed the paywall
    var showPersonalizedPaywall: Bool {
        discoveryComplete && !AppEnvironment.shared.subscriptionViewModel.isSubscribed && !discoveryPaywallDismissed
    }

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

    /// Story 8.1: Timestamp of first message in current session (for duration calculation)
    private var sessionStartTime: Date?

    /// Story 8.5: Track recently signaled conversation IDs to prevent double-signaling within 1-hour window
    private static var recentlySignaledConversations: [UUID: Date] = [:]

    /// Active ViewModels with in-flight streams, keyed by conversation ID.
    /// Allows ChatView to reuse a ViewModel when the user navigates back
    /// to a conversation that was mid-stream, preventing lost AI responses.
    private static var activeStreamViewModels: [UUID: ChatViewModel] = [:]

    /// Returns an actively streaming ViewModel for the given conversation, if one exists.
    static func activeViewModel(for conversationId: UUID) -> ChatViewModel? {
        guard let vm = activeStreamViewModels[conversationId],
              vm.isStreaming || vm.isLoading else {
            activeStreamViewModels[conversationId] = nil
            return nil
        }
        return vm
    }

    /// Story 8.3: Timer tracking inactivity for push permission prompt trigger
    @ObservationIgnored
    private var inactivityTimer: Task<Void, Never>?

    /// Story 8.3: Minimum messages before considering a session "complete" for push prompt.
    /// Reduced to one user/assistant exchange so prompt is not missed in shorter sessions.
    static let sessionCompleteMessageThreshold = 2

    /// Story 8.3: Inactivity duration (seconds) before triggering session-complete
    private static let inactivityTriggerSeconds: TimeInterval = 300 // 5 minutes

    /// Story 7.3: Task observing offline sync completion notifications
    @ObservationIgnored
    private var syncTask: Task<Void, Never>?

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
        setupSyncObserver()
    }

    deinit {
        syncTask?.cancel()
    }

    // MARK: - Setup

    private func setupTokenBuffer() {
        tokenBuffer?.onFlush = { [weak self] tokens in
            self?.streamingContent += tokens
        }
    }

    /// Story 7.3: Observe sync completion to refresh current conversation
    private func setupSyncObserver() {
        syncTask = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .offlineSyncCompleted) {
                guard let self else { return }
                await self.refresh()
            }
        }
    }

    // MARK: - Actions

    /// Sends the current input text as a message
    /// Story 6.3: Gates chat access behind subscription check (Task 4.1)
    func sendMessage() async {
        let trimmedInput = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return }

        // Story 10.3: Check TrialManager blocked state (post-discovery, no subscription)
        if TrialManager.shared.isBlocked {
            pendingMessage = trimmedInput
            inputText = ""
            showPaywall = true
            return
        }

        // Story 6.3 — Task 4.1/4.2: Check subscription before sending
        let subscriptionVM = AppEnvironment.shared.subscriptionViewModel
        if subscriptionVM.shouldGateChat {
            pendingMessage = trimmedInput
            inputText = ""
            showPaywall = true
            return
        }

        // Story 11.5: Discovery-specific gating — after paywall dismissed but user hasn't subscribed
        if discoveryPaywallDismissed && !subscriptionVM.isSubscribed {
            pendingMessage = trimmedInput
            inputText = ""
            showPaywall = true
            return
        }

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

        // Story 8.1: Track session start time on first message
        if sessionStartTime == nil {
            sessionStartTime = Date()
        }

        // Story 8.3: Reset inactivity timer on each outgoing message
        resetInactivityTimer()

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
                // Unregister from active stream recovery when Task completes
                if let id = self.currentConversationId,
                   Self.activeStreamViewModels[id] === self {
                    Self.activeStreamViewModels[id] = nil
                }
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

                // Register for stream recovery if user navigates away mid-stream
                if let id = currentConversationId {
                    Self.activeStreamViewModels[id] = self
                }

                for try await event in chatStreamService.streamChat(
                    message: trimmedInput,
                    conversationId: conversationId
                ) {
                    try Task.checkCancellation()

                    switch event {
                    case .token(let content, let hasMemoryMoment, let hasPatternInsight, let hasCrisisFlag, _):
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

                    case .done(let messageId, _, _, let isDiscoveryDone, let profile):
                        tokenBuffer?.flush()
                        currentStreamMessageId = messageId

                        // Story 11.3: Capture discovery_complete signal from server
                        if isDiscoveryDone {
                            discoveryComplete = true
                        }

                        // Story 11.5: Build DiscoveryPaywallContext from SSE metadata (Task 6.3)
                        if isDiscoveryDone {
                            discoveryPaywallContext = buildDiscoveryPaywallContext(from: profile)
                        }

                        // Story 8.3: Reset inactivity timer on each incoming message
                        resetInactivityTimer()

                        // Story 8.5 Review fix H1: Client safety net — strip any leaked reflection tags
                        let cleanedContent = streamingContent
                            .replacingOccurrences(of: "[REFLECTION_ACCEPTED]", with: "")
                            .replacingOccurrences(of: "[REFLECTION_DECLINED]", with: "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)

                        // Only create assistant message if we received actual content
                        // Prevents blank bubbles from empty LLM responses
                        if !cleanedContent.isEmpty {
                            let assistantMessage = ChatMessage(
                                id: messageId,
                                conversationId: conversationId,
                                role: .assistant,
                                content: cleanedContent,
                                createdAt: Date()
                            )
                            messages.append(assistantMessage)
                            persistCurrentConversationCache()
                            checkPushPermissionTrigger()
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
                            content: streamingContent + "\n\n[Response interrupted]",
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
                } else if case .rateLimited(let isTrial, let resetDate) = streamError {
                    // Story 10.1: Handle rate limit — show warm message, disable send (AC #5)
                    self.isRateLimited = true
                    self.error = .rateLimited(isTrial: isTrial, resetDate: resetDate)
                    // Remove the user message that was optimistically added (server rejected it)
                    messages.removeAll { $0.id == userMessage.id }
                    persistCurrentConversationCache()
                    // Show paywall for trial users
                    if isTrial {
                        showPaywall = true
                    }
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

    /// Sends the pending message that was queued while the paywall was showing (Story 6.3 — Task 4.4).
    /// Called after a successful purchase dismisses the paywall.
    func sendPendingMessage() async {
        guard let message = pendingMessage else { return }
        pendingMessage = nil
        inputText = message
        await sendMessage()
    }

    /// Story 11.3: Shows a hardcoded welcome message instantly during discovery mode.
    /// No API call — the message appears immediately so there's zero loading delay.
    /// The user's first typed response will be sent as a regular discovery-mode message.
    func showDiscoveryWelcomeMessage() {
        guard isDiscoveryMode, let conversationId = currentConversationId else { return }

        let welcomeMessage = ChatMessage(
            id: UUID(),
            conversationId: conversationId,
            role: .assistant,
            content: "Hey there! Welcome to CoachMe \u{2014} I\u{2019}m your personal coach, here to help you work through challenges, build better habits, and reach your goals.\n\nWhat would you like to work on today?",
            createdAt: Date()
        )
        messages.append(welcomeMessage)
        persistCurrentConversationCache()
    }

    /// Dismisses the current error
    func dismissError() {
        showError = false
        error = nil
    }

    /// Story 8.1: Records session engagement metrics when user leaves the conversation
    /// Called from ChatView.onDisappear, scenePhase changes, or when starting a new conversation
    /// Story 8.5: Added 1-hour conversation_id dedup to prevent double-signaling
    func onSessionEnd() {
        // Only record if user actually sent a message this session (sessionStartTime is set in sendMessage)
        // and conversation has 2+ messages (per Dev Notes)
        guard sessionStartTime != nil,
              messages.count >= 2,
              let conversationId = currentConversationId else { return }

        // Story 8.5: Prevent double-signaling within 1-hour window per conversation
        let oneHourAgo = Date().addingTimeInterval(-3600)
        // Clean up stale entries
        Self.recentlySignaledConversations = Self.recentlySignaledConversations.filter { $0.value > oneHourAgo }
        // Check if already signaled
        if let lastSignaled = Self.recentlySignaledConversations[conversationId], lastSignaled > oneHourAgo {
            sessionStartTime = nil
            return
        }

        let userMessages = messages.filter { $0.role == .user }
        guard !userMessages.isEmpty else { return }

        let messageCount = messages.count
        let totalUserChars = userMessages.reduce(0) { $0 + $1.content.count }
        let avgMessageLength = totalUserChars / userMessages.count

        // Duration from session start (or first message timestamp) to now
        let startTime = sessionStartTime ?? messages.first?.createdAt ?? Date()
        let durationSeconds = Int(Date().timeIntervalSince(startTime))

        // Story 8.5: Mark as signaled before async call to prevent races
        Self.recentlySignaledConversations[conversationId] = Date()

        // Fire-and-forget — signal failure must never affect UX
        Task {
            try? await LearningSignalService.shared.recordSessionEngagement(
                conversationId: conversationId,
                messageCount: messageCount,
                avgMessageLength: avgMessageLength,
                durationSeconds: durationSeconds
            )
        }

        // Reset so we don't double-fire
        sessionStartTime = nil
    }

    /// Story 8.3: Checks if the push permission prompt should be shown after session completion.
    /// A session is "complete" when at least one exchange happened (2 messages total),
    /// then checked on assistant response completion, app background, or 5min inactivity.
    func checkPushPermissionTrigger() {
        let hasEnoughMessages = messages.count >= Self.sessionCompleteMessageThreshold
        guard hasEnoughMessages else { return }

        // Evaluate prompt conditions synchronously so app-background transitions
        // don't suspend the task before state updates.
        let shouldPrompt = PushPermissionService.shared.shouldRequestPermission(firstSessionComplete: true)
        if shouldPrompt {
            showPushPermissionPrompt = true
        }

        // Server profile update is non-blocking and can happen asynchronously.
        Task {
            if let userId = await AuthService.shared.currentUserId {
                try? await ContextRepository.shared.markFirstSessionComplete(userId: userId)
            }
        }
    }

    /// Story 8.3: Resets the inactivity timer. Called whenever a message is sent or received.
    func resetInactivityTimer() {
        inactivityTimer?.cancel()
        inactivityTimer = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.inactivityTriggerSeconds))
            guard !Task.isCancelled else { return }
            self?.checkPushPermissionTrigger()
        }
    }

    /// Story 8.3: Handle app going to background — check push permission trigger
    func onAppBackgrounded() {
        inactivityTimer?.cancel()
        checkPushPermissionTrigger()
    }

    /// Starts a new conversation, clearing all messages
    func startNewConversation() {
        // Story 8.1: Record engagement for the ending conversation
        onSessionEnd()

        resetStateForConversation(id: UUID(), isPersisted: false)
        messages = []
    }

    /// Loads an existing conversation by fetching its messages (Story 3.6)
    /// - Parameter id: The conversation ID to load
    func loadConversation(id: UUID, alreadyPrimedFromCache: Bool = false) async {
        // If already actively streaming for this conversation, don't interrupt
        if currentConversationId == id && (isStreaming || isLoading) {
            return
        }
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

        // Story 7.1: If offline, fall back to SwiftData cache
        guard NetworkMonitor.shared.isConnected else {
            if !hasCachedMessages {
                let swiftDataMessages = OfflineCacheService.shared.getCachedMessages(conversationId: id)
                if !swiftDataMessages.isEmpty {
                    messages = swiftDataMessages.map { $0.toChatMessage() }
                    hasCachedMessages = true
                }
            }
            isLoading = false
            return
        }

        defer { isLoading = false }

        do {
            messages = try await conversationService.fetchMessages(conversationId: id)
            persistCurrentConversationCache()
        } catch let convError as ConversationService.ConversationError {
            // If cache is already shown, avoid interrupting with an alert.
            if !hasCachedMessages {
                // Story 7.1: Fall back to SwiftData on fetch failure
                let swiftDataMessages = OfflineCacheService.shared.getCachedMessages(conversationId: id)
                if !swiftDataMessages.isEmpty {
                    messages = swiftDataMessages.map { $0.toChatMessage() }
                } else {
                    self.error = .messageFailed(convError)
                    showError = true
                }
            }
        } catch {
            if !hasCachedMessages {
                // Story 7.1: Fall back to SwiftData on fetch failure
                let swiftDataMessages = OfflineCacheService.shared.getCachedMessages(conversationId: id)
                if !swiftDataMessages.isEmpty {
                    messages = swiftDataMessages.map { $0.toChatMessage() }
                } else {
                    self.error = .messageFailed(error)
                    showError = true
                }
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

    /// Story 7.3: Refreshes the current conversation from the server.
    /// Skips refresh during active streaming to avoid UI disruption.
    func refresh() async {
        guard let conversationId = currentConversationId, !isStreaming else { return }
        await loadConversation(id: conversationId)
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
        // Unregister from active stream registry for the current conversation
        if let previousId = currentConversationId,
           Self.activeStreamViewModels[previousId] === self {
            Self.activeStreamViewModels[previousId] = nil
        }
        currentSendTask?.cancel()
        inactivityTimer?.cancel()  // Story 8.3
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
        isRateLimited = false  // Story 10.1
        showPaywall = false
        isDiscoveryMode = false  // Story 11.3
        discoveryComplete = false  // Story 11.3
        discoveryPaywallContext = nil  // Story 11.5
        discoveryPaywallDismissed = false  // Story 11.5
        showPushPermissionPrompt = false  // Story 8.3
        pendingMessage = nil
        tokenBuffer?.reset()
        lastUserMessageContent = nil
        failedUserMessageIDs.removeAll()
        sessionStartTime = nil  // Story 8.1: Reset session tracking
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

    /// Story 11.5: Builds DiscoveryPaywallContext from SSE discovery profile data.
    /// Extracts first coaching domain and first key theme for paywall copy generation.
    /// Returns empty context (triggering fallback copy) when profile is nil.
    private func buildDiscoveryPaywallContext(from profile: ChatStreamService.StreamEvent.DiscoveryProfileData?) -> DiscoveryPaywallContext {
        if let profile {
            return DiscoveryPaywallContext(
                coachingDomain: profile.coachingDomains?.first,
                ahaInsight: profile.ahaInsight,
                keyTheme: profile.keyThemes?.first,
                userName: nil
            )
        }
        return DiscoveryPaywallContext(coachingDomain: nil, ahaInsight: nil, keyTheme: nil, userName: nil)
    }

    /// Persists in-memory messages for the current conversation so thread opens instantly next time.
    /// Also writes to SwiftData for offline access (Story 7.1).
    private func persistCurrentConversationCache() {
        guard let conversationId = currentConversationId else { return }
        ChatMessageCache.save(messages: messages, conversationId: conversationId)
        persistConversationListCacheSnapshot(messages: messages, conversationId: conversationId)

        // Story 7.1: Also persist to SwiftData for offline access (non-blocking)
        let messagesToCache = messages
        Task { OfflineCacheService.shared.cacheMessages(messagesToCache, forConversation: conversationId) }
    }

    /// Updates the inbox cache immediately so conversation history survives app relaunches
    /// even before the next cloud conversation-list fetch completes.
    private func persistConversationListCacheSnapshot(messages: [ChatMessage], conversationId: UUID) {
        guard let userId = AuthService.shared.currentUser?.id else { return }

        let now = Date()
        let existingPayload = ConversationListCache.load()
        let existingConversation = existingPayload?.conversations.first { $0.id == conversationId }
        let inferredTitle = existingConversation?.title
            ?? messages.first(where: { $0.role == .user }).map { String($0.content.prefix(50)) }

        let conversation = ConversationService.Conversation(
            id: conversationId,
            userId: userId,
            title: inferredTitle,
            domain: existingConversation?.domain,
            lastMessageAt: messages.last?.createdAt ?? existingConversation?.lastMessageAt ?? now,
            messageCount: max(existingConversation?.messageCount ?? 0, messages.count),
            createdAt: existingConversation?.createdAt ?? messages.first?.createdAt ?? now,
            updatedAt: now
        )

        var conversations = existingPayload?.conversations.filter { $0.id != conversationId } ?? []
        conversations.append(conversation)
        conversations.sort { ($0.lastMessageAt ?? .distantPast) > ($1.lastMessageAt ?? .distantPast) }

        var previews = existingPayload?.previews ?? [:]
        var roles = existingPayload?.roles ?? [:]
        if let last = messages.last {
            previews[conversationId] = normalizedPreview(last.content)
            roles[conversationId] = last.role
        }

        let payload = ConversationListCachePayload(
            conversations: conversations,
            previews: previews,
            roles: roles,
            cachedAt: now
        )
        ConversationListCache.save(payload)
    }

    private func normalizedPreview(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
