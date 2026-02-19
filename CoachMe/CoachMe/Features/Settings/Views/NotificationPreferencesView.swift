//
//  NotificationPreferencesView.swift
//  CoachMe
//
//  Story 8.3: Push Permission Timing & Notification Preferences
//  Settings screen for managing check-in notification preferences.
//

import SwiftUI

/// Notification preferences settings screen.
/// Allows users to enable/disable check-ins and choose frequency.
struct NotificationPreferencesView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = NotificationPreferencesViewModel()

    let userId: UUID

    var body: some View {
        ZStack {
            Color.adaptiveCream(colorScheme)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Description
                    descriptionSection

                    // Toggle and frequency
                    preferencesSection

                    // System permission warning
                    if viewModel.isSystemPermissionDenied {
                        systemPermissionSection
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Notification Preferences")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load(userId: userId)
        }
        .onDisappear {
            Task { await viewModel.save() }
        }
        .alert("Oops", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.error?.errorDescription ?? "Something went wrong")
        }
    }

    // MARK: - Sections

    /// Warm description explaining what check-ins are (6.4)
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Check-in notifications")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                .padding(.horizontal, 4)

            HStack(spacing: 12) {
                Image(systemName: "bell.badge")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.adaptiveTerracotta(colorScheme))
                    .accessibilityHidden(true)

                Text("Check-ins are gentle nudges between sessions to see how you're doing. They help keep your coaching momentum going.")
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
            }
            .padding(16)
            .adaptiveGlass()
        }
    }

    /// Toggle and frequency picker (6.2, 6.3)
    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preferences")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                // Toggle: Check-in notifications on/off (6.2)
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "bell")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.adaptiveTerracotta(colorScheme))

                        Text("Check-in notifications")
                            .font(.body)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                    }

                    Spacer()

                    Toggle("", isOn: $viewModel.checkInsEnabled)
                        .labelsHidden()
                        .tint(Color.adaptiveTerracotta(colorScheme))
                }
                .padding(16)
                .accessibilityLabel("Check-in notifications")
                .accessibilityHint("Toggle to enable or disable check-in notifications between sessions")

                // Frequency picker — only visible when enabled (6.3)
                if viewModel.checkInsEnabled {
                    Divider()
                        .padding(.horizontal, 16)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("How often?")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.adaptiveText(colorScheme))

                        Picker("Frequency", selection: $viewModel.frequency) {
                            ForEach(NotificationPreference.CheckInFrequency.allCases, id: \.self) { freq in
                                Text(freq.displayName).tag(freq)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityLabel("Check-in frequency")
                        .accessibilityHint("Choose how often you'd like check-in notifications")
                    }
                    .padding(16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .adaptiveGlass()
            .animation(.easeInOut(duration: 0.2), value: viewModel.checkInsEnabled)
        }
    }

    /// System permission denied warning with link to iOS Settings (6.5)
    private var systemPermissionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("System Permission")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                .padding(.horizontal, 4)

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.orange)
                        .accessibilityHidden(true)

                    Text("Notifications are turned off in your device settings. Tap below to enable them.")
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                }

                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack {
                        Image(systemName: "gear")
                            .font(.system(size: 14, weight: .medium))
                        Text("Open Settings")
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundStyle(Color.adaptiveTerracotta(colorScheme))
                }
                .accessibilityLabel("Open device notification settings")
                .accessibilityHint("Opens iOS Settings to enable notifications for Coach App")
            }
            .padding(16)
            .adaptiveGlass()
        }
    }
}
