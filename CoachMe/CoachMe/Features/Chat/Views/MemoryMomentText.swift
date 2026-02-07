//
//  MemoryMomentText.swift
//  CoachMe
//
//  Story 2.4: Context Injection into Coaching Responses
//  Visual treatment for memory moments (UX-4)
//
//  Per UX spec: "Memory Moments are Signature" — The visual treatment of
//  "I remembered this" is Coach App's brand moment. Distinct but never creepy.
//  Warm peach, subtle indicator, conversational framing.
//

import SwiftUI

// MARK: - Memory Moment Text

/// Inline visual treatment for memory moments in coach responses
/// Per UX-4: Subtle warm peach highlight with sparkle indicator
/// Creates the signature "I remembered this" visual moment
struct MemoryMomentText: View {
    let content: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 4) {
            // Sparkle indicator - subtle "memory" cue
            Image(systemName: "sparkle")
                .font(.caption2)
                .foregroundStyle(indicatorColor)

            Text(content)
                .font(.body)
                .foregroundStyle(textColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("I remembered: \(content)")
    }

    // MARK: - Adaptive Colors

    /// Background: warm peach in light mode, deeper warm surface in dark mode
    private var backgroundColor: Color {
        colorScheme == .dark
            ? Color.surfaceMediumDark
            : Color.memoryPeach
    }

    /// Indicator: terracotta-tinted in light, warm gold in dark for visibility
    /// Uses memoryIndicatorDark (not amber) to avoid confusion with warning states
    private var indicatorColor: Color {
        colorScheme == .dark
            ? Color.memoryIndicatorDark
            : Color.memoryIndicator
    }

    /// Text: primary text color for each mode
    private var textColor: Color {
        Color.adaptiveText(colorScheme)
    }
}

// MARK: - Memory Text with Moments

/// Renders text with memory moments visually highlighted
/// Parses [MEMORY: ...] tags and displays them with MemoryMomentText treatment
struct MemoryHighlightedText: View {
    let text: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        renderContent()
    }

    // MARK: - Content Rendering

    @ViewBuilder
    private func renderContent() -> some View {
        let parseResult = MemoryMomentParser.parse(text)

        if parseResult.hasMemoryMoments {
            // Has memory moments - render with highlights
            renderTextWithMoments(parseResult)
        } else {
            // No memory moments - plain text
            Text(text)
                .font(.body)
                .foregroundStyle(Color.adaptiveText(colorScheme))
        }
    }

    /// Renders text with inline memory moment highlights
    @ViewBuilder
    private func renderTextWithMoments(_ parseResult: MemoryParseResult) -> some View {
        // For streaming compatibility, we render the full text with memory moments
        // extracted and displayed as inline highlights
        VStack(alignment: .leading, spacing: 8) {
            Text(parseResult.cleanText)
                .font(.body)
                .foregroundStyle(Color.adaptiveText(colorScheme))

            // Show memory moments as inline indicators below if present
            if !parseResult.moments.isEmpty {
                memoryMomentsSection(parseResult.moments)
            }
        }
    }

    /// Section showing memory moments that were referenced
    @ViewBuilder
    private func memoryMomentsSection(_ moments: [MemoryMoment]) -> some View {
        FlowLayout(spacing: 8) {
            ForEach(moments) { moment in
                MemoryMomentText(content: moment.content)
            }
        }
    }
}

// MARK: - Flow Layout

/// Simple flow layout for memory moment chips
/// Wraps content to next line when needed
/// RTL support is handled automatically by SwiftUI's layout system
struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)

        for (index, subview) in subviews.enumerated() {
            let position = result.positions[index]

            subview.place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(subview.sizeThatFits(.unspecified))
            )
        }
    }

    private func arrangeSubviews(
        proposal: ProposedViewSize,
        subviews: Subviews
    ) -> ArrangementResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                // Move to next line
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            totalWidth = max(totalWidth, currentX - spacing)
            totalHeight = currentY + lineHeight
        }

        return ArrangementResult(
            positions: positions,
            size: CGSize(width: totalWidth, height: totalHeight)
        )
    }

    private struct ArrangementResult {
        let positions: [CGPoint]
        let size: CGSize
    }
}

// MARK: - Previews

#Preview("Memory Moment Text") {
    VStack(spacing: 20) {
        Text("Light Mode")
            .font(.headline)

        MemoryMomentText(content: "honesty and authenticity")

        MemoryMomentText(content: "becoming a better leader")

        Divider()

        Text("In Context")
            .font(.headline)

        VStack(alignment: .leading, spacing: 8) {
            Text("Given that you value")
                .font(.body)
            MemoryMomentText(content: "honesty")
            Text("how does this situation align with that?")
                .font(.body)
        }
        .padding()
        .background(Color.warmGray100)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .padding()
    .background(Color.cream)
}

#Preview("Memory Moment Text - Dark") {
    VStack(spacing: 20) {
        Text("Dark Mode")
            .font(.headline)
            .foregroundStyle(Color.warmGray100)

        MemoryMomentText(content: "honesty and authenticity")

        MemoryMomentText(content: "becoming a better leader")
    }
    .padding()
    .background(Color.creamDark)
    .preferredColorScheme(.dark)
}

#Preview("Memory Highlighted Text") {
    VStack(spacing: 20) {
        MemoryHighlightedText(
            text: "Given that you value [MEMORY: honesty and authenticity], how does this situation align with that?"
        )

        Divider()

        MemoryHighlightedText(
            text: "I remember you mentioned [MEMORY: navigating a career transition] - how does this relate to your goal of [MEMORY: becoming a better leader]?"
        )

        Divider()

        MemoryHighlightedText(
            text: "This is a response without any memory moments."
        )
    }
    .padding()
    .background(Color.cream)
}
