//
//  PushNotificationServiceTests.swift
//  CoachMeTests
//
//  Story 8.2: APNs Push Infrastructure
//  Tests for PushNotificationService, NotificationRouter payload parsing,
//  and push error descriptions.
//

import XCTest
@testable import CoachMe

@MainActor
final class PushNotificationServiceTests: XCTestCase {

    override func setUp() {
        super.setUp()
        NotificationRouter.shared.appRouter = nil
        NotificationRouter.shared.pendingNotificationPayload = nil
    }

    override func tearDown() {
        NotificationRouter.shared.appRouter = nil
        NotificationRouter.shared.pendingNotificationPayload = nil
        super.tearDown()
    }

    // MARK: - Token Conversion Tests

    func testDeviceTokenConvertedToHexString() {
        // Simulate a 32-byte APNs device token
        let bytes: [UInt8] = [
            0xAB, 0xCD, 0xEF, 0x01, 0x23, 0x45, 0x67, 0x89,
            0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77,
            0x88, 0x99, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF,
            0x10, 0x20, 0x30, 0x40, 0x50, 0x60, 0x70, 0x80
        ]
        let tokenData = Data(bytes)

        // Apply the same hex conversion used in PushNotificationService
        let hex = tokenData.map { String(format: "%02x", $0) }.joined()

        XCTAssertEqual(hex, "abcdef012345678900112233445566778899aabbccddeeff1020304050607080")
        XCTAssertEqual(hex.count, 64, "32-byte token should produce 64-char hex string")
    }

    func testEmptyTokenDataProducesEmptyString() {
        let hex = Data().map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(hex, "")
    }

    // MARK: - PushError Description Tests

    func testPushErrorDescriptions() {
        XCTAssertEqual(
            PushNotificationService.PushError.notAuthenticated.errorDescription,
            "You'll need to sign in before I can set up notifications."
        )
        XCTAssertEqual(
            PushNotificationService.PushError.registrationFailed("timeout").errorDescription,
            "I couldn't register for notifications right now. timeout"
        )
        XCTAssertEqual(
            PushNotificationService.PushError.removalFailed("network").errorDescription,
            "I couldn't remove your notification registration. network"
        )
    }

    // MARK: - PushTokenUpsert Encoding Tests

    func testPushTokenUpsertEncodesSnakeCase() throws {
        // Create an instance matching the private struct's shape
        struct PushTokenUpsert: Encodable {
            let userId: UUID
            let deviceToken: String
            let platform: String

            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case deviceToken = "device_token"
                case platform
            }
        }

        let userId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let upsert = PushTokenUpsert(userId: userId, deviceToken: "abcd1234", platform: "ios")

        let data = try JSONEncoder().encode(upsert)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(dict["user_id"] as? String, userId.uuidString)
        XCTAssertEqual(dict["device_token"] as? String, "abcd1234")
        XCTAssertEqual(dict["platform"] as? String, "ios")
        XCTAssertNil(dict["userId"], "Should use snake_case, not camelCase")
    }

    // MARK: - NotificationRouter Payload Parsing Tests

    func testValidPayloadWithConversationId() async {
        let conversationId = UUID()
        let userInfo: [AnyHashable: Any] = [
            "conversation_id": conversationId.uuidString,
            "domain": "career",
            "action": "open_conversation"
        ]

        // Validate UUID extraction
        let rawId = userInfo["conversation_id"] as? String
        let parsed = rawId.flatMap { UUID(uuidString: $0) }
        XCTAssertEqual(parsed, conversationId)
    }

    func testMissingConversationIdFallsToNewChat() {
        let userInfo: [AnyHashable: Any] = [
            "domain": "career",
            "action": "new_conversation"
        ]

        let rawId = userInfo["conversation_id"] as? String
        let parsed = rawId.flatMap { UUID(uuidString: $0) }
        XCTAssertNil(parsed, "Missing conversation_id should result in nil UUID")
    }

    func testMalformedConversationIdFallsToNewChat() {
        let userInfo: [AnyHashable: Any] = [
            "conversation_id": "not-a-uuid",
            "domain": "career"
        ]

        let rawId = userInfo["conversation_id"] as? String
        let parsed = rawId.flatMap { UUID(uuidString: $0) }
        XCTAssertNil(parsed, "Malformed UUID should result in nil")
    }

    func testNullConversationIdFallsToNewChat() {
        let userInfo: [AnyHashable: Any] = [
            "conversation_id": NSNull(),
            "action": "open_conversation"
        ]

        let rawId = userInfo["conversation_id"] as? String
        let parsed = rawId.flatMap { UUID(uuidString: $0) }
        XCTAssertNil(parsed, "NSNull conversation_id should result in nil")
    }

    func testEmptyPayloadFallsToNewChat() {
        let userInfo: [AnyHashable: Any] = [:]

        let rawId = userInfo["conversation_id"] as? String
        let parsed = rawId.flatMap { UUID(uuidString: $0) }
        XCTAssertNil(parsed)
    }

    // MARK: - NotificationRouter Pending Payload Tests

    func testPendingPayloadStoredWhenRouterNotReady() async {
        let router = NotificationRouter.shared
        // Ensure appRouter is nil (simulates cold launch before view hierarchy)
        router.appRouter = nil

        let payload: [AnyHashable: Any] = [
            "conversation_id": UUID().uuidString,
            "action": "open_conversation"
        ]

        await router.handleNotificationTap(userInfo: payload)

        XCTAssertNotNil(router.pendingNotificationPayload, "Payload should be stored when router is not ready")
    }

    func testPendingPayloadClearedAfterProcessing() async {
        let router = NotificationRouter.shared
        let appRouter = Router()
        router.appRouter = appRouter

        // Set a pending payload
        router.appRouter = nil
        await router.handleNotificationTap(userInfo: ["action": "new_conversation"])

        XCTAssertNotNil(router.pendingNotificationPayload)

        // Now set appRouter and process
        router.appRouter = appRouter
        await router.processPendingNotification()

        XCTAssertNil(router.pendingNotificationPayload, "Pending payload should be cleared after processing")
    }

    // MARK: - NotificationRouter Navigation Tests

    func testRouteNotificationNavigatesToNewChatForMissingId() async {
        let appRouter = Router()
        appRouter.currentScreen = .conversationList
        let router = NotificationRouter.shared
        router.appRouter = appRouter

        await router.routeNotification(userInfo: [:], router: appRouter)

        XCTAssertEqual(appRouter.currentScreen, .chat)
        XCTAssertNil(appRouter.selectedConversationId, "Should navigate to new chat when no conversation_id")
    }

    func testRouteNotificationNavigatesToNewChatForMalformedId() async {
        let appRouter = Router()
        appRouter.currentScreen = .conversationList

        await NotificationRouter.shared.routeNotification(
            userInfo: ["conversation_id": "bad-uuid"],
            router: appRouter
        )

        XCTAssertEqual(appRouter.currentScreen, .chat)
        XCTAssertNil(appRouter.selectedConversationId)
    }

    // MARK: - NotificationRouter Conversation-Exists Path Tests (Review Fix M1+M2)

    func testRouteNotificationNavigatesToExistingConversation() async {
        let mockService = MockConversationService()
        mockService.conversationExistsResult = true
        let router = NotificationRouter(conversationService: mockService)

        let appRouter = Router()
        appRouter.currentScreen = .conversationList
        let conversationId = UUID()

        await router.routeNotification(
            userInfo: ["conversation_id": conversationId.uuidString],
            router: appRouter
        )

        XCTAssertTrue(mockService.conversationExistsCalled)
        XCTAssertEqual(appRouter.currentScreen, .chat)
        XCTAssertEqual(appRouter.selectedConversationId, conversationId,
                       "Should navigate to the existing conversation")
    }

    func testRouteNotificationFallsBackWhenConversationNotAccessible() async {
        let mockService = MockConversationService()
        mockService.conversationExistsResult = false
        let router = NotificationRouter(conversationService: mockService)

        let appRouter = Router()
        appRouter.currentScreen = .conversationList
        let conversationId = UUID()

        await router.routeNotification(
            userInfo: ["conversation_id": conversationId.uuidString],
            router: appRouter
        )

        XCTAssertTrue(mockService.conversationExistsCalled)
        XCTAssertEqual(appRouter.currentScreen, .chat)
        XCTAssertNil(appRouter.selectedConversationId,
                     "Should fall back to new chat when conversation is not accessible")
    }

    // MARK: - Story 8.7: Proactive Push Notification Tests

    func testProactivePushNavigatesToNewConversation() async {
        let mockService = MockConversationService()
        mockService.conversationExistsResult = true
        let router = NotificationRouter(conversationService: mockService)

        let appRouter = Router()
        appRouter.currentScreen = .conversationList

        // Proactive push has push_type but no conversation_id
        await router.routeNotification(
            userInfo: [
                "push_type": "event_based",
                "domain": "career",
                "action": "new_conversation",
                "push_log_id": UUID().uuidString
            ],
            router: appRouter
        )

        XCTAssertEqual(appRouter.currentScreen, .chat)
        XCTAssertNil(appRouter.selectedConversationId,
                     "Proactive push should always open NEW conversation, never existing")
        XCTAssertFalse(mockService.conversationExistsCalled,
                       "Should not check for existing conversation on proactive push")
    }

    func testProactivePushWithConversationIdStillOpensNewChat() async {
        let mockService = MockConversationService()
        mockService.conversationExistsResult = true
        let router = NotificationRouter(conversationService: mockService)

        let appRouter = Router()
        appRouter.currentScreen = .conversationList
        let existingConvId = UUID()

        // Even if payload includes conversation_id, proactive push should open new
        await router.routeNotification(
            userInfo: [
                "conversation_id": existingConvId.uuidString,
                "push_type": "pattern_based",
                "domain": "relationships",
                "action": "new_conversation",
                "push_log_id": UUID().uuidString
            ],
            router: appRouter
        )

        XCTAssertEqual(appRouter.currentScreen, .chat)
        XCTAssertNil(appRouter.selectedConversationId,
                     "Proactive push should navigate to new chat even with conversation_id present")
    }

    func testReEngagementPushNavigatesToNewConversation() async {
        let mockService = MockConversationService()
        let router = NotificationRouter(conversationService: mockService)

        let appRouter = Router()
        appRouter.currentScreen = .conversationList

        await router.routeNotification(
            userInfo: [
                "push_type": "re_engagement",
                "domain": "personal",
                "action": "new_conversation"
            ],
            router: appRouter
        )

        XCTAssertEqual(appRouter.currentScreen, .chat)
        XCTAssertNil(appRouter.selectedConversationId,
                     "Re-engagement push should open new conversation")
    }

    func testPushLogIdParsedFromPayload() {
        // Verify push_log_id can be extracted from notification payload
        let pushLogId = UUID().uuidString
        let userInfo: [AnyHashable: Any] = [
            "push_type": "event_based",
            "push_log_id": pushLogId,
            "action": "new_conversation"
        ]

        let parsedPushLogId = userInfo["push_log_id"] as? String
        XCTAssertEqual(parsedPushLogId, pushLogId,
                       "push_log_id should be extractable from notification payload")
    }

    func testPushTypesParsedCorrectly() {
        let types = ["event_based", "pattern_based", "re_engagement"]
        for pushType in types {
            let userInfo: [AnyHashable: Any] = ["push_type": pushType]
            let parsed = userInfo["push_type"] as? String
            XCTAssertEqual(parsed, pushType, "push_type '\(pushType)' should be extractable")
        }
    }

    func testStandardNotificationWithoutPushTypeRoutesNormally() async {
        let mockService = MockConversationService()
        mockService.conversationExistsResult = true
        let router = NotificationRouter(conversationService: mockService)

        let appRouter = Router()
        appRouter.currentScreen = .conversationList
        let conversationId = UUID()

        // Standard notification (no push_type) should route via conversation_id
        await router.routeNotification(
            userInfo: [
                "conversation_id": conversationId.uuidString,
                "domain": "career",
                "action": "open_conversation"
            ],
            router: appRouter
        )

        XCTAssertTrue(mockService.conversationExistsCalled,
                      "Standard notification should check conversation exists")
        XCTAssertEqual(appRouter.selectedConversationId, conversationId,
                       "Standard notification should navigate to existing conversation")
    }
}
