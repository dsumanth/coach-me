//
//  ContextPromptViewModelTests.swift
//  CoachMeTests
//
//  Story 2.2: Context Setup Prompt After First Session
//  Tests for ContextPromptViewModel prompt display logic and state management
//

import XCTest
import SwiftData
@testable import CoachMe

@MainActor
final class ContextPromptViewModelTests: XCTestCase {

    private var modelContainer: ModelContainer!
    private var modelContext: ModelContext!
    private var mockRepository: MockContextRepository!
    private var viewModel: ContextPromptViewModel!

    override func setUp() async throws {
        try await super.setUp()
        // Create in-memory container for testing
        let schema = Schema([CachedContextProfile.self])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        modelContext = modelContainer.mainContext

        mockRepository = MockContextRepository()
        viewModel = ContextPromptViewModel(contextRepository: mockRepository)
    }

    override func tearDown() async throws {
        viewModel = nil
        mockRepository = nil
        modelContainer = nil
        modelContext = nil
        try await super.tearDown()
    }

    // MARK: - Test: Prompt shown when firstSessionComplete == false (AC #1)

    func testPromptShownWhenFirstSessionNotComplete() async {
        // Given: A profile where firstSessionComplete is false
        let userId = UUID()
        var profile = ContextProfile.empty(userId: userId)
        profile = ContextProfile(
            id: profile.id,
            userId: userId,
            values: [],
            goals: [],
            situation: .empty,
            extractedInsights: [],
            contextVersion: 1,
            firstSessionComplete: false,
            promptDismissedCount: 0,
            createdAt: Date(),
            updatedAt: Date()
        )
        mockRepository.mockProfile = profile

        // When: Configuring and receiving AI response
        await viewModel.configure(userId: userId)
        viewModel.onAIResponseReceived() // First exchange
        viewModel.onAIResponseReceived() // Second message (triggers check)

        // Then: Prompt should be shown
        XCTAssertTrue(viewModel.showPrompt, "Prompt should be shown when firstSessionComplete is false")
    }

    func testPromptShownWhenNoProfileExists() async {
        // Given: No profile exists (new user)
        let userId = UUID()
        mockRepository.mockProfile = nil

        // When: Configuring and receiving AI response
        await viewModel.configure(userId: userId)
        viewModel.onAIResponseReceived()
        viewModel.onAIResponseReceived()

        // Then: Prompt should be shown
        XCTAssertTrue(viewModel.showPrompt, "Prompt should be shown when no profile exists")
    }

    // MARK: - Test: Prompt NOT shown when hasContext == true (AC #2)

    func testPromptNotShownWhenUserHasContext() async {
        // Given: A profile with existing context (values, goals, or situation)
        let userId = UUID()
        var profile = ContextProfile.empty(userId: userId)
        profile.addValue(ContextValue.userValue("Test value"))
        // Create a new profile with firstSessionComplete = true and the added value
        profile = ContextProfile(
            id: profile.id,
            userId: userId,
            values: profile.values,
            goals: [],
            situation: .empty,
            extractedInsights: [],
            contextVersion: 1,
            firstSessionComplete: true,
            promptDismissedCount: 0,
            createdAt: Date(),
            updatedAt: Date()
        )
        mockRepository.mockProfile = profile

        // When: Configuring and receiving AI response
        await viewModel.configure(userId: userId)
        viewModel.onAIResponseReceived()
        viewModel.onAIResponseReceived()

        // Then: Prompt should NOT be shown
        XCTAssertFalse(viewModel.showPrompt, "Prompt should NOT be shown when user already has context")
    }

    func testPromptNotShownWhenFirstSessionCompleteAndHasContext() async {
        // Given: A profile that's complete with goals
        let userId = UUID()
        var profile = ContextProfile.empty(userId: userId)
        profile.addGoal(ContextGoal.userGoal("Get healthier"))
        profile = ContextProfile(
            id: profile.id,
            userId: userId,
            values: [],
            goals: profile.goals,
            situation: .empty,
            extractedInsights: [],
            contextVersion: 1,
            firstSessionComplete: true,
            promptDismissedCount: 0,
            createdAt: Date(),
            updatedAt: Date()
        )
        mockRepository.mockProfile = profile

        // When: Configuring and receiving AI response
        await viewModel.configure(userId: userId)
        viewModel.onAIResponseReceived()
        viewModel.onAIResponseReceived()

        // Then: Prompt should NOT be shown
        XCTAssertFalse(viewModel.showPrompt, "Prompt should NOT be shown when user has goals")
    }

    // MARK: - Test: Accept Prompt Flow (AC #3)

    func testAcceptPromptShowsSetupForm() {
        // Given: Prompt is showing
        viewModel.showPrompt = true

        // When: User accepts prompt
        viewModel.acceptPrompt()

        // Then: Should hide prompt and show setup form
        XCTAssertFalse(viewModel.showPrompt, "Prompt should be hidden after accepting")
        XCTAssertTrue(viewModel.showSetupForm, "Setup form should be shown after accepting")
    }

    // MARK: - Test: Dismiss Prompt Flow (AC #4)

    func testDismissPromptIncrementsCount() async {
        // Given: A profile and configured view model
        let userId = UUID()
        let profile = ContextProfile.empty(userId: userId)
        mockRepository.mockProfile = profile

        await viewModel.configure(userId: userId)
        viewModel.showPrompt = true

        // When: User dismisses prompt
        await viewModel.dismissPrompt()

        // Then: Should call incrementPromptDismissedCount
        XCTAssertTrue(mockRepository.incrementPromptDismissedCountCalled, "Should increment dismiss count on dismissal")
        XCTAssertEqual(mockRepository.lastIncrementedUserId, userId)
    }

    func testDismissPromptMarksFirstSessionComplete() async {
        // Given: A profile and configured view model
        let userId = UUID()
        let profile = ContextProfile.empty(userId: userId)
        mockRepository.mockProfile = profile

        await viewModel.configure(userId: userId)
        viewModel.showPrompt = true

        // When: User dismisses prompt
        await viewModel.dismissPrompt()

        // Then: Should mark first session complete
        XCTAssertTrue(mockRepository.markFirstSessionCompleteCalled, "Should mark first session complete on dismissal")
    }

    func testDismissPromptHidesPrompt() async {
        // Given: Prompt is showing
        let userId = UUID()
        let profile = ContextProfile.empty(userId: userId)
        mockRepository.mockProfile = profile

        await viewModel.configure(userId: userId)
        viewModel.showPrompt = true

        // When: User dismisses prompt
        await viewModel.dismissPrompt()

        // Then: Prompt should be hidden
        XCTAssertFalse(viewModel.showPrompt, "Prompt should be hidden after dismissal")
    }

    // MARK: - Test: Save Initial Context (AC #5, #6)

    func testSaveInitialContextCallsRepository() async {
        // Given: A configured view model
        let userId = UUID()
        let profile = ContextProfile.empty(userId: userId)
        mockRepository.mockProfile = profile

        await viewModel.configure(userId: userId)
        viewModel.showSetupForm = true

        // When: User saves context
        await viewModel.saveInitialContext(
            values: "Family, Health",
            goals: "Get fit, Learn guitar",
            situation: "Mid-career transition"
        )

        // Then: Should call addInitialContext on repository
        XCTAssertTrue(mockRepository.addInitialContextCalled, "Should call addInitialContext")
        XCTAssertEqual(mockRepository.lastContextValues, "Family, Health")
        XCTAssertEqual(mockRepository.lastContextGoals, "Get fit, Learn guitar")
        XCTAssertEqual(mockRepository.lastContextSituation, "Mid-career transition")
    }

    func testSaveInitialContextHidesForm() async {
        // Given: A configured view model with form showing
        let userId = UUID()
        let profile = ContextProfile.empty(userId: userId)
        mockRepository.mockProfile = profile

        await viewModel.configure(userId: userId)
        viewModel.showSetupForm = true

        // When: User saves context
        await viewModel.saveInitialContext(
            values: "Test",
            goals: "Test goal",
            situation: "Test situation"
        )

        // Then: Form should be hidden
        XCTAssertFalse(viewModel.showSetupForm, "Setup form should be hidden after saving")
    }

    func testSaveInitialContextMarksFirstSessionComplete() async {
        // Given: A configured view model
        let userId = UUID()
        let profile = ContextProfile.empty(userId: userId)
        mockRepository.mockProfile = profile

        await viewModel.configure(userId: userId)

        // When: User saves context
        await viewModel.saveInitialContext(
            values: "Test",
            goals: "Goal",
            situation: "Situation"
        )

        // Then: Should mark first session complete
        XCTAssertTrue(mockRepository.markFirstSessionCompleteCalled, "Should mark first session complete after saving context")
    }

    // MARK: - Test: Re-prompt Logic (AC #7)

    func testRePromptAfterSession3WhenPreviouslyDismissed() async {
        // Given: A profile that was dismissed once and session count >= 3
        let userId = UUID()
        var profile = ContextProfile.empty(userId: userId)
        profile = ContextProfile(
            id: profile.id,
            userId: userId,
            values: [],
            goals: [],
            situation: .empty,
            extractedInsights: [],
            contextVersion: 1,
            firstSessionComplete: true,
            promptDismissedCount: 1,  // Dismissed once
            createdAt: Date(),
            updatedAt: Date()
        )
        mockRepository.mockProfile = profile

        // When: Configuring and simulating 3 complete sessions (6 messages)
        await viewModel.configure(userId: userId)

        // Simulate 3 complete exchanges (each exchange = 2 messages)
        for _ in 0..<6 {
            viewModel.onAIResponseReceived()
        }

        // Then: Prompt should be shown again
        XCTAssertTrue(viewModel.showPrompt, "Prompt should be shown again after session 3 when previously dismissed")
    }

    func testNoRePromptBeforeSession3() async {
        // Given: A profile that was dismissed once but less than 3 sessions
        let userId = UUID()
        var profile = ContextProfile.empty(userId: userId)
        profile = ContextProfile(
            id: profile.id,
            userId: userId,
            values: [],
            goals: [],
            situation: .empty,
            extractedInsights: [],
            contextVersion: 1,
            firstSessionComplete: true,
            promptDismissedCount: 1,  // Dismissed once
            createdAt: Date(),
            updatedAt: Date()
        )
        mockRepository.mockProfile = profile

        // When: Configuring and simulating 2 sessions (4 messages)
        await viewModel.configure(userId: userId)

        // Simulate 2 exchanges
        for _ in 0..<4 {
            viewModel.onAIResponseReceived()
        }

        // Then: Prompt should NOT be shown yet
        XCTAssertFalse(viewModel.showPrompt, "Prompt should NOT be shown before session 3")
    }

    // MARK: - Test: Skip Setup

    func testSkipSetupHidesForm() async {
        // Given: Setup form is showing
        let userId = UUID()
        let profile = ContextProfile.empty(userId: userId)
        mockRepository.mockProfile = profile

        await viewModel.configure(userId: userId)
        viewModel.showSetupForm = true

        // When: User skips setup
        await viewModel.skipSetup()

        // Then: Form should be hidden
        XCTAssertFalse(viewModel.showSetupForm, "Setup form should be hidden after skipping")
    }

    func testSkipSetupMarksFirstSessionComplete() async {
        // Given: Setup form is showing
        let userId = UUID()
        let profile = ContextProfile.empty(userId: userId)
        mockRepository.mockProfile = profile

        await viewModel.configure(userId: userId)
        viewModel.showSetupForm = true

        // When: User skips setup
        await viewModel.skipSetup()

        // Then: Should mark first session complete
        XCTAssertTrue(mockRepository.markFirstSessionCompleteCalled, "Should mark first session complete even when skipping")
    }

    // MARK: - Test: Session Count Reset

    func testResetSessionCountClearsCount() async {
        // Given: Some messages have been received
        let userId = UUID()
        mockRepository.mockProfile = nil

        await viewModel.configure(userId: userId)
        viewModel.onAIResponseReceived()

        // When: Resetting session count
        viewModel.resetSessionCount()

        // Then: Message count should be reset (prompt won't show on first message)
        // We can't directly access sessionMessageCount, but we can verify behavior
        // by checking that prompt doesn't show after just one more message
        viewModel.onAIResponseReceived()
        XCTAssertFalse(viewModel.showPrompt, "After reset, prompt should not show on first message")
    }

    // MARK: - Test: Error Handling

    func testSaveInitialContextShowsErrorOnFailure() async {
        // Given: Repository will fail
        let userId = UUID()
        let profile = ContextProfile.empty(userId: userId)
        mockRepository.mockProfile = profile
        mockRepository.shouldFailOnSave = true

        await viewModel.configure(userId: userId)

        // When: Saving context fails
        await viewModel.saveInitialContext(
            values: "Test",
            goals: "Goal",
            situation: "Situation"
        )

        // Then: Error should be shown
        XCTAssertTrue(viewModel.showError, "Should show error on save failure")
        XCTAssertNotNil(viewModel.error, "Error should be set")
    }

    func testDismissErrorClearsError() {
        // Given: An error is set
        viewModel.error = .saveFailed("Test error")
        viewModel.showError = true

        // When: Dismissing error
        viewModel.dismissError()

        // Then: Error should be cleared
        XCTAssertFalse(viewModel.showError, "showError should be false")
        XCTAssertNil(viewModel.error, "error should be nil")
    }
}

// MARK: - Mock Context Repository

@MainActor
final class MockContextRepository: ContextRepositoryProtocol {

    var mockProfile: ContextProfile?
    var shouldFailOnSave = false

    // Tracking calls
    var incrementPromptDismissedCountCalled = false
    var markFirstSessionCompleteCalled = false
    var addInitialContextCalled = false

    var lastIncrementedUserId: UUID?
    var lastContextValues: String?
    var lastContextGoals: String?
    var lastContextSituation: String?

    func createProfile(for userId: UUID) async throws -> ContextProfile {
        return mockProfile ?? ContextProfile.empty(userId: userId)
    }

    func fetchProfile(userId: UUID) async throws -> ContextProfile {
        if let profile = mockProfile {
            return profile
        }
        throw ContextError.notFound
    }

    func updateProfile(_ profile: ContextProfile) async throws {
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

    func markFirstSessionComplete(userId: UUID) async throws {
        markFirstSessionCompleteCalled = true
    }

    func incrementPromptDismissedCount(userId: UUID) async throws {
        incrementPromptDismissedCountCalled = true
        lastIncrementedUserId = userId
    }

    func addInitialContext(userId: UUID, values: String, goals: String, situation: String) async throws {
        if shouldFailOnSave {
            throw ContextError.saveFailed("Mock save failure")
        }
        addInitialContextCalled = true
        lastContextValues = values
        lastContextGoals = goals
        lastContextSituation = situation
    }

    // Story 2.3 methods (not used by ContextPromptViewModel but required by protocol)
    func savePendingInsights(userId: UUID, insights: [ExtractedInsight]) async throws {}
    func getPendingInsights(userId: UUID) async throws -> [ExtractedInsight] { return [] }
    func confirmInsight(userId: UUID, insightId: UUID) async throws {}
    func dismissInsight(userId: UUID, insightId: UUID) async throws {}
}
