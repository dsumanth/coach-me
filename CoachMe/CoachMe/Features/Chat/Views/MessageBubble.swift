//
//  MessageBubble.swift
//  CoachMe
//
//  Created by Sumanth Daggubati on 2/6/26.
//
//  Story 2.4: Updated to render memory moments with visual treatment (UX-4)
//  Story 3.4: Updated to render pattern insights with distinct treatment (UX-5)
//

import SwiftUI
import UIKit

/// Chat bubble for user and assistant messages
/// Per architecture.md: NO glass on content — same styling on both iOS tiers
/// Story 2.4: Assistant messages parse and highlight memory moments
/// Story 3.4: Also renders pattern insights with distinct UX-5 treatment
struct MessageBubble: View {
    let message: ChatMessage
    var isFailedToSend: Bool = false
    var onRetry: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        // Story 3.4: Parse all tags (memory + pattern) once per body evaluation
        let parsed: TagParseResult? = message.isFromUser ? nil : MemoryMomentParser.parseAll(message.content)

        HStack {
            if message.isFromUser {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 4) {
                bubbleContent(parsed: parsed)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(bubbleBackground)
                    .clipShape(bubbleShape)

                statusRow
            }

            if !message.isFromUser {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 16)
        // Story 3.4: Extra vertical padding when pattern insights present (UX-5 32px spacing)
        .padding(.vertical, (parsed?.hasPatternInsights == true) ? 16 : 4)
        .contextMenu {
            Button {
                let textToCopy = parsed?.cleanText ?? message.content
                UIPasteboard.general.string = textToCopy
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText(parsed: parsed))
        .accessibilityHint("Sent at \(message.formattedTime). Long press to copy.")
    }

    // MARK: - Bubble Content

    /// Story 2.4 + 3.4: Renders content with memory moment and pattern insight highlighting
    @ViewBuilder
    private func bubbleContent(parsed: TagParseResult?) -> some View {
        if message.isFromUser {
            // User messages: plain text
            Text(message.content)
                .font(.body)
                .foregroundColor(textColor)
                .textSelection(.enabled)
        } else {
            // Assistant messages: render with coaching tags
            let result = parsed ?? TagParseResult(cleanText: message.content, tags: [])
            VStack(alignment: .leading, spacing: 8) {
                Text(result.cleanText)
                    .font(.body)
                    .foregroundColor(textColor)
                    .textSelection(.enabled)

                // Story 2.4 + 3.4: Show coaching tags with type-specific visual treatment
                if !result.tags.isEmpty {
                    ForEach(result.tags) { tag in
                        switch tag.type {
                        case .memory:
                            MemoryMomentText(content: tag.content)
                        case .pattern:
                            PatternInsightText(content: tag.content)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Accessibility

    /// Accessibility label including memory moment and pattern insight context
    private func accessibilityText(parsed: TagParseResult?) -> String {
        let sender = message.isFromUser ? "You" : "Coach"

        if let result = parsed, !result.tags.isEmpty {
            let tagDescriptions = result.tags.map { tag in
                switch tag.type {
                case .memory:
                    return "I remembered: \(tag.content)"
                case .pattern:
                    return "Coach insight based on your conversation patterns: \(tag.content)"
                }
            }.joined(separator: ". ")
            return "\(sender): \(result.cleanText). \(tagDescriptions)"
        } else {
            return "\(sender): \(message.content)"
        }
    }

    @ViewBuilder
    private var statusRow: some View {
        if message.isFromUser && isFailedToSend {
            HStack(spacing: 6) {
                Text("Not Delivered")
                    .font(.caption2)
                    .foregroundStyle(Color.red.opacity(0.9))

                if let onRetry {
                    Button(action: onRetry) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Color.red)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Retry message")
                    .accessibilityHint("Attempts to send this message again")
                }
            }
        } else {
            Text(message.formattedTime)
                .font(.caption2)
                .foregroundColor(Color.adaptiveText(colorScheme, isPrimary: false))
        }
    }

    // MARK: - Styling

    /// Background color based on message sender
    private var bubbleBackground: Color {
        if message.isFromUser {
            return Color.adaptiveTerracotta(colorScheme)
        }
        return colorScheme == .dark ? Color.warmGray700.opacity(0.58) : Color.warmGray100
    }

    /// Text color based on message sender
    private var textColor: Color {
        message.isFromUser ? .white : Color.adaptiveText(colorScheme)
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

#Preview("With Pattern Insight") {
    ZStack {
        Color.cream.ignoresSafeArea()

        VStack(spacing: 16) {
            MessageBubble(message: ChatMessage.userMessage(
                content: "I feel stuck again with this project.",
                conversationId: UUID()
            ))

            MessageBubble(message: ChatMessage.assistantMessage(
                content: "I've noticed [PATTERN: you often describe feeling stuck right before a big transition]. What do you think that pattern means for you?",
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
