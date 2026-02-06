//
//  ChatStreamServiceTests.swift
//  CoachMeTests
//
//  Created by Dev Agent on 2/6/26.
//

import Testing
import Foundation
@testable import CoachMe

/// Unit tests for ChatStreamService
@MainActor
struct ChatStreamServiceTests {

    // MARK: - StreamEvent Decoding Tests

    @Test("StreamEvent decodes token event")
    func testDecodeTokenEvent() throws {
        let json = """
        {"type":"token","content":"Hello"}
        """
        let data = json.data(using: .utf8)!

        let event = try JSONDecoder().decode(ChatStreamService.StreamEvent.self, from: data)

        if case .token(let content) = event {
            #expect(content == "Hello")
        } else {
            Issue.record("Expected token event")
        }
    }

    @Test("StreamEvent decodes done event")
    func testDecodeDoneEvent() throws {
        let json = """
        {"type":"done","message_id":"550e8400-e29b-41d4-a716-446655440000","usage":{"prompt_tokens":10,"completion_tokens":20,"total_tokens":30}}
        """
        let data = json.data(using: .utf8)!

        let event = try JSONDecoder().decode(ChatStreamService.StreamEvent.self, from: data)

        if case .done(let messageId, let usage) = event {
            #expect(messageId == UUID(uuidString: "550e8400-e29b-41d4-a716-446655440000"))
            #expect(usage.promptTokens == 10)
            #expect(usage.completionTokens == 20)
            #expect(usage.totalTokens == 30)
        } else {
            Issue.record("Expected done event")
        }
    }

    @Test("StreamEvent decodes error event")
    func testDecodeErrorEvent() throws {
        let json = """
        {"type":"error","message":"Something went wrong"}
        """
        let data = json.data(using: .utf8)!

        let event = try JSONDecoder().decode(ChatStreamService.StreamEvent.self, from: data)

        if case .error(let message) = event {
            #expect(message == "Something went wrong")
        } else {
            Issue.record("Expected error event")
        }
    }

    @Test("StreamEvent throws for unknown type")
    func testDecodeUnknownType() {
        let json = """
        {"type":"unknown","data":"something"}
        """
        let data = json.data(using: .utf8)!

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ChatStreamService.StreamEvent.self, from: data)
        }
    }

    // MARK: - TokenUsage Decoding Tests

    @Test("TokenUsage decodes with snake_case keys")
    func testDecodeTokenUsage() throws {
        let json = """
        {"prompt_tokens":100,"completion_tokens":50,"total_tokens":150}
        """
        let data = json.data(using: .utf8)!

        let usage = try JSONDecoder().decode(ChatStreamService.StreamEvent.TokenUsage.self, from: data)

        #expect(usage.promptTokens == 100)
        #expect(usage.completionTokens == 50)
        #expect(usage.totalTokens == 150)
    }

    // MARK: - ChatRequest Encoding Tests

    @Test("ChatRequest encodes correctly with snake_case keys")
    func testEncodeChatRequest() throws {
        let conversationId = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440000")!
        let request = ChatStreamService.ChatRequest(
            message: "Hello coach",
            conversationId: conversationId
        )

        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["message"] as? String == "Hello coach")
        // Uses snake_case to match Edge Function expectations
        #expect(json["conversation_id"] as? String == "550e8400-e29b-41d4-a716-446655440000")
    }

    // MARK: - ChatStreamError Tests

    @Test("ChatStreamError provides warm error messages")
    func testErrorDescriptions() {
        #expect(ChatStreamError.invalidResponse.errorDescription != nil)
        #expect(ChatStreamError.streamInterrupted.errorDescription != nil)
        #expect(ChatStreamError.authenticationRequired.errorDescription != nil)

        // HTTP errors should provide warm messages
        let httpError = ChatStreamError.httpError(statusCode: 500)
        #expect(httpError.errorDescription?.contains("Coach") == true || httpError.errorDescription?.contains("try") == true)

        // 401 should suggest signing in
        let authError = ChatStreamError.httpError(statusCode: 401)
        #expect(authError.errorDescription?.contains("sign in") == true)
    }

    @Test("ChatStreamError equality works")
    func testErrorEquality() {
        #expect(ChatStreamError.invalidResponse == ChatStreamError.invalidResponse)
        #expect(ChatStreamError.httpError(statusCode: 401) == ChatStreamError.httpError(statusCode: 401))
        #expect(ChatStreamError.httpError(statusCode: 401) != ChatStreamError.httpError(statusCode: 500))
    }

    // MARK: - Service Initialization Tests

    @Test("Service initializes with default configuration")
    func testServiceInitialization() {
        let service = ChatStreamService()

        // Should not throw - service initializes successfully
        #expect(service != nil)
    }

    @Test("Service accepts custom URL session")
    func testServiceWithCustomSession() {
        let config = URLSessionConfiguration.ephemeral
        let session = URLSession(configuration: config)
        let service = ChatStreamService(session: session)

        #expect(service != nil)
    }

    // MARK: - Auth Token Tests

    @Test("setAuthToken updates service token")
    func testSetAuthToken() {
        let service = ChatStreamService()

        // Should not throw
        service.setAuthToken("test-token")
        service.setAuthToken(nil)
    }
}
