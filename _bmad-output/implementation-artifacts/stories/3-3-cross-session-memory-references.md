# Story 3.3: Cross-Session Memory References

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want **the coach to reference things I said in previous conversations**,
So that **coaching feels continuous, not fragmented**.

## Acceptance Criteria

1. **Given** I mentioned something important in a previous conversation, **When** I bring up a related topic in a new conversation today, **Then** the coach references our previous conversation naturally (e.g., "Last time we talked about X, you mentioned...").

2. **Given** a memory reference appears in the coach's response, **When** I see it in the response, **Then** it has subtle visual distinction per UX-4 (sparkle icon + memoryPeach background — reuses existing memory moment treatment from Story 2.4).

3. **Given** I have no previous conversations, **When** the coach responds, **Then** responses are still helpful and don't mention missing history.

4. **Given** the coach references a past conversation, **When** the response is streamed, **Then** the memory reference is detected and tagged in real-time using existing `[MEMORY: ...]` tags — no new tag types needed.

5. **Given** past conversation history is loaded for context, **When** combined with context profile loading, **Then** total context+history loading completes in <200ms and time-to-first-token stays <500ms (NFR1).

6. **Given** the history loading fails (database timeout, error), **When** the chat-stream pipeline continues, **Then** the coach responds normally without cross-session references (graceful degradation).

## Tasks / Subtasks

- [x] Task 1: Add `loadRelevantHistory()` to context-loader.ts (AC: #1, #3, #5, #6)
  - [x] 1.1 Add `PastConversation` interface: `{ conversationId, title, domain, summary, lastMessageAt }`
  - [x] 1.2 Add `ConversationHistory` interface: `{ conversations: PastConversation[], hasHistory: boolean }`
  - [x] 1.3 Implement `loadRelevantHistory(supabase, userId, currentConversationId)` function
  - [x] 1.4 Query `conversations` table for user's past conversations (exclude current), ordered by `last_message_at` DESC, limit 5
  - [x] 1.5 For each conversation, load last 3 messages from `messages` table to build a brief summary
  - [x] 1.6 Return `ConversationHistory` with `hasHistory: false` for users with no past conversations
  - [x] 1.7 Wrap entire function in try/catch — return `{ conversations: [], hasHistory: false }` on any error (AC: #6)
  - [x] 1.8 Target <100ms for history load (will run in parallel with context profile load)

- [x] Task 2: Create `_shared/conversation-summarizer.ts` helper (AC: #1)
  - [x] 2.1 Create `conversation-summarizer.ts` in `_shared/`
  - [x] 2.2 Implement `summarizeConversation(messages, title?, domain?)` — creates 1-2 sentence summary
  - [x] 2.3 Use simple extraction (NO LLM call): take user's last message topic + assistant's last response theme
  - [x] 2.4 Include domain label if available (e.g., "Career coaching: discussed upcoming promotion interview")
  - [x] 2.5 Truncate summaries to ~80 characters to keep token budget low
  - [x] 2.6 Handle edge cases: empty messages, single message, messages with only system role

- [x] Task 3: Update prompt-builder.ts for cross-session references (AC: #1, #3, #4)
  - [x] 3.1 Add `pastConversations?: PastConversation[]` parameter to `buildCoachingPrompt()` signature
  - [x] 3.2 Create `formatHistorySection(pastConversations)` helper function
  - [x] 3.3 Format past conversations into a `## PREVIOUS CONVERSATIONS` section in system prompt
  - [x] 3.4 Add instruction: "When you reference something from a previous conversation, wrap it in [MEMORY: ...] tags, exactly as you do for context profile references"
  - [x] 3.5 Add instruction: "Reference past conversations naturally. Don't force references — only mention when the current topic genuinely connects"
  - [x] 3.6 Omit the PREVIOUS CONVERSATIONS section entirely when `pastConversations` is empty (AC: #3)
  - [x] 3.7 Cap total history section to ~500 tokens to stay within prompt budget

- [x] Task 4: Update chat-stream/index.ts to load and inject history (AC: #1, #5, #6)
  - [x] 4.1 Import `loadRelevantHistory` from `context-loader.ts`
  - [x] 4.2 Call `loadRelevantHistory` in `Promise.all()` with existing `loadUserContext` (parallel, no added latency)
  - [x] 4.3 Pass `pastConversations` to `buildCoachingPrompt()` alongside existing context and domain
  - [x] 4.4 No changes to memory moment detection — existing `hasMemoryMoments()` check already handles cross-session `[MEMORY: ...]` tags
  - [x] 4.5 Verify total pipeline latency stays <500ms with history loading

- [x] Task 5: Write Edge Function unit tests (AC: all)
  - [x] 5.1 Test `loadRelevantHistory` returns 5 most recent conversations for user
  - [x] 5.2 Test `loadRelevantHistory` excludes current conversation from results
  - [x] 5.3 Test `loadRelevantHistory` returns empty for user with no history
  - [x] 5.4 Test `loadRelevantHistory` returns empty for user with only current conversation
  - [x] 5.5 Test `loadRelevantHistory` gracefully handles database errors (returns empty, doesn't throw)
  - [x] 5.6 Test `summarizeConversation` produces reasonable summary from messages
  - [x] 5.7 Test `summarizeConversation` handles empty/single messages
  - [x] 5.8 Test `summarizeConversation` truncates long summaries
  - [x] 5.9 Test `buildCoachingPrompt` includes PREVIOUS CONVERSATIONS section when history present
  - [x] 5.10 Test `buildCoachingPrompt` omits section entirely when history empty
  - [x] 5.11 Test `buildCoachingPrompt` includes memory tag instruction for cross-session refs

- [x] Task 6: Write iOS regression tests (AC: #2, #4)
  - [x] 6.1 Verify existing `MemoryMomentParser` handles `[MEMORY: ...]` tags from cross-session references (regression — should already pass)
  - [x] 6.2 Verify existing `MemoryMomentText` renders correctly for any memory moment content
  - [x] 6.3 Verify `MessageBubble` renders memory moments in completed messages (regression)
  - [x] 6.4 Verify `ChatStreamService` `StreamEvent.hasMemoryMoment` flag works for cross-session memory events

## Dev Notes

### Architecture Compliance

**CRITICAL — Follow these patterns established in Epics 1-2 and Stories 3.1-3.2:**

1. **Edge Function Pattern**: All helpers in `_shared/` directory, export functions, import in `index.ts`
2. **Parallel Loading**: `Promise.all([loadUserContext(...), loadRelevantHistory(...)])` — don't add serial latency
3. **Prompt Building**: Extend existing `buildCoachingPrompt()` signature — don't create a separate function
4. **Memory Moments**: Reuse existing `[MEMORY: ...]` tag system — NO new tag types, NO new iOS parsing
5. **Performance Budget**: <500ms TTFT (NFR1), <200ms for context+history combined load
6. **Graceful Degradation**: History load failure → proceed without history, don't break chat (AC: #6)
7. **Error Handling**: Warm, first-person messages per UX-11 if errors surface to user (they shouldn't for this story — failures are silent)

### Key Design Decision: ZERO iOS Changes

The existing memory moment infrastructure from Story 2.4 already handles everything needed on the client side:

| Component | What It Does | Change Needed? |
|-----------|-------------|----------------|
| `MemoryMomentParser.swift` | Parses `[MEMORY: ...]` tags from any text | **None** — tag source doesn't matter |
| `MemoryMomentText.swift` | Renders sparkle icon + memoryPeach background | **None** — works for any memory content |
| `MessageBubble.swift` | Displays memory moment chips in completed messages | **None** — already integrated |
| `StreamingText.swift` | Detects memory moments during streaming | **None** — already integrated |
| `ChatStreamService.swift` | `StreamEvent.hasMemoryMoment` flag | **None** — flag is source-agnostic |
| `ChatViewModel.swift` | Tracks `currentResponseHasMemoryMoments` | **None** — already works |

**All work is server-side: `context-loader.ts`, `prompt-builder.ts`, `chat-stream/index.ts`, new `conversation-summarizer.ts`.**

### Technical Requirements

**From PRD (FR7):**
> The system can reference previous conversations within the current coaching response

**From UX (UX-4):**
> Memory moments receive subtle visual distinction

**From Architecture (Data Flow — Coaching Conversation):**
> Edge Function pipeline: context-loader.ts → load context + history (<200ms)

### Context Loading Strategy (Extended)

```typescript
// context-loader.ts — NEW interfaces and function

export interface PastConversation {
  conversationId: string;
  title: string | null;
  domain: string | null;
  summary: string;
  lastMessageAt: string;
}

export interface ConversationHistory {
  conversations: PastConversation[];
  hasHistory: boolean;
}

export async function loadRelevantHistory(
  supabase: SupabaseClient,
  userId: string,
  currentConversationId: string
): Promise<ConversationHistory> {
  try {
    const { data: conversations } = await supabase
      .from('conversations')
      .select('id, title, domain, last_message_at')
      .eq('user_id', userId)
      .neq('id', currentConversationId)
      .order('last_message_at', { ascending: false })
      .limit(5);

    if (!conversations?.length) {
      return { conversations: [], hasHistory: false };
    }

    const summaries = await Promise.all(
      conversations.map(async (conv) => {
        const { data: messages } = await supabase
          .from('messages')
          .select('role, content')
          .eq('conversation_id', conv.id)
          .order('created_at', { ascending: false })
          .limit(3);

        return {
          conversationId: conv.id,
          title: conv.title,
          domain: conv.domain,
          summary: summarizeConversation(messages ?? [], conv.title, conv.domain),
          lastMessageAt: conv.last_message_at,
        };
      })
    );

    return { conversations: summaries, hasHistory: true };
  } catch (error) {
    console.error('Failed to load history, proceeding without:', error);
    return { conversations: [], hasHistory: false };
  }
}
```

### Prompt Building Strategy

```typescript
// prompt-builder.ts — ADD to existing buildCoachingPrompt()

function formatHistorySection(pastConversations: PastConversation[]): string {
  if (!pastConversations.length) return '';

  let section = '\n\n## PREVIOUS CONVERSATIONS\n';
  section += 'The user has had these recent coaching conversations with you. ';
  section += 'Reference them naturally when relevant using [MEMORY: ...] tags.\n';
  section += 'Do NOT force references — only mention past conversations when the current topic genuinely connects.\n\n';

  for (const conv of pastConversations) {
    const domain = conv.domain ? ` (${conv.domain})` : '';
    const title = conv.title || 'Untitled conversation';
    section += `- ${title}${domain}: ${conv.summary}\n`;
  }

  return section;
}
```

### Chat-Stream Pipeline Integration

```typescript
// chat-stream/index.ts — MODIFY existing pipeline

// BEFORE (current):
const userContext = await loadUserContext(supabase, userId);
const systemPrompt = buildCoachingPrompt(userContext, domain);

// AFTER (with history):
const [userContext, conversationHistory] = await Promise.all([
  loadUserContext(supabase, userId),
  loadRelevantHistory(supabase, userId, conversationId),
]);
const systemPrompt = buildCoachingPrompt(
  userContext,
  domain,
  conversationHistory.conversations  // new parameter
);
```

### Performance Considerations

**Context + History Loading Budget:**
- Target: <200ms total (context + history combined, parallel)
- History query: 1 query for conversations + up to 5 queries for messages = 6 queries total
- All queries use indexed columns (`user_id`, `conversation_id`, `last_message_at`)
- Limit: 5 conversations × 3 messages = 15 DB rows max additional load
- If history load fails or times out, proceed without it (AC: #6)

**Token Budget for History Section:**
- Max ~500 tokens for history summaries in system prompt
- 5 conversations × ~100 tokens each = ~500 tokens
- Well within total context window budget
- `summarizeConversation` truncates to ~80 chars per summary

**Database Query Performance:**
- `conversations` table already has index on `(user_id, last_message_at)`
- `messages` table already has index on `(conversation_id, created_at)`
- Both queries use existing indexes — no new migrations needed

### Anti-Pattern Prevention

- **DO NOT create new tag types** — use existing `[MEMORY: ...]` tags, not `[SESSION_REF: ...]` or similar
- **DO NOT modify any iOS Swift files** — existing memory moment pipeline handles everything
- **DO NOT use an LLM call for summarization** — simple text extraction keeps latency low and cost zero
- **DO NOT load full message history** — only last 3 messages per conversation for summary
- **DO NOT add new database migrations** — all needed columns already exist
- **DO NOT block on history loading** — if it fails, proceed without it
- **DO NOT force references** — prompt instruction must tell Claude to reference naturally, only when relevant

### Project Structure Notes

**Files to CREATE:**

```
CoachMe/Supabase/supabase/functions/_shared/
├── conversation-summarizer.ts           # NEW — Simple conversation summary extraction
└── conversation-summarizer.test.ts      # NEW — Unit tests for summarizer
```

**Files to MODIFY:**

```
CoachMe/Supabase/supabase/functions/_shared/
├── context-loader.ts                    # ADD loadRelevantHistory(), PastConversation, ConversationHistory
├── context-loader.test.ts              # ADD history loading tests
└── prompt-builder.ts                    # ADD pastConversations param, formatHistorySection()
    └── prompt-builder.test.ts           # ADD history section tests

CoachMe/Supabase/supabase/functions/
└── chat-stream/index.ts                # ADD Promise.all with history loading, pass to prompt builder
```

**Files NOT to touch (verified):**

```
# iOS Client — ZERO changes needed
CoachMe/CoachMe/Core/Services/MemoryMomentParser.swift
CoachMe/CoachMe/Core/Services/ChatStreamService.swift
CoachMe/CoachMe/Features/Chat/Views/MemoryMomentText.swift
CoachMe/CoachMe/Features/Chat/Views/MessageBubble.swift
CoachMe/CoachMe/Features/Chat/Views/StreamingText.swift
CoachMe/CoachMe/Features/Chat/ViewModels/ChatViewModel.swift
CoachMe/CoachMe/Features/Chat/Views/ChatView.swift

# Database — no new migrations
CoachMe/Supabase/supabase/migrations/*

# Other Edge Functions — unchanged
CoachMe/Supabase/supabase/functions/_shared/llm-client.ts
CoachMe/Supabase/supabase/functions/_shared/auth.ts
CoachMe/Supabase/supabase/functions/_shared/cost-tracker.ts
CoachMe/Supabase/supabase/functions/extract-context/index.ts
```

### Cross-Story Dependencies

**Depends on (must be implemented first):**
- **Story 3-1** (Invisible Domain Routing) — creates `domain-router.ts`, updates `prompt-builder.ts` with domain parameter, integrates domain into `chat-stream/index.ts` pipeline
- **Story 2-4** (Context Injection) — creates `context-loader.ts`, `prompt-builder.ts`, `[MEMORY: ...]` tag system, `MemoryMomentParser.swift`, `MemoryMomentText.swift`

**Soft dependency (nice to have but not required):**
- **Story 3-2** (Domain Configuration Engine) — domain-aware config makes summaries richer, but Story 3-3 works without it using the `domain` column already on conversations table

**Enables:**
- **Story 3.4** (Pattern Recognition Across Conversations) — cross-session history loading is a prerequisite for pattern detection
- **Story 3.5** (Cross-Domain Pattern Synthesis) — needs history across domains

### Previous Story Intelligence

**From Story 2.4 (Context Injection) — direct infrastructure dependency:**
- `context-loader.ts` returns `UserContext` with `hasContext` boolean — follow same pattern for `ConversationHistory.hasHistory`
- `prompt-builder.ts` uses `MEMORY_TAG_INSTRUCTION` constant — reuse same instruction pattern for cross-session refs
- Memory moment detection in `chat-stream/index.ts` uses `hasMemoryMoments()` helper — already source-agnostic
- iOS `MemoryMomentParser` handles multiple/nested `[MEMORY: ...]` tags — proven reliable
- Code review fix: `findMomentRanges` must find ALL occurrences, not just first — already fixed

**From Story 2.4 Code Review Fixes (avoid repeating):**
- Don't use `fatalError()` — use graceful error handling
- Dark mode memory indicator uses `memoryIndicatorDark` (not amber)
- Ensure error handling returns safe defaults, not crashes

**From Story 2.3 (Progressive Context Extraction):**
- Edge Function helpers follow `_shared/` directory pattern
- Non-streaming REST for background tasks, SSE for chat streaming
- `ContextExtractionServiceProtocol` pattern for mock injection in tests

**From Story 3.1 (Invisible Domain Routing) — prerequisite:**
- `chat-stream/index.ts` will have domain routing integrated
- `buildCoachingPrompt(userContext, domain)` will accept domain parameter
- Conversation `domain` column will be populated — useful for history summaries

### Git Intelligence

```
ad8abd3 checkpoint (Epic 2 complete)
f6da5f5 Fix message input text box colors for light mode
1aa8476 Redesign message input to match iMessage style
4f9cc33 Initial commit: Coach App iOS with Epic 1 complete
```

Story 3-1 (and possibly 3-2) will be implemented before 3-3. Check latest commits and files before starting dev.

### Testing Requirements

**Edge Function Tests (primary — this is where all the work is):**

```typescript
// context-loader.test.ts — EXTEND existing
describe('loadRelevantHistory', () => {
  it('returns 5 most recent conversations for user')
  it('excludes current conversation from results')
  it('returns { conversations: [], hasHistory: false } for user with no history')
  it('returns empty for user with only current conversation')
  it('gracefully handles database error without throwing')
  it('includes title, domain, and summary for each conversation')
  it('orders by last_message_at descending')
})

// conversation-summarizer.test.ts — NEW
describe('summarizeConversation', () => {
  it('creates summary from user+assistant messages')
  it('includes domain label when provided')
  it('handles empty messages array')
  it('handles single message')
  it('truncates long summaries to ~80 chars')
  it('handles messages with only system role')
})

// prompt-builder.test.ts — EXTEND existing
describe('buildCoachingPrompt with history', () => {
  it('includes PREVIOUS CONVERSATIONS section when history present')
  it('omits section entirely when history empty')
  it('includes memory tag instruction for cross-session references')
  it('includes natural-reference instruction (no forced references)')
  it('formats each conversation with title, domain, and summary')
})
```

**iOS Tests (regression only — no new functionality):**

```swift
// CoachMeTests/MemoryMomentParserTests.swift — verify existing tests still pass
// No new tests needed — parser is tag-source-agnostic
// Run: -only-testing:CoachMeTests/MemoryMomentParserTests

// CoachMeTests/MemoryMomentTextTests.swift — verify existing tests still pass
// Run: -only-testing:CoachMeTests/MemoryMomentTextTests
```

### References

- [Source: epics.md#Story-3.3] — Story requirements (FR7)
- [Source: epics.md#FR7] — The system can reference previous conversations within the current coaching response
- [Source: ux-design-specification.md#UX-4] — Memory moment visual distinction
- [Source: architecture.md#Real-Time-Streaming-Pipeline] — Steps 2-3: load context + history (<200ms)
- [Source: architecture.md#Data-Architecture] — conversations, messages table schemas
- [Source: 2-4-context-injection-into-coaching-responses.md] — Memory moment infrastructure, context-loader.ts, prompt-builder.ts
- [Source: 2-3-progressive-context-extraction.md] — Edge Function patterns, _shared/ directory
- [Source: 3-1-invisible-domain-routing.md] — Domain routing pipeline, buildCoachingPrompt domain parameter
- [Source: 3-2-domain-configuration-engine.md] — Domain config schema, getDomainConfig()
- [Source: context-loader.ts] — Existing context loading (UserContext interface pattern)
- [Source: prompt-builder.ts] — Existing prompt building (MEMORY_TAG_INSTRUCTION pattern)
- [Source: chat-stream/index.ts] — Current pipeline with parallel loading pattern
- [Source: MemoryMomentParser.swift] — Existing tag parser (proven reliable)
- [Source: MemoryMomentText.swift] — Existing visual treatment (sparkle + memoryPeach)

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6

### Debug Log References
- Fixed bug where early return in `buildCoachingPrompt()` skipped history section when user had no context profile. Added separate path to include history even without context.

### Completion Notes List
- **Task 1**: Added `PastConversation` and `ConversationHistory` interfaces + `loadRelevantHistory()` to context-loader.ts. Queries up to 5 past conversations, loads last 3 messages each for summary generation. Full try/catch with graceful degradation.
- **Task 2**: Created `conversation-summarizer.ts` — simple text extraction (no LLM call) that produces ~80 char summaries with domain prefix. Handles empty, single, and system-only messages.
- **Task 3**: Extended `buildCoachingPrompt()` with `pastConversations` parameter. Added `formatHistorySection()` that builds `## PREVIOUS CONVERSATIONS` section with [MEMORY: ...] tag and natural-reference instructions. Section omitted when empty.
- **Task 4**: Updated `chat-stream/index.ts` to `Promise.all([loadUserContext, loadRelevantHistory])` for parallel loading. Passes `conversationHistory.conversations` to prompt builder. Zero added serial latency.
- **Task 5**: Added 7 tests for `loadRelevantHistory` (context-loader.test.ts), 8 tests for `summarizeConversation` (conversation-summarizer.test.ts), 7 tests for history in `buildCoachingPrompt` (prompt-builder.test.ts). Total: 22 new tests.
- **Task 6**: Verified existing iOS tests cover regression scenarios — MemoryMomentParser, MemoryMomentText, ChatStreamService are all source-agnostic. Zero iOS code changes needed.

### Change Log
- 2026-02-07: Story 3.3 implementation complete — cross-session memory references via server-side changes only

### File List

**New files:**
- `CoachMe/Supabase/supabase/functions/_shared/conversation-summarizer.ts`
- `CoachMe/Supabase/supabase/functions/_shared/conversation-summarizer.test.ts`

**Modified files:**
- `CoachMe/Supabase/supabase/functions/_shared/context-loader.ts` — Added PastConversation, ConversationHistory interfaces + loadRelevantHistory()
- `CoachMe/Supabase/supabase/functions/_shared/context-loader.test.ts` — Added 7 loadRelevantHistory tests
- `CoachMe/Supabase/supabase/functions/_shared/prompt-builder.ts` — Added pastConversations param + formatHistorySection()
- `CoachMe/Supabase/supabase/functions/_shared/prompt-builder.test.ts` — Added 7 cross-session history tests
- `CoachMe/Supabase/supabase/functions/chat-stream/index.ts` — Promise.all parallel loading, pass history to prompt builder
