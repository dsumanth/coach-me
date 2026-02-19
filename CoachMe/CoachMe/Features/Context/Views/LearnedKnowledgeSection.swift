//
//  LearnedKnowledgeSection.swift
//  CoachMe
//
//  Story 8.8: Enhanced Profile — Learned Knowledge Display
//  Section showing what the coach has learned about the user
//

import SwiftUI

/// Section displaying inferred patterns, coaching style, domain usage, and progress notes
/// Uses warm framing: "What I've Learned" — transparent and user-controlled
struct LearnedKnowledgeSection: View {
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Properties

    let patterns: [InferredPattern]
    let effectiveStyle: String?
    let hasManualOverride: Bool
    let domainUsage: DomainUsageStats?
    let progressNotes: [ProgressNote]
    let hasLearnedKnowledge: Bool
    let onDismissInsight: (UUID) -> Void
    let onEditStyle: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.md) {
            sectionHeader

            if !hasLearnedKnowledge {
                emptyState
            } else {
                if !patterns.isEmpty {
                    patternsSubsection
                }

                if let style = effectiveStyle {
                    coachingStyleSubsection(style: style)
                }

                if let usage = domainUsage, !usage.domains.isEmpty {
                    domainUsageSubsection(usage)
                }

                if !progressNotes.isEmpty {
                    progressSubsection
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("What I've Learned section. \(patterns.count) patterns, \(progressNotes.count) progress notes.")
    }

    // MARK: - Section Header

    private var sectionHeader: some View {
        ProfileSectionHeader(title: "What I've Learned", icon: "sparkles", color: .sage)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        AdaptiveGlassContainer {
            HStack(spacing: DesignConstants.Spacing.md) {
                Image(systemName: "sparkles")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.warmGray300)

                Text("As we talk more, I'll share what I'm learning about you here. You'll always be able to see, edit, or remove anything.")
                    .font(.subheadline)
                    .foregroundStyle(Color.warmGray500)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityLabel("As we talk more, I'll share what I'm learning about you here. You'll always be able to see, edit, or remove anything.")
    }

    // MARK: - Patterns Subsection

    private var patternsSubsection: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.sm) {
            Text("Patterns I've Noticed")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.warmGray400)

            ForEach(patterns) { pattern in
                LearnedInsightRow(
                    pattern: pattern,
                    onDelete: { onDismissInsight(pattern.id) }
                )
            }
        }
    }

    // MARK: - Coaching Style Subsection

    private func coachingStyleSubsection(style: String) -> some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.sm) {
            Text("Coaching Style")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.warmGray400)

            HStack {
                VStack(alignment: .leading, spacing: DesignConstants.Spacing.xxs) {
                    Text(style)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.adaptiveText(colorScheme))

                    if hasManualOverride {
                        Text("Manually set")
                            .font(.caption)
                            .foregroundStyle(Color.terracotta)
                    }
                }

                Spacer()

                Button {
                    onEditStyle()
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.warmGray400)
                        .frame(width: DesignConstants.Size.minTouchTarget, height: DesignConstants.Size.minTouchTarget)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit coaching style")
                .accessibilityHint("Opens style preferences")
            }
            .padding(.vertical, DesignConstants.Spacing.sm)
            .padding(.horizontal, DesignConstants.Spacing.md)
            .modifier(ContextProfileRowSurfaceModifier(colorScheme: colorScheme))
        }
    }

    // MARK: - Domain Usage Subsection

    private func domainUsageSubsection(_ usage: DomainUsageStats) -> some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.sm) {
            Text("Your Coaching Focus")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.warmGray400)

            let sortedDomains = usage.domains.sorted { $0.value > $1.value }

            ForEach(sortedDomains, id: \.key) { domain, percentage in
                HStack(spacing: DesignConstants.Spacing.sm) {
                    Circle()
                        .fill(domainColor(for: domain))
                        .frame(width: 10, height: 10)

                    Text(domain)
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveText(colorScheme))

                    Spacer()

                    Text("\(Int(percentage))%")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Color.warmGray500)
                }
                .padding(.vertical, DesignConstants.Spacing.xs)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(domain), \(Int(percentage)) percent")
                .padding(.horizontal, DesignConstants.Spacing.md)
            }
        }
    }

    // MARK: - Progress Subsection

    private var progressSubsection: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.sm) {
            Text("Progress")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.warmGray400)

            ForEach(progressNotes) { note in
                VStack(alignment: .leading, spacing: DesignConstants.Spacing.xxs) {
                    Text(note.goal)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.adaptiveText(colorScheme))

                    Text(note.progressText)
                        .font(.subheadline)
                        .foregroundStyle(Color.warmGray500)
                }
                .padding(.vertical, DesignConstants.Spacing.sm)
                .padding(.horizontal, DesignConstants.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .modifier(ContextProfileRowSurfaceModifier(colorScheme: colorScheme))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Goal: \(note.goal). \(note.progressText)")
            }
        }
    }

    // MARK: - Domain Color Mapping

    private func domainColor(for domain: String) -> Color {
        let key = domain.lowercased()
        if key.contains("career") { return .domainCareer }
        if key.contains("relationship") { return .domainRelationships }
        if key.contains("personal") || key.contains("mindset") || key.contains("growth") { return .domainMindset }
        if key.contains("life") { return .domainLife }
        if key.contains("creativ") { return .domainCreativity }
        if key.contains("fitness") || key.contains("health") { return .domainFitness }
        if key.contains("leader") { return .domainLeadership }
        return .warmGray400
    }
}

// Note: ContextProfileRowSurfaceModifier is defined in ContextProfileView.swift (internal access)
