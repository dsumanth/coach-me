//
//  OnboardingCoordinatorTests.swift
//  CoachMeTests
//
//  Story 11.3 — Task 7.1, 7.4, 7.5: OnboardingCoordinator state machine tests
//

import Testing
import Foundation
@testable import CoachMe

@MainActor
struct OnboardingCoordinatorTests {

    // MARK: - Setup

    /// Creates a fresh coordinator with cleared persisted state
    private func makeCoordinator() -> OnboardingCoordinator {
        OnboardingCoordinator.clearPersistedState()
        return OnboardingCoordinator()
    }

    // MARK: - State Transition Tests (Task 7.1)

    @Test("Initial state is welcome")
    func testInitialState() {
        let coordinator = makeCoordinator()
        #expect(coordinator.flowState == .welcome)
        #expect(coordinator.discoveryConversationId == nil)
    }

    @Test("beginDiscovery transitions from welcome to discoveryChat")
    func testBeginDiscovery() {
        let coordinator = makeCoordinator()

        coordinator.beginDiscovery()

        #expect(coordinator.flowState == .discoveryChat)
        #expect(coordinator.discoveryConversationId != nil)
    }

    @Test("beginDiscovery creates a unique conversation ID")
    func testBeginDiscoveryCreatesConversationId() {
        let coordinator = makeCoordinator()

        coordinator.beginDiscovery()
        let firstId = coordinator.discoveryConversationId

        coordinator.reset()
        coordinator.beginDiscovery()
        let secondId = coordinator.discoveryConversationId

        #expect(firstId != secondId)
    }

    @Test("onDiscoveryComplete transitions to paywall and sets discoveryCompleted")
    func testDiscoveryComplete() {
        let coordinator = makeCoordinator()
        coordinator.beginDiscovery()

        coordinator.onDiscoveryComplete()

        #expect(coordinator.flowState == .paywall)
        #expect(coordinator.discoveryCompleted == true)
    }

    @Test("onSubscriptionConfirmed transitions to paidChat and marks onboarding complete")
    func testSubscriptionConfirmed() {
        let coordinator = makeCoordinator()
        coordinator.beginDiscovery()
        coordinator.onDiscoveryComplete()

        coordinator.onSubscriptionConfirmed()

        #expect(coordinator.flowState == .paidChat)
        #expect(coordinator.hasCompletedOnboarding == true)
    }

    @Test("Full flow: welcome → discoveryChat → paywall → paidChat")
    func testFullFlow() {
        let coordinator = makeCoordinator()

        #expect(coordinator.flowState == .welcome)
        coordinator.beginDiscovery()
        #expect(coordinator.flowState == .discoveryChat)
        coordinator.onDiscoveryComplete()
        #expect(coordinator.flowState == .paywall)
        coordinator.onSubscriptionConfirmed()
        #expect(coordinator.flowState == .paidChat)
    }

    @Test("onPaywallDismissed keeps flowState at paywall")
    func testPaywallDismissedStaysAtPaywall() {
        let coordinator = makeCoordinator()
        coordinator.beginDiscovery()
        coordinator.onDiscoveryComplete()

        coordinator.onPaywallDismissed()

        #expect(coordinator.flowState == .paywall)
    }

    // MARK: - Persistence Tests (Task 7.4)

    @Test("hasCompletedOnboarding persists across instances")
    func testHasCompletedOnboardingPersistence() {
        let coordinator1 = makeCoordinator()
        #expect(coordinator1.hasCompletedOnboarding == false)

        coordinator1.hasCompletedOnboarding = true

        // New instance should read persisted value
        let coordinator2 = OnboardingCoordinator()
        #expect(coordinator2.hasCompletedOnboarding == true)

        // Clean up
        OnboardingCoordinator.clearPersistedState()
    }

    @Test("discoveryCompleted persists across instances")
    func testDiscoveryCompletedPersistence() {
        let coordinator1 = makeCoordinator()
        #expect(coordinator1.discoveryCompleted == false)

        coordinator1.discoveryCompleted = true

        // New instance should read persisted value
        let coordinator2 = OnboardingCoordinator()
        #expect(coordinator2.discoveryCompleted == true)

        // Clean up
        OnboardingCoordinator.clearPersistedState()
    }

    // MARK: - Returning User Tests (Task 7.5)

    @Test("Returning user with discoveryCompleted does not reset to welcome")
    func testReturningUserWithDiscoveryCompleted() {
        let coordinator = makeCoordinator()
        coordinator.discoveryCompleted = true

        // discoveryCompleted persists — a new coordinator can check this
        let newCoordinator = OnboardingCoordinator()
        #expect(newCoordinator.discoveryCompleted == true)

        // Clean up
        OnboardingCoordinator.clearPersistedState()
    }

    @Test("clearPersistedState resets all flags")
    func testClearPersistedState() {
        let coordinator = makeCoordinator()
        coordinator.hasCompletedOnboarding = true
        coordinator.discoveryCompleted = true

        OnboardingCoordinator.clearPersistedState()

        let newCoordinator = OnboardingCoordinator()
        #expect(newCoordinator.hasCompletedOnboarding == false)
        #expect(newCoordinator.discoveryCompleted == false)
    }

    @Test("reset clears flow state but not persisted state")
    func testResetClearsFlowStateOnly() {
        let coordinator = makeCoordinator()
        coordinator.beginDiscovery()
        coordinator.hasCompletedOnboarding = true

        coordinator.reset()

        #expect(coordinator.flowState == .welcome)
        #expect(coordinator.discoveryConversationId == nil)
        #expect(coordinator.hasCompletedOnboarding == true)  // Persisted state survives reset

        // Clean up
        OnboardingCoordinator.clearPersistedState()
    }

    // MARK: - Swipe-Back Bypass Prevention Tests (Hardening)

    @Test("Leaving discovery without completing does NOT mark discoveryCompleted")
    func testLeavingDiscoveryWithoutCompleting() {
        let coordinator = makeCoordinator()
        coordinator.beginDiscovery()
        #expect(coordinator.flowState == .discoveryChat)

        // Simulate swipe-back: reset to welcome without calling onDiscoveryComplete
        coordinator.flowState = .welcome

        #expect(coordinator.discoveryCompleted == false)
        #expect(coordinator.hasCompletedOnboarding == false)
        #expect(coordinator.flowState == .welcome)
    }

    @Test("Only onDiscoveryComplete sets discoveryCompleted flag")
    func testOnlyDiscoveryCompleteSetsFlagTrue() {
        let coordinator = makeCoordinator()
        coordinator.beginDiscovery()

        // Flow through without discovery — manually set states
        coordinator.flowState = .paywall
        #expect(coordinator.discoveryCompleted == false)

        coordinator.flowState = .paidChat
        #expect(coordinator.discoveryCompleted == false)

        // Only the explicit call sets the flag
        coordinator.onDiscoveryComplete()
        #expect(coordinator.discoveryCompleted == true)

        // Clean up
        OnboardingCoordinator.clearPersistedState()
    }

    // MARK: - Init Restoration Tests (Return-to-App)

    @Test("Init restores paywall state when discovery done but onboarding not complete")
    func testInitRestoresPaywallForReturningUser() {
        // Simulate: user completed discovery, dismissed paywall, force-quit app
        let setup = makeCoordinator()
        setup.discoveryCompleted = true
        // hasCompletedOnboarding is still false

        // New coordinator should auto-restore to .paywall
        let restored = OnboardingCoordinator()
        #expect(restored.flowState == .paywall)

        // Clean up
        OnboardingCoordinator.clearPersistedState()
    }

    @Test("Init starts at welcome when neither discovery nor onboarding is complete")
    func testInitStartsAtWelcomeForFreshUser() {
        let coordinator = makeCoordinator()
        #expect(coordinator.flowState == .welcome)
    }

    @Test("shouldShowReturnPaywall is true when discovery done but not subscribed")
    func testShouldShowReturnPaywall() {
        let coordinator = makeCoordinator()
        #expect(coordinator.shouldShowReturnPaywall == false)

        coordinator.discoveryCompleted = true
        #expect(coordinator.shouldShowReturnPaywall == true)

        coordinator.hasCompletedOnboarding = true
        #expect(coordinator.shouldShowReturnPaywall == false)

        // Clean up
        OnboardingCoordinator.clearPersistedState()
    }

    @Test("onDiscoveryComplete with context stores paywall context")
    func testDiscoveryCompleteWithContext() {
        let coordinator = makeCoordinator()
        coordinator.beginDiscovery()

        let context = DiscoveryPaywallContext(
            coachingDomain: "career",
            ahaInsight: "You thrive under autonomy",
            keyTheme: "leadership",
            userName: nil
        )
        coordinator.onDiscoveryComplete(with: context)

        #expect(coordinator.flowState == .paywall)
        #expect(coordinator.discoveryCompleted == true)
        #expect(coordinator.discoveryPaywallContext?.coachingDomain == "career")
        #expect(coordinator.discoveryPaywallContext?.ahaInsight == "You thrive under autonomy")

        // Clean up
        OnboardingCoordinator.clearPersistedState()
    }
}
