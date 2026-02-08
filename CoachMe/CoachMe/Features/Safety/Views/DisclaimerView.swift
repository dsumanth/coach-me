//
//  DisclaimerView.swift
//  CoachMe
//
//  Created by Dev Agent on 2/8/26.
//
//  Story 4.3: Reusable coaching disclaimer component

import SwiftUI

/// Shared legal URLs referenced by WelcomeView, SettingsView, and DisclaimerView
enum AppURLs {
    static let termsOfService = URL(string: "https://coachme.app/terms")!
    static let privacyPolicy = URL(string: "https://coachme.app/privacy")!
}

/// Reusable coaching disclaimer component per FR19
/// Displays "AI coaching, not therapy" text with optional Terms of Service link
struct DisclaimerView: View {
    @Environment(\.colorScheme) private var colorScheme

    /// Whether to show the Terms of Service link below the disclaimer text
    var showTermsLink: Bool = true

    var body: some View {
        VStack(spacing: 8) {
            Text("AI coaching, not therapy or mental health treatment")
                .font(.caption)
                .foregroundColor(Color.adaptiveText(colorScheme, isPrimary: false).opacity(0.88))
                .multilineTextAlignment(.center)
                .accessibilityLabel("AI coaching, not therapy or mental health treatment")

            if showTermsLink {
                Link(destination: AppURLs.termsOfService) {
                    Text("View Terms of Service")
                        .font(.caption)
                        .foregroundColor(Color.terracotta)
                }
                .accessibilityLabel("View Terms of Service")
                .accessibilityHint("Opens the terms of service in Safari")
            }
        }
    }
}

// MARK: - Preview

#Preview("With link") {
    DisclaimerView()
        .padding()
}

#Preview("Without link") {
    DisclaimerView(showTermsLink: false)
        .padding()
}
