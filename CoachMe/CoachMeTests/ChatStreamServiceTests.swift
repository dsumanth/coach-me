//
//  ChatStreamServiceTests.swift
//  CoachMeTests
//
//  Created by Dev Agent on 2/6/26.
//  Story 3.4: Extended with pattern_insight flag decoding tests
//  Story 4.1: Extended with crisis_detected flag decoding tests
//

import Testing
import Foundation
@testable import CoachMe

/// Unit tests for ChatStreamService
@MainActor
struct ChatStreamServiceTests {

    // MARK: - StreamEvent Decoding Tests

    @Test("StreamEvent decodes token event without memory_moment or pattern_insight")
    func testDecodeTokenEvent() throws {
        let json = """
        {"type":"token","content":"Hello"}
        """
        let data = json.data(using: .utf8)!

        let event = try JSONDecoder().decode(ChatStreamService.StreamEvent.self, from: data)

        if case .token(let content, let hasMemoryMoment, let hasPatternInsight, let hasCrisisFlag) = event {
            #expect(content == "Hello")
            #expect(hasMemoryMoment == false)  // Default when not present
            #expect(hasPatternInsight == false)  // Story 3.4: Default when not present
        } else {
            Issue.record("Expected token event")
        }
    }

    // Story 2.4: Test memory_moment flag parsing (AC #4)
    @Test("StreamEvent decodes token event with memory_moment true")
    func testDecodeTokenEventWithMemoryMomentTrue() throws {
        let json = """
        {"type":"token","content":"I value [MEMORY: honesty]","memory_moment":true}
        """
        let data = json.data(using: .utf8)!

        let event = try JSONDecoder().decode(ChatStreamService.StreamEvent.self, from: data)

        if case .token(let content, let hasMemoryMoment, let hasPatternInsight, let hasCrisisFlag) = event {
            #expect(content == "I value [MEMORY: honesty]")
            #expect(hasMemoryMoment == true)
            #expect(hasPatternInsight == false)  // Story 3.4: Not a pattern insight
        } else {
            Issue.record("Expected token event")
        }
    }

    @Test("StreamEvent decodes token event with memory_moment false")
    func testDecodeTokenEventWithMemoryMomentFalse() throws {
        let json = """
        {"type":"token","content":"Regular content","memory_moment":false}
        """
        let data = json.data(using: .utf8)!

        let event = try JSONDecoder().decode(ChatStreamService.StreamEvent.self, from: data)

        if case .token(let content, let hasMemoryMoment, let hasPatternInsight, let hasCrisisFlag) = event {
            #expect(content == "Regular content")
            #expect(hasMemoryMoment == false)
            #expect(hasPatternInsight == false)
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

        // Service initializes successfully - verify it has expected type
        #expect(type(of: service) == ChatStreamService.self)
    }

    @Test("Service accepts custom URL session")
    func testServiceWithCustomSession() {
        let config = URLSessionConfiguration.ephemeral
        let session = URLSession(configuration: config)
        let service = ChatStreamService(session: session)

        // Verify service was created with custom session
        #expect(type(of: service) == ChatStreamService.self)
    }

    // MARK: - Auth Token Tests

    @Test("setAuthToken updates service token")
    func testSetAuthToken() {
        let service = ChatStreamService()

        // Should not throw
        service.setAuthToken("test-token")
        service.setAuthToken(nil)
    }

    // MARK: - Story 3.4: Pattern Insight Flag Tests

    @Test("StreamEvent decodes pattern_insight flag true")
    func testDecodePatternInsightTrue() throws {
        let json = """
        {"type":"token","content":"I noticed [PATTERN: stuck before transitions]","memory_moment":false,"pattern_insight":true}
        """
        let data = json.data(using: .utf8)!

        let event = try JSONDecoder().decode(ChatStreamService.StreamEvent.self, from: data)

        if case .token(let content, let hasMemoryMoment, let hasPatternInsight, let hasCrisisFlag) = event {
            #expect(content == "I noticed [PATTERN: stuck before transitions]")
            #expect(hasMemoryMoment == false)
            #expect(hasPatternInsight == true)
        } else {
            Issue.record("Expected token event")
        }
    }

    @Test("StreamEvent backward compatibility - missing pattern_insight defaults to false")
    func testDecodePatternInsightBackwardCompat() throws {
        // Pre-3.4 SSE events don't have pattern_insight field
        let json = """
        {"type":"token","content":"Some text","memory_moment":true}
        """
        let data = json.data(using: .utf8)!

        let event = try JSONDecoder().decode(ChatStreamService.StreamEvent.self, from: data)

        if case .token(_, let hasMemoryMoment, let hasPatternInsight, _) = event {
            #expect(hasMemoryMoment == true)
            #expect(hasPatternInsight == false)  // Defaults to false
        } else {
            Issue.record("Expected token event")
        }
    }

    @Test("StreamEvent decodes both memory_moment and pattern_insight true")
    func testDecodeBothMemoryAndPatternTrue() throws {
        let json = """
        {"type":"token","content":"With both tags","memory_moment":true,"pattern_insight":true}
        """
        let data = json.data(using: .utf8)!

        let event = try JSONDecoder().decode(ChatStreamService.StreamEvent.self, from: data)

        if case .token(_, let hasMemoryMoment, let hasPatternInsight, _) = event {
            #expect(hasMemoryMoment == true)
            #expect(hasPatternInsight == true)
        } else {
            Issue.record("Expected token event")
        }
    }

    // MARK: - Story 4.1: Crisis Detection Flag Tests

    @Test("StreamEvent decodes crisis_detected flag true")
    func testDecodeCrisisDetectedTrue() throws {
        let json = """
        {"type":"token","content":"I hear you","memory_moment":false,"pattern_insight":false,"crisis_detected":true}
        """
        let data = json.data(using: .utf8)!

        let event = try JSONDecoder().decode(ChatStreamService.StreamEvent.self, from: data)

        if case .token(let content, let hasMemoryMoment, let hasPatternInsight, let hasCrisisFlag) = event {
            #expect(content == "I hear you")
            #expect(hasMemoryMoment == false)
            #expect(hasPatternInsight == false)
            #expect(hasCrisisFlag == true)
        } else {
            Issue.record("Expected token event")
        }
    }

    @Test("StreamEvent backward compatibility - missing crisis_detected defaults to false")
    func testDecodeCrisisDetectedBackwardCompat() throws {
        // Pre-4.1 SSE events don't have crisis_detected field
        let json = """
        {"type":"token","content":"Normal response","memory_moment":false,"pattern_insight":false}
        """
        let data = json.data(using: .utf8)!

        let event = try JSONDecoder().decode(ChatStreamService.StreamEvent.self, from: data)

        if case .token(_, _, _, let hasCrisisFlag) = event {
            #expect(hasCrisisFlag == false)  // Defaults to false
        } else {
            Issue.record("Expected token event")
        }
    }

    @Test("StreamEvent decodes all three flags true simultaneously")
    func testDecodeAllFlagsTrue() throws {
        let json = """
        {"type":"token","content":"All flags","memory_moment":true,"pattern_insight":true,"crisis_detected":true}
        """
        let data = json.data(using: .utf8)!

        let event = try JSONDecoder().decode(ChatStreamService.StreamEvent.self, from: data)

        if case .token(_, let hasMemoryMoment, let hasPatternInsight, let hasCrisisFlag) = event {
            #expect(hasMemoryMoment == true)
            #expect(hasPatternInsight == true)
            #expect(hasCrisisFlag == true)
        } else {
            Issue.record("Expected token event")
        }
    }

    @Test("StreamEvent decodes token with no optional flags at all")
    func testDecodeTokenMinimalFields() throws {
        // Absolute minimum: just type and content — all flags default to false
        let json = """
        {"type":"token","content":"Bare minimum"}
        """
        let data = json.data(using: .utf8)!

        let event = try JSONDecoder().decode(ChatStreamService.StreamEvent.self, from: data)

        if case .token(let content, let hasMemoryMoment, let hasPatternInsight, let hasCrisisFlag) = event {
            #expect(content == "Bare minimum")
            #expect(hasMemoryMoment == false)
            #expect(hasPatternInsight == false)
            #expect(hasCrisisFlag == false)
        } else {
            Issue.record("Expected token event")
        }
    }
}
