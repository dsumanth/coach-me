//
//  DesignSystem.swift
//  CoachMe
//
//  Created by Dev Agent on 2/5/26.
//

import SwiftUI

// MARK: - Design System

/// Central coordinator for the adaptive design system.
/// Provides unified access to design tokens, current mode, and helper methods.
@MainActor
final class DesignSystem {

    // MARK: - Singleton

    /// Shared instance of the design system
    static let shared = DesignSystem()

    // MARK: - Properties

    /// The current design mode based on iOS version
    let mode: DesignMode

    /// Whether the device supports Liquid Glass (iOS 26+)
    let supportsLiquidGlass: Bool

    // MARK: - Initialization

    private init() {
        self.supportsLiquidGlass = VersionDetection.supportsLiquidGlass
        self.mode = VersionDetection.currentDesignMode
    }

    // MARK: - Design Tokens

    /// Color palette for the app
    /// Supports both light and dark modes with warm, inviting tones
    enum Colors {
        // MARK: - Light Mode Base Colors
        static let cream = Color.cream
        static let terracotta = Color.terracotta

        // MARK: - Dark Mode Base Colors
        /// Warm dark background - NOT pure black
        static let creamDark = Color.creamDark
        /// Brightened terracotta for dark mode visibility
        static let terracottaDark = Color.terracottaDark

        // MARK: - Warm Grays (Full Scale)
        static let warmGray50 = Color.warmGray50
        static let warmGray100 = Color.warmGray100
        static let warmGray200 = Color.warmGray200
        static let warmGray300 = Color.warmGray300
        static let warmGray400 = Color.warmGray400
        static let warmGray500 = Color.warmGray500
        static let warmGray600 = Color.warmGray600
        static let warmGray700 = Color.warmGray700
        static let warmGray800 = Color.warmGray800
        static let warmGray900 = Color.warmGray900

        // MARK: - Accent Colors
        static let sage = Color.sage
        static let dustyRose = Color.dustyRose
        static let amber = Color.amber

        // MARK: - Semantic Colors (Status)
        static let success = Color.successGreen
        static let warning = Color.warningAmber
        static let error = Color.terracotta
        static let info = Color.infoBlue

        // MARK: - Light Mode Semantic
        static let background = Color.cream
        static let primaryAccent = Color.terracotta
        static let textPrimary = Color.warmGray900
        static let textSecondary = Color.warmGray800
        static let surfaceLight = Color.warmGray50
        static let surfaceMedium = Color.warmGray100

        // MARK: - Dark Mode Semantic
        static let backgroundDark = Color.creamDark
        static let primaryAccentDark = Color.terracottaDark
        static let textPrimaryDark = Color.warmGray50
        static let textSecondaryDark = Color.warmGray200
        static let surfaceLightDark = Color.surfaceLightDark
        static let surfaceMediumDark = Color.surfaceMediumDark

        // MARK: - Adaptive Color Accessors

        /// Background color that adapts to color scheme
        static func background(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? backgroundDark : background
        }

        /// Primary accent that adapts to color scheme
        static func primaryAccent(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? primaryAccentDark : primaryAccent
        }

        /// Primary text color that adapts to color scheme
        static func textPrimary(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? textPrimaryDark : textPrimary
        }

        /// Secondary text color that adapts to color scheme
        static func textSecondary(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? textSecondaryDark : textSecondary
        }

        /// Light surface color that adapts to color scheme
        static func surfaceLight(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? surfaceLightDark : surfaceLight
        }

        /// Medium surface color that adapts to color scheme
        static func surfaceMedium(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? surfaceMediumDark : surfaceMedium
        }
    }

    /// Typography styles - references the Typography system
    /// See Typography.swift for full Dynamic Type support
    typealias Typography = CoachMe.Typography

    /// Spacing values (aliased from DesignConstants)
    typealias Spacing = DesignConstants.Spacing

    /// Corner radius values (aliased from DesignConstants)
    typealias CornerRadius = DesignConstants.CornerRadius

    /// Animation durations (aliased from DesignConstants)
    typealias Animation = DesignConstants.Animation

    // MARK: - Helper Methods

    /// Returns appropriate background material based on design mode.
    /// Note: On iOS 26+, prefer using adaptive modifiers like `.adaptiveGlass()`
    /// which apply Liquid Glass effects. This method returns materials for
    /// iOS 18-25 fallback scenarios only.
    func backgroundMaterial(for elementType: ElementType) -> some ShapeStyle {
        // On iOS 26+, glass effects are preferred over materials.
        // This method exists for iOS 18-25 fallback paths.
        switch elementType {
        case .navigation:
            return AnyShapeStyle(.ultraThinMaterial)
        case .container:
            return AnyShapeStyle(.thinMaterial)
        case .interactive:
            return AnyShapeStyle(.regularMaterial)
        case .sheet:
            return AnyShapeStyle(.thickMaterial)
        case .input:
            return AnyShapeStyle(.regularMaterial)
        }
    }

    /// Indicates whether glass effects should be used (iOS 26+) or materials (iOS 18-25)
    var shouldUseGlassEffects: Bool {
        supportsLiquidGlass
    }

    /// Returns appropriate corner radius for element type
    func cornerRadius(for elementType: ElementType) -> CGFloat {
        switch elementType {
        case .navigation:
            return 0 // Navigation typically has no corner radius
        case .container:
            return CornerRadius.container
        case .interactive:
            return CornerRadius.interactive
        case .sheet:
            return CornerRadius.sheet
        case .input:
            return CornerRadius.input
        }
    }

    /// Element types for design system styling
    enum ElementType {
        case navigation
        case container
        case interactive
        case sheet
        case input
    }
}

// MARK: - View Extension for Design System Access

extension View {
    /// Provides the design system environment to the view hierarchy
    func withDesignSystem() -> some View {
        self
            .environment(\.designMode, DesignSystem.shared.mode)
    }
}

// MARK: - SwiftUI Previews

#Preview("Design System Colors - Light") {
    ScrollView {
        VStack(spacing: 12) {
            Group {
                ColorSwatchView(color: DesignSystem.Colors.cream, name: "Cream (Background)", textColor: .black)
                ColorSwatchView(color: DesignSystem.Colors.terracotta, name: "Terracotta (Accent)", textColor: .white)
                ColorSwatchView(color: DesignSystem.Colors.sage, name: "Sage (Secondary)", textColor: .white)
                ColorSwatchView(color: DesignSystem.Colors.dustyRose, name: "Dusty Rose", textColor: .black)
                ColorSwatchView(color: DesignSystem.Colors.amber, name: "Amber", textColor: .white)
            }

            Divider().padding(.vertical, 8)

            Group {
                ColorSwatchView(color: DesignSystem.Colors.success, name: "Success", textColor: .white)
                ColorSwatchView(color: DesignSystem.Colors.warning, name: "Warning", textColor: .white)
                ColorSwatchView(color: DesignSystem.Colors.error, name: "Error", textColor: .white)
                ColorSwatchView(color: DesignSystem.Colors.info, name: "Info", textColor: .white)
            }
        }
        .padding()
    }
}

#Preview("Design System Colors - Dark") {
    ScrollView {
        VStack(spacing: 12) {
            Group {
                ColorSwatchView(color: DesignSystem.Colors.creamDark, name: "Cream Dark (Background)", textColor: .white)
                ColorSwatchView(color: DesignSystem.Colors.terracottaDark, name: "Terracotta Dark (Accent)", textColor: .white)
                ColorSwatchView(color: DesignSystem.Colors.surfaceLightDark, name: "Surface Light Dark", textColor: .white)
                ColorSwatchView(color: DesignSystem.Colors.surfaceMediumDark, name: "Surface Medium Dark", textColor: .white)
            }
        }
        .padding()
    }
    .background(Color.creamDark)
    .preferredColorScheme(.dark)
}

#Preview("Design System Typography") {
    VStack(alignment: .leading, spacing: 12) {
        Text("Display").font(Typography.display)
        Text("Title").font(Typography.title)
        Text("Headline").font(Typography.headline)
        Text("Body").font(Typography.body)
        Text("Caption").font(Typography.caption)
        Text("Footnote").font(Typography.footnote)
        Text("Error Message").font(Typography.errorMessage)
        Text("Button").font(Typography.button)
    }
    .padding()
    .background(Color.cream)
}

#Preview("Design Mode Info") {
    VStack(spacing: 20) {
        Text("Current Design Mode")
            .font(.headline)

        Text(DesignSystem.shared.mode.description)
            .font(.title2)
            .foregroundStyle(DesignSystem.Colors.terracotta)

        Text("Supports Liquid Glass: \(DesignSystem.shared.supportsLiquidGlass ? "Yes" : "No")")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
    .padding()
    .background(Color.cream)
}

// MARK: - Preview Helpers

private struct ColorSwatchView: View {
    let color: Color
    let name: String
    let textColor: Color

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: 50)
            .overlay(Text(name).foregroundStyle(textColor))
    }
}
