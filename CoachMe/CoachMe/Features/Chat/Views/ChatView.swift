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

    /// Whether to show the context profile sheet (Story 2.5)
    @State private var showContextProfile = false

    /// Whether to show the settings view (Story 2.6)
    @State private var showSettings = false

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
        voiceViewModel: VoiceInputViewModel = VoiceInputViewModel()
    ) {
        _viewModel = State(initialValue: viewModel)
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

                // Message list or empty state
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

            if contextPromptViewModel.showPrompt {
                contextPromptOverlay
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(20)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if shouldShowComposer {
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
            }
        }
        // Settings sheet (Story 2.6)
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
            }
        }
        // Crisis resource sheet (Story 4.2)
        .sheet(isPresented: $viewModel.showCrisisResources) {
            CrisisResourceSheet()
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
        // Detect when AI response completes to trigger context prompt (Story 2.2) and extraction (Story 2.3)
        .onChange(of: viewModel.isStreaming) { wasStreaming, isStreaming in
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
                router.selectedConversationId = nil
                async let authConfiguration: Void = configureAuthToken()
                await viewModel.loadConversation(id: conversationId)
                _ = await authConfiguration
            } else if let starter = routedStarter {
                // Starter prompts need auth configured before send/stream.
                router.pendingStarterText = nil
                await configureAuthToken()
                await viewModel.sendMessage(starter)
            } else {
                // No route intent, just bootstrap auth/context services.
                await configureAuthToken()
            }

            isOpeningRoutedConversation = false
            hasResolvedInitialRoute = true
        }
        .contentShape(Rectangle())
        .simultaneousGesture(backToInboxSwipeGesture)
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
            Text("Coach")
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
                        MessageBubble(
                            message: message,
                            isFailedToSend: message.isFromUser && viewModel.isMessageDeliveryFailed(message.id),
                            onRetry: message.isFromUser ? {
                                Task {
                                    await viewModel.retryFailedMessage(message.id)
                                }
                            } : nil
                        )
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
                scrollToBottomDeferred(proxy: proxy, animated: false)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToBottomDeferred(proxy: proxy)
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
            .onChange(of: viewModel.streamingContent) { _, _ in
                // Auto-scroll as content streams in
                scrollToBottomDeferred(proxy: proxy)
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

    // MARK: - Actions

    /// Navigates back to inbox-style conversation list.
    private func navigateToInbox() {
        router.navigateToConversationList()
    }

    /// iMessage-style left-edge swipe back gesture.
    /// Only triggers from the leading edge and when horizontal intent is clear.
    private var backToInboxSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 18, coordinateSpace: .local)
            .onEnded { value in
                let startedFromLeftEdge = value.startLocation.x <= 28
                let horizontalDistance = value.translation.width
                let verticalDistance = abs(value.translation.height)
                let predictedHorizontalDistance = value.predictedEndTranslation.width
                let hasBackIntent = horizontalDistance > 72 || predictedHorizontalDistance > 120
                let horizontalDominant = horizontalDistance > verticalDistance

                guard startedFromLeftEdge, hasBackIntent, horizontalDominant else { return }

                navigateToInbox()
            }
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
        !showSettings
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
