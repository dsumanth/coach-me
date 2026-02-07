//
//  AdaptiveGlassModifiers.swift
//  CoachMe
//
//  Created by Sumanth Daggubati on 2/5/26.
//

import SwiftUI

// MARK: - Adaptive Glass Modifiers

extension View {

    // MARK: - Basic Glass Modifiers

    /// Applies adaptive glass effect for container/surface elements.
    /// - iOS 26+: Uses native Liquid Glass effect
    /// - iOS 18-25: Uses ultraThinMaterial with rounded corners
    @ViewBuilder
    func adaptiveGlass() -> some View {
        if #available(iOS 26, *) {
            let shape = RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.standard, style: .continuous)
            self
                .background {
                    shape
                        .fill(.clear)
                        .glassEffect(.regular, in: shape)
                    shape
                        .fill(Color.white.opacity(0.025))
                }
                .overlay(shape.stroke(Color.white.opacity(0.18), lineWidth: 1))
                .clipShape(shape)
        } else {
            self.background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.standard))
        }
    }

    /// Applies adaptive glass effect for interactive/button elements.
    /// - iOS 26+: Uses native Liquid Glass effect (interactive styling via container)
    /// - iOS 18-25: Uses regularMaterial with tighter corners and subtle shadow for affordance
    @ViewBuilder
    func adaptiveInteractiveGlass() -> some View {
        if #available(iOS 26, *) {
            let shape = RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.interactive, style: .continuous)
            self
                .background {
                    shape
                        .fill(.clear)
                        .glassEffect(.regular, in: shape)
                    shape
                        .fill(Color.white.opacity(0.03))
                }
                .overlay(shape.stroke(Color.white.opacity(0.2), lineWidth: 1))
                .clipShape(shape)
        } else {
            self.background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.interactive))
                .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
        }
    }

    /// Applies adaptive glass container for grouping multiple glass elements.
    /// Use this when multiple interactive glass elements need coordinated styling.
    @ViewBuilder
    func adaptiveGlassContainer() -> some View {
        if #available(iOS 26, *) {
            let shape = RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.container, style: .continuous)
            self
                .background {
                    shape
                        .fill(.clear)
                        .glassEffect(.regular, in: shape)
                    shape
                        .fill(Color.white.opacity(0.02))
                }
                .overlay(shape.stroke(Color.white.opacity(0.16), lineWidth: 1))
                .clipShape(shape)
        } else {
            self.background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.container))
        }
    }

    // MARK: - Specialized Glass Modifiers

    /// Applies adaptive glass effect for navigation bars and toolbars.
    /// - iOS 26+: Uses native Liquid Glass effect
    /// - iOS 18-25: Uses ultraThinMaterial for navigation elements
    @ViewBuilder
    func adaptiveGlassNavigation() -> some View {
        if #available(iOS 26, *) {
            self.background(.ultraThinMaterial)
        } else {
            self.background(.ultraThinMaterial)
        }
    }

    /// Applies adaptive glass effect for modal sheets and overlays.
    /// - iOS 26+: Uses native Liquid Glass effect with appropriate styling
    /// - iOS 18-25: Uses thickMaterial for better readability on sheets
    @ViewBuilder
    func adaptiveGlassSheet() -> some View {
        self.modifier(AdaptiveGlassSheetSurfaceModifier())
    }

    /// Applies adaptive glass effect for text input containers.
    /// - iOS 26+: Uses native Liquid Glass effect
    /// - iOS 18-25: Uses regularMaterial with subtle shadow for depth
    @ViewBuilder
    func adaptiveGlassInput() -> some View {
        if #available(iOS 26, *) {
            let shape = RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.input, style: .continuous)
            self
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
            self.background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.input))
                .shadow(color: .black.opacity(0.08), radius: 3, y: 2)
        }
    }
}

// Note: DesignConstants moved to DesignConstants.swift

private struct AdaptiveGlassSheetSurfaceModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.sheet, style: .continuous)

        if #available(iOS 26, *) {
            content
                .background {
                    shape
                        .fill(.clear)
                        .glassEffect(.regular, in: shape)
                    shape
                        .fill(
                            colorScheme == .dark
                                ? Color.black.opacity(0.34)
                                : Color.white.opacity(0.78)
                        )
                }
                .overlay(
                    shape
                        .stroke(
                            colorScheme == .dark
                                ? Color.white.opacity(0.18)
                                : Color.white.opacity(0.45),
                            lineWidth: 1
                        )
                )
                .clipShape(shape)
        } else {
            content
                .background(
                    shape.fill(
                        colorScheme == .dark
                            ? Color.warmGray800.opacity(0.92)
                            : Color.warmGray50.opacity(0.96)
                    )
                )
                .overlay(
                    shape
                        .stroke(
                            colorScheme == .dark
                                ? Color.white.opacity(0.14)
                                : Color.black.opacity(0.08),
                            lineWidth: 1
                        )
                )
                .clipShape(shape)
        }
    }
}
