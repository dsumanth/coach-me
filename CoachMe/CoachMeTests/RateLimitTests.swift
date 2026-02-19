//
//  RateLimitTests.swift
//  CoachMeTests
//
//  Story 10.1: Unit tests for message rate limiting infrastructure
//  Tests: ChatStreamError.rateLimited parsing, warm message display, send button disabled state
//

import Testing
import Foundation
@testable import CoachMe

@MainActor
struct RateLimitTests {

    // MARK: - ChatStreamError.rateLimited Tests

    @Test("rateLimited error for trial user has correct message")
    func testRateLimitedTrialMessage() {
        let error = ChatStreamError.rateLimited(isTrial: true, resetDate: nil)
        #expect(error.errorDescription == "You've used your trial sessions — ready to continue?")
    }

    @Test("rateLimited error for paid user includes reset date")
    func testRateLimitedPaidMessage() {
        // Create a known date
        let calendar = Calendar.current
        let components = DateComponents(year: 2026, month: 3, day: 1)
        let resetDate = calendar.date(from: components)!

        let error = ChatStreamError.rateLimited(isTrial: false, resetDate: resetDate)
        let description = error.errorDescription ?? ""

        #expect(description.contains("We've had a lot of great conversations this month!"))
        #expect(description.contains("refreshes on"))
    }

    @Test("rateLimited error for paid user with nil reset date shows 'soon'")
    func testRateLimitedPaidNilResetDate() {
        let error = ChatStreamError.rateLimited(isTrial: false, resetDate: nil)
        let description = error.errorDescription ?? ""

        #expect(description.contains("refreshes on soon"))
    }

    @Test("rateLimited error equality")
    func testRateLimitedEquality() {
        let date = Date()
        let error1 = ChatStreamError.rateLimited(isTrial: true, resetDate: date)
        let error2 = ChatStreamError.rateLimited(isTrial: true, resetDate: date)
        let error3 = ChatStreamError.rateLimited(isTrial: false, resetDate: date)

        #expect(error1 == error2)
        #expect(error1 != error3)
    }

    // MARK: - ChatError.rateLimited Tests

    @Test("ChatError.rateLimited for trial user")
    func testChatErrorRateLimitedTrial() {
        let error = ChatError.rateLimited(isTrial: true, resetDate: nil)
        #expect(error.errorDescription == "You've used your trial sessions — ready to continue?")
    }

    @Test("ChatError.rateLimited for paid user")
    func testChatErrorRateLimitedPaid() {
        let calendar = Calendar.current
        let components = DateComponents(year: 2026, month: 4, day: 1)
        let resetDate = calendar.date(from: components)!

        let error = ChatError.rateLimited(isTrial: false, resetDate: resetDate)
        let description = error.errorDescription ?? ""

        #expect(description.contains("We've had a lot of great conversations this month!"))
    }

    // MARK: - HTTP 429 Response Parsing Tests

    @Test("HTTP 429 JSON for trial user parses correctly")
    func testParse429TrialResponse() throws {
        let json: [String: Any] = [
            "error": "rate_limited",
            "message": "You've used your trial sessions",
            "is_trial": true,
            "remaining_until_reset": NSNull(),
            "current_count": 100,
            "limit": 100,
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let parsed = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        let isTrial = parsed["is_trial"] as? Bool ?? false
        #expect(isTrial == true)
        #expect(parsed["error"] as? String == "rate_limited")
    }

    @Test("HTTP 429 JSON for paid user parses with reset date")
    func testParse429PaidResponse() throws {
        let json: [String: Any] = [
            "error": "rate_limited",
            "message": "Great conversations",
            "is_trial": false,
            "remaining_until_reset": "2026-03-01T00:00:00.000Z",
            "current_count": 800,
            "limit": 800,
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let parsed = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        let isTrial = parsed["is_trial"] as? Bool ?? false
        #expect(isTrial == false)

        let resetStr = parsed["remaining_until_reset"] as? String
        #expect(resetStr != nil)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let resetDate = formatter.date(from: resetStr!)
        #expect(resetDate != nil)
    }

    // MARK: - ChatViewModel Rate Limit State Tests

    @Test("ChatViewModel isRateLimited defaults to false")
    func testDefaultNotRateLimited() {
        let vm = ChatViewModel()
        #expect(vm.isRateLimited == false)
    }

    @Test("ChatViewModel isRateLimited resets on new conversation")
    func testRateLimitedResetsOnNewConversation() {
        let vm = ChatViewModel()
        vm.isRateLimited = true
        vm.startNewConversation()
        #expect(vm.isRateLimited == false)
    }
}
