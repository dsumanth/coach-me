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
    @State private var hasTriggeredPress = false

    /// Tracks if we initiated recording (to know when to call onRelease)
    @State private var didStartRecording = false

    /// Task for delayed press activation - cancelled if user releases early
    @State private var pressTask: Task<Void, Never>?

    /// Minimum press duration before starting recording (in seconds)
    private static let minimumPressDuration: TimeInterval = 0.15

    var body: some View {
        Button(action: {}) {
            Image(systemName: isRecording ? "waveform" : "waveform")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(buttonColor)
                .symbolEffect(.variableColor.iterative, isActive: isRecording)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    // Only trigger press sequence once per gesture
                    if !hasTriggeredPress && !isRecording && !isDisabled {
                        hasTriggeredPress = true
                        pressTask = Task {
                            try? await Task.sleep(for: .seconds(Self.minimumPressDuration))
                            guard !Task.isCancelled else { return }
                            await MainActor.run {
                                didStartRecording = true
                                onPress()
                            }
                        }
                    }
                }
                .onEnded { _ in
                    hasTriggeredPress = false
                    pressTask?.cancel()
                    pressTask = nil
                    // Call onRelease if we initiated recording
                    if didStartRecording {
                        didStartRecording = false
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
            return Color(.systemGray4)
        }
        return isRecording ? .red : Color(.systemGray)
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
