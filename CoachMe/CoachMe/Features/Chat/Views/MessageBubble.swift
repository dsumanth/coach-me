//
//  MessageBubble.swift
//  CoachMe
//
//  Created by Sumanth Daggubati on 2/6/26.
//

import SwiftUI

/// Chat bubble for user and assistant messages
/// Per architecture.md: NO glass on content — same styling on both iOS tiers
struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .foregroundColor(textColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(bubbleBackground)
                    .clipShape(bubbleShape)

                // Timestamp
                Text(message.formattedTime)
                    .font(.caption2)
                    .foregroundColor(Color.warmGray600)
            }

            if !message.isFromUser {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(message.isFromUser ? "You" : "Coach"): \(message.content)")
        .accessibilityHint("Sent at \(message.formattedTime)")
    }

    // MARK: - Styling

    /// Background color based on message sender
    private var bubbleBackground: Color {
        message.isFromUser ? Color.terracotta : Color.warmGray100
    }

    /// Text color based on message sender
    private var textColor: Color {
        message.isFromUser ? .white : Color.warmGray900
    }

    /// Custom bubble shape with asymmetric corners
    private var bubbleShape: some Shape {
        MessageBubbleShape(isFromUser: message.isFromUser)
    }
}

// MARK: - Custom Bubble Shape

/// Custom shape for chat bubbles with asymmetric corner radius
/// User messages: flat bottom-right corner
/// Assistant messages: flat bottom-left corner
struct MessageBubbleShape: Shape {
    let isFromUser: Bool

    func path(in rect: CGRect) -> Path {
        let cornerRadius: CGFloat = 20
        let flatCornerRadius: CGFloat = 4

        var path = Path()

        if isFromUser {
            // User message: flat bottom-right corner
            path.addRoundedRect(
                in: rect,
                cornerRadii: RectangleCornerRadii(
                    topLeading: cornerRadius,
                    bottomLeading: cornerRadius,
                    bottomTrailing: flatCornerRadius,
                    topTrailing: cornerRadius
                )
            )
        } else {
            // Assistant message: flat bottom-left corner
            path.addRoundedRect(
                in: rect,
                cornerRadii: RectangleCornerRadii(
                    topLeading: cornerRadius,
                    bottomLeading: flatCornerRadius,
                    bottomTrailing: cornerRadius,
                    topTrailing: cornerRadius
                )
            )
        }

        return path
    }
}

// MARK: - Preview

#Preview("User Message") {
    ZStack {
        Color.cream.ignoresSafeArea()

        VStack {
            MessageBubble(message: ChatMessage.userMessage(
                content: "I've been feeling stuck lately and don't know where to start.",
                conversationId: UUID()
            ))

            MessageBubble(message: ChatMessage.assistantMessage(
                content: "Feeling stuck is completely normal, and it often means you're on the edge of growth. What area of your life feels most stuck right now?",
                conversationId: UUID()
            ))
        }
    }
}
