//
//  SettingsView.swift
//  CoachMe
//
//  Created by Claude Code on 2/7/26.
//
//  Story 2.6: Settings screen with "Clear all conversations" option
//

import SwiftUI

/// Settings screen with conversation management options
/// Per architecture.md: Apply adaptive design modifiers, never raw .glassEffect()
struct SettingsView: View {
    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.router) private var router
    @AppStorage(AppAppearance.storageKey) private var appAppearanceRawValue = AppAppearance.system.rawValue

    // MARK: - State

    @State private var viewModel = SettingsViewModel()
    @State private var subscriptionManagementVM = SubscriptionManagementViewModel()
    @State private var showPaywall = false
    /// Story 10.5: Usage tracking for Settings display
    @State private var usageViewModel = UsageViewModel()
    @State private var showUsageDetail = false

    /// Story 8.3: Current notification preferences summary for subtitle display
    @State private var notificationFrequencySummary: String = ""
    @State private var currentUserId: UUID?
    /// Story 8.3: Refresh counter to trigger notification summary reload
    @State private var notificationRefreshId = 0

    /// Shared subscription state (Story 6.2)
    private var subscriptionViewModel: SubscriptionViewModel {
        AppEnvironment.shared.subscriptionViewModel
    }

    var body: some View {
        ZStack {
            // Warm background
            Color.adaptiveCream(colorScheme)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Appearance section
                    appearanceSection

                    // Coaching style section
                    coachingStyleSection

                    // Subscription Section (Story 6.4)
                    subscriptionSection

                    // Notifications Section (Story 8.3)
                    if let userId = currentUserId {
                        notificationsSection(userId: userId)
                    }

                    // Data Management Section
                    dataManagementSection

                    // Account Section
                    accountSection

                    // Security Tip (Story 6.5 — native biometric)
                    securityTipSection

                    // Legal / About Section (Story 4.3)
                    legalSection
                }
                .padding(16)
            }

            // Loading overlay during conversation deletion
            if viewModel.isDeleting {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(.white)
                            Text("Clearing your conversations...")
                                .font(.subheadline)
                                .foregroundStyle(.white)
                        }
                    }
                    .accessibilityLabel("Clearing all conversations")
            }

            // Loading overlay during account deletion (Story 6.6)
            if viewModel.isDeletingAccount {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(.white)
                            Text("Removing your account...")
                                .font(.subheadline)
                                .foregroundStyle(.white)
                        }
                    }
                    .accessibilityLabel("Removing your account")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .foregroundStyle(Color.adaptiveTerracotta(colorScheme))
            }
        }
        // Delete all confirmation alert (Task 5.4)
        .allConversationsDeleteAlert(isPresented: $viewModel.showDeleteAllConfirmation) {
            Task {
                let success = await viewModel.deleteAllConversations()
                if success {
                    dismiss()
                }
            }
        }
        // Sign out confirmation alert
        .alert("Sign out?", isPresented: $viewModel.showSignOutConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Sign out", role: .destructive) {
                Task {
                    let success = await viewModel.signOut()
                    if success {
                        dismiss()
                        router.navigateToWelcome()
                    }
                }
            }
        } message: {
            Text("You'll need to sign in again to continue coaching.")
        }
        // Delete account confirmation alert (Story 6.6)
        .alert("Delete your account?", isPresented: $viewModel.showDeleteAccountConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Account", role: .destructive) {
                Task {
                    let success = await viewModel.deleteAccount()
                    if success {
                        dismiss()
                        router.navigateToWelcome()
                    }
                }
            }
        } message: {
            Text("This will permanently remove your account, conversations, and everything I know about you. This can't be undone.")
        }
        // Paywall sheet (Story 6.2)
        .sheet(isPresented: $showPaywall) {
            PaywallView(subscriptionViewModel: subscriptionViewModel)
        }
        .task(id: notificationRefreshId) {
            await subscriptionViewModel.checkTrialStatus()
            // Story 10.5: Refresh usage data for Settings display
            await usageViewModel.refreshUsage()
            // Load user-selected coaching style preference
            await viewModel.loadCoachingStylePreference()
            // Story 8.3: Load user ID and notification preferences summary
            if let userId = await AuthService.shared.currentUserId {
                currentUserId = userId
                do {
                    let profile = try await ContextRepository.shared.fetchProfile(userId: userId)
                    if let prefs = profile.notificationPreferences,
                       prefs.checkInsEnabled {
                        notificationFrequencySummary = "Check-ins: \(prefs.frequency.displayName)"
                    } else {
                        notificationFrequencySummary = "Off"
                    }
                } catch {
                    #if DEBUG
                    print("SettingsView: Profile fetch failed — \(error.localizedDescription)")
                    #endif
                    notificationFrequencySummary = "Off"
                }
            }
        }
        .onAppear {
            // Story 8.3: Refresh notification summary when returning from preferences
            notificationRefreshId += 1
        }
        .preferredColorScheme(selectedAppearance.colorScheme)
        // Error alert
        .alert("Oops", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.error?.errorDescription ?? "Something went wrong")
        }
    }

    // MARK: - Sections

    /// Appearance section with app-wide theme mode selection
    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Appearance")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                .padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 10) {
                Picker("Appearance", selection: appearanceBinding) {
                    ForEach(AppAppearance.allCases) { mode in
                        Text(mode.shortLabel).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text("Choose White, Dark, or follow your device setting.")
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
            }
            .padding(16)
            .adaptiveGlass()
        }
    }

    /// Coaching style section with explicit user override controls
    private var coachingStyleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Coaching Style")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(SettingsViewModel.CoachingStyleOption.allCases) { option in
                    Button {
                        Task {
                            await viewModel.setCoachingStyle(option)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.displayName)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(Color.adaptiveText(colorScheme))

                                Text(option.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                                    .multilineTextAlignment(.leading)
                            }

                            Spacer(minLength: 8)

                            if viewModel.selectedCoachingStyle == option {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(Color.adaptiveTerracotta(colorScheme))
                            } else {
                                Image(systemName: "circle")
                                    .font(.system(size: 18, weight: .regular))
                                    .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                            }
                        }
                        .padding(16)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if option != SettingsViewModel.CoachingStyleOption.allCases.last {
                        Divider()
                            .padding(.horizontal, 16)
                    }
                }
            }
            .adaptiveGlass()

            if viewModel.isSavingCoachingStyle {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Saving style preference...")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                }
                .padding(.horizontal, 4)
            }
        }
    }

    /// Data management section with clear all conversations option
    private var dataManagementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            Text("Data")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                .padding(.horizontal, 4)

            // Clear all conversations row (Task 5.2)
            VStack(spacing: 0) {
                Button {
                    viewModel.showDeleteAllConfirmation = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Image(systemName: "trash")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Color.red)

                                Text("Clear all conversations")
                                    .font(.body)
                                    .foregroundStyle(Color.adaptiveText(colorScheme))
                            }

                            Text("This will remove all your conversation history")
                                .font(.caption)
                                .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                    }
                    .padding(16)
                }
                .accessibilityLabel("Clear all conversations")
                .accessibilityHint("Tap to remove all your conversation history")
            }
            .adaptiveGlass()  // Task 5.6
        }
    }

    /// Account section with sign out and delete account options
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Account")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                // Sign Out row
                Button {
                    viewModel.showSignOutConfirmation = true
                } label: {
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color.red)

                            Text("Sign out")
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
                .accessibilityLabel("Sign out")
                .accessibilityHint("Signs you out of your account")

                Divider()
                    .padding(.horizontal, 16)

                // Delete Account row (Story 6.6)
                Button {
                    viewModel.showDeleteAccountConfirmation = true
                } label: {
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "trash")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color.red)

                            Text("Delete Account")
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
                .accessibilityLabel("Delete account")
                .accessibilityHint("Permanently deletes your account and all data")
            }
            .adaptiveGlass()
        }
    }

    /// Subscription section with inline plan status, manage action, and restore (Story 6.4)
    private var subscriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Subscription")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                // Current plan status
                HStack {
                    Image(systemName: subscriptionManagementVM.subscriptionState.systemImageName)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(subscriptionManagementVM.subscriptionState.statusColor)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(subscriptionManagementVM.planName ?? "Free Plan")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.adaptiveText(colorScheme))

                            Text(subscriptionManagementVM.subscriptionState.displayLabel)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(subscriptionManagementVM.subscriptionState.statusColor)
                                .clipShape(Capsule())
                        }

                        if subscriptionManagementVM.expirationDate != nil {
                            Text(subscriptionManagementVM.willRenew
                                 ? "Renews \(subscriptionManagementVM.formattedExpirationDate)"
                                 : "Expires \(subscriptionManagementVM.formattedExpirationDate)")
                                .font(.caption)
                                .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                        }
                    }

                    Spacer()
                }
                .padding(16)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Plan: \(subscriptionManagementVM.planName ?? "Free"). Status: \(subscriptionManagementVM.subscriptionState.displayLabel)")

                Divider()
                    .padding(.horizontal, 16)

                // Manage or Subscribe — conditional on subscription state
                if subscriptionManagementVM.subscriptionState == .free || subscriptionManagementVM.subscriptionState == .expired {
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
                } else {
                    Button {
                        Task { await subscriptionManagementVM.openManageSubscriptions() }
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

                // Story 10.5: Usage row — always visible in Settings
                if let usage = usageViewModel.currentUsage {
                    Divider()
                        .padding(.horizontal, 16)

                    Button { showUsageDetail = true } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Image(systemName: "chart.bar")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(Color.adaptiveTerracotta(colorScheme))
                                    Text("Usage")
                                        .font(.body)
                                        .foregroundStyle(Color.adaptiveText(colorScheme))
                                }
                                Text("\(usage.messageCount) of \(usage.limit) messages used")
                                    .font(.caption)
                                    .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                            }
                            Spacer()

                            // Compact progress indicator
                            usageProgressRing(percentage: usage.usagePercentage)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                        }
                        .padding(16)
                    }
                    .accessibilityLabel("Usage: \(usage.messageCount) of \(usage.limit) messages used")
                    .accessibilityHint("Tap for usage details")
                }

                Divider()
                    .padding(.horizontal, 16)

                // Restore Purchases
                Button {
                    Task { await subscriptionManagementVM.restorePurchases() }
                } label: {
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color.adaptiveTerracotta(colorScheme))
                            Text("Restore Purchases")
                                .font(.body)
                                .foregroundStyle(Color.adaptiveText(colorScheme))
                        }
                        Spacer()
                    }
                    .padding(16)
                }
                .accessibilityLabel("Restore Purchases")
                .accessibilityHint("Check for and restore a previous subscription")
            }
            .adaptiveGlass()
        }
        .task {
            await subscriptionManagementVM.refreshSubscriptionInfo()
            subscriptionManagementVM.startListening()
        }
        .onDisappear {
            subscriptionManagementVM.stopListening()
        }
        // Story 10.5: Usage detail sheet from Settings
        .sheet(isPresented: $showUsageDetail) {
            UsageDetailSheet(viewModel: usageViewModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .alert("Subscription", isPresented: .init(
            get: { subscriptionManagementVM.error != nil },
            set: { if !$0 { subscriptionManagementVM.error = nil } }
        )) {
            Button("OK", role: .cancel) { subscriptionManagementVM.error = nil }
        } message: {
            Text(subscriptionManagementVM.error?.errorDescription ?? "")
        }
    }

    /// Story 10.5: Compact circular progress ring for Settings usage row
    private func usageProgressRing(percentage: Double) -> some View {
        ZStack {
            Circle()
                .stroke(Color.adaptiveText(colorScheme, isPrimary: false).opacity(0.15), lineWidth: 3)
            Circle()
                .trim(from: 0, to: percentage)
                .stroke(progressColor(percentage: percentage), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 24, height: 24)
        .padding(.trailing, 4)
        .accessibilityHidden(true)
    }

    private func progressColor(percentage: Double) -> Color {
        switch percentage {
        case ..<0.80: return .green
        case 0.80..<0.95: return .terracotta
        default: return .orange
        }
    }

    /// Notifications section with link to notification preferences (Story 8.3)
    private func notificationsSection(userId: UUID) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notifications")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                NavigationLink {
                    NotificationPreferencesView(userId: userId)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Image(systemName: "bell")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Color.adaptiveTerracotta(colorScheme))

                                Text("Notification Preferences")
                                    .font(.body)
                                    .foregroundStyle(Color.adaptiveText(colorScheme))
                            }

                            if !notificationFrequencySummary.isEmpty {
                                Text(notificationFrequencySummary)
                                    .font(.caption)
                                    .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                    }
                    .padding(16)
                }
                .accessibilityLabel("Notification Preferences")
                .accessibilityHint("Manage your check-in notification settings")
            }
            .adaptiveGlass()
        }
    }

    /// Security tip pointing users to native iOS app lock (Story 6.5)
    private var securityTipSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Security")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                .padding(.horizontal, 4)

            HStack(spacing: 12) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.adaptiveTerracotta(colorScheme))
                    .accessibilityHidden(true)

                Text("To lock Coach App, long-press the app icon and tap Require Face ID.")
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
            }
            .padding(16)
            .adaptiveGlass()
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Security tip: To lock Coach App, long-press the app icon and tap Require Face ID.")
        }
    }

    /// Legal / About section with coaching disclaimer and links (Story 4.3)
    private var legalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                // Coaching disclaimer text
                HStack {
                    Text("AI coaching, not therapy or mental health treatment")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                    Spacer()
                }
                .padding(16)
                .accessibilityLabel("AI coaching, not therapy or mental health treatment")

                Divider()
                    .padding(.horizontal, 16)

                // Terms of Service link
                Link(destination: AppURLs.termsOfService) {
                    HStack {
                        Text("Terms of Service")
                            .font(.body)
                            .foregroundStyle(Color.adaptiveTerracotta(colorScheme))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                    }
                    .padding(16)
                }
                .accessibilityLabel("Terms of Service")
                .accessibilityHint("Opens the terms of service in Safari")

                Divider()
                    .padding(.horizontal, 16)

                // Privacy Policy link
                Link(destination: AppURLs.privacyPolicy) {
                    HStack {
                        Text("Privacy Policy")
                            .font(.body)
                            .foregroundStyle(Color.adaptiveTerracotta(colorScheme))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                    }
                    .padding(16)
                }
                .accessibilityLabel("Privacy Policy")
                .accessibilityHint("Opens the privacy policy in Safari")
            }
            .adaptiveGlass()
        }
    }

    private var selectedAppearance: AppAppearance {
        appearanceBinding.wrappedValue
    }

    private var appearanceBinding: Binding<AppAppearance> {
        Binding(
            get: {
                AppAppearance(rawValue: appAppearanceRawValue) ?? .system
            },
            set: { newValue in
                appAppearanceRawValue = newValue.rawValue
            }
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SettingsView()
    }
}
