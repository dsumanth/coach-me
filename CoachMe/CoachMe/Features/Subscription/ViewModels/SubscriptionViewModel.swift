//
//  SubscriptionViewModel.swift
//  CoachMe
//
//  Story 6.1: RevenueCat Integration (base)
//  Story 6.2: Free Trial Experience (trial state management)
//  Story 10.3: Updated to delegate trial state to TrialManager
//  Story 10.4: Paid trial with $3 IAP, message counting, and PaywallContext
//

import Foundation
import RevenueCat
@preconcurrency import UserNotifications

/// Subscription states for the app's trial and subscription lifecycle
/// Story 10.4: Updated .trial → .paidTrial with messagesRemaining for paid trial model
enum SubscriptionState: Equatable {
    case unknown
    case paidTrial(daysRemaining: Int, messagesRemaining: Int)
    case trialExpired
    case subscribed
    case expired
}

/// Manages trial and subscription state by combining TrialManager
/// with RevenueCat entitlement checks.
///
/// Story 10.3: Trial state now delegates to TrialManager (server-side paid trial).
/// Story 10.4: Paid trial with message counting and context-aware paywall.
@MainActor
@Observable
final class SubscriptionViewModel {
    // MARK: - Published State

    var state: SubscriptionState = .unknown
    var isPremium = false
    var isLoading = false
    var error: SubscriptionService.SubscriptionError?

    /// Available packages from RevenueCat for the paywall
    var availablePackages: [Package] = []

    /// Whether a purchase is currently in progress
    var isPurchasing = false

    /// User-facing error message from purchase or restore attempt (warm, first-person)
    var purchaseError: String?

    // MARK: - Computed Properties

    /// Whether the user is currently in an active trial
    var isTrialActive: Bool {
        if case .paidTrial = state { return true }
        return false
    }

    /// Whether the user's trial has expired
    var isTrialExpired: Bool {
        state == .trialExpired
    }

    /// Whether the user has an active subscription
    var isSubscribed: Bool {
        state == .subscribed
    }

    /// Number of trial days remaining (0 if not in trial)
    var trialDaysRemaining: Int {
        if case .paidTrial(let days, _) = state { return days }
        return 0
    }

    /// Story 10.4: Messages remaining in paid trial
    var messagesRemaining: Int {
        if case .paidTrial(_, let msgs) = state { return msgs }
        return TrialManager.shared.messagesRemaining
    }

    /// Story 10.4: Whether the paid trial's messages have been exhausted
    var isTrialMessagesExhausted: Bool {
        if case .paidTrial(_, let msgs) = state { return msgs <= 0 }
        return false
    }

    /// Warm, first-person trial status message for the banner
    var trialStatusMessage: String {
        switch state {
        case .paidTrial(let daysRemaining, let messagesRemaining):
            if daysRemaining <= 1 {
                return "Last day of your 3-day access — subscribe to keep the conversation going."
            }
            return "Day \(TrialManager.shared.trialDayNumber) of \(TrialManager.trialDurationDays) — \(messagesRemaining) conversations left"
        case .trialExpired:
            return "Your 3-day access has ended — subscribe to keep the conversation going"
        case .subscribed:
            return "You're all set with CoachMe Premium"
        default:
            return ""
        }
    }

    /// Whether chatting should be gated (trial expired, messages exhausted, blocked, or expired subscription)
    /// Story 10.4: Also gates when paid trial messages are exhausted
    var shouldGateChat: Bool {
        if state == .trialExpired || state == .expired || TrialManager.shared.isBlocked {
            return true
        }
        // Story 10.4: Gate when paid trial messages are exhausted
        if case .paidTrial(_, let msgs) = state, msgs <= 0 {
            return true
        }
        return false
    }

    /// Determines the appropriate PaywallContext for the current state
    var currentPaywallContext: PaywallContext {
        if case .paidTrial(_, let msgs) = state, msgs <= 0 {
            return .messagesExhausted
        }
        if state == .trialExpired {
            return .trialExpired
        }
        if state == .expired {
            return .cancelled
        }
        return .generic
    }

    /// Packages filtered to auto-renewing subscriptions only.
    /// Used for post-trial paywalls so the IAP doesn't appear again.
    var subscriptionOnlyPackages: [Package] {
        availablePackages.filter { $0.storeProduct.productType == .autoRenewableSubscription }
    }

    // MARK: - Dependencies

    private let subscriptionService: SubscriptionService

    /// Task for the customerInfoStream listener (started once, lives for app lifetime)
    private var customerInfoStreamTask: Task<Void, Never>?

    // MARK: - Initialization

    init(subscriptionService: SubscriptionService = .shared) {
        self.subscriptionService = subscriptionService
    }

    // MARK: - Trial Status

    /// Story 10.3: Checks subscription/trial status via TrialManager + RevenueCat.
    /// Replaces the old UserDefaults-based local trial tracking.
    func checkTrialStatus() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        // Refresh TrialManager state (checks RevenueCat + Supabase)
        await TrialManager.shared.refreshState()

        // Map TrialManager state to SubscriptionState
        syncStateFromTrialManager()

        // Start real-time subscription listener (Story 6.3 — Task 5.2)
        startCustomerInfoStream()
    }

    /// Backward-compatible alias for checkTrialStatus
    func checkEntitlements() async {
        await checkTrialStatus()
    }

    // MARK: - Customer Info Stream

    /// Starts listening to RevenueCat's customerInfoStream for real-time subscription updates.
    /// Distinguishes auto-renewing subscriptions from non-renewing IAPs using
    /// `activeSubscriptions` (which only contains auto-renewing product IDs).
    func startCustomerInfoStream() {
        guard customerInfoStreamTask == nil, Purchases.isConfigured else { return }
        customerInfoStreamTask = Task {
            for await customerInfo in Purchases.shared.customerInfoStream {
                guard let entitlement = subscriptionService.activeEntitlement(from: customerInfo) else {
                    if !customerInfo.activeSubscriptions.isEmpty {
                        state = .subscribed
                        isPremium = true
                        cancelTrialExpirationNotification()
                        continue
                    }
                    if isPremium {
                        isPremium = false
                        state = .expired
                    }
                    continue
                }

                if entitlement.isActive {
                    // Check if entitlement comes from an auto-renewing subscription
                    let isAutoRenewing = customerInfo.activeSubscriptions.contains(entitlement.productIdentifier)

                    if isAutoRenewing {
                        // Auto-renewing monthly subscription — fully subscribed
                        state = .subscribed
                        isPremium = true
                        cancelTrialExpirationNotification()
                    } else {
                        // Non-renewing IAP — refresh trial state from server
                        await TrialManager.shared.refreshState()
                        syncStateFromTrialManager()
                    }
                } else if isPremium {
                    // Was subscribed but subscription/IAP has expired
                    isPremium = false
                    state = .expired
                }
            }
        }
    }

    // MARK: - Offerings

    /// Fetches available subscription packages from RevenueCat for the paywall
    func fetchOfferings() async {
        guard Purchases.isConfigured else { return }
        do {
            let offerings = try await Purchases.shared.offerings()
            if let current = offerings.current {
                availablePackages = current.availablePackages
            }
        } catch {
            #if DEBUG
            print("SubscriptionViewModel: Failed to fetch offerings: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Purchase

    /// Purchases a package and routes post-purchase handling based on product type:
    /// - Auto-renewing subscription → set `.subscribed` immediately
    /// - Non-renewing IAP → activate 3-day trial via TrialManager
    /// Returns true on success; sets `purchaseError` with warm copy on failure.
    func purchase(package: Package) async -> Bool {
        guard Purchases.isConfigured else {
            purchaseError = "I couldn't complete that purchase. Subscriptions aren't available right now."
            return false
        }
        isPurchasing = true
        purchaseError = nil
        defer { isPurchasing = false }

        do {
            let (_, customerInfo, userCancelled) = try await Purchases.shared.purchase(package: package)

            if userCancelled {
                // User cancelled the Apple payment sheet — stay on paywall, no error
                return false
            }

            if subscriptionService.hasActiveSubscription(from: customerInfo) {
                if package.storeProduct.productType == .autoRenewableSubscription {
                    // Monthly subscription — fully subscribed, no trial needed
                    state = .subscribed
                    isPremium = true
                    cancelTrialExpirationNotification()
                } else {
                    // Non-renewing IAP — activate 3-day trial (sets trial_activated_at server-side)
                    do {
                        try await TrialManager.shared.activateTrial()
                    } catch {
                        #if DEBUG
                        print("SubscriptionViewModel: Trial activation failed (non-blocking): \(error.localizedDescription)")
                        #endif
                    }

                    await TrialManager.shared.refreshState()
                    syncStateFromTrialManager()
                }
                return true
            }
            return false
        } catch {
            purchaseError = "I couldn't complete that purchase. Let's try again when you're ready."
            #if DEBUG
            print("SubscriptionViewModel: Purchase failed: \(error.localizedDescription)")
            #endif
            return false
        }
    }

    /// Restores previous purchases (Story 6.3 — Task 3)
    /// Returns true if entitlement restored; sets `purchaseError` with warm copy otherwise.
    func restorePurchases() async -> Bool {
        guard Purchases.isConfigured else {
            purchaseError = "I wasn't able to restore purchases. Subscriptions aren't available right now."
            return false
        }
        isLoading = true
        purchaseError = nil
        defer { isLoading = false }

        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            if subscriptionService.hasActiveSubscription(from: customerInfo) {
                state = .subscribed
                isPremium = true
                cancelTrialExpirationNotification()
                return true
            }
            purchaseError = "I wasn't able to find a previous subscription. If you think this is wrong, reach out to support."
            return false
        } catch {
            purchaseError = "I wasn't able to find a previous subscription. If you think this is wrong, reach out to support."
            #if DEBUG
            print("SubscriptionViewModel: Restore failed: \(error.localizedDescription)")
            #endif
            return false
        }
    }

    // MARK: - Story 10.3/10.4: TrialManager State Sync

    /// Maps TrialManager.currentState to SubscriptionState
    /// Story 10.4: Uses .paidTrial with messagesRemaining instead of .trial
    func syncStateFromTrialManager() {
        let trialManager = TrialManager.shared
        switch trialManager.currentState {
        case .discovery:
            // During discovery, user has access — not gated
            state = .unknown
            isPremium = false
        case .paywallShown, .blocked:
            state = .trialExpired
            isPremium = false
        case .trialActive:
            let remaining = max(1, TrialManager.trialDurationDays - trialManager.trialDayNumber + 1)
            state = .paidTrial(daysRemaining: remaining, messagesRemaining: trialManager.messagesRemaining)
            isPremium = true
            scheduleTrialExpirationNotification()
        case .trialExpired:
            state = .trialExpired
            isPremium = false
            cancelTrialExpirationNotification()
        case .subscribed:
            state = .subscribed
            isPremium = true
            cancelTrialExpirationNotification()
        }
    }

    // MARK: - Trial Expiration Notification

    private static let trialNotificationId = "coachme_trial_expiration"

    /// Story 10.3: Schedules notification using trial_activated_at + 3 days.
    func scheduleTrialExpirationNotification() {
        guard case .paidTrial(let daysRemaining, _) = state, daysRemaining > 1 else { return }
        let trialManager = TrialManager.shared
        guard trialManager.trialTimeRemaining > 0 else { return }

        let expirationDate = Date().addingTimeInterval(trialManager.trialTimeRemaining)

        Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()

            switch settings.authorizationStatus {
            case .notDetermined:
                let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
                if granted {
                    await scheduleTrialNotificationRequest(expirationDate: expirationDate)
                }
            case .authorized, .provisional:
                await scheduleTrialNotificationRequest(expirationDate: expirationDate)
            default:
                break
            }
        }
    }

    private func scheduleTrialNotificationRequest(expirationDate: Date) async {
        // Fire on the expiration day at 10 AM to nudge toward monthly subscription
        var components = Calendar.current.dateComponents([.year, .month, .day], from: expirationDate)
        components.hour = 10
        components.minute = 0

        let content = UNMutableNotificationContent()
        content.title = "CoachMe"
        content.body = "Your 3-day access ends today — subscribe to keep the conversation going."
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: Self.trialNotificationId,
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            #if DEBUG
            print("SubscriptionViewModel: Failed to schedule notification: \(error.localizedDescription)")
            #endif
        }
    }

    /// Cancels the trial expiration notification (e.g., when user subscribes)
    func cancelTrialExpirationNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [Self.trialNotificationId]
        )
    }
}
