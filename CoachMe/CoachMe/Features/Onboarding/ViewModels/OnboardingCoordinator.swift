//
//  OnboardingCoordinator.swift
//  CoachMe
//
//  Story 11.3 — Task 2: Onboarding flow state machine
//

import Foundation
import SwiftUI

/// Manages the onboarding sub-flow: welcome → discoveryChat → paywall → paidChat.
/// Separate from Router — Router manages app-level navigation, this manages onboarding states.
@MainActor
@Observable
final class OnboardingCoordinator {
    // MARK: - Flow States

    enum FlowState: Equatable {
        case welcome
        case discoveryChat
        case paywall
        case paidChat
    }

    // MARK: - Published State

    /// Current position in the onboarding flow
    var flowState: FlowState = .welcome

    /// Conversation ID for the discovery chat session
    var discoveryConversationId: UUID?

    /// Story 11.5: Discovery context for personalized paywall copy (Task 5.1)
    /// Populated when discovery completes; used for both first and return paywall presentations.
    var discoveryPaywallContext: DiscoveryPaywallContext?

    // MARK: - Initialization

    /// Restores flow state from persisted flags for return-to-app scenarios (Task 5.4).
    /// When a user completed discovery but hasn't subscribed, auto-resume at paywall state.
    init() {
        let discoveryDone = UserDefaults.standard.bool(forKey: Self.discoveryCompletedKey)
        let onboardingDone = UserDefaults.standard.bool(forKey: Self.hasCompletedOnboardingKey)
        if discoveryDone && !onboardingDone {
            flowState = .paywall
        }
    }

    // MARK: - Persistence Keys

    private static let hasCompletedOnboardingKey = "has_completed_onboarding"
    private static let discoveryCompletedKey = "discovery_completed"

    // MARK: - Computed Properties

    /// Whether the user has completed the onboarding flow at least once
    var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: Self.hasCompletedOnboardingKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.hasCompletedOnboardingKey) }
    }

    /// Whether the discovery session has been used (prevents second free session)
    var discoveryCompleted: Bool {
        get { UserDefaults.standard.bool(forKey: Self.discoveryCompletedKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.discoveryCompletedKey) }
    }

    /// Story 11.5 (Task 5.4): Whether a return paywall should be shown.
    /// True when discovery was completed but user hasn't subscribed yet.
    var shouldShowReturnPaywall: Bool {
        discoveryCompleted && !hasCompletedOnboarding
    }

    // MARK: - Flow Actions

    /// User taps "Let's begin" on the welcome screen.
    /// Creates a new conversation and transitions to discovery chat.
    func beginDiscovery() {
        let conversationId = UUID()
        discoveryConversationId = conversationId
        flowState = .discoveryChat
    }

    /// Server signals that discovery is complete.
    /// Transitions to paywall overlay.
    func onDiscoveryComplete() {
        discoveryCompleted = true
        flowState = .paywall
    }

    /// Story 11.5: Server signals discovery complete with context for paywall personalization (Task 5.1).
    func onDiscoveryComplete(with context: DiscoveryPaywallContext) {
        discoveryPaywallContext = context
        onDiscoveryComplete()
    }

    /// User successfully subscribed via the paywall.
    /// Transitions to paid chat mode and marks onboarding complete.
    func onSubscriptionConfirmed() {
        hasCompletedOnboarding = true
        flowState = .paidChat
    }

    /// User dismissed the paywall without subscribing.
    /// Stays in paywall state — chat input is disabled.
    func onPaywallDismissed() {
        // flowState stays at .paywall — chat gating will handle re-showing
    }

    /// Marks onboarding as complete (e.g., after subscription or skip).
    func completeOnboarding() {
        hasCompletedOnboarding = true
    }

    /// Resets flow state for a fresh start (used in testing or re-onboarding).
    func reset() {
        flowState = .welcome
        discoveryConversationId = nil
        discoveryPaywallContext = nil
    }

    // MARK: - Server Sync

    /// Syncs local onboarding flags with server-side discovery state.
    /// Called on app launch after auth to catch state mismatches (e.g., user force-quit
    /// mid-discovery, or discovery completed on a different device).
    func syncWithServer() async {
        guard let userId = await AuthService.shared.currentUserId else { return }
        do {
            let profile = try await ContextRepository.shared.fetchProfile(userId: userId)
            if profile.discoveryCompletedAt != nil {
                discoveryCompleted = true
            }
        } catch {
            // Non-blocking — local UserDefaults state is acceptable fallback
            #if DEBUG
            print("OnboardingCoordinator: Failed to sync server state — \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - State Cleanup

    /// Clears all persisted onboarding state.
    /// Called on sign-out and account deletion so a new account gets fresh onboarding.
    static func clearPersistedState() {
        UserDefaults.standard.removeObject(forKey: hasCompletedOnboardingKey)
        UserDefaults.standard.removeObject(forKey: discoveryCompletedKey)
    }
}

// MARK: - Environment Key

private struct OnboardingCoordinatorKey: EnvironmentKey {
    @MainActor
    static let defaultValue: OnboardingCoordinator = OnboardingCoordinator()
}

extension EnvironmentValues {
    var onboardingCoordinator: OnboardingCoordinator {
        get { self[OnboardingCoordinatorKey.self] }
        set { self[OnboardingCoordinatorKey.self] = newValue }
    }
}
