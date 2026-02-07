//
//  MemoryMomentParserTests.swift
//  CoachMeTests
//
//  Story 2.4: Context Injection into Coaching Responses
//  Story 3.4: Pattern Recognition Across Conversations
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

    // MARK: - Story 3.4: Regression Tests (existing parse() unchanged)

    @Test("Existing parse() still works unchanged after Story 3.4")
    func testExistingParseStillWorks() {
        let text = "Given [MEMORY: honesty], how does this align?"
        let result = MemoryMomentParser.parse(text)

        #expect(result.hasMemoryMoments == true)
        #expect(result.moments.count == 1)
        #expect(result.moments[0].content == "honesty")
        #expect(result.cleanText == "Given honesty, how does this align?")
    }

    @Test("Existing parse() ignores [PATTERN:] tags")
    func testExistingParseIgnoresPatternTags() {
        let text = "I noticed [PATTERN: stuck before transitions] and [MEMORY: honesty]."
        let result = MemoryMomentParser.parse(text)

        // parse() only finds [MEMORY:] tags — [PATTERN:] is left in clean text
        #expect(result.moments.count == 1)
        #expect(result.moments[0].content == "honesty")
        #expect(result.cleanText.contains("[PATTERN:"))
    }

    // MARK: - Story 3.4: parseAll() Tests

    @Test("parseAll() detects [PATTERN:] tags")
    func testParseAllDetectsPatternTags() {
        let text = "I've noticed [PATTERN: you feel stuck before transitions]. What does that mean?"
        let result = MemoryMomentParser.parseAll(text)

        #expect(result.hasPatternInsights == true)
        #expect(result.hasMemoryMoments == false)
        #expect(result.tags.count == 1)
        #expect(result.tags[0].type == .pattern)
        #expect(result.tags[0].content == "you feel stuck before transitions")
        #expect(result.cleanText == "I've noticed you feel stuck before transitions. What does that mean?")
    }

    @Test("parseAll() detects [MEMORY:] tags")
    func testParseAllDetectsMemoryTags() {
        let text = "Given your value of [MEMORY: honesty], what would you do?"
        let result = MemoryMomentParser.parseAll(text)

        #expect(result.hasMemoryMoments == true)
        #expect(result.hasPatternInsights == false)
        #expect(result.tags.count == 1)
        #expect(result.tags[0].type == .memory)
        #expect(result.tags[0].content == "honesty")
    }

    @Test("parseAll() detects both [MEMORY:] and [PATTERN:] tags in same text")
    func testParseAllDetectsBothTagTypes() {
        let text = "Given [MEMORY: your goal of growth], I've noticed [PATTERN: you feel stuck before transitions]."
        let result = MemoryMomentParser.parseAll(text)

        #expect(result.hasMemoryMoments == true)
        #expect(result.hasPatternInsights == true)
        #expect(result.tags.count == 2)
    }

    @Test("parseAll() preserves tag order by position in text")
    func testParseAllPreservesTagOrder() {
        let text = "I see [PATTERN: a recurring theme]. Given [MEMORY: your honesty], this makes sense."
        let result = MemoryMomentParser.parseAll(text)

        #expect(result.tags.count == 2)
        #expect(result.tags[0].type == .pattern)
        #expect(result.tags[0].content == "a recurring theme")
        #expect(result.tags[1].type == .memory)
        #expect(result.tags[1].content == "your honesty")
    }

    @Test("parseAll() returns correct hasMemoryMoments and hasPatternInsights flags")
    func testParseAllReturnsCorrectFlags() {
        // Only pattern
        let patternOnly = MemoryMomentParser.parseAll("I noticed [PATTERN: fear of change].")
        #expect(patternOnly.hasPatternInsights == true)
        #expect(patternOnly.hasMemoryMoments == false)

        // Only memory
        let memoryOnly = MemoryMomentParser.parseAll("Your [MEMORY: goal].")
        #expect(memoryOnly.hasPatternInsights == false)
        #expect(memoryOnly.hasMemoryMoments == true)

        // Both
        let both = MemoryMomentParser.parseAll("[MEMORY: goal] and [PATTERN: pattern].")
        #expect(both.hasPatternInsights == true)
        #expect(both.hasMemoryMoments == true)

        // Neither
        let neither = MemoryMomentParser.parseAll("Regular text.")
        #expect(neither.hasPatternInsights == false)
        #expect(neither.hasMemoryMoments == false)
    }

    @Test("parseAll() with no tags returns empty tags and clean text")
    func testParseAllWithNoTags() {
        let text = "This is a regular coaching response."
        let result = MemoryMomentParser.parseAll(text)

        #expect(result.tags.isEmpty)
        #expect(result.hasMemoryMoments == false)
        #expect(result.hasPatternInsights == false)
        #expect(result.cleanText == text)
    }

    @Test("parseAll() handles empty string")
    func testParseAllEmptyString() {
        let result = MemoryMomentParser.parseAll("")

        #expect(result.tags.isEmpty)
        #expect(result.cleanText == "")
    }

    @Test("parseAll() strips both tag types from clean text")
    func testParseAllStripsBothTagTypes() {
        let text = "I see [PATTERN: a theme] and remember [MEMORY: your goal]."
        let result = MemoryMomentParser.parseAll(text)

        #expect(result.cleanText == "I see a theme and remember your goal.")
    }

    @Test("parseAll() caches results (memoization)")
    func testParseAllCachesMemoizedResults() {
        let text = "I see [PATTERN: a recurring theme]."

        // Parse twice — second call should use cache
        let result1 = MemoryMomentParser.parseAll(text)
        let result2 = MemoryMomentParser.parseAll(text)

        #expect(result1.cleanText == result2.cleanText)
        #expect(result1.tags.count == result2.tags.count)
    }

    // MARK: - Story 3.4: CoachingTag Tests

    @Test("CoachingTag is equatable")
    func testCoachingTagEquatable() {
        let id = UUID()
        let tag1 = CoachingTag(id: id, type: .pattern, content: "theme")
        let tag2 = CoachingTag(id: id, type: .pattern, content: "theme")
        let tag3 = CoachingTag(type: .memory, content: "goal")

        #expect(tag1 == tag2)
        #expect(tag1 != tag3)
    }

    @Test("CoachingTagType distinguishes memory and pattern")
    func testCoachingTagTypeDistinction() {
        let memoryTag = CoachingTag(type: .memory, content: "goal")
        let patternTag = CoachingTag(type: .pattern, content: "theme")

        #expect(memoryTag.type == .memory)
        #expect(patternTag.type == .pattern)
        #expect(memoryTag.type != patternTag.type)
    }

    // MARK: - Story 3.4: Pattern Utility Tests

    @Test("hasPatternInsights returns true for pattern tags")
    func testHasPatternInsightsTrue() {
        let text = "I see [PATTERN: stuck before transitions]."
        #expect(MemoryMomentParser.hasPatternInsights(text) == true)
    }

    @Test("hasPatternInsights returns false for memory tags only")
    func testHasPatternInsightsFalseForMemory() {
        let text = "Given [MEMORY: honesty], what would you do?"
        #expect(MemoryMomentParser.hasPatternInsights(text) == false)
    }

    @Test("hasPatternInsights returns false for empty string")
    func testHasPatternInsightsEmpty() {
        #expect(MemoryMomentParser.hasPatternInsights("") == false)
    }

    @Test("stripPatternTags removes pattern tags preserving content")
    func testStripPatternTags() {
        let text = "I see [PATTERN: a recurring theme] here."
        let stripped = MemoryMomentParser.stripPatternTags(text)

        #expect(stripped == "I see a recurring theme here.")
    }

    @Test("stripPatternTags preserves memory tags")
    func testStripPatternTagsPreservesMemory() {
        let text = "[MEMORY: honesty] and [PATTERN: theme]."
        let stripped = MemoryMomentParser.stripPatternTags(text)

        #expect(stripped == "[MEMORY: honesty] and theme.")
    }

    // MARK: - Story 3.4: String Extension Tests

    @Test("String.coachingTags extension works")
    func testStringCoachingTagsExtension() {
        let text = "I see [PATTERN: a theme] and [MEMORY: your goal]."
        let result = text.coachingTags

        #expect(result.tags.count == 2)
        #expect(result.hasPatternInsights == true)
        #expect(result.hasMemoryMoments == true)
    }

    @Test("String.containsPatternInsights extension works")
    func testStringContainsPatternInsightsExtension() {
        #expect("Has [PATTERN: theme]".containsPatternInsights == true)
        #expect("Regular text".containsPatternInsights == false)
    }
}
