//
//  RootView.swift
//  CoachMe
//
//  Created by Sumanth Daggubati on 2/6/26.
//

import SwiftUI

/// Root view that switches between auth and main content
/// Handles initial session restoration and authentication state changes
struct RootView: View {
    // MARK: - Constants

    /// Duration to show the splash screen before checking auth state
    /// Provides brief branding exposure without feeling slow
    private static let splashDuration: UInt64 = 500_000_000 // 0.5 seconds in nanoseconds

    // MARK: - State

    @State private var router = Router()
    @State private var authViewModel = AuthViewModel()
    @State private var isCheckingSession = true
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(AppAppearance.storageKey) private var appAppearanceRawValue = AppAppearance.system.rawValue

    var body: some View {
        ZStack {
            // Main content based on router state
            Group {
                switch router.currentScreen {
                case .welcome:
                    WelcomeView(onAuthenticated: {
                        router.navigateToChat()
                    })
                    .transition(.opacity)

                case .chat:
                    ChatView()
                        .transition(.opacity)

                case .conversationList:
                    ConversationListView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: router.currentScreen)

            // Initial loading screen while checking session
            if isCheckingSession {
                sessionCheckOverlay
            }
        }
        .environment(\.router, router)
        .preferredColorScheme(selectedAppearance.colorScheme)
        .task {
            await checkAuthState()
        }
    }

    // MARK: - Private Methods

    /// Check for existing authentication session on app launch
    private func checkAuthState() async {
        // Small delay to show branding briefly
        try? await Task.sleep(nanoseconds: Self.splashDuration)

        await authViewModel.checkExistingSession()

        if authViewModel.isAuthenticated {
            router.navigateToChat()
        }

        // Hide the session check overlay
        withAnimation(.easeOut(duration: 0.3)) {
            isCheckingSession = false
        }
    }

    // MARK: - Subviews

    /// Overlay shown while checking for existing session
    private var sessionCheckOverlay: some View {
        ZStack {
            Color.adaptiveCream(colorScheme)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                // App icon
                Image(systemName: "bubble.left.and.text.bubble.right.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.terracotta)

                // App name
                Text("Coach")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(Color.adaptiveText(colorScheme))

                // Loading indicator
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(Color.adaptiveText(colorScheme))
                    .padding(.top, 8)
            }
        }
        .transition(.opacity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Coach App. Loading...")
    }

    private var selectedAppearance: AppAppearance {
        AppAppearance(rawValue: appAppearanceRawValue) ?? .system
    }
}

// MARK: - Preview

#Preview {
    RootView()
}
