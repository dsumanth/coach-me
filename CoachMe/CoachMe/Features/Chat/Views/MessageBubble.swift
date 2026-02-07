//
//  MessageBubble.swift
//  CoachMe
//
//  Created by Sumanth Daggubati on 2/6/26.
//
//  Story 2.4: Updated to render memory moments with visual treatment (UX-4)
//

import SwiftUI

/// Chat bubble for user and assistant messages
/// Per architecture.md: NO glass on content — same styling on both iOS tiers
/// Story 2.4: Assistant messages parse and highlight memory moments
struct MessageBubble: View {
    let message: ChatMessage

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 4) {
                bubbleContent
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
        .accessibilityLabel(accessibilityText)
        .accessibilityHint("Sent at \(message.formattedTime)")
    }

    // MARK: - Bubble Content

    /// Story 2.4: Renders content with memory moment highlighting for assistant messages
    @ViewBuilder
    private var bubbleContent: some View {
        if message.isFromUser {
            // User messages: plain text
            Text(message.content)
                .font(.body)
                .foregroundColor(textColor)
        } else {
            // Assistant messages: parse for memory moments
            assistantContentView
        }
    }

    /// Assistant message content with memory moment detection
    @ViewBuilder
    private var assistantContentView: some View {
        let parseResult = MemoryMomentParser.parse(message.content)

        VStack(alignment: .leading, spacing: 8) {
            Text(parseResult.cleanText)
                .font(.body)
                .foregroundColor(textColor)

            // Story 2.4: Show memory moments with visual treatment
            if parseResult.hasMemoryMoments {
                FlowLayout(spacing: 6) {
                    ForEach(parseResult.moments) { moment in
                        MemoryMomentText(content: moment.content)
                    }
                }
            }
        }
    }

    // MARK: - Accessibility

    /// Accessibility label including memory moment context
    private var accessibilityText: String {
        let sender = message.isFromUser ? "You" : "Coach"
        let parseResult = MemoryMomentParser.parse(message.content)

        if parseResult.hasMemoryMoments {
            let momentContents = parseResult.moments.map { "I remembered: \($0.content)" }.joined(separator: ". ")
            return "\(sender): \(parseResult.cleanText). \(momentContents)"
        } else {
            return "\(sender): \(message.content)"
        }
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

#Preview("With Memory Moments") {
    ZStack {
        Color.cream.ignoresSafeArea()

        VStack(spacing: 16) {
            MessageBubble(message: ChatMessage.userMessage(
                content: "I'm struggling with a decision at work.",
                conversationId: UUID()
            ))

            MessageBubble(message: ChatMessage.assistantMessage(
                content: "Given that you value [MEMORY: honesty and authenticity], how does this situation align with that? I remember you mentioned [MEMORY: navigating a career transition] - this sounds like it might be connected.",
                conversationId: UUID()
            ))
        }
    }
}

#Preview("Dark Mode") {
    ZStack {
        Color.creamDark.ignoresSafeArea()

        VStack(spacing: 16) {
            MessageBubble(message: ChatMessage.userMessage(
                content: "How do I stay motivated?",
                conversationId: UUID()
            ))

            MessageBubble(message: ChatMessage.assistantMessage(
                content: "Thinking about your goal of [MEMORY: becoming a better leader], what would that version of you do to stay motivated?",
                conversationId: UUID()
            ))
        }
    }
    .preferredColorScheme(.dark)
}
