//
//  CoachingPreferences.swift
//  CoachMe
//
//  Story 8.1: Learning Signals Infrastructure
//  Story 8.6: Coaching Style Adaptation — style dimensions and domain styles
//  Story 8.8: Enhanced Profile — Learned Knowledge Display types
//  JSONB-backed struct for the coaching_preferences column on context_profiles
//

import Foundation

// MARK: - Style Dimensions (Story 8.6)

/// Four-axis style preference dimensions (0.0–1.0 scale)
/// Each dimension is a spectrum between two coaching approaches.
struct StyleDimensions: Codable, Sendable, Equatable {
    var directVsExploratory: Double
    var briefVsDetailed: Double
    var actionVsReflective: Double
    var challengingVsSupportive: Double

    /// Balanced default (0.5 on all axes — no strong preference)
    static func balanced() -> StyleDimensions {
        StyleDimensions(
            directVsExploratory: 0.5,
            briefVsDetailed: 0.5,
            actionVsReflective: 0.5,
            challengingVsSupportive: 0.5
        )
    }

    enum CodingKeys: String, CodingKey {
        case directVsExploratory = "direct_vs_exploratory"
        case briefVsDetailed = "brief_vs_detailed"
        case actionVsReflective = "action_vs_reflective"
        case challengingVsSupportive = "challenging_vs_supportive"
    }
}

// MARK: - Story 8.8: Learned Knowledge Display Types

/// A pattern the coach has inferred about the user from conversations
struct InferredPattern: Codable, Sendable, Equatable, Identifiable {
    var id: UUID
    var patternText: String
    var category: String
    var confidence: Double
    var sourceCount: Int
    var lastObserved: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case patternText = "pattern_text"
        case category
        case confidence
        case sourceCount = "source_count"
        case lastObserved = "last_observed"
    }
}

/// Coaching style inferred by the system
struct CoachingStyleInfo: Codable, Sendable, Equatable {
    var inferredStyle: String?
    var confidence: Double?
    var lastInferred: Date?

    enum CodingKeys: String, CodingKey {
        case inferredStyle = "inferred_style"
        case confidence
        case lastInferred = "last_inferred"
    }
}

/// User's manual style override (always wins over inferred)
struct ManualOverrides: Codable, Sendable, Equatable {
    var style: String?
    var setAt: Date?

    enum CodingKeys: String, CodingKey {
        case style
        case setAt = "set_at"
    }
}

/// Domain usage statistics as percentages
struct DomainUsageStats: Codable, Sendable, Equatable {
    var domains: [String: Double]
    var lastCalculated: Date?

    enum CodingKeys: String, CodingKey {
        case domains
        case lastCalculated = "last_calculated"
    }

    init(domains: [String: Double] = [:], lastCalculated: Date? = nil) {
        self.domains = domains
        self.lastCalculated = lastCalculated
    }
}

/// A progress note related to a user goal
struct ProgressNote: Codable, Sendable, Equatable, Identifiable {
    var id: UUID
    var goal: String
    var progressText: String
    var lastUpdated: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case goal
        case progressText = "progress_text"
        case lastUpdated = "last_updated"
    }
}

/// Tracks which insights the user has dismissed to prevent re-inference
struct DismissedInsights: Codable, Sendable, Equatable {
    var insightIds: [UUID]
    var lastDismissed: Date?

    enum CodingKeys: String, CodingKey {
        case insightIds = "insight_ids"
        case lastDismissed = "last_dismissed"
    }

    init(insightIds: [UUID] = [], lastDismissed: Date? = nil) {
        self.insightIds = insightIds
        self.lastDismissed = lastDismissed
    }
}

// MARK: - Coaching Preferences

/// User coaching preferences derived from learning signals
/// Populated by Stories 8.4-8.8; Story 8.1 only adds the column with empty defaults
struct CoachingPreferences: Codable, Sendable, Equatable {
    var preferredStyle: String?
    var domainUsage: [String: Int]
    var sessionPatterns: [String: String]
    var lastReflectionAt: Date?

    // Story 8.6: Style adaptation fields
    var styleDimensions: StyleDimensions?
    var domainStyles: [String: StyleDimensions]?
    var sessionCount: Int?
    var lastStyleAnalysisAt: Date?
    var manualOverride: String?

    // Story 8.8: Learned knowledge display fields
    var inferredPatterns: [InferredPattern]?
    var coachingStyle: CoachingStyleInfo?
    var manualOverrides: ManualOverrides?
    var domainUsageStats: DomainUsageStats?
    var progressNotes: [ProgressNote]?
    var dismissedInsights: DismissedInsights?

    enum CodingKeys: String, CodingKey {
        case preferredStyle = "preferred_style"
        case domainUsage = "domain_usage"
        case sessionPatterns = "session_patterns"
        case lastReflectionAt = "last_reflection_at"
        case styleDimensions = "style_dimensions"
        case domainStyles = "domain_styles"
        case sessionCount = "session_count"
        case lastStyleAnalysisAt = "last_style_analysis_at"
        case manualOverride = "manual_override"
        case inferredPatterns = "inferred_patterns"
        case coachingStyle = "coaching_style"
        case manualOverrides = "manual_overrides"
        case domainUsageStats = "domain_usage_stats"
        case progressNotes = "progress_notes"
        case dismissedInsights = "dismissed_insights"
    }

    init(preferredStyle: String? = nil,
         domainUsage: [String: Int] = [:],
         sessionPatterns: [String: String] = [:],
         lastReflectionAt: Date? = nil,
         styleDimensions: StyleDimensions? = nil,
         domainStyles: [String: StyleDimensions]? = nil,
         sessionCount: Int? = nil,
         lastStyleAnalysisAt: Date? = nil,
         manualOverride: String? = nil,
         inferredPatterns: [InferredPattern]? = nil,
         coachingStyle: CoachingStyleInfo? = nil,
         manualOverrides: ManualOverrides? = nil,
         domainUsageStats: DomainUsageStats? = nil,
         progressNotes: [ProgressNote]? = nil,
         dismissedInsights: DismissedInsights? = nil) {
        self.preferredStyle = preferredStyle
        self.domainUsage = domainUsage
        self.sessionPatterns = sessionPatterns
        self.lastReflectionAt = lastReflectionAt
        self.styleDimensions = styleDimensions
        self.domainStyles = domainStyles
        self.sessionCount = sessionCount
        self.lastStyleAnalysisAt = lastStyleAnalysisAt
        self.manualOverride = manualOverride
        self.inferredPatterns = inferredPatterns
        self.coachingStyle = coachingStyle
        self.manualOverrides = manualOverrides
        self.domainUsageStats = domainUsageStats
        self.progressNotes = progressNotes
        self.dismissedInsights = dismissedInsights
    }

    /// Empty default matching the DB default of '{}'::jsonb
    static let empty = CoachingPreferences()

    // Custom decoder: domainUsage and sessionPatterns default to empty when
    // keys are missing (DB default is '{}'::jsonb which has no keys at all).
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        preferredStyle = try container.decodeIfPresent(String.self, forKey: .preferredStyle)
        domainUsage = try container.decodeIfPresent([String: Int].self, forKey: .domainUsage) ?? [:]
        sessionPatterns = try container.decodeIfPresent([String: String].self, forKey: .sessionPatterns) ?? [:]
        lastReflectionAt = try container.decodeIfPresent(Date.self, forKey: .lastReflectionAt)
        styleDimensions = try container.decodeIfPresent(StyleDimensions.self, forKey: .styleDimensions)
        domainStyles = try container.decodeIfPresent([String: StyleDimensions].self, forKey: .domainStyles)
        sessionCount = try container.decodeIfPresent(Int.self, forKey: .sessionCount)
        lastStyleAnalysisAt = try container.decodeIfPresent(Date.self, forKey: .lastStyleAnalysisAt)
        manualOverride = try container.decodeIfPresent(String.self, forKey: .manualOverride)
        inferredPatterns = try container.decodeIfPresent([InferredPattern].self, forKey: .inferredPatterns)
        coachingStyle = try container.decodeIfPresent(CoachingStyleInfo.self, forKey: .coachingStyle)
        manualOverrides = try container.decodeIfPresent(ManualOverrides.self, forKey: .manualOverrides)
        domainUsageStats = try container.decodeIfPresent(DomainUsageStats.self, forKey: .domainUsageStats)
        progressNotes = try container.decodeIfPresent([ProgressNote].self, forKey: .progressNotes)
        dismissedInsights = try container.decodeIfPresent(DismissedInsights.self, forKey: .dismissedInsights)
    }
}
