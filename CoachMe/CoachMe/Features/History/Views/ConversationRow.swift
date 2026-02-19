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
    let preview: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            avatar

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(displayTitle)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text(relativeTimestamp)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                }

                if let coachName {
                    Text(coachName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(avatarAccentColor)
                        .lineLimit(1)
                }

                Text(preview)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    colorScheme == .dark
                        ? Color.warmGray700.opacity(0.48)
                        : Color.white.opacity(0.86)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    colorScheme == .dark
                        ? Color.white.opacity(0.08)
                        : Color.black.opacity(0.06),
                    lineWidth: 1
                )
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Subviews

    private var avatar: some View {
        let fillColor = avatarAccentColor.opacity(colorScheme == .dark ? 0.35 : 0.2)
        let symbolName = knownDomain?.avatarSymbol ?? "bubble.left.and.text.bubble.right.fill"

        return ZStack {
            Circle()
                .fill(fillColor)
            Circle()
                .stroke(
                    colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.08),
                    lineWidth: 1
                )
            Image(systemName: symbolName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.adaptiveText(colorScheme))
        }
        .frame(width: 42, height: 42)
    }

    // MARK: - Computed Properties

    /// Display title: uses conversation title if available, otherwise a default
    private var displayTitle: String {
        if let title = conversation.title, !title.isEmpty {
            return title
        }
        return "New conversation"
    }

    private var knownDomain: CoachingDomain? {
        conversation.domain.flatMap { CoachingDomain(rawValue: $0.lowercased()) }
    }

    private var coachName: String? {
        knownDomain?.coachName
    }

    private var avatarAccentColor: Color {
        knownDomain?.adaptiveColor(colorScheme)
            ?? Color.adaptiveText(colorScheme, isPrimary: false)
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

        if let coachName {
            parts.append(coachName)
        }

        parts.append(preview)

        let count = conversation.messageCount
        parts.append(String.localizedStringWithFormat(
            NSLocalizedString("message_count", comment: "Accessibility: number of messages"),
            count
        ))

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
