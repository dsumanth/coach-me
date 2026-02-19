//
//  UsageViewModelTests.swift
//  CoachMeTests
//
//  Story 10.5: Usage Transparency UI
//  Tests for MessageUsage model, UsageViewModel state, and tier calculation
//

import XCTest
@testable import CoachMe

// MARK: - MessageUsage Model Tests

final class MessageUsageModelTests: XCTestCase {

    // MARK: - messagesRemaining

    func testMessagesRemaining_paidUser_belowLimit() {
        let usage = makeUsage(messageCount: 500, limit: 800)
        XCTAssertEqual(usage.messagesRemaining, 300)
    }

    func testMessagesRemaining_atLimit() {
        let usage = makeUsage(messageCount: 800, limit: 800)
        XCTAssertEqual(usage.messagesRemaining, 0)
    }

    func testMessagesRemaining_overLimit_clampsToZero() {
        // Edge case: count exceeds limit (shouldn't happen, but defensive)
        let usage = makeUsage(messageCount: 850, limit: 800)
        XCTAssertEqual(usage.messagesRemaining, 0)
    }

    func testMessagesRemaining_zeroUsage() {
        let usage = makeUsage(messageCount: 0, limit: 800)
        XCTAssertEqual(usage.messagesRemaining, 800)
    }

    func testMessagesRemaining_trialUser() {
        let usage = makeUsage(messageCount: 42, limit: 100, billingPeriod: "trial")
        XCTAssertEqual(usage.messagesRemaining, 58)
    }

    // MARK: - usagePercentage

    func testUsagePercentage_zero() {
        let usage = makeUsage(messageCount: 0, limit: 800)
        XCTAssertEqual(usage.usagePercentage, 0.0, accuracy: 0.001)
    }

    func testUsagePercentage_midway() {
        let usage = makeUsage(messageCount: 400, limit: 800)
        XCTAssertEqual(usage.usagePercentage, 0.5, accuracy: 0.001)
    }

    func testUsagePercentage_at80Percent() {
        let usage = makeUsage(messageCount: 640, limit: 800)
        XCTAssertEqual(usage.usagePercentage, 0.8, accuracy: 0.001)
    }

    func testUsagePercentage_at95Percent() {
        let usage = makeUsage(messageCount: 760, limit: 800)
        XCTAssertEqual(usage.usagePercentage, 0.95, accuracy: 0.001)
    }

    func testUsagePercentage_at100Percent() {
        let usage = makeUsage(messageCount: 800, limit: 800)
        XCTAssertEqual(usage.usagePercentage, 1.0, accuracy: 0.001)
    }

    func testUsagePercentage_overLimit_clampsToOne() {
        let usage = makeUsage(messageCount: 900, limit: 800)
        XCTAssertEqual(usage.usagePercentage, 1.0, accuracy: 0.001)
    }

    func testUsagePercentage_zeroLimit_returnsZero() {
        // Edge case: limit of 0 should not divide by zero
        let usage = makeUsage(messageCount: 0, limit: 0)
        XCTAssertEqual(usage.usagePercentage, 0.0, accuracy: 0.001)
    }

    // MARK: - isAtLimit

    func testIsAtLimit_belowLimit() {
        let usage = makeUsage(messageCount: 500, limit: 800)
        XCTAssertFalse(usage.isAtLimit)
    }

    func testIsAtLimit_exactlyAtLimit() {
        let usage = makeUsage(messageCount: 800, limit: 800)
        XCTAssertTrue(usage.isAtLimit)
    }

    func testIsAtLimit_overLimit() {
        let usage = makeUsage(messageCount: 900, limit: 800)
        XCTAssertTrue(usage.isAtLimit)
    }

    func testIsAtLimit_trialAtLimit() {
        let usage = makeUsage(messageCount: 100, limit: 100, billingPeriod: "trial")
        XCTAssertTrue(usage.isAtLimit)
    }

    // MARK: - Threshold Boundary Tests (paid user, 800 limit)

    func testPaidUser_at0Percent_silent() {
        let usage = makeUsage(messageCount: 0, limit: 800)
        XCTAssertEqual(usage.usagePercentage, 0.0, accuracy: 0.001)
        XCTAssertFalse(usage.isAtLimit)
    }

    func testPaidUser_at79Percent_silent() {
        // 632/800 = 0.79
        let usage = makeUsage(messageCount: 632, limit: 800)
        XCTAssertLessThan(usage.usagePercentage, 0.80)
        XCTAssertFalse(usage.isAtLimit)
    }

    func testPaidUser_at80Percent_gentleBoundary() {
        // 640/800 = 0.80
        let usage = makeUsage(messageCount: 640, limit: 800)
        XCTAssertEqual(usage.usagePercentage, 0.80, accuracy: 0.001)
        XCTAssertFalse(usage.isAtLimit)
    }

    func testPaidUser_at94Percent() {
        // 752/800 = 0.94
        let usage = makeUsage(messageCount: 752, limit: 800)
        XCTAssertGreaterThanOrEqual(usage.usagePercentage, 0.80)
        XCTAssertLessThan(usage.usagePercentage, 0.95)
        XCTAssertFalse(usage.isAtLimit)
    }

    func testPaidUser_at95Percent_prominentBoundary() {
        // 760/800 = 0.95
        let usage = makeUsage(messageCount: 760, limit: 800)
        XCTAssertEqual(usage.usagePercentage, 0.95, accuracy: 0.001)
        XCTAssertFalse(usage.isAtLimit)
    }

    func testPaidUser_at99Percent() {
        // 792/800 = 0.99
        let usage = makeUsage(messageCount: 792, limit: 800)
        XCTAssertGreaterThanOrEqual(usage.usagePercentage, 0.95)
        XCTAssertLessThan(usage.usagePercentage, 1.0)
        XCTAssertFalse(usage.isAtLimit)
    }

    func testPaidUser_at100Percent_blocked() {
        let usage = makeUsage(messageCount: 800, limit: 800)
        XCTAssertEqual(usage.usagePercentage, 1.0, accuracy: 0.001)
        XCTAssertTrue(usage.isAtLimit)
    }

    // MARK: - Trial user boundary tests (100 limit)

    func testTrialUser_fresh() {
        let usage = makeUsage(messageCount: 0, limit: 100, billingPeriod: "trial")
        XCTAssertEqual(usage.messagesRemaining, 100)
        XCTAssertFalse(usage.isAtLimit)
    }

    func testTrialUser_midway() {
        let usage = makeUsage(messageCount: 50, limit: 100, billingPeriod: "trial")
        XCTAssertEqual(usage.messagesRemaining, 50)
        XCTAssertEqual(usage.usagePercentage, 0.5, accuracy: 0.001)
    }

    func testTrialUser_atLimit() {
        let usage = makeUsage(messageCount: 100, limit: 100, billingPeriod: "trial")
        XCTAssertEqual(usage.messagesRemaining, 0)
        XCTAssertTrue(usage.isAtLimit)
    }

    // MARK: - Helpers

    private func makeUsage(
        messageCount: Int,
        limit: Int,
        billingPeriod: String = "2026-02"
    ) -> MessageUsage {
        MessageUsage(
            id: UUID(),
            userId: UUID(),
            billingPeriod: billingPeriod,
            messageCount: messageCount,
            limit: limit,
            updatedAt: Date()
        )
    }
}

// MARK: - UsageDisplayState Tests

@MainActor
final class UsageDisplayStateTests: XCTestCase {

    func testHiddenState_equatable() {
        XCTAssertEqual(UsageDisplayState.hidden, UsageDisplayState.hidden)
    }

    func testCompactState_equatable() {
        let state1 = UsageDisplayState.compact(messagesRemaining: 160, tier: .gentle)
        let state2 = UsageDisplayState.compact(messagesRemaining: 160, tier: .gentle)
        XCTAssertEqual(state1, state2)
    }

    func testTrialState_equatable() {
        let state1 = UsageDisplayState.trial(messagesRemaining: 50, totalLimit: 100)
        let state2 = UsageDisplayState.trial(messagesRemaining: 50, totalLimit: 100)
        XCTAssertEqual(state1, state2)
    }

    func testBlockedState_equatable() {
        let date = Date()
        let state1 = UsageDisplayState.blocked(resetDate: date)
        let state2 = UsageDisplayState.blocked(resetDate: date)
        XCTAssertEqual(state1, state2)
    }

    func testDifferentStates_notEqual() {
        XCTAssertNotEqual(UsageDisplayState.hidden, UsageDisplayState.blocked(resetDate: nil))
    }
}

// MARK: - UsageViewModel Tests

@MainActor
final class UsageViewModelTests: XCTestCase {

    // MARK: - Initial State

    func testInitialState_isHidden() {
        let vm = UsageViewModel()
        XCTAssertEqual(vm.displayState, .hidden)
        XCTAssertNil(vm.currentUsage)
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.error)
    }

    // MARK: - Optimistic Increment

    func testOnMessageSent_withNilUsage_doesNothing() {
        let vm = UsageViewModel()
        // Should not crash when currentUsage is nil
        vm.onMessageSent()
        XCTAssertNil(vm.currentUsage)
    }

    // MARK: - Accessible Usage Description

    func testAccessibleDescription_noUsageData() {
        let vm = UsageViewModel()
        XCTAssertEqual(vm.accessibleUsageDescription, "Usage information unavailable")
    }

    func testAccessibleDescription_hiddenState() {
        let vm = UsageViewModel()
        // displayState defaults to .hidden, accessibleDescription with no currentUsage
        XCTAssertEqual(vm.accessibleUsageDescription, "Usage information unavailable")
    }

    // MARK: - UsageDisplayTier Tests

    func testDisplayTier_silent() {
        XCTAssertEqual(UsageDisplayTier.silent, UsageDisplayTier.silent)
    }

    func testDisplayTier_gentle() {
        XCTAssertEqual(UsageDisplayTier.gentle, UsageDisplayTier.gentle)
    }

    func testDisplayTier_prominent() {
        XCTAssertEqual(UsageDisplayTier.prominent, UsageDisplayTier.prominent)
    }

    func testDisplayTier_blocked() {
        XCTAssertEqual(UsageDisplayTier.blocked, UsageDisplayTier.blocked)
    }

    func testDisplayTier_differentValues_notEqual() {
        XCTAssertNotEqual(UsageDisplayTier.silent, UsageDisplayTier.gentle)
        XCTAssertNotEqual(UsageDisplayTier.gentle, UsageDisplayTier.prominent)
        XCTAssertNotEqual(UsageDisplayTier.prominent, UsageDisplayTier.blocked)
    }
}

// MARK: - UsageTrackingService Error Tests

final class UsageTrackingErrorTests: XCTestCase {

    func testFetchFailed_warmFirstPersonMessage() {
        let error = UsageTrackingError.fetchFailed("connection timeout")
        XCTAssertTrue(error.errorDescription?.starts(with: "I couldn't") ?? false,
                      "Error should use warm, first-person language per UX-11")
    }

    func testNotAuthenticated_warmFirstPersonMessage() {
        let error = UsageTrackingError.notAuthenticated
        XCTAssertTrue(error.errorDescription?.starts(with: "I need") ?? false,
                      "Error should use warm, first-person language per UX-11")
    }

    func testEquatable_sameCases() {
        XCTAssertEqual(
            UsageTrackingError.notAuthenticated,
            UsageTrackingError.notAuthenticated
        )
        XCTAssertEqual(
            UsageTrackingError.fetchFailed("reason"),
            UsageTrackingError.fetchFailed("reason")
        )
    }

    func testEquatable_differentCases() {
        XCTAssertNotEqual(
            UsageTrackingError.notAuthenticated,
            UsageTrackingError.fetchFailed("reason")
        )
        XCTAssertNotEqual(
            UsageTrackingError.fetchFailed("a"),
            UsageTrackingError.fetchFailed("b")
        )
    }
}
