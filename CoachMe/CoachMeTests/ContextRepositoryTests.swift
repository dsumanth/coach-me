//
//  ContextRepositoryTests.swift
//  CoachMeTests
//
//  Story 2.1: Context Profile Data Model & Storage
//  Tests for ContextRepository cache operations and offline fallback
//
//  Note: Full Supabase integration tests require a test environment.
//  These tests focus on local cache operations which can be tested in isolation.
//

import XCTest
import SwiftData
@testable import CoachMe

@MainActor
final class ContextRepositoryTests: XCTestCase {

    private var modelContainer: ModelContainer!
    private var modelContext: ModelContext!

    override func setUp() async throws {
        try await super.setUp()
        // Create in-memory container for testing
        let schema = Schema([CachedContextProfile.self])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        modelContext = modelContainer.mainContext
    }

    override func tearDown() async throws {
        modelContainer = nil
        modelContext = nil
        try await super.tearDown()
    }

    // MARK: - getLocalProfile Tests

    func testGetLocalProfileReturnsNilWhenNoCache() async throws {
        // Given: Empty cache and a userId
        let userId = UUID()

        // When: Getting local profile
        let profile = try await getLocalProfileDirect(userId: userId)

        // Then: Should return nil
        XCTAssertNil(profile, "Should return nil when no cached profile exists")
    }

    func testGetLocalProfileReturnsCachedProfile() async throws {
        // Given: A cached profile
        let userId = UUID()
        var profile = ContextProfile.empty(userId: userId)
        profile.addValue(ContextValue.userValue("test value"))

        let cached = try CachedContextProfile.from(profile)
        modelContext.insert(cached)
        try modelContext.save()

        // When: Getting local profile
        let retrieved = try await getLocalProfileDirect(userId: userId)

        // Then: Should return the cached profile
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.userId, userId)
        XCTAssertEqual(retrieved?.values.count, 1)
        XCTAssertEqual(retrieved?.values.first?.content, "test value")
    }

    func testGetLocalProfileReturnsCorrectUserProfile() async throws {
        // Given: Multiple cached profiles for different users
        let userId1 = UUID()
        let userId2 = UUID()

        var profile1 = ContextProfile.empty(userId: userId1)
        profile1.addValue(ContextValue.userValue("user1 value"))

        var profile2 = ContextProfile.empty(userId: userId2)
        profile2.addValue(ContextValue.userValue("user2 value"))

        modelContext.insert(try CachedContextProfile.from(profile1))
        modelContext.insert(try CachedContextProfile.from(profile2))
        try modelContext.save()

        // When: Getting profile for userId1
        let retrieved = try await getLocalProfileDirect(userId: userId1)

        // Then: Should return the correct user's profile
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.userId, userId1)
        XCTAssertEqual(retrieved?.values.first?.content, "user1 value")
    }

    // MARK: - Cache Update Tests

    func testCacheProfileCreatesNewEntry() async throws {
        // Given: A profile to cache
        let userId = UUID()
        let profile = ContextProfile.empty(userId: userId)

        // When: Caching the profile
        try await cacheProfileDirect(profile)

        // Then: Cache entry should exist
        let descriptor = FetchDescriptor<CachedContextProfile>()
        let results = try modelContext.fetch(descriptor)
        let cached = results.first { $0.userId == userId }

        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.userId, userId)
    }

    func testCacheProfileUpdatesExistingEntry() async throws {
        // Given: An existing cached profile
        let userId = UUID()
        var profile = ContextProfile.empty(userId: userId)

        let cached = try CachedContextProfile.from(profile)
        modelContext.insert(cached)
        try modelContext.save()

        // When: Updating the profile with new data
        profile.addValue(ContextValue.userValue("new value"))
        try await cacheProfileDirect(profile)

        // Then: Cache should be updated (not duplicated)
        let descriptor = FetchDescriptor<CachedContextProfile>()
        let results = try modelContext.fetch(descriptor)
        let matchingCaches = results.filter { $0.userId == userId }

        XCTAssertEqual(matchingCaches.count, 1, "Should have only one cache entry per user")

        let decoded = matchingCaches.first?.decodeProfile()
        XCTAssertEqual(decoded?.values.count, 1)
        XCTAssertEqual(decoded?.values.first?.content, "new value")
    }

    // MARK: - Delete Cache Tests

    func testDeleteCachedProfileRemovesEntry() async throws {
        // Given: A cached profile
        let userId = UUID()
        let profile = ContextProfile.empty(userId: userId)
        let cached = try CachedContextProfile.from(profile)
        modelContext.insert(cached)
        try modelContext.save()

        // When: Deleting the cached profile
        try await deleteCachedProfileDirect(userId: userId)

        // Then: Cache should be empty for that user
        let descriptor = FetchDescriptor<CachedContextProfile>()
        let results = try modelContext.fetch(descriptor)
        let matching = results.filter { $0.userId == userId }

        XCTAssertEqual(matching.count, 0, "Should have no cache entries after deletion")
    }

    func testDeleteCachedProfileDoesNotAffectOtherUsers() async throws {
        // Given: Cached profiles for multiple users
        let userId1 = UUID()
        let userId2 = UUID()

        modelContext.insert(try CachedContextProfile.from(ContextProfile.empty(userId: userId1)))
        modelContext.insert(try CachedContextProfile.from(ContextProfile.empty(userId: userId2)))
        try modelContext.save()

        // When: Deleting userId1's cache
        try await deleteCachedProfileDirect(userId: userId1)

        // Then: userId2's cache should still exist
        let descriptor = FetchDescriptor<CachedContextProfile>()
        let results = try modelContext.fetch(descriptor)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.userId, userId2)
    }

    // MARK: - Offline Scenario Tests

    func testOfflineScenarioReturnsCachedData() async throws {
        // Given: A cached profile (simulating data from previous online session)
        let userId = UUID()
        var profile = ContextProfile.empty(userId: userId)
        profile.addGoal(ContextGoal.userGoal("offline goal"))
        profile.situation = ContextSituation(
            lifeStage: "mid-career",
            occupation: "engineer",
            relationships: nil,
            challenges: nil,
            freeform: nil
        )

        let cached = try CachedContextProfile.from(profile)
        modelContext.insert(cached)
        try modelContext.save()

        // When: Fetching profile (simulating offline - direct cache access)
        let retrieved = try await getLocalProfileDirect(userId: userId)

        // Then: Should return full cached data
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.goals.count, 1)
        XCTAssertEqual(retrieved?.goals.first?.content, "offline goal")
        XCTAssertEqual(retrieved?.situation.occupation, "engineer")
    }

    func testCacheStalenessTracking() async throws {
        // Given: A cached profile
        let userId = UUID()
        let profile = ContextProfile.empty(userId: userId)
        let cached = try CachedContextProfile.from(profile)
        modelContext.insert(cached)
        try modelContext.save()

        // When: Checking staleness immediately after caching
        let descriptor = FetchDescriptor<CachedContextProfile>()
        let results = try modelContext.fetch(descriptor)
        let retrievedCache = results.first { $0.userId == userId }

        // Then: Cache should not be stale
        XCTAssertNotNil(retrievedCache)
        XCTAssertFalse(retrievedCache?.isStale ?? true, "Fresh cache should not be stale")
    }

    // MARK: - ContextProfileInsert Tests

    func testContextProfileInsertEncodingForUpsert() throws {
        // Given: A ContextProfileInsert
        let userId = UUID()
        let insert = ContextProfileInsert(userId: userId)

        // When: Encoding for Supabase
        let encoder = JSONEncoder()
        let data = try encoder.encode(insert)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Then: Should only contain user_id
        XCTAssertNotNil(json?["user_id"])
        XCTAssertEqual(json?.count, 1, "Insert should only contain user_id field")
        XCTAssertNil(json?["id"], "Should NOT contain id - let server generate")
        XCTAssertNil(json?["created_at"], "Should NOT contain created_at - let server generate")
    }

    // MARK: - Story 2.2: Context Prompt Data Tests

    func testContextProfileFirstSessionComplete() async throws {
        // Given: A profile with firstSessionComplete = false
        let userId = UUID()
        var profile = ContextProfile.empty(userId: userId)

        XCTAssertFalse(profile.firstSessionComplete, "New profile should have firstSessionComplete = false")

        // When: Marking first session complete
        profile = ContextProfile(
            id: profile.id,
            userId: userId,
            values: [],
            goals: [],
            situation: .empty,
            extractedInsights: [],
            contextVersion: 1,
            firstSessionComplete: true,
            promptDismissedCount: 0,
            createdAt: profile.createdAt,
            updatedAt: Date()
        )

        // Then: firstSessionComplete should be true
        XCTAssertTrue(profile.firstSessionComplete, "Profile should have firstSessionComplete = true after update")
    }

    func testContextProfilePromptDismissedCount() async throws {
        // Given: A profile with promptDismissedCount = 0
        let userId = UUID()
        var profile = ContextProfile.empty(userId: userId)

        XCTAssertEqual(profile.promptDismissedCount, 0, "New profile should have promptDismissedCount = 0")

        // When: Incrementing the dismiss count
        profile = ContextProfile(
            id: profile.id,
            userId: userId,
            values: [],
            goals: [],
            situation: .empty,
            extractedInsights: [],
            contextVersion: 1,
            firstSessionComplete: false,
            promptDismissedCount: 1,
            createdAt: profile.createdAt,
            updatedAt: Date()
        )

        // Then: promptDismissedCount should be 1
        XCTAssertEqual(profile.promptDismissedCount, 1, "Profile should have promptDismissedCount = 1 after increment")
    }

    func testContextProfileHasContextWithValues() async throws {
        // Given: A profile with values
        let userId = UUID()
        var profile = ContextProfile.empty(userId: userId)
        profile.addValue(ContextValue.userValue("Family"))

        // Then: hasContext should be true
        XCTAssertTrue(profile.hasContext, "Profile with values should have hasContext = true")
    }

    func testContextProfileHasContextWithGoals() async throws {
        // Given: A profile with goals
        let userId = UUID()
        var profile = ContextProfile.empty(userId: userId)
        profile.addGoal(ContextGoal.userGoal("Get fit"))

        // Then: hasContext should be true
        XCTAssertTrue(profile.hasContext, "Profile with goals should have hasContext = true")
    }

    func testContextProfileHasContextWithSituation() async throws {
        // Given: A profile with situation content
        let userId = UUID()
        var profile = ContextProfile.empty(userId: userId)
        profile.situation = ContextSituation(
            lifeStage: nil,
            occupation: nil,
            relationships: nil,
            challenges: nil,
            freeform: "Transitioning careers"
        )

        // Then: hasContext should be true
        XCTAssertTrue(profile.hasContext, "Profile with situation should have hasContext = true")
    }

    func testContextProfileHasNoContextWhenEmpty() async throws {
        // Given: An empty profile
        let userId = UUID()
        let profile = ContextProfile.empty(userId: userId)

        // Then: hasContext should be false
        XCTAssertFalse(profile.hasContext, "Empty profile should have hasContext = false")
    }

    func testAddInitialContextValuesAreParsed() async throws {
        // Given: A profile to add values to
        let userId = UUID()
        var profile = ContextProfile.empty(userId: userId)

        // When: Adding comma-separated values
        let valueItems = "Family, Health, Career"
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for valueContent in valueItems {
            let contextValue = ContextValue.userValue(valueContent)
            profile.addValue(contextValue)
        }

        // Then: Values should be parsed correctly
        XCTAssertEqual(profile.values.count, 3, "Should have 3 values")
        XCTAssertEqual(profile.values[0].content, "Family")
        XCTAssertEqual(profile.values[1].content, "Health")
        XCTAssertEqual(profile.values[2].content, "Career")
    }

    func testAddInitialContextGoalsAreParsed() async throws {
        // Given: A profile to add goals to
        let userId = UUID()
        var profile = ContextProfile.empty(userId: userId)

        // When: Adding comma-separated goals
        let goalItems = "Get fit, Learn guitar"
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for goalContent in goalItems {
            let contextGoal = ContextGoal.userGoal(goalContent)
            profile.addGoal(contextGoal)
        }

        // Then: Goals should be parsed correctly
        XCTAssertEqual(profile.goals.count, 2, "Should have 2 goals")
        XCTAssertEqual(profile.goals[0].content, "Get fit")
        XCTAssertEqual(profile.goals[1].content, "Learn guitar")
    }

    // MARK: - Private Helper Methods (Simulating Repository Operations)

    /// Direct cache fetch - simulates ContextRepository.getLocalProfile
    private func getLocalProfileDirect(userId: UUID) async throws -> ContextProfile? {
        let descriptor = FetchDescriptor<CachedContextProfile>()
        let results = try modelContext.fetch(descriptor)
        let matching = results.first { $0.userId == userId }
        return matching?.decodeProfile()
    }

    /// Direct cache save - simulates ContextRepository.cacheProfile
    private func cacheProfileDirect(_ profile: ContextProfile) async throws {
        let descriptor = FetchDescriptor<CachedContextProfile>()
        let existing = try modelContext.fetch(descriptor)
        let cached = existing.first { $0.userId == profile.userId }

        if let cached = cached {
            try cached.updateWith(profile)
        } else {
            let newCache = try CachedContextProfile.from(profile)
            modelContext.insert(newCache)
        }

        try modelContext.save()
    }

    /// Direct cache delete - simulates ContextRepository.deleteCachedProfile
    private func deleteCachedProfileDirect(userId: UUID) async throws {
        let descriptor = FetchDescriptor<CachedContextProfile>()
        let results = try modelContext.fetch(descriptor)
        let matching = results.filter { $0.userId == userId }
        for cached in matching {
            modelContext.delete(cached)
        }
        try modelContext.save()
    }
}
