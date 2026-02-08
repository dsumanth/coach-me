//
//  PatternInsightText.swift
//  CoachMe
//
//  Story 3.4: Pattern Recognition Across Conversations
//  Story 3.5: Cross-Domain Pattern Synthesis — domain badges, link icon
//  Visual treatment for pattern insights (UX-5)
//
//  Per UX spec: Pattern insights create a "pause to reflect" moment.
//  Lightbulb icon for single-domain, link icon for cross-domain.
//  Subtle left border, warm sage background.
//  Visually distinct from memory moments (UX-4).
//

import SwiftUI

// MARK: - Pattern Insight Text

/// Visual treatment for pattern insights in coach responses
/// Per UX-5: Icon indicator, subtle left border (2px, accent-primary),
/// warm sage/blue background tint, "I've noticed..." framing
/// Story 3.5: Optional domain badges showing which domains are connected
/// Creates a reflective "pause to think" visual beat
struct PatternInsightText: View {
    let content: String
    /// Story 3.5: Connected domains for cross-domain badge display
    var domains: [String] = []

    @Environment(\.colorScheme) private var colorScheme

    /// Whether this is a cross-domain insight (2+ domains)
    private var isCrossDomain: Bool { domains.count >= 2 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 6) {
                // Story 3.5: Link icon for cross-domain, lightbulb for single-domain
                Image(systemName: isCrossDomain ? "link" : "lightbulb.fill")
                    .font(.callout)
                    .foregroundStyle(indicatorColor)
                    .padding(.top, 1)

                Text(content)
                    .font(.body)
                    .foregroundStyle(textColor)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Story 3.5 Task 5.5: Domain badges showing connected domains
            if isCrossDomain {
                HStack(spacing: 4) {
                    ForEach(domains, id: \.self) { domain in
                        Text(domain.capitalized)
                            .font(.caption2)
                            .foregroundStyle(indicatorColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(indicatorColor.opacity(0.12))
                            )
                    }
                }
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 10)
        .padding(.vertical, 8)
        .background(backgroundColor)
        .overlay(alignment: .leading) {
            // Left border accent (2px, accent-primary per UX-5)
            Rectangle()
                .fill(borderColor)
                .frame(width: 2)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint("Pattern detected from your previous conversations")
    }

    // MARK: - Accessibility (Story 3.5 Task 5.7)

    /// VoiceOver label: includes domain names for cross-domain insights
    private var accessibilityText: String {
        if isCrossDomain {
            let domainList = domains.joined(separator: " and ")
            return "Cross-domain insight: \(content), connecting \(domainList)"
        }
        return "Coach insight based on your conversation patterns: \(content)"
    }

    // MARK: - Adaptive Colors

    /// Background: subtle sage in light mode, warm dark surface in dark mode
    private var backgroundColor: Color {
        colorScheme == .dark
            ? Color.patternSageDark
            : Color.patternSage
    }

    /// Left border: sage accent
    private var borderColor: Color {
        colorScheme == .dark
            ? Color.patternIndicatorDark
            : Color.patternBorder
    }

    /// Indicator: sage green in light, softer sage green in dark
    private var indicatorColor: Color {
        colorScheme == .dark
            ? Color.patternIndicatorDark
            : Color.patternIndicator
    }

    /// Text: primary text color for each mode
    private var textColor: Color {
        Color.adaptiveText(colorScheme)
    }
}

// MARK: - Previews

#Preview("Single-Domain Pattern") {
    VStack(spacing: 20) {
        Text("Single-Domain Pattern")
            .font(.headline)

        PatternInsightText(content: "you often describe feeling stuck right before a big transition")
    }
    .padding()
    .background(Color.cream)
}

#Preview("Cross-Domain Pattern") {
    VStack(spacing: 20) {
        Text("Cross-Domain Pattern (Story 3.5)")
            .font(.headline)

        PatternInsightText(
            content: "your relationship with control comes up in both your work life and personal relationships",
            domains: ["career", "relationships"]
        )

        PatternInsightText(
            content: "a pattern of avoidance before big decisions appears across multiple areas of your life",
            domains: ["career", "mindset", "relationships"]
        )
    }
    .padding()
    .background(Color.cream)
}

#Preview("Cross-Domain - Dark") {
    VStack(spacing: 20) {
        Text("Cross-Domain Dark Mode")
            .font(.headline)
            .foregroundStyle(Color.warmGray100)

        PatternInsightText(
            content: "your relationship with control comes up in both your work life and personal relationships",
            domains: ["career", "relationships"]
        )
    }
    .padding()
    .background(Color.creamDark)
    .preferredColorScheme(.dark)
}

#Preview("Side by Side - Memory vs Pattern") {
    VStack(spacing: 24) {
        Text("Memory Moment (UX-4)")
            .font(.caption)
            .foregroundStyle(Color.warmGray500)
        MemoryMomentText(content: "honesty and authenticity")

        Divider()

        Text("Single-Domain Pattern (UX-5)")
            .font(.caption)
            .foregroundStyle(Color.warmGray500)
        PatternInsightText(content: "you often describe feeling stuck right before a big transition")

        Divider()

        Text("Cross-Domain Pattern (Story 3.5)")
            .font(.caption)
            .foregroundStyle(Color.warmGray500)
        PatternInsightText(
            content: "a need for control appears in your career decisions and personal relationships",
            domains: ["career", "relationships"]
        )
    }
    .padding()
    .background(Color.cream)
}
