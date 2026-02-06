//
//  ConfigurationTests.swift
//  CoachMeTests
//
//  Created by Code Review on 2/5/26.
//

import XCTest
@testable import CoachMe

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

    func testSupabaseAnonKeyIsNotEmpty() {
        XCTAssertFalse(Configuration.supabaseAnonKey.isEmpty)
    }

    func testValidateConfigurationDetectsPlaceholders() {
        // In development with placeholders, validation should return false
        let isValid = Configuration.validateConfiguration()
        // This will be false until real credentials are added
        XCTAssertFalse(isValid, "Placeholder credentials should not pass validation")
    }
}
