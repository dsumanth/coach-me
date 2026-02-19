//
//  SubscriptionManagementViewModel.swift
//  CoachMe
//
//  Story 6.4: Subscription Management — ViewModel for management view
//

import Foundation
import RevenueCat

/// Manages subscription detail state for the SubscriptionManagementView.
/// Uses RevenueCat's `customerInfoStream` for real-time updates and
/// `unsubscribeDetectedAt` (not `willRenew`) for cancellation detection.
@MainActor @Observable
final class SubscriptionManagementViewModel {

    // MARK: - State

    var subscriptionState: SubscriptionManagementState = .free
    var planName: String?
    var expirationDate: Date?
    var willRenew: Bool = false
    var isLoading: Bool = true
    var error: SubscriptionManagementError?

    // MARK: - Error Types

    enum SubscriptionManagementError: LocalizedError {
        case loadFailed
        case manageSubscriptionsFailed
        case restoreFailed
        case restoreNotFound

        var errorDescription: String? {
            switch self {
            case .loadFailed:
                return "I couldn't load your subscription details right now."
            case .manageSubscriptionsFailed:
                return "I couldn't open subscription management. Try again from your device Settings."
            case .restoreFailed:
                return "I wasn't able to find a previous subscription."
            case .restoreNotFound:
                return "I didn't find an active subscription to restore."
            }
        }
    }

    // MARK: - Private

    private var customerInfoTask: Task<Void, Never>?
    private let subscriptionService: SubscriptionService

    init(subscriptionService: SubscriptionService = .shared) {
        self.subscriptionService = subscriptionService
    }

    // MARK: - Lifecycle

    func startListening() {
        guard customerInfoTask == nil, Purchases.isConfigured else { return }
        customerInfoTask = Task {
            for await customerInfo in Purchases.shared.customerInfoStream {
                updateState(from: customerInfo)
            }
        }
    }

    func stopListening() {
        customerInfoTask?.cancel()
        customerInfoTask = nil
    }

    // MARK: - Data

    func refreshSubscriptionInfo() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        guard Purchases.isConfigured else {
            subscriptionState = .free
            return
        }

        do {
            if let userId = await AuthService.shared.currentUserId {
                try? await subscriptionService.identifyUser(userId: userId)
            }
            await subscriptionService.syncPurchases()

            let customerInfo = try await Purchases.shared.customerInfo()
            updateState(from: customerInfo)
        } catch {
            self.error = .loadFailed
        }
    }

    // MARK: - Actions

    func openManageSubscriptions() async {
        guard Purchases.isConfigured else {
            error = .manageSubscriptionsFailed
            return
        }
        do {
            try await Purchases.shared.showManageSubscriptions()
        } catch {
            self.error = .manageSubscriptionsFailed
        }
    }

    func restorePurchases() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        guard Purchases.isConfigured else {
            error = .restoreFailed
            return
        }

        do {
            if let userId = await AuthService.shared.currentUserId {
                try? await subscriptionService.identifyUser(userId: userId)
            }
            let customerInfo = try await Purchases.shared.restorePurchases()
            updateState(from: customerInfo)
            if subscriptionState == .free || subscriptionState == .expired {
                error = .restoreNotFound
            }
        } catch {
            self.error = .restoreFailed
        }
    }

    // MARK: - State Mapping

    func updateState(from customerInfo: CustomerInfo) {
        guard let entitlement = subscriptionService.activeEntitlement(from: customerInfo) else {
            if let activeProductId = customerInfo.activeSubscriptions.first {
                subscriptionState = .active
                planName = activeProductId
                expirationDate = nil
                willRenew = true
                return
            }
            subscriptionState = .free
            planName = nil
            expirationDate = nil
            willRenew = false
            return
        }

        expirationDate = entitlement.expirationDate
        planName = entitlement.productIdentifier
        willRenew = entitlement.willRenew

        if !entitlement.isActive {
            subscriptionState = .expired
        } else if entitlement.billingIssueDetectedAt != nil {
            subscriptionState = .billingIssue
        } else if entitlement.unsubscribeDetectedAt != nil {
            subscriptionState = .cancelled
        } else {
            subscriptionState = .active
        }
    }

    // MARK: - Display Helpers

    var formattedExpirationDate: String {
        guard let date = expirationDate else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
