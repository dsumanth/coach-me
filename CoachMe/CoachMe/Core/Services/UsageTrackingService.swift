//
//  UsageTrackingService.swift
//  CoachMe
//
//  Story 10.5: Usage Transparency UI
//  Service for fetching message usage data from the message_usage table
//

import Foundation
import Supabase

/// Errors specific to usage tracking operations
/// Per UX-11: Warm, first-person error messages
enum UsageTrackingError: LocalizedError, Equatable {
    case fetchFailed(String)
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .fetchFailed(let reason):
            return "I couldn't check your usage right now — don't worry, you can keep chatting. \(reason)"
        case .notAuthenticated:
            return "I need you to sign in before I can check your usage."
        }
    }

    static func == (lhs: UsageTrackingError, rhs: UsageTrackingError) -> Bool {
        switch (lhs, rhs) {
        case (.notAuthenticated, .notAuthenticated):
            return true
        case (.fetchFailed(let a), .fetchFailed(let b)):
            return a == b
        default:
            return false
        }
    }
}

/// Service for fetching and managing message usage data
@MainActor
final class UsageTrackingService {
    // MARK: - Singleton

    static let shared = UsageTrackingService()

    // MARK: - Properties

    private let supabase: SupabaseClient

    // MARK: - Initialization

    private init() {
        self.supabase = AppEnvironment.shared.supabase
    }

    /// For testing with mock dependencies
    init(supabase: SupabaseClient) {
        self.supabase = supabase
    }

    // MARK: - Fetch Usage

    /// Fetches the current billing period's usage for a user.
    /// Returns nil if no usage row exists yet (user hasn't sent any messages).
    func fetchCurrentUsage(userId: UUID) async throws -> MessageUsage? {
        do {
            // Query the most recent usage row for this user, ordered by updated_at descending.
            // For paid users this will be the current YYYY-MM period;
            // for trial users this will be the "trial" period.
            let usages: [MessageUsage] = try await supabase
                .from("message_usage")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("updated_at", ascending: false)
                .limit(1)
                .execute()
                .value

            return usages.first
        } catch {
            #if DEBUG
            print("UsageTrackingService: Failed to fetch usage — \(error.localizedDescription)")
            #endif
            throw UsageTrackingError.fetchFailed(error.localizedDescription)
        }
    }

    // MARK: - Optimistic Increment

    /// Optimistically increments the local message count for instant UI updates.
    /// The real count will be synced from the server on the next fetch.
    func incrementLocalCount(_ usage: inout MessageUsage) {
        usage.messageCount += 1
    }
}
