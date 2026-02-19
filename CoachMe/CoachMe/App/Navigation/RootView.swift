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
    @State private var onboardingCoordinator = OnboardingCoordinator()
    @State private var isCheckingSession = true
    /// Controls the NavigationStack push for discovery chat.
    /// Starts true so ChatView is shown immediately when the discovery branch renders.
    @State private var isDiscoveryChatPresented = true
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(AppAppearance.storageKey) private var appAppearanceRawValue = AppAppearance.system.rawValue

    // MARK: - Body

    var body: some View {
        ZStack {
            if router.currentScreen == .welcome {
                WelcomeView(onAuthenticated: {
                    // Story 11.3: Route new users to onboarding, returning users to conversation list
                    if onboardingCoordinator.hasCompletedOnboarding {
                        router.navigateToConversationList()
                    } else {
                        router.navigateToOnboarding()
                    }
                })
                .transition(router.welcomeTransition)
            } else if onboardingCoordinator.flowState == .discoveryChat {
                // Story 11.3: Discovery chat in NavigationStack for swipe-back support.
                // Checked BEFORE .onboarding to prevent flash — a single @Observable
                // state change (flowState) drives the switch with no intermediate state.
                NavigationStack {
                    Color.adaptiveCream(colorScheme)
                        .ignoresSafeArea()
                        .toolbar(.hidden, for: .navigationBar)
                        .navigationDestination(isPresented: $isDiscoveryChatPresented) {
                            ChatView(isDiscoveryMode: true)
                                .toolbar(.hidden, for: .navigationBar)
                                .background(InteractivePopGestureEnabler())
                        }
                }
                .transition(.opacity)
            } else if router.currentScreen == .onboarding {
                OnboardingWelcomeView(onBegin: {
                    isDiscoveryChatPresented = true
                    onboardingCoordinator.beginDiscovery()
                })
                .transition(.opacity)
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
        .environment(\.onboardingCoordinator, onboardingCoordinator)
        .preferredColorScheme(selectedAppearance.colorScheme)
        // Detect swipe-back pop from discovery chat NavigationStack.
        // Don't mark onboarding complete — the user hasn't finished discovery.
        // Return to the onboarding welcome screen so they can restart.
        // Discovery completion is ONLY set by the server via [DISCOVERY_COMPLETE].
        .onChange(of: isDiscoveryChatPresented) { _, isPresented in
            if !isPresented {
                onboardingCoordinator.flowState = .welcome
            }
        }
        .task {
            // Story 8.2: Give NotificationRouter access to the app-level Router
            // so notification taps can drive navigation.
            NotificationRouter.shared.appRouter = router
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

        // Repair local push-permission request tracking before auth/UI routing.
        await PushPermissionService.shared.reconcileRequestedFlagWithSystem()

        await authViewModel.checkExistingSession()

        if authViewModel.isAuthenticated {
            // Sync onboarding state with server before routing to catch
            // state mismatches (e.g., force-quit mid-discovery, different device)
            await onboardingCoordinator.syncWithServer()

            // Route: users who completed onboarding → conversation list, otherwise → onboarding
            if onboardingCoordinator.hasCompletedOnboarding {
                router.navigateToConversationList()
            } else {
                router.navigateToOnboarding()
            }

            // Story 8.2: Re-register for push notifications on each launch
            // (token may have changed). Only registers if already authorized.
            await PushNotificationService.shared.registerForRemoteNotificationsIfAuthorized()

            // Story 8.2: Process any notification that launched the app (cold start)
            await NotificationRouter.shared.processPendingNotification()
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
                // Playful App Logo (Meaningful & Branded)
                PlayfulLogoView(size: 80)
                    .padding(.bottom, 8)

                // App name
                Text("CoachMe")
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
        .accessibilityLabel("CoachMe app. Loading...")
    }

    private var selectedAppearance: AppAppearance {
        AppAppearance(rawValue: appAppearanceRawValue) ?? .system
    }
}

// MARK: - Preview

#Preview {
    RootView()
}
