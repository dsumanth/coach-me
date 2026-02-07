//
//  CoachingDomain.swift
//  CoachMe
//

import SwiftUI

/// All coaching domains supported by the app.
/// Raw values match the `id` field in each domain JSON config file.
enum CoachingDomain: String, CaseIterable, Codable, Sendable {
    case life
    case career
    case relationships
    case mindset
    case creativity
    case fitness
    case leadership
    case general

    var displayName: String {
        switch self {
        case .life: "Life Coaching"
        case .career: "Career Coaching"
        case .relationships: "Relationship Coaching"
        case .mindset: "Mindset Coaching"
        case .creativity: "Creativity Coaching"
        case .fitness: "Fitness Coaching"
        case .leadership: "Leadership Coaching"
        case .general: "General Coaching"
        }
    }

    /// Domain accent color for light mode.
    var color: Color {
        switch self {
        case .life: .domainLife
        case .career: .domainCareer
        case .relationships: .domainRelationships
        case .mindset: .domainMindset
        case .creativity: .domainCreativity
        case .fitness: .domainFitness
        case .leadership: .domainLeadership
        case .general: .terracotta
        }
    }

    /// Domain accent color adapted for the current color scheme.
    func adaptiveColor(_ colorScheme: ColorScheme) -> Color {
        if colorScheme == .dark {
            switch self {
            case .life: return .domainLifeDark
            case .career: return .domainCareerDark
            case .relationships: return .domainRelationshipsDark
            case .mindset: return .domainMindsetDark
            case .creativity: return .domainCreativityDark
            case .fitness: return .domainFitnessDark
            case .leadership: return .domainLeadershipDark
            case .general: return .terracottaDark
            }
        }
        return color
    }
}
