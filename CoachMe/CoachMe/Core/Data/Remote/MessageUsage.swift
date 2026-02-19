//
//  MessageUsage.swift
//  CoachMe
//
//  Story 10.5: Usage Transparency UI
//  Codable struct matching the message_usage table (Story 10.1)
//

import Foundation

/// A row from the `message_usage` table representing a user's message consumption
/// for a billing period (YYYY-MM for paid, "trial" for trial users).
struct MessageUsage: Codable, Sendable, Identifiable, Equatable {
    let id: UUID
    let userId: UUID
    let billingPeriod: String
    var messageCount: Int
    let limit: Int
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case billingPeriod = "billing_period"
        case messageCount = "message_count"
        case limit = "limit_amount"
        case updatedAt = "updated_at"
    }

    // MARK: - Computed Properties

    /// Number of messages the user can still send this period
    var messagesRemaining: Int {
        max(limit - messageCount, 0)
    }

    /// Percentage of the limit consumed (0.0–1.0)
    var usagePercentage: Double {
        guard limit > 0 else { return 0.0 }
        return min(Double(messageCount) / Double(limit), 1.0)
    }

    /// Whether the user has reached or exceeded their limit
    var isAtLimit: Bool {
        messageCount >= limit
    }
}
