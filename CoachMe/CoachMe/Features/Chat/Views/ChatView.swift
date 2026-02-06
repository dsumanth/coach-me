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

    // Router available via environment for future navigation (Story 3.7)
    // @Environment(\.router) private var router: Router

    /// Whether to show the "coming soon" toast for history
    @State private var showHistoryToast = false

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
        .task {
            // Set auth token for streaming API calls
            await configureAuthToken()
        }
    }

    // MARK: - Auth Configuration

    /// Configure the auth token for streaming API calls
    private func configureAuthToken() async {
        let token = await AuthService.shared.currentAccessToken
        viewModel.setAuthToken(token)
    }

    // MARK: - Toolbar

    /// Adaptive toolbar with history and new conversation buttons
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

            Spacer()

            // App title
            Text("Coach")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(Color.warmGray900)

            Spacer()

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
