//
//  ContextSituation.swift
//  CoachMe
//
//  Story 2.1: Context Profile Data Model & Storage
//  Represents the user's current life situation
//

import Foundation

/// User's life situation context
/// Flexible structure for various aspects of their current life
struct ContextSituation: Codable, Sendable, Equatable {
    var lifeStage: String?
    var occupation: String?
    var relationships: String?
    var challenges: String?
    var freeform: String?

    enum CodingKeys: String, CodingKey {
        case lifeStage = "life_stage"
        case occupation
        case relationships
        case challenges
        case freeform
    }

    // MARK: - Static Factory

    /// Empty situation with all fields nil
    static let empty = ContextSituation(
        lifeStage: nil,
        occupation: nil,
        relationships: nil,
        challenges: nil,
        freeform: nil
    )

    // MARK: - Computed Properties

    /// Check if any situation content is set
    var hasContent: Bool {
        [lifeStage, occupation, relationships, challenges, freeform]
            .compactMap { $0 }
            .contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    /// Count of filled fields
    var filledFieldCount: Int {
        [lifeStage, occupation, relationships, challenges, freeform]
            .compactMap { $0 }
            .count
    }

    /// Summary text for display (first non-nil field)
    var summary: String? {
        occupation ?? lifeStage ?? relationships ?? challenges ?? freeform
    }
}
