//
//  InsightSuggestionCard.swift
//  CoachMe
//
//  Story 2.3: Progressive Context Extraction
//  Card for displaying a single extracted insight suggestion
//  Per architecture.md: Use adaptive design modifiers, VoiceOver accessibility
//

import SwiftUI

/// Card displaying a single extracted insight for user confirmation
/// Uses warm, first-person copy per UX guidelines
struct InsightSuggestionCard: View {
    // MARK: - Properties

    /// The insight to display
    let insight: ExtractedInsight

    /// Called when user confirms the insight is accurate
    let onConfirm: () -> Void

    /// Called when user dismisses the insight
    let onDismiss: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.sm) {
            // Category badge and content
            HStack(alignment: .top, spacing: DesignConstants.Spacing.sm) {
                // Category icon
                categoryIcon
                    .font(.system(size: 24))
                    .foregroundStyle(categoryColor)
                    .frame(width: 32, height: 32)
                    .accessibilityHidden(true)

                // Content text with warm prompt
                VStack(alignment: .leading, spacing: DesignConstants.Spacing.xs) {
                    Text(promptText)
                        .font(.subheadline)
                        .foregroundStyle(Color.warmGray600)

                    Text(insight.content)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.warmGray900)
                }
            }

            // Action buttons
            HStack(spacing: DesignConstants.Spacing.sm) {
                // Confirm button
                Button {
                    onConfirm()
                } label: {
                    Text("Yes, that's right")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: DesignConstants.Size.buttonSmall)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.terracotta)
                .adaptiveInteractiveGlass()
                .accessibilityLabel("Confirm insight")
                .accessibilityHint("Adds this to your profile: \(insight.content)")

                // Dismiss button
                Button {
                    onDismiss()
                } label: {
                    Text("Not quite")
                        .font(.subheadline)
                        .foregroundStyle(Color.warmGray500)
                        .frame(maxWidth: .infinity)
                        .frame(height: DesignConstants.Size.buttonSmall)
                }
                .adaptiveInteractiveGlass()
                .accessibilityLabel("Dismiss insight")
                .accessibilityHint("Removes this suggestion")
            }
            .padding(.top, DesignConstants.Spacing.xs)
        }
        .padding(DesignConstants.Spacing.md)
        .adaptiveGlass()
        .clipShape(RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.container))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Computed Properties

    /// Icon for the insight category
    private var categoryIcon: Image {
        switch insight.category {
        case .value:
            return Image(systemName: "heart.fill")
        case .goal:
            return Image(systemName: "target")
        case .situation:
            return Image(systemName: "person.fill")
        case .pattern:
            return Image(systemName: "chart.line.uptrend.xyaxis")
        }
    }

    /// Color for the insight category
    private var categoryColor: Color {
        switch insight.category {
        case .value:
            return Color.terracotta
        case .goal:
            return Color.sage
        case .situation:
            return Color.warmGray600
        case .pattern:
            return Color.dustyRose
        }
    }

    /// Warm prompt text based on category
    private var promptText: String {
        switch insight.category {
        case .value:
            return "I noticed this seems important to you:"
        case .goal:
            return "It sounds like you're working toward:"
        case .situation:
            return "I heard you mention:"
        case .pattern:
            return "I noticed a pattern:"
        }
    }

    /// Full accessibility description
    private var accessibilityDescription: String {
        let categoryName: String
        switch insight.category {
        case .value:
            categoryName = "Value"
        case .goal:
            categoryName = "Goal"
        case .situation:
            categoryName = "Life situation"
        case .pattern:
            categoryName = "Pattern"
        }
        return "\(categoryName) suggestion: \(insight.content)"
    }
}

// MARK: - Previews

#Preview("InsightSuggestionCard - Value") {
    InsightSuggestionCard(
        insight: ExtractedInsight.pending(
            content: "honesty and transparency",
            category: .value,
            confidence: 0.85
        ),
        onConfirm: { print("Confirmed") },
        onDismiss: { print("Dismissed") }
    )
    .padding()
}

#Preview("InsightSuggestionCard - Goal") {
    InsightSuggestionCard(
        insight: ExtractedInsight.pending(
            content: "career transition to tech",
            category: .goal,
            confidence: 0.9
        ),
        onConfirm: { print("Confirmed") },
        onDismiss: { print("Dismissed") }
    )
    .padding()
}

#Preview("InsightSuggestionCard - Situation") {
    InsightSuggestionCard(
        insight: ExtractedInsight.pending(
            content: "parent of two children",
            category: .situation,
            confidence: 0.95
        ),
        onConfirm: { print("Confirmed") },
        onDismiss: { print("Dismissed") }
    )
    .padding()
}

#Preview("InsightSuggestionCard - Dark") {
    InsightSuggestionCard(
        insight: ExtractedInsight.pending(
            content: "values work-life balance",
            category: .value,
            confidence: 0.85
        ),
        onConfirm: {},
        onDismiss: {}
    )
    .padding()
    .preferredColorScheme(.dark)
}
