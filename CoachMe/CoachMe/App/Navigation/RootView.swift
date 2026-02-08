//
//  RootView.swift
//  CoachMe
//
//  Created by Sumanth Daggubati on 2/6/26.
//

import SwiftUI
import UIKit

/// Re-enables the interactive pop gesture when the navigation bar is hidden.
/// UIKit disables it by default when `.toolbar(.hidden)` is used.
private struct InteractivePopGestureEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController { UIViewController() }
    func updateUIViewController(_ controller: UIViewController, context: Context) {
        DispatchQueue.main.async {
            controller.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
            controller.navigationController?.interactivePopGestureRecognizer?.delegate = nil
        }
    }
}

/// Root view that switches between auth and main content.
/// Uses NavigationStack for chat ↔ list transitions so that UIKit-level
/// push/pop animations work regardless of SwiftUI animation modifiers
/// inside ChatView.  Interactive back-swipe comes for free.
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

    // MARK: - Body

    var body: some View {
        ZStack {
            if router.currentScreen == .welcome {
                WelcomeView(onAuthenticated: {
                    router.navigateToConversationList()
                })
                .transition(router.welcomeTransition)
            } else {
                NavigationStack {
                    ConversationListView()
                        .toolbar(.hidden, for: .navigationBar)
                        .navigationDestination(isPresented: chatPresentedBinding) {
                            ChatView(
                                initialConversationId: router.selectedConversationId,
                                initialMessages: router.selectedConversationPreloadedMessages
                            )
                            .toolbar(.hidden, for: .navigationBar)
                            .background(InteractivePopGestureEnabler())
                        }
                }
            }

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

    // MARK: - Bindings

    /// Two-way binding that drives NavigationStack push/pop from Router state.
    /// get: true when chat is active → NavigationStack pushes ChatView.
    /// set: false when user swipes back or pops → Router returns to conversationList.
    private var chatPresentedBinding: Binding<Bool> {
        Binding(
            get: { router.currentScreen == .chat },
            set: { presented in
                if !presented {
                    router.currentScreen = .conversationList
                }
            }
        )
    }

    // MARK: - Private Methods

    /// Check for existing authentication session on app launch
    private func checkAuthState() async {
        // Small delay to show branding briefly
        try? await Task.sleep(nanoseconds: Self.splashDuration)

        await authViewModel.checkExistingSession()

        if authViewModel.isAuthenticated {
            router.navigateToConversationList()
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
