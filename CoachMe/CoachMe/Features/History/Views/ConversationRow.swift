//
//  ConversationRow.swift
//  CoachMe
//
//  Story 3.6: Row component for conversation list showing domain badge,
//  title/preview, relative timestamp, and message count
//

import SwiftUI

/// A row in the conversation list displaying conversation metadata
struct ConversationRow: View {
    let conversation: ConversationService.Conversation
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Domain color indicator
            domainIndicator

            VStack(alignment: .leading, spacing: 4) {
                // Title and timestamp row
                HStack(alignment: .firstTextBaseline) {
                    Text(displayTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text(relativeTimestamp)
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                }

                // Domain badge
                if conversation.domain != nil {
                    DomainBadge(domain: conversation.domain)
                }

                // Message count
                if conversation.messageCount > 0 {
                    Text("\(conversation.messageCount) message\(conversation.messageCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Subviews

    private var domainIndicator: some View {
        let knownDomain = conversation.domain.flatMap { CoachingDomain(rawValue: $0.lowercased()) }
        let indicatorColor = knownDomain?.adaptiveColor(colorScheme) ?? Color.adaptiveText(colorScheme, isPrimary: false).opacity(0.3)

        return Circle()
            .fill(indicatorColor)
            .frame(width: 10, height: 10)
            .padding(.top, 5)
    }

    // MARK: - Computed Properties

    /// Display title: uses conversation title if available, otherwise a default
    private var displayTitle: String {
        if let title = conversation.title, !title.isEmpty {
            return title
        }
        return "New conversation"
    }

    /// Relative timestamp formatted for display
    private var relativeTimestamp: String {
        guard let date = conversation.lastMessageAt ?? Optional(conversation.createdAt) else {
            return ""
        }
        return Self.relativeFormatter.localizedString(for: date, relativeTo: Date())
    }

    /// Accessibility description combining all conversation info
    private var accessibilityDescription: String {
        var parts: [String] = [displayTitle]

        if let domain = conversation.domain.flatMap { CoachingDomain(rawValue: $0.lowercased()) } {
            parts.append("\(domain.displayName) coaching")
        }

        if conversation.messageCount > 0 {
            parts.append("\(conversation.messageCount) \(conversation.messageCount == 1 ? "message" : "messages")")
        }

        if !relativeTimestamp.isEmpty {
            parts.append(relativeTimestamp)
        }

        return parts.joined(separator: ", ")
    }

    // MARK: - Static Formatters

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
}
