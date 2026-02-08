//
//  HistoryView.swift
//  CoachMe
//
//  Story 3.7: Sheet-based conversation history view with NavigationStack
//  Presents conversation list with drill-down to ConversationDetailView
//

import SwiftUI

/// Sheet-based conversation history view
/// Presented from ChatView's toolbar menu as a modal sheet
struct HistoryView: View {
    @State private var viewModel = ConversationListViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    /// Callback when user taps "Continue this conversation"
    var onContinueConversation: ((UUID) -> Void)?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.adaptiveCream(colorScheme)
                    .ignoresSafeArea()

                if viewModel.isLoading && viewModel.conversations.isEmpty {
                    loadingState
                } else if viewModel.error != nil && viewModel.conversations.isEmpty {
                    EmptyStateView.loadingFailed {
                        Task {
                            await viewModel.loadConversations()
                        }
                    }
                } else if viewModel.conversations.isEmpty {
                    EmptyStateView.noHistory {
                        dismiss()
                    }
                } else {
                    conversationList
                }
            }
            .navigationTitle("Your Conversations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(Color.adaptiveTerracotta(colorScheme))
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
        }
        .task {
            await viewModel.loadConversations()
        }
    }

    // MARK: - Conversation List

    private var conversationList: some View {
        List {
            ForEach(viewModel.conversations) { conversation in
                NavigationLink(value: conversation) {
                    ConversationRow(
                        conversation: conversation,
                        preview: viewModel.previewText(for: conversation)
                    )
                }
                .listRowBackground(Color.clear)
                .listRowSeparatorTint(Color.adaptiveText(colorScheme, isPrimary: false).opacity(0.15))
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        viewModel.requestDelete(conversation)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .accessibilityLabel("Delete conversation")
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable {
            await viewModel.refreshConversations()
        }
        .navigationDestination(for: ConversationService.Conversation.self) { conversation in
            ConversationDetailView(
                conversationId: conversation.id,
                title: conversation.title,
                domain: conversation.domain,
                onContinue: { conversationId in
                    dismiss()
                    onContinueConversation?(conversationId)
                }
            )
        }
    }

    // MARK: - Loading State

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
}
