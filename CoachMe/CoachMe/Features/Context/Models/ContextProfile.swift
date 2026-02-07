//
//  ContextProfile.swift
//  CoachMe
//
//  Story 2.1: Context Profile Data Model & Storage
//  Per architecture.md: Use Codable with CodingKeys for snake_case conversion
//

import Foundation

/// User's context profile for personalized coaching
/// Stores values, goals, life situation, and extracted insights
struct ContextProfile: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    let userId: UUID
    var values: [ContextValue]
    var goals: [ContextGoal]
    var situation: ContextSituation
    var extractedInsights: [ExtractedInsight]
    var contextVersion: Int
    var firstSessionComplete: Bool
    var promptDismissedCount: Int
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case values
        case goals
        case situation
        case extractedInsights = "extracted_insights"
        case contextVersion = "context_version"
        case firstSessionComplete = "first_session_complete"
        case promptDismissedCount = "prompt_dismissed_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // MARK: - Factory Methods

    /// Creates an empty context profile for a new user
    /// - Parameter userId: The user's ID
    /// - Returns: A new empty ContextProfile
    static func empty(userId: UUID) -> ContextProfile {
        ContextProfile(
            id: UUID(),
            userId: userId,
            values: [],
            goals: [],
            situation: .empty,
            extractedInsights: [],
            contextVersion: 1,
            firstSessionComplete: false,
            promptDismissedCount: 0,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    // MARK: - Computed Properties

    /// Check if profile has any context set
    var hasContext: Bool {
        !values.isEmpty || !goals.isEmpty || situation.hasContent
    }

    /// Count of all context items (values + goals)
    var totalContextItems: Int {
        values.count + goals.count
    }

    /// Active goals only
    var activeGoals: [ContextGoal] {
        goals.filter { $0.status == .active }
    }

    // MARK: - Mutation Helpers

    /// Add a new value to the profile
    mutating func addValue(_ value: ContextValue) {
        values.append(value)
        updatedAt = Date()
    }

    /// Add a new goal to the profile
    mutating func addGoal(_ goal: ContextGoal) {
        goals.append(goal)
        updatedAt = Date()
    }

    /// Remove a value by ID
    mutating func removeValue(id: UUID) {
        values.removeAll { $0.id == id }
        updatedAt = Date()
    }

    /// Remove a goal by ID
    mutating func removeGoal(id: UUID) {
        goals.removeAll { $0.id == id }
        updatedAt = Date()
    }
}

/// Minimal insert struct for creating new profiles in Supabase
/// Only includes required fields - Supabase will use defaults for others
struct ContextProfileInsert: Codable, Sendable {
    let userId: UUID

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
    }

    init(userId: UUID) {
        self.userId = userId
    }
}
