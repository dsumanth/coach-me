# Story 2.4: Context Injection into Coaching Responses

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want **the coach to use what it knows about me in every response**,
So that **advice feels personalized, not generic**.

## Acceptance Criteria

1. **Given** I have context in my profile (values, goals, or situation)
   **When** the coach responds
   **Then** responses reference my values, goals, or situation when relevant

2. **Given** the coach references my context
   **When** I see the response
   **Then** memory moments are highlighted with subtle visual distinction (per UX-4)

3. **Given** I have no context in my profile
   **When** the coach responds
   **Then** responses are still helpful and don't mention missing context

4. **Given** the coach references my context
   **When** the response is streamed
   **Then** the memory moment is detected and tagged in real-time

## Tasks / Subtasks

- [x] Task 1: Create context-loader.ts Edge Function helper (AC: #1, #3)
  - [x] 1.1 Create `_shared/context-loader.ts` in Supabase functions
  - [x] 1.2 Implement `loadUserContext(supabase, userId)` function
  - [x] 1.3 Load from `context_profiles` table (values, goals, situation)
  - [x] 1.4 Load from `extracted_insights` where `confirmed = true`
  - [x] 1.5 Return structured context object (empty if no profile)
  - [x] 1.6 Handle database errors gracefully (return empty context, log error)
  - [x] 1.7 Target <200ms total load time per architecture NFR

- [x] Task 2: Create prompt-builder.ts Edge Function helper (AC: #1)
  - [x] 2.1 Create `_shared/prompt-builder.ts` in Supabase functions
  - [x] 2.2 Implement `buildCoachingPrompt(context, domain?)` function
  - [x] 2.3 Inject values section: "User values: {values}"
  - [x] 2.4 Inject goals section: "User goals: {goals}"
  - [x] 2.5 Inject situation section: "User life situation: {situation}"
  - [x] 2.6 Add instruction: "When you reference the user's context, wrap it in [MEMORY: ...] tags"
  - [x] 2.7 Handle empty context gracefully (omit empty sections)
  - [x] 2.8 Return complete system prompt string

- [x] Task 3: Update chat-stream/index.ts to use context injection (AC: #1, #3, #4)
  - [x] 3.1 Import `loadUserContext` from `context-loader.ts`
  - [x] 3.2 Import `buildCoachingPrompt` from `prompt-builder.ts`
  - [x] 3.3 Call `loadUserContext` before building messages array
  - [x] 3.4 Replace static `buildSystemPrompt()` with `buildCoachingPrompt(context)`
  - [x] 3.5 Add `hasMemoryMoment` detection in streamed tokens
  - [x] 3.6 Send `memory_moment: true` flag in SSE event when detected
  - [x] 3.7 Ensure total context loading + streaming start <500ms (NFR1)

- [x] Task 4: Create memory moment detection service (AC: #2, #4)
  - [x] 4.1 Create `MemoryMomentParser.swift` in `Core/Services/`
  - [x] 4.2 Detect `[MEMORY: ...]` tags in streamed text
  - [x] 4.3 Extract memory content and strip tags from display text
  - [x] 4.4 Return structured `MemoryMoment` with content and range
  - [x] 4.5 Handle nested or multiple memory moments in one response

- [x] Task 5: Create memory moment visual treatment (AC: #2)
  - [x] 5.1 Create `MemoryMomentText.swift` in `Features/Chat/Views/`
  - [x] 5.2 Apply subtle visual distinction per UX-4 (warm highlight, slight emphasis)
  - [x] 5.3 Use warm color from design system (memoryPeach #FFEDD5 background)
  - [x] 5.4 Add subtle icon or indicator (sparkle icon)
  - [x] 5.5 Ensure VoiceOver announces "I remembered: {content}"
  - [x] 5.6 Apply `.accessibilityLabel()` with memory context

- [x] Task 6: Integrate memory moments into streaming UI (AC: #2, #4)
  - [x] 6.1 Update `StreamingText.swift` to detect memory moments
  - [x] 6.2 Render memory moments using `MemoryMomentText` component
  - [x] 6.3 Handle memory moments appearing during active streaming
  - [x] 6.4 Update `MessageBubble.swift` to render completed memory moments
  - [x] 6.5 Test rendering on both iOS 18 and iOS 26 simulators

- [x] Task 7: Update ChatStreamService for memory moment events (AC: #4)
  - [x] 7.1 Update `StreamEvent` enum to include `hasMemoryMoment` flag
  - [x] 7.2 Parse `memory_moment` flag from SSE events
  - [x] 7.3 Yield memory moment events to ChatViewModel
  - [x] 7.4 Update ChatViewModel to track memory moments in current message

- [x] Task 8: Write Unit Tests
  - [x] 8.1 Test context-loader.ts loads profile correctly
  - [x] 8.2 Test context-loader.ts handles missing profile (returns empty)
  - [x] 8.3 Test prompt-builder.ts injects context correctly
  - [x] 8.4 Test prompt-builder.ts handles empty context gracefully
  - [x] 8.5 Test MemoryMomentParser detects `[MEMORY: ...]` tags
  - [x] 8.6 Test MemoryMomentParser handles multiple/nested moments
  - [x] 8.7 Test MemoryMomentText accessibility labels
  - [x] 8.8 Test StreamEvent parsing of memory_moment flag

## Dev Notes

### Architecture Compliance

**CRITICAL - Follow these patterns established in Epic 1 & Stories 2.1-2.3:**

1. **ViewModel Pattern**: Use `@Observable` not `@ObservableObject` (like `ChatViewModel.swift`)
2. **Service Pattern**: Use singleton `@MainActor` services
3. **Supabase Access**: Always via `AppEnvironment.shared.supabase`
4. **Edge Functions**: Use existing patterns from `chat-stream/index.ts`
5. **Adaptive Design**: Use `.adaptiveGlass()` for containers, keep content styling minimal
6. **Error Handling**: Custom `LocalizedError` enums with first-person messages per UX-11

### Technical Requirements

**From PRD (FR13):**
> The system can inject stored context (values, goals, situation, conversation history) into every coaching response

**From UX (UX-4):**
> Memory moments receive subtle visual distinction

**Key Design Principles:**
- Context injection is invisible to the user - they just see personalized responses
- Memory moments are a subtle enhancement, not a distraction
- Performance target: <500ms time-to-first-token even with context loading (NFR1)
- Context loading target: <200ms per architecture spec

**Context Loading Strategy:**
```typescript
// context-loader.ts
export interface UserContext {
  values: string[];       // From context_profiles.values JSONB
  goals: string[];        // From context_profiles.goals JSONB
  situation: string;      // From context_profiles.situation JSONB
  confirmedInsights: ExtractedInsight[]; // From extracted_insights where confirmed=true
}

export async function loadUserContext(
  supabase: SupabaseClient,
  userId: string
): Promise<UserContext | null> {
  const { data: profile } = await supabase
    .from('context_profiles')
    .select('values, goals, situation')
    .eq('user_id', userId)
    .single();

  const { data: insights } = await supabase
    .from('extracted_insights')
    .select('*')
    .eq('user_id', userId)
    .eq('confirmed', true);

  return {
    values: profile?.values ?? [],
    goals: profile?.goals ?? [],
    situation: profile?.situation ?? '',
    confirmedInsights: insights ?? []
  };
}
```

**Prompt Building Strategy:**
```typescript
// prompt-builder.ts
export function buildCoachingPrompt(context: UserContext | null): string {
  let prompt = `You are a warm, supportive life coach...`;

  if (context) {
    if (context.values.length > 0) {
      prompt += `\n\nUser values: ${context.values.join(', ')}`;
    }
    if (context.goals.length > 0) {
      prompt += `\n\nUser goals: ${context.goals.join(', ')}`;
    }
    if (context.situation) {
      prompt += `\n\nUser life situation: ${context.situation}`;
    }

    prompt += `\n\nIMPORTANT: When you reference the user's values, goals, or situation in your response, wrap that reference in [MEMORY: your reference here] tags. This helps highlight personalized moments.`;
  }

  return prompt;
}
```

**Memory Moment Detection (iOS):**
```swift
// MemoryMomentParser.swift
struct MemoryMoment: Identifiable {
    let id = UUID()
    let content: String
    let range: Range<String.Index>
}

final class MemoryMomentParser {
    private static let pattern = /\[MEMORY:\s*(.+?)\s*\]/

    static func parse(_ text: String) -> (cleanText: String, moments: [MemoryMoment]) {
        var cleanText = text
        var moments: [MemoryMoment] = []

        for match in text.matches(of: pattern) {
            let content = String(match.output.1)
            moments.append(MemoryMoment(content: content, range: match.range))
            cleanText = cleanText.replacingOccurrences(of: String(match.output.0), with: content)
        }

        return (cleanText, moments)
    }
}
```

**Memory Moment Visual Treatment (UX-4):**
```swift
// MemoryMomentText.swift
struct MemoryMomentText: View {
    let content: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkle")
                .font(.caption2)
                .foregroundStyle(Color.warmGold)

            Text(content)
                .font(.body)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.warmGold.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .accessibilityLabel("I remembered: \(content)")
    }
}
```

### Project Structure Notes

**Files to Create:**
```
CoachMe/Supabase/supabase/functions/
└── _shared/
    ├── context-loader.ts           # NEW - Load user context from DB
    └── prompt-builder.ts           # NEW - Build context-aware prompts

CoachMe/CoachMe/Core/Services/
└── MemoryMomentParser.swift        # NEW - Parse memory tags from text

CoachMe/CoachMe/Features/Chat/Views/
└── MemoryMomentText.swift          # NEW - Memory moment visual component
```

**Files to Modify:**
```
CoachMe/Supabase/supabase/functions/chat-stream/index.ts
  - Import and use context-loader.ts
  - Import and use prompt-builder.ts
  - Add memory moment detection in stream

CoachMe/CoachMe/Core/Services/ChatStreamService.swift
  - Add memory_moment event parsing
  - Update StreamEvent enum

CoachMe/CoachMe/Features/Chat/Views/StreamingText.swift
  - Integrate MemoryMomentParser
  - Render MemoryMomentText components

CoachMe/CoachMe/Features/Chat/Views/MessageBubble.swift
  - Render memory moments in completed messages
```

### Previous Story Learnings (Stories 2.1-2.3)

**Key Patterns Established:**
1. Use `@MainActor` for all services and ViewModels
2. Access Supabase via `AppEnvironment.shared.supabase`
3. Use `ContextProfileInsert` for minimal inserts (let server generate defaults)
4. Fetch-all-and-filter pattern for SwiftData queries (Swift 6 Sendable compliance)
5. Error messages are warm, first-person (per UX-11)
6. Use `.adaptiveGlassSheet()` for modal sheets
7. Add `.accessibilityAddTraits(.isModal)` for accessibility
8. VoiceOver labels on all interactive elements
9. Edge Functions use consistent `_shared/` helper pattern

**From Story 2.3 Code Review:**
- Use `.adaptiveGlass()` not `.background(Color.warmGray50)`
- All interactive elements need `.adaptiveInteractiveGlass()`
- Test on both iOS 18 and iOS 26 simulators

### Git Intelligence (Recent Commits)

```
f6da5f5 Fix message input text box colors for light mode
1aa8476 Redesign message input to match iMessage style
4f9cc33 Initial commit: Coach App iOS with Epic 1 complete
```

Recent work focused on chat UI polish. Story 2.4 modifies chat-stream backend and streaming UI components.

### Existing Code Context

**Current `chat-stream/index.ts` structure:**
- Uses `verifyAuth()` from `_shared/auth.ts`
- Uses `streamChatCompletion()` from `_shared/llm-client.ts`
- Uses `logUsage()` from `_shared/cost-tracker.ts`
- Has placeholder `buildSystemPrompt()` function that needs to be replaced

**Existing Models (from Story 2.1):**
```swift
// ContextProfile already has:
struct ContextProfile {
    var values: [ContextValue]      // User's core values
    var goals: [ContextGoal]        // User's goals
    var situation: LifeSituation    // Life situation context
    var extractedInsights: [ExtractedInsight]
}

// ContextValue, ContextGoal, LifeSituation are already defined
```

**Existing Edge Function Patterns:**
- All helpers in `_shared/` directory
- Export functions, import in `index.ts`
- Use Supabase client passed from main handler
- Async/await throughout

### Testing Requirements

**Unit Tests to Create:**

```typescript
// context-loader.test.ts
describe('loadUserContext', () => {
  it('loads profile with values, goals, situation')
  it('returns null for user without profile')
  it('includes only confirmed insights')
  it('handles database errors gracefully')
})

// prompt-builder.test.ts
describe('buildCoachingPrompt', () => {
  it('includes values in prompt')
  it('includes goals in prompt')
  it('includes situation in prompt')
  it('adds MEMORY tag instruction')
  it('handles null context gracefully')
  it('omits empty sections')
})
```

```swift
// CoachMeTests/Services/MemoryMomentParserTests.swift
final class MemoryMomentParserTests: XCTestCase {
    func testDetectsSingleMemoryMoment()
    func testDetectsMultipleMemoryMoments()
    func testStripsTagsFromCleanText()
    func testHandlesNoMemoryMoments()
    func testHandlesEmptyString()
}

// CoachMeTests/Features/Chat/MemoryMomentTextTests.swift
final class MemoryMomentTextTests: XCTestCase {
    func testAccessibilityLabel()
    func testRendersContent()
}
```

### Performance Considerations

**Context Loading Budget:**
- Target: <200ms for context load
- Parallel queries for profile and insights
- Cache context in memory for session duration

**Streaming Budget:**
- Target: <500ms time-to-first-token (includes context load)
- Memory moment detection happens client-side during stream
- No additional server round-trips for moment detection

### References

- [Source: epics.md#Story-2.4] - Original story requirements
- [Source: architecture.md#API-Communication-Patterns] - Edge Function patterns
- [Source: architecture.md#Frontend-Architecture] - MVVM + Repository pattern
- [Source: prd.md#FR13] - Context injection requirement
- [Source: ux-design-specification.md#UX-4] - Memory moment visual distinction
- [Source: ContextProfile.swift] - Existing context profile model
- [Source: chat-stream/index.ts] - Current chat streaming implementation
- [Source: 2-3-progressive-context-extraction.md] - Previous story patterns

## Dev Agent Record

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

N/A - Implementation completed without errors requiring debug investigation.

### Completion Notes List

1. **Context Loading**: Created context-loader.ts with single query pattern to load profile and insights together for performance.
2. **Prompt Building**: Created prompt-builder.ts with MEMORY_TAG_INSTRUCTION that instructs LLM to wrap context references in [MEMORY: ...] tags.
3. **Memory Moment Visual**: Used memoryPeach color (#FFEDD5) per UX-4 spec with sparkle icon indicator. Dark mode uses memoryIndicatorDark (warm gold) to distinguish from warning states.
4. **Accessibility**: Memory moments use "I remembered: {content}" accessibility label per UX warmth guidelines.
5. **Streaming Integration**: StreamEvent updated to include hasMemoryMoment flag. ChatViewModel tracks memory moment state.
6. **FlowLayout**: Created custom Layout for memory moment chips that wrap to next line when needed. Supports RTL languages.
7. **Test Structure**: Tests moved from `Tests/Unit/` to `CoachMeTests/` (standard Xcode structure).

### Code Review Fixes Applied

The following issues were identified and fixed during code review:

**High Priority:**
- Added context-loader.test.ts with comprehensive unit tests (Tasks 8.1-8.2 were missing)
- Replaced fatalError() with graceful error handling in ChatStreamService initialization

**Medium Priority:**
- Improved MemoryMomentTextTests accessibility verification
- Fixed prompt-builder.test.ts to use correct type structure from context-loader.ts
- Added RTL language support to FlowLayout
- Changed dark mode memory indicator from amber to memoryIndicatorDark (distinct from warning)

**Low Priority:**
- Documented currentResponseHasMemoryMoments property for future use
- Fixed findMomentRanges to find all occurrences (not just first)

### File List

**New Files Created:**
- `CoachMe/Supabase/supabase/functions/_shared/context-loader.ts` - Loads user context from DB
- `CoachMe/Supabase/supabase/functions/_shared/context-loader.test.ts` - Unit tests for context loader
- `CoachMe/Supabase/supabase/functions/_shared/prompt-builder.ts` - Builds context-aware prompts
- `CoachMe/Supabase/supabase/functions/_shared/prompt-builder.test.ts` - Unit tests for prompt builder
- `CoachMe/CoachMe/Core/Services/MemoryMomentParser.swift` - Parses [MEMORY: ...] tags
- `CoachMe/CoachMe/Features/Chat/Views/MemoryMomentText.swift` - Memory moment visual component
- `CoachMe/CoachMeTests/MemoryMomentParserTests.swift` - Unit tests for parser
- `CoachMe/CoachMeTests/MemoryMomentTextTests.swift` - Unit tests for visual component

**Modified Files:**
- `CoachMe/Supabase/supabase/functions/chat-stream/index.ts` - Added context loading and memory_moment flag
- `CoachMe/CoachMe/Core/UI/Theme/Colors.swift` - Added memoryPeach and memoryIndicator colors
- `CoachMe/CoachMe/Features/Chat/Views/StreamingText.swift` - Memory moment detection during streaming
- `CoachMe/CoachMe/Features/Chat/Views/MessageBubble.swift` - Memory moment rendering in completed messages
- `CoachMe/CoachMe/Core/Services/ChatStreamService.swift` - StreamEvent updated with hasMemoryMoment
- `CoachMe/CoachMe/Features/Chat/ViewModels/ChatViewModel.swift` - Memory moment state tracking
- `CoachMe/CoachMeTests/ChatStreamServiceTests.swift` - Updated tests for new StreamEvent signature
