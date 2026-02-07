//
//  ContextGoal.swift
//  CoachMe
//
//  Story 2.1: Context Profile Data Model & Storage
//  Represents a user's goal (e.g., "get promoted", "improve relationships")
//

import Foundation

/// A goal in the user's context profile
/// Can be user-entered or extracted from conversations
struct ContextGoal: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    var content: String
    var domain: String?
    var source: ContextSource
    var status: GoalStatus
    let addedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case content
        case domain
        case source
        case status
        case addedAt = "added_at"
    }

    // MARK: - Factory Methods

    /// Creates a user-entered goal
    /// - Parameters:
    ///   - content: The goal description
    ///   - domain: Optional coaching domain (life, career, relationships, etc.)
    /// - Returns: A new ContextGoal with source .user and status .active
    static func userGoal(_ content: String, domain: String? = nil) -> ContextGoal {
        ContextGoal(
            id: UUID(),
            content: content,
            domain: domain,
            source: .user,
            status: .active,
            addedAt: Date()
        )
    }

    /// Creates an AI-extracted goal
    /// - Parameters:
    ///   - content: The goal description
    ///   - domain: Optional coaching domain
    /// - Returns: A new ContextGoal with source .extracted and status .active
    static func extractedGoal(_ content: String, domain: String? = nil) -> ContextGoal {
        ContextGoal(
            id: UUID(),
            content: content,
            domain: domain,
            source: .extracted,
            status: .active,
            addedAt: Date()
        )
    }

    // MARK: - Mutation Methods

    /// Mark goal as achieved
    mutating func markAchieved() {
        status = .achieved
    }

    /// Archive the goal
    mutating func archive() {
        status = .archived
    }

    /// Reactivate an achieved or archived goal
    mutating func reactivate() {
        status = .active
    }
}

/// Status of a goal
enum GoalStatus: String, Codable, Sendable, Equatable {
    case active = "active"
    case achieved = "achieved"
    case archived = "archived"
}
