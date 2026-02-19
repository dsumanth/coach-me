//
//  UsageViewModel.swift
//  CoachMe
//
//  Story 10.5: Usage Transparency UI
//  ViewModel for computing and exposing message usage display state
//

import Foundation

// MARK: - Display Tier

/// Severity tier for usage display, based on percentage consumed
enum UsageDisplayTier: Equatable, Sendable {
    /// 0–79% — no indicator shown for paid users
    case silent
    /// 80–94% — gentle reminder
    case gentle
    /// 95–99% — prominent warning
    case prominent
    /// 100% — blocked
    case blocked
}

// MARK: - Display State

/// What the usage indicator should render
enum UsageDisplayState: Equatable, Sendable {
    /// Do not show any indicator
    case hidden
    /// Paid user: compact indicator with remaining count
    case compact(messagesRemaining: Int, tier: UsageDisplayTier)
    /// Trial user: always-visible indicator with remaining/total
    case trial(messagesRemaining: Int, totalLimit: Int)
    /// User is at limit — show blocked state
    case blocked(resetDate: Date?)
}

// MARK: - UsageViewModel

/// Observes message usage data and computes display state for UI
@MainActor
@Observable
final class UsageViewModel {
    // MARK: - State

    var displayState: UsageDisplayState = .hidden
    private(set) var currentUsage: MessageUsage?
    var isLoading = false
    var error: String?

    // MARK: - Dependencies

    private let usageService: UsageTrackingService
    private var subscriptionViewModel: SubscriptionViewModel {
        AppEnvironment.shared.subscriptionViewModel
    }

    // MARK: - Initialization

    init(usageService: UsageTrackingService = .shared) {
        self.usageService = usageService
    }

    // MARK: - Refresh

    /// Fetches current usage from Supabase and recomputes display state
    func refreshUsage() async {
        guard let userId = await AuthService.shared.currentUserId else { return }

        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            currentUsage = try await usageService.fetchCurrentUsage(userId: userId)
            recalculateDisplayState()
        } catch {
            #if DEBUG
            print("UsageViewModel: Fetch failed — \(error.localizedDescription)")
            #endif
            self.error = "I couldn't check your usage right now — don't worry, you can keep chatting."
            displayState = .hidden
        }
    }

    // MARK: - Optimistic Increment

    /// Called after a message is sent — optimistically increments count and recalculates
    func onMessageSent() {
        guard var usage = currentUsage else { return }
        usageService.incrementLocalCount(&usage)
        currentUsage = usage
        recalculateDisplayState()
    }

    // MARK: - Tier Calculation

    /// Recalculates `displayState` from current usage + subscription state
    private func recalculateDisplayState() {
        guard let usage = currentUsage else {
            displayState = .hidden
            return
        }

        let subState = subscriptionViewModel.state

        switch subState {
        case .paidTrial:
            // Trial user: always show trial indicator
            if usage.isAtLimit {
                displayState = .blocked(resetDate: nil)
            } else {
                displayState = .trial(
                    messagesRemaining: usage.messagesRemaining,
                    totalLimit: usage.limit
                )
            }

        case .subscribed:
            // Paid user: threshold-based display
            let tier = computeTier(percentage: usage.usagePercentage)
            switch tier {
            case .silent:
                displayState = .hidden
            case .gentle, .prominent:
                displayState = .compact(messagesRemaining: usage.messagesRemaining, tier: tier)
            case .blocked:
                // Approximate next month reset — first day of next month
                let nextReset = nextBillingResetDate()
                displayState = .blocked(resetDate: nextReset)
            }

        default:
            // Unknown/expired — hide indicator; rate limiting handled by edge function
            displayState = .hidden
        }
    }

    /// Maps a usage percentage to a display tier
    private func computeTier(percentage: Double) -> UsageDisplayTier {
        switch percentage {
        case ..<0.80:
            return .silent
        case 0.80..<0.95:
            return .gentle
        case 0.95..<1.0:
            return .prominent
        default:
            return .blocked
        }
    }

    /// Approximates the next billing reset date (first of next month)
    private func nextBillingResetDate() -> Date? {
        let calendar = Calendar.current
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: Date()) else {
            return nil
        }
        let components = calendar.dateComponents([.year, .month], from: nextMonth)
        return calendar.date(from: components)
    }

    // MARK: - Accessibility

    /// VoiceOver description for the current usage state
    var accessibleUsageDescription: String {
        guard let usage = currentUsage else {
            return "Usage information unavailable"
        }

        switch displayState {
        case .hidden:
            return "\(usage.messageCount) of \(usage.limit) messages used this month"
        case .compact(let remaining, _):
            return "\(remaining) messages remaining this month. \(usage.messageCount) of \(usage.limit) used."
        case .trial(let remaining, let total):
            return "\(remaining) of \(total) trial messages remaining"
        case .blocked(let resetDate):
            if let date = resetDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                return "Message limit reached. Refreshes on \(formatter.string(from: date))"
            }
            return "Message limit reached"
        }
    }
}
