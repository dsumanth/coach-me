//
//  MemoryMomentParser.swift
//  CoachMe
//
//  Story 2.4: Context Injection into Coaching Responses
//  Parses [MEMORY: ...] tags from streaming text for visual highlighting (UX-4)
//

import Foundation

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

    // MARK: - Regex Pattern

    /// Pattern to match [MEMORY: content] tags
    /// Captures the content inside the tags
    private static let memoryPattern = /\[MEMORY:\s*(.+?)\s*\]/

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

        var cleanText = text
        var moments: [MemoryMoment] = []

        // Find all matches
        let matches = text.matches(of: memoryPattern)

        for match in matches {
            let fullMatch = String(match.output.0)  // [MEMORY: content]
            let content = String(match.output.1)    // content (captured group)

            // Create memory moment
            let moment = MemoryMoment(
                content: content,
                originalTag: fullMatch
            )
            moments.append(moment)

            // Replace tag with just the content in clean text
            cleanText = cleanText.replacingOccurrences(of: fullMatch, with: content)
        }

        return MemoryParseResult(cleanText: cleanText, moments: moments)
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
}
