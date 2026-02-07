//
//  InsightSuggestionsSheet.swift
//  CoachMe
//
//  Story 2.3: Progressive Context Extraction
//  Sheet displaying pending insight suggestions for user confirmation
//  Per architecture.md: Use adaptive design modifiers, VoiceOver accessibility
//

import SwiftUI

/// Sheet displaying all pending insight suggestions
/// Users can confirm or dismiss each suggestion individually
struct InsightSuggestionsSheet: View {
    // MARK: - Properties

    /// Pending insights to display
    let insights: [ExtractedInsight]

    /// Called when user confirms an insight
    let onConfirm: (UUID) -> Void

    /// Called when user dismisses an insight
    let onDismiss: (UUID) -> Void

    /// Called when user dismisses the entire sheet
    let onDismissAll: () -> Void

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: DesignConstants.Spacing.lg) {
                // Header
                headerSection

                if insights.isEmpty {
                    // Empty state
                    emptyState
                } else {
                    // Insight cards
                    insightsList
                }

                // Review later button
                reviewLaterButton
            }
            .padding(.horizontal, DesignConstants.Spacing.lg)
            .padding(.vertical, DesignConstants.Spacing.md)
        }
        .adaptiveGlassSheet()
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityLabel("Insight suggestions")
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: DesignConstants.Spacing.sm) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(Color.terracotta)
                .accessibilityHidden(true)

            Text("I learned something about you")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(Color.warmGray900)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text("Would you like me to remember these things?")
                .font(.body)
                .foregroundStyle(Color.warmGray600)
                .multilineTextAlignment(.center)
        }
        .padding(.top, DesignConstants.Spacing.sm)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DesignConstants.Spacing.md) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundStyle(Color.sage)
                .accessibilityHidden(true)

            Text("All caught up!")
                .font(.headline)
                .foregroundStyle(Color.warmGray700)

            Text("I don't have any new suggestions right now.")
                .font(.body)
                .foregroundStyle(Color.warmGray500)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, DesignConstants.Spacing.xl)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No pending suggestions")
    }

    // MARK: - Insights List

    private var insightsList: some View {
        VStack(spacing: DesignConstants.Spacing.md) {
            ForEach(insights) { insight in
                InsightSuggestionCard(
                    insight: insight,
                    onConfirm: { onConfirm(insight.id) },
                    onDismiss: { onDismiss(insight.id) }
                )
            }
        }
    }

    // MARK: - Review Later Button

    private var reviewLaterButton: some View {
        Button {
            onDismissAll()
        } label: {
            Text("Review later")
                .font(.subheadline)
                .foregroundStyle(Color.warmGray500)
        }
        .padding(.top, DesignConstants.Spacing.sm)
        .padding(.bottom, DesignConstants.Spacing.md)
        .accessibilityLabel("Review later")
        .accessibilityHint("Closes suggestions. You can review them from your profile.")
    }
}

// MARK: - Previews

#Preview("InsightSuggestionsSheet - Multiple") {
    InsightSuggestionsSheet(
        insights: [
            ExtractedInsight.pending(content: "honesty and transparency", category: .value, confidence: 0.85),
            ExtractedInsight.pending(content: "career transition to tech", category: .goal, confidence: 0.9),
            ExtractedInsight.pending(content: "parent of two children", category: .situation, confidence: 0.95),
        ],
        onConfirm: { id in print("Confirmed: \(id)") },
        onDismiss: { id in print("Dismissed: \(id)") },
        onDismissAll: { print("Dismiss all") }
    )
}

#Preview("InsightSuggestionsSheet - Single") {
    InsightSuggestionsSheet(
        insights: [
            ExtractedInsight.pending(content: "values work-life balance", category: .value, confidence: 0.88),
        ],
        onConfirm: { _ in },
        onDismiss: { _ in },
        onDismissAll: {}
    )
}

#Preview("InsightSuggestionsSheet - Empty") {
    InsightSuggestionsSheet(
        insights: [],
        onConfirm: { _ in },
        onDismiss: { _ in },
        onDismissAll: {}
    )
}

#Preview("InsightSuggestionsSheet - Dark") {
    InsightSuggestionsSheet(
        insights: [
            ExtractedInsight.pending(content: "creativity and self-expression", category: .value, confidence: 0.85),
            ExtractedInsight.pending(content: "learning to play guitar", category: .goal, confidence: 0.9),
        ],
        onConfirm: { _ in },
        onDismiss: { _ in },
        onDismissAll: {}
    )
    .preferredColorScheme(.dark)
}
