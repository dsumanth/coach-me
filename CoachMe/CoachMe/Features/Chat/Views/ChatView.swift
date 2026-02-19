//
//  ChatView.swift
//  CoachMe
//
//  Created by Sumanth Daggubati on 2/6/26.
//

import SwiftUI
import UIKit

/// Main chat screen with adaptive toolbar
/// Per architecture.md: Apply adaptive design modifiers, never raw .glassEffect()
struct ChatView: View {
    // MARK: - Dependencies (Injected for testability)

    /// Chat view model - injected for testing/previews, defaults to new instance
    @State private var viewModel: ChatViewModel

    /// Voice input view model - injected for testing/previews, defaults to new instance
    @State private var voiceViewModel: VoiceInputViewModel

    /// Context prompt view model - manages context setup prompt flow (Story 2.2)
    @State private var contextPromptViewModel = ContextPromptViewModel()

    /// Insight suggestions view model - manages progressive context extraction (Story 2.3)
    @State private var insightSuggestionsViewModel = InsightSuggestionsViewModel()

    /// Router for navigation (Story 3.6)
    @Environment(\.router) private var router

    /// Onboarding coordinator for discovery flow (Story 11.3)
    @Environment(\.onboardingCoordinator) private var onboardingCoordinator

    /// Whether to show the discovery paywall overlay (Story 11.3 → 11.5: PersonalizedPaywallView)
    @State private var showDiscoveryPaywall = false

    /// Hoisted VM for discovery paywall overlay — persists across view updates (Story 11.5)
    @State private var discoveryPaywallVM: PersonalizedPaywallViewModel?

    /// Whether to show the return paywall sheet (Story 11.5: user dismissed first paywall, taps send)
    @State private var showReturnPaywall = false

    /// Whether to show the context profile sheet (Story 2.5)
    @State private var showContextProfile = false

    /// Whether to show the settings view (Story 2.6)
    @State private var showSettings = false

    /// Whether to show the paywall sheet (Story 6.2)
    @State private var showPaywall = false

    /// Usage tracking view model (Story 10.5)
    @State private var usageViewModel = UsageViewModel()

    /// Whether to show the usage detail sheet (Story 10.5)
    @State private var showUsageDetail = false

    /// Shared subscription state (Story 6.2)
    private var subscriptionViewModel: SubscriptionViewModel {
        AppEnvironment.shared.subscriptionViewModel
    }

    /// Scene phase for detecting background transitions (Story 8.3)
    @Environment(\.scenePhase) private var scenePhase

    /// Network connectivity monitor (Story 7.2)
    private var networkMonitor = NetworkMonitor.shared

    /// True while opening a routed conversation so we avoid flashing the empty-state.
    @State private var isOpeningRoutedConversation = false

    /// True once initial route intent has been resolved for this ChatView lifetime.
    @State private var hasResolvedInitialRoute = false

    /// Combined routing intent ID — changes trigger the .task to re-run
    private var routeTaskId: String {
        "\(router.selectedConversationId?.uuidString ?? "")-\(router.pendingStarterText ?? "")"
    }

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Initialization

    /// Creates a ChatView with injectable dependencies
    /// - Parameters:
    ///   - viewModel: Chat view model (defaults to new instance)
    ///   - voiceViewModel: Voice input view model (defaults to new instance)
    init(
        viewModel: ChatViewModel = ChatViewModel(),
        voiceViewModel: VoiceInputViewModel = VoiceInputViewModel(),
        initialConversationId: UUID? = nil,
        initialMessages: [ChatMessage]? = nil,
        isDiscoveryMode: Bool = false
    ) {
        // Reuse an active ViewModel if the conversation has an in-flight stream.
        // This prevents losing AI responses when the user navigates away mid-stream
        // and returns to the same conversation.
        if let initialConversationId,
           let activeVM = ChatViewModel.activeViewModel(for: initialConversationId) {
            _viewModel = State(initialValue: activeVM)
        } else {
            if let initialConversationId, let initialMessages {
                // Prime preloaded thread before first render to prevent chat-body fade.
                _ = viewModel.primeConversationFromPreloaded(id: initialConversationId, messages: initialMessages)
            } else if let initialConversationId {
                // Fallback: prime from local cache before first render.
                _ = viewModel.primeConversationFromCache(id: initialConversationId)
            }
            // Story 11.3: Set discovery mode and add welcome message before first render.
            // Must happen BEFORE _viewModel = State(...) so messages is never empty
            // on the first frame — prevents the EmptyConversationView flash.
            if isDiscoveryMode {
                viewModel.isDiscoveryMode = true
                viewModel.showDiscoveryWelcomeMessage()
            }
            _viewModel = State(initialValue: viewModel)
        }
        _voiceViewModel = State(initialValue: voiceViewModel)
    }

    var body: some View {
        ZStack {
            // Warm background
            Color.adaptiveCream(colorScheme)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Adaptive toolbar
                chatToolbar

                // Banner priority: Offline > UsageIndicator > TrialBanner (Story 7.2, 10.5)
                if !networkMonitor.isConnected {
                    OfflineBanner()
                        .transition(.move(edge: .top).combined(with: .opacity))
                } else if usageViewModel.displayState != .hidden {
                    // Story 10.5: Usage indicator — handles both paid threshold and trial message display
                    UsageIndicator(viewModel: usageViewModel, showDetail: $showUsageDetail)
                } else if case .trialActive = TrialManager.shared.currentState {
                    // Story 10.3: Trial banner fallback — only when usage hasn't loaded yet
                    TrialBanner(
                        onViewPlans: { showPaywall = true }
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Message list or empty state
                Group {
                    if viewModel.messages.isEmpty {
                        if shouldShowConversationLoadingState {
                            loadingConversationState
                        } else {
                            emptyState
                        }
                    } else {
                        messageList
                    }
                }
                .animation(nil, value: shouldShowConversationLoadingState)
                .animation(nil, value: viewModel.messages.isEmpty)
            }
            .animation(.easeInOut(duration: DesignConstants.Animation.standard), value: networkMonitor.isConnected)

            if contextPromptViewModel.showPrompt {
                contextPromptOverlay
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(20)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if viewModel.isTrialBlocked && shouldShowComposer {
                // Story 10.3: Post-discovery blocked — show warm message and paywall
                trialExpiredPrompt
                    .background(composerDockBackground)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if viewModel.isRateLimited && shouldShowComposer {
                // Story 10.1: Rate limited — show warm message instead of composer (AC #5)
                rateLimitedPrompt
                    .background(composerDockBackground)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if subscriptionViewModel.shouldGateChat && shouldShowComposer {
                // Trial expired gate — show gentle prompt instead of composer (Story 6.2)
                trialExpiredPrompt
                    .background(composerDockBackground)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if viewModel.discoveryPaywallDismissed && !subscriptionViewModel.isSubscribed && shouldShowComposer {
                // Story 11.5: Discovery-gated — disable composer, route to personalized return paywall
                discoveryGatedPrompt
                    .background(composerDockBackground)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if shouldShowComposer {
                VStack(spacing: 0) {
                    if contextPromptViewModel.showSuggestionChip {
                        contextSuggestionChip
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    MessageInput(viewModel: viewModel, voiceViewModel: voiceViewModel)
                }
                .background(composerDockBackground)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        // Chat error alert
        .alert("Oops", isPresented: $viewModel.showError) {
            Button("Try Again", role: .cancel) {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.error?.errorDescription ?? "Something went wrong")
        }
        // Voice input error alert
        .alert("Voice Input", isPresented: $voiceViewModel.showError) {
            Button("OK", role: .cancel) {
                voiceViewModel.dismissError()
            }
            if voiceViewModel.error == .permissionDenied || voiceViewModel.error == .microphonePermissionDenied {
                Button("Open Settings") {
                    voiceViewModel.dismissError()
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        } message: {
            Text(voiceViewModel.error?.errorDescription ?? "Something went wrong with voice input")
        }
        // Voice permission sheet
        .sheet(isPresented: $voiceViewModel.showPermissionSheet) {
            VoiceInputPermissionSheet(
                onEnable: {
                    Task {
                        await voiceViewModel.requestPermissions()
                    }
                },
                onDismiss: {
                    voiceViewModel.dismissPermissionSheet()
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        // Context setup form sheet (Story 2.2)
        .sheet(isPresented: $contextPromptViewModel.showSetupForm) {
            ContextSetupForm(
                onSave: { values, goals, situation in
                    Task {
                        await contextPromptViewModel.saveInitialContext(
                            values: values,
                            goals: goals,
                            situation: situation
                        )
                    }
                },
                onSkip: {
                    Task {
                        await contextPromptViewModel.skipSetup()
                    }
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        // Context error alert
        .alert("Context Setup", isPresented: $contextPromptViewModel.showError) {
            Button("OK", role: .cancel) {
                contextPromptViewModel.dismissError()
            }
        } message: {
            Text(contextPromptViewModel.error?.errorDescription ?? "Something went wrong saving your context")
        }
        // Insight suggestions sheet (Story 2.3)
        .sheet(isPresented: $insightSuggestionsViewModel.showSuggestions) {
            InsightSuggestionsSheet(
                insights: insightSuggestionsViewModel.pendingInsights,
                onConfirm: { id in
                    Task {
                        await insightSuggestionsViewModel.confirmInsight(id: id)
                    }
                },
                onDismiss: { id in
                    Task {
                        await insightSuggestionsViewModel.dismissInsight(id: id)
                    }
                },
                onDismissAll: {
                    insightSuggestionsViewModel.dismissAll()
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        // Insight error alert (Story 2.3)
        .alert("Insights", isPresented: $insightSuggestionsViewModel.showError) {
            Button("OK", role: .cancel) {
                insightSuggestionsViewModel.dismissError()
            }
        } message: {
            Text(insightSuggestionsViewModel.error?.errorDescription ?? "Something went wrong with insights")
        }
        // Context profile sheet (Story 2.5)
        .sheet(isPresented: Binding(
            get: { showContextProfile && contextPromptViewModel.userId != nil },
            set: { showContextProfile = $0 }
        )) {
            if let userId = contextPromptViewModel.userId {
                ContextProfileView(userId: userId)
            } else {
                VStack(spacing: 12) {
                    Text("Unable to load profile")
                        .font(.headline)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text("Please sign in to view your profile.")
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .presentationDetents([.medium])
            }
        }
        // Settings sheet (Story 2.6)
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
            }
        }
        // Paywall sheet (Story 6.2 + 6.3 + 11.3)
        .sheet(isPresented: $showPaywall) {
            PaywallView(
                subscriptionViewModel: subscriptionViewModel,
                context: subscriptionViewModel.currentPaywallContext,
                packages: subscriptionViewModel.subscriptionOnlyPackages
            ) { purchaseSucceeded in
                if purchaseSucceeded {
                    // Story 11.3: Notify onboarding coordinator of subscription
                    if viewModel.isDiscoveryMode {
                        onboardingCoordinator.onSubscriptionConfirmed()
                        onboardingCoordinator.completeOnboarding()
                    }

                    // Story 6.3 — Task 4.4: Handle post-purchase via explicit callback
                    if viewModel.pendingMessage != nil {
                        Task {
                            await viewModel.sendPendingMessage()
                        }
                    }
                } else {
                    viewModel.pendingMessage = nil
                }
            }
        }
        // Story 11.5: Return paywall sheet — shown when dismissed user taps send
        .sheet(isPresented: $showReturnPaywall) {
            NavigationStack {
                PersonalizedPaywallView(
                    viewModel: PersonalizedPaywallViewModel(
                        presentation: .returnPresentation(discoveryContext: viewModel.discoveryPaywallContext)
                    ),
                    subscriptionViewModel: subscriptionViewModel,
                    onPurchaseCompleted: { success in
                        if success {
                            showReturnPaywall = false
                            onboardingCoordinator.onSubscriptionConfirmed()
                            onboardingCoordinator.completeOnboarding()
                            if viewModel.pendingMessage != nil {
                                Task {
                                    await viewModel.sendPendingMessage()
                                }
                            }
                        }
                    },
                    onDismiss: {
                        showReturnPaywall = false
                    }
                )
            }
        }
        // Crisis resource sheet (Story 4.2)
        .sheet(isPresented: $viewModel.showCrisisResources) {
            CrisisResourceSheet()
        }
        // Push permission prompt sheet (Story 8.3)
        .sheet(isPresented: $viewModel.showPushPermissionPrompt) {
            PushPermissionPromptView(
                onAccept: {
                    Task {
                        // Request iOS permission (records the request regardless of outcome)
                        await PushPermissionService.shared.requestPermissionIfNeeded()

                        // Save default notification preferences regardless of grant/deny.
                        // The user expressed interest — store their preference even if iOS
                        // permission was denied so Settings shows correct state.
                        if let userId = await AuthService.shared.currentUserId {
                            do {
                                var profile = try await ContextRepository.shared.fetchProfile(userId: userId)
                                profile.notificationPreferences = .default()
                                try await ContextRepository.shared.updateProfile(profile)
                            } catch {
                                #if DEBUG
                                print("PushPermissionPrompt: Failed to save notification preferences — \(error.localizedDescription)")
                                #endif
                            }
                        }
                    }
                },
                onDecline: {
                    PushPermissionService.shared.markPromptDismissedThisSession()
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        // Delete conversation confirmation alert (Story 2.6 - Task 4.2)
        .singleConversationDeleteAlert(isPresented: $viewModel.showDeleteConfirmation) {
            Task {
                await viewModel.deleteConversation()
            }
        }
        // Loading overlay during deletion (Story 2.6 - Task 4.3)
        .overlay {
            if viewModel.isDeleting {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(.white)
                    }
                    .accessibilityLabel("Removing conversation")
            }
        }
        // Story 11.3: Discovery paywall overlay — chat visible behind semi-transparent material
        .overlay {
            if showDiscoveryPaywall {
                discoveryPaywallOverlay
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: showDiscoveryPaywall)
        // Detect when AI response completes to trigger context prompt (Story 2.2) and extraction (Story 2.3)
        .onChange(of: viewModel.isStreaming) { wasStreaming, isStreaming in
            // Story 10.5: Optimistic usage increment when a message is sent (streaming starts)
            if !wasStreaming && isStreaming {
                usageViewModel.onMessageSent()
            }

            // When streaming ends (transitions from true to false)
            if wasStreaming && !isStreaming {
                // Only trigger post-response flows when an assistant message was actually delivered.
                guard viewModel.messages.last?.role == .assistant else { return }

                // Trigger context prompt (Story 2.2)
                contextPromptViewModel.onAIResponseReceived()

                // Trigger context extraction (Story 2.3)
                if let conversationId = viewModel.currentConversationId {
                    insightSuggestionsViewModel.onAIResponseReceived(
                        conversationId: conversationId,
                        messages: viewModel.messages
                    )
                }

                // Story 4.2: Show crisis resource sheet when crisis was detected
                if viewModel.currentResponseHasCrisisFlag {
                    viewModel.showCrisisResources = true
                }

                // Story 11.3/11.5: Show discovery paywall when discovery completes.
                // Works in both discovery and non-discovery mode — handles the edge case
                // where a user reaches chat through conversation list before completing discovery.
                if viewModel.discoveryComplete {
                    // H3 fix: Pass discovery context to coordinator for return paywall scenarios
                    if viewModel.isDiscoveryMode {
                        if let context = viewModel.discoveryPaywallContext {
                            onboardingCoordinator.onDiscoveryComplete(with: context)
                        } else {
                            onboardingCoordinator.onDiscoveryComplete()
                        }
                    }
                    // Hoist VM: create once when paywall is shown so state persists across renders
                    discoveryPaywallVM = PersonalizedPaywallViewModel(
                        presentation: .firstPresentation(
                            discoveryContext: viewModel.discoveryPaywallContext ?? DiscoveryPaywallContext(
                                coachingDomain: nil, ahaInsight: nil, keyTheme: nil, userName: nil
                            )
                        )
                    )
                    showDiscoveryPaywall = true
                }
            }
        }
        .onChange(of: contextPromptViewModel.showPrompt) { _, isShowingPrompt in
            if isShowingPrompt {
                dismissKeyboard()
            }
        }
        .onChange(of: shouldShowComposer) { _, isVisible in
            if !isVisible {
                dismissKeyboard()
            }
        }
        // Story 6.3 — Task 4.3: Bridge ViewModel paywall trigger to local sheet state
        // Story 11.5: Route to personalized return paywall when in discovery mode
        .onChange(of: viewModel.showPaywall) { _, shouldShow in
            if shouldShow {
                if viewModel.isDiscoveryMode && viewModel.discoveryPaywallDismissed {
                    // Task 3.6: Show return paywall as sheet when dismissed user taps send
                    showReturnPaywall = true
                } else {
                    showPaywall = true
                }
                viewModel.showPaywall = false
            }
        }
        .task(id: routeTaskId) {
            let routedConversationId = router.selectedConversationId
            let routedStarter = router.pendingStarterText
            let hasRouteIntent = routedConversationId != nil || routedStarter != nil

            if hasRouteIntent {
                isOpeningRoutedConversation = true
                hasResolvedInitialRoute = false
            } else {
                hasResolvedInitialRoute = true
            }

            if let conversationId = routedConversationId {
                // For conversation opens, load cache/messages first so UI appears instantly.
                let alreadyPrimedForRoute =
                    viewModel.currentConversationId == conversationId &&
                    !viewModel.messages.isEmpty

                let primedFromCache = alreadyPrimedForRoute || viewModel.primeConversationFromCache(id: conversationId)
                async let authConfiguration: Void = configureAuthToken()
                await viewModel.loadConversation(
                    id: conversationId,
                    alreadyPrimedFromCache: primedFromCache
                )
                _ = await authConfiguration
                router.selectedConversationId = nil
                router.selectedConversationPreloadedMessages = nil
            } else if let starter = routedStarter {
                // Starter prompts need auth configured before send/stream.
                await configureAuthToken()
                await viewModel.sendMessage(starter)
                router.pendingStarterText = nil
            } else {
                // No route intent, just bootstrap auth/context services.
                await configureAuthToken()
            }

            isOpeningRoutedConversation = false
            hasResolvedInitialRoute = true
        }
        .contentShape(Rectangle())
        // Story 10.5: Refresh usage data on appear
        .task {
            await usageViewModel.refreshUsage()
        }
        // Story 10.5: Usage detail sheet
        .sheet(isPresented: $showUsageDetail) {
            UsageDetailSheet(viewModel: usageViewModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        // Story 8.3: Trigger push permission check when app goes to background
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .inactive || newPhase == .background {
                viewModel.onAppBackgrounded()
            }
        }
        // Story 8.1: Record session engagement when user navigates away from chat
        .onDisappear {
            viewModel.onSessionEnd()
        }
    }

    // MARK: - Auth Configuration

    /// Configure the auth token for streaming API calls and context prompt
    private func configureAuthToken() async {
        let token = await AuthService.shared.currentAccessToken
        viewModel.setAuthToken(token)

        // Configure context prompt with current user (Story 2.2)
        if let userId = await AuthService.shared.currentUserId {
            await contextPromptViewModel.configure(userId: userId)

            // Configure insight suggestions with current user (Story 2.3)
            insightSuggestionsViewModel.setAuthToken(token)
            await insightSuggestionsViewModel.configure(userId: userId)
        }

        // Check trial/subscription status (Story 6.2)
        await subscriptionViewModel.checkTrialStatus()
    }

    /// Full-screen overlay for the context prompt.
    /// Uses a single custom pane instead of system sheet chrome to keep liquid-glass appearance.
    private var contextPromptOverlay: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Color.black.opacity(promptBackdropOpacity)
                    .ignoresSafeArea()

                ContextPromptSheet(
                    onAccept: {
                        contextPromptViewModel.acceptPrompt()
                    },
                    onDismiss: {
                        Task {
                            await contextPromptViewModel.dismissPrompt()
                        }
                    },
                    onClose: {
                        Task {
                            await contextPromptViewModel.dismissPrompt()
                        }
                    }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, max(proxy.safeAreaInsets.bottom, 12))
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            dismissKeyboard()
        }
    }

    private var promptBackdropOpacity: Double {
        if #available(iOS 26, *) {
            return 0.05
        } else {
            return 0.10
        }
    }

    // MARK: - Toolbar

    /// Adaptive toolbar with history, insights, and new conversation buttons
    private var chatToolbar: some View {
        ZStack {
            // App title
            Text("CoachMe")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(Color.adaptiveText(colorScheme))

            HStack {
                // Back to inbox button
                Button {
                    navigateToInbox()
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                colorScheme == .dark
                                    ? Color.warmGray700.opacity(0.42)
                                    : Color.white.opacity(0.78)
                                )
                        Circle()
                            .stroke(
                                colorScheme == .dark
                                    ? Color.white.opacity(0.2)
                                    : Color.black.opacity(0.08),
                                lineWidth: 1
                            )
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                    }
                    .frame(width: 36, height: 36)
                }
                .accessibilityLabel("Back to inbox")
                .accessibilityHint("Returns to your conversation list")

                Spacer()

                // Overflow menu for secondary/occasional actions
                Menu {
                    Button {
                        showProfile()
                    } label: {
                        Label("Your profile", systemImage: "person.crop.circle")
                    }

                    if insightSuggestionsViewModel.hasPendingInsights {
                        Button {
                            showInsightsSuggestions()
                        } label: {
                            Label(
                                "Review insights (\(insightSuggestionsViewModel.pendingCount))",
                                systemImage: "sparkles"
                            )
                        }
                    }

                    Button {
                        showSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }

                    if canDeleteCurrentConversation {
                        Button(role: .destructive) {
                            viewModel.showDeleteConfirmation = true
                        } label: {
                            Label("Delete conversation", systemImage: "trash")
                        }
                        .accessibilityHint("Shows confirmation to delete this conversation")
                    }
                } label: {
                    ZStack(alignment: .topTrailing) {
                        ZStack {
                            Circle()
                                .fill(
                                    colorScheme == .dark
                                        ? Color.warmGray700.opacity(0.42)
                                        : Color.white.opacity(0.78)
                                )
                            Circle()
                                .stroke(
                                    colorScheme == .dark
                                        ? Color.white.opacity(0.2)
                                        : Color.black.opacity(0.08),
                                    lineWidth: 1
                                )
                            Image(systemName: "ellipsis")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                        }
                        .frame(width: 36, height: 36)

                        if insightSuggestionsViewModel.pendingCount > 0 {
                            Text("\(min(insightSuggestionsViewModel.pendingCount, 9))")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 16, height: 16)
                                .background(Color.terracotta)
                                .clipShape(Circle())
                                .offset(x: 4, y: -2)
                        }
                    }
                }
                .accessibilityLabel("More options")
                .accessibilityHint("Opens conversation actions, settings, and history")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .animation(.spring(duration: 0.3), value: insightSuggestionsViewModel.hasPendingInsights)
    }

    // MARK: - Message List

    /// Scrollable list of messages with auto-scroll to bottom and pull-to-refresh
    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.messages) { message in
                        messageBubble(for: message)
                            .id(message.id)
                    }

                    // iMessage-style typing indicator while coach is preparing a response.
                    if viewModel.isLoading || viewModel.isStreaming {
                        TypingIndicator()
                            .id("typing-indicator")
                    }

                    // Invisible anchor for scrolling
                    Color.clear
                        .frame(height: 24)
                        .id("bottom")
                }
                .padding(.top, 8)
                .padding(.bottom, 8)
            }
            .transaction { transaction in
                if isOpeningRoutedConversation || !hasResolvedInitialRoute {
                    transaction.animation = nil
                    transaction.disablesAnimations = true
                }
            }
            .animation(nil, value: viewModel.messages.count)
            .animation(nil, value: viewModel.messages.last?.id)
            .refreshable {
                // Pull-to-refresh for syncing (Task 1.5)
                // Will integrate with sync service in Story 7.3
                await viewModel.refresh()
            }
            .onAppear {
                scrollToBottomDeferred(proxy: proxy, animated: false)
            }
            .onChange(of: viewModel.currentConversationId) { _, _ in
                // When opening a different thread, always jump to latest first.
                scrollToBottomDeferred(proxy: proxy, animated: false)
            }
            .onChange(of: viewModel.messages.last?.id) { _, _ in
                // Handles cache->server replacement where count may not change.
                scrollToNewMessage(
                    proxy: proxy,
                    animated: !(isOpeningRoutedConversation || !hasResolvedInitialRoute)
                )
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToNewMessage(
                    proxy: proxy,
                    animated: !(isOpeningRoutedConversation || !hasResolvedInitialRoute)
                )
            }
            .onChange(of: viewModel.isLoading) { _, isLoading in
                if isLoading {
                    scrollToBottomDeferred(proxy: proxy)
                }
            }
            .onChange(of: viewModel.isStreaming) { _, isStreaming in
                if isStreaming {
                    scrollToBottomDeferred(proxy: proxy)
                }
            }
            .onReceive(NotificationCenter.default.publisher(
                for: UIResponder.keyboardWillChangeFrameNotification
            )) { _ in
                DispatchQueue.main.async {
                    scrollToBottomDeferred(proxy: proxy)
                }
            }
        }
    }

    /// Empty state with conversation starters
    private var emptyState: some View {
        ScrollView {
            EmptyConversationView { starter in
                Task {
                    await viewModel.sendMessage(starter)
                }
            }
            .padding(.top, 40)
        }
    }

    private var loadingConversationState: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(1.1)
                .tint(Color.adaptiveText(colorScheme, isPrimary: false))
            Spacer()
        }
        .accessibilityLabel("Loading conversation")
    }

    @ViewBuilder
    private func messageBubble(for message: ChatMessage) -> some View {
        MessageBubble(
            message: message,
            isFailedToSend: message.isFromUser && viewModel.isMessageDeliveryFailed(message.id),
            onRetry: message.isFromUser ? {
                Task {
                    await viewModel.retryFailedMessage(message.id)
                }
            } : nil,
            feedbackSentiment: message.role == .assistant ? viewModel.feedbackSentiment(for: message.id) : nil,
            isSubmittingFeedback: message.role == .assistant ? viewModel.isSubmittingFeedback(for: message.id) : false,
            onFeedback: assistantFeedbackHandler(for: message)
        )
    }

    private func assistantFeedbackHandler(for message: ChatMessage) -> ((MessageFeedbackSentiment) -> Void)? {
        guard message.role == .assistant else { return nil }
        return { sentiment in
            Task {
                await viewModel.submitAssistantMessageFeedback(
                    messageID: message.id,
                    sentiment: sentiment
                )
            }
        }
    }

    /// Inline suggestion chip for context setup.
    /// This appears before showing the full sheet so the user opts in.
    private var contextSuggestionChip: some View {
        HStack(spacing: 12) {
            Image(systemName: "heart.text.clipboard.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.terracotta)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(Color.terracotta.opacity(0.14))
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Help me personalize coaching")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .lineLimit(1)

                Text("Add what matters to you")
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button("Add") {
                contextPromptViewModel.openPromptFromSuggestion()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.terracotta)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(
                Capsule()
                    .fill(Color.terracotta.opacity(0.13))
            )
            .accessibilityHint("Opens a short setup to personalize your coaching")

            Button {
                contextPromptViewModel.dismissSuggestionChip()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(
                                colorScheme == .dark
                                    ? Color.warmGray700.opacity(0.8)
                                    : Color.warmGray100.opacity(0.9)
                            )
                    )
            }
            .accessibilityLabel("Dismiss suggestion")
            .accessibilityHint("Hides this reminder for now")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .modifier(SuggestionChipSurfaceModifier())
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    colorScheme == .dark
                        ? Color.white.opacity(0.16)
                        : Color.white.opacity(0.22),
                    lineWidth: 1
                )
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Personalization suggestion")
    }

    // MARK: - Trial Expired Prompt (Story 6.2, Story 10.4: context-aware copy)

    /// Gentle prompt shown instead of composer when trial has expired or messages are exhausted.
    /// Story 10.4: Shows context-specific copy based on PaywallContext.
    /// Users can still read past conversations but need to subscribe to send new messages.
    private var trialExpiredPrompt: some View {
        VStack(spacing: 12) {
            Text(trialGatedCopy)
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .multilineTextAlignment(.center)

            Button {
                showPaywall = true
            } label: {
                Text(trialGatedButtonLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        Capsule()
                            .fill(Color.terracotta)
                    )
            }
            .accessibilityLabel(trialGatedButtonLabel)
            .accessibilityHint("Subscribe to continue sending messages")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    /// Story 10.4: Context-aware gated copy — warm, first-person per UX-11
    private var trialGatedCopy: String {
        switch subscriptionViewModel.currentPaywallContext {
        case .messagesExhausted:
            return "You've used all your conversations — subscribe to keep the momentum going."
        case .cancelled:
            return "Your coach is still here — ready to pick up where you left off"
        case .trialExpired, .generic:
            return "You've experienced what CoachMe can do — keep the conversation going"
        }
    }

    /// Story 10.4: Context-aware button label
    private var trialGatedButtonLabel: String {
        switch subscriptionViewModel.currentPaywallContext {
        case .messagesExhausted:
            return "See plans"
        default:
            return "View plans"
        }
    }

    // MARK: - Discovery Gated Prompt (Story 11.5 — H1 fix)

    /// Prompt shown when user dismissed the discovery paywall without subscribing.
    /// Routes to the personalized return paywall (AC #6), NOT the generic PaywallView.
    private var discoveryGatedPrompt: some View {
        VStack(spacing: 12) {
            Text("Your coach is still here — pick up where you left off")
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .multilineTextAlignment(.center)

            Button {
                showReturnPaywall = true
            } label: {
                Text("Continue my coaching journey")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        Capsule()
                            .fill(Color.terracotta)
                    )
            }
            .accessibilityLabel("Continue my coaching journey")
            .accessibilityHint("Opens personalized subscription options")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Rate Limited Prompt (Story 10.1)

    /// Warm prompt shown instead of composer when user has reached their message limit.
    /// Paid users see their reset date; trial users see a subscribe CTA.
    private var rateLimitedPrompt: some View {
        VStack(spacing: 12) {
            Text(viewModel.error?.errorDescription ?? "You've reached your message limit for now.")
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .multilineTextAlignment(.center)

            if case .rateLimited(let isTrial, _) = viewModel.error, isTrial {
                Button {
                    showPaywall = true
                } label: {
                    Text("Subscribe")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            Capsule()
                                .fill(Color.terracotta)
                        )
                }
                .accessibilityLabel("Subscribe")
                .accessibilityHint("Subscribe to continue sending messages")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Discovery Paywall Overlay (Story 11.5)

    /// Semi-transparent overlay with personalized paywall. Chat remains visible underneath.
    /// Uses PersonalizedPaywallView with .firstPresentation mode and discovery context.
    private var discoveryPaywallOverlay: some View {
        ZStack {
            // Semi-transparent backdrop — coach's last message visible underneath (Task 3.3)
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.85)
                .ignoresSafeArea()

            PersonalizedPaywallView(
                viewModel: discoveryPaywallVM ?? PersonalizedPaywallViewModel(
                    presentation: .firstPresentation(
                        discoveryContext: viewModel.discoveryPaywallContext ?? DiscoveryPaywallContext(
                            coachingDomain: nil, ahaInsight: nil, keyTheme: nil, userName: nil
                        )
                    )
                ),
                subscriptionViewModel: subscriptionViewModel,
                onPurchaseCompleted: { success in
                    if success {
                        // Task 3.4: Purchase success → dismiss overlay, send pending message
                        showDiscoveryPaywall = false
                        onboardingCoordinator.onSubscriptionConfirmed()
                        onboardingCoordinator.completeOnboarding()
                        if viewModel.pendingMessage != nil {
                            Task {
                                await viewModel.sendPendingMessage()
                            }
                        }
                    }
                },
                onDismiss: {
                    // Task 3.5: Dismiss → set discoveryPaywallDismissed, disable MessageInput
                    showDiscoveryPaywall = false
                    viewModel.discoveryPaywallDismissed = true
                    onboardingCoordinator.onPaywallDismissed()
                }
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Personalized coaching subscription offer")
    }

    // MARK: - Actions

    /// Navigates back to inbox-style conversation list.
    /// For discovery mode: marks onboarding complete so the user's conversation
    /// is accessible on next launch (instead of restarting onboarding).
    private func navigateToInbox() {
        if viewModel.isDiscoveryMode {
            onboardingCoordinator.completeOnboarding()
            onboardingCoordinator.flowState = .paidChat
        }
        router.navigateToConversationList()
    }


    /// Starts a new conversation
    private func startNewConversation() {
        viewModel.startNewConversation()
        contextPromptViewModel.resetSessionCount()
        insightSuggestionsViewModel.resetResponseCount()  // Story 2.3
    }

    /// Shows the insight suggestions sheet (Story 2.3)
    private func showInsightsSuggestions() {
        insightSuggestionsViewModel.showSuggestionsSheet()
    }

    /// Shows the context profile sheet (Story 2.5)
    private func showProfile() {
        showContextProfile = true
    }

    /// Hides composer whenever popups/sheets are active so it never overlays modal UI.
    private var shouldShowComposer: Bool {
        !contextPromptViewModel.showPrompt &&
        !voiceViewModel.showPermissionSheet &&
        !contextPromptViewModel.showSetupForm &&
        !insightSuggestionsViewModel.showSuggestions &&
        !showContextProfile &&
        !showSettings &&
        !showDiscoveryPaywall &&  // Story 11.3: Hide composer during discovery paywall
        !showReturnPaywall  // Story 11.5: Hide composer during return paywall
    }

    private var shouldShowConversationLoadingState: Bool {
        guard viewModel.messages.isEmpty else { return false }

        return !hasResolvedInitialRoute ||
            viewModel.isLoading ||
            isOpeningRoutedConversation ||
            router.selectedConversationId != nil ||
            router.pendingStarterText != nil
    }

    /// Delete is only relevant when there is actual conversation content on screen.
    private var canDeleteCurrentConversation: Bool {
        !viewModel.messages.isEmpty
    }

    /// Opaque composer dock so chat content never shows through behind the input row.
    private var composerDockBackground: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(
                    colorScheme == .dark
                        ? Color.white.opacity(0.08)
                        : Color.black.opacity(0.07)
                )
                .frame(height: 0.5)

            Rectangle()
                .fill(
                    colorScheme == .dark
                        ? Color.black.opacity(0.94)
                        : Color.white.opacity(0.985)
                )
        }
        .ignoresSafeArea(edges: .bottom)
    }

    /// Dismisses keyboard from anywhere in the view hierarchy.
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )

        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .forEach { $0.endEditing(true) }

        DispatchQueue.main.async {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .forEach { $0.endEditing(true) }
        }
    }

    /// Scrolls to the bottom of the message list
    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool = true) {
        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        } else {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }

    private func scrollToBottomDeferred(proxy: ScrollViewProxy, animated: Bool = true) {
        DispatchQueue.main.async {
            scrollToBottom(proxy: proxy, animated: animated)
        }

        // Second pass catches layout that finishes one frame later on initial load.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            scrollToBottom(proxy: proxy, animated: animated)
        }
    }

    /// Intelligently scrolls based on the last message:
    /// - User messages: scroll to bottom to show typing indicator
    /// - Assistant messages: scroll to top of message so user can read from the beginning
    private func scrollToNewMessage(proxy: ScrollViewProxy, animated: Bool = true) {
        guard let lastMessage = viewModel.messages.last else {
            scrollToBottomDeferred(proxy: proxy, animated: animated)
            return
        }

        if lastMessage.isFromUser {
            // User message: scroll to bottom to show their message + typing indicator
            scrollToBottomDeferred(proxy: proxy, animated: animated)
        } else {
            // Assistant message: scroll to the TOP of the message so user reads from the start
            let messageId = lastMessage.id

            let scrollAction = {
                if animated {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(messageId, anchor: .top)
                    }
                } else {
                    proxy.scrollTo(messageId, anchor: .top)
                }
            }

            DispatchQueue.main.async {
                scrollAction()
            }

            // Second pass catches layout that finishes one frame later
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                scrollAction()
            }
        }
    }
}

private struct SuggestionChipSurfaceModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

        if #available(iOS 26, *) {
            content
                .background {
                    shape
                        .fill(.clear)
                        .glassEffect(.regular, in: shape)
                    shape
                        .fill(
                            colorScheme == .dark
                                ? Color.black.opacity(0.26)
                                : Color.white.opacity(0.2)
                        )
                }
                .clipShape(shape)
        } else {
            content
                .background(
                    shape.fill(
                        colorScheme == .dark
                            ? Color.warmGray800.opacity(0.88)
                            : Color.warmGray50.opacity(0.95)
                    )
                )
                .clipShape(shape)
        }
    }
}

// MARK: - Preview

#Preview {
    ChatView()
}
