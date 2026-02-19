//
//  PushPermissionPromptTests.swift
//  CoachMeTests
//
//  Story 8.3: Push Permission Timing & Notification Preferences
//  Tests for push permission prompt visibility conditions
//

import XCTest
@testable import CoachMe

@MainActor
final class PushPermissionPromptTests: XCTestCase {

    private var service: PushPermissionService!

    private static let suiteName = "PushPermissionPromptTests"

    /// Access the test suite defaults for directly setting keys
    private var testDefaults: UserDefaults {
        UserDefaults(suiteName: Self.suiteName)!
    }

    override func setUp() {
        super.setUp()
        UserDefaults().removePersistentDomain(forName: Self.suiteName)
        service = PushPermissionService(defaults: UserDefaults(suiteName: Self.suiteName)!)
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: Self.suiteName)
        super.tearDown()
    }

    // MARK: - AC #1: New User Does NOT See Push Prompt

    /// Verifies that a new user who has never completed a session does not see the prompt
    func testNewUserDoesNotSeePrompt() {
        // New user: firstSessionComplete = false, no flags set
        XCTAssertFalse(
            service.shouldRequestPermission(firstSessionComplete: false),
            "AC #1: New user on first launch must NOT see push permission prompt"
        )
    }

    // MARK: - AC #2: After First Session, Prompt Appears

    func testPromptAppearsAfterFirstSessionComplete() {
        XCTAssertTrue(
            service.shouldRequestPermission(firstSessionComplete: true),
            "AC #2: User should see prompt after first session completes"
        )
    }

    // MARK: - Prompt Suppression After Denial

    func testPromptSuppressedAfterDenial() {
        // Simulate the user declining the OS permission dialog
        testDefaults.set(true, forKey: "pushPermissionRequested")

        XCTAssertFalse(
            service.shouldRequestPermission(firstSessionComplete: true),
            "Should not re-prompt after permission was already requested (denied or granted)"
        )
    }

    // MARK: - Session Dismissal Suppression

    func testSessionDismissalSuppressesPrompt() {
        service.markPromptDismissedThisSession()

        XCTAssertFalse(
            service.shouldRequestPermission(firstSessionComplete: true),
            "Should not show prompt when user tapped 'Not now' this session"
        )
    }

    func testNewSessionAllowsPromptAfterPreviousDismissal() {
        service.markPromptDismissedThisSession()
        XCTAssertFalse(service.shouldRequestPermission(firstSessionComplete: true))

        // Simulate new session
        service.resetSessionDismissal()
        XCTAssertTrue(
            service.shouldRequestPermission(firstSessionComplete: true),
            "New session should allow prompt to appear again"
        )
    }

    // MARK: - Message Threshold Test (Integration-style)

    /// Validates that the ChatViewModel session-complete threshold requires 4+ messages.
    /// The threshold of 4 ensures the user has had a meaningful exchange (2 user + 2 assistant)
    /// before the app asks for push notification permission — avoids prompting during casual browsing.
    func testSessionCompleteRequiresMinimumMessages() {
        // The threshold is defined as a static constant
        XCTAssertEqual(
            ChatViewModel.sessionCompleteMessageThreshold,
            4,
            "Session should require at least 4 messages (2 exchanges) before triggering push permission check"
        )
    }
}
