//
//  DesignConstants.swift
//  CoachMe
//
//  Created by Dev Agent on 2/6/26.
//

import SwiftUI

// MARK: - Design Constants

/// Centralized design constants for the adaptive design system.
/// Provides consistent spacing, corner radii, animation durations,
/// shadows, and other design tokens used throughout the app.
enum DesignConstants {

    // MARK: - Corner Radius

    /// Corner radius values for different element types
    enum CornerRadius {
        /// Container elements (cards, panels): 16pt
        static let container: CGFloat = 16

        /// Standard elements: 12pt
        static let standard: CGFloat = 12

        /// Interactive elements (buttons): 8pt
        static let interactive: CGFloat = 8

        /// Input fields: 10pt
        static let input: CGFloat = 10

        /// Sheet/modal elements: 20pt
        static let sheet: CGFloat = 20

        /// Full rounding (circular/pill): Uses .infinity for capsule
        static let full: CGFloat = .infinity
    }

    // MARK: - Spacing

    /// Spacing values for consistent layout
    /// Based on 4pt grid system
    enum Spacing {
        /// 4pt - Extra extra small
        static let xxs: CGFloat = 4

        /// 8pt - Extra small
        static let xs: CGFloat = 8

        /// 12pt - Small
        static let sm: CGFloat = 12

        /// 16pt - Medium (base)
        static let md: CGFloat = 16

        /// 24pt - Large
        static let lg: CGFloat = 24

        /// 32pt - Extra large
        static let xl: CGFloat = 32

        /// 48pt - Extra extra large
        static let xxl: CGFloat = 48

        /// 64pt - Maximum spacing
        static let max: CGFloat = 64
    }

    // MARK: - Animation

    /// Animation durations for consistent motion
    enum Animation {
        /// 0.15s - Quick interactions (button press, toggle)
        static let quick: Double = 0.15

        /// 0.25s - Standard transitions
        static let standard: Double = 0.25

        /// 0.35s - Smooth, deliberate animations
        static let smooth: Double = 0.35

        /// 0.5s - Slow, prominent animations
        static let slow: Double = 0.5

        /// Spring animation for natural feel
        static var spring: SwiftUI.Animation {
            .spring(response: 0.35, dampingFraction: 0.7)
        }

        /// Bouncy spring for playful interactions
        static var bouncy: SwiftUI.Animation {
            .spring(response: 0.4, dampingFraction: 0.6)
        }
    }

    // MARK: - Shadows

    /// Shadow configurations for depth and elevation
    enum Shadow {
        /// Light shadow for subtle elevation
        static let light = ShadowConfig(
            color: Color.black.opacity(0.08),
            radius: 4,
            x: 0,
            y: 2
        )

        /// Medium shadow for cards and containers
        static let medium = ShadowConfig(
            color: Color.black.opacity(0.12),
            radius: 8,
            x: 0,
            y: 4
        )

        /// Strong shadow for floating elements
        static let strong = ShadowConfig(
            color: Color.black.opacity(0.16),
            radius: 16,
            x: 0,
            y: 8
        )

        /// Warm shadow for light mode (terracotta tinted)
        static let warmLight = ShadowConfig(
            color: Color.warmGray400.opacity(0.15),
            radius: 8,
            x: 0,
            y: 4
        )

        /// Dark mode shadow (deeper black)
        static let darkMode = ShadowConfig(
            color: Color.black.opacity(0.3),
            radius: 8,
            x: 0,
            y: 4
        )
    }

    // MARK: - Sizing

    /// Standard sizes for common UI elements
    enum Size {
        /// Minimum touch target per HIG: 44pt
        static let minTouchTarget: CGFloat = 44

        /// Icon sizes
        static let iconSmall: CGFloat = 16
        static let iconMedium: CGFloat = 24
        static let iconLarge: CGFloat = 32
        static let iconXLarge: CGFloat = 48

        /// Avatar sizes
        static let avatarSmall: CGFloat = 32
        static let avatarMedium: CGFloat = 48
        static let avatarLarge: CGFloat = 64

        /// Button heights
        static let buttonSmall: CGFloat = 36
        static let buttonMedium: CGFloat = 44
        static let buttonLarge: CGFloat = 52
    }

    // MARK: - Opacity

    /// Standard opacity values
    enum Opacity {
        /// Disabled state
        static let disabled: Double = 0.5

        /// Secondary/subtle elements
        static let secondary: Double = 0.7

        /// Overlay backgrounds
        static let overlay: Double = 0.4

        /// Pressed state
        static let pressed: Double = 0.8
    }
}

// MARK: - Shadow Configuration

/// Configuration for shadow effects
struct ShadowConfig {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - View Extension for Shadows

extension View {
    /// Applies a shadow configuration
    func shadow(_ config: ShadowConfig) -> some View {
        self.shadow(
            color: config.color,
            radius: config.radius,
            x: config.x,
            y: config.y
        )
    }

    /// Applies warm shadow that adapts to color scheme
    func warmShadow(for colorScheme: ColorScheme) -> some View {
        self.shadow(
            colorScheme == .dark
                ? DesignConstants.Shadow.darkMode
                : DesignConstants.Shadow.warmLight
        )
    }
}
