//
//  LearnedKnowledgeViewModelTests.swift
//  CoachMeTests
//
//  Story 8.8: Enhanced Profile — Learned Knowledge Display
//  Tests for ContextViewModel learned knowledge computed properties and actions
//

import XCTest
@testable import CoachMe

@MainActor
final class LearnedKnowledgeViewModelTests: XCTestCase {

    private var mockRepository: MockLearnedKnowledgeRepository!
    private var viewModel: ContextViewModel!
    private var testUserId: UUID!

    override func setUp() async throws {
        try await super.setUp()
        testUserId = UUID()
        mockRepository = MockLearnedKnowledgeRepository()
        viewModel = ContextViewModel(contextRepository: mockRepository)
    }

    override func tearDown() async throws {
        viewModel = nil
        mockRepository = nil
        testUserId = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func loadProfileWithPatterns(_ patterns: [InferredPattern] = [],
                                          style: CoachingStyleInfo? = nil,
                                          manualOverrides: ManualOverrides? = nil,
                                          domainUsageStats: DomainUsageStats? = nil,
                                          progressNotes: [ProgressNote]? = nil,
                                          dismissedInsights: DismissedInsights? = nil) async {
        var profile = ContextProfile.empty(userId: testUserId)
        profile.coachingPreferences.inferredPatterns = patterns.isEmpty ? nil : patterns
        profile.coachingPreferences.coachingStyle = style
        profile.coachingPreferences.manualOverrides = manualOverrides
        profile.coachingPreferences.domainUsageStats = domainUsageStats
        profile.coachingPreferences.progressNotes = progressNotes
        profile.coachingPreferences.dismissedInsights = dismissedInsights
        mockRepository.mockProfile = profile
        await viewModel.loadProfile(userId: testUserId)
    }

    private func makePattern(text: String = "Test pattern",
                              category: String = "growth",
                              confidence: Double = 0.8,
                              sourceCount: Int = 3) -> InferredPattern {
        InferredPattern(
            id: UUID(),
            patternText: text,
            category: category,
            confidence: confidence,
            sourceCount: sourceCount,
            lastObserved: nil
        )
    }

    // MARK: - Computed Properties: inferredPatterns

    func testInferredPatternsEmptyWhenNoProfile() {
        // No profile loaded
        XCTAssertTrue(viewModel.inferredPatterns.isEmpty)
    }

    func testInferredPatternsEmptyWhenNilInPrefs() async {
        await loadProfileWithPatterns()
        XCTAssertTrue(viewModel.inferredPatterns.isEmpty)
    }

    func testInferredPatternsReturnsPatternsFromProfile() async {
        let patterns = [makePattern(text: "Pattern A"), makePattern(text: "Pattern B")]
        await loadProfileWithPatterns(patterns)

        XCTAssertEqual(viewModel.inferredPatterns.count, 2)
        XCTAssertEqual(viewModel.inferredPatterns[0].patternText, "Pattern A")
        XCTAssertEqual(viewModel.inferredPatterns[1].patternText, "Pattern B")
    }

    // MARK: - Computed Properties: coachingStyle

    func testCoachingStyleNilWhenNoProfile() {
        XCTAssertNil(viewModel.coachingStyle)
    }

    func testCoachingStyleReturnsFromProfile() async {
        let style = CoachingStyleInfo(inferredStyle: "Exploratory", confidence: 0.9, lastInferred: nil)
        await loadProfileWithPatterns(style: style)

        XCTAssertEqual(viewModel.coachingStyle?.inferredStyle, "Exploratory")
        XCTAssertEqual(viewModel.coachingStyle?.confidence, 0.9)
    }

    // MARK: - Computed Properties: domainUsage

    func testDomainUsageNilWhenNoProfile() {
        XCTAssertNil(viewModel.domainUsage)
    }

    func testDomainUsageReturnsFromProfile() async {
        let stats = DomainUsageStats(domains: ["career": 0.6, "relationships": 0.4])
        await loadProfileWithPatterns(domainUsageStats: stats)

        XCTAssertEqual(viewModel.domainUsage?.domains.count, 2)
        XCTAssertEqual(viewModel.domainUsage?.domains["career"], 0.6)
    }

    // MARK: - Computed Properties: progressNotes

    func testProgressNotesEmptyWhenNoProfile() {
        XCTAssertTrue(viewModel.progressNotes.isEmpty)
    }

    func testProgressNotesReturnsFromProfile() async {
        let notes = [ProgressNote(id: UUID(), goal: "Run marathon", progressText: "Completed 10K", lastUpdated: nil)]
        await loadProfileWithPatterns(progressNotes: notes)

        XCTAssertEqual(viewModel.progressNotes.count, 1)
        XCTAssertEqual(viewModel.progressNotes[0].goal, "Run marathon")
    }

    // MARK: - Computed Properties: hasLearnedKnowledge

    func testHasLearnedKnowledgeFalseWhenEmpty() async {
        await loadProfileWithPatterns()
        XCTAssertFalse(viewModel.hasLearnedKnowledge)
    }

    func testHasLearnedKnowledgeTrueWithPatterns() async {
        await loadProfileWithPatterns([makePattern()])
        XCTAssertTrue(viewModel.hasLearnedKnowledge)
    }

    func testHasLearnedKnowledgeTrueWithInferredStyle() async {
        let style = CoachingStyleInfo(inferredStyle: "Direct", confidence: 0.8, lastInferred: nil)
        await loadProfileWithPatterns(style: style)
        XCTAssertTrue(viewModel.hasLearnedKnowledge)
    }

    func testHasLearnedKnowledgeTrueWithDomainUsage() async {
        let stats = DomainUsageStats(domains: ["career": 1.0])
        await loadProfileWithPatterns(domainUsageStats: stats)
        XCTAssertTrue(viewModel.hasLearnedKnowledge)
    }

    func testHasLearnedKnowledgeTrueWithProgressNotes() async {
        let notes = [ProgressNote(id: UUID(), goal: "Goal", progressText: "Progress", lastUpdated: nil)]
        await loadProfileWithPatterns(progressNotes: notes)
        XCTAssertTrue(viewModel.hasLearnedKnowledge)
    }

    func testHasLearnedKnowledgeFalseWithEmptyDomains() async {
        let stats = DomainUsageStats(domains: [:])
        await loadProfileWithPatterns(domainUsageStats: stats)
        XCTAssertFalse(viewModel.hasLearnedKnowledge)
    }

    // MARK: - Computed Properties: effectiveCoachingStyle

    func testEffectiveCoachingStyleNilWhenNoProfile() {
        XCTAssertNil(viewModel.effectiveCoachingStyle)
    }

    func testEffectiveCoachingStyleUsesInferredWhenNoOverride() async {
        let style = CoachingStyleInfo(inferredStyle: "Exploratory", confidence: 0.9, lastInferred: nil)
        await loadProfileWithPatterns(style: style)

        XCTAssertEqual(viewModel.effectiveCoachingStyle, "Exploratory")
    }

    func testEffectiveCoachingStyleManualOverrideWins() async {
        let style = CoachingStyleInfo(inferredStyle: "Exploratory", confidence: 0.9, lastInferred: nil)
        let manual = ManualOverrides(style: "Direct", setAt: Date())
        await loadProfileWithPatterns(style: style, manualOverrides: manual)

        XCTAssertEqual(viewModel.effectiveCoachingStyle, "Direct")
    }

    // MARK: - Computed Properties: hasManualStyleOverride

    func testHasManualStyleOverrideFalseWhenNoOverride() async {
        await loadProfileWithPatterns()
        XCTAssertFalse(viewModel.hasManualStyleOverride)
    }

    func testHasManualStyleOverrideTrueWhenSet() async {
        let manual = ManualOverrides(style: "Supportive", setAt: Date())
        await loadProfileWithPatterns(manualOverrides: manual)

        XCTAssertTrue(viewModel.hasManualStyleOverride)
    }

    // MARK: - Action: dismissLearnedInsight

    func testDismissLearnedInsightRemovesPattern() async {
        let pattern = makePattern(text: "To be dismissed")
        let keepPattern = makePattern(text: "Keep this")
        await loadProfileWithPatterns([pattern, keepPattern])

        await viewModel.dismissLearnedInsight(id: pattern.id)

        XCTAssertEqual(viewModel.inferredPatterns.count, 1)
        XCTAssertEqual(viewModel.inferredPatterns[0].patternText, "Keep this")
    }

    func testDismissLearnedInsightAddsToDismissedList() async {
        let pattern = makePattern()
        await loadProfileWithPatterns([pattern])

        await viewModel.dismissLearnedInsight(id: pattern.id)

        let dismissed = viewModel.profile?.coachingPreferences.dismissedInsights
        XCTAssertTrue(dismissed?.insightIds.contains(pattern.id) ?? false)
        XCTAssertNotNil(dismissed?.lastDismissed)
    }

    func testDismissLearnedInsightClearsDialogState() async {
        let pattern = makePattern()
        await loadProfileWithPatterns([pattern])

        viewModel.deletingLearnedItemId = pattern.id
        viewModel.showDeleteLearnedConfirmation = true

        await viewModel.dismissLearnedInsight(id: pattern.id)

        XCTAssertFalse(viewModel.showDeleteLearnedConfirmation)
        XCTAssertNil(viewModel.deletingLearnedItemId)
    }

    func testDismissLearnedInsightCallsUpdateProfile() async {
        let pattern = makePattern()
        await loadProfileWithPatterns([pattern])

        await viewModel.dismissLearnedInsight(id: pattern.id)

        XCTAssertTrue(mockRepository.updateProfileCalled)
    }

    func testDismissLearnedInsightRollbackOnError() async {
        let pattern = makePattern(text: "Should survive")
        await loadProfileWithPatterns([pattern])

        mockRepository.shouldFailOnUpdate = true
        await viewModel.dismissLearnedInsight(id: pattern.id)

        // Should rollback — pattern should still be there
        XCTAssertEqual(viewModel.inferredPatterns.count, 1)
        XCTAssertEqual(viewModel.inferredPatterns[0].patternText, "Should survive")
        XCTAssertTrue(viewModel.showError)
    }

    func testDismissLearnedInsightNoOpWhenNoProfile() async {
        // No profile loaded
        await viewModel.dismissLearnedInsight(id: UUID())
        XCTAssertFalse(mockRepository.updateProfileCalled)
    }

    // MARK: - Action: setStyleOverride

    func testSetStyleOverrideSetsManualOverride() async {
        await loadProfileWithPatterns()

        await viewModel.setStyleOverride("Direct")

        XCTAssertEqual(viewModel.profile?.coachingPreferences.manualOverrides?.style, "Direct")
        XCTAssertNotNil(viewModel.profile?.coachingPreferences.manualOverrides?.setAt)
    }

    func testSetStyleOverrideCallsUpdateProfile() async {
        await loadProfileWithPatterns()

        await viewModel.setStyleOverride("Challenging")

        XCTAssertTrue(mockRepository.updateProfileCalled)
    }

    func testSetStyleOverrideRollbackOnError() async {
        let style = CoachingStyleInfo(inferredStyle: "Exploratory", confidence: 0.8, lastInferred: nil)
        await loadProfileWithPatterns(style: style)

        mockRepository.shouldFailOnUpdate = true
        await viewModel.setStyleOverride("Direct")

        // Should rollback — no manual override
        XCTAssertNil(viewModel.profile?.coachingPreferences.manualOverrides)
        XCTAssertTrue(viewModel.showError)
    }

    func testSetStyleOverrideNoOpWhenNoProfile() async {
        await viewModel.setStyleOverride("Direct")
        XCTAssertFalse(mockRepository.updateProfileCalled)
    }

    // MARK: - Action: clearStyleOverride

    func testClearStyleOverrideRemovesManualOverride() async {
        let manual = ManualOverrides(style: "Direct", setAt: Date())
        await loadProfileWithPatterns(manualOverrides: manual)

        await viewModel.clearStyleOverride()

        XCTAssertNil(viewModel.profile?.coachingPreferences.manualOverrides)
    }

    func testClearStyleOverrideCallsUpdateProfile() async {
        let manual = ManualOverrides(style: "Direct", setAt: Date())
        await loadProfileWithPatterns(manualOverrides: manual)

        await viewModel.clearStyleOverride()

        XCTAssertTrue(mockRepository.updateProfileCalled)
    }

    func testClearStyleOverrideRollbackOnError() async {
        let manual = ManualOverrides(style: "Direct", setAt: Date())
        await loadProfileWithPatterns(manualOverrides: manual)

        mockRepository.shouldFailOnUpdate = true
        await viewModel.clearStyleOverride()

        // Should rollback — override should still be there
        XCTAssertEqual(viewModel.profile?.coachingPreferences.manualOverrides?.style, "Direct")
        XCTAssertTrue(viewModel.showError)
    }

    func testClearStyleOverrideNoOpWhenNoProfile() async {
        await viewModel.clearStyleOverride()
        XCTAssertFalse(mockRepository.updateProfileCalled)
    }

    // MARK: - Saving State

    func testSavingStateFalseBeforeAndAfterDismiss() async {
        let pattern = makePattern()
        await loadProfileWithPatterns([pattern])

        // Before action
        XCTAssertFalse(viewModel.isSaving)

        await viewModel.dismissLearnedInsight(id: pattern.id)

        // After action completes
        XCTAssertFalse(viewModel.isSaving)
    }

    func testSavingStateFalseBeforeAndAfterSetOverride() async {
        await loadProfileWithPatterns()

        XCTAssertFalse(viewModel.isSaving)
        await viewModel.setStyleOverride("Direct")
        XCTAssertFalse(viewModel.isSaving)
    }
}

// MARK: - Mock Repository

final class MockLearnedKnowledgeRepository: ContextRepositoryProtocol {

    var mockProfile: ContextProfile?
    var shouldFailOnUpdate = false
    var updateProfileCalled = false

    func createProfile(for userId: UUID) async throws -> ContextProfile {
        mockProfile ?? ContextProfile.empty(userId: userId)
    }

    func fetchProfile(userId: UUID) async throws -> ContextProfile {
        if let profile = mockProfile { return profile }
        throw ContextError.notFound
    }

    func updateProfile(_ profile: ContextProfile) async throws {
        updateProfileCalled = true
        if shouldFailOnUpdate {
            throw ContextError.saveFailed("Mock update failure")
        }
        mockProfile = profile
    }

    func getLocalProfile(userId: UUID) async throws -> ContextProfile? { mockProfile }
    func profileExists(userId: UUID) async -> Bool { mockProfile != nil }
    func deleteProfile(userId: UUID) async throws { mockProfile = nil }
    func markFirstSessionComplete(userId: UUID) async throws {}
    func incrementPromptDismissedCount(userId: UUID) async throws {}
    func addInitialContext(userId: UUID, values: String, goals: String, situation: String) async throws {}
    func savePendingInsights(userId: UUID, insights: [ExtractedInsight]) async throws {}
    func getPendingInsights(userId: UUID) async throws -> [ExtractedInsight] { [] }
    func confirmInsight(userId: UUID, insightId: UUID) async throws {}
    func dismissInsight(userId: UUID, insightId: UUID) async throws {}
}
