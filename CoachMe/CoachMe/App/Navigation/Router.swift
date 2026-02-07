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
        /// Conversation list/history screen (Story 3.6)
        case conversationList
    }

    /// Current active screen
    var currentScreen: Screen = .welcome

    /// Conversation ID to load when navigating back to chat from conversation list
    var selectedConversationId: UUID?

    // MARK: - Navigation Methods

    /// Navigate to the chat screen (after successful authentication)
    func navigateToChat() {
        selectedConversationId = nil
        currentScreen = .chat
    }

    /// Navigate to chat with a specific conversation loaded (Story 3.6)
    /// - Parameter conversationId: The conversation to load in ChatView
    func navigateToChat(conversationId: UUID) {
        selectedConversationId = conversationId
        currentScreen = .chat
    }

    /// Navigate to the welcome screen (after sign out or session expiry)
    func navigateToWelcome() {
        currentScreen = .welcome
    }

    /// Navigate to conversation list (Story 3.6)
    /// Note: History is now sheet-based from ChatView (Story 3.7).
    /// This method and .conversationList screen are kept for potential future tab-based navigation refactor.
    func navigateToConversationList() {
        currentScreen = .conversationList
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
