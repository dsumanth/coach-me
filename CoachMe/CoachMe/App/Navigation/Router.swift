//
//  Router.swift
//  CoachMe
//
//  Created by Sumanth Daggubati on 2/6/26.
//

import SwiftUI

/// Navigation coordinator per architecture.md
/// Manages app-level navigation state between authentication and main content.
///
/// Chat ↔ list transitions use NavigationStack (UIKit-level push/pop) to avoid
/// SwiftUI .transition() being stripped by internal .animation(nil, value:)
/// modifiers inside ChatView.  Only the welcome crossfade uses SwiftUI transitions.
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

    /// Optional preloaded messages for selected conversation to render chat body on first frame.
    var selectedConversationPreloadedMessages: [ChatMessage]?

    /// Starter prompt to send when opening chat from inbox suggestions
    var pendingStarterText: String?

    /// Welcome uses a simple crossfade for auth transitions.
    var welcomeTransition: AnyTransition { .opacity }

    // MARK: - Navigation Methods

    /// Navigate to the chat screen.
    /// NavigationStack observes the currentScreen binding and handles the push animation.
    func navigateToChat() {
        selectedConversationId = nil
        selectedConversationPreloadedMessages = nil
        pendingStarterText = nil
        currentScreen = .chat
    }

    /// Navigate to chat with a specific conversation loaded (Story 3.6)
    func navigateToChat(conversationId: UUID, preloadedMessages: [ChatMessage]? = nil) {
        selectedConversationId = conversationId
        selectedConversationPreloadedMessages = preloadedMessages
        pendingStarterText = nil
        currentScreen = .chat
    }

    /// Navigate to chat and prefill/send a starter prompt from inbox
    func navigateToChat(starter: String) {
        selectedConversationId = nil
        selectedConversationPreloadedMessages = nil
        pendingStarterText = starter
        currentScreen = .chat
    }

    /// Navigate to the welcome screen (after sign out or session expiry)
    func navigateToWelcome() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentScreen = .welcome
        }
    }

    /// Navigate to conversation list.
    /// From chat: NavigationStack handles the pop animation natively.
    /// From welcome: uses SwiftUI crossfade transition.
    func navigateToConversationList() {
        if currentScreen == .chat {
            currentScreen = .conversationList
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentScreen = .conversationList
            }
        }
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
