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
    var coachingPreferences: CoachingPreferences = .empty
    var notificationPreferences: NotificationPreference?
    // Story 11.4: Discovery session fields
    var discoveryCompletedAt: Date?
    var ahaInsight: String?
    var coachingDomains: [String]
    var currentChallenges: [String]
    var emotionalBaseline: String?
    var communicationStyle: String?
    var keyThemes: [String]
    var strengthsIdentified: [String]
    var vision: String?
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
        case coachingPreferences = "coaching_preferences"
        case notificationPreferences = "notification_preferences"
        case discoveryCompletedAt = "discovery_completed_at"
        case ahaInsight = "aha_insight"
        case coachingDomains = "coaching_domains"
        case currentChallenges = "current_challenges"
        case emotionalBaseline = "emotional_baseline"
        case communicationStyle = "communication_style"
        case keyThemes = "key_themes"
        case strengthsIdentified = "strengths_identified"
        case vision
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
            coachingPreferences: .empty,
            notificationPreferences: nil,
            discoveryCompletedAt: nil,
            ahaInsight: nil,
            coachingDomains: [],
            currentChallenges: [],
            emotionalBaseline: nil,
            communicationStyle: nil,
            keyThemes: [],
            strengthsIdentified: [],
            vision: nil,
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

    /// Story 11.4: Whether this profile has data from a discovery session
    /// Checks both timestamp AND at least one substantive field extracted
    var hasDiscoveryData: Bool {
        discoveryCompletedAt != nil && (
            ahaInsight?.isEmpty == false ||
            !coachingDomains.isEmpty ||
            vision?.isEmpty == false ||
            communicationStyle?.isEmpty == false ||
            !keyThemes.isEmpty ||
            !strengthsIdentified.isEmpty ||
            !currentChallenges.isEmpty ||
            emotionalBaseline?.isEmpty == false
        )
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

// MARK: - Backward-compatible decoding (Story 8.1, Story 11.4)

extension ContextProfile {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        values = try container.decode([ContextValue].self, forKey: .values)
        goals = try container.decode([ContextGoal].self, forKey: .goals)
        situation = try container.decode(ContextSituation.self, forKey: .situation)
        extractedInsights = try container.decode([ExtractedInsight].self, forKey: .extractedInsights)
        contextVersion = try container.decode(Int.self, forKey: .contextVersion)
        firstSessionComplete = try container.decode(Bool.self, forKey: .firstSessionComplete)
        promptDismissedCount = try container.decode(Int.self, forKey: .promptDismissedCount)
        coachingPreferences = try container.decodeIfPresent(CoachingPreferences.self, forKey: .coachingPreferences) ?? .empty
        notificationPreferences = try container.decodeIfPresent(NotificationPreference.self, forKey: .notificationPreferences)
        // Story 11.4: Discovery fields — all use decodeIfPresent for backward compatibility
        discoveryCompletedAt = try container.decodeIfPresent(Date.self, forKey: .discoveryCompletedAt)
        ahaInsight = try container.decodeIfPresent(String.self, forKey: .ahaInsight)
        coachingDomains = try container.decodeIfPresent([String].self, forKey: .coachingDomains) ?? []
        currentChallenges = try container.decodeIfPresent([String].self, forKey: .currentChallenges) ?? []
        emotionalBaseline = try container.decodeIfPresent(String.self, forKey: .emotionalBaseline)
        communicationStyle = try container.decodeIfPresent(String.self, forKey: .communicationStyle)
        keyThemes = try container.decodeIfPresent([String].self, forKey: .keyThemes) ?? []
        strengthsIdentified = try container.decodeIfPresent([String].self, forKey: .strengthsIdentified) ?? []
        vision = try container.decodeIfPresent(String.self, forKey: .vision)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

/// Story 11.4: Data transfer object for discovery profile fields
/// Used by ContextRepository.saveDiscoveryProfile() to merge discovery data into existing profile
struct DiscoveryProfileData: Sendable {
    let ahaInsight: String?
    let coachingDomains: [String]
    let currentChallenges: [String]
    let emotionalBaseline: String?
    let communicationStyle: String?
    let keyThemes: [String]
    let strengthsIdentified: [String]
    let vision: String?
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
