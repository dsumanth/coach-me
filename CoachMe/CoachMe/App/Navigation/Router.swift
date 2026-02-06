//
//  Router.swift
//  CoachMe
//
//  Created by Sumanth Daggubati on 2/6/26.
//

import SwiftUI

/// Navigation coordinator per architecture.md
/// Manages app-level navigation state between authentication and main content
@MainActor
@Observable
final class Router {
    /// Available screens in the app
    enum Screen: Equatable {
        /// Welcome/authentication screen
        case welcome
        /// Main chat screen (authenticated)
        case chat
    }

    /// Current active screen
    var currentScreen: Screen = .welcome

    // MARK: - Navigation Methods

    /// Navigate to the chat screen (after successful authentication)
    func navigateToChat() {
        currentScreen = .chat
    }

    /// Navigate to the welcome screen (after sign out or session expiry)
    func navigateToWelcome() {
        currentScreen = .welcome
    }

    /// Navigate to conversation history
    /// Note: Will be implemented in Story 3.7
    func navigateToHistory() {
        // Placeholder - conversation history view will be added in Story 3.7
        #if DEBUG
        print("Router: navigateToHistory() called - will be implemented in Story 3.7")
        #endif
    }
}

// MARK: - Environment Key

/// Environment key for injecting Router into the view hierarchy
/// Note: We use an optional Router to detect when it hasn't been properly injected.
/// RootView is responsible for injecting the actual Router instance.
private struct RouterKey: EnvironmentKey {
    // Using a shared instance ensures consistent state if accessed before injection
    // This is safer than creating new instances that could lead to navigation bugs
    @MainActor
    static let defaultValue: Router = {
        #if DEBUG
        print("Warning: Router accessed from environment before being set by RootView")
        #endif
        return Router()
    }()
}

extension EnvironmentValues {
    /// The app's navigation router
    /// Always inject this from RootView to ensure consistent navigation state
    var router: Router {
        get { self[RouterKey.self] }
        set { self[RouterKey.self] = newValue }
    }
}
