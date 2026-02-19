//
//  PaywallView.swift
//  CoachMe
//
//  Story 6.2: Free Trial Experience — Subscription purchase screen
//  Story 10.4: Context-specific paywall copy for trial states
//

import SwiftUI
import RevenueCat

/// Paywall presentation contexts for different trial/subscription states
enum PaywallContext: Equatable {
    /// 3-day IAP access has fully expired (time ran out)
    case trialExpired
    /// IAP trial messages exhausted before time expired
    case messagesExhausted
    /// User cancelled subscription
    case cancelled
    /// Generic paywall (no specific context)
    case generic
}

/// A warm, value-focused paywall that presents subscription options.
/// Story 10.4: Supports context-specific copy for different trial states.
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let subscriptionViewModel: SubscriptionViewModel
    /// Context for which state triggered the paywall
    var context: PaywallContext = .generic
    /// Packages to display. Defaults to all available; use `subscriptionOnlyPackages`
    /// for post-trial paywalls so the IAP doesn't appear again.
    var packages: [Package]?
    var onPurchaseCompleted: ((Bool) -> Void)?

    /// Resolved packages: explicit override or all available packages
    private var displayPackages: [Package] {
        packages ?? subscriptionViewModel.availablePackages
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Warm background
                Color.adaptiveCream(colorScheme)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Hero section — context-aware copy (Story 10.4)
                        heroSection

                        // Subscription options
                        packagesSection

                        // Purchase/restore error (Story 6.3 — Task 2.6)
                        if let errorMessage = subscriptionViewModel.purchaseError {
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundStyle(Color.terracotta.opacity(0.9))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                                .transition(.opacity)
                                .accessibilityLabel("Purchase error: \(errorMessage)")
                        }

                        // Restore purchases
                        restoreButton

                        // Fine print
                        legalText
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Keep Coaching")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Not now") {
                        dismiss()
                    }
                    .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                    .accessibilityHint("Dismiss paywall. You can still read past conversations.")
                }
            }
            .task {
                await subscriptionViewModel.fetchOfferings()
            }
            .overlay {
                if subscriptionViewModel.isPurchasing {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .overlay {
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(.white)
                        }
                        .accessibilityLabel("Processing your subscription")
                }
            }
        }
    }

    // MARK: - Hero Section (Story 10.4: context-aware copy)

    private var heroSection: some View {
        VStack(spacing: 16) {
            Image(systemName: heroIconName)
                .font(.system(size: 48))
                .foregroundStyle(Color.terracotta)
                .accessibilityHidden(true)

            Text(heroTitle)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .multilineTextAlignment(.center)

            Text(heroSubtitle)
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 12)
        .accessibilityElement(children: .combine)
    }

    /// Story 10.4: Context-specific hero icon
    private var heroIconName: String {
        switch context {
        case .messagesExhausted:
            return "bubble.left.and.text.bubble.right.fill"
        case .cancelled:
            return "heart.fill"
        default:
            return "heart.text.clipboard.fill"
        }
    }

    /// Context-specific hero title (warm, first-person per UX-11)
    private var heroTitle: String {
        switch context {
        case .messagesExhausted:
            return "You've used all your conversations — subscribe to keep the momentum going."
        case .cancelled:
            return "Ready to come back?"
        case .trialExpired:
            return "Your 3-day access has ended"
        case .generic:
            return "You've experienced what Coach App can do"
        }
    }

    /// Context-specific hero subtitle
    private var heroSubtitle: String {
        switch context {
        case .messagesExhausted:
            return "You're on a roll — subscribe to unlock 800 conversations per month"
        case .cancelled:
            return "Your coach is still here, ready to pick up where you left off"
        case .trialExpired, .generic:
            return "Keep the conversation going with a subscription"
        }
    }

    // MARK: - Packages Section

    private var packagesSection: some View {
        VStack(spacing: 12) {
            if displayPackages.isEmpty && !subscriptionViewModel.isLoading {
                // Fallback when RevenueCat isn't configured or offerings unavailable
                VStack(spacing: 12) {
                    Text("Subscriptions are currently unavailable — please try again later.")
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                }
                .padding(20)
                .adaptiveGlass()
            } else {
                ForEach(displayPackages, id: \.identifier) { package in
                    PackageRow(package: package) {
                        Task {
                            let success = await subscriptionViewModel.purchase(package: package)
                            if success {
                                onPurchaseCompleted?(true)
                                dismiss()
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Restore Button

    private var restoreButton: some View {
        Button {
            Task {
                let success = await subscriptionViewModel.restorePurchases()
                if success {
                    onPurchaseCompleted?(true)
                    dismiss()
                }
            }
        } label: {
            Text("Restore purchases")
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveTerracotta(colorScheme))
        }
        .accessibilityHint("Restore a previously purchased subscription")
    }

    // MARK: - Legal Text

    private var legalText: some View {
        Text("Subscriptions are managed through your Apple ID. You can cancel anytime in Settings.")
            .font(.caption2)
            .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
    }
}

// MARK: - Package Row

private struct PackageRow: View {
    let package: Package
    let onPurchase: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onPurchase) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(package.storeProduct.localizedTitle)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.adaptiveText(colorScheme))

                    Text(package.storeProduct.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                        .lineLimit(2)
                }

                Spacer()

                Text(package.storeProduct.localizedPriceString)
                    .font(.body.weight(.bold))
                    .foregroundStyle(Color.terracotta)
            }
            .padding(16)
            .adaptiveGlass()
        }
        .accessibilityLabel("\(package.storeProduct.localizedTitle), \(package.storeProduct.localizedPriceString)")
        .accessibilityHint("Subscribe to \(package.storeProduct.localizedTitle)")
    }
}
