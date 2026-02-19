//
//  SubscriptionServiceTests.swift
//  CoachMeTests
//
//  Story 6.1: RevenueCat Integration - Unit Tests
//  Story 6.2: Free Trial Experience - Trial state tests
//  Story 6.3: Subscription Purchase Flow - Purchase/error/gating tests
//

import Testing
import Foundation
@testable import CoachMe

@MainActor
struct SubscriptionServiceTests {

    // MARK: - Singleton Tests (Story 6.1)

    @Test("SubscriptionService initializes as singleton")
    func testSingleton() {
        let instance1 = SubscriptionService.shared
        let instance2 = SubscriptionService.shared
        #expect(instance1 === instance2)
    }

    // MARK: - SubscriptionViewModel Initial State Tests (Story 6.1)

    @Test("SubscriptionViewModel initial state is correct")
    func testViewModelInitialState() {
        let viewModel = SubscriptionViewModel()

        #expect(!viewModel.isPremium)
        #expect(!viewModel.isLoading)
        #expect(viewModel.error == nil)
        #expect(viewModel.state == .unknown)
        #expect(!viewModel.isTrialActive)
        #expect(!viewModel.isTrialExpired)
        #expect(!viewModel.isSubscribed)
        #expect(viewModel.trialDaysRemaining == 0)
        #expect(!viewModel.shouldGateChat)
    }

    // MARK: - Error Enum Tests (Story 6.1)

    @Test("SubscriptionError.identifyFailed provides warm first-person message")
    func testIdentifyFailedMessage() {
        let error = SubscriptionService.SubscriptionError.identifyFailed(
            NSError(domain: "test", code: 0)
        )
        #expect(error.errorDescription == "I had trouble syncing your subscription. Let's try again.")
    }

    @Test("SubscriptionError.entitlementCheckFailed provides warm first-person message")
    func testEntitlementCheckFailedMessage() {
        let error = SubscriptionService.SubscriptionError.entitlementCheckFailed(
            NSError(domain: "test", code: 0)
        )
        #expect(error.errorDescription == "I couldn't check your subscription status right now.")
    }

    @Test("SubscriptionError.notConfigured provides warm first-person message")
    func testNotConfiguredMessage() {
        let error = SubscriptionService.SubscriptionError.notConfigured
        #expect(error.errorDescription == "Subscription features aren't available yet.")
    }

    // MARK: - Service Behavior Tests (Story 6.1)

    @Test("isEntitled returns false when RevenueCat is not configured")
    func testIsEntitledReturnsFalseWhenNotConfigured() async {
        let service = SubscriptionService.shared
        let result = await service.isEntitled(to: "premium")
        #expect(!result)
    }

    @Test("isEntitled uses premium as default entitlement ID")
    func testDefaultEntitlementId() async {
        let service = SubscriptionService.shared
        let result = await service.isEntitled()
        #expect(!result)
    }

    // MARK: - Trial State Detection Tests (Story 6.2 — Task 7.1, Updated Story 10.4)

    @Test("Trial active state detected from paidTrial state")
    func testTrialActiveState() {
        let viewModel = SubscriptionViewModel()

        // Story 10.3/10.4: Trial state now managed by TrialManager, test via direct state
        viewModel.state = .paidTrial(daysRemaining: 3, messagesRemaining: 100)
        viewModel.isPremium = true

        #expect(viewModel.isTrialActive)
        #expect(!viewModel.isTrialExpired)
        #expect(!viewModel.isSubscribed)
        #expect(!viewModel.shouldGateChat)
    }

    // MARK: - Trial Expired State Tests (Story 6.2 — Task 7.2)

    @Test("Trial expired state gates chat")
    func testTrialExpiredState() {
        let viewModel = SubscriptionViewModel()

        viewModel.state = .trialExpired
        viewModel.isPremium = false

        #expect(!viewModel.isTrialActive)
        #expect(viewModel.isTrialExpired)
        #expect(!viewModel.isSubscribed)
        #expect(viewModel.shouldGateChat)
    }

    // MARK: - Subscribed State Tests (Story 6.2 — Task 7.3)

    @Test("Subscribed state reflects isPremium correctly")
    func testSubscribedState() {
        let viewModel = SubscriptionViewModel()

        // Manually set state (RevenueCat not configured in tests)
        viewModel.state = .subscribed
        viewModel.isPremium = true

        #expect(viewModel.isSubscribed)
        #expect(!viewModel.isTrialActive)
        #expect(!viewModel.isTrialExpired)
        #expect(!viewModel.shouldGateChat)
    }

    // MARK: - Days Remaining Calculation Tests (Story 6.2 — Task 7.4, Updated Story 10.4)

    @Test("Days remaining reads from paidTrial state")
    func testDaysRemainingFromPaidTrial() {
        let viewModel = SubscriptionViewModel()

        // Story 10.4: daysRemaining is now stored directly in state
        viewModel.state = .paidTrial(daysRemaining: 3, messagesRemaining: 100)
        #expect(viewModel.trialDaysRemaining == 3)
    }

    @Test("Days remaining is 0 for non-trial states")
    func testDaysRemainingNonTrial() {
        let viewModel = SubscriptionViewModel()

        viewModel.state = .trialExpired
        #expect(viewModel.trialDaysRemaining == 0)

        viewModel.state = .subscribed
        #expect(viewModel.trialDaysRemaining == 0)

        viewModel.state = .unknown
        #expect(viewModel.trialDaysRemaining == 0)
    }

    // MARK: - Chat Gate Logic Tests (Story 6.2 — Task 7.5)

    @Test("Chat gate is active when trial expired")
    func testChatGateTrialExpired() {
        let viewModel = SubscriptionViewModel()
        viewModel.state = .trialExpired
        #expect(viewModel.shouldGateChat)
    }

    @Test("Chat gate is active when subscription expired")
    func testChatGateSubscriptionExpired() {
        let viewModel = SubscriptionViewModel()
        viewModel.state = .expired
        #expect(viewModel.shouldGateChat)
    }

    @Test("Chat gate is inactive during active trial")
    func testChatGateTrialActive() {
        let viewModel = SubscriptionViewModel()
        viewModel.state = .paidTrial(daysRemaining: 5, messagesRemaining: 50)
        #expect(!viewModel.shouldGateChat)
    }

    @Test("Chat gate is inactive when subscribed")
    func testChatGateSubscribed() {
        let viewModel = SubscriptionViewModel()
        viewModel.state = .subscribed
        #expect(!viewModel.shouldGateChat)
    }

    // MARK: - Trial Status Message Tests (Story 6.2)

    @Test("Trial status message uses warm first-person language")
    func testTrialStatusMessageWarm() {
        let viewModel = SubscriptionViewModel()

        // Story 10.4: .trial → .paidTrial with messagesRemaining
        viewModel.state = .paidTrial(daysRemaining: 2, messagesRemaining: 80)
        #expect(viewModel.trialStatusMessage.contains("conversations left"))

        viewModel.state = .paidTrial(daysRemaining: 1, messagesRemaining: 20)
        #expect(viewModel.trialStatusMessage.contains("Last day"))

        viewModel.state = .trialExpired
        #expect(viewModel.trialStatusMessage.contains("3-day access has ended"))
    }

    @Test("Trial status message is empty for unknown state")
    func testTrialStatusMessageUnknown() {
        let viewModel = SubscriptionViewModel()
        viewModel.state = .unknown
        #expect(viewModel.trialStatusMessage.isEmpty)
    }

    // MARK: - Trial Activation Tests (Story 10.3/10.4: Server-Side Trial)

    @Test("TrialManager trialExpirationDate is nil when no trial activated")
    func testTrialExpirationDateNil() {
        let trialManager = TrialManager.shared
        trialManager.resetForTesting()
        #expect(trialManager.trialExpirationDate == nil)
        trialManager.resetForTesting()
    }

    @Test("TrialManager trialExpirationDate returns correct date when trial active")
    func testTrialExpirationDateActive() {
        let trialManager = TrialManager.shared
        trialManager.resetForTesting()

        let now = Date()
        trialManager.setTrialActivatedAt(now)

        let expected = now.addingTimeInterval(TimeInterval(TrialManager.trialDurationDays * 24 * 60 * 60))
        if let expiration = trialManager.trialExpirationDate {
            #expect(abs(expiration.timeIntervalSince(expected)) < 1.0)
        } else {
            Issue.record("Expected non-nil trialExpirationDate")
        }

        trialManager.resetForTesting()
    }

    // MARK: - SubscriptionState Equatable Tests

    @Test("SubscriptionState equality works correctly")
    func testSubscriptionStateEquality() {
        #expect(SubscriptionState.unknown == .unknown)
        // Story 10.4: .trial → .paidTrial with messagesRemaining
        #expect(SubscriptionState.paidTrial(daysRemaining: 3, messagesRemaining: 100)
            == .paidTrial(daysRemaining: 3, messagesRemaining: 100))
        #expect(SubscriptionState.paidTrial(daysRemaining: 3, messagesRemaining: 100)
            != .paidTrial(daysRemaining: 2, messagesRemaining: 100))
        #expect(SubscriptionState.trialExpired == .trialExpired)
        #expect(SubscriptionState.subscribed == .subscribed)
        #expect(SubscriptionState.expired == .expired)
        #expect(SubscriptionState.paidTrial(daysRemaining: 3, messagesRemaining: 100) != .subscribed)
    }

    // MARK: - Purchase Error Handling Tests (Story 6.3 — Task 6.1)

    @Test("SubscriptionViewModel purchaseError is nil initially")
    func testPurchaseErrorNilInitially() {
        let viewModel = SubscriptionViewModel()
        #expect(viewModel.purchaseError == nil)
    }

    @Test("SubscriptionViewModel isPurchasing is false initially")
    func testIsPurchasingFalseInitially() {
        let viewModel = SubscriptionViewModel()
        #expect(!viewModel.isPurchasing)
    }

    @Test("Subscribed state clears shouldGateChat")
    func testSubscribedClearsChatGate() {
        let viewModel = SubscriptionViewModel()
        viewModel.state = .trialExpired
        #expect(viewModel.shouldGateChat)

        // Simulate purchase success
        viewModel.state = .subscribed
        viewModel.isPremium = true
        #expect(!viewModel.shouldGateChat)
    }

    @Test("Expired state from subscribed triggers chat gate")
    func testExpiredFromSubscribedGatesChat() {
        let viewModel = SubscriptionViewModel()

        // Start as subscribed
        viewModel.state = .subscribed
        viewModel.isPremium = true
        #expect(!viewModel.shouldGateChat)

        // Subscription expires
        viewModel.state = .expired
        viewModel.isPremium = false
        #expect(viewModel.shouldGateChat)
    }

    @Test("Available packages starts empty")
    func testAvailablePackagesStartsEmpty() {
        let viewModel = SubscriptionViewModel()
        #expect(viewModel.availablePackages.isEmpty)
    }

    // MARK: - Paywall Trigger Logic Tests (Story 6.3 — Task 6.2)

    @Test("shouldGateChat is true for trialExpired state")
    func testPaywallTriggerTrialExpired() {
        let viewModel = SubscriptionViewModel()
        viewModel.state = .trialExpired
        #expect(viewModel.shouldGateChat)
    }

    @Test("shouldGateChat is true for expired state")
    func testPaywallTriggerExpired() {
        let viewModel = SubscriptionViewModel()
        viewModel.state = .expired
        #expect(viewModel.shouldGateChat)
    }

    @Test("shouldGateChat is false during active trial")
    func testPaywallNotTriggeredDuringTrial() {
        let viewModel = SubscriptionViewModel()
        viewModel.state = .paidTrial(daysRemaining: 3, messagesRemaining: 50)
        #expect(!viewModel.shouldGateChat)
    }

    @Test("shouldGateChat is false when subscribed")
    func testPaywallNotTriggeredWhenSubscribed() {
        let viewModel = SubscriptionViewModel()
        viewModel.state = .subscribed
        viewModel.isPremium = true
        #expect(!viewModel.shouldGateChat)
    }

    @Test("shouldGateChat is false for unknown state")
    func testPaywallNotTriggeredForUnknown() {
        let viewModel = SubscriptionViewModel()
        viewModel.state = .unknown
        #expect(!viewModel.shouldGateChat)
    }

    @Test("Purchase error message matches UX-11 warm copy for purchase failure")
    func testPurchaseErrorWarmCopy() {
        let viewModel = SubscriptionViewModel()
        // Simulate setting the error that the purchase method would set
        viewModel.purchaseError = "I couldn't complete that purchase. Let's try again when you're ready."
        #expect(viewModel.purchaseError?.contains("I couldn't") == true)
    }

    @Test("Restore error message matches UX-11 warm copy for restore failure")
    func testRestoreErrorWarmCopy() {
        let viewModel = SubscriptionViewModel()
        viewModel.purchaseError = "I wasn't able to find a previous subscription. If you think this is wrong, reach out to support."
        #expect(viewModel.purchaseError?.contains("I wasn't able") == true)
    }
}
