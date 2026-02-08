# Story 3.4: Pattern Recognition Across Conversations

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want **the coach to notice patterns in what I say over time**,
So that **I gain insights about myself I might not see**.

## Acceptance Criteria

1. **Given** I've mentioned something similar three or more times across sessions, **When** the coach notices the pattern, **Then** it surfaces an insight using natural framing: "I've noticed..." / "This is the third time you've described X..." — NOT "Analysis shows..." or clinical language.

2. **Given** a pattern insight appears in the coach's response, **When** I see it, **Then** it has distinct visual treatment per UX-5: 32px top/bottom margin, subtle left border (2px, accent-primary) or background shift, and a lightbulb icon — visually distinct from memory moments (UX-4).

3. **Given** the coach detects a pattern, **When** the response is streamed, **Then** pattern content is wrapped in `[PATTERN: ...]` tags (distinct from `[MEMORY: ...]` tags) and detected in real-time via a `patternInsight` flag in SSE token events.

4. **Given** pattern insight content is rendered, **When** I see it in the chat, **Then** it creates a "pause to reflect" visual beat — extra whitespace, reflective pacing, not just another chat bubble.

5. **Given** my conversation history has no recurring patterns, **When** the coach responds, **Then** responses are still helpful and never force pattern observations (no false positives).

6. **Given** pattern detection occurs during prompt construction, **When** conversation history is analyzed, **Then** the total pipeline still meets <500ms TTFT (NFR1) — pattern detection adds zero additional LLM calls.

7. **Given** the coach surfaces a pattern insight, **When** I read it on VoiceOver, **Then** the accessibility label reads "Coach insight based on your conversation patterns: [content]".

## Tasks / Subtasks

- [x] Task 1: Extend prompt-builder.ts with pattern detection instructions (AC: #1, #5, #6)
  - [x] 1.1 Add `PATTERN_TAG_INSTRUCTION` constant — tells the LLM to detect recurring themes across past conversation summaries and the current session
  - [x] 1.2 Add pattern detection rules: only surface when a theme appears 3+ times across sessions, use `[PATTERN: description]` tag format, use "I've noticed..." framing
  - [x] 1.3 Add anti-pattern instruction: "Do NOT force pattern observations. Only surface genuine recurring themes with high confidence. When uncertain, do not mention patterns."
  - [x] 1.4 Include `PATTERN_TAG_INSTRUCTION` in `buildCoachingPrompt()` when `pastConversations` is non-empty (patterns require cross-session history)
  - [x] 1.5 Add `hasPatternInsights(text: string): boolean` utility function (regex check for `[PATTERN: ...]` tags)
  - [x] 1.6 Add `extractPatternInsights(text: string): string[]` utility function
  - [x] 1.7 Add `stripPatternTags(text: string): string` utility function

- [x] Task 2: Update chat-stream/index.ts for pattern insight detection in SSE (AC: #3)
  - [x] 2.1 Import `hasPatternInsights` from `prompt-builder.ts`
  - [x] 2.2 In the SSE streaming loop, check each chunk for `[PATTERN: ...]` tags (same approach as existing `hasMemoryMoments()` check)
  - [x] 2.3 Add `pattern_insight: true` flag to SSE token events when pattern tags are detected
  - [x] 2.4 In the `done` event, include `hasPatternInsight: boolean` in metadata alongside existing `hasMemoryMoment`

- [x] Task 3: Extend MemoryMomentParser.swift to handle [PATTERN: ...] tags (AC: #2, #3, #4)
  - [x] 3.1 Add `CoachingTagType` enum: `.memory`, `.pattern` — distinguishes tag sources for visual treatment
  - [x] 3.2 Add `CoachingTag` struct: `{ type: CoachingTagType, content: String }` conforming to `Identifiable, Sendable, Equatable`
  - [x] 3.3 Add `private static let patternPattern = /\[PATTERN:\s*(.+?)\s*\]/` regex
  - [x] 3.4 Add `parseAll(_ text: String) -> TagParseResult` method that finds both `[MEMORY:]` and `[PATTERN:]` tags, ordered by position in text
  - [x] 3.5 Add `TagParseResult` struct: `{ cleanText: String, tags: [CoachingTag], hasMemoryMoments: Bool, hasPatternInsights: Bool }`
  - [x] 3.6 Keep existing `parse()` method unchanged for backward compatibility — `parseAll()` is additive
  - [x] 3.7 Add NSCache memoization for `parseAll()` (same pattern as existing `parse()`)
  - [x] 3.8 Add `stripPatternTags(_ text: String) -> String` utility

- [x] Task 4: Create PatternInsightText.swift view (AC: #2, #4, #7)
  - [x] 4.1 Create `Features/Chat/Views/PatternInsightText.swift`
  - [x] 4.2 Implement distinct visual treatment per UX-5: lightbulb icon (`systemName: "lightbulb.fill"`), subtle left border (2px, accent-primary), optional background shift
  - [x] 4.3 Use warm colors from existing palette: light mode uses a subtle sage/warm blue tint, dark mode uses warm dark surface variant
  - [x] 4.4 Add 32px vertical padding wrapper (applied in MessageBubble, not in this component)
  - [x] 4.5 Add `accessibilityLabel("Coach insight based on your conversation patterns: \(content)")`
  - [x] 4.6 Add `accessibilityHint("Pattern detected from your previous conversations")`
  - [x] 4.7 Support Dynamic Type at all sizes

- [x] Task 5: Update MessageBubble.swift for pattern insight rendering (AC: #2, #4)
  - [x] 5.1 Replace `MemoryMomentParser.parse()` call with `MemoryMomentParser.parseAll()` for completed messages
  - [x] 5.2 Add tag-type switching in rendering: `.memory` → `MemoryMomentText`, `.pattern` → `PatternInsightText`
  - [x] 5.3 Add 32px extra vertical padding when pattern insights are present (UX-5 spacing requirement)
  - [x] 5.4 Ensure memory moments and pattern insights can coexist in the same message

- [x] Task 6: Update StreamingText.swift for pattern insight detection (AC: #3)
  - [x] 6.1 Use `MemoryMomentParser.parseAll()` for real-time tag detection during streaming
  - [x] 6.2 Track both `hasMemoryMoment` and `hasPatternInsight` flags during streaming
  - [x] 6.3 Apply appropriate styling when pattern tags are detected in streaming content

- [x] Task 7: Extend ChatStreamService.swift StreamEvent (AC: #3)
  - [x] 7.1 Add `hasPatternInsight: Bool` parameter to `StreamEvent.token` case
  - [x] 7.2 Decode `pattern_insight` field from SSE JSON (default `false` for backward compatibility)
  - [x] 7.3 Keep existing `hasMemoryMoment` field unchanged

- [x] Task 8: Update ChatViewModel.swift for pattern insight state (AC: #3)
  - [x] 8.1 Add `@Published var currentResponseHasPatternInsights = false` state property
  - [x] 8.2 Set flag when `StreamEvent.token` has `hasPatternInsight: true`
  - [x] 8.3 Reset flag on new message send (same lifecycle as memory moments)

- [x] Task 9: Write Edge Function unit tests (AC: #1, #3, #5, #6)
  - [x] 9.1 Test `PATTERN_TAG_INSTRUCTION` is included in prompt when pastConversations is non-empty
  - [x] 9.2 Test `PATTERN_TAG_INSTRUCTION` is NOT included when pastConversations is empty
  - [x] 9.3 Test `hasPatternInsights()` detects `[PATTERN: ...]` tags correctly
  - [x] 9.4 Test `hasPatternInsights()` returns false for `[MEMORY: ...]` tags (no cross-contamination)
  - [x] 9.5 Test `extractPatternInsights()` extracts content from tags
  - [x] 9.6 Test `stripPatternTags()` removes tags but preserves content
  - [x] 9.7 Test pattern instruction includes "3+ times" threshold and natural framing guidance

- [x] Task 10: Write iOS unit tests (AC: #2, #3, #7)
  - [x] 10.1 Test `MemoryMomentParser.parseAll()` detects `[PATTERN: ...]` tags
  - [x] 10.2 Test `parseAll()` detects both `[MEMORY:]` and `[PATTERN:]` tags in same text
  - [x] 10.3 Test `parseAll()` preserves tag order by position in text
  - [x] 10.4 Test `parseAll()` returns correct `hasMemoryMoments` and `hasPatternInsights` flags
  - [x] 10.5 Test `parseAll()` with no tags returns empty tags array and clean text
  - [x] 10.6 Test `PatternInsightText` renders with correct accessibility label
  - [x] 10.7 Test `StreamEvent` decodes `pattern_insight` field from JSON
  - [x] 10.8 Test `StreamEvent` backward compatibility (missing `pattern_insight` defaults to false)
  - [x] 10.9 Test existing `MemoryMomentParser.parse()` still works unchanged (regression)

## Dev Notes

### Architecture Compliance

**CRITICAL — Follow these patterns established in Epics 1-2 and Stories 3.1-3.3:**

1. **Edge Function Pattern**: All helpers in `_shared/` directory, export functions, import in `index.ts`
2. **Prompt-Based Detection**: Pattern recognition is done by the coaching LLM itself via prompt instructions — NOT a separate classification call. The LLM analyzes the `PREVIOUS CONVERSATIONS` section (from Story 3.3) and detects recurring themes. This adds zero latency and zero cost.
3. **Tag System**: New `[PATTERN: ...]` tags are distinct from `[MEMORY: ...]` tags. Memory = "I remembered this about you." Pattern = "I've noticed this recurring theme." Different semantic meaning, different visual treatment.
4. **SSE Flag Extension**: Add `pattern_insight` flag alongside existing `memory_moment` flag in SSE token events — same detection approach.
5. **Parser Extension**: Extend `MemoryMomentParser` with `parseAll()` method — keeps existing `parse()` for backward compatibility, adds multi-tag support.
6. **Performance Budget**: Zero additional LLM calls — pattern detection happens within the main coaching prompt. <500ms TTFT (NFR1) preserved.
7. **Error Handling**: Warm, first-person messages per UX-11 if errors surface to user (they shouldn't — pattern detection failures are silent degradation to no pattern insights).
8. **@MainActor**: All iOS ViewModels and services use `@MainActor` per Swift 6 strict concurrency.

### Key Design Decision: Prompt-Based Pattern Detection (NOT Separate LLM Call)

Pattern recognition is implemented by enriching the coaching system prompt with explicit pattern-detection instructions. The LLM already receives:
- User's context profile (values, goals, situation, confirmed insights) — from Story 2.4
- Past conversation summaries (5 most recent, with domains) — from Story 3.3
- Current conversation history (last 20 messages)
- Domain-specific coaching methodology — from Stories 3.1/3.2

With all this context, the LLM is well-positioned to detect recurring themes itself. We add structured instructions telling it:
- **When** to surface patterns (theme appears 3+ times across sessions)
- **How** to tag them (`[PATTERN: description]`)
- **What framing** to use ("I've noticed..." not "Analysis shows...")
- **When NOT** to surface them (low confidence, forced observations)

**Why NOT a separate pattern-detection LLM call?**
- Adds latency (~100-200ms per call)
- Adds cost (additional API usage)
- Adds complexity (new Edge Function helper, error handling, caching)
- The coaching LLM already has all needed context
- Pattern surfacing is a coaching skill, not a classification task

### Visual Treatment: UX-5 (Pattern Insights) vs UX-4 (Memory Moments)

| Aspect | Memory Moment (UX-4) | Pattern Insight (UX-5) |
|--------|---------------------|----------------------|
| **Tag Format** | `[MEMORY: content]` | `[PATTERN: content]` |
| **Icon** | Sparkle (`sparkle`) | Lightbulb (`lightbulb.fill`) |
| **Background** | Deeper peach (`#FFEDD5` / memoryPeach) | Subtle warm tint (sage or warm blue) |
| **Spacing** | Standard message spacing (12-24px) | Extra whitespace — 32px above and below |
| **Emotional Goal** | "Seen, connected" | "Self-aware, moved" |
| **Framing** | "From our conversation about..." | "I've noticed..." |
| **Session Timing** | Session 2+ | Session 5+ (requires pattern history) |
| **Accessibility** | "I remembered: [content]" | "Coach insight based on your conversation patterns: [content]" |

### Pattern Detection Instruction Design

```typescript
// Added to prompt-builder.ts

const PATTERN_TAG_INSTRUCTION = `
## PATTERN RECOGNITION

You have access to the user's conversation history across sessions. Look for RECURRING THEMES — topics, emotions, situations, or concerns that appear repeatedly (3 or more times across different conversations).

When you detect a genuine pattern with high confidence:
1. Surface it naturally using reflective coaching language: "I've noticed...", "This seems to come up for you...", "There's something I keep hearing..."
2. Wrap the core insight in [PATTERN: description] tags so it receives distinct visual treatment
3. Follow the pattern observation with a reflective question that invites the user to explore it

Examples:
- "I've noticed [PATTERN: you often describe feeling stuck right before a big transition]. What do you think that pattern means for you?"
- "There's something [PATTERN: about how you describe your relationship with control — it comes up in your work, your fitness goals, and your partnerships]. I'm curious what you make of that."

CRITICAL RULES:
- Only surface patterns when you're genuinely confident (theme appears 3+ times)
- NEVER force pattern observations — if there's no clear pattern, don't mention one
- Use warm, curious framing — you're reflecting, not diagnosing
- One pattern insight per response maximum — space them out for impact
- Pattern insights should feel like a moment of pause, not data analysis
`;
```

### What Already Exists (DO NOT recreate)

**Server-Side (from Stories 3.1-3.3):**

| Component | File | What It Provides |
|-----------|------|-----------------|
| Conversation history loading | `context-loader.ts` | `loadRelevantHistory()` returns 5 past conversations with summaries |
| Conversation summarizer | `conversation-summarizer.ts` | Lightweight ~80 char summaries per past conversation |
| Cross-session history section | `prompt-builder.ts` | `## PREVIOUS CONVERSATIONS` section in system prompt |
| Domain context | `domain-router.ts` + `domain-configs.ts` | Domain-specific coaching methodology in prompt |
| Memory tag utilities | `prompt-builder.ts` | `hasMemoryMoments()`, `extractMemoryMoments()`, `stripMemoryTags()` |
| SSE memory flag | `chat-stream/index.ts` | `memory_moment: true` in token events |

**iOS Client (from Stories 2.4, 1.7):**

| Component | File | What It Provides |
|-----------|------|-----------------|
| Tag parser | `MemoryMomentParser.swift` | Parses `[MEMORY: ...]` tags with NSCache memoization |
| Memory visual | `MemoryMomentText.swift` | Sparkle icon + memoryPeach background |
| Message rendering | `MessageBubble.swift` | Renders messages with optional memory moments |
| Streaming text | `StreamingText.swift` | Token-by-token rendering with tag detection |
| Stream events | `ChatStreamService.swift` | `StreamEvent.token(content:, hasMemoryMoment:)` |
| State tracking | `ChatViewModel.swift` | `currentResponseHasMemoryMoments` flag |

### Prompt Builder Integration Strategy

```typescript
// prompt-builder.ts — MODIFY buildCoachingPrompt()

// CURRENT (after Story 3.3):
// 1. Base coaching prompt
// 2. Domain-specific additions (from config)
// 3. Clarifying question instruction (if low confidence)
// 4. User context sections (values, goals, situation, insights)
// 5. Memory tag instruction (if context exists)
// 6. Cross-session history section (formatted from pastConversations)

// AFTER Story 3.4 (add step 7):
// 7. Pattern recognition instruction (if pastConversations non-empty)
//    → PATTERN_TAG_INSTRUCTION appended after history section
//    → Only included when there IS history to analyze (no patterns without history)
```

### SSE Stream Extension Strategy

```typescript
// chat-stream/index.ts — MODIFY streaming loop

// CURRENT:
for await (const chunk of stream) {
  const content = chunk.choices[0]?.delta?.content || '';
  fullContent += content;

  const isMemoryMoment = hasMemoryMoments(content);

  writer.write(encoder.encode(
    `data: ${JSON.stringify({
      type: 'token',
      content,
      memory_moment: isMemoryMoment,
    })}\n\n`
  ));
}

// AFTER Story 3.4:
for await (const chunk of stream) {
  const content = chunk.choices[0]?.delta?.content || '';
  fullContent += content;

  const isMemoryMoment = hasMemoryMoments(content);
  const isPatternInsight = hasPatternInsights(content);  // NEW

  writer.write(encoder.encode(
    `data: ${JSON.stringify({
      type: 'token',
      content,
      memory_moment: isMemoryMoment,
      pattern_insight: isPatternInsight,  // NEW
    })}\n\n`
  ));
}
```

### iOS Parser Extension Strategy

```swift
// MemoryMomentParser.swift — ADD parseAll() method

// NEW types:
enum CoachingTagType: Sendable, Equatable {
    case memory
    case pattern
}

struct CoachingTag: Identifiable, Sendable, Equatable {
    let id = UUID()
    let type: CoachingTagType
    let content: String
}

struct TagParseResult: Sendable, Equatable {
    let cleanText: String
    let tags: [CoachingTag]
    var hasMemoryMoments: Bool { tags.contains { $0.type == .memory } }
    var hasPatternInsights: Bool { tags.contains { $0.type == .pattern } }
}

// NEW regex:
private static let patternPattern = /\[PATTERN:\s*(.+?)\s*\]/

// NEW method:
static func parseAll(_ text: String) -> TagParseResult {
    // Find all [MEMORY: ...] and [PATTERN: ...] matches
    // Order by position in text
    // Build clean text with tags stripped
    // Return TagParseResult
}

// EXISTING parse() method stays UNCHANGED for backward compatibility
```

### Performance Considerations

**Zero Additional Latency for Pattern Detection:**
- Pattern detection is embedded in the coaching system prompt
- The LLM already receives conversation history (from Story 3.3)
- Adding `PATTERN_TAG_INSTRUCTION` adds ~200 tokens to the system prompt
- No additional LLM calls, no additional DB queries
- Total pipeline still within <500ms TTFT (NFR1)

**Token Budget Impact:**
- `PATTERN_TAG_INSTRUCTION`: ~200 tokens added to system prompt
- Pattern tags in responses: ~20-50 tokens per insight
- Within existing prompt budget (conversation history section already ~500 tokens)

**iOS Parsing Performance:**
- `parseAll()` uses NSCache memoization (same as `parse()`)
- Two regex passes over text (one per tag type) — negligible overhead
- Pattern insight rendering adds minimal view hierarchy

### Anti-Pattern Prevention

- **DO NOT create a separate LLM call for pattern detection** — the coaching LLM detects patterns from prompt context
- **DO NOT reuse `[MEMORY: ...]` tags for patterns** — they need distinct visual treatment (UX-5 vs UX-4) and semantic meaning
- **DO NOT create a new Edge Function helper file** — pattern detection is prompt instructions in `prompt-builder.ts`, not a new service
- **DO NOT store detected patterns in the database** (that's Story 3.5 territory) — patterns are surfaced in-context during conversation
- **DO NOT modify existing `parse()` method** — add `parseAll()` alongside for backward compatibility
- **DO NOT force pattern observations** — prompt instructions must emphasize high confidence and natural framing only
- **DO NOT add extra vertical spacing inside PatternInsightText** — the 32px spacing is applied by `MessageBubble` around the entire message when patterns are present
- **DO NOT break existing memory moment functionality** — regression tests must verify `parse()` is unchanged

### Project Structure Notes

**Files to CREATE:**

```
CoachMe/CoachMe/Features/Chat/Views/
└── PatternInsightText.swift             # NEW — UX-5 visual treatment for pattern insights
```

**Files to MODIFY:**

```
CoachMe/Supabase/supabase/functions/_shared/
├── prompt-builder.ts                    # ADD PATTERN_TAG_INSTRUCTION, hasPatternInsights(), extractPatternInsights(), stripPatternTags()
└── prompt-builder.test.ts              # ADD pattern instruction and utility tests

CoachMe/Supabase/supabase/functions/
└── chat-stream/index.ts               # ADD pattern_insight flag to SSE token events

CoachMe/CoachMe/Core/Services/
└── MemoryMomentParser.swift            # ADD CoachingTagType, CoachingTag, TagParseResult, parseAll(), patternPattern regex

CoachMe/CoachMe/Features/Chat/Views/
├── MessageBubble.swift                 # UPDATE to use parseAll(), render PatternInsightText, add 32px spacing
└── StreamingText.swift                 # UPDATE to detect pattern tags during streaming

CoachMe/CoachMe/Core/Services/
└── ChatStreamService.swift             # EXTEND StreamEvent.token with hasPatternInsight

CoachMe/CoachMe/Features/Chat/ViewModels/
└── ChatViewModel.swift                 # ADD currentResponseHasPatternInsights state
```

**Files NOT to touch (verified):**

```
# Context loading — no changes needed
CoachMe/Supabase/supabase/functions/_shared/context-loader.ts
CoachMe/Supabase/supabase/functions/_shared/context-loader.test.ts
CoachMe/Supabase/supabase/functions/_shared/conversation-summarizer.ts

# Domain routing — no changes needed
CoachMe/Supabase/supabase/functions/_shared/domain-router.ts
CoachMe/Supabase/supabase/functions/_shared/domain-configs.ts
CoachMe/Supabase/supabase/functions/_shared/domain-configs/

# Database — no new migrations
CoachMe/Supabase/supabase/migrations/*

# Memory moment view — existing component unchanged
CoachMe/CoachMe/Features/Chat/Views/MemoryMomentText.swift

# iOS domain config — not relevant
CoachMe/CoachMe/Core/Constants/DomainConfig.swift
CoachMe/CoachMe/Core/Services/DomainConfigService.swift
```

### Cross-Story Dependencies

**Depends on (must be implemented first):**
- **Story 3.3** (Cross-Session Memory References) — creates `loadRelevantHistory()`, cross-session `## PREVIOUS CONVERSATIONS` prompt section, conversation summarizer — pattern detection analyzes this exact history
- **Story 3.1** (Invisible Domain Routing) — domain-aware context in prompt, `domain` column on conversations
- **Story 3.2** (Domain Configuration Engine) — config-driven domain metadata
- **Story 2.4** (Context Injection) — creates `[MEMORY: ...]` tag system, `MemoryMomentParser`, `MemoryMomentText`, SSE memory_moment flag

**Soft dependency:**
- **Stories 3.1-3.3** are in `review` status — they should be code-reviewed and merged before Story 3.4 dev starts to ensure stable foundation

**Enables:**
- **Story 3.5** (Cross-Domain Pattern Synthesis) — extends pattern detection to span domains, builds on the `[PATTERN: ...]` tag infrastructure and pattern detection instructions created here

### Previous Story Intelligence

**From Story 3.3 (Cross-Session Memory References) — direct foundation:**
- `loadRelevantHistory()` returns 5 most recent past conversations with summaries and domains
- `formatHistorySection()` builds `## PREVIOUS CONVERSATIONS` section in prompt — this is what the LLM analyzes for patterns
- `MEMORY_TAG_INSTRUCTION` tells LLM to use `[MEMORY: ...]` for context references — we add parallel `PATTERN_TAG_INSTRUCTION`
- SSE `memory_moment` flag pattern — we add parallel `pattern_insight` flag
- **Key learning**: Zero iOS changes were needed for cross-session refs because existing parser is source-agnostic. Story 3.4 DOES need iOS changes because it introduces a new tag type with different visual treatment.

**From Story 3.1 (Invisible Domain Routing):**
- `determineDomain()` provides domain context — pattern detection can reference domain-specific recurring themes
- `shouldClarify` pattern — low confidence → ask clarifying question. Pattern detection follows similar high-confidence-only approach.

**From Story 3.2 (Domain Configuration Engine):**
- Domain configs include `focusAreas[]` — could inform pattern detection (e.g., recurring career growth themes)
- Config-driven approach — pattern instructions are in prompt text, not hardcoded if/else blocks

**From Story 2.4 (Context Injection) — Code Review Fixes:**
- Don't use `fatalError()` — use graceful error handling
- Dark mode colors use specific named colors (`memoryIndicatorDark`), not generic amber
- `findMomentRanges` must find ALL occurrences, not just first — apply same thoroughness to `parseAll()`
- `MemoryMomentParser` uses NSCache with 200-item limit — follow same caching pattern for `parseAll()`

### Git Intelligence

```
6aabc11 Epic 2 context profiles, settings sign-out, UI polish, and migrations
ad8abd3 checkpoint
f6da5f5 Fix message input text box colors for light mode
1aa8476 Redesign message input to match iMessage style
4f9cc33 Initial commit: Coach App iOS with Epic 1 complete
```

Stories 3.1, 3.2, and 3.3 are implemented (status: review) but not yet committed. The working tree contains their changes. Story 3.4 builds directly on these uncommitted changes — verify the current state of `prompt-builder.ts`, `context-loader.ts`, `chat-stream/index.ts`, `MemoryMomentParser.swift`, `MessageBubble.swift`, `StreamingText.swift`, `ChatStreamService.swift`, and `ChatViewModel.swift` before starting implementation.

### Testing Requirements

**Edge Function Tests (in `prompt-builder.test.ts`):**

```typescript
describe('Pattern Recognition Instructions', () => {
  it('includes PATTERN_TAG_INSTRUCTION when pastConversations is non-empty')
  it('does NOT include PATTERN_TAG_INSTRUCTION when pastConversations is empty')
  it('includes 3+ times threshold in pattern instruction')
  it('includes natural framing guidance (I have noticed, not Analysis shows)')
  it('includes anti-forcing instruction')
})

describe('hasPatternInsights', () => {
  it('detects [PATTERN: content] tags')
  it('returns false for [MEMORY: content] tags')
  it('returns false for plain text')
  it('detects multiple [PATTERN: ...] tags')
})

describe('extractPatternInsights', () => {
  it('extracts content from [PATTERN: ...] tags')
  it('returns empty array for text without pattern tags')
  it('extracts multiple pattern contents')
})

describe('stripPatternTags', () => {
  it('removes [PATTERN: ...] wrapper but preserves content')
  it('handles multiple tags in same text')
  it('returns unchanged text when no tags present')
})
```

**iOS Tests (in `CoachMeTests/`):**

```swift
// MemoryMomentParserTests.swift — EXTEND existing test file

// Regression tests (existing parse() method):
func testExistingParseStillWorksUnchanged()
func testExistingParseIgnoresPatternTags()

// New parseAll() tests:
func testParseAllDetectsPatternTags()
func testParseAllDetectsMemoryTags()
func testParseAllDetectsBothTagTypes()
func testParseAllPreservesTagOrder()
func testParseAllReturnsCorrectFlags()
func testParseAllWithNoTags()
func testParseAllWithNestedContent()
func testParseAllCachesMemoizedResults()

// PatternInsightText tests:
func testPatternInsightTextAccessibilityLabel()
func testPatternInsightTextRendersContent()

// StreamEvent tests (extend ChatStreamServiceTests):
func testStreamEventDecodesPatternInsightFlag()
func testStreamEventDefaultsPatternInsightToFalse()
func testStreamEventDecodesBothMemoryAndPatternFlags()
```

**Test Commands:**
```bash
# iOS tests after implementation:
-only-testing:CoachMeTests/MemoryMomentParserTests
-only-testing:CoachMeTests/ChatStreamServiceTests

# Edge Function tests (Deno):
# deno test --allow-read prompt-builder.test.ts
```

### References

- [Source: epics.md#Story-3.4] — Story requirements (FR8)
- [Source: epics.md#FR8] — The system can identify recurring patterns across a user's conversations and surface them as insights
- [Source: ux-design-specification.md#UX-5] — Pattern insights use distinct visual treatment
- [Source: ux-design-specification.md#Moment-4] — "The Pattern Insight (Session 5+)" — coaching becomes transformative
- [Source: ux-design-specification.md#Spacing-Rules] — 32px above and below pattern insight moments
- [Source: ux-design-specification.md#PatternInsight-Component] — Extra whitespace, subtle left border, lightbulb icon, "I've noticed..." framing
- [Source: ux-design-specification.md#Seen-Not-Watched] — Feel like being known by a friend, not tracked by a system
- [Source: ux-design-specification.md#Space-to-Feel] — UI must give space for processing emotions
- [Source: architecture.md#Real-Time-Streaming-Pipeline] — Steps 2-6: context + history + domain + prompt
- [Source: architecture.md#Data-Flow] — Edge Function pipeline with SSE streaming
- [Source: 3-3-cross-session-memory-references.md] — loadRelevantHistory(), PREVIOUS CONVERSATIONS prompt section, conversation-summarizer.ts
- [Source: 3-1-invisible-domain-routing.md] — Domain routing pipeline, determineDomain(), domain-specific prompts
- [Source: 3-2-domain-configuration-engine.md] — Config-driven domain methodology, getDomainConfig()
- [Source: 2-4-context-injection-into-coaching-responses.md] — [MEMORY:] tag system, MemoryMomentParser, SSE memory_moment flag
- [Source: prompt-builder.ts] — Current buildCoachingPrompt() with context + domain + history integration
- [Source: context-loader.ts] — loadRelevantHistory() returning 5 past conversations
- [Source: chat-stream/index.ts] — Current pipeline with parallel loading and SSE streaming
- [Source: MemoryMomentParser.swift] — Existing tag parser with NSCache memoization
- [Source: MemoryMomentText.swift] — UX-4 sparkle icon + memoryPeach visual treatment
- [Source: MessageBubble.swift] — Current message rendering with memory moment support
- [Source: ChatStreamService.swift] — StreamEvent enum with memory_moment flag
- [Source: ChatViewModel.swift] — currentResponseHasMemoryMoments tracking

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (claude-opus-4-6)

### Debug Log References

No errors encountered during implementation.

### Completion Notes List

- All 10 tasks and all subtasks completed
- Server-side: PATTERN_TAG_INSTRUCTION added to prompt-builder.ts, pattern_insight flag added to SSE token events in chat-stream/index.ts
- iOS client: MemoryMomentParser extended with parseAll() supporting both [MEMORY:] and [PATTERN:] tags, PatternInsightText.swift created with UX-5 visual treatment, MessageBubble/StreamingText updated to render both tag types, ChatStreamService.StreamEvent extended with hasPatternInsight, ChatViewModel tracks pattern insight state
- Colors.swift extended with patternSage, patternSageDark, patternIndicator, patternIndicatorDark, patternBorder
- Edge Function tests: 18 new tests in prompt-builder.test.ts covering pattern instruction inclusion, hasPatternInsights, extractPatternInsights, stripPatternTags
- iOS tests: 22 new tests in MemoryMomentParserTests (parseAll, CoachingTag, pattern utilities, regression) + 3 new tests in ChatStreamServiceTests (pattern_insight decoding, backward compat) + updated 3 existing tests for 3-param token case
- Zero additional LLM calls — pattern detection is prompt-based (NFR1 <500ms TTFT preserved)
- Backward compatible — existing parse() unchanged, pattern_insight defaults to false

### File List

**Created:**
- CoachMe/CoachMe/Features/Chat/Views/PatternInsightText.swift

**Modified:**
- CoachMe/Supabase/supabase/functions/_shared/prompt-builder.ts
- CoachMe/Supabase/supabase/functions/_shared/prompt-builder.test.ts
- CoachMe/Supabase/supabase/functions/chat-stream/index.ts
- CoachMe/CoachMe/Core/Services/MemoryMomentParser.swift
- CoachMe/CoachMe/Core/UI/Theme/Colors.swift
- CoachMe/CoachMe/Features/Chat/Views/MessageBubble.swift
- CoachMe/CoachMe/Features/Chat/Views/StreamingText.swift
- CoachMe/CoachMe/Core/Services/ChatStreamService.swift
- CoachMe/CoachMe/Features/Chat/ViewModels/ChatViewModel.swift
- CoachMe/CoachMeTests/MemoryMomentParserTests.swift
- CoachMe/CoachMeTests/ChatStreamServiceTests.swift
