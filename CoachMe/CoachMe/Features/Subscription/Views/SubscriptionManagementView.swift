//
//  SubscriptionManagementView.swift
//  CoachMe
//
//  Story 6.4: Subscription Management — view/manage subscription details
//

import SwiftUI

/// Displays subscription status and management actions.
/// Supports active, cancelled, billing issue, expired, and free states.
struct SubscriptionManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var viewModel = SubscriptionManagementViewModel()
    @State private var showPaywall = false

    /// Shared subscription VM for paywall presentation
    private var subscriptionViewModel: SubscriptionViewModel {
        AppEnvironment.shared.subscriptionViewModel
    }

    var body: some View {
        ZStack {
            Color.adaptiveCream(colorScheme)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Status section (AC #1)
                    statusSection

                    // Cancellation banner (AC #3)
                    if viewModel.subscriptionState == .cancelled {
                        cancellationBanner
                    }

                    // Billing issue alert (AC #4)
                    if viewModel.subscriptionState == .billingIssue {
                        billingIssueAlert
                    }

                    // Actions section (AC #2, #5, #6)
                    actionsSection

                    // Restore purchases (AC #6)
                    restoreSection
                }
                .padding(16)
            }

            if viewModel.isLoading {
                Color.black.opacity(0.15)
                    .ignoresSafeArea()
                    .overlay {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(Color.adaptiveTerracotta(colorScheme))
                    }
                    .accessibilityLabel("Loading subscription details")
            }
        }
        .navigationTitle("Subscription")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
                    .foregroundStyle(Color.adaptiveTerracotta(colorScheme))
            }
        }
        .task {
            await viewModel.refreshSubscriptionInfo()
            viewModel.startListening()
        }
        .onDisappear {
            viewModel.stopListening()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(subscriptionViewModel: subscriptionViewModel)
        }
        .alert("Subscription", isPresented: .init(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.error = nil }
        } message: {
            Text(viewModel.error?.errorDescription ?? "")
        }
    }

    // MARK: - Status Section (Task 1.2)

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Plan")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                HStack {
                    // Status icon + badge
                    Image(systemName: viewModel.subscriptionState.systemImageName)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(viewModel.subscriptionState.statusColor)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(viewModel.planName ?? "Free Plan")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.adaptiveText(colorScheme))

                            Text(viewModel.subscriptionState.displayLabel)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(viewModel.subscriptionState.statusColor)
                                .clipShape(Capsule())
                        }

                        if viewModel.expirationDate != nil {
                            Text(viewModel.willRenew ? "Renews \(viewModel.formattedExpirationDate)" : "Expires \(viewModel.formattedExpirationDate)")
                                .font(.caption)
                                .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                        }
                    }

                    Spacer()
                }
                .padding(16)
            }
            .adaptiveGlass()
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Plan: \(viewModel.planName ?? "Free"). Status: \(viewModel.subscriptionState.displayLabel)")
        }
    }

    // MARK: - Cancellation Banner (Task 1.3)

    private var cancellationBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(Color.orange)
                    .accessibilityHidden(true)
                Text("Your subscription is active until \(viewModel.formattedExpirationDate). You can resubscribe anytime.")
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
            }
        }
        .padding(16)
        .adaptiveGlass()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Your subscription is active until \(viewModel.formattedExpirationDate). You can resubscribe anytime.")
    }

    // MARK: - Billing Issue Alert (Task 1.4)

    private var billingIssueAlert: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.red)
                    .accessibilityHidden(true)
                Text("There's a hiccup with your payment. Let's get that sorted.")
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
            }

            Button {
                Task { await viewModel.openManageSubscriptions() }
            } label: {
                Text("Update Payment Method")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.adaptiveTerracotta(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .accessibilityLabel("Update payment method")
            .accessibilityHint("Opens subscription management to update your payment")
        }
        .padding(16)
        .adaptiveGlass()
    }

    // MARK: - Actions Section (Task 1.5, AC #2, #5)

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Actions")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                // Manage Subscription (AC #2) — only when subscribed/cancelled/billing
                if viewModel.subscriptionState != .free && viewModel.subscriptionState != .expired {
                    Button {
                        Task { await viewModel.openManageSubscriptions() }
                    } label: {
                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: "gearshape")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Color.adaptiveTerracotta(colorScheme))
                                Text("Manage Subscription")
                                    .font(.body)
                                    .foregroundStyle(Color.adaptiveText(colorScheme))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                        }
                        .padding(16)
                    }
                    .accessibilityLabel("Manage Subscription")
                    .accessibilityHint("Opens iOS subscription management")
                }

                // Subscribe button (AC #5) — when free or expired
                if viewModel.subscriptionState == .free || viewModel.subscriptionState == .expired {
                    Button {
                        showPaywall = true
                    } label: {
                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: "crown")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Color.adaptiveTerracotta(colorScheme))
                                Text("Subscribe")
                                    .font(.body)
                                    .foregroundStyle(Color.adaptiveText(colorScheme))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                        }
                        .padding(16)
                    }
                    .accessibilityLabel("Subscribe")
                    .accessibilityHint("Opens subscription plans")
                }
            }
            .adaptiveGlass()
        }
    }

    // MARK: - Restore Section (Task 1.5, AC #6)

    private var restoreSection: some View {
        VStack(spacing: 8) {
            Button {
                Task { await viewModel.restorePurchases() }
            } label: {
                Text("Restore Purchases")
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveTerracotta(colorScheme))
            }
            .accessibilityLabel("Restore Purchases")
            .accessibilityHint("Check for and restore a previous subscription")
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SubscriptionManagementView()
    }
}
