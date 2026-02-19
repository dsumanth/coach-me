//
//  PersonalizedPaywallView.swift
//  CoachMe
//
//  Story 11.5: Personalized Paywall — Dynamic, discovery-driven paywall view
//

import SwiftUI
import RevenueCat

/// Personalized paywall that references discovery context for emotional continuity.
/// Separate from PaywallView — this serves post-discovery with dynamic copy;
/// PaywallView serves trial expiration with static copy.
struct PersonalizedPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let viewModel: PersonalizedPaywallViewModel
    let subscriptionViewModel: SubscriptionViewModel

    /// Called when purchase completes (true = success)
    var onPurchaseCompleted: ((Bool) -> Void)?
    /// Called when user dismisses without purchasing
    var onDismiss: (() -> Void)?

    var body: some View {
        ZStack {
            // Task 1.14: Adaptive background
            Color.adaptiveCream(colorScheme)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Task 1.4: Personalized header
                    heroSection

                    // Task 1.5: Personalized body
                    bodySection

                    // Task 1.6: RevenueCat packages
                    packagesSection

                    // Task 1.12: Purchase error display
                    if let errorMessage = subscriptionViewModel.purchaseError {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(Color.terracotta.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .transition(.opacity)
                            .accessibilityLabel("Purchase error: \(errorMessage)")
                    }

                    // Task 1.7: CTA button
                    ctaButton

                    // Task 1.8: Dismiss button (secondary for firstPresentation)
                    if viewModel.isFirstPresentation {
                        dismissButton
                    }

                    // Task 1.9: Restore purchases
                    restoreButton

                    // Task 1.10: Legal fine print
                    legalText
                }
                .padding(20)
                .padding(.top, viewModel.isFirstPresentation ? 40 : 12)
            }

            // Task 1.11: Loading overlay during purchase
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
        // Return presentation: show as sheet with toolbar dismiss
        .toolbar {
            if !viewModel.isFirstPresentation {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Not now") {
                        onDismiss?()
                        dismiss()
                    }
                    .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                    .accessibilityHint("Dismiss paywall. You'll need to subscribe to send messages.")
                }
            }
        }
        .task {
            // H2 fix: Track impression once per presentation (Task 2.6)
            if !viewModel.impressionLogged {
                viewModel.impressionLogged = true
            }
            // Fetch offerings when view appears
            await subscriptionViewModel.fetchOfferings()
        }
    }

    // MARK: - Hero Section (Task 1.4)

    private var heroSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 36))
                .foregroundStyle(Color.terracotta)
                .accessibilityHidden(true)

            Text(viewModel.headerText)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .accessibilityAddTraits(.isHeader)
        }
    }

    // MARK: - Body Section (Task 1.5)

    private var bodySection: some View {
        Text(viewModel.bodyText)
            .font(.body)
            .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
            .multilineTextAlignment(.center)
            .lineSpacing(3)
            .padding(.horizontal, 8)
    }

    // MARK: - Packages Section (Task 1.6 + Task 1.13)

    private var packagesSection: some View {
        VStack(spacing: 12) {
            if subscriptionViewModel.availablePackages.isEmpty {
                if subscriptionViewModel.isLoading {
                    // M3 fix: Show loading indicator while offerings fetch
                    ProgressView()
                        .padding(.vertical, 20)
                        .accessibilityLabel("Loading subscription options")
                } else {
                    // Task 1.13: Offerings failure state
                    offeringsFailureState
                }
            } else {
                ForEach(subscriptionViewModel.availablePackages, id: \.identifier) { package in
                    personalizedPackageRow(package: package) {
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

    // MARK: - Package Row (Task 1.6, reuses PaywallView pattern)

    private func personalizedPackageRow(package: Package, onPurchase: @escaping () -> Void) -> some View {
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

    // MARK: - CTA Button (Task 1.7)

    private var ctaButton: some View {
        Button {
            // If packages available, purchase first; otherwise CTA acts as scroll indicator
            if let firstPackage = subscriptionViewModel.availablePackages.first {
                Task {
                    let success = await subscriptionViewModel.purchase(package: firstPackage)
                    if success {
                        onPurchaseCompleted?(true)
                        dismiss()
                    }
                }
            }
        } label: {
            Text(viewModel.ctaText)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    Capsule()
                        .fill(Color.terracotta)
                )
        }
        .padding(.horizontal, 12)
        .accessibilityLabel(viewModel.ctaText)
        .accessibilityHint("Opens subscription options to continue coaching")
        .disabled(subscriptionViewModel.availablePackages.isEmpty)
        .opacity(subscriptionViewModel.availablePackages.isEmpty ? 0.5 : 1.0)
    }

    // MARK: - Dismiss Button (Task 1.8)

    private var dismissButton: some View {
        Button {
            onDismiss?()
            dismiss()
        } label: {
            Text("Not now")
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
        }
        .accessibilityLabel("Not now")
        .accessibilityHint("Dismisses the paywall. You'll need to subscribe to send more messages.")
    }

    // MARK: - Restore Button (Task 1.9)

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

    // MARK: - Legal Text (Task 1.10)

    private var legalText: some View {
        Text("Subscriptions are managed through your Apple ID. You can cancel anytime in Settings.")
            .font(.caption2)
            .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
    }

    // MARK: - Offerings Failure State (Task 1.13)

    private var offeringsFailureState: some View {
        VStack(spacing: 16) {
            Text("I'm having trouble loading subscription options. Please check your connection and try again.")
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                .multilineTextAlignment(.center)

            Button {
                Task {
                    await subscriptionViewModel.fetchOfferings()
                }
            } label: {
                Text("Try again")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.terracotta)
                    .padding(.horizontal, 20)
                    .frame(height: 36)
                    .background(
                        Capsule()
                            .strokeBorder(Color.terracotta, lineWidth: 1.5)
                    )
            }
            .accessibilityHint("Retry loading subscription options")
        }
        .padding(20)
        .adaptiveGlass()
    }
}
