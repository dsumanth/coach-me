//
//  TrialManager.swift
//  CoachMe
//
//  Story 10.3: Central trial state machine for paid-trial-after-discovery model
//

import Foundation
import RevenueCat
import Supabase

/// Trial lifecycle states for the paid-trial-after-discovery model
enum TrialState: Equatable, Sendable {
    /// User is in the free discovery session (no payment required)
    case discovery
    /// Discovery complete, paywall shown but no purchase yet
    case paywallShown
    /// Active paid trial ($3/3-day IAP)
    case trialActive(activatedAt: Date, messagesUsed: Int, messagesLimit: Int)
    /// Paid trial expired (>3 days or messages exhausted)
    case trialExpired
    /// Full subscriber (past trial or direct)
    case subscribed
    /// Discovery complete but no subscription/trial — read-only, paywall required
    case blocked
}

/// Central trial state machine managing the paid-trial-after-discovery lifecycle.
/// Service-layer singleton — NOT a ViewModel.
///
/// State flow: discovery → paywallShown → trialActive → trialExpired → subscribed
///                               ↓ (no purchase)
///                            blocked (read-only)
@MainActor
@Observable
final class TrialManager {

    // MARK: - Singleton

    static let shared = TrialManager()

    // MARK: - State

    /// The current trial state, computed from server data + entitlements
    private(set) var currentState: TrialState = .discovery

    /// Server-side trial activation timestamp (source of truth)
    private var trialActivatedAt: Date?

    /// Messages used during trial (from Story 10.1 rate limiting)
    private var messagesUsed: Int = 0
    /// Cached auto-renewing subscription flag resolved from RevenueCat.
    private var hasAutoRenewingSubscription = false

    /// Trial message limit
    static let trialMessageLimit = 100

    /// Trial duration in days
    static let trialDurationDays = 3

    // MARK: - Dependencies

    private let subscriptionService: SubscriptionService

    // MARK: - Init

    private init(subscriptionService: SubscriptionService = .shared) {
        self.subscriptionService = subscriptionService
    }

    /// Testing initializer
    init(subscriptionService: SubscriptionService, testInit: Bool = true) {
        self.subscriptionService = subscriptionService
    }

    // MARK: - Computed Properties

    /// Whether the user is in discovery mode (before discovery completion)
    var isDiscoveryMode: Bool {
        currentState == .discovery
    }

    /// Whether the user is blocked (discovery done, no subscription, no active trial)
    var isBlocked: Bool {
        currentState == .blocked
    }

    /// Whether the user has premium access (trial or subscribed)
    var isPremium: Bool {
        switch currentState {
        case .trialActive, .subscribed:
            return true
        default:
            return false
        }
    }

    /// Current trial day number (1, 2, or 3). Returns 0 if not in trial.
    var trialDayNumber: Int {
        guard let activatedAt = trialActivatedAt else { return 0 }
        let daysSince = Calendar.current.dateComponents([.day], from: activatedAt, to: Date()).day ?? 0
        return min(max(daysSince + 1, 1), Self.trialDurationDays)
    }

    /// Time remaining in trial. Returns 0 if not in trial.
    var trialTimeRemaining: TimeInterval {
        guard let activatedAt = trialActivatedAt else { return 0 }
        let trialEnd = activatedAt.addingTimeInterval(TimeInterval(Self.trialDurationDays * 24 * 60 * 60))
        return max(0, trialEnd.timeIntervalSince(Date()))
    }

    /// Messages remaining in trial
    var messagesRemaining: Int {
        guard case .trialActive(_, let used, let limit) = currentState else { return 0 }
        return max(0, limit - used)
    }

    /// The date when the 3-day IAP access expires
    var trialExpirationDate: Date? {
        guard let activatedAt = trialActivatedAt else { return nil }
        return activatedAt.addingTimeInterval(TimeInterval(Self.trialDurationDays * 24 * 60 * 60))
    }

    /// Formatted trial status text: "Day [X] of 3 — [Y] conversations left"
    var trialStatusText: String {
        guard case .trialActive = currentState else { return "" }
        let remaining = messagesRemaining
        return "Day \(trialDayNumber) of \(Self.trialDurationDays) — \(remaining) conversations left"
    }

    // MARK: - Actions

    /// Activates the paid trial by calling the server-side RPC.
    /// Only called after a successful StoreKit purchase.
    func activateTrial() async throws {
        let supabase = AppEnvironment.shared.supabase
        let activatedAt: Date = try await supabase.rpc("activate_trial").execute().value
        self.trialActivatedAt = activatedAt
        evaluateState()
    }

    /// Checks if the trial has expired (>3 days since activation)
    func checkTrialExpiry() -> Bool {
        guard let activatedAt = trialActivatedAt else { return false }
        let trialEnd = activatedAt.addingTimeInterval(TimeInterval(Self.trialDurationDays * 24 * 60 * 60))
        return Date() >= trialEnd
    }

    /// Refreshes trial state from Supabase + RevenueCat.
    /// Distinguishes auto-renewing subscriptions from non-renewing IAPs:
    /// - Auto-renewing → `.subscribed`
    /// - Non-renewing IAP → fall through to `trial_activated_at` tracking
    func refreshState() async {
        // Check RevenueCat entitlement and determine product type
        if let isAutoRenewing = await checkActiveEntitlementType() {
            hasAutoRenewingSubscription = isAutoRenewing
            if isAutoRenewing {
                currentState = .subscribed
                return
            }
            // Non-renewing IAP — fall through to trial_activated_at tracking
        } else {
            hasAutoRenewingSubscription = false
        }

        // Fetch user's trial_activated_at from Supabase
        await fetchTrialActivatedAt()

        // Fetch discovery status from context profile
        evaluateState()
    }

    /// Checks the active "premium" entitlement and determines if it comes from
    /// an auto-renewing subscription. Returns `nil` if no active entitlement,
    /// `true` if auto-renewing, `false` if non-renewing (IAP).
    private func checkActiveEntitlementType() async -> Bool? {
        do {
            let customerInfo = try await subscriptionService.fetchCustomerInfo()
            guard let entitlement = subscriptionService.activeEntitlement(from: customerInfo) else {
                if !customerInfo.activeSubscriptions.isEmpty {
                    return true
                }
                return nil
            }
            // activeSubscriptions only contains auto-renewing product IDs
            return customerInfo.activeSubscriptions.contains(entitlement.productIdentifier)
        } catch {
            // Fall back to simple entitlement check
            let isEntitled = await subscriptionService.isEntitled(to: "premium")
            return isEntitled ? true : nil
        }
    }

    // MARK: - State Evaluation

    /// Evaluates the current state based on all inputs
    func evaluateState() {
        // Already subscribed via RevenueCat
        if hasAutoRenewingSubscription {
            currentState = .subscribed
            return
        }

        // Check discovery completion via context profile
        // discoveryCompletedAt is set by Epic 11 when discovery session ends
        let discoveryCompleted = isDiscoveryCompleted()

        if !discoveryCompleted {
            currentState = .discovery
            return
        }

        // Discovery is complete — check trial
        guard let activatedAt = trialActivatedAt else {
            // No trial activated = blocked (or paywall shown state)
            currentState = .blocked
            return
        }

        // Check trial expiry
        let trialEnd = activatedAt.addingTimeInterval(TimeInterval(Self.trialDurationDays * 24 * 60 * 60))
        if Date() >= trialEnd || messagesUsed >= Self.trialMessageLimit {
            currentState = .trialExpired
            return
        }

        currentState = .trialActive(
            activatedAt: activatedAt,
            messagesUsed: messagesUsed,
            messagesLimit: Self.trialMessageLimit
        )
    }

    // MARK: - Internal Helpers

    /// Fetches trial_activated_at from Supabase user metadata
    private func fetchTrialActivatedAt() async {
        do {
            let supabase = AppEnvironment.shared.supabase
            let session = try await supabase.auth.session
            // trial_activated_at stored in users table, accessible via RPC
            struct TrialInfo: Decodable {
                let trialActivatedAt: Date?
                enum CodingKeys: String, CodingKey {
                    case trialActivatedAt = "trial_activated_at"
                }
            }

            // Query trial_activated_at from users table.
            // Some environments do not have users_view in PostgREST schema cache.
            do {
                let result: [TrialInfo] = try await supabase
                    .from("users")
                    .select("trial_activated_at")
                    .eq("id", value: session.user.id.uuidString)
                    .limit(1)
                    .execute()
                    .value
                trialActivatedAt = result.first?.trialActivatedAt
            } catch {
                // Fallback for older environments that still expose users_view.
                let fallback: [TrialInfo] = try await supabase
                    .from("users_view")
                    .select("trial_activated_at")
                    .eq("id", value: session.user.id.uuidString)
                    .limit(1)
                    .execute()
                    .value
                trialActivatedAt = fallback.first?.trialActivatedAt
            }
        } catch {
            #if DEBUG
            print("TrialManager: Failed to fetch trial_activated_at: \(error.localizedDescription)")
            #endif
        }
    }

    /// Checks if the user has completed the discovery session
    private func isDiscoveryCompleted() -> Bool {
        // This checks the locally cached context profile
        // discoveryCompletedAt is set by Epic 11 (Story 11.4)
        // For now, delegate to the context data
        guard let profile = cachedContextProfile else { return false }
        return profile.discoveryCompletedAt != nil
    }

    /// Cached context profile reference (set during app launch)
    var cachedContextProfile: ContextProfile?

    /// Updates the cached context profile (called when profile is fetched)
    func updateCachedProfile(_ profile: ContextProfile?) {
        cachedContextProfile = profile
        evaluateState()
    }

    /// Updates the message usage count (called by rate limiting system)
    func updateMessageUsage(_ count: Int) {
        messagesUsed = count
        evaluateState()
    }

    // MARK: - Testing Support

    /// Resets state for testing
    func resetForTesting() {
        currentState = .discovery
        trialActivatedAt = nil
        messagesUsed = 0
        hasAutoRenewingSubscription = false
        cachedContextProfile = nil
    }

    /// Sets trial activated at directly (for testing)
    func setTrialActivatedAt(_ date: Date?) {
        trialActivatedAt = date
    }
}
