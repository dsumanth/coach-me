//
//  AdaptiveButton.swift
//  CoachMe
//
//  Created by Dev Agent on 2/5/26.
//

import SwiftUI

// MARK: - AdaptiveButton

/// A button with adaptive glass styling that adjusts based on iOS version.
/// - iOS 26+: Uses Liquid Glass effect
/// - iOS 18-25: Uses warm material styling with subtle shadow
///
/// Supports Dynamic Type and VoiceOver accessibility.
struct AdaptiveButton: View {

    // MARK: - Properties

    let title: String
    let icon: String?
    let style: ButtonVariant
    let action: () -> Void

    // MARK: - Initialization

    /// Creates an adaptive button with a title only.
    init(
        _ title: String,
        style: ButtonVariant = .secondary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = nil
        self.style = style
        self.action = action
    }

    /// Creates an adaptive button with a title and icon.
    init(
        _ title: String,
        icon: String,
        style: ButtonVariant = .secondary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.action = action
    }

    // MARK: - Body

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignConstants.Spacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.body.weight(.medium))
                }
                Text(title)
                    .font(.body.weight(.medium))
            }
            .padding(.horizontal, DesignConstants.Spacing.md)
            .padding(.vertical, DesignConstants.Spacing.sm)
            .frame(minHeight: 44) // Accessibility minimum tap target
        }
        .buttonStyle(AdaptiveButtonStyle(variant: style))
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Button Variants

    enum ButtonVariant {
        case primary     // Terracotta filled
        case secondary   // Glass/material background
        case tertiary    // Text only with subtle hover
    }
}

// MARK: - AdaptiveButtonStyle

/// Custom button style that applies adaptive glass effects.
struct AdaptiveButtonStyle: ButtonStyle {

    let variant: AdaptiveButton.ButtonVariant

    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        AdaptiveButtonContent(
            configuration: configuration,
            variant: variant
        )
    }
}

// MARK: - AdaptiveButtonContent

private struct AdaptiveButtonContent: View {

    let configuration: ButtonStyleConfiguration
    let variant: AdaptiveButton.ButtonVariant

    var body: some View {
        configuration.label
            .foregroundStyle(foregroundColor)
            .background(backgroundView)
            .clipShape(RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.interactive))
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: DesignConstants.Animation.quick), value: configuration.isPressed)
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch variant {
        case .primary:
            Color.terracotta

        case .secondary:
            // Note: Using version-checked glass effect inline because ButtonStyle
            // context requires concrete View types. This follows the architecture's
            // intent of always version-checking before applying glass effects.
            if #available(iOS 26, *) {
                Color.clear.glassEffect()
            } else {
                Color.clear
                    .background(.regularMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
            }

        case .tertiary:
            Color.clear
        }
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary:
            return .white
        case .secondary:
            return .warmGray900
        case .tertiary:
            return .terracotta
        }
    }
}

// MARK: - AdaptiveIconButton

/// A circular icon-only button with adaptive glass styling.
struct AdaptiveIconButton: View {

    let icon: String
    let accessibilityLabel: String
    let action: () -> Void

    init(
        icon: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.body.weight(.medium))
                .frame(width: 44, height: 44) // Accessibility minimum
                .contentShape(Circle())
        }
        .buttonStyle(AdaptiveIconButtonStyle())
        .accessibilityLabel(accessibilityLabel)
    }
}

// MARK: - AdaptiveIconButtonStyle

private struct AdaptiveIconButtonStyle: ButtonStyle {

    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .foregroundStyle(Color.warmGray900)
            // Note: Using version-checked glass effect inline because ButtonStyle
            // context requires concrete View types.
            .background {
                if #available(iOS 26, *) {
                    Circle().fill(.clear).glassEffect()
                } else {
                    Circle()
                        .fill(.regularMaterial)
                        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                }
            }
            .clipShape(Circle())
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: DesignConstants.Animation.quick), value: configuration.isPressed)
    }
}

// MARK: - Previews

#Preview("AdaptiveButton Variants") {
    VStack(spacing: 20) {
        AdaptiveButton("Primary Button", style: .primary) { }

        AdaptiveButton("Secondary Button", style: .secondary) { }

        AdaptiveButton("Tertiary Button", style: .tertiary) { }

        AdaptiveButton("With Icon", icon: "paperplane.fill", style: .secondary) { }
    }
    .padding()
    .background(Color.cream)
}

#Preview("AdaptiveIconButton") {
    HStack(spacing: 16) {
        AdaptiveIconButton(icon: "mic.fill", accessibilityLabel: "Record voice") { }
        AdaptiveIconButton(icon: "paperplane.fill", accessibilityLabel: "Send message") { }
        AdaptiveIconButton(icon: "ellipsis", accessibilityLabel: "More options") { }
    }
    .padding()
    .background(Color.cream)
}
