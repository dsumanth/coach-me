//
//  StreamingTokenBufferTests.swift
//  CoachMeTests
//
//  Created by Dev Agent on 2/6/26.
//

import Testing
@testable import CoachMe

/// Unit tests for StreamingTokenBuffer
@MainActor
struct StreamingTokenBufferTests {

    // MARK: - Initialization Tests

    @Test("Buffer initializes with empty state")
    func testInitialState() {
        let buffer = StreamingTokenBuffer()

        // Buffer starts empty - flush should produce nothing
        var flushedContent = ""
        buffer.onFlush = { flushedContent = $0 }
        buffer.flush()

        #expect(flushedContent.isEmpty)
    }

    // MARK: - Token Accumulation Tests

    @Test("addToken accumulates tokens")
    func testAddTokenAccumulates() async {
        let buffer = StreamingTokenBuffer()
        var flushedContent = ""
        buffer.onFlush = { flushedContent += $0 }

        // Add multiple tokens
        buffer.addToken("Hello")
        buffer.addToken(" ")
        buffer.addToken("World")

        // Force flush to get accumulated content
        buffer.flush()

        #expect(flushedContent == "Hello World")
    }

    @Test("flush sends all pending tokens")
    func testFlushSendsPendingTokens() {
        let buffer = StreamingTokenBuffer()
        var flushedContent = ""
        buffer.onFlush = { flushedContent = $0 }

        buffer.addToken("Test content")
        buffer.flush()

        #expect(flushedContent == "Test content")
    }

    @Test("flush with no tokens produces no callback")
    func testFlushWithNoTokens() {
        let buffer = StreamingTokenBuffer()
        var flushCount = 0
        buffer.onFlush = { _ in flushCount += 1 }

        buffer.flush()

        #expect(flushCount == 0)
    }

    // MARK: - Reset Tests

    @Test("reset clears all pending tokens")
    func testResetClearsBuffer() {
        let buffer = StreamingTokenBuffer()
        var flushedContent = ""
        buffer.onFlush = { flushedContent = $0 }

        buffer.addToken("Some content")
        buffer.reset()
        buffer.flush()

        #expect(flushedContent.isEmpty)
    }

    @Test("reset allows fresh accumulation")
    func testResetAllowsFreshAccumulation() {
        let buffer = StreamingTokenBuffer()
        var flushedContent = ""
        buffer.onFlush = { flushedContent = $0 }

        buffer.addToken("Old content")
        buffer.reset()
        buffer.addToken("New content")
        buffer.flush()

        #expect(flushedContent == "New content")
    }

    // MARK: - Callback Tests

    @Test("onFlush callback receives accumulated content")
    func testOnFlushCallback() {
        let buffer = StreamingTokenBuffer()
        var receivedContent: [String] = []
        buffer.onFlush = { receivedContent.append($0) }

        buffer.addToken("First")
        buffer.flush()
        buffer.addToken("Second")
        buffer.flush()

        #expect(receivedContent.count == 2)
        #expect(receivedContent[0] == "First")
        #expect(receivedContent[1] == "Second")
    }

    @Test("onFlush can be changed")
    func testOnFlushCanBeChanged() {
        let buffer = StreamingTokenBuffer()
        var firstCallback = ""
        var secondCallback = ""

        buffer.onFlush = { firstCallback = $0 }
        buffer.addToken("First")
        buffer.flush()

        buffer.onFlush = { secondCallback = $0 }
        buffer.addToken("Second")
        buffer.flush()

        #expect(firstCallback == "First")
        #expect(secondCallback == "Second")
    }

    // MARK: - Multiple Token Types Tests

    @Test("handles whitespace-only tokens")
    func testWhitespaceTokens() {
        let buffer = StreamingTokenBuffer()
        var flushedContent = ""
        buffer.onFlush = { flushedContent = $0 }

        buffer.addToken("Word")
        buffer.addToken(" ")
        buffer.addToken("\n")
        buffer.addToken("NextLine")
        buffer.flush()

        #expect(flushedContent == "Word \nNextLine")
    }

    @Test("handles empty string tokens")
    func testEmptyStringTokens() {
        let buffer = StreamingTokenBuffer()
        var flushedContent = ""
        buffer.onFlush = { flushedContent = $0 }

        buffer.addToken("Hello")
        buffer.addToken("")
        buffer.addToken("World")
        buffer.flush()

        #expect(flushedContent == "HelloWorld")
    }

    @Test("handles special characters")
    func testSpecialCharacters() {
        let buffer = StreamingTokenBuffer()
        var flushedContent = ""
        buffer.onFlush = { flushedContent = $0 }

        buffer.addToken("Hello 👋 ")
        buffer.addToken("🌍")
        buffer.flush()

        #expect(flushedContent == "Hello 👋 🌍")
    }
}
