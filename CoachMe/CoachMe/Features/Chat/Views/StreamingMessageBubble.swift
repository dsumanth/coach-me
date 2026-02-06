//
//  StreamingMessageBubble.swift
//  CoachMe
//
//  Created by Dev Agent on 2/6/26.
//

import SwiftUI

/// Message bubble variant for streaming content
/// Per UX spec: Shows streaming text with retry on failure
struct StreamingMessageBubble: View {
    /// The streaming content
    let content: String

    /// Whether still actively streaming
    let isStreaming: Bool

    /// Callback for retry action
    var onRetry: (() -> Void)?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                if content.isEmpty && isStreaming {
                    // Show minimal placeholder while waiting for first token
                    Text("")
                        .font(.body)
                        .frame(minHeight: 20)
                } else {
                    StreamingText(text: content, isStreaming: isStreaming)
                }

                // Show retry button when stream failed with partial content
                if !isStreaming && !content.isEmpty && onRetry != nil {
                    retryButton
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.warmGray100)
            .clipShape(AssistantBubbleShape())

            Spacer(minLength: 60)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(content.isEmpty ? "Coach is typing" : content)
        .accessibilityHint(isStreaming ? "Response is still being generated" : (onRetry != nil ? "Tap retry to resend message" : "Coach's response"))
    }

    // MARK: - Retry Button

    private var retryButton: some View {
        Button(action: { onRetry?() }) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
                Text("Retry")
                    .font(.caption)
            }
            .foregroundColor(.terracotta)
        }
        .accessibilityLabel("Retry sending message")
    }
}

// MARK: - Assistant Bubble Shape

/// Shape for assistant message bubbles (flat bottom-left corner)
/// Per design: Matches MessageBubbleShape for non-user messages
struct AssistantBubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRoundedRect(
            in: rect,
            cornerRadii: RectangleCornerRadii(
                topLeading: 20,
                bottomLeading: 4,
                bottomTrailing: 20,
                topTrailing: 20
            )
        )
        return path
    }
}

// MARK: - Preview

#Preview("Streaming") {
    ZStack {
        Color.cream.ignoresSafeArea()

        VStack(spacing: 16) {
            StreamingMessageBubble(
                content: "I hear you. Feeling stuck is completely normal...",
                isStreaming: true
            )

            StreamingMessageBubble(
                content: "This is partial content that failed.",
                isStreaming: false,
                onRetry: { print("Retry tapped") }
            )

            StreamingMessageBubble(
                content: "",
                isStreaming: true
            )
        }
    }
}
