//
//  Colors.swift
//  CoachMe
//
//  Created by Sumanth Daggubati on 2/5/26.
//

import SwiftUI

extension Color {
    // MARK: - Light Mode Base Colors

    /// Warm cream background - NOT sterile white
    static let cream = Color(red: 254/255, green: 247/255, blue: 237/255)

    /// Primary accent - warm terracotta
    static let terracotta = Color(red: 194/255, green: 65/255, blue: 12/255)

    // MARK: - Dark Mode Base Colors

    /// Warm dark background - NOT pure black (#000000)
    /// RGB: 30, 28, 24 - maintains warmth in dark mode
    static let creamDark = Color(red: 30/255, green: 28/255, blue: 24/255)

    /// Brighter terracotta for dark mode contrast
    static let terracottaDark = Color(red: 234/255, green: 88/255, blue: 12/255)

    // MARK: - Accent Color Variations

    /// Soft sage green accent
    static let sage = Color(red: 143/255, green: 159/255, blue: 143/255)

    /// Warm dusty rose accent
    static let dustyRose = Color(red: 199/255, green: 163/255, blue: 163/255)

    /// Warm amber accent
    static let amber = Color(red: 217/255, green: 119/255, blue: 6/255)

    // MARK: - Semantic Colors

    /// Success state - warm forest green
    static let successGreen = Color(red: 34/255, green: 139/255, blue: 34/255)

    /// Warning state - warm amber
    static let warningAmber = Color(red: 217/255, green: 119/255, blue: 6/255)

    /// Info state - warm steel blue (not cold tech blue)
    static let infoBlue = Color(red: 70/255, green: 130/255, blue: 180/255)

    /// Subtle highlight - very light warm
    static let subtleHighlight = Color(red: 255/255, green: 251/255, blue: 235/255)

    // MARK: - Dark Mode Surface Colors

    /// Light surface in dark mode
    static let surfaceLightDark = Color(red: 40/255, green: 38/255, blue: 34/255)

    /// Medium surface in dark mode
    static let surfaceMediumDark = Color(red: 50/255, green: 48/255, blue: 44/255)

    // MARK: - Warm Grays (full scale for chat UI)

    static let warmGray50 = Color(red: 250/255, green: 249/255, blue: 247/255)
    static let warmGray100 = Color(red: 245/255, green: 243/255, blue: 240/255)
    static let warmGray200 = Color(red: 232/255, green: 229/255, blue: 224/255)
    static let warmGray300 = Color(red: 214/255, green: 211/255, blue: 204/255)
    static let warmGray400 = Color(red: 169/255, green: 165/255, blue: 156/255)
    static let warmGray500 = Color(red: 124/255, green: 120/255, blue: 111/255)
    static let warmGray600 = Color(red: 95/255, green: 91/255, blue: 82/255)
    static let warmGray700 = Color(red: 70/255, green: 67/255, blue: 59/255)
    static let warmGray800 = Color(red: 46/255, green: 42/255, blue: 34/255)
    static let warmGray900 = Color(red: 26/255, green: 24/255, blue: 20/255)

    // MARK: - Adaptive Color Accessors

    /// Returns cream or creamDark based on color scheme
    static func adaptiveCream(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? creamDark : cream
    }

    /// Returns terracotta adjusted for color scheme
    static func adaptiveTerracotta(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? terracottaDark : terracotta
    }

    /// Returns appropriate surface color for color scheme
    static func adaptiveSurface(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? surfaceLightDark : warmGray50
    }

    /// Returns appropriate text color for color scheme
    static func adaptiveText(_ colorScheme: ColorScheme, isPrimary: Bool = true) -> Color {
        if colorScheme == .dark {
            return isPrimary ? warmGray100 : warmGray400
        } else {
            return isPrimary ? warmGray900 : warmGray600
        }
    }
}
