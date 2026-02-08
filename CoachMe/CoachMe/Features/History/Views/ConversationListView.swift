//
//  ConversationListView.swift
//  CoachMe
//
//  Inbox-style home view for conversation threads.
//

import SwiftUI

/// Inbox-style home screen showing conversation threads
struct ConversationListView: View {
    @State private var viewModel = ConversationListViewModel()
    @State private var showSettings = false
    @State private var showContextProfile = false
    @State private var currentUserId: UUID?
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.router) private var router

    /// Callback when a conversation is selected for loading
    var onSelectConversation: ((UUID) -> Void)?

    private let starters = [
        "I've been feeling stuck lately...",
        "I want to make a change but don't know where to start",
        "Help me think through a decision",
        "I need to process something that happened"
    ]

    var body: some View {
        ZStack {
            Color.adaptiveCream(colorScheme)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                if viewModel.isLoading && viewModel.conversations.isEmpty {
                    loadingState
                } else if viewModel.conversations.isEmpty {
                    emptyState
                } else {
                    conversationList
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomActionBar
        }
        .alert("Oops", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.error?.errorDescription ?? "Something went wrong")
        }
        .alert("Remove conversation", isPresented: $viewModel.showDeleteConfirmation) {
            Button("Remove", role: .destructive) {
                Task {
                    await viewModel.confirmDelete()
                }
            }
            Button("Keep it", role: .cancel) {
                viewModel.cancelDelete()
            }
        } message: {
            Text("This will remove our conversation. You sure?")
        }
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
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
            }
        }
        .sheet(isPresented: Binding(
            get: { showContextProfile && currentUserId != nil },
            set: { showContextProfile = $0 }
        )) {
            if let userId = currentUserId {
                ContextProfileView(userId: userId)
            }
        }
        .task {
            await viewModel.loadConversations()
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        ZStack {
            Text("Coach")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.adaptiveText(colorScheme))

            HStack {
                Spacer()

                Menu {
                    Button {
                        Task { @MainActor in
                            currentUserId = await AuthService.shared.currentUserId
                            showContextProfile = currentUserId != nil
                        }
                    } label: {
                        Label("Your profile", systemImage: "person.crop.circle")
                    }

                    Button {
                        showSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                } label: {
                    Circle()
                        .fill(colorScheme == .dark ? Color.warmGray700.opacity(0.62) : Color.white.opacity(0.86))
                        .overlay(
                            Circle()
                                .stroke(
                                    colorScheme == .dark
                                        ? Color.white.opacity(0.16)
                                        : Color.black.opacity(0.07),
                                    lineWidth: 1
                                )
                        )
                        .overlay(
                            Image(systemName: "ellipsis")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                        )
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("More options")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    // MARK: - Content

    private var conversationList: some View {
        List {
            ForEach(viewModel.conversations) { conversation in
                Button {
                    selectConversation(conversation)
                } label: {
                    ConversationRow(
                        conversation: conversation,
                        preview: viewModel.previewText(for: conversation)
                    )
                }
                .buttonStyle(ConversationRowPressStyle())
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        viewModel.requestDelete(conversation)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable {
            await viewModel.refreshConversations()
        }
    }

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.text.bubble.right.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(Color.adaptiveTerracotta(colorScheme).opacity(0.88))
                        .accessibilityHidden(true)

                    Text("What's on your mind?")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(Color.adaptiveText(colorScheme))

                    Text("I'm here to help you reflect, plan, and grow.")
                        .font(.title3)
                        .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 52)

                VStack(spacing: 12) {
                    ForEach(starters, id: \.self) { starter in
                        Button {
                            router.navigateToChat(starter: starter)
                        } label: {
                            Text(starter)
                                .font(.system(size: 17))
                                .foregroundStyle(Color.adaptiveText(colorScheme))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 18)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(colorScheme == .dark ? Color.warmGray700.opacity(0.56) : Color.white.opacity(0.84))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(
                                            colorScheme == .dark
                                                ? Color.white.opacity(0.08)
                                                : Color.black.opacity(0.05),
                                            lineWidth: 1
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 6)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }

    private var loadingState: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(1.1)
                .tint(Color.adaptiveText(colorScheme, isPrimary: false))
            Spacer()
        }
        .accessibilityLabel("Loading conversations")
    }

    // MARK: - Bottom CTA

    private var bottomActionBar: some View {
        VStack(spacing: 0) {
            Divider()
                .opacity(0.08)

            Button {
                startNewConversation()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 16, weight: .semibold))
                    Text("New chat")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    Capsule()
                        .fill(Color.adaptiveTerracotta(colorScheme))
                )
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 10)
            }
            .buttonStyle(.plain)
            .background(Color.adaptiveCream(colorScheme))
        }
    }

    // MARK: - Actions

    private func startNewConversation() {
        router.navigateToChat()
    }

    private func selectConversation(_ conversation: ConversationService.Conversation) {
        onSelectConversation?(conversation.id)
        router.navigateToChat(conversationId: conversation.id)
    }
}

// MARK: - iMessage-Style Row Press Feedback

/// Provides tactile press feedback on conversation rows matching iMessage behavior:
/// fast press-down with subtle scale + dim, slower release back to normal.
private struct ConversationRowPressStyle: ButtonStyle {
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(
                .easeOut(duration: configuration.isPressed ? 0.08 : 0.3),
                value: configuration.isPressed
            )
    }
}
