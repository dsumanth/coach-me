//
//  VersionDetection.swift
//  CoachMe
//
//  Created by Dev Agent on 2/5/26.
//

import SwiftUI

// MARK: - Design Mode

/// Represents the current design mode based on iOS version
/// - liquidGlass: iOS 26+ with native Liquid Glass effects
/// - warmModern: iOS 18-25 with SwiftUI materials
enum DesignMode: String, Sendable {
    case liquidGlass
    case warmModern

    /// Human-readable description of the design mode
    var description: String {
        switch self {
        case .liquidGlass:
            return "Liquid Glass (iOS 26+)"
        case .warmModern:
            return "Warm Modern (iOS 18-25)"
        }
    }
}

// MARK: - Environment Key

/// Environment key for injecting DesignMode throughout the view hierarchy
struct DesignModeKey: EnvironmentKey {
    static let defaultValue: DesignMode = {
        if #available(iOS 26, *) {
            return .liquidGlass
        } else {
            return .warmModern
        }
    }()
}

extension EnvironmentValues {
    /// The current design mode based on iOS version
    var designMode: DesignMode {
        get { self[DesignModeKey.self] }
        set { self[DesignModeKey.self] = newValue }
    }
}

// MARK: - Version Detection Utilities

/// Utility struct for iOS version detection
struct VersionDetection {

    /// Returns true if the device supports Liquid Glass (iOS 26+)
    static var supportsLiquidGlass: Bool {
        if #available(iOS 26, *) {
            return true
        }
        return false
    }

    /// Returns the current design mode
    static var currentDesignMode: DesignMode {
        supportsLiquidGlass ? .liquidGlass : .warmModern
    }

    /// Returns true if running on iOS 18 or later
    static var isIOS18OrLater: Bool {
        if #available(iOS 18, *) {
            return true
        }
        return false
    }

    /// Returns the iOS major version number
    static var iOSMajorVersion: Int {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return version.majorVersion
    }
}

// MARK: - View Extension for Design Mode Access

extension View {
    /// Provides access to the current design mode.
    /// @available(*, deprecated, renamed: "withDesignSystem")
    /// Prefer using `withDesignSystem()` from DesignSystem.swift for consistency.
    /// Usage: Use `@Environment(\.designMode)` in views to access
    func withDesignMode() -> some View {
        self.environment(\.designMode, VersionDetection.currentDesignMode)
    }
}
