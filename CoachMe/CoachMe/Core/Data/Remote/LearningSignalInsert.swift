//
//  LearningSignalInsert.swift
//  CoachMe
//
//  Story 8.1: Learning Signals Infrastructure
//  Minimal insert struct — lets server generate id, created_at, updated_at
//

import Foundation
import Supabase

/// Minimal struct for inserting a learning signal into Supabase
struct LearningSignalInsert: Codable, Sendable {
    let userId: UUID
    let signalType: String
    let signalData: [String: AnyJSON]

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case signalType = "signal_type"
        case signalData = "signal_data"
    }
}
