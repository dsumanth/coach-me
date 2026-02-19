//
//  ContextRepository.swift
//  CoachMe
//
//  Story 2.1: Context Profile Data Model & Storage
//  Repository for managing context profiles with remote + local caching
//

import Foundation
import Supabase
import SwiftData

/// Errors specific to context profile operations
/// Per UX-11: Use warm, first-person error messages
enum ContextError: LocalizedError, Equatable {
    case notFound
    case notAuthenticated
    case fetchFailed(String)
    case saveFailed(String)
    case cacheError(String)
    case encodingError(String)
    case insightDismissFailed(String)
    case styleOverrideFailed(String)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "I don't have your context yet. Let's set that up."
        case .notAuthenticated:
            return "I need you to sign in first."
        case .fetchFailed(let reason):
            return "I couldn't load your context. \(reason)"
        case .saveFailed(let reason):
            return "I couldn't save your context. \(reason)"
        case .cacheError(let reason):
            return "I had trouble with local storage. \(reason)"
        case .encodingError(let reason):
            return "I had trouble processing your data. \(reason)"
        case .insightDismissFailed(let reason):
            return "I couldn't remove that insight. \(reason)"
        case .styleOverrideFailed(let reason):
            return "I couldn't save your style preference. \(reason)"
        }
    }

    // Equatable conformance for error with associated values
    static func == (lhs: ContextError, rhs: ContextError) -> Bool {
        switch (lhs, rhs) {
        case (.notFound, .notFound), (.notAuthenticated, .notAuthenticated):
            return true
        case (.fetchFailed(let a), .fetchFailed(let b)):
            return a == b
        case (.saveFailed(let a), .saveFailed(let b)):
            return a == b
        case (.cacheError(let a), .cacheError(let b)):
            return a == b
        case (.encodingError(let a), .encodingError(let b)):
            return a == b
        case (.insightDismissFailed(let a), .insightDismissFailed(let b)):
            return a == b
        case (.styleOverrideFailed(let a), .styleOverrideFailed(let b)):
            return a == b
        default:
            return false
        }
    }
}

/// Protocol for context repository operations (enables testing)
@MainActor
protocol ContextRepositoryProtocol {
    func createProfile(for userId: UUID) async throws -> ContextProfile
    func fetchProfile(userId: UUID) async throws -> ContextProfile
    func updateProfile(_ profile: ContextProfile) async throws
    func getLocalProfile(userId: UUID) async throws -> ContextProfile?
    func profileExists(userId: UUID) async -> Bool
    func deleteProfile(userId: UUID) async throws
    func markFirstSessionComplete(userId: UUID) async throws
    func incrementPromptDismissedCount(userId: UUID) async throws
    func addInitialContext(userId: UUID, values: String, goals: String, situation: String) async throws

    // Story 2.3: Progressive Context Extraction
    func savePendingInsights(userId: UUID, insights: [ExtractedInsight]) async throws
    func getPendingInsights(userId: UUID) async throws -> [ExtractedInsight]
    func confirmInsight(userId: UUID, insightId: UUID) async throws
    func dismissInsight(userId: UUID, insightId: UUID) async throws

    // Story 11.4: Discovery-to-Profile Pipeline
    func saveDiscoveryProfile(userId: UUID, discoveryData: DiscoveryProfileData) async throws
}

/// Repository for context profile operations
/// Follows the singleton pattern per architecture.md
/// Handles remote (Supabase) and local (SwiftData) persistence
@MainActor
final class ContextRepository: ContextRepositoryProtocol {
    // MARK: - Singleton

    static let shared = ContextRepository()

    // MARK: - Properties

    private let supabase: SupabaseClient
    private let modelContext: ModelContext

    // MARK: - Initialization

    private init() {
        self.supabase = AppEnvironment.shared.supabase
        self.modelContext = AppEnvironment.shared.modelContext
    }

    /// For testing with mock dependencies
    init(supabase: SupabaseClient, modelContext: ModelContext) {
        self.supabase = supabase
        self.modelContext = modelContext
    }

    // MARK: - Public Methods

    /// Creates a new empty context profile for a user
    /// Called when user first signs up
    /// Uses upsert to handle race conditions (e.g., simultaneous sign-in from multiple devices)
    /// - Parameter userId: The user's ID
    /// - Returns: The created ContextProfile with server-assigned values
    /// - Throws: ContextError if creation fails
    func createProfile(for userId: UUID) async throws -> ContextProfile {
        // Use minimal insert struct - let server generate id, timestamps via defaults
        let insert = ContextProfileInsert(userId: userId)

        do {
            // Use upsert with ignoreDuplicates to handle race conditions atomically
            // If profile already exists (unique constraint on user_id), this becomes a no-op
            try await supabase
                .from("context_profiles")
                .upsert(insert, onConflict: "user_id", ignoreDuplicates: true)
                .execute()

            // Fetch the profile to get server-assigned values (id, created_at, updated_at)
            let profiles: [ContextProfile] = try await supabase
                .from("context_profiles")
                .select()
                .eq("user_id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value

            guard let profile = profiles.first else {
                throw ContextError.saveFailed("Profile was not created")
            }

            // Cache locally with server values
            try await cacheProfile(profile)

            #if DEBUG
            print("ContextRepository: Created/retrieved profile for user \(userId)")
            #endif

            return profile
        } catch let error as ContextError {
            throw error
        } catch {
            #if DEBUG
            print("ContextRepository: Failed to create profile: \(error)")
            #endif
            throw ContextError.saveFailed(error.localizedDescription)
        }
    }

    /// Fetches a user's context profile
    /// Tries remote first, falls back to local cache on failure
    /// - Parameter userId: The user's ID
    /// - Returns: The user's ContextProfile
    /// - Throws: ContextError if profile not found and no cache available
    func fetchProfile(userId: UUID) async throws -> ContextProfile {
        do {
            // Try remote first
            let profiles: [ContextProfile] = try await supabase
                .from("context_profiles")
                .select()
                .eq("user_id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value

            guard let profile = profiles.first else {
                // No profile found remotely, check cache
                if let cached = try await getLocalProfile(userId: userId) {
                    return cached
                }
                throw ContextError.notFound
            }

            // Update local cache with fresh data
            try await cacheProfile(profile)

            #if DEBUG
            print("ContextRepository: Fetched profile from remote for user \(userId)")
            #endif

            return profile

        } catch let error as ContextError {
            throw error
        } catch {
            // Network/remote error - try local cache
            #if DEBUG
            print("ContextRepository: Remote fetch failed, trying cache: \(error)")
            #endif

            if let cached = try await getLocalProfile(userId: userId) {
                #if DEBUG
                print("ContextRepository: Loaded profile from cache for user \(userId)")
                #endif
                return cached
            }

            throw ContextError.notFound
        }
    }

    /// Updates an existing context profile
    /// Syncs to remote and updates local cache
    /// Story 7.3: Queues update for offline sync if not connected
    /// - Parameter profile: The profile to update
    /// - Throws: ContextError if update fails
    func updateProfile(_ profile: ContextProfile) async throws {
        // Story 7.3/7.4: If offline, update local cache optimistically and queue for sync
        // Story 7.4: Set localUpdatedAt so conflict resolver knows local was edited offline
        if !NetworkMonitor.shared.isConnected {
            try await cacheProfile(profile)
            // Mark the cached profile with localUpdatedAt for conflict resolution
            let descriptor = FetchDescriptor<CachedContextProfile>()
            let cached = try modelContext.fetch(descriptor)
            if let localCache = cached.first(where: { $0.userId == profile.userId }) {
                localCache.localUpdatedAt = Date()
                localCache.syncStatus = "pending"
                try modelContext.save()
            }
            OfflineSyncService.shared.queueOperation(.updateContextProfile(profile))
            #if DEBUG
            print("ContextRepository: Profile update queued for offline sync (localUpdatedAt set)")
            #endif
            return
        }

        // Online: existing remote-first logic
        var updated = profile
        updated.updatedAt = Date()

        do {
            try await supabase
                .from("context_profiles")
                .update(updated)
                .eq("id", value: profile.id.uuidString)
                .execute()

            // Update local cache
            try await cacheProfile(updated)

            #if DEBUG
            print("ContextRepository: Updated profile \(profile.id)")
            #endif

        } catch {
            #if DEBUG
            print("ContextRepository: Failed to update profile: \(error)")
            #endif
            throw ContextError.saveFailed(error.localizedDescription)
        }
    }

    /// Gets profile from local SwiftData cache
    /// Used for offline access
    /// - Parameter userId: The user's ID
    /// - Returns: Cached ContextProfile if available, nil otherwise
    func getLocalProfile(userId: UUID) async throws -> ContextProfile? {
        do {
            // Fetch all and filter in memory to avoid Swift 6 predicate Sendable issues
            // This is efficient since we typically have only one cached profile per device
            let descriptor = FetchDescriptor<CachedContextProfile>()
            let results = try modelContext.fetch(descriptor)
            let matching = results.first { $0.userId == userId }
            return matching?.decodeProfile()
        } catch {
            #if DEBUG
            print("ContextRepository: Cache fetch error: \(error)")
            #endif
            return nil
        }
    }

    /// Checks if a context profile exists for the user
    /// - Parameter userId: The user's ID
    /// - Returns: true if profile exists (remote or cached)
    func profileExists(userId: UUID) async -> Bool {
        // Check remote first
        do {
            let count: Int = try await supabase
                .from("context_profiles")
                .select("id", head: true, count: .exact)
                .eq("user_id", value: userId.uuidString)
                .execute()
                .count ?? 0

            return count > 0
        } catch {
            // Remote check failed, check local cache
            if let _ = try? await getLocalProfile(userId: userId) {
                return true
            }
            return false
        }
    }

    /// Deletes a user's context profile
    /// - Parameter userId: The user's ID
    /// - Throws: ContextError if deletion fails
    func deleteProfile(userId: UUID) async throws {
        do {
            try await supabase
                .from("context_profiles")
                .delete()
                .eq("user_id", value: userId.uuidString)
                .execute()

            // Remove from local cache
            try await deleteCachedProfile(userId: userId)

            #if DEBUG
            print("ContextRepository: Deleted profile for user \(userId)")
            #endif

        } catch {
            #if DEBUG
            print("ContextRepository: Failed to delete profile: \(error)")
            #endif
            throw ContextError.saveFailed(error.localizedDescription)
        }
    }

    // MARK: - Story 2.2: Context Prompt Methods

    /// Marks the first session as complete for a user
    /// Called after the context prompt is shown (accepted or dismissed)
    /// - Parameter userId: The user's ID
    /// - Throws: ContextError if update fails
    func markFirstSessionComplete(userId: UUID) async throws {
        do {
            // Fetch current profile
            var profile = try await fetchProfile(userId: userId)

            // Only update if not already complete
            guard !profile.firstSessionComplete else {
                #if DEBUG
                print("ContextRepository: First session already complete for user \(userId)")
                #endif
                return
            }

            profile.firstSessionComplete = true
            profile.updatedAt = Date()

            try await supabase
                .from("context_profiles")
                .update(profile)
                .eq("user_id", value: userId.uuidString)
                .execute()

            try await cacheProfile(profile)

            #if DEBUG
            print("ContextRepository: Marked first session complete for user \(userId)")
            #endif
        } catch let error as ContextError {
            throw error
        } catch {
            throw ContextError.saveFailed(error.localizedDescription)
        }
    }

    /// Increments the prompt dismissed count for a user
    /// Called when user taps "Not now" on the context prompt
    /// - Parameter userId: The user's ID
    /// - Throws: ContextError if update fails
    func incrementPromptDismissedCount(userId: UUID) async throws {
        do {
            // Fetch current profile
            var profile = try await fetchProfile(userId: userId)

            profile.promptDismissedCount += 1
            profile.updatedAt = Date()

            try await supabase
                .from("context_profiles")
                .update(profile)
                .eq("user_id", value: userId.uuidString)
                .execute()

            try await cacheProfile(profile)

            #if DEBUG
            print("ContextRepository: Incremented dismiss count to \(profile.promptDismissedCount) for user \(userId)")
            #endif
        } catch let error as ContextError {
            throw error
        } catch {
            throw ContextError.saveFailed(error.localizedDescription)
        }
    }

    /// Adds initial context values, goals, and situation for a user
    /// Called when user completes the context setup form
    /// - Parameters:
    ///   - userId: The user's ID
    ///   - values: Comma-separated or freeform values string
    ///   - goals: Comma-separated or freeform goals string
    ///   - situation: Freeform life situation description
    /// - Throws: ContextError if save fails
    func addInitialContext(userId: UUID, values: String, goals: String, situation: String) async throws {
        do {
            // Fetch current profile
            var profile = try await fetchProfile(userId: userId)

            // Parse values into ContextValue objects
            let trimmedValues = values.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedValues.isEmpty {
                let valueItems = trimmedValues
                    .split(separator: ",")
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }

                for valueContent in valueItems {
                    let contextValue = ContextValue.userValue(valueContent)
                    profile.addValue(contextValue)
                }
            }

            // Parse goals into ContextGoal objects
            let trimmedGoals = goals.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedGoals.isEmpty {
                let goalItems = trimmedGoals
                    .split(separator: ",")
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }

                for goalContent in goalItems {
                    let contextGoal = ContextGoal.userGoal(goalContent)
                    profile.addGoal(contextGoal)
                }
            }

            // Set life situation
            let trimmedSituation = situation.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedSituation.isEmpty {
                profile.situation.freeform = trimmedSituation
            }

            profile.updatedAt = Date()

            try await supabase
                .from("context_profiles")
                .update(profile)
                .eq("user_id", value: userId.uuidString)
                .execute()

            try await cacheProfile(profile)

            #if DEBUG
            print("ContextRepository: Added initial context for user \(userId)")
            print("  - Values: \(profile.values.count)")
            print("  - Goals: \(profile.goals.count)")
            print("  - Situation: \(profile.situation.hasContent)")
            #endif
        } catch let error as ContextError {
            throw error
        } catch {
            throw ContextError.saveFailed(error.localizedDescription)
        }
    }

    // MARK: - Story 2.3: Pending Insights Methods

    /// Saves pending insights to the user's profile (local cache only)
    /// Insights are stored unconfirmed until user approves them
    /// - Parameters:
    ///   - userId: The user's ID
    ///   - insights: Array of unconfirmed ExtractedInsight
    /// - Throws: ContextError if save fails
    func savePendingInsights(userId: UUID, insights: [ExtractedInsight]) async throws {
        do {
            var profile = try await fetchProfile(userId: userId)

            // Filter to only unconfirmed insights
            let pendingInsights = insights.filter { !$0.confirmed }

            // Replace existing extractedInsights with new pending list
            // This maintains the pending queue while preserving confirmed insights
            let confirmedInsights = profile.extractedInsights.filter { $0.confirmed }
            profile.extractedInsights = confirmedInsights + pendingInsights
            profile.updatedAt = Date()

            // Update remote
            try await supabase
                .from("context_profiles")
                .update(profile)
                .eq("user_id", value: userId.uuidString)
                .execute()

            // Update local cache
            try await cacheProfile(profile)

            #if DEBUG
            print("ContextRepository: Saved \(pendingInsights.count) pending insights for user \(userId)")
            #endif
        } catch let error as ContextError {
            throw error
        } catch {
            throw ContextError.saveFailed(error.localizedDescription)
        }
    }

    /// Gets all unconfirmed (pending) insights for a user
    /// - Parameter userId: The user's ID
    /// - Returns: Array of unconfirmed ExtractedInsight
    func getPendingInsights(userId: UUID) async throws -> [ExtractedInsight] {
        do {
            let profile = try await fetchProfile(userId: userId)
            return profile.extractedInsights.filter { !$0.confirmed }
        } catch ContextError.notFound {
            // No profile means no pending insights
            return []
        }
    }

    /// Confirms an insight, moving it to the user's permanent profile
    /// The insight is converted to the appropriate ContextValue, ContextGoal, or situation
    /// - Parameters:
    ///   - userId: The user's ID
    ///   - insightId: The insight ID to confirm
    /// - Throws: ContextError if confirmation fails
    func confirmInsight(userId: UUID, insightId: UUID) async throws {
        do {
            var profile = try await fetchProfile(userId: userId)

            // Find the insight
            guard let insightIndex = profile.extractedInsights.firstIndex(where: { $0.id == insightId }) else {
                #if DEBUG
                print("ContextRepository: Insight \(insightId) not found")
                #endif
                return
            }

            var insight = profile.extractedInsights[insightIndex]

            // Mark as confirmed
            insight.confirm()

            // Add to appropriate profile section based on category
            switch insight.category {
            case .value:
                let contextValue = ContextValue.extractedValue(insight.content, confidence: insight.confidence)
                profile.addValue(contextValue)
            case .goal:
                let contextGoal = ContextGoal.extractedGoal(insight.content)
                profile.addGoal(contextGoal)
            case .situation:
                // Append to freeform situation
                if let existing = profile.situation.freeform, !existing.isEmpty {
                    profile.situation.freeform = existing + "; \(insight.content)"
                } else {
                    profile.situation.freeform = insight.content
                }
            case .pattern:
                // Patterns stay in extractedInsights but marked confirmed
                break
            }

            // Update the insight in the list
            profile.extractedInsights[insightIndex] = insight
            profile.updatedAt = Date()

            // Save to remote
            try await supabase
                .from("context_profiles")
                .update(profile)
                .eq("user_id", value: userId.uuidString)
                .execute()

            // Update local cache
            try await cacheProfile(profile)

            // Story 8.1: Record insight confirmation as learning signal (non-blocking)
            let category = insight.category.rawValue
            Task {
                try? await LearningSignalService.shared.recordInsightFeedback(
                    insightId: insightId, action: .confirmed, category: category
                )
            }

            #if DEBUG
            print("ContextRepository: Confirmed insight \(insightId) as \(insight.category.rawValue)")
            #endif
        } catch let error as ContextError {
            throw error
        } catch {
            throw ContextError.saveFailed(error.localizedDescription)
        }
    }

    /// Dismisses an insight, removing it from the pending list
    /// - Parameters:
    ///   - userId: The user's ID
    ///   - insightId: The insight ID to dismiss
    /// - Throws: ContextError if dismissal fails
    func dismissInsight(userId: UUID, insightId: UUID) async throws {
        do {
            var profile = try await fetchProfile(userId: userId)

            // Story 8.1: Capture category before removal for learning signal
            let insightCategory = profile.extractedInsights.first { $0.id == insightId }?.category.rawValue

            // Remove the insight
            profile.extractedInsights.removeAll { $0.id == insightId }
            profile.updatedAt = Date()

            // Save to remote
            try await supabase
                .from("context_profiles")
                .update(profile)
                .eq("user_id", value: userId.uuidString)
                .execute()

            // Update local cache
            try await cacheProfile(profile)

            // Story 8.1: Record insight dismissal as learning signal (non-blocking)
            if let category = insightCategory {
                Task {
                    try? await LearningSignalService.shared.recordInsightFeedback(
                        insightId: insightId, action: .dismissed, category: category
                    )
                }
            }

            #if DEBUG
            print("ContextRepository: Dismissed insight \(insightId)")
            #endif
        } catch let error as ContextError {
            throw error
        } catch {
            throw ContextError.saveFailed(error.localizedDescription)
        }
    }

    // MARK: - Story 11.4: Discovery Profile Pipeline

    /// Saves discovery session data into the user's existing context profile
    /// Fetches the current profile, merges discovery fields, then updates remote and local cache
    /// If offline, queues the update for sync on reconnect (Story 7.3)
    /// - Parameters:
    ///   - userId: The user's ID
    ///   - discoveryData: Extracted discovery session fields
    /// - Throws: ContextError if save fails
    func saveDiscoveryProfile(userId: UUID, discoveryData: DiscoveryProfileData) async throws {
        do {
            var profile = try await fetchProfile(userId: userId)

            // Merge discovery fields into existing profile
            profile.discoveryCompletedAt = Date()
            profile.ahaInsight = discoveryData.ahaInsight
            profile.coachingDomains = discoveryData.coachingDomains
            profile.currentChallenges = discoveryData.currentChallenges
            profile.emotionalBaseline = discoveryData.emotionalBaseline
            profile.communicationStyle = discoveryData.communicationStyle
            profile.keyThemes = discoveryData.keyThemes
            profile.strengthsIdentified = discoveryData.strengthsIdentified
            profile.vision = discoveryData.vision
            profile.contextVersion += 1
            profile.updatedAt = Date()

            // Story 7.3: If offline, cache locally and queue for sync
            if !NetworkMonitor.shared.isConnected {
                try await cacheProfile(profile)
                let descriptor = FetchDescriptor<CachedContextProfile>()
                let cached = try modelContext.fetch(descriptor)
                if let localCache = cached.first(where: { $0.userId == profile.userId }) {
                    localCache.localUpdatedAt = Date()
                    localCache.syncStatus = "pending"
                    try modelContext.save()
                }
                OfflineSyncService.shared.queueOperation(.updateContextProfile(profile))
                #if DEBUG
                print("ContextRepository: Discovery profile queued for offline sync")
                #endif
                return
            }

            // Online: update remote then cache
            try await supabase
                .from("context_profiles")
                .update(profile)
                .eq("user_id", value: userId.uuidString)
                .execute()

            try await cacheProfile(profile)

            #if DEBUG
            print("ContextRepository: Saved discovery profile for user \(userId)")
            #endif
        } catch let error as ContextError {
            throw error
        } catch {
            #if DEBUG
            print("ContextRepository: Failed to save discovery profile: \(error)")
            #endif
            throw ContextError.saveFailed(error.localizedDescription)
        }
    }

    // MARK: - Public Cache Methods (Story 7.4)

    /// Update local SwiftData cache with a profile (used by OfflineSyncService during conflict resolution)
    func updateLocalCache(_ profile: ContextProfile) async throws {
        try await cacheProfile(profile)
    }

    // MARK: - Private Cache Methods

    /// Caches a profile to SwiftData
    private func cacheProfile(_ profile: ContextProfile) async throws {
        do {
            // Fetch all and filter in memory to avoid Swift 6 predicate Sendable issues
            let descriptor = FetchDescriptor<CachedContextProfile>()
            let existing = try modelContext.fetch(descriptor)
            let cached = existing.first { $0.userId == profile.userId }

            if let cached = cached {
                // Update existing cache
                try cached.updateWith(profile)
            } else {
                // Create new cache entry
                let newCache = try CachedContextProfile.from(profile)
                modelContext.insert(newCache)
            }

            try modelContext.save()

            #if DEBUG
            print("ContextRepository: Cached profile for user \(profile.userId)")
            #endif

        } catch {
            #if DEBUG
            print("ContextRepository: Cache save error: \(error)")
            #endif
            // Non-fatal: cache failure shouldn't break main flow
        }
    }

    /// Deletes cached profile from SwiftData
    private func deleteCachedProfile(userId: UUID) async throws {
        do {
            // Fetch all and filter in memory to avoid Swift 6 predicate Sendable issues
            let descriptor = FetchDescriptor<CachedContextProfile>()
            let results = try modelContext.fetch(descriptor)
            let matching = results.filter { $0.userId == userId }
            for cached in matching {
                modelContext.delete(cached)
            }
            try modelContext.save()
        } catch {
            #if DEBUG
            print("ContextRepository: Cache delete error: \(error)")
            #endif
            // Non-fatal
        }
    }
}
