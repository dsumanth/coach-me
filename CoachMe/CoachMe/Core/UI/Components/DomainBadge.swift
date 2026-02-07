//
//  DomainBadge.swift
//  CoachMe
//
//  Story 3.6: Small pill/tag showing domain name with domain-specific color
//

import SwiftUI

/// A small pill badge displaying a coaching domain name with its associated color
///
/// Handles three cases:
/// - Known domain: Shows short name with domain-specific color
/// - Unknown but non-nil domain: Shows raw string capitalized with neutral color
/// - Nil domain: Renders nothing (EmptyView)
struct DomainBadge: View {
    let domain: String?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if let domain = domain, !domain.isEmpty {
            let knownDomain = CoachingDomain(rawValue: domain.lowercased())
            let displayText = knownDomain.map { Self.shortName(for: $0) } ?? domain.capitalized
            let badgeColor = knownDomain?.adaptiveColor(colorScheme) ?? Color.adaptiveText(colorScheme, isPrimary: false)

            Text(displayText)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(badgeColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(badgeColor.opacity(0.12))
                )
                .accessibilityLabel("\(displayText) coaching")
        }
    }

    /// Short display names for badges (without "Coaching" suffix)
    private static func shortName(for domain: CoachingDomain) -> String {
        switch domain {
        case .life: return "Life"
        case .career: return "Career"
        case .relationships: return "Relationships"
        case .mindset: return "Mindset"
        case .creativity: return "Creativity"
        case .fitness: return "Fitness"
        case .leadership: return "Leadership"
        case .general: return "General"
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 12) {
        DomainBadge(domain: "career")
        DomainBadge(domain: "relationships")
        DomainBadge(domain: "fitness")
        DomainBadge(domain: "unknown_domain")
        DomainBadge(domain: nil)
    }
    .padding()
}
