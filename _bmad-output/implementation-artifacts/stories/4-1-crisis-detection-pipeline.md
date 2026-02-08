# Story 4.1: Crisis Detection Pipeline

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **system**,
I want **to detect crisis indicators in user messages before generating a coaching response**,
So that **users in distress get appropriate resources immediately instead of standard coaching**.

## Acceptance Criteria

1. **Given** a user message arrives at the Edge Function, **When** it contains crisis indicators (self-harm, suicidal ideation, abuse, severe distress), **Then** the crisis detection layer identifies it with a confidence score before the LLM generates a response.

2. **Given** crisis indicators are detected with high confidence, **When** the chat-stream pipeline processes the message, **Then** the response includes a `crisis_detected: true` flag in the SSE stream metadata AND the LLM system prompt is augmented with crisis-specific instructions to produce an empathetic acknowledgment + resource referral instead of standard coaching.

3. **Given** crisis indicators are detected, **When** the assistant response is streamed back, **Then** the response tone is empathetic ("I hear you, and what you're feeling sounds really heavy..."), sets honest boundaries ("This is beyond what I can help with as a coaching tool"), and references crisis resources (988 Lifeline, Crisis Text Line).

4. **Given** a message has ambiguous crisis indicators (low confidence), **When** the detection layer is uncertain, **Then** the system errs on the side of caution and flags it as crisis (false positive is safer than false negative).

5. **Given** the iOS app receives an SSE stream with `crisis_detected: true`, **When** the ChatViewModel processes the event, **Then** it sets `currentResponseHasCrisisFlag = true` so the UI layer (Story 4.2) can present crisis resources.

6. **Given** crisis detection runs, **When** it evaluates a user message, **Then** it completes within 200ms to stay within the NFR performance budget and does not add noticeable latency to the chat pipeline.

7. **Given** the crisis detection service encounters an error, **When** it fails to analyze the message, **Then** the chat pipeline continues with normal coaching (fail-open) — never block the user from receiving a response due to a detection error.

## Tasks / Subtasks

- [ ] Task 1: Create `crisis-detector.ts` Edge Function helper (AC: #1, #4, #6, #7)
  - [ ] 1.1 Create `CoachMe/Supabase/supabase/functions/_shared/crisis-detector.ts`
  - [ ] 1.2 Define `CrisisDetectionResult` interface: `{ crisisDetected: boolean; confidence: number; indicators: string[]; category: CrisisCategory | null }`
  - [ ] 1.3 Define `CrisisCategory` type: `'self_harm' | 'suicidal_ideation' | 'abuse' | 'severe_distress' | 'other'`
  - [ ] 1.4 Implement `detectCrisis(message: string, recentMessages?: { role: string; content: string }[]): Promise<CrisisDetectionResult>` as the main export
  - [ ] 1.5 Implement keyword-based first pass: scan for high-signal crisis keywords/phrases (e.g., "kill myself", "end it all", "want to die", "self-harm", "hurting myself", "suicide", "no point in living", "better off dead", "can't go on"). Use a curated keyword list, NOT regex-only — include contextual phrases
  - [ ] 1.6 If keyword match found, set confidence >= 0.8 and return immediately (fast path, <10ms)
  - [ ] 1.7 If no keyword match but message tone is ambiguous (negative sentiment + hopelessness indicators), use a lightweight LLM classification call with a focused system prompt: "Classify whether this message indicates a crisis requiring professional intervention. Return JSON: { crisis: boolean, confidence: 0-1, category: string, reasoning: string }"
  - [ ] 1.8 LLM classification should use a fast model (e.g., `claude-haiku-4-5-20251001`) for speed — target <150ms
  - [ ] 1.9 Threshold: `confidence >= 0.6` → `crisisDetected = true` (err on side of caution, AC #4)
  - [ ] 1.10 Wrap all detection in try/catch — on error, return `{ crisisDetected: false, confidence: 0, indicators: [], category: null }` (fail-open, AC #7)
  - [ ] 1.11 Include recent messages (last 2-3) in context for detection — a single message like "I don't care anymore" is ambiguous alone but clear in context of escalating distress
  - [ ] 1.12 Export `CRISIS_RESOURCES` constant: `{ lifeline: { name: '988 Suicide & Crisis Lifeline', phone: '988', text: null }, crisisText: { name: 'Crisis Text Line', phone: null, text: 'Text HOME to 741741' } }`

- [ ] Task 2: Create crisis-aware system prompt injection (AC: #2, #3)
  - [ ] 2.1 In `prompt-builder.ts`, add `buildCrisisPrompt(): string` function that returns a crisis-specific system prompt section
  - [ ] 2.2 Crisis prompt content: instruct the LLM to (a) acknowledge the user's pain empathetically, (b) state honestly that this is beyond coaching scope, (c) reference 988 Lifeline and Crisis Text Line by name, (d) leave the door open: "I'm here for coaching whenever you want to come back", (e) NEVER diagnose or use clinical language
  - [ ] 2.3 Update `buildCoachingPrompt()` signature to accept optional `crisisDetected: boolean` parameter
  - [ ] 2.4 When `crisisDetected === true`, prepend the crisis prompt section BEFORE the domain-specific content — crisis takes priority over domain routing
  - [ ] 2.5 When crisis is detected, still include user context (values, goals) — the response should feel personal, not generic (e.g., "I know [career goal] matters to you, and right now what you're feeling is more important")

- [ ] Task 3: Integrate crisis detection into chat-stream pipeline (AC: #1, #2, #6)
  - [ ] 3.1 In `chat-stream/index.ts`, import `detectCrisis` from `crisis-detector.ts`
  - [ ] 3.2 Add crisis detection call AFTER user message is saved but BEFORE the LLM call — insert between current line 74 (parallel data loading) and line 108 (domain routing)
  - [ ] 3.3 Run crisis detection in parallel with existing `loadUserContext()`, `loadRelevantHistory()`, `detectCrossDomainPatterns()` — add to `Promise.all()` to avoid adding latency
  - [ ] 3.4 Pass `crisisDetected` to `buildCoachingPrompt()` call (line 139)
  - [ ] 3.5 Add `crisis_detected: boolean` to token SSE events: `{ type: 'token', content, memory_moment, pattern_insight, crisis_detected }`
  - [ ] 3.6 Add `crisis_detected: boolean` to done SSE event: `{ type: 'done', message_id, usage, domain, crisis_detected }`
  - [ ] 3.7 Log crisis detection in usage tracking — add `crisis_detected: boolean` field to `logUsage()` call for monitoring
  - [ ] 3.8 If crisis detected AND LLM response doesn't contain empathetic acknowledgment, append a safety fallback message (defense in depth)

- [ ] Task 4: Update iOS `ChatStreamService` to handle crisis flag (AC: #5)
  - [ ] 4.1 In `ChatStreamService.swift`, add `crisisDetected` CodingKey: `case crisisDetected = "crisis_detected"`
  - [ ] 4.2 Update `StreamEvent.token` case to include `hasCrisisFlag: Bool` parameter: `.token(content: String, hasMemoryMoment: Bool, hasPatternInsight: Bool, hasCrisisFlag: Bool)`
  - [ ] 4.3 Parse `crisis_detected` from token events (default `false` for backward compatibility)
  - [ ] 4.4 Update `StreamEvent.done` case to include `crisisDetected: Bool` — not strictly needed for Story 4.1 but prevents a breaking change later when Story 4.2 needs it
  - [ ] 4.5 Update all `switch event` pattern matches in `ChatViewModel.swift` to handle the new tuple element

- [ ] Task 5: Update `ChatViewModel` to track crisis state (AC: #5)
  - [ ] 5.1 Add `var currentResponseHasCrisisFlag = false` observable property (matches `currentResponseHasMemoryMoments` pattern)
  - [ ] 5.2 In `sendMessage()`, reset `currentResponseHasCrisisFlag = false` at start
  - [ ] 5.3 In `sendMessage()` stream processing, when `hasCrisisFlag` is true on a token event, set `currentResponseHasCrisisFlag = true`
  - [ ] 5.4 Reset `currentResponseHasCrisisFlag` in `startNewConversation()` and `loadConversation(id:)`
  - [ ] 5.5 This property will be consumed by Story 4.2 (CrisisResourceSheet) — for now it's tracked but not displayed

- [ ] Task 6: Update `cost-tracker.ts` for crisis logging (AC: #7 monitoring)
  - [ ] 6.1 Add `crisisDetected?: boolean` to the `logUsage()` parameters interface
  - [ ] 6.2 Include `crisis_detected` in the usage_logs insert when provided
  - [ ] 6.3 If usage_logs table doesn't have `crisis_detected` column, add a Supabase migration: `ALTER TABLE usage_logs ADD COLUMN crisis_detected BOOLEAN DEFAULT false`

- [ ] Task 7: Write unit tests (AC: all)
  - [ ] 7.1 Test crisis-detector keyword match: message "I want to kill myself" → `crisisDetected: true, confidence >= 0.8`
  - [ ] 7.2 Test crisis-detector no match: message "How do I negotiate a raise?" → `crisisDetected: false`
  - [ ] 7.3 Test crisis-detector ambiguous: message "I don't see the point anymore" → LLM classification triggered
  - [ ] 7.4 Test crisis-detector error handling: mock LLM failure → `crisisDetected: false` (fail-open)
  - [ ] 7.5 Test `ChatStreamService.StreamEvent` decoding with `crisis_detected: true` field
  - [ ] 7.6 Test `ChatStreamService.StreamEvent` decoding without `crisis_detected` field (backward compat → defaults false)
  - [ ] 7.7 Test `ChatViewModel.currentResponseHasCrisisFlag` is set when token with crisis flag received
  - [ ] 7.8 Test `ChatViewModel.currentResponseHasCrisisFlag` is reset on `startNewConversation()`
  - [ ] 7.9 Test `buildCoachingPrompt()` with `crisisDetected: true` includes crisis-specific instructions

## Dev Notes

### Architecture Compliance

**CRITICAL — Follow these patterns established in Epics 1-3:**

1. **Edge Function Pattern**: All new Edge Function helpers go in `_shared/` — match `domain-router.ts`, `pattern-synthesizer.ts`, `context-loader.ts` patterns
2. **Pipeline Integration**: Add to existing `chat-stream/index.ts` parallel loading — match how `detectCrossDomainPatterns()` was added in Story 3.5
3. **SSE Event Extension**: Add new boolean fields to existing events — match how `memory_moment` (Story 2.4) and `pattern_insight` (Story 3.4) were added. DO NOT create new event types
4. **iOS ViewModel Pattern**: Use `@Observable` with `@MainActor`, track boolean flags — match `currentResponseHasMemoryMoments` and `currentResponseHasPatternInsights` exactly
5. **Supabase Access**: Edge Functions use service role from `verifyAuth()` — never create separate clients
6. **Error Handling**: Warm, first-person messages per UX-11 on the iOS side; fail-open on the Edge Function side
7. **Backward Compatibility**: New SSE fields default to `false` when absent — match how `memory_moment` was added with `decodeIfPresent`

### Technical Requirements

**From PRD (FR16):**
> The system can detect crisis indicators (self-harm, suicidal ideation, abuse) in user messages

**From Architecture (Chat Stream Pipeline — Step 7):**
```
7. Run crisis detection on user message (pre-response safety check)
```

**From Architecture (Project Structure):**
```
Core/Services/
├── ChatStreamService.swift    # SSE streaming client — UPDATE
Supabase/functions/_shared/
├── crisis-detector.ts         # Crisis detection — CREATE
├── prompt-builder.ts          # Prompt construction — UPDATE
```

**From Architecture (Data Flow — Critical Path):**
```
Edge Function pipeline:
├─ auth.ts → verify JWT
├─ context-loader.ts → load context + history (<200ms)
├─ domain-router.ts → classify domain (<100ms)
├─ crisis-detector.ts → safety check        ← THIS STORY
├─ prompt-builder.ts → construct full prompt ← MODIFY
├─ llm-client.ts → call LLM API (streaming)
└─ on complete: save message + log cost
```

### Crisis Detection Strategy

**Two-Tier Detection Model:**

```
User Message → Tier 1: Keyword Scan (<10ms)
                  ├── Match found? → crisis_detected = true (high confidence)
                  └── No match → Tier 2: Contextual Analysis
                                    ├── Recent messages show escalation? → LLM classify (<150ms)
                                    └── No concerning signals → crisis_detected = false
```

**Tier 1 — Keyword/Phrase Matching (Fast Path):**
High-signal phrases that are almost always crisis indicators:
- Direct self-harm: "kill myself", "hurt myself", "cutting myself", "self-harm"
- Suicidal ideation: "want to die", "better off dead", "end it all", "no reason to live", "can't go on"
- Severe distress: "going to hurt someone", "being abused", "help me please"

**Tier 2 — LLM Classification (Contextual Path):**
For ambiguous messages that don't trigger keyword matching:
- "I don't see the point anymore" — ambiguous alone, may be about a project or life
- "Nothing matters" — could be existential or conversational
- "I give up" — context-dependent
Use recent conversation history (last 2-3 messages) to determine if the message is escalating toward crisis.

**Threshold Calibration:**
- `>= 0.8` confidence: Clear crisis indicator (keyword match or strong LLM signal)
- `0.6 - 0.8` confidence: Probable crisis — treat as crisis (err on safety)
- `< 0.6` confidence: Not crisis — proceed with normal coaching
- **Design principle: False positives are acceptable; false negatives are not** (AC #4)

### Crisis Keyword List

```typescript
const CRISIS_KEYWORDS = [
  // Self-harm
  'kill myself', 'hurt myself', 'cutting myself', 'self-harm', 'self harm',
  'harming myself', 'injure myself',
  // Suicidal ideation
  'want to die', 'wanna die', 'better off dead', 'end it all', 'end my life',
  'no reason to live', 'no point in living', 'suicide', 'suicidal',
  "can't go on", 'rather be dead', 'wish i was dead', 'wish i were dead',
  'take my own life', 'don\'t want to be alive', 'don\'t want to live',
  // Abuse
  'being abused', 'he hits me', 'she hits me', 'they hit me',
  'sexual abuse', 'domestic violence', 'being hurt by',
  // Severe distress
  'going to hurt someone', 'want to hurt someone',
];
```

### LLM Classification Prompt

```typescript
const CRISIS_CLASSIFICATION_PROMPT = `You are a crisis detection system for an AI coaching app.
Analyze the user's message (and recent conversation context if provided) to determine if the user is experiencing a mental health crisis that requires professional intervention.

Crisis indicators include:
- Suicidal ideation or self-harm intent
- Abuse (physical, sexual, emotional) — being experienced or witnessed
- Severe psychological distress beyond normal stress/frustration
- Intent to harm others

Important:
- A user discussing career frustration, relationship problems, or general sadness is NOT a crisis
- A user who says "this job is killing me" is using a figure of speech, NOT a crisis
- Context matters: escalating desperation across messages IS a signal
- When uncertain, err toward flagging as crisis (safety first)

Return ONLY valid JSON:
{ "crisis": boolean, "confidence": 0.0-1.0, "category": "self_harm"|"suicidal_ideation"|"abuse"|"severe_distress"|"none", "reasoning": "brief explanation" }`;
```

### Crisis-Aware System Prompt Section

When crisis is detected, this section is prepended to the system prompt:

```typescript
const CRISIS_PROMPT = `
CRITICAL SAFETY OVERRIDE — Crisis indicators detected in user message.

Your response MUST follow this exact structure:
1. EMPATHETIC ACKNOWLEDGMENT: Start with warm, genuine empathy. Example: "I hear you, and what you're feeling sounds really heavy."
2. HONEST BOUNDARY: State clearly but gently: "I want to be honest with you — what you're describing is beyond what I can help with as a coaching tool. You deserve support from someone trained for exactly this."
3. PROFESSIONAL RESOURCES: Mention these by name:
   - 988 Suicide & Crisis Lifeline — call or text 988
   - Crisis Text Line — text HOME to 741741
4. DOOR STAYS OPEN: End with: "I'm here for coaching whenever you want to come back. You matter."

ABSOLUTE RULES:
- NEVER diagnose or use clinical terms
- NEVER minimize what they're feeling
- NEVER suggest they're overreacting
- NEVER continue standard coaching as if nothing happened
- NEVER say "I'm just an AI" — say "I'm a coaching tool"
- DO reference their personal context if available (e.g., their values, goals) to show you know them
- Keep response under 200 words — this is about connection, not length
`;
```

### Existing Code to Leverage — DO NOT RECREATE

**Pattern: Adding parallel detection (Story 3.5 model):**
```typescript
// chat-stream/index.ts — current line 70-74
const [userContext, conversationHistory, patternResult] = await Promise.all([
  loadUserContext(supabase, userId),
  loadRelevantHistory(supabase, userId, conversationId),
  detectCrossDomainPatterns(userId, supabase),
]);
// ADD crisis detection to this Promise.all():
const [userContext, conversationHistory, patternResult, crisisResult] = await Promise.all([
  loadUserContext(supabase, userId),
  loadRelevantHistory(supabase, userId, conversationId),
  detectCrossDomainPatterns(userId, supabase),
  detectCrisis(message, historyMessages.slice(-3)),  // Last 3 messages for context
]);
```

**Pattern: SSE event with boolean flags (Story 2.4 + 3.4 model):**
```typescript
// chat-stream/index.ts — current line 181-186
const event = `data: ${JSON.stringify({
  type: 'token',
  content: chunk.content,
  memory_moment: memoryMomentFound,
  pattern_insight: patternInsightFound,
  crisis_detected: crisisResult.crisisDetected,  // ADD this field
})}\n\n`;
```

**Pattern: iOS StreamEvent decoding (Story 2.4 + 3.4 model):**
```swift
// ChatStreamService.swift — current line 50-51
case memoryMoment = "memory_moment"
case patternInsight = "pattern_insight"
case crisisDetected = "crisis_detected"  // ADD this CodingKey

// Current line 63-68
case "token":
    let content = try container.decode(String.self, forKey: .content)
    let memoryMoment = try container.decodeIfPresent(Bool.self, forKey: .memoryMoment) ?? false
    let patternInsight = try container.decodeIfPresent(Bool.self, forKey: .patternInsight) ?? false
    let crisisDetected = try container.decodeIfPresent(Bool.self, forKey: .crisisDetected) ?? false  // ADD
    self = .token(content: content, hasMemoryMoment: memoryMoment, hasPatternInsight: patternInsight, hasCrisisFlag: crisisDetected)
```

**Pattern: ChatViewModel flag tracking (Story 2.4 model):**
```swift
// ChatViewModel.swift — matches existing memory moment / pattern insight pattern
var currentResponseHasCrisisFlag = false

// In sendMessage() stream processing:
case .token(let content, let hasMemoryMoment, let hasPatternInsight, let hasCrisisFlag):
    tokenBuffer?.addToken(content)
    if hasMemoryMoment { currentResponseHasMemoryMoments = true }
    if hasPatternInsight { currentResponseHasPatternInsights = true }
    if hasCrisisFlag { currentResponseHasCrisisFlag = true }
```

**llm-client.ts (for classification call):**
```typescript
// Use existing streamChatCompletion for main response
// For classification, use a non-streaming call with Haiku for speed
import { streamChatCompletion, type ChatMessage } from './llm-client.ts';
```

### Pipeline Integration Architecture

```
Current Pipeline (Stories 1.6 + 2.4 + 3.1 + 3.5):
─────────────────────────────────────────────────
1. verifyAuth(req)
2. Save user message to DB
3. Promise.all([loadUserContext, loadRelevantHistory, detectCrossDomainPatterns])
4. Load conversation history (last 20 messages)
5. determineDomain()
6. filterByRateLimit() for patterns
7. buildCoachingPrompt(context, domain, clarify, history, patterns)
8. streamChatCompletion(messages)
9. Save assistant message + log usage

Updated Pipeline (+ Story 4.1):
────────────────────────────────
1. verifyAuth(req)
2. Save user message to DB
3. Promise.all([loadUserContext, loadRelevantHistory, detectCrossDomainPatterns, detectCrisis])  ← MODIFIED
4. Load conversation history (last 20 messages)
5. determineDomain()
6. filterByRateLimit() for patterns
7. buildCoachingPrompt(context, domain, clarify, history, patterns, crisisDetected)             ← MODIFIED
8. streamChatCompletion(messages) — with crisis_detected in SSE events                          ← MODIFIED
9. Save assistant message + log usage (with crisis_detected flag)                                ← MODIFIED
```

**Note on ordering:** Crisis detection runs in parallel with data loading (step 3), not sequentially before it. This is critical for meeting the <200ms performance target. The crisis result is consumed in step 7 when building the prompt.

### Anti-Pattern Prevention

- **DO NOT block the pipeline** — crisis detection runs in parallel, never sequential. If detection fails, proceed with normal coaching (fail-open)
- **DO NOT create a separate Edge Function endpoint** — crisis detection is a helper in `_shared/`, called from within `chat-stream/index.ts`
- **DO NOT use regex-only for keyword matching** — use case-insensitive string includes for phrases. Regex misses variations and is harder to maintain
- **DO NOT create a new SSE event type** (e.g., `type: 'crisis'`) — add `crisis_detected` boolean to existing `token` and `done` events, matching the `memory_moment` pattern
- **DO NOT store crisis messages differently in the database** — messages table stays the same. Crisis state is logged in usage_logs only
- **DO NOT use `@ObservableObject`** — use `@Observable` (architecture mandate)
- **DO NOT create CrisisResourceSheet.swift in this story** — that's Story 4.2. This story only adds the detection pipeline and state tracking
- **DO NOT over-engineer the keyword list** — start with ~30 high-confidence phrases, iterate based on real usage
- **DO NOT log user message content in crisis detection** — only log `crisis_detected: boolean` and `category` for privacy (NFR14: no PII in logs)

### Project Structure Notes

**Files to CREATE:**

```
CoachMe/Supabase/supabase/functions/_shared/
└── crisis-detector.ts                          # NEW — Crisis detection helper with keyword + LLM classification
```

**Files to MODIFY:**

```
CoachMe/Supabase/supabase/functions/_shared/
├── prompt-builder.ts                           # ADD buildCrisisPrompt(), update buildCoachingPrompt() signature
└── cost-tracker.ts                             # ADD crisisDetected field to logUsage()

CoachMe/Supabase/supabase/functions/chat-stream/
└── index.ts                                    # ADD detectCrisis to pipeline, crisis_detected to SSE events

CoachMe/CoachMe/Core/Services/
└── ChatStreamService.swift                     # ADD crisis_detected to StreamEvent parsing

CoachMe/CoachMe/Features/Chat/ViewModels/
└── ChatViewModel.swift                         # ADD currentResponseHasCrisisFlag tracking

CoachMe/Supabase/supabase/migrations/
└── YYYYMMDD_add_crisis_to_usage_logs.sql       # ADD crisis_detected column to usage_logs (if needed)
```

**Files NOT to touch (verified):**

```
# These are consumed by Story 4.2, not this story
CoachMe/CoachMe/Features/Safety/                # Does not exist yet — Story 4.2 creates it
CoachMe/CoachMe/Core/Constants/CrisisResources.swift  # Does not exist yet — Story 4.2 creates it

# These are unrelated to crisis detection
CoachMe/Supabase/supabase/functions/_shared/domain-router.ts      # Unchanged
CoachMe/Supabase/supabase/functions/_shared/context-loader.ts     # Unchanged
CoachMe/Supabase/supabase/functions/_shared/pattern-synthesizer.ts # Unchanged
CoachMe/CoachMe/Features/Chat/Views/ChatView.swift                # Unchanged (UI is Story 4.2)
CoachMe/CoachMe/Features/Chat/Views/MessageBubble.swift           # Unchanged
```

### Cross-Story Dependencies

**Depends on (already completed):**
- **Story 1.6** (Chat Streaming Edge Function) — chat-stream/index.ts pipeline, SSE event structure
- **Story 1.7** (iOS SSE Streaming Client) — ChatStreamService.swift, StreamEvent enum
- **Story 2.4** (Context Injection) — memory_moment flag pattern in SSE, prompt-builder.ts
- **Story 3.4** (Pattern Recognition) — pattern_insight flag pattern, boolean flag tracking in ChatViewModel
- **Story 3.5** (Cross-Domain Pattern Synthesis) — Promise.all parallel loading pattern in chat-stream

**Enables:**
- **Story 4.2** (Crisis Resource Display) — consumes `currentResponseHasCrisisFlag` to present CrisisResourceSheet
- **Story 4.4** (Tone Guardrails & Clinical Boundaries) — crisis prompt establishes tone patterns
- **Story 4.5** (Context Continuity After Crisis) — crisis_detected in usage_logs enables identifying past crisis episodes

### Previous Story Intelligence

**From Story 3.7 (Conversation History View) — most recent completed story:**
- Sheet-based UI presentation pattern established — Story 4.2 will reuse this for CrisisResourceSheet
- `ConversationService.Conversation` has `Hashable` conformance added
- All tests pass in existing test suite

**From Story 2.4 (Context Injection) — SSE flag addition pattern:**
- Added `memory_moment` boolean to SSE token events
- Added `hasMemoryMoments` to prompt-builder.ts
- Added `currentResponseHasMemoryMoments` to ChatViewModel
- Added CodingKey + `decodeIfPresent` with `?? false` default
- **This is the EXACT pattern to follow for `crisis_detected`**

**From Story 3.5 (Cross-Domain Pattern Synthesis) — parallel helper integration:**
- Added `detectCrossDomainPatterns()` to `Promise.all()` in chat-stream
- Helper module exports a main detection function + supporting types
- Result consumed by `buildCoachingPrompt()` downstream
- **This is the EXACT pattern to follow for `detectCrisis()`**

### Git Intelligence

```
f2fa466 Epic 3: Domain routing, config engine, memory references, pattern synthesis, conversation history
6aabc11 Epic 2 context profiles, settings sign-out, UI polish, and migrations
```

Recent commits show the established pattern of adding new pipeline stages as `_shared/` helpers integrated into `chat-stream/index.ts`. The convention is: create helper → import in chat-stream → add to parallel loading → consume in prompt building → propagate flag to iOS SSE.

### Performance Considerations

**Crisis detection MUST be fast:**
- **Tier 1 (keyword scan)**: <10ms — simple string matching, no async
- **Tier 2 (LLM classification)**: <150ms — use Haiku model, 50-token response
- **Total budget**: <200ms — fits within existing pipeline latency
- **Parallel execution**: Runs alongside `loadUserContext()`, `loadRelevantHistory()`, `detectCrossDomainPatterns()` — does NOT add sequential latency

**LLM classification cost:**
- Haiku model: ~$0.0001 per classification call
- Only triggered for ambiguous messages (estimated 5-10% of all messages)
- Per-user cost impact: negligible

### Security Considerations

- **No PII in logs**: Only log `crisis_detected: boolean` and `category: string` — never log the actual message content that triggered detection (NFR14)
- **No client-side detection**: All crisis detection runs server-side in Edge Functions — the iOS app only receives the boolean flag. Detection logic and keyword lists are never exposed to the client
- **Prompt injection protection**: The crisis classification prompt is server-side only and uses a separate LLM call — user input cannot influence the classification system prompt

### Testing Requirements

**Edge Function Tests (TypeScript):**
```typescript
// crisis-detector.test.ts
describe('detectCrisis', () => {
  test('keyword match returns high confidence', async () => {
    const result = await detectCrisis('I want to kill myself');
    expect(result.crisisDetected).toBe(true);
    expect(result.confidence).toBeGreaterThanOrEqual(0.8);
    expect(result.category).toBe('suicidal_ideation');
  });

  test('normal message returns no crisis', async () => {
    const result = await detectCrisis('How do I negotiate a raise?');
    expect(result.crisisDetected).toBe(false);
  });

  test('figurative language is not crisis', async () => {
    const result = await detectCrisis('This job is killing me');
    expect(result.crisisDetected).toBe(false);
  });

  test('error in detection fails open', async () => {
    // Mock LLM to throw
    const result = await detectCrisis('ambiguous message');
    expect(result.crisisDetected).toBe(false);
  });
});
```

**iOS Tests (Swift):**
```swift
// ChatViewModelTests.swift — EXTEND existing
func testCrisisFlagSetOnTokenEvent() async {
    // Given mock stream yields token with crisis_detected: true
    // When sendMessage() processes the stream
    // Then currentResponseHasCrisisFlag == true
}

func testCrisisFlagResetOnNewConversation() async {
    // Given currentResponseHasCrisisFlag == true
    // When startNewConversation() called
    // Then currentResponseHasCrisisFlag == false
}

// ChatStreamServiceTests.swift — EXTEND existing
func testStreamEventDecodesWithCrisisFlag() throws {
    let json = """
    {"type":"token","content":"hello","memory_moment":false,"pattern_insight":false,"crisis_detected":true}
    """
    let event = try JSONDecoder().decode(ChatStreamService.StreamEvent.self, from: json.data(using: .utf8)!)
    if case .token(_, _, _, let hasCrisisFlag) = event {
        XCTAssertTrue(hasCrisisFlag)
    } else { XCTFail("Expected token event") }
}

func testStreamEventDecodesWithoutCrisisFlag() throws {
    // Backward compatibility: crisis_detected absent → defaults to false
    let json = """
    {"type":"token","content":"hello","memory_moment":false,"pattern_insight":false}
    """
    let event = try JSONDecoder().decode(ChatStreamService.StreamEvent.self, from: json.data(using: .utf8)!)
    if case .token(_, _, _, let hasCrisisFlag) = event {
        XCTAssertFalse(hasCrisisFlag)
    } else { XCTFail("Expected token event") }
}
```

**Tests to run after implementation:**
```bash
-only-testing:CoachMeTests/ChatViewModelTests
-only-testing:CoachMeTests/ChatStreamServiceTests
```

### Accessibility Requirements

1. **VoiceOver**: When `currentResponseHasCrisisFlag` is true and the assistant response is rendered, VoiceOver should announce the response content (including crisis resources). Story 4.2 will handle the specific accessibility announcement for the CrisisResourceSheet.
2. **No UI changes in this story** — all accessibility for crisis display is in Story 4.2.

### References

- [Source: epics.md#Story-4.1] — Story requirements (FR16: crisis detection in user messages)
- [Source: epics.md#FR16] — The system can detect crisis indicators (self-harm, suicidal ideation, abuse) in user messages
- [Source: epics.md#FR17] — Crisis resource display (Story 4.2, enabled by this story)
- [Source: architecture.md#API-Communication-Patterns] — Chat stream pipeline step 7: crisis detection
- [Source: architecture.md#Project-Structure] — `_shared/crisis-detector.ts` file location
- [Source: architecture.md#Data-Flow] — Crisis detection as part of Edge Function pipeline
- [Source: architecture.md#Error-Handling] — Warm first-person messages, 3-second timeout
- [Source: architecture.md#Security-Measures] — No PII in logs, system prompts server-side
- [Source: prd.md#Coaching-Not-Therapy-Boundary] — Crisis detection requirements, scope guardrails
- [Source: prd.md#AI-Safety] — Tone guardrails, content safety
- [Source: prd.md#NFR1] — 500ms time to first token (crisis detection within this budget)
- [Source: ux-design-specification.md#Crisis-Handling-Flow] — Mermaid flow diagram: User Message → Detection → Resources
- [Source: ux-design-specification.md#Crisis-Design-Principles] — Held not handled, honest boundary, resources not rejection, door stays open
- [Source: ux-design-specification.md#CrisisBanner] — Crisis-subtle background (#FED7AA), empathetic copy
- [Source: chat-stream/index.ts] — Current pipeline structure (289 lines)
- [Source: prompt-builder.ts] — Current prompt building with memory/pattern injection
- [Source: ChatStreamService.swift] — Current SSE event parsing with memory_moment/pattern_insight
- [Source: ChatViewModel.swift] — Current flag tracking pattern for memory moments
- [Source: 3-7-conversation-history-view.md] — Most recent story learnings
- [Source: 2-4-context-injection-into-coaching-responses.md] — SSE flag addition pattern reference

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
