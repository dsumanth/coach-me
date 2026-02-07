//
//  ExtractedInsight.swift
//  CoachMe
//
//  Story 2.1: Context Profile Data Model & Storage
//  Represents an AI-extracted insight from conversations
//

import Foundation

/// An insight extracted by AI from user conversations
/// Used for progressive context building (Story 2.3)
struct ExtractedInsight: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    var content: String
    var category: InsightCategory
    var confidence: Double
    var sourceConversationId: UUID?
    var confirmed: Bool
    let extractedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case content
        case category
        case confidence
        case sourceConversationId = "source_conversation_id"
        case confirmed
        case extractedAt = "extracted_at"
    }

    // MARK: - Factory Methods

    /// Creates a new extracted insight pending user confirmation
    /// - Parameters:
    ///   - content: The insight text
    ///   - category: Type of insight (value, goal, situation)
    ///   - confidence: Confidence score (0.0 to 1.0)
    ///   - conversationId: Source conversation ID
    /// - Returns: A new unconfirmed ExtractedInsight
    static func pending(
        content: String,
        category: InsightCategory,
        confidence: Double,
        conversationId: UUID? = nil
    ) -> ExtractedInsight {
        ExtractedInsight(
            id: UUID(),
            content: content,
            category: category,
            confidence: confidence,
            sourceConversationId: conversationId,
            confirmed: false,
            extractedAt: Date()
        )
    }

    // MARK: - Mutation Methods

    /// Confirm the insight (user verified it's accurate)
    mutating func confirm() {
        confirmed = true
    }
}

/// Category of extracted insight
enum InsightCategory: String, Codable, Sendable, Equatable {
    case value = "value"
    case goal = "goal"
    case situation = "situation"
    case pattern = "pattern"
}
