//
//  LearningSignal.swift
//  CoachMe
//
//  Story 8.1: Learning Signals Infrastructure
//  Codable struct representing a row in the learning_signals table
//

import Foundation
import Supabase

/// A behavioral signal captured from user interactions
/// Used by intelligence layers (pattern recognition, coaching adaptation, proactive nudges)
struct LearningSignal: Codable, Sendable, Identifiable, Equatable {
    let id: UUID
    let userId: UUID
    let signalType: String
    let signalData: [String: AnyJSON]
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case signalType = "signal_type"
        case signalData = "signal_data"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
