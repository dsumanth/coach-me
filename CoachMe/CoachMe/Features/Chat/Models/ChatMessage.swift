//
//  ChatMessage.swift
//  CoachMe
//
//  Created by Sumanth Daggubati on 2/6/26.
//

import Foundation

/// Represents a single chat message
/// Per architecture.md: Use Codable with CodingKeys for snake_case conversion
struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let conversationId: UUID
    let role: Role
    let content: String
    let createdAt: Date

    enum Role: String, Codable {
        case user
        case assistant
    }

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case role
        case content
        case createdAt = "created_at"
    }

    // MARK: - Static Formatters (Performance Optimization)

    /// Cached date formatter for time display
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    /// Formatted time string for display
    var formattedTime: String {
        Self.timeFormatter.string(from: createdAt)
    }

    /// Convenience property to check if message is from user
    var isFromUser: Bool {
        role == .user
    }

    // MARK: - Factory Methods

    /// Creates a user message with the given content
    /// - Parameters:
    ///   - content: The message text
    ///   - conversationId: The conversation this message belongs to
    /// - Returns: A new ChatMessage with role .user
    static func userMessage(content: String, conversationId: UUID) -> ChatMessage {
        ChatMessage(
            id: UUID(),
            conversationId: conversationId,
            role: .user,
            content: content,
            createdAt: Date()
        )
    }

    /// Creates an assistant message with the given content
    /// - Parameters:
    ///   - content: The message text
    ///   - conversationId: The conversation this message belongs to
    /// - Returns: A new ChatMessage with role .assistant
    static func assistantMessage(content: String, conversationId: UUID) -> ChatMessage {
        ChatMessage(
            id: UUID(),
            conversationId: conversationId,
            role: .assistant,
            content: content,
            createdAt: Date()
        )
    }
}
