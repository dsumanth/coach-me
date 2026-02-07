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
            self.glassEffect()
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
            // iOS 26 glass effect handles interactive states via GlassEffectContainer
            // Individual interactive elements inherit from container context
            self.glassEffect()
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
            self.glassEffect()
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
            self.glassEffect()
        } else {
            self.background(.ultraThinMaterial)
        }
    }

    /// Applies adaptive glass effect for modal sheets and overlays.
    /// - iOS 26+: Uses native Liquid Glass effect with appropriate styling
    /// - iOS 18-25: Uses thickMaterial for better readability on sheets
    @ViewBuilder
    func adaptiveGlassSheet() -> some View {
        if #available(iOS 26, *) {
            // .glassEffect() creates a squircle shape inside the sheet — use material instead.
            // The sheet presentation handles its own corner radius on iOS 26.
            self.background(.thickMaterial)
        } else {
            self.background(.thickMaterial)
                .clipShape(RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.sheet))
        }
    }

    /// Applies adaptive glass effect for text input containers.
    /// - iOS 26+: Uses native Liquid Glass effect
    /// - iOS 18-25: Uses regularMaterial with subtle shadow for depth
    @ViewBuilder
    func adaptiveGlassInput() -> some View {
        if #available(iOS 26, *) {
            self.glassEffect()
        } else {
            self.background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.input))
                .shadow(color: .black.opacity(0.08), radius: 3, y: 2)
        }
    }
}

// Note: DesignConstants moved to DesignConstants.swift
