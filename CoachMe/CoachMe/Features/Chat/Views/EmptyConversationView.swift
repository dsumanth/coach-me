//
//  EmptyConversationView.swift
//  CoachMe
//
//  Created by Sumanth Daggubati on 2/6/26.
//

import SwiftUI

/// Empty state when no messages exist
/// Per architecture.md: Empty states with personality (UX-9)
struct EmptyConversationView: View {
    /// Callback when a conversation starter is tapped
    let onStarterTapped: (String) -> Void

    /// Conversation starter prompts
    private let starters = [
        "I've been feeling stuck lately...",
        "I want to make a change but don't know where to start",
        "Help me think through a decision",
        "I need to process something that happened"
    ]

    var body: some View {
        VStack(spacing: 32) {
            // Welcome message
            welcomeSection

            // Conversation starters
            startersSection
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Subviews

    /// Welcome header with icon and text
    private var welcomeSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.text.bubble.right.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.terracotta.opacity(0.8))
                .accessibilityHidden(true)

            Text("What's on your mind?")
                .font(.title2.weight(.semibold))
                .foregroundColor(Color.warmGray900)

            Text("I'm here to help you reflect, plan, and grow.")
                .font(.subheadline)
                .foregroundColor(Color.warmGray700)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("What's on your mind? I'm here to help you reflect, plan, and grow.")
    }

    /// Grid of conversation starter buttons
    private var startersSection: some View {
        VStack(spacing: 12) {
            ForEach(starters, id: \.self) { starter in
                Button(action: { onStarterTapped(starter) }) {
                    Text(starter)
                        .font(.subheadline)
                        .foregroundColor(Color.warmGray800)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.warmGray100)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .accessibilityLabel("Start with: \(starter)")
                .accessibilityHint("Tapping this will start your conversation with this message")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.cream.ignoresSafeArea()

        EmptyConversationView { starter in
            print("Selected: \(starter)")
        }
    }
}
