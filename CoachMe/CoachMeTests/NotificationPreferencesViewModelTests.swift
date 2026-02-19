//
//  NotificationPreferencesViewModelTests.swift
//  CoachMeTests
//
//  Story 8.3: Push Permission Timing & Notification Preferences
//  Tests for NotificationPreferencesViewModel save/load preferences
//

import XCTest
@testable import CoachMe

@MainActor
final class NotificationPreferencesViewModelTests: XCTestCase {

    private var mockRepo: MockNotificationContextRepository!
    private var viewModel: NotificationPreferencesViewModel!
    private let testUserId = UUID()

    override func setUp() {
        super.setUp()
        mockRepo = MockNotificationContextRepository()
        viewModel = NotificationPreferencesViewModel(contextRepository: mockRepo)
    }

    // MARK: - Load Tests

    func testLoadWithNoPreferencesShowsDefaults() async {
        let profile = ContextProfile.empty(userId: testUserId)
        mockRepo.mockProfile = profile

        await viewModel.load(userId: testUserId)

        XCTAssertFalse(viewModel.checkInsEnabled, "Should default to disabled when no preferences saved")
        XCTAssertEqual(viewModel.frequency, .fewTimesAWeek, "Should default to few times a week")
    }

    func testLoadWithExistingPreferences() async {
        var profile = ContextProfile.empty(userId: testUserId)
        profile.notificationPreferences = NotificationPreference(
            checkInsEnabled: true,
            frequency: .daily
        )
        mockRepo.mockProfile = profile

        await viewModel.load(userId: testUserId)

        XCTAssertTrue(viewModel.checkInsEnabled)
        XCTAssertEqual(viewModel.frequency, .daily)
    }

    func testLoadShowsErrorOnFailure() async {
        mockRepo.shouldFailOnFetch = true

        await viewModel.load(userId: testUserId)

        XCTAssertTrue(viewModel.showError)
        XCTAssertNotNil(viewModel.error)
    }

    // MARK: - Save Tests

    func testSaveUpdatesProfile() async {
        var profile = ContextProfile.empty(userId: testUserId)
        profile.notificationPreferences = nil
        mockRepo.mockProfile = profile

        await viewModel.load(userId: testUserId)

        viewModel.checkInsEnabled = true
        viewModel.frequency = .weekly
        await viewModel.save()

        // Verify profile was updated
        let savedProfile = mockRepo.mockProfile
        XCTAssertNotNil(savedProfile?.notificationPreferences)
        XCTAssertTrue(savedProfile?.notificationPreferences?.checkInsEnabled ?? false)
        XCTAssertEqual(savedProfile?.notificationPreferences?.frequency, .weekly)
    }

    func testSaveShowsErrorOnFailure() async {
        var profile = ContextProfile.empty(userId: testUserId)
        mockRepo.mockProfile = profile

        await viewModel.load(userId: testUserId)

        mockRepo.shouldFailOnSave = true
        viewModel.checkInsEnabled = true
        await viewModel.save()

        XCTAssertTrue(viewModel.showError)
    }

    func testDismissError() {
        viewModel.error = .saveFailed("test")
        viewModel.showError = true

        viewModel.dismissError()

        XCTAssertFalse(viewModel.showError)
        XCTAssertNil(viewModel.error)
    }
}

// MARK: - Mock Repository

@MainActor
private final class MockNotificationContextRepository: ContextRepositoryProtocol {
    var mockProfile: ContextProfile?
    var shouldFailOnFetch = false
    var shouldFailOnSave = false

    func createProfile(for userId: UUID) async throws -> ContextProfile {
        return mockProfile ?? ContextProfile.empty(userId: userId)
    }

    func fetchProfile(userId: UUID) async throws -> ContextProfile {
        if shouldFailOnFetch { throw ContextError.fetchFailed("Mock fetch failure") }
        if let profile = mockProfile { return profile }
        throw ContextError.notFound
    }

    func updateProfile(_ profile: ContextProfile) async throws {
        if shouldFailOnSave { throw ContextError.saveFailed("Mock save failure") }
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
