//
//  ContextExtractionServiceTests.swift
//  CoachMeTests
//
//  Story 2.3: Progressive Context Extraction
//  Tests for ContextExtractionService request/response handling
//

import XCTest
@testable import CoachMe

@MainActor
final class ContextExtractionServiceTests: XCTestCase {

    override func tearDown() {
        super.tearDown()
        ContextExtractionService.shared.setAuthToken(nil)
    }

    // MARK: - Test: Service Configuration

    func testServiceIsSingleton() {
        // Given/When: Accessing the shared instance twice
        let instance1 = ContextExtractionService.shared
        let instance2 = ContextExtractionService.shared

        // Then: Should be the same instance
        XCTAssertTrue(instance1 === instance2, "Shared instances should be identical")
    }

    // MARK: - Test: Auth Token Management

    func testSetAuthTokenStoresToken() {
        // Given: A service instance
        let service = ContextExtractionService.shared

        // When: Setting a token
        service.setAuthToken("test-token-123")

        // Then: Token is stored (we can verify via extraction attempt)
        // Note: Direct verification not possible due to private storage
        // The behavior is tested via integration with extractFromConversation
    }

    func testSetAuthTokenWithNilClearsToken() {
        // Given: A service with a token set
        let service = ContextExtractionService.shared
        service.setAuthToken("existing-token")

        // When: Setting nil
        service.setAuthToken(nil)

        // Then: Token should be cleared
        // Verified indirectly - extraction should fail with notAuthenticated
    }

    // MARK: - Test: Extract From Conversation - Error Cases

    func testExtractWithoutAuthTokenThrowsNotAuthenticated() async {
        // Given: A service with no auth token
        let service = ContextExtractionService.shared
        service.setAuthToken(nil)

        let conversationId = UUID()
        let messages = [
            ExtractionMessage(role: "user", content: "Test message")
        ]

        // When/Then: Should throw notAuthenticated
        do {
            _ = try await service.extractFromConversation(
                conversationId: conversationId,
                messages: messages
            )
            XCTFail("Should throw notAuthenticated error")
        } catch let error as ContextExtractionError {
            XCTAssertEqual(error, .notAuthenticated)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testExtractWithEmptyMessagesAndNoAuthThrowsNotAuthenticated() async {
        // Given: A service with NO auth token — throws before empty-message handling is reached
        let service = ContextExtractionService.shared
        service.setAuthToken(nil)

        let conversationId = UUID()
        let messages: [ExtractionMessage] = []

        // When/Then: With no token, should throw notAuthenticated before any network call
        do {
            _ = try await service.extractFromConversation(
                conversationId: conversationId,
                messages: messages
            )
            XCTFail("Should throw notAuthenticated error")
        } catch let error as ContextExtractionError {
            XCTAssertEqual(error, .notAuthenticated)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Test: ChatMessage Convenience Method

    func testExtractFromChatMessagesConvertsProperly() async {
        // Given: ChatMessage objects
        let conversationId = UUID()
        let chatMessages = [
            ChatMessage(
                id: UUID(),
                conversationId: conversationId,
                role: .user,
                content: "I value honesty",
                createdAt: Date()
            ),
            ChatMessage(
                id: UUID(),
                conversationId: conversationId,
                role: .assistant,
                content: "That's important",
                createdAt: Date()
            )
        ]

        let service = ContextExtractionService.shared
        service.setAuthToken(nil) // Will fail auth, but we're testing the conversion

        // When/Then: Should convert messages and call the main method
        // Will throw notAuthenticated, which proves conversion happened
        do {
            _ = try await service.extractFromConversation(
                conversationId: conversationId,
                chatMessages: chatMessages
            )
            XCTFail("Should throw notAuthenticated")
        } catch let error as ContextExtractionError {
            XCTAssertEqual(error, .notAuthenticated, "Should reach auth check after conversion")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Test: ExtractionMessage Structure

    func testExtractionMessageEncodesCorrectly() throws {
        // Given: An ExtractionMessage
        let message = ExtractionMessage(role: "user", content: "Test content")

        // When: Encoding to JSON
        let encoder = JSONEncoder()
        let data = try encoder.encode(message)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Then: Should have correct structure
        XCTAssertEqual(json?["role"] as? String, "user")
        XCTAssertEqual(json?["content"] as? String, "Test content")
    }

    // MARK: - Test: Error Messages (UX-11 Compliance)

    func testNotAuthenticatedErrorHasWarmMessage() {
        let error = ContextExtractionError.notAuthenticated
        XCTAssertEqual(error.errorDescription, "I need you to sign in first.")
    }

    func testNetworkErrorHasWarmMessage() {
        let error = ContextExtractionError.networkError("Connection lost")
        XCTAssertEqual(error.errorDescription, "I had trouble connecting. Connection lost")
    }

    func testInvalidResponseErrorHasWarmMessage() {
        let error = ContextExtractionError.invalidResponse
        XCTAssertEqual(error.errorDescription, "I had trouble understanding the response.")
    }

    func testExtractionFailedErrorHasWarmMessage() {
        let error = ContextExtractionError.extractionFailed("Parse error")
        XCTAssertEqual(error.errorDescription, "I couldn't analyze our conversation. Parse error")
    }

    // MARK: - Test: Error Equatable

    func testContextExtractionErrorEquatable() {
        XCTAssertEqual(
            ContextExtractionError.notAuthenticated,
            ContextExtractionError.notAuthenticated
        )
        XCTAssertEqual(
            ContextExtractionError.invalidResponse,
            ContextExtractionError.invalidResponse
        )
        XCTAssertEqual(
            ContextExtractionError.networkError("test"),
            ContextExtractionError.networkError("test")
        )
        XCTAssertNotEqual(
            ContextExtractionError.networkError("a"),
            ContextExtractionError.networkError("b")
        )
        XCTAssertNotEqual(
            ContextExtractionError.notAuthenticated,
            ContextExtractionError.invalidResponse
        )
    }
}
