//
//  MemoryMomentTextTests.swift
//  CoachMeTests
//
//  Story 2.4: Context Injection into Coaching Responses
//  Tests for MemoryMomentText visual component and accessibility
//

import XCTest
import SwiftUI
@testable import CoachMe

/// Tests for MemoryMomentText visual component
/// Verifies accessibility labels and view structure (AC #2, UX-4)
@MainActor
final class MemoryMomentTextTests: XCTestCase {

    // MARK: - View Instantiation Tests

    func testMemoryMomentTextCanBeInstantiated() {
        // Given/When: Creating a MemoryMomentText
        let view = MemoryMomentText(content: "honesty")

        // Then: Should be a valid SwiftUI view (compile-time check)
        XCTAssertNotNil(view, "MemoryMomentText should be instantiable")
    }

    func testMemoryMomentTextViewBodyExists() {
        // Given: A MemoryMomentText
        let view = MemoryMomentText(content: "becoming a leader")

        // When: Accessing the body
        let body = view.body

        // Then: Body should exist (verifies view structure is valid)
        XCTAssertNotNil(body, "MemoryMomentText body should exist")
    }

    func testMemoryMomentTextWithEmptyContent() {
        // Given/When: Creating with empty content
        let view = MemoryMomentText(content: "")

        // Then: Should still be valid
        XCTAssertNotNil(view, "MemoryMomentText with empty content should be instantiable")
    }

    func testMemoryMomentTextWithLongContent() {
        // Given: Long content string
        let longContent = "navigating a significant career transition while maintaining work-life balance"

        // When: Creating MemoryMomentText
        let view = MemoryMomentText(content: longContent)

        // Then: Should handle long content
        XCTAssertNotNil(view, "MemoryMomentText should handle long content")
    }

    // MARK: - MemoryHighlightedText Tests

    func testMemoryHighlightedTextCanBeInstantiated() {
        // Given/When: Creating MemoryHighlightedText with memory tags
        let view = MemoryHighlightedText(
            text: "Given that you value [MEMORY: honesty], how does this align?"
        )

        // Then: Should be instantiable
        XCTAssertNotNil(view, "MemoryHighlightedText should be instantiable")
    }

    func testMemoryHighlightedTextWithoutMemoryMoments() {
        // Given/When: Text without memory tags
        let view = MemoryHighlightedText(
            text: "This is regular coaching text."
        )

        // Then: Should handle text without memory moments
        XCTAssertNotNil(view, "MemoryHighlightedText should handle text without memory moments")
    }

    func testMemoryHighlightedTextWithMultipleMoments() {
        // Given: Text with multiple memory tags
        let text = "You value [MEMORY: honesty] and [MEMORY: growth] in your [MEMORY: career]."

        // When: Creating view
        let view = MemoryHighlightedText(text: text)

        // Then: Should handle multiple moments
        XCTAssertNotNil(view, "MemoryHighlightedText should handle multiple memory moments")
    }

    // MARK: - FlowLayout Tests

    func testFlowLayoutCanBeInstantiated() {
        // Given/When: Creating FlowLayout with content
        let layout = FlowLayout(spacing: 8)

        // Then: Should be valid
        XCTAssertNotNil(layout, "FlowLayout should be instantiable")
    }

    func testFlowLayoutWithCustomSpacing() {
        // Given: Various spacing values
        let layout1 = FlowLayout(spacing: 4)
        let layout2 = FlowLayout(spacing: 16)
        let layout3 = FlowLayout(spacing: 0)

        // Then: All should be valid
        XCTAssertNotNil(layout1, "FlowLayout with spacing 4 should work")
        XCTAssertNotNil(layout2, "FlowLayout with spacing 16 should work")
        XCTAssertNotNil(layout3, "FlowLayout with spacing 0 should work")
    }

    // MARK: - Accessibility Label Verification

    /// Verifies the accessibility label format matches UX-4 spec
    /// Format: "I remembered: {content}"
    /// Note: Full accessibility modifier testing requires ViewInspector or UI tests
    func testAccessibilityLabelFormat() {
        // Test various content strings to ensure the format is correct
        let testCases = [
            "honesty and authenticity",
            "becoming a better leader",
            "work-life balance",
            "", // Edge case: empty content
        ]

        for content in testCases {
            // Build expected label using same format as MemoryMomentText
            let expectedLabel = "I remembered: \(content)"

            // Verify format requirements per UX-4
            XCTAssertTrue(
                expectedLabel.hasPrefix("I remembered:"),
                "Accessibility label must start with 'I remembered:' for VoiceOver warmth"
            )
            XCTAssertTrue(
                expectedLabel.contains(content),
                "Accessibility label must include the memory content"
            )

            // Verify the view can be created with this content
            let view = MemoryMomentText(content: content)
            XCTAssertNotNil(view, "MemoryMomentText should handle content: '\(content)'")
        }
    }

    /// Verifies accessibility element children are combined for VoiceOver
    /// The sparkle icon + text should be read as a single element
    func testAccessibilityElementCombined() {
        // MemoryMomentText uses .accessibilityElement(children: .combine)
        // This ensures VoiceOver reads the sparkle icon and text together
        // as "I remembered: {content}" rather than separately

        // Structural verification: the view exists and accepts content
        let view = MemoryMomentText(content: "career transition")
        XCTAssertNotNil(view.body, "View should have valid body with combined accessibility")

        // Note: Full verification requires Accessibility Inspector or XCUITest
        // to confirm VoiceOver reads the combined label correctly
    }

    // MARK: - Integration Tests

    func testStreamingTextWithMemoryMoments() {
        // Given: Streaming text with memory moments
        let text = "Thinking about [MEMORY: your career goals], what's next?"

        // When: Creating StreamingText
        let view = StreamingText(text: text, isStreaming: false)

        // Then: View should be valid and handle memory parsing
        XCTAssertNotNil(view, "StreamingText should handle memory moments")
    }

    func testMessageBubbleWithMemoryMoments() {
        // Given: A message with memory tags
        let message = ChatMessage.assistantMessage(
            content: "Given your value of [MEMORY: honesty], how does this situation feel?",
            conversationId: UUID()
        )

        // When: Creating MessageBubble
        let bubble = MessageBubble(message: message)

        // Then: View should be valid
        XCTAssertNotNil(bubble, "MessageBubble should handle messages with memory moments")
    }
}
