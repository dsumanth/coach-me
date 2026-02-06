//
//  ColorSchemeModifiers.swift
//  CoachMe
//
//  Created by Dev Agent on 2/6/26.
//

import SwiftUI

// MARK: - Adaptive Background Modifier

/// Applies warm adaptive background color that respects color scheme
struct AdaptiveBackgroundModifier: ViewModifier {
    @SwiftUI.Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(Color.adaptiveCream(colorScheme))
    }
}

// MARK: - Adaptive Text Modifier

/// Applies warm adaptive text color that respects color scheme
struct AdaptiveTextModifier: ViewModifier {
    @SwiftUI.Environment(\.colorScheme) private var colorScheme
    let isPrimary: Bool

    func body(content: Content) -> some View {
        content
            .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: isPrimary))
    }
}

// MARK: - Adaptive Surface Modifier

/// Applies warm adaptive surface color that respects color scheme
struct AdaptiveSurfaceModifier: ViewModifier {
    @SwiftUI.Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(Color.adaptiveSurface(colorScheme))
    }
}

// MARK: - Adaptive Accent Modifier

/// Applies warm adaptive terracotta accent that respects color scheme
struct AdaptiveAccentModifier: ViewModifier {
    @SwiftUI.Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .foregroundStyle(Color.adaptiveTerracotta(colorScheme))
    }
}

// MARK: - Warm Card Modifier

/// Applies complete warm card styling with shadows and corner radius
struct WarmCardModifier: ViewModifier {
    @SwiftUI.Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(Color.adaptiveSurface(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.container))
            .shadow(
                color: colorScheme == .dark
                    ? Color.black.opacity(0.3)
                    : Color.warmGray400.opacity(0.15),
                radius: 8,
                x: 0,
                y: 4
            )
    }
}

// MARK: - Warm Button Modifier

/// Applies warm button styling with terracotta accent
struct WarmButtonModifier: ViewModifier {
    @SwiftUI.Environment(\.colorScheme) private var colorScheme
    let style: ButtonStyleType

    enum ButtonStyleType {
        case primary
        case secondary
        case tertiary
    }

    func body(content: Content) -> some View {
        switch style {
        case .primary:
            content
                .font(Typography.button)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.adaptiveTerracotta(colorScheme))
                .clipShape(Capsule())

        case .secondary:
            content
                .font(Typography.button)
                .foregroundStyle(Color.adaptiveTerracotta(colorScheme))
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.adaptiveSurface(colorScheme))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.adaptiveTerracotta(colorScheme), lineWidth: 1.5)
                )

        case .tertiary:
            content
                .font(Typography.button)
                .foregroundStyle(Color.adaptiveTerracotta(colorScheme))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Applies warm adaptive background color
    func warmBackground() -> some View {
        modifier(AdaptiveBackgroundModifier())
    }

    /// Applies warm adaptive text color
    /// - Parameter isPrimary: Whether to use primary or secondary text color
    func warmText(isPrimary: Bool = true) -> some View {
        modifier(AdaptiveTextModifier(isPrimary: isPrimary))
    }

    /// Applies warm adaptive surface color
    func warmSurface() -> some View {
        modifier(AdaptiveSurfaceModifier())
    }

    /// Applies warm terracotta accent color
    func warmAccent() -> some View {
        modifier(AdaptiveAccentModifier())
    }

    /// Applies complete warm card styling
    func warmCard() -> some View {
        modifier(WarmCardModifier())
    }

    /// Applies warm button styling
    /// - Parameter style: The button style (primary, secondary, or tertiary)
    func warmButton(_ style: WarmButtonModifier.ButtonStyleType = .primary) -> some View {
        modifier(WarmButtonModifier(style: style))
    }
}

// MARK: - Previews

#Preview("Adaptive Background") {
    VStack(spacing: 20) {
        Text("Light Mode")
            .warmBackground()
            .padding()

        Text("Dark Mode")
            .warmBackground()
            .padding()
            .preferredColorScheme(.dark)
    }
}

#Preview("Warm Cards") {
    VStack(spacing: 20) {
        VStack {
            Text("Light Mode Card")
                .padding()
        }
        .warmCard()
        .padding()

        VStack {
            Text("Dark Mode Card")
                .padding()
        }
        .warmCard()
        .padding()
        .preferredColorScheme(.dark)
    }
    .warmBackground()
}

#Preview("Warm Buttons") {
    VStack(spacing: 20) {
        Text("Primary")
            .warmButton(.primary)

        Text("Secondary")
            .warmButton(.secondary)

        Text("Tertiary")
            .warmButton(.tertiary)
    }
    .padding()
    .warmBackground()
}

#Preview("Warm Text Hierarchy") {
    VStack(alignment: .leading, spacing: 12) {
        Text("Primary Text")
            .font(Typography.title)
            .warmText(isPrimary: true)

        Text("Secondary Text - provides supporting information")
            .font(Typography.body)
            .warmText(isPrimary: false)

        Text("Accent Text")
            .font(Typography.headline)
            .warmAccent()
    }
    .padding()
    .warmBackground()
}
