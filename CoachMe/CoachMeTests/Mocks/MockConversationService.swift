//
//  MockConversationService.swift
//  CoachMeTests
//
//  Story 2.6: Mock for testing ConversationService interactions
//

import Foundation
@testable import CoachMe

/// Mock implementation of ConversationServiceProtocol for unit testing
@MainActor
final class MockConversationService: ConversationServiceProtocol {
    // MARK: - Call Tracking

    var createConversationCalled = false
    var ensureConversationExistsCalled = false
    var conversationExistsCalled = false
    var updateConversationCalled = false
    var deleteConversationCalled = false
    var deleteAllConversationsCalled = false

    var lastDeletedConversationId: UUID?

    // MARK: - Configurable Behavior

    var shouldThrowOnDelete = false
    var deleteError: ConversationService.ConversationError = .deleteFailed("Mock error")
    var shouldThrowOnDeleteAll = false
    var deleteAllError: ConversationService.ConversationError = .deleteFailed("Mock error")
    var conversationExistsResult = true

    // MARK: - Protocol Implementation

    nonisolated func createConversation(id: UUID?) async throws -> UUID {
        await MainActor.run { createConversationCalled = true }
        return id ?? UUID()
    }

    nonisolated func ensureConversationExists(id: UUID) async throws -> UUID {
        await MainActor.run { ensureConversationExistsCalled = true }
        return id
    }

    nonisolated func conversationExists(id: UUID) async -> Bool {
        await MainActor.run { conversationExistsCalled = true }
        return await MainActor.run { conversationExistsResult }
    }

    nonisolated func updateConversation(id: UUID, title: String?) async {
        await MainActor.run { updateConversationCalled = true }
    }

    nonisolated func deleteConversation(id: UUID) async throws {
        let shouldThrow = await MainActor.run {
            deleteConversationCalled = true
            lastDeletedConversationId = id
            return shouldThrowOnDelete
        }

        if shouldThrow {
            let error = await MainActor.run { deleteError }
            throw error
        }
    }

    nonisolated func deleteAllConversations() async throws {
        let shouldThrow = await MainActor.run {
            deleteAllConversationsCalled = true
            return shouldThrowOnDeleteAll
        }

        if shouldThrow {
            let error = await MainActor.run { deleteAllError }
            throw error
        }
    }

    // MARK: - Test Helpers

    func reset() {
        createConversationCalled = false
        ensureConversationExistsCalled = false
        conversationExistsCalled = false
        updateConversationCalled = false
        deleteConversationCalled = false
        deleteAllConversationsCalled = false
        lastDeletedConversationId = nil
        shouldThrowOnDelete = false
        shouldThrowOnDeleteAll = false
        conversationExistsResult = true
    }
}
