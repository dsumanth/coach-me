//
//  ContextValue.swift
//  CoachMe
//
//  Story 2.1: Context Profile Data Model & Storage
//  Represents a user's personal value (e.g., "honesty", "family first")
//

import Foundation

/// A personal value in the user's context profile
/// Can be user-entered or extracted from conversations
struct ContextValue: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    var content: String
    var source: ContextSource
    var confidence: Double?
    let addedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case content
        case source
        case confidence
        case addedAt = "added_at"
    }

    // MARK: - Factory Methods

    /// Creates a user-entered value
    /// - Parameter content: The value text
    /// - Returns: A new ContextValue with source .user
    static func userValue(_ content: String) -> ContextValue {
        ContextValue(
            id: UUID(),
            content: content,
            source: .user,
            confidence: nil,
            addedAt: Date()
        )
    }

    /// Creates an AI-extracted value
    /// - Parameters:
    ///   - content: The value text
    ///   - confidence: Confidence score (0.0 to 1.0)
    /// - Returns: A new ContextValue with source .extracted
    static func extractedValue(_ content: String, confidence: Double) -> ContextValue {
        ContextValue(
            id: UUID(),
            content: content,
            source: .extracted,
            confidence: confidence,
            addedAt: Date()
        )
    }
}

/// Source of context data - user-entered or AI-extracted
enum ContextSource: String, Codable, Sendable, Equatable {
    case user = "user"
    case extracted = "extracted"
}
