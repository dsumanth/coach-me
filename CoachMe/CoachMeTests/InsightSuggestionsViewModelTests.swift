//
//  InsightSuggestionsViewModelTests.swift
//  CoachMeTests
//
//  Story 2.3: Progressive Context Extraction
//  Tests for InsightSuggestionsViewModel state management and business logic
//

import XCTest
import SwiftData
@testable import CoachMe

@MainActor
final class InsightSuggestionsViewModelTests: XCTestCase {

    private var mockRepository: MockContextRepository2_3!
    private var mockExtractionService: MockContextExtractionService!
    private var viewModel: InsightSuggestionsViewModel!

    override func setUp() async throws {
        try await super.setUp()
        mockRepository = MockContextRepository2_3()
        mockExtractionService = MockContextExtractionService()
        viewModel = InsightSuggestionsViewModel(
            extractionService: mockExtractionService,
            contextRepository: mockRepository
        )
    }

    override func tearDown() async throws {
        viewModel = nil
        mockRepository = nil
        mockExtractionService = nil
        try await super.tearDown()
    }

    // MARK: - Test: Configuration loads existing pending insights

    func testConfigureLoadsPendingInsights() async {
        // Given: A user with existing pending insights
        let userId = UUID()
        let existingInsights = [
            ExtractedInsight.pending(content: "Values family", category: .value, confidence: 0.85),
            ExtractedInsight.pending(content: "Career change goal", category: .goal, confidence: 0.9)
        ]
        mockRepository.mockPendingInsights = existingInsights

        // When: Configuring the view model
        await viewModel.configure(userId: userId)

        // Then: Pending insights should be loaded
        XCTAssertEqual(viewModel.pendingInsights.count, 2)
        XCTAssertTrue(viewModel.hasPendingInsights)
    }

    func testConfigureHandlesNoPendingInsights() async {
        // Given: A user with no pending insights
        let userId = UUID()
        mockRepository.mockPendingInsights = []

        // When: Configuring the view model
        await viewModel.configure(userId: userId)

        // Then: No pending insights
        XCTAssertEqual(viewModel.pendingInsights.count, 0)
        XCTAssertFalse(viewModel.hasPendingInsights)
    }

    // MARK: - Test: Extraction trigger at intervals (AC #1)

    func testExtractionTriggeredAtInterval() async {
        // Given: Configured view model
        let userId = UUID()
        let conversationId = UUID()
        mockRepository.mockPendingInsights = []

        // Set up mock extraction response
        mockExtractionService.mockInsights = [
            ExtractedInsight.pending(content: "Test insight", category: .value, confidence: 0.8)
        ]

        await viewModel.configure(userId: userId)
        viewModel.setAuthToken("test-token")

        let messages = [
            ChatMessage(id: UUID(), conversationId: conversationId, role: .user, content: "Test", createdAt: Date()),
            ChatMessage(id: UUID(), conversationId: conversationId, role: .assistant, content: "Response", createdAt: Date())
        ]

        // When: Receiving AI responses (extraction interval is 5)
        for i in 1...5 {
            viewModel.onAIResponseReceived(conversationId: conversationId, messages: messages)

            // Give async task time to run if triggered
            if i == 5 {
                // Wait for background extraction task
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }

        // Then: Extraction should have been triggered at response 5
        XCTAssertTrue(mockExtractionService.extractCalled, "Extraction should be called after interval")
    }

    func testExtractionNotTriggeredBeforeInterval() async {
        // Given: Configured view model
        let userId = UUID()
        let conversationId = UUID()
        mockRepository.mockPendingInsights = []

        await viewModel.configure(userId: userId)

        let messages = [
            ChatMessage(id: UUID(), conversationId: conversationId, role: .user, content: "Test", createdAt: Date())
        ]

        // When: Receiving only 4 AI responses (less than interval of 5)
        for _ in 1...4 {
            viewModel.onAIResponseReceived(conversationId: conversationId, messages: messages)
        }

        // Then: Extraction should NOT be triggered
        XCTAssertFalse(mockExtractionService.extractCalled, "Extraction should not be called before interval")
    }

    // MARK: - Test: Confirm insight (AC #3)

    func testConfirmInsightAddsToProfile() async {
        // Given: A view model with pending insights
        let userId = UUID()
        let insight = ExtractedInsight.pending(content: "Honesty matters", category: .value, confidence: 0.9)
        mockRepository.mockPendingInsights = [insight]

        await viewModel.configure(userId: userId)
        XCTAssertEqual(viewModel.pendingInsights.count, 1)

        // When: Confirming the insight
        await viewModel.confirmInsight(id: insight.id)

        // Then: Insight should be confirmed via repository
        XCTAssertTrue(mockRepository.confirmInsightCalled)
        XCTAssertEqual(mockRepository.lastConfirmedInsightId, insight.id)
    }

    func testConfirmInsightRemovesFromPending() async {
        // Given: A view model with pending insights
        let userId = UUID()
        let insight = ExtractedInsight.pending(content: "Honesty matters", category: .value, confidence: 0.9)
        mockRepository.mockPendingInsights = [insight]

        await viewModel.configure(userId: userId)

        // When: Confirming the insight
        await viewModel.confirmInsight(id: insight.id)

        // Then: Insight should be removed from pending list
        XCTAssertEqual(viewModel.pendingInsights.count, 0)
        XCTAssertFalse(viewModel.hasPendingInsights)
    }

    func testConfirmLastInsightClosesSheet() async {
        // Given: A view model with one pending insight and sheet showing
        let userId = UUID()
        let insight = ExtractedInsight.pending(content: "Test", category: .goal, confidence: 0.85)
        mockRepository.mockPendingInsights = [insight]

        await viewModel.configure(userId: userId)
        viewModel.showSuggestions = true

        // When: Confirming the last insight
        await viewModel.confirmInsight(id: insight.id)

        // Then: Sheet should close
        XCTAssertFalse(viewModel.showSuggestions)
    }

    // MARK: - Test: Dismiss insight (AC #3)

    func testDismissInsightRemovesFromPending() async {
        // Given: A view model with pending insights
        let userId = UUID()
        let insight = ExtractedInsight.pending(content: "Wrong insight", category: .situation, confidence: 0.75)
        mockRepository.mockPendingInsights = [insight]

        await viewModel.configure(userId: userId)

        // When: Dismissing the insight
        await viewModel.dismissInsight(id: insight.id)

        // Then: Insight should be dismissed via repository and removed from pending
        XCTAssertTrue(mockRepository.dismissInsightCalled)
        XCTAssertEqual(mockRepository.lastDismissedInsightId, insight.id)
        XCTAssertEqual(viewModel.pendingInsights.count, 0)
    }

    func testDismissLastInsightClosesSheet() async {
        // Given: A view model with one pending insight and sheet showing
        let userId = UUID()
        let insight = ExtractedInsight.pending(content: "Test", category: .value, confidence: 0.8)
        mockRepository.mockPendingInsights = [insight]

        await viewModel.configure(userId: userId)
        viewModel.showSuggestions = true

        // When: Dismissing the last insight
        await viewModel.dismissInsight(id: insight.id)

        // Then: Sheet should close
        XCTAssertFalse(viewModel.showSuggestions)
    }

    // MARK: - Test: Dismiss all

    func testDismissAllClosesSheetButKeepsPending() async {
        // Given: A view model with pending insights and sheet showing
        let userId = UUID()
        let insights = [
            ExtractedInsight.pending(content: "Insight 1", category: .value, confidence: 0.8),
            ExtractedInsight.pending(content: "Insight 2", category: .goal, confidence: 0.85)
        ]
        mockRepository.mockPendingInsights = insights

        await viewModel.configure(userId: userId)
        viewModel.showSuggestions = true

        // When: Dismissing all
        viewModel.dismissAll()

        // Then: Sheet should close but insights remain for later
        XCTAssertFalse(viewModel.showSuggestions)
        XCTAssertEqual(viewModel.pendingInsights.count, 2, "Pending insights should remain for later review")
    }

    // MARK: - Test: Show suggestions sheet

    func testShowSuggestionsSheetShowsWhenPendingExist() async {
        // Given: A view model with pending insights
        let userId = UUID()
        mockRepository.mockPendingInsights = [
            ExtractedInsight.pending(content: "Test", category: .value, confidence: 0.8)
        ]

        await viewModel.configure(userId: userId)
        XCTAssertFalse(viewModel.showSuggestions)

        // When: Calling showSuggestionsSheet
        viewModel.showSuggestionsSheet()

        // Then: Sheet should show
        XCTAssertTrue(viewModel.showSuggestions)
    }

    func testShowSuggestionsSheetDoesNotShowWhenEmpty() async {
        // Given: A view model with no pending insights
        let userId = UUID()
        mockRepository.mockPendingInsights = []

        await viewModel.configure(userId: userId)

        // When: Calling showSuggestionsSheet
        viewModel.showSuggestionsSheet()

        // Then: Sheet should NOT show
        XCTAssertFalse(viewModel.showSuggestions)
    }

    // MARK: - Test: Deduplication

    func testExtractionDeduplicatesInsights() async {
        // Given: A view model with existing pending insight
        let userId = UUID()
        let conversationId = UUID()
        let existingInsight = ExtractedInsight.pending(content: "Family is important", category: .value, confidence: 0.85)
        mockRepository.mockPendingInsights = [existingInsight]

        // Mock extraction returns same content (different case)
        mockExtractionService.mockInsights = [
            ExtractedInsight.pending(content: "family is important", category: .value, confidence: 0.9)
        ]

        await viewModel.configure(userId: userId)
        viewModel.setAuthToken("test-token")

        let messages = [
            ChatMessage(id: UUID(), conversationId: conversationId, role: .user, content: "Test", createdAt: Date())
        ]

        // When: Triggering extraction
        await viewModel.triggerExtraction(conversationId: conversationId, messages: messages)

        // Then: Duplicate should not be added
        XCTAssertEqual(viewModel.pendingInsights.count, 1, "Duplicate insight should not be added")
    }

    // MARK: - Test: Reset response count

    func testResetResponseCountClearsCounter() async {
        // Given: A view model that has received some responses
        let userId = UUID()
        let conversationId = UUID()
        mockRepository.mockPendingInsights = []

        await viewModel.configure(userId: userId)

        let messages = [
            ChatMessage(id: UUID(), conversationId: conversationId, role: .user, content: "Test", createdAt: Date())
        ]

        // Receive 3 responses
        for _ in 1...3 {
            viewModel.onAIResponseReceived(conversationId: conversationId, messages: messages)
        }

        // When: Resetting response count
        viewModel.resetResponseCount()

        // Then: Should need full interval again to trigger extraction
        // Receive 4 more responses (total would be 7 without reset, but should be 4 now)
        for _ in 1...4 {
            viewModel.onAIResponseReceived(conversationId: conversationId, messages: messages)
        }

        // Extraction should NOT be called (only 4 responses since reset, need 5)
        XCTAssertFalse(mockExtractionService.extractCalled)
    }

    // MARK: - Test: Error handling

    func testConfirmInsightShowsErrorOnFailure() async {
        // Given: Repository will fail on confirm
        let userId = UUID()
        let insight = ExtractedInsight.pending(content: "Test", category: .value, confidence: 0.8)
        mockRepository.mockPendingInsights = [insight]
        mockRepository.shouldFailOnConfirm = true

        await viewModel.configure(userId: userId)

        // When: Confirming fails
        await viewModel.confirmInsight(id: insight.id)

        // Then: Error should be shown
        XCTAssertTrue(viewModel.showError)
        XCTAssertNotNil(viewModel.error)
    }

    func testDismissErrorClearsError() {
        // Given: An error is set
        viewModel.error = .extractionFailed("Test error")
        viewModel.showError = true

        // When: Dismissing error
        viewModel.dismissError()

        // Then: Error should be cleared
        XCTAssertFalse(viewModel.showError)
        XCTAssertNil(viewModel.error)
    }

    // MARK: - Test: Pending count

    func testPendingCountReturnsCorrectValue() async {
        // Given: A view model with multiple pending insights
        let userId = UUID()
        mockRepository.mockPendingInsights = [
            ExtractedInsight.pending(content: "Insight 1", category: .value, confidence: 0.8),
            ExtractedInsight.pending(content: "Insight 2", category: .goal, confidence: 0.85),
            ExtractedInsight.pending(content: "Insight 3", category: .situation, confidence: 0.9)
        ]

        await viewModel.configure(userId: userId)

        // Then: Pending count should match
        XCTAssertEqual(viewModel.pendingCount, 3)
    }
}

// MARK: - Mock Context Extraction Service

@MainActor
final class MockContextExtractionService: ContextExtractionServiceProtocol {
    var mockInsights: [ExtractedInsight] = []
    var extractCalled = false
    var shouldFail = false
    var authToken: String?

    func setAuthToken(_ token: String?) {
        authToken = token
    }

    func extractFromConversation(
        conversationId: UUID,
        messages: [ExtractionMessage]
    ) async throws -> [ExtractedInsight] {
        extractCalled = true
        if shouldFail {
            throw ContextExtractionError.extractionFailed("Mock failure")
        }
        return mockInsights
    }

    func extractFromConversation(
        conversationId: UUID,
        chatMessages: [ChatMessage]
    ) async throws -> [ExtractedInsight] {
        extractCalled = true
        if shouldFail {
            throw ContextExtractionError.extractionFailed("Mock failure")
        }
        return mockInsights
    }
}

// MARK: - Mock Context Repository (Story 2.3 extended)

@MainActor
final class MockContextRepository2_3: ContextRepositoryProtocol {

    var mockProfile: ContextProfile?
    var mockPendingInsights: [ExtractedInsight] = []
    var shouldFailOnSave = false
    var shouldFailOnConfirm = false

    // Tracking calls
    var confirmInsightCalled = false
    var dismissInsightCalled = false
    var savePendingInsightsCalled = false
    var getPendingInsightsCalled = false

    var lastConfirmedInsightId: UUID?
    var lastDismissedInsightId: UUID?

    // Story 2.1 methods
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
        if shouldFailOnSave {
            throw ContextError.saveFailed("Mock failure")
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

    // Story 2.2 methods
    func markFirstSessionComplete(userId: UUID) async throws {}
    func incrementPromptDismissedCount(userId: UUID) async throws {}
    func addInitialContext(userId: UUID, values: String, goals: String, situation: String) async throws {}

    // Story 2.3 methods
    func savePendingInsights(userId: UUID, insights: [ExtractedInsight]) async throws {
        savePendingInsightsCalled = true
        if shouldFailOnSave {
            throw ContextError.saveFailed("Mock failure")
        }
        mockPendingInsights = insights
    }

    func getPendingInsights(userId: UUID) async throws -> [ExtractedInsight] {
        getPendingInsightsCalled = true
        return mockPendingInsights
    }

    func confirmInsight(userId: UUID, insightId: UUID) async throws {
        confirmInsightCalled = true
        lastConfirmedInsightId = insightId
        if shouldFailOnConfirm {
            throw ContextError.saveFailed("Mock confirm failure")
        }
    }

    func dismissInsight(userId: UUID, insightId: UUID) async throws {
        dismissInsightCalled = true
        lastDismissedInsightId = insightId
    }

}
