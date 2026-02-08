# Story 4.5: Context Continuity After Crisis

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user who returns after a crisis episode**,
I want **the coach to pick up naturally**,
So that **I don't feel awkward about what happened**.

## Acceptance Criteria

1. **Given** I had a crisis-detected conversation last session, **When** I return and send a new message, **Then** the coach welcomes me back warmly without explicitly referencing the crisis episode — responding naturally as if picking up a normal coaching relationship.

2. **Given** I want to continue normal coaching after a crisis episode, **When** I start talking about career, relationships, or any other topic, **Then** the coach responds with full domain-appropriate coaching and context continuity — all my values, goals, situation, and past conversation history are available.

3. **Given** a crisis was detected in a previous conversation, **When** the context-loader loads my conversation history for the next session, **Then** the crisis conversation is included in past conversation summaries with NO filtering, special flagging, or metadata modification — it is treated identically to any other conversation.

4. **Given** I had a crisis conversation and then send multiple follow-up messages in a new conversation, **When** the coach responds to each, **Then** there is no lingering "crisis mode" behavior — every response is standard coaching unless I bring up crisis topics again.

5. **Given** I had context (values, goals, situation) before the crisis episode, **When** I return for a new session, **Then** all my context profile data is fully intact and referenced naturally via [MEMORY: ...] tags as normal.

6. **Given** crisis resources were shown to me (Story 4.2), **When** I return to the app later and start a new conversation, **Then** I see the normal chat interface — no residual crisis UI, no lingering banners, no "are you okay?" prompts.

7. **Given** VoiceOver is active, **When** I return after a crisis episode, **Then** all elements behave identically to a non-crisis return — no extra crisis-related accessibility announcements.

## Tasks / Subtasks

- [ ] Task 1: Add post-crisis continuity instruction to system prompt (AC: #1, #2, #4)
  - [ ] 1.1 In `prompt-builder.ts`, add `CRISIS_CONTINUITY_INSTRUCTION` constant — a short instruction block telling the LLM to handle returns after sensitive/crisis conversations naturally: welcome warmly, don't dwell, don't reference unless user brings it up
  - [ ] 1.2 Append `CRISIS_CONTINUITY_INSTRUCTION` to `BASE_COACHING_PROMPT` so it's always present (small token cost, avoids conditional crisis-history detection)
  - [ ] 1.3 Update the existing crisis guideline in `BASE_COACHING_PROMPT` to reference 4.1's crisis-detector.ts instead of relying solely on LLM inference (coordinate with Story 4.4)

- [ ] Task 2: Verify and document context-loader crisis neutrality (AC: #3, #5)
  - [ ] 2.1 In `context-loader.ts`, add explicit comment block above `loadRelevantHistory()` documenting that crisis conversations MUST NOT be filtered, flagged, or treated differently — this is a deliberate design decision per Story 4.5
  - [ ] 2.2 Verify `loadRelevantHistory()` has no filtering logic that could exclude conversations based on metadata, domain, or any crisis indicator that Story 4.1 may have added
  - [ ] 2.3 Verify `loadUserContext()` continues to load the full context profile regardless of crisis history — no degradation
  - [ ] 2.4 If Story 4.1 added a `crisis_detected` column to conversations table, ensure `loadRelevantHistory()` SELECT query does NOT filter on it

- [ ] Task 3: Verify chat-stream pipeline continuity (AC: #4)
  - [ ] 3.1 In `chat-stream/index.ts`, verify that the crisis detection step added by Story 4.1 only affects the CURRENT message (not subsequent messages or conversations)
  - [ ] 3.2 Verify that after a crisis-detected response, the next `POST /functions/v1/chat-stream` call follows the normal pipeline: auth → context load → domain routing → prompt building → LLM streaming
  - [ ] 3.3 Add inline comment in chat-stream pipeline documenting: "Crisis detection is per-message only. Subsequent messages/conversations follow normal pipeline (Story 4.5)"

- [ ] Task 4: Verify iOS crisis UI cleanup (AC: #6, #7)
  - [ ] 4.1 Verify `CrisisResourceSheet` (from Story 4.2) is dismissed properly and does NOT persist state that would re-trigger on next conversation or app launch
  - [ ] 4.2 Verify `ChatViewModel` does NOT store persistent crisis state — any `isCrisisDetected` flag from Story 4.2 must be conversation-scoped (reset on new conversation or `startNewConversation()`)
  - [ ] 4.3 Verify conversation history view (Story 3.7) does NOT apply special visual treatment to crisis conversations — they appear with normal domain badge and title like any other conversation
  - [ ] 4.4 If Story 4.1 added crisis-related state to `ChatViewModel`, verify it's reset in `startNewConversation()` and `loadConversation(id:)`

- [ ] Task 5: Write Edge Function tests (AC: #1, #2, #3, #4, #5)
  - [ ] 5.1 Test `buildCoachingPrompt()` output includes crisis continuity instruction
  - [ ] 5.2 Test `loadRelevantHistory()` returns crisis conversations in results without filtering
  - [ ] 5.3 Test `buildCoachingPrompt()` with context + crisis conversation in history produces a prompt that does NOT include explicit crisis handling instructions for the return scenario
  - [ ] 5.4 Test that the system prompt instructs natural return behavior (warm welcome, no dwelling)

- [ ] Task 6: Write iOS unit tests (AC: #4, #6)
  - [ ] 6.1 Test `ChatViewModel.startNewConversation()` resets any crisis-related state from Story 4.1/4.2 (e.g., `isCrisisDetected = false`, crisis sheet dismissed)
  - [ ] 6.2 Test `ChatViewModel.loadConversation(id:)` for a conversation that followed a crisis conversation loads normally with no crisis state

## Dev Notes

### Architecture Compliance

**CRITICAL — This story is primarily about verification and minimal code changes:**

1. **Design Principle**: "Don't flag crisis conversations differently in context loading" — this is the CORE mandate. Crisis conversations flow through the system identically to normal ones.
2. **Prompt Strategy**: Add a STATIC instruction to the system prompt (always present, not conditional). This avoids needing to detect crisis history in context-loader, which would violate the "no special treatment" principle.
3. **Service Pattern**: Use `@MainActor` singleton services — no new services created for this story.
4. **Edge Function Pattern**: Modifications to existing shared helpers only (`prompt-builder.ts`, `context-loader.ts`). No new Edge Functions.
5. **Error Handling**: Warm, first-person messages per UX-11 (inherited from existing patterns).
6. **Testing**: Both Edge Function tests (Deno) and iOS unit tests (XCTest).

### Technical Requirements

**From PRD (FR22):**
> The system can maintain context continuity after a crisis episode when the user returns to coaching.

**From Epics (Story 4.5):**
> - Don't flag crisis conversations differently in context loading
> - Resume normal coaching without special treatment
> - Maintain all context from before crisis

**From Architecture (Data Flow — Critical Path):**
```
User types message
  → ChatStreamService.streamChat()
  → Edge Function pipeline:
    ├─ auth.ts → verify JWT
    ├─ context-loader.ts → load context + history (<200ms)  ← MUST NOT filter crisis convos
    ├─ domain-router.ts → classify domain (<100ms)
    ├─ crisis-detector.ts → safety check                    ← Per-message only
    ├─ prompt-builder.ts → construct full prompt             ← Includes continuity instruction
    ├─ llm-client.ts → call LLM API (streaming)
    └─ on complete: save message + log cost
```

**From Architecture (Cross-Cutting Concerns):**
> Content safety: Crisis detection pipeline must intercept before response delivery

Key: "intercept before response delivery" — crisis detection is a per-message gate, NOT a persistent conversation state.

### Existing Code to Leverage — DO NOT RECREATE

**prompt-builder.ts (MODIFY — add crisis continuity instruction):**
```typescript
// Current BASE_COACHING_PROMPT already includes:
// "If users mention crisis indicators (self-harm, suicide), acknowledge
//  their feelings and encourage professional help"
//
// Story 4.5 ADDS adjacent instruction for post-crisis returns:
const CRISIS_CONTINUITY_INSTRUCTION = `
- If the user has previously discussed sensitive topics (crisis, self-harm,
  severe distress), and they return for a new conversation: welcome them back
  naturally. Do NOT reference the previous crisis unless they bring it up.
  Continue coaching normally with full context — the user deserves to feel
  like a whole person, not a crisis case.`;
```

**context-loader.ts (VERIFY — add documentation comments only):**
```typescript
// Current loadRelevantHistory() already loads ALL past conversations:
const { data: conversations } = await supabase
  .from('conversations')
  .select('id, title, domain, last_message_at')
  .eq('user_id', userId)
  .neq('id', currentConversationId)
  .order('last_message_at', { ascending: false })
  .limit(5);

// STORY 4.5: This query intentionally does NOT filter on crisis_detected
// or any crisis-related metadata. Crisis conversations MUST appear in
// history like any other conversation. This is a deliberate design decision.
```

**chat-stream/index.ts (VERIFY — add documentation comment only):**
```typescript
// Story 4.5: Crisis detection (Story 4.1) is per-message only.
// Subsequent messages and conversations follow the normal pipeline.
// No persistent "crisis mode" exists. This is by design.
```

**ChatViewModel.swift (VERIFY — crisis state reset):**
```swift
// startNewConversation() must reset any crisis state from Story 4.1/4.2
func startNewConversation() {
    // ... existing resets ...
    // Story 4.5: Ensure crisis state is cleared
    // isCrisisDetected = false  (if added by Story 4.1/4.2)
    // showCrisisSheet = false   (if added by Story 4.2)
}
```

**ConversationService.Conversation (REUSE — no changes):**
```swift
// Conversation struct stays identical. If Story 4.1 adds crisis_detected
// column to DB, it does NOT need to be in the iOS Conversation model
// (iOS doesn't need to know about crisis status of past conversations).
```

### What Story 4.1-4.4 Will Have Built (Dependencies)

**Story 4.1 (Crisis Detection Pipeline):**
- `_shared/crisis-detector.ts` — Edge Function helper with keyword matching + LLM analysis
- `crisis_detected` flag returned in SSE stream event (or metadata)
- Runs BEFORE LLM call in chat-stream pipeline
- May add `crisis_detected` boolean column to conversations or messages table

**Story 4.2 (Crisis Resource Display):**
- `CrisisResourceSheet.swift` — iOS sheet with 988 Lifeline, Crisis Text Line
- Triggered when `crisis_detected` flag received in SSE stream
- `@State private var showCrisisSheet = false` or similar in ChatViewModel/ChatView

**Story 4.3 (Coaching Disclaimers):**
- Disclaimer text in WelcomeView and terms of service
- "AI coaching, not therapy or mental health treatment"

**Story 4.4 (Tone Guardrails & Clinical Boundaries):**
- System prompt additions for tone guardrails (never dismissive, sarcastic, harsh)
- Clinical boundary rules (no diagnose, no prescribe, no claim clinical expertise)
- Updated `prompt-builder.ts` BASE_COACHING_PROMPT or additional prompt sections

### Implementation Strategy

**Principle: "What NOT to do is as important as what to do."**

This story is unusual because it's primarily a **verification and documentation story** with minimal code additions. The core value is ensuring that the crisis detection pipeline from 4.1-4.4 does NOT break conversation continuity.

**Code changes (small):**
1. `prompt-builder.ts` — Add 3-4 lines of crisis continuity instruction to BASE_COACHING_PROMPT
2. `context-loader.ts` — Add documentation comments (2-3 comment blocks)
3. `chat-stream/index.ts` — Add 1 documentation comment

**Verification tasks (primary work):**
1. Trace through the full chat-stream pipeline after a crisis conversation
2. Verify context-loader loads crisis conversations normally
3. Verify iOS doesn't persist crisis state across conversations
4. Verify CrisisResourceSheet dismisses cleanly
5. Write tests proving continuity

### Prompt Design — Crisis Continuity Instruction

The instruction should be:
1. **Brief** — minimize token cost since it's always present
2. **Warm** — match the coaching tone
3. **Clear** — unambiguous direction for the LLM
4. **Non-conditional** — doesn't require detecting crisis history

```
If the user previously discussed a crisis topic and returns for a new
conversation: welcome them back naturally. Don't reference the previous
crisis unless they bring it up first. Resume normal coaching with their
full context. They are a whole person, not a crisis case.
```

This integrates naturally with the existing BASE_COACHING_PROMPT guidelines.

### Anti-Pattern Prevention

- **DO NOT add crisis history detection to context-loader** — the technical notes explicitly say "don't flag crisis conversations differently in context loading"
- **DO NOT add conditional prompt sections based on crisis history** — use a static instruction that's always present (minimal token cost, maximum reliability)
- **DO NOT add crisis-related fields to the iOS Conversation model** — iOS doesn't need to know about crisis status of past conversations
- **DO NOT add crisis indicators to ConversationRow or HistoryView** — crisis conversations should look identical to normal ones in the UI
- **DO NOT create a "crisis cooldown" or "post-crisis mode"** — there is no persistent crisis state
- **DO NOT add a "returning after crisis" welcome message** — the coach should welcome naturally, not draw attention to the crisis
- **DO NOT log crisis-related conversation content** — per architecture, no PII in logs

### Project Structure Notes

**Files to MODIFY (minimal changes):**

```
CoachMe/Supabase/supabase/functions/_shared/
├── prompt-builder.ts              # ADD crisis continuity instruction to BASE_COACHING_PROMPT
└── context-loader.ts              # ADD documentation comments only (verify no crisis filtering)

CoachMe/Supabase/supabase/functions/chat-stream/
└── index.ts                       # ADD documentation comment only (per-message crisis scope)
```

**Files to VERIFY (no code changes, only review):**

```
CoachMe/CoachMe/Features/Chat/
├── ViewModels/ChatViewModel.swift             # VERIFY crisis state reset in startNewConversation() and loadConversation()
└── Views/ChatView.swift                       # VERIFY CrisisResourceSheet dismiss behavior

CoachMe/CoachMe/Features/History/
├── Views/ConversationRow.swift                # VERIFY no crisis-specific visual treatment
├── Views/HistoryView.swift                    # VERIFY crisis conversations shown normally
└── ViewModels/ConversationListViewModel.swift # VERIFY no crisis filtering in list
```

**Files NOT to touch (verified):**

```
# These should remain unchanged
CoachMe/CoachMe/Core/Services/ConversationService.swift         # No crisis fields needed
CoachMe/CoachMe/Core/Services/MemoryMomentParser.swift          # Parses [MEMORY:] tags only
CoachMe/CoachMe/Features/Chat/Views/MessageBubble.swift         # Renders all messages same
CoachMe/CoachMe/Core/UI/Components/EmptyStateView.swift         # No crisis states
CoachMe/Supabase/supabase/functions/_shared/domain-router.ts    # Domain routing unaffected
CoachMe/Supabase/supabase/functions/_shared/pattern-synthesizer.ts  # Pattern detection unaffected
```

### Cross-Story Dependencies

**Hard dependencies (MUST be completed first):**
- **Story 4.1** (Crisis Detection Pipeline) — establishes crisis detection in chat-stream; 4.5 ensures it doesn't break continuity
- **Story 4.2** (Crisis Resource Display) — creates CrisisResourceSheet; 4.5 verifies clean dismissal
- **Story 4.4** (Tone Guardrails & Clinical Boundaries) — modifies BASE_COACHING_PROMPT; 4.5 adds adjacent instruction

**Soft dependency:**
- **Story 4.3** (Coaching Disclaimers) — adds disclaimers but doesn't affect context continuity

**Already completed (leveraged):**
- **Epic 1** (Foundation) — ChatView, ChatViewModel, ConversationService, streaming pipeline
- **Epic 2** (Context & Memory) — context-loader.ts, prompt-builder.ts, context injection
- **Epic 3** (Domain Routing & Patterns) — loadRelevantHistory, pattern synthesis, conversation history

**Enables:**
- No direct downstream dependencies — this is a quality/safety story

### Git Intelligence

```
f2fa466 Epic 3: Domain routing, config engine, memory references, pattern synthesis, conversation history
6aabc11 Epic 2 context profiles, settings sign-out, UI polish, and migrations
ad8abd3 checkpoint
f6da5f5 Fix message input text box colors for light mode
1aa8476 Redesign message input to match iMessage style
4f9cc33 Initial commit: Coach App iOS with Epic 1 complete
```

Epics 1-3 are complete. Epic 3 stories are in review. Epic 4 has not started — stories 4.1-4.4 must be created and implemented before 4.5 can be developed.

### Testing Requirements

**Edge Function Tests (Deno):**

```typescript
// prompt-builder.test.ts — EXTEND existing
Deno.test('buildCoachingPrompt includes crisis continuity instruction', () => {
  const prompt = buildCoachingPrompt(null);
  assertStringIncludes(prompt, 'welcome them back naturally');
  assertStringIncludes(prompt, 'Don\'t reference the previous crisis');
});

Deno.test('buildCoachingPrompt with context still includes crisis continuity', () => {
  const context = createMockContext({ values: ['honesty'] });
  const prompt = buildCoachingPrompt(context, 'career');
  assertStringIncludes(prompt, 'welcome them back naturally');
});

// context-loader.test.ts — EXTEND existing
Deno.test('loadRelevantHistory does not filter crisis conversations', async () => {
  // Given: user has 3 past conversations, one with crisis_detected = true
  // When: loadRelevantHistory() is called
  // Then: all 3 conversations are returned, including the crisis one
});

Deno.test('loadRelevantHistory includes crisis conversation in summaries', async () => {
  // Given: most recent past conversation had crisis content
  // When: loadRelevantHistory() is called
  // Then: that conversation appears in results with normal summary
});
```

**iOS Unit Tests (XCTest):**

```swift
// ChatViewModelTests.swift — EXTEND existing
func testStartNewConversationResetsCrisisState() async {
    // Given: ChatViewModel has crisis state from previous conversation
    // (e.g., isCrisisDetected = true if Story 4.1 adds such state)
    // When: startNewConversation() is called
    // Then: all crisis state is reset to defaults
}

func testLoadConversationAfterCrisisLoadsNormally() async {
    // Given: previous conversation had crisis detection triggered
    // When: loadConversation(id: newConversationId) is called
    // Then: messages load normally, no crisis state is set
}
```

**Tests to run after implementation:**
```bash
# Edge Function tests (if Deno test runner configured)
deno test CoachMe/Supabase/supabase/functions/_shared/prompt-builder.test.ts
deno test CoachMe/Supabase/supabase/functions/_shared/context-loader.test.ts

# iOS tests
xcodebuild test -scheme CoachMe -destination 'platform=iOS Simulator,id=8111EC8A-2D7C-43F6-B603-9803D4A60683' -only-testing:CoachMeTests/ChatViewModelTests
```

### Performance Considerations

**Minimal impact:**
- Crisis continuity instruction adds ~50 tokens to system prompt (always present)
- No additional database queries
- No additional API calls
- No changes to <200ms context loading target
- No changes to <100ms domain routing target

### Accessibility Requirements

1. **VoiceOver**: No new UI elements. Verify existing elements behave identically post-crisis.
2. **Dynamic Type**: No new text. All existing text already supports Dynamic Type.
3. **Reduce Motion**: No new animations.
4. **Crisis conversation in history**: Must NOT have distinct VoiceOver announcement — same as any other conversation.

### References

- [Source: epics.md#Story-4.5] — Story requirements (FR22)
- [Source: epics.md#FR22] — The system can maintain context continuity after a crisis episode when the user returns to coaching
- [Source: architecture.md#API-Communication-Patterns] — Real-Time Streaming Architecture (critical path)
- [Source: architecture.md#Data-Architecture] — conversations, messages table schemas, JSONB metadata
- [Source: architecture.md#Cross-Cutting-Concerns] — Content safety: crisis detection intercepts before response delivery
- [Source: architecture.md#Enforcement-Guidelines] — No PII in logs, warm first-person error messages
- [Source: prompt-builder.ts] — BASE_COACHING_PROMPT, buildCoachingPrompt(), memory/pattern tag instructions
- [Source: context-loader.ts] — loadUserContext(), loadRelevantHistory(), UserContext interface
- [Source: chat-stream/index.ts] — Full pipeline: auth → context → domain → crisis → prompt → stream
- [Source: 3-7-conversation-history-view.md] — History view renders all conversations identically

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
