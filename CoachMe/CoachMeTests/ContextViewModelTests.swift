//
//  ContextViewModelTests.swift
//  CoachMeTests
//
//  Story 2.5: Context Profile Viewing & Editing
//  Tests for ContextViewModel state management and CRUD operations
//

import XCTest
@testable import CoachMe

@MainActor
final class ContextViewModelTests: XCTestCase {

    private var mockRepository: MockContextRepositoryForViewing!
    private var viewModel: ContextViewModel!
    private var testUserId: UUID!
    private var testProfile: ContextProfile!

    override func setUp() async throws {
        try await super.setUp()
        testUserId = UUID()
        mockRepository = MockContextRepositoryForViewing()
        viewModel = ContextViewModel(contextRepository: mockRepository)

        // Create a test profile with some data
        var profile = ContextProfile.empty(userId: testUserId)
        profile.addValue(ContextValue.userValue("Family"))
        profile.addValue(ContextValue.userValue("Health"))
        profile.addGoal(ContextGoal.userGoal("Get promoted"))
        profile.addGoal(ContextGoal.userGoal("Run a marathon"))
        profile.situation = ContextSituation(
            lifeStage: "Mid-career",
            occupation: "Software Engineer",
            relationships: "Married",
            challenges: "Work-life balance",
            freeform: "Focused on career growth"
        )
        testProfile = profile
    }

    override func tearDown() async throws {
        viewModel = nil
        mockRepository = nil
        testProfile = nil
        testUserId = nil
        try await super.tearDown()
    }

    // MARK: - Test: Load Profile (AC #1)

    func testLoadProfileSuccess() async {
        // Given: A profile exists
        mockRepository.mockProfile = testProfile

        // When: Loading profile
        await viewModel.loadProfile(userId: testUserId)

        // Then: Profile should be loaded
        XCTAssertNotNil(viewModel.profile, "Profile should be loaded")
        XCTAssertEqual(viewModel.profile?.values.count, 2)
        XCTAssertEqual(viewModel.profile?.goals.count, 2)
        XCTAssertFalse(viewModel.isLoading, "Loading should be false after completion")
    }

    func testLoadProfileSetsLoadingState() async {
        // Given: A profile exists
        mockRepository.mockProfile = testProfile
        mockRepository.delay = 0.1

        // When: Starting to load profile
        let loadTask = Task {
            await viewModel.loadProfile(userId: testUserId)
        }

        // Give a moment for the loading state to be set
        try? await Task.sleep(nanoseconds: 50_000_000)

        // Then: Loading should be true during load
        XCTAssertTrue(viewModel.isLoading, "Loading should be true during load")

        await loadTask.value
        XCTAssertFalse(viewModel.isLoading, "Loading should be false after completion")
    }

    func testLoadProfileHandlesNotFound() async {
        // Given: No profile exists
        mockRepository.mockProfile = nil

        // When: Loading profile
        await viewModel.loadProfile(userId: testUserId)

        // Then: Profile should be nil but no error shown (expected for new users)
        XCTAssertNil(viewModel.profile, "Profile should be nil when not found")
        XCTAssertFalse(viewModel.showError, "Should not show error for notFound")
    }

    // MARK: - Test: Edit Value (AC #2)

    func testStartEditingValueSetsEditingItem() {
        // Given: Profile is loaded
        viewModel.profile = testProfile
        let valueId = testProfile.values[0].id

        // When: Starting to edit a value
        viewModel.startEditingValue(id: valueId)

        // Then: Editing item should be set
        XCTAssertNotNil(viewModel.editingItem, "Editing item should be set")
        if case .value(let id) = viewModel.editingItem?.type {
            XCTAssertEqual(id, valueId, "Editing item should have correct ID")
        } else {
            XCTFail("Editing item type should be .value")
        }
        XCTAssertEqual(viewModel.editingItem?.currentContent, "Family")
    }

    func testUpdateValueOptimisticallyUpdates() async {
        // Given: Profile is loaded
        mockRepository.mockProfile = testProfile
        viewModel.profile = testProfile
        let valueId = testProfile.values[0].id

        // When: Updating value
        await viewModel.updateValue(id: valueId, newContent: "Family and Friends")

        // Then: Value should be updated optimistically
        XCTAssertEqual(viewModel.profile?.values[0].content, "Family and Friends")
        XCTAssertNil(viewModel.editingItem, "Editing item should be cleared")
    }

    func testUpdateValueRollsBackOnError() async {
        // Given: Profile is loaded and repository will fail
        mockRepository.mockProfile = testProfile
        mockRepository.shouldFailOnUpdate = true
        viewModel.profile = testProfile
        let valueId = testProfile.values[0].id

        // When: Updating value fails
        await viewModel.updateValue(id: valueId, newContent: "New Value")

        // Then: Value should be rolled back to original
        XCTAssertEqual(viewModel.profile?.values[0].content, "Family", "Value should be rolled back")
        XCTAssertTrue(viewModel.showError, "Error should be shown")
    }

    // MARK: - Test: Delete Value (AC #3)

    func testRequestDeleteValueShowsConfirmation() {
        // Given: Profile is loaded
        viewModel.profile = testProfile
        let valueId = testProfile.values[0].id

        // When: Requesting deletion
        viewModel.requestDeleteValue(id: valueId)

        // Then: Confirmation should be shown
        XCTAssertTrue(viewModel.showDeleteConfirmation, "Delete confirmation should be shown")
        XCTAssertEqual(viewModel.deletingItemId, valueId, "Deleting item ID should be set")
    }

    func testDeleteValueOptimisticallyRemoves() async {
        // Given: Profile is loaded
        mockRepository.mockProfile = testProfile
        viewModel.profile = testProfile
        let valueId = testProfile.values[0].id
        let originalCount = testProfile.values.count

        // When: Deleting value
        await viewModel.deleteValue(id: valueId)

        // Then: Value should be removed
        XCTAssertEqual(viewModel.profile?.values.count, originalCount - 1)
        XCTAssertFalse(viewModel.profile?.values.contains { $0.id == valueId } ?? true)
    }

    func testDeleteValueRollsBackOnError() async {
        // Given: Profile is loaded and repository will fail
        mockRepository.mockProfile = testProfile
        mockRepository.shouldFailOnUpdate = true
        viewModel.profile = testProfile
        let valueId = testProfile.values[0].id
        let originalCount = testProfile.values.count

        // When: Deleting value fails
        await viewModel.deleteValue(id: valueId)

        // Then: Value should be restored
        XCTAssertEqual(viewModel.profile?.values.count, originalCount, "Value should be restored")
        XCTAssertTrue(viewModel.showError, "Error should be shown")
    }

    // MARK: - Test: Edit Goal (AC #2)

    func testStartEditingGoalSetsEditingItem() {
        // Given: Profile is loaded
        viewModel.profile = testProfile
        let goalId = testProfile.goals[0].id

        // When: Starting to edit a goal
        viewModel.startEditingGoal(id: goalId)

        // Then: Editing item should be set
        XCTAssertNotNil(viewModel.editingItem, "Editing item should be set")
        if case .goal(let id) = viewModel.editingItem?.type {
            XCTAssertEqual(id, goalId, "Editing item should have correct ID")
        } else {
            XCTFail("Editing item type should be .goal")
        }
    }

    func testUpdateGoalOptimisticallyUpdates() async {
        // Given: Profile is loaded
        mockRepository.mockProfile = testProfile
        viewModel.profile = testProfile
        let goalId = testProfile.goals[0].id

        // When: Updating goal
        await viewModel.updateGoal(id: goalId, newContent: "Get promoted to Senior")

        // Then: Goal should be updated
        XCTAssertEqual(viewModel.profile?.goals[0].content, "Get promoted to Senior")
    }

    func testUpdateGoalRollsBackOnError() async {
        // Given: Profile is loaded and repository will fail
        mockRepository.mockProfile = testProfile
        mockRepository.shouldFailOnUpdate = true
        viewModel.profile = testProfile
        let goalId = testProfile.goals[0].id
        let originalContent = testProfile.goals[0].content

        // When: Updating goal fails
        await viewModel.updateGoal(id: goalId, newContent: "New Goal Content")

        // Then: Goal should be rolled back to original
        XCTAssertEqual(viewModel.profile?.goals[0].content, originalContent, "Goal should be rolled back")
        XCTAssertTrue(viewModel.showError, "Error should be shown")
    }

    // MARK: - Test: Toggle Goal Status

    func testToggleGoalStatusChangesFromActiveToAchieved() async {
        // Given: Profile with active goal
        mockRepository.mockProfile = testProfile
        viewModel.profile = testProfile
        let goalId = testProfile.goals[0].id
        XCTAssertEqual(viewModel.profile?.goals[0].status, .active)

        // When: Toggling status
        await viewModel.toggleGoalStatus(id: goalId)

        // Then: Goal should be achieved
        XCTAssertEqual(viewModel.profile?.goals[0].status, .achieved)
    }

    func testToggleGoalStatusChangesFromAchievedToActive() async {
        // Given: Profile with achieved goal
        var profile = testProfile!
        profile.goals[0].markAchieved()
        mockRepository.mockProfile = profile
        viewModel.profile = profile
        let goalId = profile.goals[0].id
        XCTAssertEqual(viewModel.profile?.goals[0].status, .achieved)

        // When: Toggling status
        await viewModel.toggleGoalStatus(id: goalId)

        // Then: Goal should be active
        XCTAssertEqual(viewModel.profile?.goals[0].status, .active)
    }

    // MARK: - Test: Delete Goal (AC #3)

    func testDeleteGoalOptimisticallyRemoves() async {
        // Given: Profile is loaded
        mockRepository.mockProfile = testProfile
        viewModel.profile = testProfile
        let goalId = testProfile.goals[0].id
        let originalCount = testProfile.goals.count

        // When: Deleting goal
        await viewModel.deleteGoal(id: goalId)

        // Then: Goal should be removed
        XCTAssertEqual(viewModel.profile?.goals.count, originalCount - 1)
    }

    // MARK: - Test: Edit Situation (AC #2)

    func testStartEditingSituationSetsEditingItem() {
        // Given: Profile is loaded with situation
        viewModel.profile = testProfile

        // When: Starting to edit situation
        viewModel.startEditingSituation()

        // Then: Editing item should be set
        XCTAssertNotNil(viewModel.editingItem, "Editing item should be set")
        if case .situation = viewModel.editingItem?.type {
            // Success
        } else {
            XCTFail("Editing item type should be .situation")
        }
        XCTAssertEqual(viewModel.editingItem?.currentContent, testProfile.situation.freeform)
    }

    func testUpdateSituationOptimisticallyUpdates() async {
        // Given: Profile is loaded
        mockRepository.mockProfile = testProfile
        viewModel.profile = testProfile

        // When: Updating situation
        await viewModel.updateSituation(newContent: "Starting a new chapter")

        // Then: Situation should be updated
        XCTAssertEqual(viewModel.profile?.situation.freeform, "Starting a new chapter")
    }

    func testUpdateSituationRollsBackOnError() async {
        // Given: Profile is loaded and repository will fail
        mockRepository.mockProfile = testProfile
        mockRepository.shouldFailOnUpdate = true
        viewModel.profile = testProfile
        let originalSituation = testProfile.situation.freeform

        // When: Updating situation fails
        await viewModel.updateSituation(newContent: "New situation")

        // Then: Situation should be rolled back
        XCTAssertEqual(viewModel.profile?.situation.freeform, originalSituation, "Situation should be rolled back")
        XCTAssertTrue(viewModel.showError, "Error should be shown")
    }

    // MARK: - Test: Cancel Operations

    func testCancelEditClearsEditingItem() {
        // Given: An item is being edited
        viewModel.profile = testProfile
        viewModel.startEditingValue(id: testProfile.values[0].id)
        XCTAssertNotNil(viewModel.editingItem)

        // When: Canceling edit
        viewModel.cancelEdit()

        // Then: Editing item should be cleared
        XCTAssertNil(viewModel.editingItem, "Editing item should be nil after cancel")
    }

    func testCancelDeleteClearsState() {
        // Given: A delete is pending confirmation
        viewModel.profile = testProfile
        viewModel.requestDeleteValue(id: testProfile.values[0].id)
        XCTAssertTrue(viewModel.showDeleteConfirmation)
        XCTAssertNotNil(viewModel.deletingItemId)

        // When: Canceling delete
        viewModel.cancelDelete()

        // Then: Delete state should be cleared
        XCTAssertFalse(viewModel.showDeleteConfirmation, "Delete confirmation should be hidden")
        XCTAssertNil(viewModel.deletingItemId, "Deleting item ID should be nil")
    }

    // MARK: - Test: Confirm Delete (AC #3)

    func testConfirmDeleteForValue() async {
        // Given: A value deletion is pending
        mockRepository.mockProfile = testProfile
        viewModel.profile = testProfile
        let valueId = testProfile.values[0].id
        viewModel.requestDeleteValue(id: valueId)

        // When: Confirming delete
        await viewModel.confirmDelete()

        // Then: Value should be deleted
        XCTAssertFalse(viewModel.profile?.values.contains { $0.id == valueId } ?? true)
        XCTAssertFalse(viewModel.showDeleteConfirmation)
    }

    func testConfirmDeleteForGoal() async {
        // Given: A goal deletion is pending
        mockRepository.mockProfile = testProfile
        viewModel.profile = testProfile
        let goalId = testProfile.goals[0].id
        viewModel.requestDeleteGoal(id: goalId)

        // When: Confirming delete
        await viewModel.confirmDelete()

        // Then: Goal should be deleted
        XCTAssertFalse(viewModel.profile?.goals.contains { $0.id == goalId } ?? true)
        XCTAssertFalse(viewModel.showDeleteConfirmation)
    }

    // MARK: - Test: Error Handling (AC #5)

    func testDismissErrorClearsError() {
        // Given: An error is showing
        viewModel.error = .saveFailed("Test error")
        viewModel.showError = true

        // When: Dismissing error
        viewModel.dismissError()

        // Then: Error should be cleared
        XCTAssertFalse(viewModel.showError, "showError should be false")
        XCTAssertNil(viewModel.error, "error should be nil")
    }

    // MARK: - Test: Refresh Profile

    func testRefreshProfileReloadsData() async {
        // Given: Profile is loaded
        mockRepository.mockProfile = testProfile
        await viewModel.loadProfile(userId: testUserId)

        // Update the mock profile
        var updatedProfile = testProfile!
        updatedProfile.addValue(ContextValue.userValue("New Value"))
        mockRepository.mockProfile = updatedProfile

        // When: Refreshing profile
        await viewModel.refreshProfile()

        // Then: Profile should have new data
        XCTAssertEqual(viewModel.profile?.values.count, 3)
    }

    // MARK: - Test: Saving State (AC #5)

    func testUpdateValueSetsSavingState() async {
        // Given: Profile is loaded
        mockRepository.mockProfile = testProfile
        mockRepository.delay = 0.1
        viewModel.profile = testProfile
        let valueId = testProfile.values[0].id

        // When: Starting update
        let updateTask = Task {
            await viewModel.updateValue(id: valueId, newContent: "New content")
        }

        // Give a moment for saving state to be set
        try? await Task.sleep(nanoseconds: 50_000_000)

        // Then: Saving should be true during operation
        XCTAssertTrue(viewModel.isSaving, "isSaving should be true during update")

        await updateTask.value
        XCTAssertFalse(viewModel.isSaving, "isSaving should be false after completion")
    }
}

// MARK: - Mock Repository for Viewing Tests

@MainActor
final class MockContextRepositoryForViewing: ContextRepositoryProtocol {

    var mockProfile: ContextProfile?
    var shouldFailOnUpdate = false
    var delay: TimeInterval = 0

    func createProfile(for userId: UUID) async throws -> ContextProfile {
        return mockProfile ?? ContextProfile.empty(userId: userId)
    }

    func fetchProfile(userId: UUID) async throws -> ContextProfile {
        if delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        if let profile = mockProfile {
            return profile
        }
        throw ContextError.notFound
    }

    func updateProfile(_ profile: ContextProfile) async throws {
        if delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        if shouldFailOnUpdate {
            throw ContextError.saveFailed("Mock update failure")
        }
        mockProfile = profile
    }

    func getLocalProfile(userId: UUID) async throws -> ContextProfile? {
        return mockProfile
    }

    func profileExists(userId: UUID) async -> Bool {
        return mockProfile != nil
    }

    func deleteProfile(userId: UUID) async throws {
        mockProfile = nil
    }

    func markFirstSessionComplete(userId: UUID) async throws {}
    func incrementPromptDismissedCount(userId: UUID) async throws {}
    func addInitialContext(userId: UUID, values: String, goals: String, situation: String) async throws {}
    func savePendingInsights(userId: UUID, insights: [ExtractedInsight]) async throws {}
    func getPendingInsights(userId: UUID) async throws -> [ExtractedInsight] { return [] }
    func confirmInsight(userId: UUID, insightId: UUID) async throws {}
    func dismissInsight(userId: UUID, insightId: UUID) async throws {}
}
