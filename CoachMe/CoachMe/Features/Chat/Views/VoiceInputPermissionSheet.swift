//
//  VoiceInputPermissionSheet.swift
//  CoachMe
//
//  Created by Dev Agent on 2/6/26.
//

import SwiftUI

/// Permission explanation sheet for voice input
/// Per UX spec: Warm permission explanation before system dialog
struct VoiceInputPermissionSheet: View {
    /// Callback when user taps enable
    var onEnable: () -> Void

    /// Callback when user dismisses
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color.terracotta)

            // Title
            Text("Voice Input")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(Color.warmGray800)

            // Description - warm first-person voice
            Text("I'd love to hear your voice. Enable the microphone so you can speak your thoughts instead of typing.")
                .font(.body)
                .foregroundStyle(Color.warmGray600)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer()

            // Buttons
            VStack(spacing: 12) {
                Button(action: onEnable) {
                    Text("Enable Microphone")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.terracotta)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .accessibilityLabel("Enable microphone access")
                .accessibilityHint("Grants permission to use voice input")

                Button(action: onDismiss) {
                    Text("Not Now")
                        .font(.body)
                        .foregroundStyle(Color.warmGray600)
                }
                .accessibilityLabel("Dismiss")
                .accessibilityHint("Continue without voice input")
            }
            .padding(.horizontal, 24)
        }
        .padding(.vertical, 32)
        .background(Color.cream)
    }
}

// MARK: - Preview

#Preview {
    VoiceInputPermissionSheet(
        onEnable: { print("Enable tapped") },
        onDismiss: { print("Dismiss tapped") }
    )
}
