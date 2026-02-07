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

    /// Memory moment peach - UX-4 memory highlight
    /// #FFEDD5 (254, 237, 213) - warm peach cream for personalized moments
    static let memoryPeach = Color(red: 254/255, green: 237/255, blue: 213/255)

    /// Memory moment indicator - subtle terracotta (light mode)
    static let memoryIndicator = Color(red: 194/255, green: 65/255, blue: 12/255).opacity(0.6)

    /// Memory moment indicator for dark mode - warm gold (distinct from warningAmber)
    /// #D4A574 (212, 165, 116) - softer, more muted gold that reads as "memory" not "warning"
    static let memoryIndicatorDark = Color(red: 212/255, green: 165/255, blue: 116/255)

    /// Pattern insight background - subtle sage tint for light mode (UX-5)
    /// Warm, reflective tone — distinct from memory peach
    static let patternSage = Color(red: 230/255, green: 240/255, blue: 230/255)

    /// Pattern insight background for dark mode - warm dark surface variant (UX-5)
    static let patternSageDark = Color(red: 38/255, green: 45/255, blue: 38/255)

    /// Pattern insight indicator - sage green (light mode)
    static let patternIndicator = Color(red: 93/255, green: 143/255, blue: 93/255)

    /// Pattern insight indicator for dark mode - softer sage green
    static let patternIndicatorDark = Color(red: 140/255, green: 190/255, blue: 140/255)

    /// Pattern insight left border - accent-primary sage (UX-5)
    static let patternBorder = Color(red: 93/255, green: 143/255, blue: 93/255)

    // MARK: - Story 3.5: Cross-Domain Pattern Insight Aliases
    // Aliases per Story 3.5 spec naming; same sage palette as patternSage

    /// Cross-domain insight primary color — soft sage green (Task 9.1)
    static let insightSage = patternIndicator

    /// Cross-domain insight subtle background tint (Task 9.2)
    static let insightSageSubtle = patternSage

    // MARK: - Domain Colors (Light Mode)

    /// Life coaching - warm teal (growth, vitality)
    static let domainLife = Color(red: 45/255, green: 148/255, blue: 136/255)

    /// Career coaching - professional slate blue
    static let domainCareer = Color(red: 59/255, green: 102/255, blue: 155/255)

    /// Relationships coaching - warm rose
    static let domainRelationships = Color(red: 186/255, green: 96/255, blue: 114/255)

    /// Mindset coaching - deep warm purple
    static let domainMindset = Color(red: 126/255, green: 87/255, blue: 155/255)

    /// Creativity coaching - vibrant amber-orange
    static let domainCreativity = Color(red: 214/255, green: 132/255, blue: 32/255)

    /// Fitness coaching - energetic green
    static let domainFitness = Color(red: 56/255, green: 142/255, blue: 60/255)

    /// Leadership coaching - rich bronze-gold
    static let domainLeadership = Color(red: 161/255, green: 115/255, blue: 42/255)

    // MARK: - Domain Colors (Dark Mode)

    /// Life coaching dark - brighter teal for contrast
    static let domainLifeDark = Color(red: 72/255, green: 187/255, blue: 173/255)

    /// Career coaching dark - brighter blue
    static let domainCareerDark = Color(red: 90/255, green: 140/255, blue: 200/255)

    /// Relationships coaching dark - brighter rose
    static let domainRelationshipsDark = Color(red: 220/255, green: 130/255, blue: 150/255)

    /// Mindset coaching dark - brighter purple
    static let domainMindsetDark = Color(red: 165/255, green: 125/255, blue: 195/255)

    /// Creativity coaching dark - brighter amber
    static let domainCreativityDark = Color(red: 245/255, green: 166/255, blue: 55/255)

    /// Fitness coaching dark - brighter green
    static let domainFitnessDark = Color(red: 90/255, green: 185/255, blue: 95/255)

    /// Leadership coaching dark - brighter gold
    static let domainLeadershipDark = Color(red: 205/255, green: 155/255, blue: 65/255)

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
