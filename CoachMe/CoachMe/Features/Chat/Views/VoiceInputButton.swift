//
//  VoiceInputButton.swift
//  CoachMe
//
//  Created by Dev Agent on 2/6/26.
//

import SwiftUI

/// Microphone button for voice input
/// Per architecture.md: Use .adaptiveInteractiveGlass() styling
struct VoiceInputButton: View {
    /// Whether currently recording
    let isRecording: Bool

    /// Whether button is disabled
    let isDisabled: Bool

    /// Action when pressed
    var onPress: () -> Void

    /// Action when released
    var onRelease: () -> Void

    /// Internal state to prevent multiple onPress calls during gesture
    /// Fix for code review H1: DragGesture.onChanged fires repeatedly
    @State private var hasTriggeredPress = false

    var body: some View {
        Button(action: {}) {
            Image(systemName: isRecording ? "mic.fill" : "mic")
                .font(.system(size: 20))
                .foregroundStyle(buttonColor)
                .frame(width: 44, height: 44)
        }
        .adaptiveInteractiveGlass()
        .disabled(isDisabled)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    // Only trigger onPress once per gesture (fix for H1)
                    if !hasTriggeredPress && !isRecording && !isDisabled {
                        hasTriggeredPress = true
                        onPress()
                    }
                }
                .onEnded { _ in
                    // Reset press state for next gesture
                    hasTriggeredPress = false
                    if isRecording {
                        onRelease()
                    }
                }
        )
        .sensoryFeedback(.impact(weight: .medium), trigger: isRecording)
        .accessibilityLabel(isRecording ? "Stop recording" : "Voice input")
        .accessibilityHint(isRecording ? "Release to stop recording" : "Press and hold to record your message")
        .accessibilityAddTraits(isRecording ? .isSelected : [])
    }

    private var buttonColor: Color {
        if isDisabled {
            return .warmGray300
        }
        return isRecording ? .terracotta : .warmGray600
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 16) {
        VoiceInputButton(
            isRecording: false,
            isDisabled: false,
            onPress: { print("Press") },
            onRelease: { print("Release") }
        )

        VoiceInputButton(
            isRecording: true,
            isDisabled: false,
            onPress: { print("Press") },
            onRelease: { print("Release") }
        )

        VoiceInputButton(
            isRecording: false,
            isDisabled: true,
            onPress: { print("Press") },
            onRelease: { print("Release") }
        )
    }
    .padding()
    .background(Color.cream)
}
