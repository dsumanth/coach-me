//
//  StreamingText.swift
//  CoachMe
//
//  Created by Dev Agent on 2/6/26.
//
//  Story 2.4: Updated to detect and highlight memory moments during streaming
//

import SwiftUI

/// View that renders streaming text with smooth buffered display
/// Per UX spec: 50-100ms buffer for coaching-paced rendering
/// Story 2.4: Detects and highlights memory moments in real-time
struct StreamingText: View {
    /// The accumulated text to display
    let text: String

    /// Whether the stream is still active
    let isStreaming: Bool

    /// Blinking cursor opacity (animated)
    @State private var cursorOpacity: Double = 1.0

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .bottom, spacing: 0) {
                // Story 2.4: Parse and display text with memory moments stripped
                Text(parsedResult.cleanText)
                    .font(.body)
                    .foregroundColor(Color.adaptiveText(colorScheme))
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

            // Story 2.4: Show memory moments with visual treatment
            if parsedResult.hasMemoryMoments {
                memoryMomentsSection
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

    // MARK: - Memory Moment Detection

    /// Parsed result with clean text and detected memory moments
    private var parsedResult: MemoryParseResult {
        MemoryMomentParser.parse(text)
    }

    /// Visual section showing detected memory moments
    @ViewBuilder
    private var memoryMomentsSection: some View {
        FlowLayout(spacing: 6) {
            ForEach(parsedResult.moments) { moment in
                MemoryMomentText(content: moment.content)
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .animation(.easeInOut(duration: 0.2), value: parsedResult.moments.count)
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

#Preview("Basic Streaming") {
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

#Preview("With Memory Moments") {
    ZStack {
        Color.cream.ignoresSafeArea()

        VStack(alignment: .leading, spacing: 20) {
            Text("Streaming with memory moment:")
                .font(.caption)
                .foregroundStyle(Color.warmGray500)

            StreamingText(
                text: "Given that you value [MEMORY: honesty and authenticity], how does this situation align with that?",
                isStreaming: true
            )

            Divider()

            Text("Completed with multiple moments:")
                .font(.caption)
                .foregroundStyle(Color.warmGray500)

            StreamingText(
                text: "I remember you mentioned [MEMORY: navigating a career transition]. Thinking about your goal of [MEMORY: becoming a better leader], what would that version of you do here?",
                isStreaming: false
            )
        }
        .padding()
    }
}
