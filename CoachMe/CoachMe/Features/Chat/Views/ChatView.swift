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

    // Router available via environment for future navigation (Story 3.7)
    // @Environment(\.router) private var router: Router

    /// Whether to show the "coming soon" toast for history
    @State private var showHistoryToast = false

    /// Whether to show the context profile sheet (Story 2.5)
    @State private var showContextProfile = false

    /// Whether to show the settings view (Story 2.6)
    @State private var showSettings = false

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
            Color.cream
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Adaptive toolbar
                chatToolbar

                // Message list or empty state
                if viewModel.messages.isEmpty {
                    emptyState
                } else {
                    messageList
                }

                // Input area with voice support
                MessageInput(viewModel: viewModel, voiceViewModel: voiceViewModel)
            }

            // History coming soon toast
            if showHistoryToast {
                historyToast
                    .transition(.move(edge: .top).combined(with: .opacity))
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
        // Context prompt sheet (Story 2.2)
        .sheet(isPresented: $contextPromptViewModel.showPrompt) {
            ContextPromptSheet(
                onAccept: {
                    contextPromptViewModel.acceptPrompt()
                },
                onDismiss: {
                    Task {
                        await contextPromptViewModel.dismissPrompt()
                    }
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
        .sheet(isPresented: $showContextProfile) {
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
                // Trigger context prompt (Story 2.2)
                contextPromptViewModel.onAIResponseReceived()

                // Trigger context extraction (Story 2.3)
                if let conversationId = viewModel.currentConversationId {
                    insightSuggestionsViewModel.onAIResponseReceived(
                        conversationId: conversationId,
                        messages: viewModel.messages
                    )
                }
            }
        }
        .task {
            // Set auth token for streaming API calls
            await configureAuthToken()
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
    }

    // MARK: - Toolbar

    /// Adaptive toolbar with history, insights, and new conversation buttons
    private var chatToolbar: some View {
        HStack {
            // History button
            Button(action: showHistoryComingSoon) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.warmGray700)
                    .frame(width: 44, height: 44)
            }
            .adaptiveInteractiveGlass()
            .accessibilityLabel("View conversation history")
            .accessibilityHint("Opens your past conversations. Coming soon.")

            // Insights indicator (Story 2.3) - shows when pending insights exist
            if insightSuggestionsViewModel.hasPendingInsights {
                Button(action: showInsightsSuggestions) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Color.terracotta)
                            .frame(width: 44, height: 44)

                        // Badge with count
                        if insightSuggestionsViewModel.pendingCount > 0 {
                            Text("\(min(insightSuggestionsViewModel.pendingCount, 9))")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 18, height: 18)
                                .background(Color.terracotta)
                                .clipShape(Circle())
                                .offset(x: 6, y: 4)
                        }
                    }
                }
                .adaptiveInteractiveGlass()
                .accessibilityLabel("View insights")
                .accessibilityHint("You have \(insightSuggestionsViewModel.pendingCount) insights I'd like to confirm with you")
                .transition(.scale.combined(with: .opacity))
            }

            Spacer()

            // App title
            Text("Coach")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(Color.warmGray900)

            Spacer()

            // Profile button (Story 2.5)
            Button(action: showProfile) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.warmGray700)
                    .frame(width: 44, height: 44)
            }
            .adaptiveInteractiveGlass()
            .accessibilityLabel("View your profile")
            .accessibilityHint("Opens your context profile to see what I remember about you")

            // More options menu (Story 2.6)
            Menu {
                // Delete current conversation (Task 4.1)
                Button(role: .destructive) {
                    viewModel.showDeleteConfirmation = true
                } label: {
                    Label("Delete conversation", systemImage: "trash")
                }
                .accessibilityHint("Shows confirmation to delete this conversation")

                // Settings (Task 5.5)
                Button {
                    showSettings = true
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.warmGray700)
                    .frame(width: 44, height: 44)
            }
            .adaptiveInteractiveGlass()
            .accessibilityLabel("More options")
            .accessibilityHint("Opens menu with delete and settings options")

            // New conversation button
            Button(action: startNewConversation) {
                Image(systemName: "plus.bubble")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.warmGray700)
                    .frame(width: 44, height: 44)
            }
            .adaptiveInteractiveGlass()
            .accessibilityLabel("Start new conversation")
            .accessibilityHint("Starts a fresh conversation with your coach")
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
                        MessageBubble(message: message)
                            .id(message.id)
                    }

                    // Typing indicator when loading but not yet streaming
                    if viewModel.isLoading && !viewModel.isStreaming {
                        TypingIndicator()
                            .id("typing-indicator")
                    }

                    // Streaming message bubble when streaming or can retry
                    if viewModel.isStreaming || viewModel.canRetry {
                        StreamingMessageBubble(
                            content: viewModel.streamingContent,
                            isStreaming: viewModel.isStreaming,
                            onRetry: viewModel.canRetry ? {
                                Task {
                                    await viewModel.retryLastMessage()
                                }
                            } : nil
                        )
                        .id("streaming-bubble")
                    }

                    // Invisible anchor for scrolling
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(.top, 8)
            }
            .refreshable {
                // Pull-to-refresh for syncing (Task 1.5)
                // Will integrate with sync service in Story 7.3
                await viewModel.refresh()
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.isLoading) { _, isLoading in
                if isLoading {
                    scrollToBottom(proxy: proxy)
                }
            }
            .onChange(of: viewModel.isStreaming) { _, isStreaming in
                if isStreaming {
                    scrollToBottom(proxy: proxy)
                }
            }
            .onChange(of: viewModel.streamingContent) { _, _ in
                // Auto-scroll as content streams in
                scrollToBottom(proxy: proxy)
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

    // MARK: - Toast

    /// Toast shown when history button is tapped
    private var historyToast: some View {
        VStack {
            Text("Conversation history coming soon!")
                .font(.subheadline.weight(.medium))
                .foregroundColor(Color.warmGray900)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.warmGray100)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                .padding(.top, 60)

            Spacer()
        }
        .accessibilityLabel("Conversation history coming soon")
    }

    // MARK: - Actions

    /// Shows a toast that history is coming soon
    private func showHistoryComingSoon() {
        withAnimation(.spring(duration: 0.3)) {
            showHistoryToast = true
        }

        // Auto-dismiss after 2 seconds
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation(.spring(duration: 0.3)) {
                showHistoryToast = false
            }
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

    /// Scrolls to the bottom of the message list
    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }
}

// MARK: - Preview

#Preview {
    ChatView()
}
