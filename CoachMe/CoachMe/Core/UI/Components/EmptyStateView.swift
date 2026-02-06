//
//  EmptyStateView.swift
//  CoachMe
//
//  Created by Dev Agent on 2/6/26.
//

import SwiftUI

/// Reusable empty state component with warm personality
/// Per UX spec: Empty states have personality with warm copy
struct EmptyStateView: View {
    // MARK: - Properties

    /// SF Symbol name for the icon
    let icon: String

    /// Title text - warm and inviting
    let title: String

    /// Message text - conversational, not technical
    let message: String

    /// Optional action button title
    var actionTitle: String? = nil

    /// Optional action callback
    var action: (() -> Void)? = nil

    // MARK: - Environment

    @SwiftUI.Environment(\.colorScheme) private var colorScheme

    // MARK: - Body

    var body: some View {
        VStack(spacing: 24) {
            // Warm icon treatment
            Image(systemName: icon)
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Color.warmGray400)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(title)
                    .font(Typography.emptyStateTitle)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(Typography.body)
                    .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(Typography.button)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.adaptiveTerracotta(colorScheme))
                        .clipShape(Capsule())
                }
                .padding(.top, 8)
                .accessibilityHint("Double tap to \(actionTitle.lowercased())")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
    }
}

// MARK: - Predefined Empty States

extension EmptyStateView {
    /// Empty conversation history
    static func noHistory(onStartChat: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "bubble.left.and.bubble.right",
            title: "No conversations yet",
            message: "Your coaching journey starts with a single message. What's on your mind?",
            actionTitle: "Start a Conversation",
            action: onStartChat
        )
    }

    /// Empty search results
    static func noSearchResults() -> EmptyStateView {
        EmptyStateView(
            icon: "magnifyingglass",
            title: "Nothing found",
            message: "I couldn't find what you're looking for. Try different words?"
        )
    }

    /// Offline state
    static func offline() -> EmptyStateView {
        EmptyStateView(
            icon: "wifi.slash",
            title: "You're offline",
            message: "Your past conversations are here — new coaching needs a connection."
        )
    }

    /// No context profile yet
    static func noContext(onSetup: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "person.crop.circle.badge.questionmark",
            title: "Want me to remember you?",
            message: "Share what matters to you and I'll personalize your coaching experience.",
            actionTitle: "Set Up My Profile",
            action: onSetup
        )
    }

    /// Empty creator dashboard
    static func noPersonas(onCreate: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "person.2.badge.gearshape",
            title: "No coaching personas yet",
            message: "Create your own coaching style and share it with others.",
            actionTitle: "Create a Coach",
            action: onCreate
        )
    }

    /// Generic loading failed state
    static func loadingFailed(onRetry: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "arrow.clockwise",
            title: "Couldn't load that",
            message: "I had trouble loading this content. Let's try again?",
            actionTitle: "Try Again",
            action: onRetry
        )
    }
}

// MARK: - Preview

#Preview("Empty States") {
    ScrollView {
        VStack(spacing: 40) {
            EmptyStateView.noHistory { print("Start chat") }
                .frame(height: 300)

            Divider()

            EmptyStateView.noSearchResults()
                .frame(height: 250)

            Divider()

            EmptyStateView.offline()
                .frame(height: 250)

            Divider()

            EmptyStateView.noContext { print("Setup") }
                .frame(height: 300)
        }
        .padding()
    }
    .background(Color.cream)
}

#Preview("Empty State - Dark Mode") {
    EmptyStateView.noHistory { print("Start chat") }
        .frame(height: 300)
        .background(Color.creamDark)
        .preferredColorScheme(.dark)
}
