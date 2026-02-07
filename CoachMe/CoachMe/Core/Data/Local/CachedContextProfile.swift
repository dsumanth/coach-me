//
//  CachedContextProfile.swift
//  CoachMe
//
//  Story 2.1: Context Profile Data Model & Storage
//  SwiftData model for offline caching of context profiles
//

import Foundation
import SwiftData

/// SwiftData model for caching context profiles locally
/// Enables offline access to user context
@Model
final class CachedContextProfile {
    /// User ID - unique constraint ensures one cache per user
    @Attribute(.unique) var userId: UUID

    /// Encoded ContextProfile JSON data
    /// Using Data instead of nested model for flexibility
    var profileData: Data

    /// Timestamp of last sync with Supabase
    var lastSyncedAt: Date

    init(userId: UUID, profileData: Data, lastSyncedAt: Date = Date()) {
        self.userId = userId
        self.profileData = profileData
        self.lastSyncedAt = lastSyncedAt
    }

    // MARK: - Convenience Methods

    /// Decode the cached profile data to ContextProfile
    /// - Returns: ContextProfile if decoding succeeds, nil otherwise
    /// Note: Must be called from MainActor context
    @MainActor
    func decodeProfile() -> ContextProfile? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(ContextProfile.self, from: profileData)
    }

    /// Update cache with new profile data
    /// - Parameter profile: The ContextProfile to cache
    /// - Throws: Encoding error if profile can't be serialized
    /// Note: Must be called from MainActor context
    @MainActor
    func updateWith(_ profile: ContextProfile) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.profileData = try encoder.encode(profile)
        self.lastSyncedAt = Date()
    }

    /// Create cache entry from ContextProfile
    /// - Parameter profile: The profile to cache
    /// - Returns: CachedContextProfile instance
    /// - Throws: Encoding error if profile can't be serialized
    /// Note: Must be called from MainActor context
    @MainActor
    static func from(_ profile: ContextProfile) throws -> CachedContextProfile {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(profile)
        return CachedContextProfile(
            userId: profile.userId,
            profileData: data,
            lastSyncedAt: Date()
        )
    }

    // MARK: - Computed Properties

    /// Check if cache is stale (older than 1 hour)
    var isStale: Bool {
        let oneHourAgo = Date().addingTimeInterval(-3600)
        return lastSyncedAt < oneHourAgo
    }

    /// Time since last sync for display
    var timeSinceSync: TimeInterval {
        Date().timeIntervalSince(lastSyncedAt)
    }
}
