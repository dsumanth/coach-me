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

    var body: some View {
        ZStack {
            // Warm background
            Color.adaptiveCream(colorScheme)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Appearance section
                    appearanceSection

                    // Data Management Section
                    dataManagementSection

                    // Account Section
                    accountSection

                    // Legal / About Section (Story 4.3)
                    legalSection
                }
                .padding(16)
            }

            // Loading overlay during deletion
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

    /// Account section with sign out option
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Account")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
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
            }
            .adaptiveGlass()
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
