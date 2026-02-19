//
//  LearnedInsightRow.swift
//  CoachMe
//
//  Story 8.8: Enhanced Profile — Learned Knowledge Display
//  Row displaying a single inferred pattern with delete action
//

import SwiftUI

/// A row displaying an inferred pattern the coach has noticed
/// Includes category icon, pattern text, confidence indicator, and delete button
struct LearnedInsightRow: View {
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Properties

    let pattern: InferredPattern
    let onDelete: () -> Void

    // MARK: - Body

    var body: some View {
        HStack(spacing: DesignConstants.Spacing.sm) {
            // Category icon
            Image(systemName: categoryIcon(for: pattern.category))
                .font(.system(size: 24))
                .foregroundStyle(Color.dustyRose)
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)

            // Pattern text and confidence
            VStack(alignment: .leading, spacing: DesignConstants.Spacing.xxs) {
                Text(pattern.patternText)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.adaptiveText(colorScheme))

                Text("Seen \(pattern.sourceCount) times")
                    .font(.caption)
                    .foregroundStyle(Color.warmGray500)
            }

            Spacer(minLength: DesignConstants.Spacing.xs)

            // Delete button
            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.warmGray400)
                    .frame(width: DesignConstants.Size.minTouchTarget, height: DesignConstants.Size.minTouchTarget)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove this insight")
            .accessibilityHint("The coach won't suggest this pattern again")
        }
        .padding(.vertical, DesignConstants.Spacing.sm)
        .padding(.horizontal, DesignConstants.Spacing.md)
        .modifier(ContextProfileRowSurfaceModifier(colorScheme: colorScheme))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Pattern: \(pattern.patternText). Seen \(pattern.sourceCount) times.")
    }

    // MARK: - Category Icon Mapping

    private func categoryIcon(for category: String) -> String {
        let key = category.lowercased()
        if key.contains("boundary") || key.contains("relationship") { return "heart.fill" }
        if key.contains("career") || key.contains("work") { return "briefcase.fill" }
        if key.contains("growth") || key.contains("mindset") { return "brain.head.profile" }
        if key.contains("stress") || key.contains("anxiety") { return "wind" }
        if key.contains("goal") || key.contains("progress") { return "target" }
        if key.contains("health") || key.contains("fitness") { return "heart.circle.fill" }
        return "sparkles"
    }
}
