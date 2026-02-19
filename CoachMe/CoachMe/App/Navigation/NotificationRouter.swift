//
//  NotificationRouter.swift
//  CoachMe
//
//  Story 8.2 — APNs push infrastructure
//  Story 8.7 — Proactive push tap handling + push_log open tracking
//

import Foundation
import Supabase

/// Routes push-notification taps to the correct conversation.
///
/// **Payload contract** (see Story 8.2 Dev Notes):
/// ```json
/// {
///   "conversation_id": "uuid-or-null",
///   "domain": "career",
///   "action": "open_conversation" | "new_conversation"
/// }
/// ```
///
/// **Proactive push payload** (Story 8.7):
/// ```json
/// {
///   "domain": "career",
///   "action": "new_conversation",
///   "push_type": "event_based" | "pattern_based" | "re_engagement",
///   "push_log_id": "uuid"
/// }
/// ```
///
/// **Validation rules (Task 4.3):**
/// - `conversation_id` must be a well-formed UUID string.
/// - The conversation must exist in Supabase *and* belong to the current user.
/// - On any failure, fall back to opening a new conversation.
@MainActor
final class NotificationRouter {
    static let shared = NotificationRouter()

    /// The app-level Router. Set by RootView on appear so notification taps
    /// can drive navigation after the view hierarchy is established.
    weak var appRouter: Router?

    /// Pending payload received before the app (or Router) was fully loaded.
    /// Processed after auth restoration in RootView.
    private(set) var pendingNotificationPayload: [AnyHashable: Any]?

    private let conversationService: ConversationServiceProtocol

    private init() {
        self.conversationService = ConversationService.shared
    }

    /// Test-injectable initializer.
    init(conversationService: ConversationServiceProtocol) {
        self.conversationService = conversationService
    }

    // MARK: - Public API

    /// Called by `AppDelegate.userNotificationCenter(_:didReceive:)`.
    func handleNotificationTap(userInfo: [AnyHashable: Any]) async {
        guard let router = appRouter else {
            // App not yet ready — store for later processing.
            pendingNotificationPayload = userInfo
            #if DEBUG
            print("NotificationRouter: Router not ready — queued payload for later")
            #endif
            return
        }

        await routeNotification(userInfo: userInfo, router: router)
    }

    /// Re-processes a payload that arrived before the Router was ready (cold launch).
    func processPendingNotification() async {
        guard let payload = pendingNotificationPayload else { return }
        pendingNotificationPayload = nil

        guard let router = appRouter else { return }
        await routeNotification(userInfo: payload, router: router)
    }

    // MARK: - Internal (visible for testing)

    /// Parses and validates the notification payload, then navigates.
    func routeNotification(userInfo: [AnyHashable: Any], router: Router) async {
        // Story 8.7: Parse push_type to detect proactive notifications
        let pushType = userInfo["push_type"] as? String
        let pushLogId = userInfo["push_log_id"] as? String

        // Story 8.7: Record opened status for proactive pushes (fire-and-forget)
        if let pushLogId {
            Task {
                await recordPushOpened(pushLogId: pushLogId)
            }
        }

        // Story 8.7: Proactive pushes always open a NEW conversation
        // (coach references the topic naturally via domain routing)
        if pushType != nil {
            router.navigateToChat()
            return
        }

        // Standard notification routing (Story 8.2)

        // 1. Extract conversation_id and validate as UUID
        guard let rawId = userInfo["conversation_id"] as? String,
              let conversationId = UUID(uuidString: rawId) else {
            // No valid conversation_id — start new conversation
            router.navigateToChat()
            return
        }

        // 2. Verify the conversation exists and the current user owns it
        let hasAccess = await conversationService.conversationExists(id: conversationId)
        guard hasAccess else {
            #if DEBUG
            print("NotificationRouter: conversation \(conversationId) not accessible — opening new chat")
            #endif
            router.navigateToChat()
            return
        }

        // 3. Navigate to the existing conversation
        router.navigateToChat(conversationId: conversationId)
    }

    // MARK: - Push Log Open Tracking (Story 8.7, Task 5.3)

    /// Record that a proactive push notification was opened by updating push_log.
    private func recordPushOpened(pushLogId: String) async {
        do {
            try await AppEnvironment.shared.supabase
                .from("push_log")
                .update(["opened": true])
                .eq("id", value: pushLogId)
                .execute()
            #if DEBUG
            print("NotificationRouter: Recorded push open for \(pushLogId)")
            #endif
        } catch {
            // Non-critical — log but don't disrupt navigation
            #if DEBUG
            print("NotificationRouter: Failed to record push open: \(error)")
            #endif
        }
    }
}
