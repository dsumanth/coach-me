//
//  AppAppearance.swift
//  CoachMe
//
//  Created by Codex on 2/7/26.
//

import SwiftUI

/// User-selectable app appearance mode.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let storageKey = "app_appearance_mode"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system:
            return "System Default"
        case .light:
            return "White"
        case .dark:
            return "Dark"
        }
    }

    var shortLabel: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "White"
        case .dark:
            return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}
