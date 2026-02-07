//
//  ConfigurationTests.swift
//  CoachMeTests
//
//  Created by Code Review on 2/5/26.
//

import XCTest
@testable import CoachMe

@MainActor
final class ConfigurationTests: XCTestCase {

    func testEnvironmentDefaultsToDevelopment() {
        XCTAssertEqual(Configuration.current, .development)
    }

    func testSupabaseURLIsNotEmpty() {
        XCTAssertFalse(Configuration.supabaseURL.isEmpty)
    }

    func testSupabaseURLIsValidURL() {
        let url = URL(string: Configuration.supabaseURL)
        XCTAssertNotNil(url, "Supabase URL should be a valid URL")
    }

    func testSupabasePublishableKeyIsNotEmpty() {
        XCTAssertFalse(Configuration.supabasePublishableKey.isEmpty)
    }

    func testValidateConfigurationPassesInDevelopment() {
        // In development with real credentials, validation should pass
        let isValid = Configuration.validateConfiguration()
        XCTAssertTrue(isValid, "Development credentials should pass validation")
    }

    func testSupabaseURLContainsSupabaseDomain() {
        XCTAssertTrue(Configuration.supabaseURL.contains("supabase.co"))
    }

    func testSupabaseKeyHasCorrectPrefix() {
        XCTAssertTrue(Configuration.supabasePublishableKey.hasPrefix("sb_publishable_"))
    }
}
