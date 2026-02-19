//
//  OnboardingWelcomeView.swift
//  CoachMe
//
//  Story 11.3 — Task 1: Warm welcome screen for new users
//

import SwiftUI

/// Single welcome screen shown to brand-new users after sign-in.
/// Communicates warmth and safety before entering the discovery conversation.
struct OnboardingWelcomeView: View {
    /// Called when the user taps "Let's begin"
    var onBegin: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isVisible = false

    var body: some View {
        ZStack {
            Color.adaptiveCream(colorScheme)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // App icon
                Image(systemName: "bubble.left.and.text.bubble.right.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.terracotta)
                    .accessibilityHidden(true)

                // Warm messaging
                VStack(spacing: 12) {
                    Text("This is your space.")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .multilineTextAlignment(.center)

                    Text("No judgment, no forms.\nJust a conversation.")
                        .font(.system(size: 18, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("This is your space. No judgment, no forms. Just a conversation.")

                Spacer()

                // "Let's begin" CTA
                Button {
                    onBegin()
                } label: {
                    Text("Let's begin")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            Capsule()
                                .fill(Color.terracotta)
                        )
                }
                .padding(.horizontal, 32)
                .accessibilityLabel("Let's begin")
                .accessibilityHint("Starts a conversation with your coach")

                Spacer()
                    .frame(height: 48)
            }
            .opacity(isVisible ? 1 : 0)
        }
        .onAppear {
            // Subtle fade-in entrance animation (matches welcomeTransition pattern)
            withAnimation(.easeOut(duration: 0.5)) {
                isVisible = true
            }
        }
    }
}

#Preview {
    OnboardingWelcomeView(onBegin: {})
}
