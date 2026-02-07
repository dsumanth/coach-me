//
//  ConversationDetailView.swift
//  CoachMe
//
//  Story 3.7: Read-only conversation detail view showing full message history
//  with a "Continue this conversation" button to reopen in ChatView
//

import SwiftUI

/// Read-only view of a past conversation's messages
/// Pushed within HistoryView's NavigationStack
struct ConversationDetailView: View {
    let conversationId: UUID
    let title: String?
    let domain: String?
    let onContinue: (UUID) -> Void

    @State private var messages: [ChatMessage] = []
    @State private var isLoading = true
    @State private var loadError: Error?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color.adaptiveCream(colorScheme)
                .ignoresSafeArea()

            if isLoading {
                loadingState
            } else if loadError != nil {
                errorState
            } else if messages.isEmpty {
                emptyState
            } else {
                messageList
            }
        }
        .navigationTitle(title ?? "Conversation")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(title ?? "Conversation")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    if domain != nil {
                        DomainBadge(domain: domain)
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            continueButton
        }
        .task {
            await loadMessages()
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(messages) { message in
                    MessageBubble(message: message)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Continue Button

    private var continueButton: some View {
        Button {
            onContinue(conversationId)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.uturn.forward")
                    .font(.system(size: 14, weight: .semibold))
                Text("Continue this conversation")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.adaptiveTerracotta(colorScheme))
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.adaptiveCream(colorScheme))
        .accessibilityLabel("Continue this conversation")
        .accessibilityHint("Reopens this conversation for new messages")
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
        .accessibilityLabel("Loading messages")
    }

    private var errorState: some View {
        EmptyStateView.loadingFailed {
            Task {
                await loadMessages()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false).opacity(0.4))
            Text("No messages in this conversation")
                .font(.headline)
                .foregroundStyle(Color.adaptiveText(colorScheme))
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Data Loading

    private func loadMessages() async {
        isLoading = true
        loadError = nil

        do {
            messages = try await ConversationService.shared.fetchMessages(conversationId: conversationId)
        } catch {
            loadError = error
        }

        isLoading = false
    }
}
