//
//  InsightSuggestionsViewModel.swift
//  CoachMe
//
//  Story 2.3: Progressive Context Extraction
//  ViewModel for managing extracted insight suggestions
//  Per architecture.md: Use @Observable pattern, @MainActor for services
//

import Foundation

/// ViewModel for managing the insight suggestions flow
/// Handles extraction triggers, pending insights, and user confirmations
@MainActor
@Observable
final class InsightSuggestionsViewModel {
    // MARK: - Published State

    /// Pending insights waiting for user confirmation
    var pendingInsights: [ExtractedInsight] = []

    /// Whether the suggestions sheet should be shown
    var showSuggestions = false

    /// Whether an extraction is in progress
    var isExtracting = false

    /// Whether a save operation is in progress
    var isSaving = false

    /// Current error (if any)
    var error: ContextExtractionError?

    /// Whether to show the error alert
    var showError = false

    /// Whether there are pending insights to review
    var hasPendingInsights: Bool {
        !pendingInsights.isEmpty
    }

    /// Number of pending insights
    var pendingCount: Int {
        pendingInsights.count
    }

    // MARK: - Private State

    /// The current user's ID
    private var userId: UUID?

    /// Response count for extraction interval
    private var responseCount = 0

    // MARK: - Dependencies

    private let extractionService: any ContextExtractionServiceProtocol
    private let contextRepository: any ContextRepositoryProtocol

    // MARK: - Constants

    /// Number of AI responses before triggering extraction
    private static let extractionInterval = 5

    /// Minimum pending insights before showing suggestions sheet
    private static let suggestionThreshold = 3

    // MARK: - Initialization

    init(
        extractionService: any ContextExtractionServiceProtocol = ContextExtractionService.shared,
        contextRepository: any ContextRepositoryProtocol = ContextRepository.shared
    ) {
        self.extractionService = extractionService
        self.contextRepository = contextRepository
    }

    // MARK: - Configuration

    /// Configures the view model with the current user
    /// - Parameter userId: The authenticated user's ID
    func configure(userId: UUID) async {
        self.userId = userId

        // Load any existing pending insights
        do {
            pendingInsights = try await contextRepository.getPendingInsights(userId: userId)
            #if DEBUG
            print("InsightSuggestionsViewModel: Loaded \(pendingInsights.count) pending insights")
            #endif
        } catch {
            #if DEBUG
            print("InsightSuggestionsViewModel: Failed to load pending insights: \(error)")
            #endif
        }
    }

    /// Sets the auth token on the extraction service
    /// - Parameter token: The JWT auth token
    func setAuthToken(_ token: String?) {
        extractionService.setAuthToken(token)
    }

    // MARK: - Extraction Trigger

    /// Called when an AI response is received
    /// Triggers extraction at configured intervals
    /// - Parameters:
    ///   - conversationId: The current conversation ID
    ///   - messages: The current conversation messages
    func onAIResponseReceived(conversationId: UUID, messages: [ChatMessage]) {
        responseCount += 1

        // Only trigger extraction every N responses
        guard responseCount >= Self.extractionInterval else { return }

        responseCount = 0

        // Trigger extraction in background
        Task {
            await triggerExtraction(conversationId: conversationId, messages: messages)
        }
    }

    /// Manually trigger extraction
    /// - Parameters:
    ///   - conversationId: The conversation to analyze
    ///   - messages: The messages to analyze
    func triggerExtraction(conversationId: UUID, messages: [ChatMessage]) async {
        guard !isExtracting else { return }
        guard !messages.isEmpty else { return }

        isExtracting = true
        defer { isExtracting = false }

        do {
            let newInsights = try await extractionService.extractFromConversation(
                conversationId: conversationId,
                chatMessages: messages
            )

            // Deduplicate against existing pending insights
            let existingContents = Set(pendingInsights.map { $0.content.lowercased() })
            let uniqueInsights = newInsights.filter { insight in
                !existingContents.contains(insight.content.lowercased())
            }

            guard !uniqueInsights.isEmpty else {
                #if DEBUG
                print("InsightSuggestionsViewModel: No new unique insights found")
                #endif
                return
            }

            // Add to pending insights
            pendingInsights.append(contentsOf: uniqueInsights)

            // Save to repository
            if let userId = userId {
                try await contextRepository.savePendingInsights(
                    userId: userId,
                    insights: pendingInsights
                )
            }

            #if DEBUG
            print("InsightSuggestionsViewModel: Added \(uniqueInsights.count) new insights, total pending: \(pendingInsights.count)")
            #endif

            // Check if we should show suggestions
            checkSuggestionThreshold()

        } catch {
            #if DEBUG
            print("InsightSuggestionsViewModel: Extraction failed: \(error)")
            #endif
            // Don't show error to user for background extraction
        }
    }

    // MARK: - Insight Management

    /// Confirms an insight, adding it to the user's profile
    /// - Parameter id: The insight ID to confirm
    func confirmInsight(id: UUID) async {
        guard let userId = userId else { return }
        guard let insight = pendingInsights.first(where: { $0.id == id }) else { return }

        isSaving = true
        defer { isSaving = false }

        do {
            try await contextRepository.confirmInsight(userId: userId, insightId: id)

            // Remove from pending
            pendingInsights.removeAll { $0.id == id }

            #if DEBUG
            print("InsightSuggestionsViewModel: Confirmed insight: \(insight.content)")
            #endif

            // Close sheet if no more insights
            if pendingInsights.isEmpty {
                showSuggestions = false
            }
        } catch {
            self.error = .extractionFailed(error.localizedDescription)
            showError = true
        }
    }

    /// Dismisses an insight without adding to profile
    /// - Parameter id: The insight ID to dismiss
    func dismissInsight(id: UUID) async {
        guard let userId = userId else { return }

        do {
            try await contextRepository.dismissInsight(userId: userId, insightId: id)

            // Remove from pending
            pendingInsights.removeAll { $0.id == id }

            #if DEBUG
            print("InsightSuggestionsViewModel: Dismissed insight: \(id)")
            #endif

            // Close sheet if no more insights
            if pendingInsights.isEmpty {
                showSuggestions = false
            }
        } catch {
            #if DEBUG
            print("InsightSuggestionsViewModel: Failed to dismiss insight: \(error)")
            #endif
        }
    }

    /// Dismisses all pending insights (review later)
    func dismissAll() {
        showSuggestions = false
        // Keep pending insights for later review
    }

    /// Shows the suggestions sheet
    func showSuggestionsSheet() {
        guard !pendingInsights.isEmpty else { return }
        showSuggestions = true
    }

    /// Dismisses the current error
    func dismissError() {
        showError = false
        error = nil
    }

    /// Resets the response count (e.g., when starting a new conversation)
    func resetResponseCount() {
        responseCount = 0
    }

    // MARK: - Private Methods

    /// Checks if we've reached the threshold to show suggestions
    private func checkSuggestionThreshold() {
        // Only auto-show if we have enough insights batched
        if pendingInsights.count >= Self.suggestionThreshold {
            // Don't auto-show during conversation - let user initiate or show after session
            // This prevents interrupting the user
            #if DEBUG
            print("InsightSuggestionsViewModel: Suggestion threshold reached (\(pendingInsights.count) insights)")
            #endif
        }
    }
}
