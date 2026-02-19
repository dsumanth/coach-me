//
//  SubscriptionService.swift
//  CoachMe
//
//  Story 6.1: RevenueCat Integration
//

import Foundation
import RevenueCat

@MainActor
final class SubscriptionService {
    static let shared = SubscriptionService()
    private let preferredEntitlementIDs = ["premium", "pro", "plus", "subscription"]

    enum SubscriptionError: LocalizedError {
        case identifyFailed(Error)
        case logoutFailed(Error)
        case entitlementCheckFailed(Error)
        case notConfigured

        var errorDescription: String? {
            switch self {
            case .identifyFailed:
                return "I had trouble syncing your subscription. Let's try again."
            case .logoutFailed:
                return "I had trouble signing out of your subscription. Let's try again."
            case .entitlementCheckFailed:
                return "I couldn't check your subscription status right now."
            case .notConfigured:
                return "Subscription features aren't available yet."
            }
        }
    }

    /// True when running inside the XCTest host — avoids touching RevenueCat's
    /// C-level code which causes malloc double-free crashes in unit tests.
    private let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    private init() {}

    /// Identify user with RevenueCat using their Supabase user ID
    /// Links the Supabase user to their RevenueCat subscription
    func identifyUser(userId: UUID) async throws {
        guard !isRunningTests, Purchases.isConfigured else {
            throw SubscriptionError.notConfigured
        }
        do {
            let (_, _) = try await Purchases.shared.logIn(userId.uuidString)
            #if DEBUG
            print("SubscriptionService: Identified user \(userId.uuidString)")
            #endif
        } catch {
            #if DEBUG
            print("SubscriptionService: Failed to identify user: \(error.localizedDescription)")
            #endif
            throw SubscriptionError.identifyFailed(error)
        }
    }

    /// Reset RevenueCat to anonymous user on sign-out
    func logOutUser() async throws {
        guard !isRunningTests, Purchases.isConfigured else { return }
        do {
            _ = try await Purchases.shared.logOut()
            #if DEBUG
            print("SubscriptionService: Logged out user")
            #endif
        } catch {
            #if DEBUG
            print("SubscriptionService: Failed to log out: \(error.localizedDescription)")
            #endif
            throw SubscriptionError.logoutFailed(error)
        }
    }

    /// Check if user has an active entitlement
    func isEntitled(to entitlementId: String = "premium") async -> Bool {
        guard !isRunningTests, Purchases.isConfigured else { return false }
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            if customerInfo.entitlements.all[entitlementId]?.isActive == true {
                return true
            }
            return activeEntitlement(from: customerInfo) != nil
        } catch {
            #if DEBUG
            print("SubscriptionService: Failed to check entitlement: \(error.localizedDescription)")
            #endif
            return false
        }
    }

    /// Returns the best active entitlement for the current user.
    /// Prefers known IDs, then falls back to any active entitlement.
    func activeEntitlement(from customerInfo: CustomerInfo) -> EntitlementInfo? {
        for entitlementId in preferredEntitlementIDs {
            if let entitlement = customerInfo.entitlements.all[entitlementId], entitlement.isActive {
                return entitlement
            }
        }
        return customerInfo.entitlements.active.values.first
    }

    /// Returns true when either an entitlement is active, or RevenueCat reports
    /// an active auto-renewing subscription product.
    func hasActiveSubscription(from customerInfo: CustomerInfo) -> Bool {
        activeEntitlement(from: customerInfo) != nil || !customerInfo.activeSubscriptions.isEmpty
    }

    /// Sync purchases with App Store to recover entitlements after account transfer
    /// or delayed RevenueCat updates.
    func syncPurchases() async {
        guard !isRunningTests, Purchases.isConfigured else { return }
        do {
            _ = try await Purchases.shared.syncPurchases()
        } catch {
            #if DEBUG
            print("SubscriptionService: syncPurchases failed: \(error.localizedDescription)")
            #endif
        }
    }

    /// Fetch full customer info from RevenueCat
    func fetchCustomerInfo() async throws -> CustomerInfo {
        guard !isRunningTests, Purchases.isConfigured else {
            throw SubscriptionError.notConfigured
        }
        do {
            return try await Purchases.shared.customerInfo()
        } catch {
            #if DEBUG
            print("SubscriptionService: Failed to fetch customer info: \(error.localizedDescription)")
            #endif
            throw SubscriptionError.entitlementCheckFailed(error)
        }
    }
}
