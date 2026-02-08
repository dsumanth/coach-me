//
//  MemoryMomentParser.swift
//  CoachMe
//
//  Story 2.4: Context Injection into Coaching Responses
//  Parses [MEMORY: ...] tags from streaming text for visual highlighting (UX-4)
//
//  Story 3.4: Pattern Recognition Across Conversations
//  Extends parser with [PATTERN: ...] tag support for pattern insight highlighting (UX-5)
//

import Foundation

// MARK: - Coaching Tag Types (Story 3.4)

/// Distinguishes tag sources for visual treatment
/// .memory → UX-4 (sparkle icon, memoryPeach background)
/// .pattern → UX-5 (lightbulb icon, sage/warm blue tint, 32px spacing)
enum CoachingTagType: Sendable, Equatable {
    case memory
    case pattern
}

/// A coaching tag detected in coach's response
struct CoachingTag: Identifiable, Sendable, Equatable {
    let id: UUID
    let type: CoachingTagType
    let content: String

    init(id: UUID = UUID(), type: CoachingTagType, content: String) {
        self.id = id
        self.type = type
        self.content = content
    }

    static func == (lhs: CoachingTag, rhs: CoachingTag) -> Bool {
        lhs.id == rhs.id && lhs.type == rhs.type && lhs.content == rhs.content
    }
}

/// Result of parsing text for all coaching tags (memory + pattern)
struct TagParseResult: Sendable, Equatable {
    /// Text with all tags removed, content preserved (for copy & accessibility)
    let cleanText: String
    /// Text with pattern tags fully stripped (for rendering — patterns shown in separate box)
    let displayText: String
    /// All detected tags, ordered by position in original text
    let tags: [CoachingTag]
    /// Whether any memory moments were found
    var hasMemoryMoments: Bool { tags.contains { $0.type == .memory } }
    /// Whether any pattern insights were found
    var hasPatternInsights: Bool { tags.contains { $0.type == .pattern } }

    static func == (lhs: TagParseResult, rhs: TagParseResult) -> Bool {
        lhs.cleanText == rhs.cleanText && lhs.displayText == rhs.displayText && lhs.tags == rhs.tags
    }
}

// MARK: - Memory Moment Model

/// A memory moment detected in coach's response
/// Represents when the coach references user's personal context
struct MemoryMoment: Identifiable, Sendable, Equatable {
    let id: UUID
    let content: String
    let originalTag: String

    init(id: UUID = UUID(), content: String, originalTag: String) {
        self.id = id
        self.content = content
        self.originalTag = originalTag
    }
}

/// Result of parsing text for memory moments
struct MemoryParseResult: Sendable, Equatable {
    /// Text with [MEMORY: ...] tags removed, content preserved
    let cleanText: String
    /// Array of detected memory moments
    let moments: [MemoryMoment]
    /// Whether any memory moments were found
    var hasMemoryMoments: Bool { !moments.isEmpty }
}

// MARK: - Memory Moment Parser

/// Parser for detecting and extracting [MEMORY: ...] tags from text
/// Used for highlighting personalized coaching moments (UX-4)
enum MemoryMomentParser {

    // MARK: - Regex Patterns

    /// Pattern to match [MEMORY: content] tags
    /// Captures the content inside the tags
    private static let memoryPattern = /\[MEMORY:\s*(.+?)\s*\]/

    /// Pattern to match [PATTERN: content] tags (Story 3.4)
    /// Captures the content inside the tags
    private static let patternPattern = /\[PATTERN:\s*(.+?)\s*\]/

    // MARK: - Parse Cache

    /// NSCache-backed memoization for parse results.
    /// Avoids re-parsing the same content on repeated SwiftUI body evaluations.
    private static let parseCache: NSCache<NSString, ParseResultBox> = {
        let cache = NSCache<NSString, ParseResultBox>()
        cache.countLimit = 200
        return cache
    }()

    /// NSCache-backed memoization for parseAll results (Story 3.4).
    private static let parseAllCache: NSCache<NSString, TagParseResultBox> = {
        let cache = NSCache<NSString, TagParseResultBox>()
        cache.countLimit = 200
        return cache
    }()

    /// Reference-type wrapper so MemoryParseResult (a value type) can be stored in NSCache.
    private final class ParseResultBox: @unchecked Sendable {
        let result: MemoryParseResult
        init(_ result: MemoryParseResult) { self.result = result }
    }

    /// Reference-type wrapper so TagParseResult (a value type) can be stored in NSCache.
    private final class TagParseResultBox: @unchecked Sendable {
        let result: TagParseResult
        init(_ result: TagParseResult) { self.result = result }
    }

    // MARK: - Public Methods

    /// Parse text to extract memory moments and clean text
    ///
    /// - Parameter text: Text potentially containing [MEMORY: ...] tags
    /// - Returns: MemoryParseResult with clean text and extracted moments
    ///
    /// Example:
    /// ```swift
    /// let result = MemoryMomentParser.parse("Given your value of [MEMORY: honesty], how...")
    /// // result.cleanText == "Given your value of honesty, how..."
    /// // result.moments[0].content == "honesty"
    /// ```
    static func parse(_ text: String) -> MemoryParseResult {
        guard !text.isEmpty else {
            return MemoryParseResult(cleanText: "", moments: [])
        }

        let key = text as NSString
        if let cached = parseCache.object(forKey: key) {
            return cached.result
        }

        var moments: [MemoryMoment] = []

        // Find all matches
        let matches = text.matches(of: memoryPattern)

        for match in matches {
            let fullMatch = String(match.output.0)
            let content = String(match.output.1)

            let moment = MemoryMoment(
                content: content,
                originalTag: fullMatch
            )
            moments.append(moment)
        }

        // Single-pass replacement
        let cleanText = text.replacing(memoryPattern) { String($0.output.1) }

        let result = MemoryParseResult(cleanText: cleanText, moments: moments)
        parseCache.setObject(ParseResultBox(result), forKey: key)
        return result
    }

    /// Check if text contains any memory moment tags
    ///
    /// - Parameter text: Text to check
    /// - Returns: true if [MEMORY: ...] tags are present
    static func hasMemoryMoments(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }
        return text.contains(memoryPattern)
    }

    /// Extract just the memory moment contents without cleaning text
    ///
    /// - Parameter text: Text containing [MEMORY: ...] tags
    /// - Returns: Array of memory content strings
    static func extractMomentContents(_ text: String) -> [String] {
        guard !text.isEmpty else { return [] }
        return text.matches(of: memoryPattern).map { String($0.output.1) }
    }

    /// Strip all memory tags from text, preserving content
    ///
    /// - Parameter text: Text with [MEMORY: ...] tags
    /// - Returns: Text with tags removed, content preserved
    static func stripTags(_ text: String) -> String {
        guard !text.isEmpty else { return "" }
        return text.replacing(memoryPattern) { match in
            String(match.output.1)
        }
    }

    // MARK: - Multi-Tag Parsing (Story 3.4)

    /// Parse text to extract all coaching tags (memory + pattern), ordered by position
    ///
    /// - Parameter text: Text potentially containing [MEMORY: ...] and [PATTERN: ...] tags
    /// - Returns: TagParseResult with clean text and all extracted tags in order
    ///
    /// Example:
    /// ```swift
    /// let result = MemoryMomentParser.parseAll("I've noticed [PATTERN: you feel stuck before transitions]. Given [MEMORY: your goal of growth]...")
    /// // result.tags[0].type == .pattern
    /// // result.tags[1].type == .memory
    /// // result.hasPatternInsights == true
    /// // result.hasMemoryMoments == true
    /// ```
    static func parseAll(_ text: String) -> TagParseResult {
        guard !text.isEmpty else {
            return TagParseResult(cleanText: "", displayText: "", tags: [])
        }

        let key = text as NSString
        if let cached = parseAllCache.object(forKey: key) {
            return cached.result
        }

        // Collect all matches with their positions for ordering
        var tagEntries: [(range: Range<String.Index>, type: CoachingTagType, content: String)] = []

        // Find all [MEMORY: ...] matches
        for match in text.matches(of: memoryPattern) {
            let content = String(match.output.1)
            tagEntries.append((range: match.range, type: .memory, content: content))
        }

        // Find all [PATTERN: ...] matches
        for match in text.matches(of: patternPattern) {
            let content = String(match.output.1)
            tagEntries.append((range: match.range, type: .pattern, content: content))
        }

        // Sort by position in text
        tagEntries.sort { $0.range.lowerBound < $1.range.lowerBound }

        // Build tags array
        let tags = tagEntries.map { CoachingTag(type: $0.type, content: $0.content) }

        // Build clean text by stripping both tag types (content preserved for copy/accessibility)
        let cleanText = text
            .replacing(memoryPattern) { String($0.output.1) }
            .replacing(patternPattern) { String($0.output.1) }

        // Build display text — pattern tags fully removed (shown in separate box)
        let rawDisplay = text
            .replacing(memoryPattern) { String($0.output.1) }
            .replacing(patternPattern) { _ in "" }
        let displayText = rawDisplay
            .replacing(/[ \t]{2,}/) { _ in " " }
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let result = TagParseResult(cleanText: cleanText, displayText: displayText, tags: tags)
        parseAllCache.setObject(TagParseResultBox(result), forKey: key)
        return result
    }

    /// Strip all pattern tags from text, preserving content (Story 3.4)
    ///
    /// - Parameter text: Text with [PATTERN: ...] tags
    /// - Returns: Text with tags removed, content preserved
    static func stripPatternTags(_ text: String) -> String {
        guard !text.isEmpty else { return "" }
        return text.replacing(patternPattern) { match in
            String(match.output.1)
        }
    }

    /// Check if text contains any pattern insight tags (Story 3.4)
    ///
    /// - Parameter text: Text to check
    /// - Returns: true if [PATTERN: ...] tags are present
    static func hasPatternInsights(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }
        return text.contains(patternPattern)
    }

    /// Find ranges of memory moments in clean text
    /// Useful for applying attributed string styling
    ///
    /// - Parameter text: Original text with tags
    /// - Returns: Array of (content, range in clean text) tuples
    /// - Note: Handles duplicate content by tracking search position
    static func findMomentRanges(_ text: String) -> [(content: String, range: Range<String.Index>)] {
        let result = parse(text)
        var ranges: [(content: String, range: Range<String.Index>)] = []
        var searchStartIndex = result.cleanText.startIndex

        for moment in result.moments {
            // Search from the current position to handle duplicates
            let searchRange = searchStartIndex..<result.cleanText.endIndex
            if let range = result.cleanText.range(of: moment.content, range: searchRange) {
                ranges.append((moment.content, range))
                // Move search start past this match to find subsequent duplicates
                searchStartIndex = range.upperBound
            }
        }

        return ranges
    }
}

// MARK: - String Extension

extension String {
    /// Parse this string for memory moments
    var memoryMoments: MemoryParseResult {
        MemoryMomentParser.parse(self)
    }

    /// Check if this string contains memory moment tags
    var containsMemoryMoments: Bool {
        MemoryMomentParser.hasMemoryMoments(self)
    }

    /// This string with memory tags stripped (content preserved)
    var strippingMemoryTags: String {
        MemoryMomentParser.stripTags(self)
    }

    /// Parse this string for all coaching tags (memory + pattern)
    var coachingTags: TagParseResult {
        MemoryMomentParser.parseAll(self)
    }

    /// Check if this string contains pattern insight tags
    var containsPatternInsights: Bool {
        MemoryMomentParser.hasPatternInsights(self)
    }
}
