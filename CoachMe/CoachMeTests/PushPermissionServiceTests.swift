//
//  PushPermissionServiceTests.swift
//  CoachMeTests
//
//  Story 8.3: Push Permission Timing & Notification Preferences
//  Tests for PushPermissionService shouldRequestPermission() logic
//

import XCTest
@testable import CoachMe

@MainActor
final class PushPermissionServiceTests: XCTestCase {

    private var service: PushPermissionService!

    private static let suiteName = "PushPermissionServiceTests"

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

    // MARK: - shouldRequestPermission Tests

    /// AC #1: New user should NOT see push prompt on first launch
    func testShouldNotRequestWhenFirstSessionNotComplete() {
        XCTAssertFalse(
            service.shouldRequestPermission(firstSessionComplete: false),
            "Should not request permission before first session is complete"
        )
    }

    /// AC #2: After first session complete, should request if not previously requested
    func testShouldRequestWhenFirstSessionCompleteAndNotPreviouslyRequested() {
        XCTAssertTrue(
            service.shouldRequestPermission(firstSessionComplete: true),
            "Should request permission after first session when never asked before"
        )
    }

    /// Should not re-prompt after permission was already requested (UserDefaults flag)
    func testShouldNotRequestWhenAlreadyRequested() {
        testDefaults.set(true, forKey: "pushPermissionRequested")

        XCTAssertFalse(
            service.shouldRequestPermission(firstSessionComplete: true),
            "Should not request permission again after it was already requested"
        )
    }

    /// Should not show prompt when dismissed this session
    func testShouldNotRequestWhenDismissedThisSession() {
        service.markPromptDismissedThisSession()

        XCTAssertFalse(
            service.shouldRequestPermission(firstSessionComplete: true),
            "Should not show prompt when dismissed this session"
        )
    }

    /// After resetting session dismissal, should request again
    func testResetSessionDismissalAllowsPromptAgain() {
        service.markPromptDismissedThisSession()
        XCTAssertFalse(service.shouldRequestPermission(firstSessionComplete: true))

        service.resetSessionDismissal()
        XCTAssertTrue(
            service.shouldRequestPermission(firstSessionComplete: true),
            "Should allow prompt after session dismissal is reset"
        )
    }

    // MARK: - hasBeenRequested Tests

    func testHasBeenRequestedInitiallyFalse() {
        XCTAssertFalse(service.hasBeenRequested)
    }

    func testHasBeenRequestedTrueAfterRequest() {
        testDefaults.set(true, forKey: "pushPermissionRequested")
        XCTAssertTrue(service.hasBeenRequested)
    }
}
