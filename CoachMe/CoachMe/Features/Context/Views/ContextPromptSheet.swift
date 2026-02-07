//
//  ContextPromptSheet.swift
//  CoachMe
//
//  Story 2.2: Context Setup Prompt After First Session
//  Per architecture.md: Use adaptive design modifiers, VoiceOver accessibility
//  Per UX-8: "Want me to remember what matters to you?"
//

import SwiftUI

/// Sheet that asks users if they want the coach to remember their context
/// Displayed after the first AI response in a coaching session
/// Per UX-8: Warm, inviting tone that feels like a natural pause
struct ContextPromptSheet: View {
    // MARK: - Actions

    /// Called when user taps "Yes, remember me"
    let onAccept: () -> Void

    /// Called when user taps "Not now"
    let onDismiss: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: DesignConstants.Spacing.lg) {
            // Header illustration (optional - warm visual)
            Image(systemName: "heart.text.clipboard")
                .font(.system(size: 56))
                .foregroundStyle(Color.terracotta)
                .padding(.top, DesignConstants.Spacing.md)
                .accessibilityHidden(true)

            // Main prompt - per UX-8
            Text("Want me to remember what matters to you?")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            // Supporting text - warm, first-person
            Text("I can give you better coaching when I know what's important to you.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignConstants.Spacing.md)

            // Action buttons
            VStack(spacing: DesignConstants.Spacing.sm) {
                // Primary action - "Yes, remember me"
                Button {
                    onAccept()
                } label: {
                    Text("Yes, remember me")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: DesignConstants.Size.buttonLarge)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.terracotta)
                .adaptiveInteractiveGlass()
                .accessibilityLabel("Yes, remember me")
                .accessibilityHint("Continues to set up your personal context profile")

                // Secondary action - "Not now"
                Button {
                    onDismiss()
                } label: {
                    Text("Not now")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Not now")
                .accessibilityHint("Dismisses this prompt. You'll be asked again after a few more sessions.")
            }
            .padding(.top, DesignConstants.Spacing.sm)
        }
        .padding(.horizontal, DesignConstants.Spacing.xl)
        .padding(.vertical, DesignConstants.Spacing.lg)
        .frame(maxWidth: .infinity)
        .adaptiveGlassSheet()
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityLabel("Context setup prompt")
    }
}

// MARK: - Preview

#Preview("ContextPromptSheet") {
    ContextPromptSheet(
        onAccept: { print("Accepted") },
        onDismiss: { print("Dismissed") }
    )
}

#Preview("ContextPromptSheet - Dark") {
    ContextPromptSheet(
        onAccept: { print("Accepted") },
        onDismiss: { print("Dismissed") }
    )
    .preferredColorScheme(.dark)
}
