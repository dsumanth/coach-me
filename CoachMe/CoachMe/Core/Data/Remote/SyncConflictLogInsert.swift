//
//  SyncConflictLogInsert.swift
//  CoachMe
//
//  Story 7.4: Sync Conflict Resolution
//  Minimal insert model for logging sync conflicts to Supabase
//

import Foundation

/// Codable struct for inserting sync conflict log entries into Supabase.
/// Following the ContextProfileInsert pattern: minimal fields, server generates defaults.
struct SyncConflictLogInsert: Codable, Sendable {
    let userId: UUID
    let recordType: String
    let recordId: UUID
    let conflictType: String
    let resolution: String
    let localTimestamp: Date?
    let remoteTimestamp: Date?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case recordType = "record_type"
        case recordId = "record_id"
        case conflictType = "conflict_type"
        case resolution
        case localTimestamp = "local_timestamp"
        case remoteTimestamp = "remote_timestamp"
    }
}
