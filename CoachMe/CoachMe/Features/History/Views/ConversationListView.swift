//
//  ConversationListView.swift
//  CoachMe
//
//  Story 3.6: Conversation list view showing all conversations
//  organized by recency with domain badges and message previews
//

import SwiftUI

/// Conversation history list with swipe-to-delete and conversation selection
struct ConversationListView: View {
    @State private var viewModel = ConversationListViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.router) private var router

    /// Callback when a conversation is selected for loading
    var onSelectConversation: ((UUID) -> Void)?

    var body: some View {
        ZStack {
            Color.adaptiveCream(colorScheme)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Navigation bar
                navigationBar

                if viewModel.isLoading && viewModel.conversations.isEmpty {
                    loadingState
                } else if viewModel.conversations.isEmpty {
                    emptyState
                } else {
                    conversationList
                }
            }
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
        .task {
            await viewModel.loadConversations()
        }
    }

    // MARK: - Navigation Bar

    private var navigationBar: some View {
        ZStack {
            Text("Conversations")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(Color.adaptiveText(colorScheme))

            HStack {
                Button {
                    router.navigateToChat()
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
                .accessibilityLabel("Back to chat")

                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Conversation List

    private var conversationList: some View {
        List {
            ForEach(viewModel.conversations) { conversation in
                ConversationRow(conversation: conversation)
                    .listRowBackground(Color.clear)
                    .listRowSeparatorTint(Color.adaptiveText(colorScheme, isPrimary: false).opacity(0.15))
                    .onTapGesture {
                        selectConversation(conversation)
                    }
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

    // MARK: - States

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

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false).opacity(0.4))

            Text("No conversations yet")
                .font(.headline)
                .foregroundStyle(Color.adaptiveText(colorScheme))

            Text("Start one!")
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))

            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No conversations yet. Start one!")
    }

    // MARK: - Actions

    private func selectConversation(_ conversation: ConversationService.Conversation) {
        onSelectConversation?(conversation.id)
        router.navigateToChat(conversationId: conversation.id)
    }
}
