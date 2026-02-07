//
//  KeychainManagerTests.swift
//  CoachMeTests
//
//  Created by Code Review on 2/6/26.
//

import XCTest
@testable import CoachMe

@MainActor
final class KeychainManagerTests: XCTestCase {

    private let manager = KeychainManager.shared

    override func tearDown() async throws {
        // Clean up after each test
        try? manager.clearAllAuthData()
        try await super.tearDown()
    }

    // MARK: - Save and Load Tests

    func testSaveAndLoadData() throws {
        // Given
        let testData = "test-token-12345".data(using: .utf8)!
        let key = KeychainKey.accessToken

        // When
        try manager.save(testData, for: key)
        let loadedData = try manager.load(for: key)

        // Then
        XCTAssertEqual(loadedData, testData)
    }

    func testSaveAndLoadString() throws {
        // Given
        let testString = "refresh-token-67890"
        let key = KeychainKey.refreshToken

        // When
        try manager.save(testString, for: key)
        let loadedString = try manager.loadString(for: key)

        // Then
        XCTAssertEqual(loadedString, testString)
    }

    func testLoadReturnsNilForNonexistentKey() throws {
        // Given - ensure key doesn't exist
        try? manager.delete(for: .userId)

        // When
        let result = try manager.load(for: .userId)

        // Then
        XCTAssertNil(result)
    }

    // MARK: - Delete Tests

    func testDeleteRemovesItem() throws {
        // Given
        let testData = "to-be-deleted".data(using: .utf8)!
        try manager.save(testData, for: .accessToken)

        // When
        try manager.delete(for: .accessToken)
        let result = try manager.load(for: .accessToken)

        // Then
        XCTAssertNil(result)
    }

    func testDeleteNonexistentKeyDoesNotThrow() {
        // Given - key doesn't exist
        try? manager.delete(for: .userId)

        // When/Then - should not throw
        XCTAssertNoThrow(try manager.delete(for: .userId))
    }

    // MARK: - Exists Tests

    func testExistsReturnsTrueForExistingKey() throws {
        // Given
        let testData = "exists-test".data(using: .utf8)!
        try manager.save(testData, for: .accessToken)

        // When
        let exists = manager.exists(for: .accessToken)

        // Then
        XCTAssertTrue(exists)
    }

    func testExistsReturnsFalseForNonexistentKey() {
        // Given - ensure key doesn't exist
        try? manager.delete(for: .userId)

        // When
        let exists = manager.exists(for: .userId)

        // Then
        XCTAssertFalse(exists)
    }

    // MARK: - Overwrite Tests

    func testSaveOverwritesExistingValue() throws {
        // Given
        let originalValue = "original-value"
        let newValue = "new-value"
        try manager.save(originalValue, for: .accessToken)

        // When
        try manager.save(newValue, for: .accessToken)
        let loadedValue = try manager.loadString(for: .accessToken)

        // Then
        XCTAssertEqual(loadedValue, newValue)
    }

    // MARK: - Clear All Tests

    func testClearAllAuthDataRemovesAllKeys() throws {
        // Given
        try manager.save("access", for: .accessToken)
        try manager.save("refresh", for: .refreshToken)
        try manager.save("user-id", for: .userId)

        // When
        try manager.clearAllAuthData()

        // Then
        XCTAssertFalse(manager.exists(for: .accessToken))
        XCTAssertFalse(manager.exists(for: .refreshToken))
        XCTAssertFalse(manager.exists(for: .userId))
    }

    // MARK: - Codable Tests

    func testSaveAndLoadCodableType() throws {
        // Given
        struct TestUser: Codable, Equatable {
            let id: String
            let name: String
        }
        let testUser = TestUser(id: "123", name: "Test User")

        // When
        try manager.save(testUser, for: .userId)
        let loadedUser: TestUser? = try manager.load(for: .userId)

        // Then
        XCTAssertEqual(loadedUser, testUser)
    }
}
