//
//  DeleteConfirmationAlert.swift
//  CoachMe
//
//  Created by Claude Code on 2/7/26.
//
//  Story 2.6: Reusable delete confirmation alert with warm copy
//

import SwiftUI

/// Configuration for delete confirmation alerts with warm, user-friendly copy
/// Per UX-11: Use first-person messages ("I couldn't..." not "Failed to...")
enum DeleteConfirmationAlert {
    /// Type of deletion being confirmed
    enum DeleteType {
        /// Single conversation deletion
        case singleConversation
        /// All conversations deletion (clear all)
        case allConversations
    }

    /// Alert title for the deletion type
    /// - Parameter type: The type of deletion
    /// - Returns: Warm, friendly alert title
    static func title(for type: DeleteType) -> String {
        switch type {
        case .singleConversation:
            return "This will remove our conversation. You sure?"
        case .allConversations:
            return "This will clear all our conversations. Are you sure you want to start fresh?"
        }
    }

    /// Primary (destructive) action button text
    /// - Parameter type: The type of deletion
    /// - Returns: Action button text
    static func primaryActionText(for type: DeleteType) -> String {
        switch type {
        case .singleConversation:
            return "Remove"
        case .allConversations:
            return "Clear All"
        }
    }

    /// Secondary (cancel) action button text
    /// - Returns: Cancel button text (same for all deletion types)
    static var cancelActionText: String {
        "Keep it"
    }
}

// MARK: - View Modifier for Single Conversation Delete

/// View modifier to present a delete confirmation alert for a single conversation
struct SingleConversationDeleteAlert: ViewModifier {
    @Binding var isPresented: Bool
    let onDelete: () -> Void

    func body(content: Content) -> some View {
        content
            .alert(
                DeleteConfirmationAlert.title(for: .singleConversation),
                isPresented: $isPresented
            ) {
                Button(DeleteConfirmationAlert.cancelActionText, role: .cancel) {
                    // Dismiss handled automatically
                }
                Button(DeleteConfirmationAlert.primaryActionText(for: .singleConversation), role: .destructive) {
                    onDelete()
                }
            }
    }
}

// MARK: - View Modifier for All Conversations Delete

/// View modifier to present a delete confirmation alert for all conversations
struct AllConversationsDeleteAlert: ViewModifier {
    @Binding var isPresented: Bool
    let onDelete: () -> Void

    func body(content: Content) -> some View {
        content
            .alert(
                DeleteConfirmationAlert.title(for: .allConversations),
                isPresented: $isPresented
            ) {
                Button(DeleteConfirmationAlert.cancelActionText, role: .cancel) {
                    // Dismiss handled automatically
                }
                Button(DeleteConfirmationAlert.primaryActionText(for: .allConversations), role: .destructive) {
                    onDelete()
                }
            }
    }
}

// MARK: - View Extensions

extension View {
    /// Presents a confirmation alert for deleting a single conversation
    /// - Parameters:
    ///   - isPresented: Binding to control alert visibility
    ///   - onDelete: Closure called when user confirms deletion
    /// - Returns: Modified view with delete confirmation alert
    func singleConversationDeleteAlert(
        isPresented: Binding<Bool>,
        onDelete: @escaping () -> Void
    ) -> some View {
        modifier(SingleConversationDeleteAlert(isPresented: isPresented, onDelete: onDelete))
    }

    /// Presents a confirmation alert for deleting all conversations
    /// - Parameters:
    ///   - isPresented: Binding to control alert visibility
    ///   - onDelete: Closure called when user confirms deletion
    /// - Returns: Modified view with delete confirmation alert
    func allConversationsDeleteAlert(
        isPresented: Binding<Bool>,
        onDelete: @escaping () -> Void
    ) -> some View {
        modifier(AllConversationsDeleteAlert(isPresented: isPresented, onDelete: onDelete))
    }
}

// MARK: - Preview

#Preview("Single Conversation Delete") {
    struct PreviewWrapper: View {
        @State private var showAlert = true

        var body: some View {
            VStack {
                Text("Single Conversation Delete Alert")
                Button("Show Alert") {
                    showAlert = true
                }
            }
            .singleConversationDeleteAlert(isPresented: $showAlert) {
                // Delete action
            }
        }
    }
    return PreviewWrapper()
}

#Preview("All Conversations Delete") {
    struct PreviewWrapper: View {
        @State private var showAlert = true

        var body: some View {
            VStack {
                Text("All Conversations Delete Alert")
                Button("Show Alert") {
                    showAlert = true
                }
            }
            .allConversationsDeleteAlert(isPresented: $showAlert) {
                // Delete action
            }
        }
    }
    return PreviewWrapper()
}
