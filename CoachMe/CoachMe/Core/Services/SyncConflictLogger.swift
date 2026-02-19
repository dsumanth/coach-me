//
//  SyncConflictLogger.swift
//  CoachMe
//
//  Story 7.4: Sync Conflict Resolution
//  Logs sync conflict resolutions locally and optionally to Supabase (fire-and-forget)
//

import Foundation
@preconcurrency import Supabase

/// Logs sync conflict resolutions for monitoring and debugging.
/// Logs locally via print (no PII — only record IDs, timestamps, resolution types).
/// Optionally writes to Supabase `sync_conflict_logs` table (fire-and-forget, non-blocking).
@MainActor
final class SyncConflictLogger {
    private let supabase: SupabaseClient

    init(supabase: SupabaseClient = AppEnvironment.shared.supabase) {
        self.supabase = supabase
    }

    /// Log a conflict resolution event
    /// - Parameters:
    ///   - type: Record type ("conversation", "message", "context_profile")
    ///   - conflictType: The reason for the conflict ("timestamp_mismatch", "data_mismatch")
    ///   - resolution: Resolution strategy used ("server_wins", "local_wins", "skipped")
    ///   - localTimestamp: Timestamp of the local version
    ///   - remoteTimestamp: Timestamp of the remote version
    ///   - recordId: The ID of the conflicting record
    func logConflict(
        type: String,
        conflictType: String,
        resolution: String,
        localTimestamp: Date,
        remoteTimestamp: Date,
        recordId: UUID
    ) {
        // Always log locally (no PII — only record IDs and timestamps)
        #if DEBUG
        print("SyncConflictLogger: Conflict resolved: \(type) \(recordId) → \(resolution) (local: \(localTimestamp), remote: \(remoteTimestamp))")
        #endif

        // Resolve authenticated user for Supabase insert (user_id is NOT NULL)
        guard let userId = AuthService.shared.currentUser?.id else {
            #if DEBUG
            print("SyncConflictLogger: No authenticated user — skipping remote log")
            #endif
            return
        }

        // Fire-and-forget log to Supabase (non-blocking)
        let insert = SyncConflictLogInsert(
            userId: userId,
            recordType: type,
            recordId: recordId,
            conflictType: conflictType,
            resolution: resolution,
            localTimestamp: localTimestamp,
            remoteTimestamp: remoteTimestamp
        )
        let client = supabase
        Task {
            try? await client
                .from("sync_conflict_logs")
                .insert(insert)
                .execute()
        }
    }
}
