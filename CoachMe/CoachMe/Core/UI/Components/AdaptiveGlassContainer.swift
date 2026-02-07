//
//  AdaptiveGlassContainer.swift
//  CoachMe
//
//  Created by Dev Agent on 2/5/26.
//

import SwiftUI

// MARK: - AdaptiveGlassContainer

/// A container that wraps content with adaptive glass styling.
/// - iOS 26+: Uses `GlassEffectContainer` for native Liquid Glass grouping
/// - iOS 18-25: Uses `.ultraThinMaterial` with rounded corners for Warm Modern styling
///
/// Use this when grouping multiple interactive glass elements that need coordinated styling.
///
/// - Note: On iOS 26+, the `cornerRadius` parameter is not applied because
///   `GlassEffectContainer` manages its own corner styling via the Liquid Glass system.
///   The parameter is retained for iOS 18-25 fallback styling only.
///
/// Example:
/// ```swift
/// AdaptiveGlassContainer {
///     HStack {
///         Button("Voice") { ... }
///         Button("Send") { ... }
///     }
/// }
/// ```
struct AdaptiveGlassContainer<Content: View>: View {

    // MARK: - Properties

    let content: Content
    let padding: CGFloat
    let cornerRadius: CGFloat

    // MARK: - Initialization

    /// Creates an adaptive glass container with default padding and corner radius.
    /// - Parameter content: The content to display inside the container
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
        self.padding = DesignConstants.Spacing.md
        self.cornerRadius = DesignConstants.CornerRadius.container
    }

    /// Creates an adaptive glass container with custom padding and corner radius.
    /// - Parameters:
    ///   - padding: The padding around the content (default: 16pt)
    ///   - cornerRadius: The corner radius for the container (default: 16pt)
    ///   - content: The content to display inside the container
    init(
        padding: CGFloat = DesignConstants.Spacing.md,
        cornerRadius: CGFloat = DesignConstants.CornerRadius.container,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.padding = padding
        self.cornerRadius = cornerRadius
    }

    // MARK: - Body

    var body: some View {
        if #available(iOS 26, *) {
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            content
                .padding(padding)
                .background {
                    shape
                        .fill(.clear)
                        .glassEffect(.regular, in: shape)
                    shape
                        .fill(Color.white.opacity(0.022))
                }
                .overlay(shape.stroke(Color.white.opacity(0.16), lineWidth: 1))
                .clipShape(shape)
        } else {
            content
                .padding(padding)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}

// MARK: - AdaptiveGlassSheet

/// A sheet-style container with adaptive glass styling.
/// Designed for modal presentations and overlays.
///
/// - Note: On iOS 26+, corner radius is managed by `GlassEffectContainer`.
///   The sheet corner radius is only applied on iOS 18-25.
struct AdaptiveGlassSheet<Content: View>: View {

    let content: Content
    let padding: CGFloat

    init(
        padding: CGFloat = DesignConstants.Spacing.lg,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.padding = padding
    }

    var body: some View {
        if #available(iOS 26, *) {
            let shape = RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.sheet, style: .continuous)
            content
                .padding(padding)
                .background {
                    shape
                        .fill(.clear)
                        .glassEffect(.regular, in: shape)
                    shape
                        .fill(Color.white.opacity(0.028))
                }
                .overlay(shape.stroke(Color.white.opacity(0.18), lineWidth: 1))
                .clipShape(shape)
        } else {
            content
                .padding(padding)
                .background(.thickMaterial)
                .clipShape(RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.sheet))
        }
    }
}

// MARK: - AdaptiveGlassInputContainer

/// An input-style container with adaptive glass styling.
/// Designed for text fields and input areas.
///
/// - Note: On iOS 26, uses `.glassEffect()` on a background shape to create visible glass.
///   `GlassEffectContainer` alone doesn't create a visible background - it only groups elements.
struct AdaptiveGlassInputContainer<Content: View>: View {

    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        if #available(iOS 26, *) {
            let shape = RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.input, style: .continuous)
            content
                .padding(.horizontal, DesignConstants.Spacing.md)
                .padding(.vertical, DesignConstants.Spacing.sm)
                .background {
                    shape
                        .fill(.clear)
                        .glassEffect(.regular, in: shape)
                    shape
                        .fill(Color.white.opacity(0.03))
                }
                .overlay(shape.stroke(Color.white.opacity(0.22), lineWidth: 1))
                .clipShape(shape)
        } else {
            content
                .padding(.horizontal, DesignConstants.Spacing.md)
                .padding(.vertical, DesignConstants.Spacing.sm)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.input))
                .shadow(color: .black.opacity(0.08), radius: 3, y: 2)
        }
    }
}

// MARK: - Previews

#Preview("AdaptiveGlassContainer") {
    ZStack {
        Color.cream.ignoresSafeArea()

        AdaptiveGlassContainer {
            HStack(spacing: 12) {
                Button("Voice") { }
                    .buttonStyle(.bordered)
                Button("Send") { }
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

#Preview("AdaptiveGlassSheet") {
    ZStack {
        Color.cream.ignoresSafeArea()

        AdaptiveGlassSheet {
            VStack(spacing: 16) {
                Text("Modal Content")
                    .font(.headline)
                Text("This is a sheet-style container")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

#Preview("AdaptiveGlassInputContainer") {
    ZStack {
        Color.cream.ignoresSafeArea()

        AdaptiveGlassInputContainer {
            HStack {
                TextField("Type a message...", text: .constant(""))
                Button(action: {}) {
                    Image(systemName: "paperplane.fill")
                }
            }
        }
        .padding()
    }
}
