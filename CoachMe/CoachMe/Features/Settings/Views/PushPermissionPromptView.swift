//
//  PushPermissionPromptView.swift
//  CoachMe
//
//  Story 8.3: Push Permission Timing & Notification Preferences
//  Post-session prompt asking user to opt in to check-in notifications.
//

import SwiftUI

/// Warm, explanatory prompt shown after the user's first coaching session.
/// Asks if they'd like check-in notifications between sessions.
struct PushPermissionPromptView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    /// Called when user taps "Sure, check in with me"
    var onAccept: () -> Void

    /// Called when user taps "Not now"
    var onDecline: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: "bell.badge")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Color.adaptiveTerracotta(colorScheme))
                .accessibilityHidden(true)

            // Title
            Text("Stay connected between sessions")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .multilineTextAlignment(.center)

            // Warm copy (AC #2)
            Text("I'd love to check in between our sessions — a quick nudge to see how things are going. You can always adjust this later.")
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 12) {
                // Primary: Accept
                Button {
                    onAccept()
                    dismiss()
                } label: {
                    Text("Sure, check in with me")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            Capsule()
                                .fill(Color.adaptiveTerracotta(colorScheme))
                        )
                }
                .accessibilityLabel("Enable check-in notifications")
                .accessibilityHint("Allows the app to send gentle check-in reminders between sessions")

                // Secondary: Decline
                Button {
                    onDecline()
                    dismiss()
                } label: {
                    Text("Not now")
                        .font(.body)
                        .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .accessibilityLabel("Skip notifications for now")
                .accessibilityHint("Dismisses this prompt. You can enable notifications later in Settings.")
            }
        }
        .padding(24)
        .adaptiveGlass()
        .padding(.horizontal, 16)
    }
}
