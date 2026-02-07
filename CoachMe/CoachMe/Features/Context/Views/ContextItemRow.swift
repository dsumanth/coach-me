//
//  ContextItemRow.swift
//  CoachMe
//
//  Story 2.5: Context Profile Viewing & Editing
//  Reusable row component for displaying context items with edit/delete actions
//  Per architecture.md: Use adaptive design modifiers, VoiceOver accessibility
//

import SwiftUI

/// Row displaying a context item (value or goal) with edit and delete actions
/// Supports both tap-to-edit and swipe-to-delete gestures
struct ContextItemRow: View {
    // MARK: - Properties

    /// The content to display
    let content: String

    /// Optional badge text (e.g., "achieved" for goals)
    let badge: String?

    /// Badge color
    let badgeColor: Color

    /// Icon for the item type
    let icon: Image

    /// Icon color
    let iconColor: Color

    /// Called when user taps to edit
    let onEdit: () -> Void

    /// Called when user requests deletion
    let onDelete: () -> Void

    // MARK: - State

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Initialization

    /// Creates a context item row
    /// - Parameters:
    ///   - content: The text content to display
    ///   - badge: Optional status badge text
    ///   - badgeColor: Color for the badge (default: sage)
    ///   - icon: System image for the item type
    ///   - iconColor: Color for the icon
    ///   - onEdit: Callback when edit is triggered
    ///   - onDelete: Callback when delete is triggered
    init(
        content: String,
        badge: String? = nil,
        badgeColor: Color = .sage,
        icon: Image,
        iconColor: Color,
        onEdit: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.content = content
        self.badge = badge
        self.badgeColor = badgeColor
        self.icon = icon
        self.iconColor = iconColor
        self.onEdit = onEdit
        self.onDelete = onDelete
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: DesignConstants.Spacing.sm) {
            // Category icon
            icon
                .font(.system(size: 18))
                .foregroundStyle(iconColor)
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)

            // Content
            VStack(alignment: .leading, spacing: DesignConstants.Spacing.xxs) {
                Text(content)
                    .font(.body)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .lineLimit(3)

                // Optional badge
                if let badge = badge {
                    Text(badge)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(badgeColor)
                }
            }

            Spacer(minLength: DesignConstants.Spacing.xs)

            // Edit button
            Button {
                onEdit()
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.warmGray400)
                    .frame(width: DesignConstants.Size.minTouchTarget, height: DesignConstants.Size.minTouchTarget)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit")
            .accessibilityHint("Opens editor for this item")

            // Delete button (visible since swipeActions don't work in VStack)
            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.warmGray400)
                    .frame(width: DesignConstants.Size.minTouchTarget, height: DesignConstants.Size.minTouchTarget)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete")
            .accessibilityHint("Removes this item from your profile")
        }
        .padding(.vertical, DesignConstants.Spacing.sm)
        .padding(.horizontal, DesignConstants.Spacing.md)
        .background(Color.adaptiveSurface(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.standard))
        .contentShape(Rectangle())
        .onTapGesture {
            onEdit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Double tap to edit")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Computed Properties

    private var accessibilityDescription: String {
        if let badge = badge {
            return "\(content). Status: \(badge)"
        }
        return content
    }
}

// MARK: - Convenience Initializers

extension ContextItemRow {
    /// Creates a row for a context value
    static func value(
        _ value: ContextValue,
        onEdit: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) -> ContextItemRow {
        ContextItemRow(
            content: value.content,
            badge: value.source == .extracted ? "AI-suggested" : nil,
            badgeColor: .dustyRose,
            icon: Image(systemName: "heart.fill"),
            iconColor: .terracotta,
            onEdit: onEdit,
            onDelete: onDelete
        )
    }

    /// Creates a row for a context goal
    static func goal(
        _ goal: ContextGoal,
        onEdit: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) -> ContextItemRow {
        let badge: String?
        let badgeColor: Color

        switch goal.status {
        case .active:
            badge = nil
            badgeColor = .sage
        case .achieved:
            badge = "achieved"
            badgeColor = .successGreen
        case .archived:
            badge = "archived"
            badgeColor = .warmGray400
        }

        return ContextItemRow(
            content: goal.content,
            badge: badge,
            badgeColor: badgeColor,
            icon: Image(systemName: goal.status == .achieved ? "checkmark.circle.fill" : "target"),
            iconColor: goal.status == .achieved ? .successGreen : .sage,
            onEdit: onEdit,
            onDelete: onDelete
        )
    }
}

// MARK: - Previews

#Preview("Value Row") {
    VStack {
        ContextItemRow.value(
            ContextValue.userValue("honesty and transparency"),
            onEdit: { print("Edit") },
            onDelete: { print("Delete") }
        )

        ContextItemRow.value(
            ContextValue.extractedValue("family comes first", confidence: 0.9),
            onEdit: { print("Edit") },
            onDelete: { print("Delete") }
        )
    }
    .padding()
}

#Preview("Goal Row") {
    VStack {
        ContextItemRow.goal(
            ContextGoal.userGoal("Get promoted to senior engineer"),
            onEdit: { print("Edit") },
            onDelete: { print("Delete") }
        )

        ContextItemRow.goal(
            {
                var goal = ContextGoal.userGoal("Run a marathon")
                goal.markAchieved()
                return goal
            }(),
            onEdit: { print("Edit") },
            onDelete: { print("Delete") }
        )
    }
    .padding()
}

#Preview("Dark Mode") {
    VStack {
        ContextItemRow.value(
            ContextValue.userValue("work-life balance"),
            onEdit: {},
            onDelete: {}
        )
    }
    .padding()
    .preferredColorScheme(.dark)
}
