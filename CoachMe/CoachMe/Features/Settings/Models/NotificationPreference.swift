//
//  NotificationPreference.swift
//  CoachMe
//
//  Story 8.3: Push Permission Timing & Notification Preferences
//  JSONB-backed struct for the notification_preferences column on context_profiles
//

import Foundation

/// User notification preferences for check-in notifications
/// Stored as JSONB in context_profiles.notification_preferences
struct NotificationPreference: Codable, Sendable, Equatable {
    var checkInsEnabled: Bool
    var frequency: CheckInFrequency

    enum CheckInFrequency: String, Codable, Sendable, CaseIterable {
        case daily
        case fewTimesAWeek = "few_times_a_week"
        case weekly

        var displayName: String {
            switch self {
            case .daily: return "Daily"
            case .fewTimesAWeek: return "Few times a week"
            case .weekly: return "Weekly"
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case checkInsEnabled = "check_ins_enabled"
        case frequency
    }

    /// Default preferences for new opt-ins: check-ins enabled, few times a week
    static func `default`() -> NotificationPreference {
        NotificationPreference(checkInsEnabled: true, frequency: .fewTimesAWeek)
    }
}
