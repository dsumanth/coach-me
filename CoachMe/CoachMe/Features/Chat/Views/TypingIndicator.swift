//
//  TypingIndicator.swift
//  CoachMe
//
//  Created by Sumanth Daggubati on 2/6/26.
//

import SwiftUI

/// Animated typing indicator shown while coach is responding
struct TypingIndicator: View {
    /// Current animation phase (0, 1, or 2)
    @State private var animationPhase = 0

    /// Timer for animation
    @State private var animationTimer: Timer?

    /// Animation interval in seconds
    private static let animationInterval: TimeInterval = 0.4

    var body: some View {
        HStack {
            // Left-aligned like assistant messages
            indicatorBubble

            Spacer(minLength: 60)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .onAppear {
            startAnimation()
        }
        .onDisappear {
            stopAnimation()
        }
        .accessibilityLabel("Coach is typing")
        .accessibilityAddTraits(.updatesFrequently)
    }

    // MARK: - Subviews

    /// The animated dots bubble
    private var indicatorBubble: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.warmGray400)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animationPhase == index ? 1.2 : 1.0)
                    .opacity(animationPhase == index ? 1.0 : 0.5)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.warmGray100)
        .clipShape(TypingIndicatorShape())
    }

    // MARK: - Animation

    /// Starts the typing animation using async/await pattern to avoid retain cycles
    private func startAnimation() {
        Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(Self.animationInterval * 1_000_000_000))
                guard !Task.isCancelled else { break }
                withAnimation(.easeInOut(duration: 0.2)) {
                    animationPhase = (animationPhase + 1) % 3
                }
            }
        }
    }

    /// Stops the typing animation
    private func stopAnimation() {
        // Timer cleanup no longer needed with Task-based animation
        animationTimer?.invalidate()
        animationTimer = nil
    }
}

// MARK: - Typing Indicator Shape

/// Custom shape for the typing indicator bubble (matches assistant message style)
struct TypingIndicatorShape: Shape {
    func path(in rect: CGRect) -> Path {
        let cornerRadius: CGFloat = 20
        let flatCornerRadius: CGFloat = 4

        var path = Path()
        // Same shape as assistant message: flat bottom-left corner
        path.addRoundedRect(
            in: rect,
            cornerRadii: RectangleCornerRadii(
                topLeading: cornerRadius,
                bottomLeading: flatCornerRadius,
                bottomTrailing: cornerRadius,
                topTrailing: cornerRadius
            )
        )
        return path
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.cream.ignoresSafeArea()

        VStack {
            // Sample message followed by typing indicator
            MessageBubble(message: ChatMessage.userMessage(
                content: "What should I focus on today?",
                conversationId: UUID()
            ))

            TypingIndicator()

            Spacer()
        }
        .padding(.top, 20)
    }
}
