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
    @Environment(\.colorScheme) private var colorScheme

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
                        .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))

                    Text(insight.content)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
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
                        .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
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

    // MARK: - Category Style

    private struct CategoryStyle {
        let icon: Image
        let color: Color
        let promptText: String
        let accessibilityName: String
    }

    private var categoryStyle: CategoryStyle {
        switch insight.category {
        case .value:
            return CategoryStyle(
                icon: Image(systemName: "heart.fill"),
                color: Color.terracotta,
                promptText: "I noticed this seems important to you:",
                accessibilityName: "Value"
            )
        case .goal:
            return CategoryStyle(
                icon: Image(systemName: "target"),
                color: Color.sage,
                promptText: "It sounds like you're working toward:",
                accessibilityName: "Goal"
            )
        case .situation:
            return CategoryStyle(
                icon: Image(systemName: "person.fill"),
                color: Color.warmGray600,
                promptText: "I heard you mention:",
                accessibilityName: "Life situation"
            )
        case .pattern:
            return CategoryStyle(
                icon: Image(systemName: "chart.line.uptrend.xyaxis"),
                color: Color.dustyRose,
                promptText: "I noticed a pattern:",
                accessibilityName: "Pattern"
            )
        }
    }

    // MARK: - Computed Properties

    private var categoryIcon: Image { categoryStyle.icon }
    private var categoryColor: Color { categoryStyle.color }
    private var promptText: String { categoryStyle.promptText }

    private var accessibilityDescription: String {
        "\(categoryStyle.accessibilityName) suggestion: \(insight.content)"
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
