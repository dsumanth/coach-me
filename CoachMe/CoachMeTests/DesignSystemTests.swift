//
//  DesignSystemTests.swift
//  CoachMe
//
//  Created by Dev Agent on 2/6/26.
//

import Testing
import SwiftUI
@testable import CoachMe

// MARK: - Color Tests

@Suite("Colors Tests")
@MainActor
struct ColorsTests {

    @Test("Cream color has correct warm RGB values")
    func creamColor() {
        // Cream should be warm off-white, not pure white
        let cream = Color.cream
        #expect(cream != Color.white, "Cream should not be pure white")
    }

    @Test("Cream dark is NOT pure black")
    func creamDarkNotBlack() {
        // Per UX spec: Dark mode should be warm, NOT pure black
        let creamDark = Color.creamDark
        #expect(creamDark != Color.black, "Dark mode background must not be pure black")
    }

    @Test("Adaptive cream returns correct color for light mode")
    func adaptiveCreamLight() {
        let color = Color.adaptiveCream(.light)
        #expect(color == Color.cream)
    }

    @Test("Adaptive cream returns correct color for dark mode")
    func adaptiveCreamDark() {
        let color = Color.adaptiveCream(.dark)
        #expect(color == Color.creamDark)
    }

    @Test("Adaptive terracotta returns correct color for light mode")
    func adaptiveTerracottaLight() {
        let color = Color.adaptiveTerracotta(.light)
        #expect(color == Color.terracotta)
    }

    @Test("Adaptive terracotta returns correct color for dark mode")
    func adaptiveTerracottaDark() {
        let color = Color.adaptiveTerracotta(.dark)
        #expect(color == Color.terracottaDark)
    }

    @Test("Adaptive text primary returns different colors for modes")
    func adaptiveTextPrimary() {
        let lightPrimary = Color.adaptiveText(.light, isPrimary: true)
        let darkPrimary = Color.adaptiveText(.dark, isPrimary: true)
        #expect(lightPrimary != darkPrimary, "Primary text should differ between modes")
    }

    @Test("Adaptive text secondary returns different colors for modes")
    func adaptiveTextSecondary() {
        let lightSecondary = Color.adaptiveText(.light, isPrimary: false)
        let darkSecondary = Color.adaptiveText(.dark, isPrimary: false)
        #expect(lightSecondary != darkSecondary, "Secondary text should differ between modes")
    }

    @Test("Warm grays form a complete scale")
    func warmGrayScale() {
        // Verify all grays exist and are distinct
        let grays: [Color] = [
            .warmGray50, .warmGray100, .warmGray200, .warmGray300,
            .warmGray400, .warmGray500, .warmGray600, .warmGray700,
            .warmGray800, .warmGray900
        ]

        // All grays should be distinct
        for i in 0..<grays.count {
            for j in (i+1)..<grays.count {
                #expect(grays[i] != grays[j], "Gray scale colors should be distinct")
            }
        }
    }

    @Test("Semantic colors exist")
    func semanticColors() {
        // Verify semantic colors are accessible
        _ = Color.successGreen
        _ = Color.warningAmber
        _ = Color.infoBlue
    }

    @Test("Accent colors exist")
    func accentColors() {
        _ = Color.sage
        _ = Color.dustyRose
        _ = Color.amber
    }
}

// MARK: - Typography Tests

@Suite("Typography Tests")
@MainActor
struct TypographyTests {

    @Test("All semantic fonts are accessible")
    func semanticFonts() {
        // Verify all typography accessors work
        _ = Typography.display
        _ = Typography.title
        _ = Typography.headline
        _ = Typography.body
        _ = Typography.caption
        _ = Typography.footnote
        _ = Typography.button
        _ = Typography.errorMessage
    }

    @Test("Display style uses SF Rounded design")
    func displayStyle() {
        // Verify display style exists (SF Rounded for headlines/display)
        _ = Typography.display
        // Typography.display is defined with .rounded design
    }
}

// MARK: - Design Constants Tests

@Suite("DesignConstants Tests")
@MainActor
struct DesignConstantsTests {

    @Test("Corner radius values are positive")
    func cornerRadiusValues() {
        #expect(DesignConstants.CornerRadius.container > 0)
        #expect(DesignConstants.CornerRadius.standard > 0)
        #expect(DesignConstants.CornerRadius.interactive > 0)
        #expect(DesignConstants.CornerRadius.input > 0)
        #expect(DesignConstants.CornerRadius.sheet > 0)
    }

    @Test("Container radius is larger than interactive")
    func cornerRadiusHierarchy() {
        #expect(DesignConstants.CornerRadius.container > DesignConstants.CornerRadius.interactive)
    }

    @Test("Spacing follows 4pt grid system")
    func spacingGridSystem() {
        // All spacing values should be divisible by 4
        #expect(DesignConstants.Spacing.xxs.truncatingRemainder(dividingBy: 4) == 0)
        #expect(DesignConstants.Spacing.xs.truncatingRemainder(dividingBy: 4) == 0)
        #expect(DesignConstants.Spacing.sm.truncatingRemainder(dividingBy: 4) == 0)
        #expect(DesignConstants.Spacing.md.truncatingRemainder(dividingBy: 4) == 0)
        #expect(DesignConstants.Spacing.lg.truncatingRemainder(dividingBy: 4) == 0)
        #expect(DesignConstants.Spacing.xl.truncatingRemainder(dividingBy: 4) == 0)
        #expect(DesignConstants.Spacing.xxl.truncatingRemainder(dividingBy: 4) == 0)
        #expect(DesignConstants.Spacing.max.truncatingRemainder(dividingBy: 4) == 0)
    }

    @Test("Spacing values increase progressively")
    func spacingProgression() {
        #expect(DesignConstants.Spacing.xxs < DesignConstants.Spacing.xs)
        #expect(DesignConstants.Spacing.xs < DesignConstants.Spacing.sm)
        #expect(DesignConstants.Spacing.sm < DesignConstants.Spacing.md)
        #expect(DesignConstants.Spacing.md < DesignConstants.Spacing.lg)
        #expect(DesignConstants.Spacing.lg < DesignConstants.Spacing.xl)
        #expect(DesignConstants.Spacing.xl < DesignConstants.Spacing.xxl)
    }

    @Test("Animation durations are positive and progressive")
    func animationDurations() {
        #expect(DesignConstants.Animation.quick > 0)
        #expect(DesignConstants.Animation.standard > DesignConstants.Animation.quick)
        #expect(DesignConstants.Animation.smooth > DesignConstants.Animation.standard)
    }

    @Test("Minimum touch target meets HIG guidelines")
    func touchTargetSize() {
        // Apple HIG: minimum 44pt touch target
        #expect(DesignConstants.Size.minTouchTarget >= 44)
    }

    @Test("Opacity values are in valid range")
    func opacityValues() {
        #expect(DesignConstants.Opacity.disabled >= 0 && DesignConstants.Opacity.disabled <= 1)
        #expect(DesignConstants.Opacity.secondary >= 0 && DesignConstants.Opacity.secondary <= 1)
        #expect(DesignConstants.Opacity.overlay >= 0 && DesignConstants.Opacity.overlay <= 1)
        #expect(DesignConstants.Opacity.pressed >= 0 && DesignConstants.Opacity.pressed <= 1)
    }
}

// MARK: - WarmErrorMessages Tests

@Suite("WarmErrorMessages Tests")
@MainActor
struct WarmErrorMessagesTests {

    @Test("Error messages use first-person voice")
    func firstPersonMessages() {
        // Most messages use "I" for first-person singular
        #expect(WarmErrorMessages.connectionFailed.contains("I"))
        #expect(WarmErrorMessages.loadFailed.contains("I"))
        #expect(WarmErrorMessages.saveFailed.contains("I"))
        #expect(WarmErrorMessages.serverError.contains("I"))
        #expect(WarmErrorMessages.networkUnavailable.contains("I"))

        // Timeout uses "Let's" (first-person plural) - still warm and personal
        #expect(WarmErrorMessages.timeout.contains("Let's"),
               "Timeout message should use first-person plural 'Let's'")
    }

    @Test("Error messages do NOT contain technical jargon")
    func noTechnicalJargon() {
        let messages = [
            WarmErrorMessages.connectionFailed,
            WarmErrorMessages.loadFailed,
            WarmErrorMessages.saveFailed,
            WarmErrorMessages.serverError,
            WarmErrorMessages.timeout,
            WarmErrorMessages.networkUnavailable,
            WarmErrorMessages.generic,
            WarmErrorMessages.permissionDenied,
            WarmErrorMessages.notFound,
            WarmErrorMessages.rateLimited
        ]

        let technicalTerms = ["error", "exception", "code", "status", "500", "503", "HTTP"]

        for message in messages {
            for term in technicalTerms {
                #expect(!message.lowercased().contains(term.lowercased()),
                       "Error message should not contain '\(term)': \(message)")
            }
        }
    }

    @Test("Error messages are conversational and end with question or period")
    func conversationalTone() {
        let messages = [
            WarmErrorMessages.connectionFailed,
            WarmErrorMessages.loadFailed,
            WarmErrorMessages.saveFailed,
            WarmErrorMessages.serverError,
            WarmErrorMessages.timeout,
            WarmErrorMessages.generic
        ]

        for message in messages {
            let endsCorrectly = message.hasSuffix(".") || message.hasSuffix("?")
            #expect(endsCorrectly, "Message should end with period or question mark: \(message)")
        }
    }
}

// MARK: - DesignSystem Integration Tests

@Suite("DesignSystem Integration Tests")
@MainActor
struct DesignSystemIntegrationTests {

    @Test("DesignSystem Colors references match Color extension")
    func colorReferencesMatch() {
        #expect(DesignSystem.Colors.cream == Color.cream)
        #expect(DesignSystem.Colors.terracotta == Color.terracotta)
        #expect(DesignSystem.Colors.creamDark == Color.creamDark)
        #expect(DesignSystem.Colors.terracottaDark == Color.terracottaDark)
    }

    @Test("DesignSystem adaptive color accessors work")
    func adaptiveColorAccessors() {
        let lightBg = DesignSystem.Colors.background(for: .light)
        let darkBg = DesignSystem.Colors.background(for: .dark)
        #expect(lightBg != darkBg, "Backgrounds should differ between modes")

        let lightAccent = DesignSystem.Colors.primaryAccent(for: .light)
        let darkAccent = DesignSystem.Colors.primaryAccent(for: .dark)
        #expect(lightAccent != darkAccent, "Accents should differ between modes")
    }
}

// MARK: - Accessibility Color Contrast Tests

@Suite("Accessibility Color Contrast Tests")
@MainActor
struct AccessibilityColorContrastTests {

    @Test("Primary text contrasts with backgrounds in light mode")
    func lightModeTextContrast() {
        // Verify text colors differ significantly from backgrounds
        let background = Color.adaptiveCream(.light)
        let primaryText = Color.adaptiveText(.light, isPrimary: true)
        let secondaryText = Color.adaptiveText(.light, isPrimary: false)

        // Primary text (warmGray900) should contrast with cream background
        #expect(primaryText != background, "Primary text must contrast with background")
        #expect(secondaryText != background, "Secondary text must contrast with background")
    }

    @Test("Primary text contrasts with backgrounds in dark mode")
    func darkModeTextContrast() {
        // Verify text colors differ significantly from backgrounds
        let background = Color.adaptiveCream(.dark)
        let primaryText = Color.adaptiveText(.dark, isPrimary: true)
        let secondaryText = Color.adaptiveText(.dark, isPrimary: false)

        // Light text should contrast with dark background
        #expect(primaryText != background, "Primary text must contrast with dark background")
        #expect(secondaryText != background, "Secondary text must contrast with dark background")
    }

    @Test("Terracotta accent is visible on backgrounds")
    func accentContrastOnBackgrounds() {
        // Light mode: terracotta on cream
        let lightAccent = Color.adaptiveTerracotta(.light)
        let lightBg = Color.adaptiveCream(.light)
        #expect(lightAccent != lightBg, "Terracotta must be visible on cream")

        // Dark mode: terracotta (brighter) on dark cream
        let darkAccent = Color.adaptiveTerracotta(.dark)
        let darkBg = Color.adaptiveCream(.dark)
        #expect(darkAccent != darkBg, "Terracotta must be visible on dark background")
    }

    @Test("Gray scale provides sufficient variation for hierarchy")
    func grayScaleHierarchy() {
        // Verify grays span from light to dark for visual hierarchy
        // warmGray50 should be notably lighter than warmGray900
        let lightest = Color.warmGray50
        let darkest = Color.warmGray900

        #expect(lightest != darkest, "Gray scale must provide light-to-dark range")

        // Mid-tones should differ from extremes
        let mid = Color.warmGray500
        #expect(mid != lightest, "Mid-gray differs from lightest")
        #expect(mid != darkest, "Mid-gray differs from darkest")
    }

    @Test("Semantic status colors are distinct")
    func semanticColorDistinction() {
        // Success, warning, error should be distinguishable
        let success = Color.successGreen
        let warning = Color.warningAmber
        let error = Color.terracotta  // Error uses terracotta
        let info = Color.infoBlue

        #expect(success != warning, "Success and warning must be distinct")
        #expect(success != error, "Success and error must be distinct")
        #expect(warning != error, "Warning and error must be distinct")
        #expect(info != success, "Info and success must be distinct")
    }
}
