//
//  ContextViewModel.swift
//  CoachMe
//
//  Story 2.5: Context Profile Viewing & Editing
//  Per architecture.md: Use @Observable pattern, @MainActor for services
//

import Foundation

/// Editable discovery text fields (Story 11.4 AC #6)
enum DiscoveryFieldKey: Equatable, Sendable {
    case ahaInsight
    case vision
    case communicationStyle
    case emotionalBaseline
}

/// Item types that can be edited in the context profile
enum ContextEditItemType: Equatable, Sendable {
    case value(UUID)
    case goal(UUID)
    case situation
    case discoveryField(DiscoveryFieldKey)
}

/// Wrapper for items being edited
struct ContextEditItem: Identifiable, Sendable {
    let id = UUID()
    let type: ContextEditItemType
    let currentContent: String
}

/// ViewModel for viewing and editing the user's context profile
/// Handles loading, editing, and deleting context items with optimistic UI
@MainActor
@Observable
final class ContextViewModel {
    // MARK: - Published State

    /// The user's context profile
    var profile: ContextProfile?

    /// Whether the profile is loading
    var isLoading = false

    /// Whether a save operation is in progress
    var isSaving = false

    /// Current error (if any)
    var error: ContextError?

    /// Whether to show the error alert
    var showError = false

    /// Item being edited (triggers editor sheet)
    var editingItem: ContextEditItem?

    /// Item pending deletion (for confirmation)
    var deletingItemId: UUID?

    /// Whether to show delete confirmation
    var showDeleteConfirmation = false

    // Story 8.8: Learned knowledge state
    /// Whether to show style override sheet
    var showStyleOverrideSheet = false

    /// ID of learned item pending deletion
    var deletingLearnedItemId: UUID?

    /// Whether to show delete learned insight confirmation
    var showDeleteLearnedConfirmation = false

    // MARK: - Dependencies

    private let contextRepository: any ContextRepositoryProtocol

    // MARK: - Private State

    private var userId: UUID?

    // MARK: - Initialization

    init(contextRepository: any ContextRepositoryProtocol = ContextRepository.shared) {
        self.contextRepository = contextRepository
    }

    // MARK: - Public Methods

    /// Loads the user's context profile
    /// - Parameter userId: The authenticated user's ID
    func loadProfile(userId: UUID) async {
        self.userId = userId
        isLoading = true

        do {
            profile = try await contextRepository.fetchProfile(userId: userId)
            #if DEBUG
            print("ContextViewModel: Loaded profile for user \(userId)")
            #endif
        } catch let contextError as ContextError {
            // Don't show error for notFound - it's expected for new users
            if case .notFound = contextError {
                self.error = contextError
                // showError stays false
            } else {
                self.error = contextError
                showError = true
            }
        } catch {
            self.error = .fetchFailed(error.localizedDescription)
            showError = true
        }

        isLoading = false
    }

    /// Refreshes the profile from the server
    func refreshProfile() async {
        guard let userId = userId else { return }
        await loadProfile(userId: userId)
    }

    // MARK: - Value Operations

    /// Starts editing a value
    /// - Parameter id: The value's ID
    func startEditingValue(id: UUID) {
        guard let value = profile?.values.first(where: { $0.id == id }) else { return }
        editingItem = ContextEditItem(type: .value(id), currentContent: value.content)
    }

    /// Updates a value with new content (optimistic UI with rollback)
    /// - Parameters:
    ///   - id: The value's ID
    ///   - newContent: The new content
    func updateValue(id: UUID, newContent: String) async {
        guard var profile = profile else { return }
        let trimmed = newContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Save original for rollback
        let originalProfile = profile

        // Optimistic update
        if let index = profile.values.firstIndex(where: { $0.id == id }) {
            profile.values[index].content = trimmed
            self.profile = profile
        }

        editingItem = nil

        do {
            isSaving = true
            defer { isSaving = false }
            try await contextRepository.updateProfile(profile)
            #if DEBUG
            print("ContextViewModel: Updated value \(id)")
            #endif
        } catch {
            // Rollback on error
            self.profile = originalProfile
            self.error = error as? ContextError ?? .saveFailed(error.localizedDescription)
            showError = true
        }
    }

    /// Requests deletion of a value (shows confirmation)
    /// - Parameter id: The value's ID
    func requestDeleteValue(id: UUID) {
        deletingItemId = id
        showDeleteConfirmation = true
    }

    /// Deletes a value after confirmation (optimistic UI with rollback)
    /// - Parameter id: The value's ID
    func deleteValue(id: UUID) async {
        guard var profile = profile else { return }

        // Save original for rollback
        let originalProfile = profile

        // Optimistic update
        profile.removeValue(id: id)
        self.profile = profile

        showDeleteConfirmation = false
        deletingItemId = nil

        do {
            isSaving = true
            defer { isSaving = false }
            try await contextRepository.updateProfile(profile)
            #if DEBUG
            print("ContextViewModel: Deleted value \(id)")
            #endif
        } catch {
            // Rollback on error
            self.profile = originalProfile
            self.error = error as? ContextError ?? .saveFailed(error.localizedDescription)
            showError = true
        }
    }

    // MARK: - Goal Operations

    /// Starts editing a goal
    /// - Parameter id: The goal's ID
    func startEditingGoal(id: UUID) {
        guard let goal = profile?.goals.first(where: { $0.id == id }) else { return }
        editingItem = ContextEditItem(type: .goal(id), currentContent: goal.content)
    }

    /// Updates a goal with new content (optimistic UI with rollback)
    /// - Parameters:
    ///   - id: The goal's ID
    ///   - newContent: The new content
    func updateGoal(id: UUID, newContent: String) async {
        guard var profile = profile else { return }
        let trimmed = newContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Save original for rollback
        let originalProfile = profile

        // Optimistic update
        if let index = profile.goals.firstIndex(where: { $0.id == id }) {
            profile.goals[index].content = trimmed
            self.profile = profile
        }

        editingItem = nil

        do {
            isSaving = true
            defer { isSaving = false }
            try await contextRepository.updateProfile(profile)
            #if DEBUG
            print("ContextViewModel: Updated goal \(id)")
            #endif
        } catch {
            // Rollback on error
            self.profile = originalProfile
            self.error = error as? ContextError ?? .saveFailed(error.localizedDescription)
            showError = true
        }
    }

    /// Toggles a goal's status between active and achieved
    /// - Parameter id: The goal's ID
    func toggleGoalStatus(id: UUID) async {
        guard var profile = profile else { return }

        // Save original for rollback
        let originalProfile = profile

        // Optimistic update
        if let index = profile.goals.firstIndex(where: { $0.id == id }) {
            if profile.goals[index].status == .active {
                profile.goals[index].markAchieved()
            } else {
                profile.goals[index].reactivate()
            }
            self.profile = profile
        }

        do {
            isSaving = true
            defer { isSaving = false }
            try await contextRepository.updateProfile(profile)
            #if DEBUG
            print("ContextViewModel: Toggled goal status \(id)")
            #endif
        } catch {
            // Rollback on error
            self.profile = originalProfile
            self.error = error as? ContextError ?? .saveFailed(error.localizedDescription)
            showError = true
        }
    }

    /// Requests deletion of a goal (shows confirmation)
    /// - Parameter id: The goal's ID
    func requestDeleteGoal(id: UUID) {
        deletingItemId = id
        showDeleteConfirmation = true
    }

    /// Deletes a goal after confirmation (optimistic UI with rollback)
    /// - Parameter id: The goal's ID
    func deleteGoal(id: UUID) async {
        guard var profile = profile else { return }

        // Save original for rollback
        let originalProfile = profile

        // Optimistic update
        profile.removeGoal(id: id)
        self.profile = profile

        showDeleteConfirmation = false
        deletingItemId = nil

        do {
            isSaving = true
            defer { isSaving = false }
            try await contextRepository.updateProfile(profile)
            #if DEBUG
            print("ContextViewModel: Deleted goal \(id)")
            #endif
        } catch {
            // Rollback on error
            self.profile = originalProfile
            self.error = error as? ContextError ?? .saveFailed(error.localizedDescription)
            showError = true
        }
    }

    // MARK: - Situation Operations

    /// Starts editing the life situation
    func startEditingSituation() {
        let currentContent = profile?.situation.freeform ?? ""
        editingItem = ContextEditItem(type: .situation, currentContent: currentContent)
    }

    /// Updates the life situation (optimistic UI with rollback)
    /// - Parameter newContent: The new situation text
    func updateSituation(newContent: String) async {
        guard var profile = profile else { return }
        let trimmed = newContent.trimmingCharacters(in: .whitespacesAndNewlines)

        // Save original for rollback
        let originalProfile = profile

        // Optimistic update
        profile.situation.freeform = trimmed.isEmpty ? nil : trimmed
        self.profile = profile

        editingItem = nil

        do {
            isSaving = true
            defer { isSaving = false }
            try await contextRepository.updateProfile(profile)
            #if DEBUG
            print("ContextViewModel: Updated situation")
            #endif
        } catch {
            // Rollback on error
            self.profile = originalProfile
            self.error = error as? ContextError ?? .saveFailed(error.localizedDescription)
            showError = true
        }
    }

    // MARK: - Story 8.8: Learned Knowledge Computed Properties

    /// Inferred patterns from coaching preferences
    var inferredPatterns: [InferredPattern] {
        profile?.coachingPreferences.inferredPatterns ?? []
    }

    /// Coaching style info from coaching preferences
    var coachingStyle: CoachingStyleInfo? {
        profile?.coachingPreferences.coachingStyle
    }

    /// Domain usage statistics
    var domainUsage: DomainUsageStats? {
        profile?.coachingPreferences.domainUsageStats
    }

    /// Progress notes
    var progressNotes: [ProgressNote] {
        profile?.coachingPreferences.progressNotes ?? []
    }

    /// Whether any learned knowledge exists to display
    var hasLearnedKnowledge: Bool {
        !inferredPatterns.isEmpty
            || coachingStyle?.inferredStyle != nil
            || !(domainUsage?.domains.isEmpty ?? true)
            || !progressNotes.isEmpty
    }

    /// Effective coaching style — manual override always wins
    /// Checks both manualOverrides (8.8 struct) and manualOverride (8.6 string, used by server-side style-adapter)
    var effectiveCoachingStyle: String? {
        profile?.coachingPreferences.manualOverrides?.style
            ?? profile?.coachingPreferences.manualOverride
            ?? coachingStyle?.inferredStyle
    }

    /// Whether a manual style override is active (checks both 8.8 struct and 8.6 string)
    var hasManualStyleOverride: Bool {
        profile?.coachingPreferences.manualOverrides?.style != nil
            || profile?.coachingPreferences.manualOverride != nil
    }

    // MARK: - Story 8.8: Learned Knowledge Actions

    /// Dismisses a learned insight with optimistic UI and rollback on error
    func dismissLearnedInsight(id: UUID) async {
        guard var profile = profile else { return }

        // Save original for rollback
        let originalProfile = profile

        // Optimistic update
        var prefs = profile.coachingPreferences
        prefs.inferredPatterns?.removeAll { $0.id == id }
        var dismissed = prefs.dismissedInsights ?? DismissedInsights()
        dismissed.insightIds.append(id)
        dismissed.lastDismissed = Date()
        prefs.dismissedInsights = dismissed
        profile.coachingPreferences = prefs
        self.profile = profile

        showDeleteLearnedConfirmation = false
        deletingLearnedItemId = nil

        do {
            isSaving = true
            defer { isSaving = false }
            try await contextRepository.updateProfile(profile)
            // Non-blocking learning signal
            Task {
                do {
                    try await LearningSignalService.shared.recordInsightFeedback(
                        insightId: id, action: .dismissed, category: "learned_pattern"
                    )
                } catch {
                    #if DEBUG
                    print("ContextViewModel: Failed to record insight feedback for \(id) — \(error.localizedDescription)")
                    #endif
                }
            }
        } catch {
            self.profile = originalProfile
            self.error = error as? ContextError ?? .insightDismissFailed(error.localizedDescription)
            showError = true
        }
    }

    /// Sets a manual style override with optimistic UI
    /// Syncs both manualOverrides (8.8 client) and manualOverride (8.6 server-side style-adapter)
    func setStyleOverride(_ style: String) async {
        guard var profile = profile else { return }

        // Save original for rollback
        let originalProfile = profile

        // Optimistic update — sync both fields for client + server compatibility
        profile.coachingPreferences.manualOverrides = ManualOverrides(style: style, setAt: Date())
        profile.coachingPreferences.manualOverride = style
        self.profile = profile

        do {
            isSaving = true
            defer { isSaving = false }
            try await contextRepository.updateProfile(profile)
        } catch {
            self.profile = originalProfile
            self.error = error as? ContextError ?? .styleOverrideFailed(error.localizedDescription)
            showError = true
        }
    }

    /// Clears the manual style override, reverting to inferred style
    /// Clears both manualOverrides (8.8 client) and manualOverride (8.6 server-side style-adapter)
    func clearStyleOverride() async {
        guard var profile = profile else { return }

        // Save original for rollback
        let originalProfile = profile

        // Optimistic update — clear both fields for client + server compatibility
        profile.coachingPreferences.manualOverrides = nil
        profile.coachingPreferences.manualOverride = nil
        self.profile = profile

        do {
            isSaving = true
            defer { isSaving = false }
            try await contextRepository.updateProfile(profile)
        } catch {
            self.profile = originalProfile
            self.error = error as? ContextError ?? .styleOverrideFailed(error.localizedDescription)
            showError = true
        }
    }

    // MARK: - Story 11.4: Discovery Field Editing (AC #6)

    /// Starts editing a discovery text field
    func startEditingDiscoveryField(_ key: DiscoveryFieldKey) {
        let content: String
        switch key {
        case .ahaInsight:
            content = profile?.ahaInsight ?? ""
        case .vision:
            content = profile?.vision ?? ""
        case .communicationStyle:
            content = profile?.communicationStyle ?? ""
        case .emotionalBaseline:
            content = profile?.emotionalBaseline ?? ""
        }
        editingItem = ContextEditItem(type: .discoveryField(key), currentContent: content)
    }

    /// Updates a discovery text field (optimistic UI with rollback)
    func updateDiscoveryField(_ key: DiscoveryFieldKey, newContent: String) async {
        guard var profile = profile else { return }
        let trimmed = newContent.trimmingCharacters(in: .whitespacesAndNewlines)

        let originalProfile = profile

        switch key {
        case .ahaInsight:
            profile.ahaInsight = trimmed.isEmpty ? nil : trimmed
        case .vision:
            profile.vision = trimmed.isEmpty ? nil : trimmed
        case .communicationStyle:
            profile.communicationStyle = trimmed.isEmpty ? nil : trimmed
        case .emotionalBaseline:
            profile.emotionalBaseline = trimmed.isEmpty ? nil : trimmed
        }
        self.profile = profile
        editingItem = nil

        do {
            isSaving = true
            defer { isSaving = false }
            try await contextRepository.updateProfile(profile)
        } catch {
            self.profile = originalProfile
            self.error = error as? ContextError ?? .saveFailed(error.localizedDescription)
            showError = true
        }
    }

    // MARK: - Helper Methods

    /// Cancels any pending edit
    func cancelEdit() {
        editingItem = nil
    }

    /// Cancels delete confirmation
    func cancelDelete() {
        showDeleteConfirmation = false
        deletingItemId = nil
    }

    /// Confirms and executes the pending deletion
    func confirmDelete() async {
        guard let id = deletingItemId else { return }

        // Determine if this is a value or goal by checking which collection contains it
        if profile?.values.contains(where: { $0.id == id }) == true {
            await deleteValue(id: id)
        } else if profile?.goals.contains(where: { $0.id == id }) == true {
            await deleteGoal(id: id)
        }
    }

    /// Dismisses the current error
    func dismissError() {
        showError = false
        error = nil
    }
}
