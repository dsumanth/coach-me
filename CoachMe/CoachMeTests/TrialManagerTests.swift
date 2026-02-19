//
//  TrialManagerTests.swift
//  CoachMeTests
//
//  Story 10.3: Unit tests for TrialManager paid-trial-after-discovery state machine
//

import XCTest
@testable import CoachMe

@MainActor
final class TrialManagerTests: XCTestCase {

    private var sut: TrialManager!

    override func setUp() {
        super.setUp()
        sut = TrialManager(subscriptionService: .shared, testInit: true)
        sut.resetForTesting()
    }

    override func tearDown() {
        sut.resetForTesting()
        sut = nil
        super.tearDown()
    }

    // MARK: - Task 7.1: State Transitions

    func testInitialStateIsDiscovery() {
        XCTAssertEqual(sut.currentState, .discovery)
    }

    func testDiscoveryToBlockedAfterDiscoveryCompletion() {
        // When discovery completes but no trial activated
        var profile = ContextProfile.empty(userId: UUID())
        profile.discoveryCompletedAt = Date()
        sut.updateCachedProfile(profile)

        XCTAssertEqual(sut.currentState, .blocked)
    }

    func testBlockedToTrialActiveAfterActivation() {
        // Setup: discovery completed
        var profile = ContextProfile.empty(userId: UUID())
        profile.discoveryCompletedAt = Date()
        sut.updateCachedProfile(profile)
        XCTAssertEqual(sut.currentState, .blocked)

        // When trial is activated
        sut.setTrialActivatedAt(Date())
        sut.evaluateState()

        if case .trialActive = sut.currentState {
            // Expected
        } else {
            XCTFail("Expected .trialActive, got \(sut.currentState)")
        }
    }

    func testTrialActiveToTrialExpiredAfter3Days() {
        var profile = ContextProfile.empty(userId: UUID())
        profile.discoveryCompletedAt = Date()
        sut.updateCachedProfile(profile)

        // Activate trial 4 days ago (expired)
        let fourDaysAgo = Calendar.current.date(byAdding: .day, value: -4, to: Date())!
        sut.setTrialActivatedAt(fourDaysAgo)
        sut.evaluateState()

        XCTAssertEqual(sut.currentState, .trialExpired)
    }

    // MARK: - Task 7.2: isDiscoveryMode

    func testIsDiscoveryModeBeforeDiscoveryCompletion() {
        // No profile set = no discovery_completed_at = discovery mode
        XCTAssertTrue(sut.isDiscoveryMode)
    }

    func testIsDiscoveryModeFalseAfterCompletion() {
        var profile = ContextProfile.empty(userId: UUID())
        profile.discoveryCompletedAt = Date()
        sut.updateCachedProfile(profile)

        XCTAssertFalse(sut.isDiscoveryMode)
    }

    // MARK: - Task 7.3: isBlocked

    func testIsBlockedWhenDiscoveryCompleteNoSubscriptionNoTrial() {
        var profile = ContextProfile.empty(userId: UUID())
        profile.discoveryCompletedAt = Date()
        sut.updateCachedProfile(profile)

        XCTAssertTrue(sut.isBlocked)
    }

    func testIsBlockedFalseBeforeDiscovery() {
        XCTAssertFalse(sut.isBlocked)
    }

    func testIsBlockedFalseWhenTrialActive() {
        var profile = ContextProfile.empty(userId: UUID())
        profile.discoveryCompletedAt = Date()
        sut.updateCachedProfile(profile)

        sut.setTrialActivatedAt(Date())
        sut.evaluateState()

        XCTAssertFalse(sut.isBlocked)
    }

    // MARK: - Task 7.4: trialDayNumber

    func testTrialDayNumberDay1() {
        sut.setTrialActivatedAt(Date())

        XCTAssertEqual(sut.trialDayNumber, 1)
    }

    func testTrialDayNumberDay2() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        sut.setTrialActivatedAt(yesterday)

        XCTAssertEqual(sut.trialDayNumber, 2)
    }

    func testTrialDayNumberDay3() {
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        sut.setTrialActivatedAt(twoDaysAgo)

        XCTAssertEqual(sut.trialDayNumber, 3)
    }

    func testTrialDayNumberCapsAt3() {
        let fiveDaysAgo = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        sut.setTrialActivatedAt(fiveDaysAgo)

        XCTAssertEqual(sut.trialDayNumber, 3)
    }

    func testTrialDayNumberZeroWhenNoTrial() {
        XCTAssertEqual(sut.trialDayNumber, 0)
    }

    // MARK: - Task 7.5: checkTrialExpiry

    func testCheckTrialExpiryFalseWithinThreeDays() {
        sut.setTrialActivatedAt(Date())

        XCTAssertFalse(sut.checkTrialExpiry())
    }

    func testCheckTrialExpiryTrueAfterThreeDays() {
        let fourDaysAgo = Calendar.current.date(byAdding: .day, value: -4, to: Date())!
        sut.setTrialActivatedAt(fourDaysAgo)

        XCTAssertTrue(sut.checkTrialExpiry())
    }

    func testCheckTrialExpiryFalseWhenNoActivation() {
        XCTAssertFalse(sut.checkTrialExpiry())
    }

    // MARK: - Task 7.6: activateTrial state transition

    func testActivateTrialSetsStateToTrialActive() {
        var profile = ContextProfile.empty(userId: UUID())
        profile.discoveryCompletedAt = Date()
        sut.updateCachedProfile(profile)

        // Simulate activation (without actual server call)
        sut.setTrialActivatedAt(Date())
        sut.evaluateState()

        if case .trialActive(let activatedAt, let messagesUsed, let messagesLimit) = sut.currentState {
            XCTAssertNotNil(activatedAt)
            XCTAssertEqual(messagesUsed, 0)
            XCTAssertEqual(messagesLimit, TrialManager.trialMessageLimit)
        } else {
            XCTFail("Expected .trialActive, got \(sut.currentState)")
        }
    }

    // MARK: - Task 7.7: trialStatusText

    func testTrialStatusTextFormatsCorrectly() {
        var profile = ContextProfile.empty(userId: UUID())
        profile.discoveryCompletedAt = Date()
        sut.updateCachedProfile(profile)

        sut.setTrialActivatedAt(Date())
        sut.evaluateState()

        let text = sut.trialStatusText
        XCTAssertTrue(text.contains("Day 1 of 3"), "Expected 'Day 1 of 3' in '\(text)'")
        XCTAssertTrue(text.contains("conversations left"), "Expected 'conversations left' in '\(text)'")
    }

    func testTrialStatusTextEmptyWhenNotInTrial() {
        XCTAssertTrue(sut.trialStatusText.isEmpty)
    }

    // MARK: - Task 7.9: isPremium

    func testIsPremiumFalseInDiscovery() {
        XCTAssertFalse(sut.isPremium)
    }

    func testIsPremiumTrueInTrialActive() {
        var profile = ContextProfile.empty(userId: UUID())
        profile.discoveryCompletedAt = Date()
        sut.updateCachedProfile(profile)

        sut.setTrialActivatedAt(Date())
        sut.evaluateState()

        XCTAssertTrue(sut.isPremium)
    }

    func testIsPremiumFalseWhenBlocked() {
        var profile = ContextProfile.empty(userId: UUID())
        profile.discoveryCompletedAt = Date()
        sut.updateCachedProfile(profile)

        XCTAssertFalse(sut.isPremium)
    }

    // MARK: - Message Usage

    func testTrialExpiresWhenMessagesExhausted() {
        var profile = ContextProfile.empty(userId: UUID())
        profile.discoveryCompletedAt = Date()
        sut.updateCachedProfile(profile)

        sut.setTrialActivatedAt(Date())
        sut.updateMessageUsage(100)

        XCTAssertEqual(sut.currentState, .trialExpired)
    }

    func testMessagesRemainingDuringTrial() {
        var profile = ContextProfile.empty(userId: UUID())
        profile.discoveryCompletedAt = Date()
        sut.updateCachedProfile(profile)

        sut.setTrialActivatedAt(Date())
        sut.updateMessageUsage(30)

        XCTAssertEqual(sut.messagesRemaining, 70)
    }

    func testMessagesRemainingZeroWhenNotInTrial() {
        XCTAssertEqual(sut.messagesRemaining, 0)
    }

    // MARK: - Time Remaining

    func testTrialTimeRemainingPositiveOnDay1() {
        sut.setTrialActivatedAt(Date())

        XCTAssertGreaterThan(sut.trialTimeRemaining, 0)
    }

    func testTrialTimeRemainingZeroAfterExpiry() {
        let fourDaysAgo = Calendar.current.date(byAdding: .day, value: -4, to: Date())!
        sut.setTrialActivatedAt(fourDaysAgo)

        XCTAssertEqual(sut.trialTimeRemaining, 0)
    }

    func testTrialTimeRemainingZeroWhenNoActivation() {
        XCTAssertEqual(sut.trialTimeRemaining, 0)
    }
}
