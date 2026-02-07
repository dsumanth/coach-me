//
//  ConversationServiceTests.swift
//  CoachMeTests
//
//  Story 2.6: Unit tests for ConversationService delete functionality
//

import Foundation
import Testing
@testable import CoachMe

/// Unit tests for ConversationService error handling and protocol conformance
@MainActor
struct ConversationServiceTests {

    // MARK: - Error Message Tests (Task 6.1-6.3)

    @Test("ConversationError.deleteFailed provides warm user-friendly message")
    func testDeleteFailedErrorDescription() {
        let error = ConversationService.ConversationError.deleteFailed("Network timeout")

        // Should use first-person message per UX-11
        let description = error.errorDescription ?? ""
        #expect(description.contains("I couldn't"))
        #expect(description.contains("remove"))
        #expect(description.contains("conversation"))
        #expect(description.contains("Network timeout"))
    }

    @Test("ConversationError.notFound has appropriate message")
    func testNotFoundErrorDescription() {
        let error = ConversationService.ConversationError.notFound

        let description = error.errorDescription ?? ""
        #expect(description.contains("Couldn't find"))
        #expect(description.contains("conversation"))
    }

    @Test("ConversationError.notAuthenticated has appropriate message")
    func testNotAuthenticatedErrorDescription() {
        let error = ConversationService.ConversationError.notAuthenticated

        let description = error.errorDescription ?? ""
        #expect(description.contains("sign in"))
    }

    @Test("ConversationError equality works for deleteFailed")
    func testDeleteFailedEquality() {
        let error1 = ConversationService.ConversationError.deleteFailed("reason")
        let error2 = ConversationService.ConversationError.deleteFailed("reason")
        let error3 = ConversationService.ConversationError.deleteFailed("different")

        #expect(error1 == error2)
        #expect(error1 != error3)
    }

    @Test("ConversationError equality works across different cases")
    func testErrorCaseEquality() {
        let deleteError = ConversationService.ConversationError.deleteFailed("test")
        let notFoundError = ConversationService.ConversationError.notFound
        let notAuthError = ConversationService.ConversationError.notAuthenticated

        #expect(deleteError != notFoundError)
        #expect(notFoundError != notAuthError)
        #expect(deleteError != notAuthError)
    }

    // MARK: - Service Singleton Tests

    @Test("ConversationService.shared returns singleton instance")
    func testSharedSingleton() {
        let instance1 = ConversationService.shared
        let instance2 = ConversationService.shared

        #expect(instance1 === instance2)
    }

    // MARK: - Protocol Conformance Tests

    @Test("ConversationService conforms to ConversationServiceProtocol")
    func testProtocolConformance() {
        let service: any ConversationServiceProtocol = ConversationService.shared

        // Verify the service can be used as the protocol type
        #expect(service is ConversationService)
    }
}

// MARK: - Mock-Based Delete Tests (Task 6.1-6.3)

@MainActor
struct ConversationServiceMockTests {

    // MARK: - Task 6.1: Test deleteConversation() success case

    @Test("deleteConversation calls service and succeeds")
    func testDeleteConversationSuccess() async throws {
        // Given: A mock service that will succeed
        let mockService = MockConversationService()
        let conversationId = UUID()

        // When: Deleting a conversation
        try await mockService.deleteConversation(id: conversationId)

        // Then: The service method was called with correct ID
        #expect(mockService.deleteConversationCalled)
        #expect(mockService.lastDeletedConversationId == conversationId)
    }

    // MARK: - Task 6.2: Test deleteConversation() not found case

    @Test("deleteConversation throws notFound error when conversation doesn't exist")
    func testDeleteConversationNotFound() async {
        // Given: A mock service configured to throw notFound
        let mockService = MockConversationService()
        mockService.shouldThrowOnDelete = true
        mockService.deleteError = .notFound

        // When/Then: Deleting should throw notFound error
        do {
            try await mockService.deleteConversation(id: UUID())
            Issue.record("Expected error to be thrown")
        } catch let error as ConversationService.ConversationError {
            #expect(error == .notFound)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }

        #expect(mockService.deleteConversationCalled)
    }

    @Test("deleteConversation throws deleteFailed error on failure")
    func testDeleteConversationFailed() async {
        // Given: A mock service configured to throw deleteFailed
        let mockService = MockConversationService()
        mockService.shouldThrowOnDelete = true
        mockService.deleteError = .deleteFailed("Network timeout")

        // When/Then: Deleting should throw deleteFailed error
        do {
            try await mockService.deleteConversation(id: UUID())
            Issue.record("Expected error to be thrown")
        } catch let error as ConversationService.ConversationError {
            if case .deleteFailed(let reason) = error {
                #expect(reason == "Network timeout")
            } else {
                Issue.record("Expected deleteFailed error")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    // MARK: - Task 6.3: Test deleteAllConversations() success case

    @Test("deleteAllConversations calls service and succeeds")
    func testDeleteAllConversationsSuccess() async throws {
        // Given: A mock service that will succeed
        let mockService = MockConversationService()

        // When: Deleting all conversations
        try await mockService.deleteAllConversations()

        // Then: The service method was called
        #expect(mockService.deleteAllConversationsCalled)
    }

    @Test("deleteAllConversations throws deleteFailed error on failure")
    func testDeleteAllConversationsFailed() async {
        // Given: A mock service configured to throw
        let mockService = MockConversationService()
        mockService.shouldThrowOnDeleteAll = true
        mockService.deleteAllError = .deleteFailed("Server error")

        // When/Then: Deleting all should throw error
        do {
            try await mockService.deleteAllConversations()
            Issue.record("Expected error to be thrown")
        } catch let error as ConversationService.ConversationError {
            if case .deleteFailed(let reason) = error {
                #expect(reason == "Server error")
            } else {
                Issue.record("Expected deleteFailed error")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }

        #expect(mockService.deleteAllConversationsCalled)
    }

    @Test("deleteAllConversations throws notAuthenticated when not logged in")
    func testDeleteAllConversationsNotAuthenticated() async {
        // Given: A mock service configured to throw notAuthenticated
        let mockService = MockConversationService()
        mockService.shouldThrowOnDeleteAll = true
        mockService.deleteAllError = .notAuthenticated

        // When/Then: Deleting all should throw notAuthenticated
        do {
            try await mockService.deleteAllConversations()
            Issue.record("Expected error to be thrown")
        } catch let error as ConversationService.ConversationError {
            #expect(error == .notAuthenticated)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
}
