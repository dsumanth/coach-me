//
//  DomainConfig.swift
//  CoachMe
//
//  Story 3.1: Basic domain config model
//  Story 3.2: Extended with full schema for config-driven coaching
//

import Foundation

/// Configuration data for a coaching domain, loaded from JSON resource files.
/// Uses camelCase keys matching the JSON schema (not Supabase snake_case).
struct DomainConfig: Codable, Sendable, Equatable {
    let id: String
    let name: String
    let description: String
    let systemPromptAddition: String
    let tone: String
    let methodology: String
    let personality: String
    let domainKeywords: [String]
    let focusAreas: [String]
    let enabled: Bool
}

// MARK: - Factory

extension DomainConfig {

    /// Fallback config used when a domain is unknown, config is malformed,
    /// or classification is indeterminate.
    static func general() -> DomainConfig {
        DomainConfig(
            id: "general",
            name: "General Coaching",
            description: "Broad personal coaching covering any topic",
            systemPromptAddition: "",
            tone: "warm, supportive, curious",
            methodology: "active listening, open-ended questions, reflective coaching",
            personality: "empathetic coach who adapts to whatever the user needs",
            domainKeywords: [],
            focusAreas: [],
            enabled: true
        )
    }
}
