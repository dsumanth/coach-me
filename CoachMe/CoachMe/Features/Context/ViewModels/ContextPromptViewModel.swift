//
//  ContextPromptViewModel.swift
//  CoachMe
//
//  Story 2.2: Context Setup Prompt After First Session
//  Per architecture.md: Use @Observable pattern, @MainActor for services
//

import Foundation

/// ViewModel for managing the context setup prompt flow
/// Handles prompt display logic, dismissal tracking, and context saving
@MainActor
@Observable
final class ContextPromptViewModel {
    // MARK: - Published State

    /// Whether the context prompt sheet should be shown
    var showPrompt = false

    /// Whether the context setup form should be shown (after accepting prompt)
    var showSetupForm = false

    /// Whether a save operation is in progress
    var isSaving = false

    /// Current error (if any)
    var error: ContextError?

    /// Whether to show the error alert
    var showError = false

    // MARK: - Private State

    /// The current user's ID
    private(set) var userId: UUID?

    /// The current context profile
    private var profile: ContextProfile?

    /// Session count for re-prompt logic (tracked locally per app session)
    private var sessionMessageCount = 0

    // MARK: - Dependencies

    private let contextRepository: any ContextRepositoryProtocol

    // MARK: - Constants

    /// Number of sessions before re-prompting after dismissal
    private static let rePromptSessionThreshold = 3

    /// Minimum messages in a session to count as "completed"
    private static let messagesPerSession = 2  // 1 user + 1 AI response

    // MARK: - Initialization

    init(contextRepository: any ContextRepositoryProtocol = ContextRepository.shared) {
        self.contextRepository = contextRepository
    }

    // MARK: - Public Methods

    /// Configures the view model with the current user
    /// - Parameter userId: The authenticated user's ID
    func configure(userId: UUID) async {
        self.userId = userId

        // Load the user's context profile
        do {
            profile = try await contextRepository.fetchProfile(userId: userId)
        } catch {
            // Profile might not exist yet - that's okay
            #if DEBUG
            print("ContextPromptViewModel: Profile not found for user \(userId)")
            #endif
            profile = nil
        }
    }

    /// Called when an AI response is received
    /// Determines if the context prompt should be shown
    func onAIResponseReceived() {
        sessionMessageCount += 1

        // Only check after first complete exchange (user message + AI response)
        guard sessionMessageCount >= Self.messagesPerSession else { return }

        if shouldShowPrompt() {
            showPrompt = true
        }
    }

    /// Determines if the prompt should be shown based on profile state
    /// - Returns: true if prompt should be displayed
    func shouldShowPrompt() -> Bool {
        guard let profile = profile else {
            // No profile means first time - show prompt
            return true
        }

        // First session not complete yet - show prompt
        if !profile.firstSessionComplete {
            return true
        }

        // Already has context - don't show
        if profile.hasContext {
            return false
        }

        // Re-prompt logic: show again after session 3 if dismissed before
        if profile.promptDismissedCount >= 1 {
            // Calculate session count based on messages
            let approximateSessions = sessionMessageCount / Self.messagesPerSession
            return approximateSessions >= Self.rePromptSessionThreshold
        }

        return false
    }

    /// Called when user accepts the prompt ("Yes, remember me")
    func acceptPrompt() {
        showPrompt = false
        showSetupForm = true
    }

    /// Called when user dismisses the prompt ("Not now")
    func dismissPrompt() async {
        showPrompt = false

        guard let userId = userId else { return }

        do {
            try await contextRepository.incrementPromptDismissedCount(userId: userId)
            try await contextRepository.markFirstSessionComplete(userId: userId)

            // Refresh profile
            profile = try await contextRepository.fetchProfile(userId: userId)

            #if DEBUG
            print("ContextPromptViewModel: Prompt dismissed, count incremented")
            #endif
        } catch {
            // Non-fatal - log but don't show error
            #if DEBUG
            print("ContextPromptViewModel: Failed to update dismiss count: \(error)")
            #endif
        }
    }

    /// Saves the initial context from the setup form
    /// - Parameters:
    ///   - values: User's values input
    ///   - goals: User's goals input
    ///   - situation: User's life situation input
    func saveInitialContext(values: String, goals: String, situation: String) async {
        guard let userId = userId else {
            error = .notAuthenticated
            showError = true
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            try await contextRepository.addInitialContext(
                userId: userId,
                values: values,
                goals: goals,
                situation: situation
            )

            // Mark first session complete
            try await contextRepository.markFirstSessionComplete(userId: userId)

            // Refresh profile
            profile = try await contextRepository.fetchProfile(userId: userId)

            showSetupForm = false

            #if DEBUG
            print("ContextPromptViewModel: Initial context saved successfully")
            #endif
        } catch let contextError as ContextError {
            self.error = contextError
            showError = true
        } catch {
            self.error = .saveFailed(error.localizedDescription)
            showError = true
        }
    }

    /// Called when user skips the setup form
    func skipSetup() async {
        showSetupForm = false

        guard let userId = userId else { return }

        // Mark first session complete even if they skip
        do {
            try await contextRepository.markFirstSessionComplete(userId: userId)
            profile = try await contextRepository.fetchProfile(userId: userId)
        } catch {
            #if DEBUG
            print("ContextPromptViewModel: Failed to mark session complete: \(error)")
            #endif
        }
    }

    /// Dismisses the current error
    func dismissError() {
        showError = false
        error = nil
    }

    /// Resets the session message count (e.g., when starting a new conversation)
    func resetSessionCount() {
        sessionMessageCount = 0
    }
}
