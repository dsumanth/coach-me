//
//  RecordingIndicator.swift
//  CoachMe
//
//  Created by Dev Agent on 2/6/26.
//

import SwiftUI

/// Animated recording indicator with pulsing dot
/// Per UX spec: Visual feedback during voice recording
struct RecordingIndicator: View {
    /// Whether recording is active
    let isRecording: Bool

    /// Pulsing animation state
    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 8) {
            // Pulsing red dot
            Circle()
                .fill(Color.terracotta)
                .frame(width: 12, height: 12)
                .scaleEffect(isPulsing ? 1.2 : 1.0)
                .opacity(isPulsing ? 0.7 : 1.0)

            Text("Recording...")
                .font(.caption)
                .foregroundStyle(Color.warmGray600)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .adaptiveInteractiveGlass()
        // Use task(id:) to handle animation state changes reliably
        // This avoids the race condition between view creation and onAppear
        // When isRecording changes, the previous task is cancelled and a new one starts
        .task(id: isRecording) {
            if isRecording {
                startAnimation()
            } else {
                stopAnimation()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Recording in progress")
    }

    private func startAnimation() {
        withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
            isPulsing = true
        }
    }

    private func stopAnimation() {
        withAnimation(.linear(duration: 0.1)) {
            isPulsing = false
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        RecordingIndicator(isRecording: true)
        RecordingIndicator(isRecording: false)
    }
    .padding()
    .background(Color.cream)
}
