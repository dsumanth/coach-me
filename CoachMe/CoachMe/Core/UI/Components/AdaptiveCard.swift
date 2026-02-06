//
//  AdaptiveCard.swift
//  CoachMe
//
//  Created by Dev Agent on 2/5/26.
//

import SwiftUI

// MARK: - AdaptiveCard

/// A content card with warm, solid styling.
/// Per architecture guidelines: Cards do NOT use glass effects.
/// Glass effects are reserved for navigation and control elements only.
///
/// Supports Dynamic Type and VoiceOver accessibility.
/// Apply `.accessibilityElement(children:)` and `.accessibilityLabel()` as needed.
struct AdaptiveCard<Content: View>: View {

    // MARK: - Properties

    let content: Content
    let padding: CGFloat
    let cornerRadius: CGFloat
    let accessibilityLabel: String?

    // MARK: - Initialization

    /// Creates an adaptive card with default padding and corner radius.
    init(
        accessibilityLabel: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.padding = DesignConstants.Spacing.md
        self.cornerRadius = DesignConstants.CornerRadius.container
        self.accessibilityLabel = accessibilityLabel
    }

    /// Creates an adaptive card with custom padding and corner radius.
    init(
        padding: CGFloat = DesignConstants.Spacing.md,
        cornerRadius: CGFloat = DesignConstants.CornerRadius.container,
        accessibilityLabel: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.accessibilityLabel = accessibilityLabel
    }

    // MARK: - Body

    var body: some View {
        content
            .padding(padding)
            .background(Color.warmGray50)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
            .ifLet(accessibilityLabel) { view, label in
                view
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(label)
            }
    }
}

// MARK: - View Extension for Optional Modifier

extension View {
    /// Applies a modifier only if the optional value is non-nil.
    @ViewBuilder
    func ifLet<T, Content: View>(_ value: T?, transform: (Self, T) -> Content) -> some View {
        if let value = value {
            transform(self, value)
        } else {
            self
        }
    }
}

// MARK: - AdaptiveElevatedCard

/// A card with more prominent elevation for featured content.
/// Does NOT use glass effects per architecture guidelines.
struct AdaptiveElevatedCard<Content: View>: View {

    let content: Content
    let padding: CGFloat
    let accessibilityLabel: String?

    init(
        padding: CGFloat = DesignConstants.Spacing.lg,
        accessibilityLabel: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.padding = padding
        self.accessibilityLabel = accessibilityLabel
    }

    var body: some View {
        content
            .padding(padding)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.container))
            .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
            .ifLet(accessibilityLabel) { view, label in
                view
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(label)
            }
    }
}

// MARK: - AdaptiveOutlineCard

/// A card with an outline border instead of fill.
/// Useful for secondary or grouped content.
struct AdaptiveOutlineCard<Content: View>: View {

    let content: Content
    let padding: CGFloat
    let accessibilityLabel: String?

    init(
        padding: CGFloat = DesignConstants.Spacing.md,
        accessibilityLabel: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.padding = padding
        self.accessibilityLabel = accessibilityLabel
    }

    var body: some View {
        content
            .padding(padding)
            .background(Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.container))
            .overlay(
                RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.container)
                    .stroke(Color.warmGray200, lineWidth: 1)
            )
            .ifLet(accessibilityLabel) { view, label in
                view
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(label)
            }
    }
}

// MARK: - AdaptiveInteractiveCard

/// A tappable card with press state feedback.
/// Does NOT use glass effects per architecture guidelines.
struct AdaptiveInteractiveCard<Content: View>: View {

    let content: Content
    let action: () -> Void
    let accessibilityLabel: String?
    let accessibilityHint: String?

    init(
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.action = action
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
    }

    var body: some View {
        Button(action: action) {
            content
                .padding(DesignConstants.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.warmGray50)
                .clipShape(RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.container))
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        }
        .buttonStyle(CardButtonStyle())
        .ifLet(accessibilityLabel) { view, label in
            view.accessibilityLabel(label)
        }
        .ifLet(accessibilityHint) { view, hint in
            view.accessibilityHint(hint)
        }
    }
}

// MARK: - CardButtonStyle

/// Custom button style for interactive cards with press feedback.
private struct CardButtonStyle: ButtonStyle {

    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: DesignConstants.Animation.quick), value: configuration.isPressed)
    }
}

// MARK: - Previews

#Preview("AdaptiveCard") {
    VStack(spacing: 16) {
        AdaptiveCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Standard Card")
                    .font(.headline)
                Text("This is a basic content card with warm styling.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }

        AdaptiveElevatedCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Elevated Card")
                    .font(.headline)
                Text("This card has more prominent elevation for featured content.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }

        AdaptiveOutlineCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Outline Card")
                    .font(.headline)
                Text("This card uses a border instead of a fill.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }
    .padding()
    .background(Color.cream)
}

#Preview("AdaptiveInteractiveCard") {
    VStack(spacing: 16) {
        AdaptiveInteractiveCard(action: { }) {
            HStack {
                Image(systemName: "calendar")
                    .font(.title2)
                    .foregroundStyle(Color.terracotta)
                VStack(alignment: .leading) {
                    Text("Today's Session")
                        .font(.headline)
                    Text("Tap to view details")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityLabel("Today's Session")
        .accessibilityHint("Tap to view session details")
    }
    .padding()
    .background(Color.cream)
}
