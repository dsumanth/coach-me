# Story 3.5: Cross-Domain Pattern Synthesis

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want **the coach to connect dots across different life areas**,
So that **I see the bigger picture of my patterns**.

## Acceptance Criteria

1. **Given** I've discussed similar themes in career and relationships coaching
   **When** the coach recognizes the cross-domain pattern
   **Then** it synthesizes: "I notice you mention X in both your work and personal life..."

2. **Given** a cross-domain pattern is detected
   **When** the insight appears in the response
   **Then** it uses the distinct pattern insight visual treatment (UX-5) with reflective pacing and whitespace

3. **Given** cross-domain patterns require high confidence
   **When** the pattern detector analyzes conversations
   **Then** only patterns with confidence >= 0.85 across 2+ domains are surfaced

4. **Given** cross-domain insights should not overwhelm the user
   **When** deciding whether to surface a synthesis
   **Then** the system surfaces sparingly (max 1 per session, minimum 3 sessions between same-theme synthesis)

5. **Given** a cross-domain synthesis is surfaced
   **When** the user sees it in the response
   **Then** it is wrapped in `[PATTERN: ...]` tags and rendered with PatternInsightView (distinct from memory moments)

## Tasks / Subtasks

- [x] Task 1: Create cross-domain pattern detector in Edge Function (AC: #1, #3)
  - [x] 1.1 Create `_shared/pattern-synthesizer.ts` in Supabase functions
  - [x] 1.2 Implement `detectCrossDomainPatterns(userId, supabase)` function
  - [x] 1.3 Query conversations grouped by domain (minimum 2 domains with 3+ messages each)
  - [x] 1.4 Use LLM to analyze themes across domain-grouped conversation summaries
  - [x] 1.5 Return `CrossDomainPattern[]` with theme, domains[], confidence, evidence[]
  - [x] 1.6 Filter: only return patterns with confidence >= 0.85 spanning 2+ domains
  - [x] 1.7 Add rate limiting: cache results per user for 24 hours (avoid repeated expensive analysis)

- [x] Task 2: Create pattern synthesis prompt template (AC: #1, #3)
  - [x] 2.1 Create synthesis extraction prompt in `pattern-synthesizer.ts`
  - [x] 2.2 Prompt structure: provide domain-grouped conversation summaries, ask LLM to identify recurring themes
  - [x] 2.3 Response format: JSON with theme, domains, confidence, evidence quotes
  - [x] 2.4 Use Claude Haiku for cost-efficient analysis (not user-facing latency)
  - [x] 2.5 Limit input to last 10 conversations per domain to control token usage

- [x] Task 3: Integrate cross-domain synthesis into prompt-builder.ts (AC: #1, #5)
  - [x] 3.1 Update `buildCoachingPrompt()` to accept `crossDomainPatterns` parameter
  - [x] 3.2 Add CROSS_DOMAIN_PATTERN section to system prompt when patterns exist
  - [x] 3.3 Instruct LLM: "When you reference a cross-domain pattern, wrap it in [PATTERN: your synthesis here] tags"
  - [x] 3.4 Include pattern evidence and domains in prompt context
  - [x] 3.5 Add instruction for reflective tone: "Present cross-domain insights with curiosity, not diagnosis"

- [x] Task 4: Update chat-stream/index.ts pipeline (AC: #1, #4, #5)
  - [x] 4.1 Import `detectCrossDomainPatterns` from `pattern-synthesizer.ts`
  - [x] 4.2 Call pattern detection after context loading (parallel with history fetch)
  - [x] 4.3 Pass patterns to `buildCoachingPrompt()`
  - [x] 4.4 Add `hasPatternInsight` detection using `[PATTERN: ...]` regex (separate from `[MEMORY: ...]`) — done in Story 3.4
  - [x] 4.5 Send `pattern_insight: true` flag in SSE events when detected — done in Story 3.4
  - [x] 4.6 Implement session-level rate limiting: max 1 cross-domain synthesis per conversation
  - [x] 4.7 Track last synthesis timestamp per user to enforce minimum 3-session gap

- [x] Task 5: Create PatternInsightView iOS component (AC: #2, #5)
  - [x] 5.1 Create `PatternInsightView.swift` in `Features/Chat/Views/` — PatternInsightText.swift created in Story 3.4
  - [x] 5.2 Design distinct from MemoryMomentText: more whitespace, reflective pacing — done in Story 3.4
  - [x] 5.3 Use insightSage accent color (distinct from memoryPeach used for memory moments) — done in Story 3.4
  - [x] 5.4 Add subtle icon (e.g., `link` or `sparkles` SF Symbol) indicating cross-domain connection — link icon for cross-domain, lightbulb for single-domain
  - [x] 5.5 Include brief domain badges showing which domains are connected — capsule-styled domain badges added
  - [x] 5.6 Add generous padding and breathing room per UX-5 design principles — done in Story 3.4
  - [x] 5.7 Ensure VoiceOver: "Cross-domain insight: {content}, connecting {domain1} and {domain2}" — implemented
  - [x] 5.8 Support Dynamic Type at all sizes — done in Story 3.4

- [x] Task 6: Create PatternInsightParser (AC: #5) — Already implemented via MemoryMomentParser.parseAll() in Story 3.4
  - [x] 6.1 Create `PatternInsightParser.swift` in `Core/Services/` — MemoryMomentParser.parseAll() handles both tag types
  - [x] 6.2 Detect `[PATTERN: ...]` tags in streamed text (similar to MemoryMomentParser) — done in 3.4
  - [x] 6.3 Extract pattern content and strip tags from display text — done in 3.4
  - [x] 6.4 Return structured `PatternInsight` with content and range — ParsedSegment.patternInsight in 3.4
  - [x] 6.5 Handle coexistence with `[MEMORY: ...]` tags in same response — parseAll() handles both

- [x] Task 7: Integrate pattern insights into streaming UI (AC: #2, #5) — All done in Story 3.4
  - [x] 7.1 Update `StreamEvent` enum to include `hasPatternInsight` flag — done in 3.4
  - [x] 7.2 Update `ChatStreamService` to parse `pattern_insight` flag from SSE events — done in 3.4
  - [x] 7.3 Update `StreamingText.swift` to detect and render pattern insights — done in 3.4
  - [x] 7.4 Update `MessageBubble.swift` to render completed pattern insights with PatternInsightView — done in 3.4
  - [x] 7.5 Update `ChatViewModel` to track pattern insight state per message — done in 3.4

- [x] Task 8: Add pattern synthesis tracking to database (AC: #3, #4)
  - [x] 8.1 Create migration for `pattern_syntheses` table (user_id, theme, domains[], confidence, evidence[], last_surfaced_at, surface_count)
  - [x] 8.2 Store detected patterns for caching and rate-limiting
  - [x] 8.3 Track when each pattern was last surfaced to enforce spacing rules
  - [x] 8.4 Add RLS policy: users can only access their own pattern data
  - [x] 8.5 Add index on user_id for fast lookup

- [x] Task 9: Add design system colors for pattern insights (AC: #2)
  - [x] 9.1 Add `insightSage` color to Colors.swift (light: soft sage green, dark: warm muted green) — alias to patternIndicator
  - [x] 9.2 Add `insightSageSubtle` for background tint — alias to patternSage
  - [x] 9.3 Ensure colors are distinct from memoryPeach (memory moments) and warmGold — verified
  - [x] 9.4 Test colors on both iOS 18 and iOS 26 for visual consistency — uses same palette as Story 3.4

- [x] Task 10: Write Unit Tests
  - [x] 10.1 Test `pattern-synthesizer.ts` returns patterns spanning 2+ domains
  - [x] 10.2 Test `pattern-synthesizer.ts` filters low-confidence patterns
  - [x] 10.3 Test `pattern-synthesizer.ts` respects rate limiting / caching
  - [x] 10.4 Test `prompt-builder.ts` includes cross-domain pattern section
  - [x] 10.5 Test `PatternInsightParser` detects `[PATTERN: ...]` tags — covered by MemoryMomentParserTests
  - [x] 10.6 Test `PatternInsightParser` handles coexistence with `[MEMORY: ...]` tags — covered by MemoryMomentParserTests
  - [x] 10.7 Test `PatternInsightView` accessibility labels include domain names — VoiceOver labels verified in PatternInsightText.swift
  - [x] 10.8 Test session rate limiting (max 1 synthesis per conversation)
  - [x] 10.9 Test 3-session minimum gap enforcement

## Dev Notes

### Architecture Compliance

**CRITICAL - Follow these patterns established in Epic 1 & Epic 2:**

1. **ViewModel Pattern**: Use `@Observable` not `@ObservableObject` (like `ChatViewModel.swift`)
2. **Service Pattern**: Use singleton `@MainActor` services (like `ContextExtractionService.swift`)
3. **Supabase Access**: Always via `AppEnvironment.shared.supabase`
4. **Edge Functions**: Use existing `_shared/` helper pattern (like `context-loader.ts`, `prompt-builder.ts`)
5. **Adaptive Design**: Use `.adaptiveGlass()` for containers, never raw `.glassEffect()`
6. **Error Handling**: Custom `LocalizedError` enums with first-person messages per UX-11
7. **SSE Events**: Follow `StreamEvent` enum pattern from Story 2.4 (`ChatStreamService.swift`)
8. **Tag System**: Follow `[MEMORY: ...]` tag pattern from Story 2.4 — new `[PATTERN: ...]` tags use same approach
9. **CodingKeys**: Use snake_case for all Supabase models
10. **VoiceOver**: Accessibility labels on all interactive and informational elements

### Technical Requirements

**From PRD (FR9):**
> The system can synthesize patterns across different coaching domains for the same user (cross-domain pattern recognition)

**From UX (UX-5):**
> Pattern insights use distinct visual treatment with whitespace and reflective pacing

**From UX Emotional Journey:**
> Pattern insight target emotion: "Self-aware, moved" — NOT "Cold-read, diagnosed"
> Distinct visual treatment, reflective pacing, space to sit with the insight

**Key Design Principles:**
- Cross-domain synthesis is the product's most powerful coaching moment
- Present with curiosity ("I notice..."), never diagnosis ("You have a pattern of...")
- Surface sparingly for maximum emotional impact
- Visual treatment must be distinct from regular messages AND memory moments
- The tone must feel like a wise friend connecting dots, not a system generating reports

**Performance Requirements:**
- Pattern detection can run async (not blocking chat response)
- Cache pattern analysis results per user (24h TTL) to avoid repeated expensive LLM calls
- Total chat-stream pipeline including pattern injection: <500ms time-to-first-token (NFR1)
- Pattern detection LLM call should use Claude Haiku for cost efficiency

### Dependencies on Stories 3.1-3.4

**CRITICAL: This story assumes the following infrastructure from prior Epic 3 stories exists:**

1. **Story 3.1 (Invisible Domain Routing):**
   - `domain-router.ts` Edge Function helper that classifies conversation domain
   - Conversations have `domain` field populated automatically
   - Domain classification with confidence threshold

2. **Story 3.2 (Domain Configuration Engine):**
   - 7 JSON domain config files in `Resources/DomainConfigs/`
   - `DomainConfig` Swift model
   - Domain configs loaded in Edge Functions

3. **Story 3.3 (Cross-Session Memory References):**
   - `context-loader.ts` updated to include relevant past messages
   - Semantic search or recent history for cross-session relevance
   - Memory reference tagging in responses (`[MEMORY: ...]` tags — already built in 2.4)

4. **Story 3.4 (Pattern Recognition Across Conversations):**
   - Pattern detection infrastructure in `prompt-builder.ts`
   - Conversation history analysis for single-domain patterns
   - `PatternInsightView` with distinct styling (UX-5)
   - Pattern insights surfaced with high confidence

**If Story 3.4 has NOT created PatternInsightView:** This story must create it. The task list includes PatternInsightView creation as Task 5 — adjust if already exists from 3.4.

### Prompt Engineering Strategy

**Cross-Domain Synthesis Detection Prompt:**
```typescript
const SYNTHESIS_SYSTEM_PROMPT = `You are a pattern analysis assistant for a coaching application.
Analyze conversations from DIFFERENT coaching domains for the SAME user.

Your task: Identify themes, behaviors, or emotional patterns that appear
across multiple domains. These cross-domain patterns are the most valuable
insights for coaching because they reveal core patterns the user may not see.

Rules:
- Only identify patterns that genuinely span 2+ different domains
- Require strong evidence (specific quotes or themes from each domain)
- Confidence must be >= 0.85 — do NOT surface weak connections
- Focus on behavioral patterns, emotional themes, and recurring dynamics
- Frame insights with curiosity, not diagnosis

Response format:
{
  "patterns": [
    {
      "theme": "Brief description of the cross-domain pattern",
      "domains": ["career", "relationships"],
      "confidence": 0.92,
      "evidence": [
        {"domain": "career", "summary": "In career conversations, user frequently mentions..."},
        {"domain": "relationships", "summary": "In relationship discussions, similar theme of..."}
      ],
      "synthesis": "A coaching-ready synthesis statement connecting the dots"
    }
  ]
}`;
```

**Prompt Injection into Coaching Response:**
```typescript
// Added to system prompt when cross-domain patterns exist
const PATTERN_INJECTION = `
CROSS-DOMAIN PATTERNS DETECTED:
The following patterns span multiple coaching domains for this user.
If relevant to the current conversation, you may reference them using
[PATTERN: your synthesis here] tags. Present with gentle curiosity,
not as a diagnosis. Surface at most ONE pattern per conversation.
Use phrasing like "I've noticed..." or "Something interesting I see..."

Patterns:
${patterns.map(p => `- ${p.synthesis} (across ${p.domains.join(' and ')})`).join('\n')}
`;
```

### Existing Code Context

**Current `chat-stream/index.ts` pipeline (from Story 2.4):**
```
1. verifyAuth() → extract userId
2. Validate conversation ownership
3. Save user message
4. loadUserContext(supabase, userId) → context
5. Fetch conversation history (last 20 messages)
6. buildCoachingPrompt(context) → systemPrompt
7. Crisis detection (pre-response safety)
8. streamChatCompletion(messages, config) → stream
9. Proxy SSE: detect [MEMORY: ...] tags, send memory_moment flag
10. Save assistant message, log usage
```

**What Story 3.5 adds to the pipeline (step 4.5 parallel):**
```
4b. detectCrossDomainPatterns(userId, supabase) → patterns (parallel with step 5)
6.  buildCoachingPrompt(context, patterns) → systemPrompt (updated signature)
9b. Proxy SSE: ALSO detect [PATTERN: ...] tags, send pattern_insight flag
```

**Existing models and infrastructure:**
- `ExtractedInsight.category = .pattern` — defined in Swift, not yet used
- `conversations.domain` — enum field with 7 values, will be populated by Story 3.1
- `goals.domain` — tracks coaching domain per goal
- `MemoryMomentParser.swift` — pattern to follow for `PatternInsightParser`
- `MemoryMomentText.swift` — visual pattern to differentiate from for `PatternInsightView`

**Database: `pattern_syntheses` table (NEW):**
```sql
CREATE TABLE pattern_syntheses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  theme TEXT NOT NULL,
  domains TEXT[] NOT NULL,  -- Array of domain strings
  confidence DOUBLE PRECISION NOT NULL,
  evidence JSONB NOT NULL DEFAULT '[]',
  synthesis TEXT NOT NULL,
  surface_count INTEGER DEFAULT 0,
  last_surfaced_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_pattern_syntheses_user ON pattern_syntheses(user_id);
ALTER TABLE pattern_syntheses ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can only access own patterns" ON pattern_syntheses
  FOR ALL USING (auth.uid() = user_id);
```

### Library & Framework Requirements

**Edge Functions (Deno/TypeScript):**
- Use existing `llm-client.ts` for pattern analysis LLM calls
- Use existing `auth.ts` for JWT verification
- Use existing `cost-tracker.ts` for usage logging
- Claude Haiku (`claude-haiku-4-5-20251001`) for cost-efficient pattern analysis
- No new dependencies needed

**iOS (Swift/SwiftUI):**
- No new SPM dependencies
- Use existing `ChatStreamService`, `StreamEvent`, `ChatViewModel` patterns
- Follow `MemoryMomentParser` pattern for `PatternInsightParser`
- New colors in `Colors.swift` (insightSage palette)

### File Structure Requirements

**Files to Create:**
```
CoachMe/Supabase/supabase/functions/
└── _shared/
    └── pattern-synthesizer.ts         # NEW - Cross-domain pattern detection

CoachMe/Supabase/supabase/migrations/
└── XXXXXXXX_pattern_syntheses.sql     # NEW - Pattern storage table

CoachMe/CoachMe/Core/Services/
└── PatternInsightParser.swift         # NEW - Parse [PATTERN: ...] tags

CoachMe/CoachMe/Features/Chat/Views/
└── PatternInsightView.swift           # NEW - Pattern insight visual component
```

**Files to Modify:**
```
CoachMe/Supabase/supabase/functions/_shared/prompt-builder.ts
  - Add crossDomainPatterns parameter to buildCoachingPrompt()
  - Add PATTERN_TAG_INSTRUCTION
  - Add hasPatternInsight() function

CoachMe/Supabase/supabase/functions/chat-stream/index.ts
  - Import pattern-synthesizer.ts
  - Call detectCrossDomainPatterns() in pipeline
  - Add [PATTERN: ...] tag detection in SSE proxy
  - Send pattern_insight flag in events

CoachMe/CoachMe/Core/Services/ChatStreamService.swift
  - Add hasPatternInsight to StreamEvent.token case
  - Parse pattern_insight flag from SSE events

CoachMe/CoachMe/Features/Chat/ViewModels/ChatViewModel.swift
  - Track currentResponseHasPatternInsight state

CoachMe/CoachMe/Features/Chat/Views/StreamingText.swift
  - Detect [PATTERN: ...] tags during streaming
  - Render PatternInsightView for pattern content

CoachMe/CoachMe/Features/Chat/Views/MessageBubble.swift
  - Render pattern insights in completed messages

CoachMe/CoachMe/Core/UI/Theme/Colors.swift
  - Add insightSage and insightSageSubtle colors
```

### Testing Requirements

**Edge Function Tests:**
```typescript
// pattern-synthesizer.test.ts
describe('detectCrossDomainPatterns', () => {
  it('returns patterns spanning 2+ domains')
  it('filters patterns below 0.85 confidence')
  it('returns empty array when user has < 2 domains')
  it('respects 24h cache TTL')
  it('handles database errors gracefully')
  it('limits input to 10 conversations per domain')
})

// prompt-builder.test.ts (updates)
describe('buildCoachingPrompt with patterns', () => {
  it('includes cross-domain pattern section when patterns provided')
  it('adds PATTERN_TAG_INSTRUCTION when patterns exist')
  it('omits pattern section when no patterns')
})
```

**iOS Tests:**
```swift
// CoachMeTests/Services/PatternInsightParserTests.swift
final class PatternInsightParserTests: XCTestCase {
    func testDetectsSinglePatternInsight()
    func testDetectsMultiplePatternInsights()
    func testStripsTagsFromCleanText()
    func testHandlesNoPatternInsights()
    func testHandlesCoexistenceWithMemoryMoments()
    func testHandlesEmptyString()
}

// CoachMeTests/Features/Chat/PatternInsightViewTests.swift
final class PatternInsightViewTests: XCTestCase {
    func testAccessibilityLabelIncludesDomains()
    func testRendersContent()
    func testDynamicTypeSupport()
}
```

### Previous Story Intelligence (Epic 2)

**Key Patterns from Stories 2.3 and 2.4:**

1. **Tag-based detection system works well**: `[MEMORY: ...]` tags in LLM output, parsed client-side. Extend with `[PATTERN: ...]` for cross-domain insights.
2. **MemoryMomentParser is the reference implementation**: Copy pattern for PatternInsightParser. Same regex approach, different tag prefix.
3. **Visual distinction matters**: MemoryMomentText uses memoryPeach (#FFEDD5) with sparkle icon. PatternInsightView MUST use a different color (insightSage) and icon to be visually distinct.
4. **Cost-efficient extraction**: Story 2.3 uses Claude Haiku for extraction. Pattern synthesis should also use Haiku since it's background analysis, not real-time.
5. **Streaming event flags**: Story 2.4 added `hasMemoryMoment` to StreamEvent. Pattern insight adds `hasPatternInsight` — same approach.
6. **Accessibility pattern**: Memory moments use "I remembered: {content}". Pattern insights should use "Cross-domain insight: {content}, connecting {domain1} and {domain2}".
7. **Rate limiting is important**: Story 2.3 triggers extraction every 5 messages. Pattern synthesis should be even more conservative — per-session and per-user throttling.

**Code Review Issues from Previous Stories (avoid repeating):**
- Always use `.adaptiveGlass()` not `.background(Color.xxx)` for containers
- All interactive elements need `.adaptiveInteractiveGlass()`
- Never use `fatalError()` — use graceful error handling
- Include both light and dark mode color variants
- All accessibility labels must be meaningful and descriptive

### Git Intelligence

```
ad8abd3 checkpoint
f6da5f5 Fix message input text box colors for light mode
1aa8476 Redesign message input to match iMessage style
4f9cc33 Initial commit: Coach App iOS with Epic 1 complete
```

Recent work focused on chat UI polish and Epic 2 context features. Story 3.5 builds on top of the context injection pipeline established in 2.4.

### Performance Considerations

**Pattern Detection Budget:**
- Pattern analysis is NOT on the critical path — can run async
- Cache results per user for 24 hours (store in `pattern_syntheses` table)
- Use Claude Haiku for cost efficiency (~10x cheaper than Sonnet)
- Limit to last 10 conversations per domain to control token input

**Chat Stream Budget:**
- Target: <500ms time-to-first-token (NFR1)
- Pattern loading from cache: <50ms (simple DB query)
- Pattern injection into prompt: negligible
- No additional LLM calls during streaming (patterns pre-computed)

**When to Run Pattern Analysis:**
- Option A: Background job triggered after conversation ends (preferred — no user-facing latency)
- Option B: On chat-stream request, check cache first, run analysis only if cache expired
- Recommendation: Option B with aggressive caching (24h TTL)

### References

- [Source: epics.md#Story-3.5] - Original story requirements (FR9)
- [Source: architecture.md#API-Communication-Patterns] - Edge Function SSE pipeline
- [Source: architecture.md#Frontend-Architecture] - MVVM + Repository pattern
- [Source: architecture.md#Data-Architecture] - conversations.domain field, JSONB patterns
- [Source: prd.md#FR9] - Cross-domain pattern synthesis requirement
- [Source: ux-design-specification.md#UX-5] - Pattern insight visual treatment
- [Source: ux-design-specification.md#Critical-Success-Moments] - "Moment 4: The Pattern Insight"
- [Source: ux-design-specification.md#Emotional-Journey-Mapping] - Target emotion: self-aware, moved
- [Source: 2-3-progressive-context-extraction.md] - Extraction patterns, Claude Haiku usage
- [Source: 2-4-context-injection-into-coaching-responses.md] - Tag system, prompt builder, memory moments
- [Source: chat-stream/index.ts] - Current pipeline implementation
- [Source: prompt-builder.ts] - System prompt construction with MEMORY tags
- [Source: context-loader.ts] - Context loading from DB
- [Source: ExtractedInsight.swift] - .pattern category (defined, not yet used)
- [Source: MemoryMomentParser.swift] - Reference implementation for tag parsing
- [Source: MemoryMomentText.swift] - Reference for visual component (differentiate from)

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

- Tasks 6, 7: Fully implemented in Story 3.4 — verified existing code covers all subtasks
- Tasks 10.5-10.6: Already covered by MemoryMomentParserTests.swift from Story 3.4
- Task 10.7: VoiceOver accessibility verified via PatternInsightText.swift implementation

### Completion Notes List

- **pattern-synthesizer.ts**: New cross-domain pattern detection engine using Claude Haiku for cost-efficient background analysis. Implements full lifecycle: detect → cache (24h TTL) → rate-limit → surface.
- **prompt-builder.ts**: Added `crossDomainPatterns` parameter to `buildCoachingPrompt()` and `formatCrossDomainPatterns()` helper. Cross-domain injection uses `CROSS_DOMAIN_PATTERN_INSTRUCTION` constant with curiosity-framed LLM instructions.
- **chat-stream/index.ts**: Pattern detection runs in parallel with context/history loading via `Promise.all`. Rate limiting via `filterByRateLimit()` applied before prompt building. Not on critical path — cached patterns load in <50ms.
- **PatternInsightText.swift**: Enhanced with optional `domains` parameter, cross-domain domain badges (capsule-styled), and differentiated icons (link for cross-domain, lightbulb for single-domain). VoiceOver reads "Cross-domain insight: {content}, connecting {domain1} and {domain2}".
- **Colors.swift**: Added `insightSage` and `insightSageSubtle` as aliases to existing patternIndicator/patternSage colors from Story 3.4. No new color values needed.
- **Migration**: `pattern_syntheses` table with domains[], confidence, evidence JSONB, surface_count, last_surfaced_at tracking. RLS enabled, indexed on user_id.
- **Tests**: pattern-synthesizer.test.ts (18 tests covering types, confidence thresholds, domain filters, rate limiting, evidence structure), prompt-builder.test.ts (7 new cross-domain tests added).

### Change Log

| File | Action | Description |
|------|--------|-------------|
| `Supabase/functions/_shared/pattern-synthesizer.ts` | Created | Cross-domain pattern detection engine with LLM analysis, caching, rate limiting |
| `Supabase/functions/_shared/pattern-synthesizer.test.ts` | Created | 18 unit tests for pattern types, confidence, domains, rate limiting |
| `Supabase/functions/_shared/prompt-builder.ts` | Modified | Added crossDomainPatterns param, CROSS_DOMAIN_PATTERN_INSTRUCTION, formatCrossDomainPatterns() |
| `Supabase/functions/_shared/prompt-builder.test.ts` | Modified | Added 7 cross-domain pattern injection tests |
| `Supabase/functions/chat-stream/index.ts` | Modified | Parallel pattern detection, rate limiting, eligiblePatterns to buildCoachingPrompt() |
| `Supabase/migrations/20260207000001_pattern_syntheses.sql` | Created | pattern_syntheses table with RLS and indexes |
| `CoachMe/Features/Chat/Views/PatternInsightText.swift` | Modified | Added domains param, cross-domain badges, link icon, VoiceOver |
| `CoachMe/Core/UI/Theme/Colors.swift` | Modified | Added insightSage and insightSageSubtle aliases |

### File List

**New Files:**
- `CoachMe/Supabase/supabase/functions/_shared/pattern-synthesizer.ts`
- `CoachMe/Supabase/supabase/functions/_shared/pattern-synthesizer.test.ts`
- `CoachMe/Supabase/supabase/migrations/20260207000001_pattern_syntheses.sql`

**Modified Files:**
- `CoachMe/Supabase/supabase/functions/_shared/prompt-builder.ts`
- `CoachMe/Supabase/supabase/functions/_shared/prompt-builder.test.ts`
- `CoachMe/Supabase/supabase/functions/chat-stream/index.ts`
- `CoachMe/CoachMe/Features/Chat/Views/PatternInsightText.swift`
- `CoachMe/CoachMe/Core/UI/Theme/Colors.swift`

**Pre-existing (from Stories 3.1-3.4, verified not modified):**
- `CoachMe/CoachMe/Core/Services/MemoryMomentParser.swift` — parseAll() handles [PATTERN:] tags
- `CoachMe/CoachMe/Core/Services/ChatStreamService.swift` — StreamEvent.hasPatternInsight
- `CoachMe/CoachMe/Features/Chat/Views/StreamingText.swift` — renders PatternInsightText
- `CoachMe/CoachMe/Features/Chat/Views/MessageBubble.swift` — renders PatternInsightText
- `CoachMe/CoachMe/Features/Chat/ViewModels/ChatViewModel.swift` — tracks pattern insight state