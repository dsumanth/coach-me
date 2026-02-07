//
//  MemoryMomentParserTests.swift
//  CoachMeTests
//
//  Story 2.4: Context Injection into Coaching Responses
//  Tests for MemoryMomentParser service
//

import Testing
import Foundation
@testable import CoachMe

/// Unit tests for MemoryMomentParser
@MainActor
struct MemoryMomentParserTests {

    // MARK: - Basic Parsing Tests

    @Test("Detects single memory moment")
    func testDetectsSingleMemoryMoment() {
        let text = "Given that you value [MEMORY: honesty], how does this align?"
        let result = MemoryMomentParser.parse(text)

        #expect(result.hasMemoryMoments == true)
        #expect(result.moments.count == 1)
        #expect(result.moments[0].content == "honesty")
        #expect(result.cleanText == "Given that you value honesty, how does this align?")
    }

    @Test("Detects multiple memory moments")
    func testDetectsMultipleMemoryMoments() {
        let text = "You value [MEMORY: honesty] and want to become [MEMORY: a better leader]."
        let result = MemoryMomentParser.parse(text)

        #expect(result.moments.count == 2)
        #expect(result.moments[0].content == "honesty")
        #expect(result.moments[1].content == "a better leader")
        #expect(result.cleanText == "You value honesty and want to become a better leader.")
    }

    @Test("Handles text without memory moments")
    func testHandlesNoMemoryMoments() {
        let text = "This is a regular response without any memory references."
        let result = MemoryMomentParser.parse(text)

        #expect(result.hasMemoryMoments == false)
        #expect(result.moments.isEmpty)
        #expect(result.cleanText == text)
    }

    @Test("Handles empty string")
    func testHandlesEmptyString() {
        let result = MemoryMomentParser.parse("")

        #expect(result.hasMemoryMoments == false)
        #expect(result.moments.isEmpty)
        #expect(result.cleanText == "")
    }

    // MARK: - Edge Cases

    @Test("Handles memory moment with extra whitespace")
    func testHandlesExtraWhitespace() {
        let text = "You mentioned [MEMORY:   career transition   ] is important."
        let result = MemoryMomentParser.parse(text)

        #expect(result.moments.count == 1)
        #expect(result.moments[0].content == "career transition")
    }

    @Test("Handles memory moment at start of text")
    func testMemoryMomentAtStart() {
        let text = "[MEMORY: Your goal] is what we discussed."
        let result = MemoryMomentParser.parse(text)

        #expect(result.moments.count == 1)
        #expect(result.moments[0].content == "Your goal")
        #expect(result.cleanText == "Your goal is what we discussed.")
    }

    @Test("Handles memory moment at end of text")
    func testMemoryMomentAtEnd() {
        let text = "Let's focus on [MEMORY: becoming a leader]"
        let result = MemoryMomentParser.parse(text)

        #expect(result.moments.count == 1)
        #expect(result.moments[0].content == "becoming a leader")
        #expect(result.cleanText == "Let's focus on becoming a leader")
    }

    @Test("Preserves original tag in moment")
    func testPreservesOriginalTag() {
        let text = "You value [MEMORY: honesty and authenticity]."
        let result = MemoryMomentParser.parse(text)

        #expect(result.moments[0].originalTag == "[MEMORY: honesty and authenticity]")
    }

    // MARK: - Utility Method Tests

    @Test("hasMemoryMoments returns true when tags present")
    func testHasMemoryMomentsTrue() {
        let text = "Given [MEMORY: your values], what would you do?"
        #expect(MemoryMomentParser.hasMemoryMoments(text) == true)
    }

    @Test("hasMemoryMoments returns false when no tags")
    func testHasMemoryMomentsFalse() {
        let text = "This is a regular message."
        #expect(MemoryMomentParser.hasMemoryMoments(text) == false)
    }

    @Test("hasMemoryMoments returns false for empty string")
    func testHasMemoryMomentsEmpty() {
        #expect(MemoryMomentParser.hasMemoryMoments("") == false)
    }

    @Test("extractMomentContents returns all contents")
    func testExtractMomentContents() {
        let text = "You value [MEMORY: honesty] and [MEMORY: growth]."
        let contents = MemoryMomentParser.extractMomentContents(text)

        #expect(contents.count == 2)
        #expect(contents[0] == "honesty")
        #expect(contents[1] == "growth")
    }

    @Test("stripTags removes all tags")
    func testStripTags() {
        let text = "Focus on [MEMORY: your goals] and [MEMORY: values]."
        let stripped = MemoryMomentParser.stripTags(text)

        #expect(stripped == "Focus on your goals and values.")
    }

    // MARK: - String Extension Tests

    @Test("String.memoryMoments extension works")
    func testStringMemoryMomentsExtension() {
        let text = "You mentioned [MEMORY: career change]."
        let result = text.memoryMoments

        #expect(result.hasMemoryMoments == true)
        #expect(result.moments.count == 1)
    }

    @Test("String.containsMemoryMoments extension works")
    func testStringContainsMemoryMomentsExtension() {
        let withMemory = "Check [MEMORY: this]"
        let withoutMemory = "Regular text"

        #expect(withMemory.containsMemoryMoments == true)
        #expect(withoutMemory.containsMemoryMoments == false)
    }

    @Test("String.strippingMemoryTags extension works")
    func testStringStrippingMemoryTagsExtension() {
        let text = "Your [MEMORY: honesty] matters."
        #expect(text.strippingMemoryTags == "Your honesty matters.")
    }

    // MARK: - Equatable Tests

    @Test("MemoryMoment is equatable")
    func testMemoryMomentEquatable() {
        let moment1 = MemoryMoment(id: UUID(), content: "honesty", originalTag: "[MEMORY: honesty]")
        let moment2 = MemoryMoment(id: moment1.id, content: "honesty", originalTag: "[MEMORY: honesty]")
        let moment3 = MemoryMoment(id: UUID(), content: "growth", originalTag: "[MEMORY: growth]")

        #expect(moment1 == moment2)
        #expect(moment1 != moment3)
    }

    @Test("MemoryParseResult is equatable")
    func testMemoryParseResultEquatable() {
        let result1 = MemoryMomentParser.parse("Check [MEMORY: this]")
        let result2 = MemoryMomentParser.parse("Check [MEMORY: this]")
        let result3 = MemoryMomentParser.parse("No memory here")

        // Clean text should match
        #expect(result1.cleanText == result2.cleanText)
        // Both should have memory moments
        #expect(result1.hasMemoryMoments == result2.hasMemoryMoments)
        // Third should be different
        #expect(result1.hasMemoryMoments != result3.hasMemoryMoments)
    }

    // MARK: - Complex Text Tests

    @Test("Handles complex multi-line text")
    func testComplexMultiLineText() {
        let text = """
        I remember you mentioned [MEMORY: navigating a career transition].

        Given your goal of [MEMORY: becoming a better leader], how might this challenge \
        help you grow?

        Your value of [MEMORY: honesty] could guide you here.
        """

        let result = MemoryMomentParser.parse(text)

        #expect(result.moments.count == 3)
        #expect(result.moments[0].content == "navigating a career transition")
        #expect(result.moments[1].content == "becoming a better leader")
        #expect(result.moments[2].content == "honesty")
    }

    @Test("Handles special characters in content")
    func testSpecialCharactersInContent() {
        let text = "You mentioned [MEMORY: work-life balance & self-care]."
        let result = MemoryMomentParser.parse(text)

        #expect(result.moments.count == 1)
        #expect(result.moments[0].content == "work-life balance & self-care")
    }
}
