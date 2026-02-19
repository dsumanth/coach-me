//
//  LearningSignalService.swift
//  CoachMe
//
//  Story 8.1: Learning Signals Infrastructure
//  Service for recording and querying behavioral learning signals
//

import Foundation
import Supabase

/// Errors specific to learning signal operations
/// Per UX-11: Use warm, first-person error messages
enum LearningSignalError: LocalizedError, Equatable {
    case recordFailed(String)
    case fetchFailed(String)
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .recordFailed(let reason):
            return "I couldn't save that learning signal. \(reason)"
        case .fetchFailed(let reason):
            return "I couldn't load your learning data. \(reason)"
        case .notAuthenticated:
            return "I need you to sign in before I can track your progress."
        }
    }

    static func == (lhs: LearningSignalError, rhs: LearningSignalError) -> Bool {
        switch (lhs, rhs) {
        case (.notAuthenticated, .notAuthenticated):
            return true
        case (.recordFailed(let a), .recordFailed(let b)):
            return a == b
        case (.fetchFailed(let a), .fetchFailed(let b)):
            return a == b
        default:
            return false
        }
    }
}

/// Insight feedback action
enum InsightFeedbackAction: String, Sendable {
    case confirmed = "insight_confirmed"
    case dismissed = "insight_dismissed"
}

/// Service for recording and querying learning signals
/// All signal writes are designed to be non-blocking (fire-and-forget via Task { })
@MainActor
final class LearningSignalService {
    // MARK: - Singleton

    static let shared = LearningSignalService()

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

    // MARK: - Signal Recording

    /// Records insight feedback (confirmed or dismissed)
    /// Called via non-blocking Task { } from ContextRepository
    /// - Parameters:
    ///   - insightId: The insight's UUID
    ///   - action: Whether the insight was confirmed or dismissed
    ///   - category: The insight category (values, goals, situation, pattern)
    func recordInsightFeedback(insightId: UUID, action: InsightFeedbackAction, category: String) async throws {
        let userId = try await getCurrentUserId()

        let signalData: [String: AnyJSON] = [
            "insight_id": .string(insightId.uuidString),
            "category": .string(category)
        ]

        let insert = LearningSignalInsert(
            userId: userId,
            signalType: action.rawValue,
            signalData: signalData
        )

        do {
            try await supabase
                .from("learning_signals")
                .insert(insert)
                .execute()

            #if DEBUG
            print("LearningSignalService: Recorded \(action.rawValue) for insight \(insightId)")
            #endif
        } catch {
            #if DEBUG
            print("LearningSignalService: Failed to record insight feedback: \(error)")
            #endif
            throw LearningSignalError.recordFailed(error.localizedDescription)
        }
    }

    /// Records session engagement metrics when a conversation session ends
    /// Called via non-blocking Task { } from ChatViewModel
    /// - Parameters:
    ///   - conversationId: The conversation UUID
    ///   - messageCount: Total messages in the session
    ///   - avgMessageLength: Average character count of user messages
    ///   - durationSeconds: Session duration in seconds
    func recordSessionEngagement(
        conversationId: UUID,
        messageCount: Int,
        avgMessageLength: Int,
        durationSeconds: Int
    ) async throws {
        let userId = try await getCurrentUserId()

        var signalData: [String: AnyJSON] = [
            "conversation_id": .string(conversationId.uuidString),
            "message_count": .integer(messageCount),
            "avg_message_length": .integer(avgMessageLength),
            "duration_seconds": .integer(durationSeconds)
        ]

        // Look up domain from conversation (best-effort, non-blocking)
        if let conversations: [ConversationService.Conversation] = try? await supabase
            .from("conversations")
            .select("id, domain")
            .eq("id", value: conversationId.uuidString)
            .limit(1)
            .execute()
            .value,
           let domain = conversations.first?.domain {
            signalData["domain"] = .string(domain)
        }

        let insert = LearningSignalInsert(
            userId: userId,
            signalType: "session_completed",
            signalData: signalData
        )

        do {
            try await supabase
                .from("learning_signals")
                .insert(insert)
                .execute()

            #if DEBUG
            print("LearningSignalService: Recorded session engagement for conversation \(conversationId)")
            #endif
        } catch {
            #if DEBUG
            print("LearningSignalService: Failed to record session engagement: \(error)")
            #endif
            throw LearningSignalError.recordFailed(error.localizedDescription)
        }
    }

    // MARK: - Signal Querying

    /// Fetches learning signals for a user, optionally filtered by type
    /// - Parameters:
    ///   - userId: The user's UUID
    ///   - signalType: Optional filter by signal type
    ///   - limit: Maximum number of results (default 100)
    /// - Returns: Array of LearningSignal ordered by created_at descending
    func fetchSignals(userId: UUID, signalType: String? = nil, limit: Int = 100) async throws -> [LearningSignal] {
        do {
            // Apply all filters before transforms (.order, .limit)
            var filterQuery = supabase
                .from("learning_signals")
                .select()
                .eq("user_id", value: userId.uuidString)

            if let signalType = signalType {
                filterQuery = filterQuery.eq("signal_type", value: signalType)
            }

            let signals: [LearningSignal] = try await filterQuery
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value

            #if DEBUG
            print("LearningSignalService: Fetched \(signals.count) signals for user \(userId)")
            #endif

            return signals
        } catch {
            #if DEBUG
            print("LearningSignalService: Failed to fetch signals: \(error)")
            #endif
            throw LearningSignalError.fetchFailed(error.localizedDescription)
        }
    }

    /// Fetches aggregate data for downstream consumers (domain preferences, session frequency, engagement depth)
    /// Limits to most recent 500 signals to maintain AC-4 200ms query target
    /// - Parameter userId: The user's UUID
    /// - Returns: Aggregated metrics from learning signals
    func fetchAggregates(userId: UUID) async throws -> LearningSignalAggregates {
        do {
            // Fetch recent signals for client-side aggregation (capped at 500 for performance per AC-4)
            // Future stories can move to server-side RPC for full-history aggregation
            let signals: [LearningSignal] = try await supabase
                .from("learning_signals")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .limit(500)
                .execute()
                .value

            return LearningSignalAggregates.compute(from: signals)
        } catch {
            #if DEBUG
            print("LearningSignalService: Failed to fetch aggregates: \(error)")
            #endif
            throw LearningSignalError.fetchFailed(error.localizedDescription)
        }
    }

    // MARK: - Private Helpers

    private func getCurrentUserId() async throws -> UUID {
        do {
            let session = try await supabase.auth.session
            return session.user.id
        } catch {
            throw LearningSignalError.notAuthenticated
        }
    }
}

/// Aggregate metrics derived from learning signals (AC-3)
struct LearningSignalAggregates: Sendable, Equatable {
    let domainPreferences: [String: Int]
    let sessionCount: Int
    let averageSessionDurationSeconds: Int
    let averageMessagesPerSession: Int
    let insightsConfirmed: Int
    let insightsDismissed: Int

    /// Computes aggregate metrics from raw signals
    /// Extracted as a static method so tests can verify the real computation logic
    static func compute(from signals: [LearningSignal]) -> LearningSignalAggregates {
        var domainCounts: [String: Int] = [:]
        var totalDurationSeconds = 0
        var sessionCount = 0
        var totalMessageCount = 0

        for signal in signals {
            switch signal.signalType {
            case "session_completed":
                sessionCount += 1
                if case .string(let domain) = signal.signalData["domain"] {
                    domainCounts[domain, default: 0] += 1
                }
                if case .integer(let duration) = signal.signalData["duration_seconds"] {
                    totalDurationSeconds += duration
                }
                if case .integer(let count) = signal.signalData["message_count"] {
                    totalMessageCount += count
                }

            case "insight_confirmed", "insight_dismissed":
                break

            default:
                break
            }
        }

        let avgSessionDuration = sessionCount > 0 ? totalDurationSeconds / sessionCount : 0
        let avgMessagesPerSession = sessionCount > 0 ? totalMessageCount / sessionCount : 0

        let insightConfirmed = signals.filter { $0.signalType == "insight_confirmed" }.count
        let insightDismissed = signals.filter { $0.signalType == "insight_dismissed" }.count

        return LearningSignalAggregates(
            domainPreferences: domainCounts,
            sessionCount: sessionCount,
            averageSessionDurationSeconds: avgSessionDuration,
            averageMessagesPerSession: avgMessagesPerSession,
            insightsConfirmed: insightConfirmed,
            insightsDismissed: insightDismissed
        )
    }
}
