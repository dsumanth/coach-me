//
//  StreamingText.swift
//  CoachMe
//
//  Created by Dev Agent on 2/6/26.
//

import SwiftUI

/// View that renders streaming text with smooth buffered display
/// Per UX spec: 50-100ms buffer for coaching-paced rendering
struct StreamingText: View {
    /// The accumulated text to display
    let text: String

    /// Whether the stream is still active
    let isStreaming: Bool

    /// Blinking cursor opacity (animated)
    @State private var cursorOpacity: Double = 1.0

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Text(text)
                .font(.body)
                .foregroundColor(.warmGray800)
                .multilineTextAlignment(.leading)
                .animation(.easeInOut(duration: 0.1), value: text)

            if isStreaming {
                Text("▌")
                    .font(.body)
                    .foregroundColor(.warmGray400)
                    .opacity(cursorOpacity)
                    .onAppear {
                        startCursorAnimation()
                    }
                    .onDisappear {
                        stopCursorAnimation()
                    }
            }
        }
        .onChange(of: isStreaming) { _, newValue in
            if newValue {
                startCursorAnimation()
            } else {
                stopCursorAnimation()
            }
        }
    }

    // MARK: - Private Methods

    private func startCursorAnimation() {
        // Reset to full opacity before starting animation
        cursorOpacity = 1.0
        withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
            cursorOpacity = 0.3
        }
    }

    private func stopCursorAnimation() {
        // Reset animation state cleanly
        withAnimation(.linear(duration: 0.1)) {
            cursorOpacity = 1.0
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.cream.ignoresSafeArea()

        VStack(alignment: .leading, spacing: 20) {
            StreamingText(
                text: "I hear you. Feeling stuck is completely normal...",
                isStreaming: true
            )

            StreamingText(
                text: "This is a completed message that is no longer streaming.",
                isStreaming: false
            )
        }
        .padding()
    }
}
