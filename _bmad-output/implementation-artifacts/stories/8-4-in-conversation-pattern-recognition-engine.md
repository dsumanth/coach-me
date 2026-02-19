# Story 8.4: In-Conversation Pattern Recognition Engine

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want **the coach to notice patterns in my behavior and conversations over time**,
so that **I gain self-awareness about recurring themes I might not see on my own**.

## Acceptance Criteria

1. **Given** I have 5+ sessions with accumulated learning signals, **When** the coach constructs a response, **Then** the system prompt includes a "patterns summary" derived from learning signals (recurring themes, domain frequency, behavioral trends)

2. **Given** the coach detects a recurring theme across 3+ sessions, **When** it surfaces the pattern in conversation, **Then** it does so naturally through the coach's voice: "I've noticed this is the third time we've talked about X — what do you think is driving that?"

3. **Given** a pattern is surfaced, **When** the user engages with it (responds with 2+ messages about the pattern), **Then** the engagement is captured as a learning signal confirming the pattern's relevance

4. **Given** the system generates pattern summaries, **When** multiple patterns exist, **Then** patterns are ranked by frequency and recency, with only high-confidence patterns (3+ occurrences) included in prompts

## Tasks / Subtasks

- [x] Task 1: Create `pattern-analyzer` shared helper module (AC: #1, #4)
  - [x] 1.1 Create `_shared/pattern-analyzer.ts` — queries learning signals + pattern_syntheses, generates pattern summary for prompt injection
  - [x] 1.2 Implement `generatePatternSummary(userId, supabase)` — main entry point returning `PatternSummary[]`
  - [x] 1.3 Implement session-count-based cache check: refresh when 3+ new conversations since last analysis
  - [x] 1.4 Implement pattern ranking by frequency (occurrence count) and recency (last seen timestamp)
  - [x] 1.5 Filter to only high-confidence patterns (3+ occurrences, confidence >= 0.85)
  - [x] 1.6 Generate coaching-ready summary strings (~100 tokens each, max 2-3 patterns)
  - [x] 1.7 Write `pattern-analyzer.test.ts` — test summarization, signal extraction, caching, ranking, empty states

- [x] Task 2: Create database migration for pattern summary caching (AC: #1, #4)
  - [x] 2.1 Create migration `20260210000005_pattern_cache.sql` (**Note:** `20260210000003` was already taken by `push_tokens.sql`. Used `20260210000005` to avoid collision.)
  - [x] 2.2 Add `pattern_cache` table: `id`, `user_id`, `summaries` (JSONB), `session_count_at_analysis` (INTEGER), `created_at`, `updated_at`
  - [x] 2.3 Add index on `user_id` and RLS policy (users can only read own `pattern_cache`)
  - [x] 2.4 Add RPC function `get_session_count(p_user_id UUID)` — returns count of conversations for user

- [x] Task 3: Extend `prompt-builder.ts` with `[PATTERNS_CONTEXT]` section (AC: #1, #2)
  - [x] 3.1 Add `PATTERNS_CONTEXT_INSTRUCTION` constant with coaching instructions for pattern surfacing
  - [x] 3.2 Add `patternSummaries: PatternSummary[]` parameter to `buildCoachingPrompt()`
  - [x] 3.3 Insert `[PATTERNS_CONTEXT]` section AFTER existing `CROSS_DOMAIN_PATTERN_INSTRUCTION` block
  - [x] 3.4 Format pattern summaries: theme, occurrence count, domains, coaching-ready synthesis
  - [x] 3.5 Guard: only include section when user has 5+ sessions (per AC #1)
  - [x] 3.6 Update existing `prompt-builder.test.ts` with tests for new section
  - [x] 3.7 Export new `PatternSummary` interface from prompt-builder

- [x] Task 4: Integrate pattern-analyzer into `chat-stream/index.ts` pipeline (AC: #1, #2)
  - [x] 4.1 Import `generatePatternSummary` from pattern-analyzer
  - [x] 4.2 Add to existing `Promise.all()` parallel load block (NOT on critical path)
  - [x] 4.3 Pass resulting `patternSummaries` to `buildCoachingPrompt()`
  - [x] 4.4 Graceful degradation: if pattern-analyzer fails, return empty array (never block coaching)

- [x] Task 5: Implement pattern engagement tracking (AC: #3)
  - [x] 5.1 Detect when assistant response contains `[PATTERN: ...]` tag — set `patternSurfacedThisSession` flag
  - [x] 5.2 After surfacing, count subsequent user messages in the same conversation
  - [x] 5.3 If user sends 2+ messages after pattern surfaced → record `pattern_engaged` learning signal
  - [x] 5.4 Learning signal payload: `{ pattern_theme, engagement_depth, conversation_id }`
  - [x] 5.5 Story 8.1 `learning_signals` table EXISTS — full implementation (no stub). Migration also adds `pattern_engaged` to allowed signal_type CHECK constraint.

- [x] Task 6: End-to-end integration testing
  - [x] 6.1 Test: User with <5 sessions → no pattern summary injected
  - [x] 6.2 Test: User with 5+ sessions → pattern summary present in system prompt
  - [x] 6.3 Test: Pattern cache hit within 3-session window → uses cached data
  - [x] 6.4 Test: Pattern cache miss (3+ new conversations) → triggers re-analysis
  - [x] 6.5 Test: Graceful degradation when pattern-analyzer errors
  - [x] 6.6 Test: Pattern ranking respects frequency and recency ordering

## Dev Notes

### Critical Dependencies

**Story 8.1 (Learning Signals Infrastructure)** is listed as a dependency. However, Story 8.4 can be **partially implemented without 8.1** because:
- The existing `pattern_syntheses` table (from Story 3.5) already contains cross-domain patterns
- The existing `messages`, `conversations`, and `context_profiles` tables provide signal-like data
- The `pattern-analyzer` can initially query these existing tables
- Learning signal recording (Task 5) should be **stubbed** if 8.1 is not yet complete

**Recommendation**: Implement Tasks 1-4, 6 fully. For Task 5, create the detection logic but stub the signal recording with a clear TODO marker.

### Architecture Patterns & Constraints

**Edge Function Pattern** — All shared modules follow this structure:
```
CoachMe/Supabase/supabase/functions/_shared/{module-name}.ts
CoachMe/Supabase/supabase/functions/_shared/{module-name}.test.ts
```

**Service Singleton Pattern** (Swift side — no iOS changes expected for this story):
```swift
@MainActor final class ServiceName { static let shared = ServiceName() }
```

**Graceful Degradation** — Pattern detection MUST never block coaching:
```typescript
try {
  const summaries = await generatePatternSummary(userId, supabase);
} catch (error) {
  console.error('Pattern analysis failed:', error);
  return []; // Silent fail — coaching continues
}
```

**Error Messages** — UX-11 warm first-person style (not applicable to server-side, but keep in mind for any client-side changes):
- "I couldn't..." not "Failed to..."

### Existing Pattern Infrastructure (Epic 3 — DO NOT REINVENT)

The following already exists and MUST be reused:

| Component | File | What It Does |
|-----------|------|--------------|
| Pattern Synthesizer | `_shared/pattern-synthesizer.ts` | Cross-domain pattern detection with LLM analysis, 24h cache, rate limiting |
| Prompt Builder | `_shared/prompt-builder.ts` | System prompt construction with context, history, patterns, crisis handling |
| Pattern Tag Instruction | `prompt-builder.ts:62-83` | `PATTERN_TAG_INSTRUCTION` — guides LLM to surface patterns with `[PATTERN: ...]` tags |
| Cross-Domain Injection | `prompt-builder.ts:85-97` | `CROSS_DOMAIN_PATTERN_INSTRUCTION` + `formatCrossDomainPatterns()` |
| Pattern Tag Utils | `prompt-builder.ts:437-475` | `hasPatternInsights()`, `extractPatternInsights()`, `stripPatternTags()` |
| Chat Stream Pipeline | `chat-stream/index.ts:73-146` | Parallel loading of context, history, patterns; rate limiting; prompt building |
| Rate Limiting | `pattern-synthesizer.ts:405-508` | `canSurfaceSynthesis()`, `filterByRateLimit()` — max 1/session, 3-session gap |

**Key Difference Between Story 3.5 and 8.4**:
- **3.5** provides *cross-domain pattern synthesis* — background LLM analysis, 24h cache, injected as pattern instructions
- **8.4** provides *pattern summaries from learning signals* — enriched summaries injected as context (not just instructions). Enables the LLM to have richer, data-backed pattern awareness during conversations

### Chat Stream Pipeline Integration Point

Current `chat-stream/index.ts` parallel load (line 73):
```typescript
const [userContext, conversationHistory, patternResult, rawHistory] = await Promise.all([
  loadUserContext(supabase, userId),
  loadRelevantHistory(supabase, userId, conversationId),
  detectCrossDomainPatterns(userId, supabase),
  supabase.from('messages').select('*').eq('conversation_id', conversationId).order('created_at').limit(20)
]);
```

**Add `generatePatternSummary` to this Promise.all()** — it runs in parallel, NOT on the critical path.

Current `buildCoachingPrompt` call (line ~120):
```typescript
const systemPrompt = buildCoachingPrompt(
  userContext,
  domainResult.domain,
  domainResult.shouldClarify,
  conversationHistory.conversations,
  eligiblePatterns,
  crisisResult.crisisDetected
);
```

**Add `patternSummaries` as a new parameter** after `crisisDetected`.

### Prompt Section Placement

The `[PATTERNS_CONTEXT]` section goes AFTER the existing cross-domain pattern section. Full prompt order:
1. BASE_COACHING_PROMPT
2. TONE_GUARDRAILS_INSTRUCTION
3. CLINICAL_BOUNDARY_INSTRUCTION
4. CRISIS_CONTINUITY_INSTRUCTION
5. [CRISIS_PROMPT if crisis]
6. Domain-specific config
7. CLARIFY_INSTRUCTION (if needed)
8. USER CONTEXT section
9. MEMORY_TAG_INSTRUCTION
10. PREVIOUS CONVERSATIONS
11. PATTERN_TAG_INSTRUCTION
12. CROSS_DOMAIN_PATTERN_INSTRUCTION
13. **[PATTERNS_CONTEXT] ← NEW (Story 8.4)**

### Pattern Summary Format for System Prompt

```
## PATTERNS CONTEXT

Based on accumulated coaching history, here are the recurring patterns detected for this user.
Reference these naturally if relevant to the current conversation. Do not force pattern references.

Patterns (ranked by confidence):
1. "Control and Perfectionism" — Appears across career, relationships, personal projects (5 occurrences over 3 weeks). User tends to seek control when feeling uncertain. — Confidence: 0.92
2. "Self-Doubt in Leadership" — When discussing leadership roles, frequently questions readiness despite strong evidence of competence (3 occurrences). — Confidence: 0.88

Coaching guidance:
- Surface at most ONE pattern per response using [PATTERN: your insight] tags
- Use reflective language: "I've noticed...", "This seems to come up..."
- If user engages (responds with depth), explore further
- If user deflects, respect that and move on
```

### 3-Session Cache TTL Implementation

Instead of time-based TTL (current 24h), use conversation-count-based:

```typescript
// Check if cache needs refresh
const conversationsSinceAnalysis = await supabase
  .from('conversations')
  .select('id', { count: 'exact', head: true })
  .eq('user_id', userId)
  .gt('created_at', cachedPattern.created_at);

if ((conversationsSinceAnalysis.count ?? 0) >= 3) {
  // Trigger re-analysis
} else {
  // Use cached summary
}
```

### Performance Budgets

| Component | Target | Notes |
|-----------|--------|-------|
| Pattern summary generation | <3s | Runs async in parallel, cached |
| Cache lookup | <50ms | Simple DB query by user_id |
| Prompt injection | <10ms | String concatenation only |
| Session count check | <50ms | COUNT query with index |

**LLM Model for Pattern Analysis**: `claude-haiku-4-5-20251001` (same as pattern-synthesizer — cost-efficient)

### Database Conventions

```sql
-- Tables: snake_case, plural
-- Columns: snake_case
-- Foreign keys: {table_singular}_id
-- Indexes: idx_{table}_{column}
-- Migrations: {timestamp}_{description}.sql
```

### File Naming Conventions

```
Edge Functions: kebab-case (pattern-analyzer.ts)
Shared modules: kebab-case (_shared/pattern-analyzer.ts)
Tests: {module}.test.ts (_shared/pattern-analyzer.test.ts)
Migrations: {timestamp}_{description}.sql
```

### What NOT to Do

- **DO NOT** create a new Edge Function endpoint — `pattern-analyzer` is a **shared helper** (`_shared/pattern-analyzer.ts`), not a standalone function
- **DO NOT** modify the iOS client (ChatStreamService, ChatViewModel) — pattern recognition engine is entirely server-side
- **DO NOT** replace the existing 24h TTL in `pattern-synthesizer.ts` — the 3-session TTL is for the NEW pattern cache, not the existing one
- **DO NOT** increase the rate limit beyond 1 pattern surfacing per session (existing `MAX_SYNTHESES_PER_SESSION = 1`)
- **DO NOT** query learning_signals table if Story 8.1 migration hasn't run — check table existence or use a feature flag
- **DO NOT** block the coaching response if pattern analysis fails — always degrade gracefully
- **DO NOT** log user message content to console/Sentry (PII protection)

### Project Structure Notes

- All Edge Function shared modules go in: `CoachMe/Supabase/supabase/functions/_shared/`
- Migrations go in: `CoachMe/Supabase/supabase/migrations/`
- No new iOS files needed for this story
- Aligns with existing monorepo structure: server code in `Supabase/` directory

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 8.4] — Story definition, acceptance criteria, technical notes
- [Source: CoachMe/Supabase/supabase/functions/_shared/pattern-synthesizer.ts] — Existing pattern detection, caching, rate limiting
- [Source: CoachMe/Supabase/supabase/functions/_shared/prompt-builder.ts] — Prompt construction pipeline, pattern tag instructions
- [Source: CoachMe/Supabase/supabase/functions/chat-stream/index.ts] — Chat stream orchestration, parallel loading
- [Source: CoachMe/Supabase/supabase/functions/_shared/context-loader.ts] — Context and history loading patterns
- [Source: CoachMe/Supabase/supabase/migrations/20260207000001_pattern_syntheses.sql] — Pattern syntheses table schema
- **Migration naming:** This story uses `20260210000003_pattern_cache.sql`. The table name is `pattern_cache` (not `pattern_summaries`). Ensure all indexes, RLS policies, RPC docs, and code references use `pattern_cache` consistently.
- [Source: _bmad-output/planning-artifacts/epics.md#Story 8.1] — Learning signals dependency (learning_signals table, LearningSignalService)

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (claude-opus-4-6)

### Debug Log References

- Migration timestamp collision detected: `20260210000003` already taken by `push_tokens.sql`. Used `20260210000005` instead.
- Story 8.1 `learning_signals` table confirmed to exist — implemented full engagement tracking (no stub needed).
- `learning_signals` CHECK constraint updated to include `pattern_engaged` signal type in the same migration.

### Completion Notes List

- **Task 1**: Created `pattern-analyzer.ts` shared helper module with `generatePatternSummary()` entry point, session-count-based caching (3-session TTL via `pattern_cache` table), pattern ranking by frequency + recency + engagement, filtering (3+ occurrences, >= 0.85 confidence), max 3 patterns per prompt. Exported `PATTERN_ANALYZER_CONSTANTS` for testability.
- **Task 2**: Created migration `20260210000005_pattern_cache.sql` with `pattern_cache` table (UNIQUE on user_id for upsert), RLS policies (SELECT/INSERT/UPDATE), `get_session_count` RPC, and added `pattern_engaged` to learning_signals CHECK constraint.
- **Task 3**: Extended `prompt-builder.ts` with `PATTERNS_CONTEXT_INSTRUCTION` constant, added `patternSummaries` parameter to `buildCoachingPrompt()`, added `formatPatternSummaries()` function placed AFTER cross-domain patterns. Re-exported `PatternSummary` type. Added 11 new tests to `prompt-builder.test.ts`.
- **Task 4**: Integrated into `chat-stream/index.ts` — added `generatePatternSummary` to existing `Promise.all()` with `.catch()` for graceful degradation. Passed `patternSummaries` as 7th param to `buildCoachingPrompt()`.
- **Task 5**: Implemented `trackPatternEngagement()` in `chat-stream/index.ts` — scans rawHistory for [PATTERN: ...] tags, counts user messages after surfacing, records `pattern_engaged` learning signal when 2+ messages detected. Runs fire-and-forget (never blocks). Deduplicates via conversation_id + pattern_theme.
- **Task 6**: Created `pattern-analyzer-integration.test.ts` with 14 E2E tests covering all 6 scenarios: <5 sessions, 5+ sessions, cache hit, cache miss, graceful degradation, ranking order, and engagement detection logic.

### File List

New files:
- `CoachMe/Supabase/supabase/functions/_shared/pattern-analyzer.ts`
- `CoachMe/Supabase/supabase/functions/_shared/pattern-analyzer.test.ts`
- `CoachMe/Supabase/supabase/functions/_shared/pattern-analyzer-integration.test.ts`
- `CoachMe/Supabase/supabase/migrations/20260210000005_pattern_cache.sql`

Modified files:
- `CoachMe/Supabase/supabase/functions/_shared/prompt-builder.ts`
- `CoachMe/Supabase/supabase/functions/_shared/prompt-builder.test.ts`
- `CoachMe/Supabase/supabase/functions/chat-stream/index.ts`

## Senior Developer Review (AI)

**Reviewer**: Claude Opus 4.6 | **Date**: 2026-02-09 | **Outcome**: Approved (after fixes)

**Issues Found**: 3 High, 3 Medium, 2 Low — all HIGH and MEDIUM fixed automatically.

### Fixes Applied
1. **[H1] SECURITY**: `get_session_count` RPC was `SECURITY DEFINER` without auth guard — added `auth.uid() IS DISTINCT FROM p_user_id` check to prevent cross-user session count leaking
2. **[H2] DATA BUG**: `cacheSummaries` used `JSON.stringify(summaries)` for JSONB column causing double-serialization — changed to pass raw array
3. **[H3] LOGIC BUG**: Occurrence count summed all conversations per domain instead of actual pattern occurrences — changed to use `Math.max(evidence.length, surface_count)` from pattern_syntheses
4. **[M1] TEST QUALITY**: Unit tests reimplemented ranking logic inline instead of testing actual functions — exported `rankPatterns()` and `AggregatedPattern`, replaced tests with direct function calls
5. **[M2] RESILIENCE**: `learning_signals` query failure blocked all pattern generation — wrapped in try/catch with graceful fallback to empty signals
6. **[M3] PERFORMANCE**: `learning_signals` query loaded all rows without bounds — added `.limit(200)`

### Remaining Low Issues (acceptable)
- **[L1]** Mid-file imports in prompt-builder.test.ts — cosmetic only
- **[L2]** `trackPatternEngagement` only records first pattern theme — acceptable since prompt instructs max ONE pattern per response

## Change Log

- **2026-02-09**: Story 8.4 implementation complete. Added in-conversation pattern recognition engine: pattern-analyzer shared module, pattern_cache migration, PATTERNS_CONTEXT prompt section, chat-stream integration, pattern engagement tracking, and comprehensive E2E tests.
- **2026-02-09**: Code review fixes — 6 issues resolved: RPC security guard, JSONB double-serialization, occurrence count logic, test quality improvements, learning_signals resilience, query bounds.
