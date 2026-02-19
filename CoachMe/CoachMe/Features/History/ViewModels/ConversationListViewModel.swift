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

    /// Cached preview text keyed by conversation ID for inbox-style rows
    var lastMessagePreviewByConversation: [UUID: String] = [:]

    /// Cached role of the last message, used for "You:" prefix
    var lastMessageRoleByConversation: [UUID: ChatMessage.Role] = [:]

    /// Recently fetched message arrays keyed by conversation, used to open threads instantly.
    private(set) var preloadedMessagesByConversation: [UUID: [ChatMessage]] = [:]

    /// True when the list on screen is coming from local cache while cloud refresh is in-flight.
    var isShowingCachedData = false

    // MARK: - Private State

    /// Story 7.3: Task observing offline sync completion notifications
    @ObservationIgnored
    private var syncTask: Task<Void, Never>?

    // MARK: - Dependencies

    private let conversationService: any ConversationServiceProtocol

    // MARK: - Initialization

    init(conversationService: any ConversationServiceProtocol = ConversationService.shared) {
        self.conversationService = conversationService
        setupSyncObserver()
    }

    deinit {
        syncTask?.cancel()
    }

    // MARK: - Setup

    /// Story 7.3: Observe sync completion to refresh conversation list
    private func setupSyncObserver() {
        syncTask = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .offlineSyncCompleted) {
                guard let self else { return }
                await self.loadConversations()
            }
        }
    }

    // MARK: - Actions

    /// Loads all conversations for the current user
    func loadConversations() async {
        isLoading = true
        defer { isLoading = false }

        // 1) Fast path: render local cache immediately.
        if let payload = ConversationListCache.load() {
            conversations = payload.conversations
            lastMessagePreviewByConversation = payload.previews
            lastMessageRoleByConversation = payload.roles
            isShowingCachedData = !payload.conversations.isEmpty
        }

        // Story 7.1: If offline, fall back to SwiftData cache instead of cloud
        guard NetworkMonitor.shared.isConnected else {
            if conversations.isEmpty {
                let cached = OfflineCacheService.shared.getCachedConversations()
                conversations = cached.map { $0.toConversation() }
                isShowingCachedData = !conversations.isEmpty
            }
            return
        }

        // 2) Source of truth refresh: cloud.
        do {
            conversations = try await conversationService.fetchConversations()
            await loadLastMessagePreviews(for: conversations)
            persistCache()
            isShowingCachedData = false
            error = nil
        } catch let convError as ConversationService.ConversationError {
            // If cache is visible, keep UX stable and avoid interruption.
            if conversations.isEmpty {
                // Story 7.1: Fall back to SwiftData cache on fetch failure
                let cached = OfflineCacheService.shared.getCachedConversations()
                if !cached.isEmpty {
                    conversations = cached.map { $0.toConversation() }
                    isShowingCachedData = true
                } else {
                    self.error = convError
                    showError = true
                }
            }
        } catch {
            if conversations.isEmpty {
                // Story 7.1: Fall back to SwiftData cache on fetch failure
                let cached = OfflineCacheService.shared.getCachedConversations()
                if !cached.isEmpty {
                    conversations = cached.map { $0.toConversation() }
                    isShowingCachedData = true
                } else {
                    self.error = .fetchFailed(error.localizedDescription)
                    showError = true
                }
            }
        }
    }

    /// Refreshes conversations (pull-to-refresh)
    func refreshConversations() async {
        do {
            conversations = try await conversationService.fetchConversations()
            await loadLastMessagePreviews(for: conversations)
            persistCache()
            isShowingCachedData = false
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
            lastMessagePreviewByConversation.removeValue(forKey: conversation.id)
            lastMessageRoleByConversation.removeValue(forKey: conversation.id)
            ChatMessageCache.remove(conversationId: conversation.id)
            persistCache()
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

    // MARK: - Inbox Row Helpers

    /// Returns a messaging-style preview for a conversation row.
    func previewText(for conversation: ConversationService.Conversation) -> String {
        if let preview = lastMessagePreviewByConversation[conversation.id], !preview.isEmpty {
            if lastMessageRoleByConversation[conversation.id] == .user {
                return "You: \(preview)"
            }
            return preview
        }

        if let title = conversation.title, !title.isEmpty {
            return title
        }

        return "Start a conversation"
    }

    /// Returns preloaded full messages for a conversation when available.
    func preloadedMessages(for conversation: ConversationService.Conversation) -> [ChatMessage]? {
        preloadedMessagesByConversation[conversation.id]
    }

    /// Returns whether the latest message is from the user.
    func isLastMessageFromUser(for conversation: ConversationService.Conversation) -> Bool {
        lastMessageRoleByConversation[conversation.id] == .user
    }

    // MARK: - Private Helpers

    /// Loads latest message previews for recent conversations.
    private func loadLastMessagePreviews(for conversations: [ConversationService.Conversation]) async {
        var previews: [UUID: String] = [:]
        var roles: [UUID: ChatMessage.Role] = [:]
        var preloaded: [UUID: [ChatMessage]] = [:]

        // Keep this bounded to avoid excessive per-load requests on large histories.
        for conversation in conversations.prefix(30) where conversation.messageCount > 0 {
            guard let messages = try? await conversationService.fetchMessages(conversationId: conversation.id),
                  let last = messages.last else {
                continue
            }
            previews[conversation.id] = normalizedPreview(last.content)
            roles[conversation.id] = last.role
            // Preload last 50 messages max to bound memory
            preloaded[conversation.id] = Array(messages.suffix(50))
            ChatMessageCache.save(messages: messages, conversationId: conversation.id)
        }

        lastMessagePreviewByConversation = previews
        lastMessageRoleByConversation = roles
        preloadedMessagesByConversation = preloaded
    }

    /// Flattens whitespace so previews stay single-line and readable.
    private func normalizedPreview(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func persistCache() {
        let payload = ConversationListCachePayload(
            conversations: conversations,
            previews: lastMessagePreviewByConversation,
            roles: lastMessageRoleByConversation,
            cachedAt: Date()
        )
        ConversationListCache.save(payload)
    }
}
