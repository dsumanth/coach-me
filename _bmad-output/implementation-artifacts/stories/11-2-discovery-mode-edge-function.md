# Story 11.2: Discovery Mode Edge Function

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **developer**,
I want **the chat-stream Edge Function to route between Haiku (discovery) and Sonnet (paid coaching) based on user state**,
So that **onboarding is cost-effective (~$0.035/user) while paid coaching is premium quality**.

## Acceptance Criteria

1. **Given** a user with `subscription_status = NULL` and `discovery_completed_at IS NULL`, **When** they send a message via chat-stream, **Then** the Edge Function uses `claude-haiku-4-5-20251001` with the discovery system prompt (from `buildDiscoveryPrompt()`).

2. **Given** a user with `subscription_status = 'trial'` or `subscription_status = 'active'`, **When** they send a message via chat-stream, **Then** the Edge Function uses `claude-sonnet-4-5-20250929` with the full coaching system prompt (existing `buildCoachingPrompt()`).

3. **Given** the discovery conversation reaches the `[DISCOVERY_COMPLETE]` signal in the AI's response, **When** the response is streamed to the client, **Then** the response includes a `discovery_complete: true` flag in SSE metadata AND the extracted context profile JSON, AND the Edge Function writes `discovery_completed_at = NOW()` to the user's `context_profiles` row.

4. **Given** a user who completed discovery (`discovery_completed_at IS NOT NULL`) but does NOT have a subscription (`subscription_status IS NULL`), **When** they attempt to send a message via chat-stream, **Then** the Edge Function returns a 403 response with `{ error: "subscription_required", discovery_completed: true }`.

5. **Given** a discovery conversation is in progress, **When** messages are exchanged, **Then** the conversation is stored with `type = 'discovery'` tag and usage is logged normally (model, tokens, cost) with the discovery model.

6. **Given** a user subscribes after discovery, **When** they send their first paid message in the same conversation thread, **Then** the Edge Function detects the subscription, switches to Sonnet + coaching prompt, and the conversation continues seamlessly in the same thread.

7. **When** a user subscribes mid-discovery (before `[DISCOVERY_COMPLETE]` is emitted) and sends subsequent messages in the same discovery thread, **Then** the Edge Function switches to `claude-sonnet-4-5-20250929` with `buildCoachingPrompt()`, keeps `discovery_completed_at` as `NULL` (discovery not marked complete), retains `conversation.type = 'discovery'`, and logs usage with the new model. (Ref: AC #6 for post-discovery subscription; this covers mid-discovery.)

8. **Given** crisis indicators are detected during a discovery conversation, **When** the AI responds, **Then** the existing crisis detection pipeline (Story 4.1) activates and crisis prompt overrides discovery prompt.

9. **Given** the discovery conversation is complete, **When** measuring cost, **Then** the total discovery cost per user is approximately $0.035 (12 messages x Haiku pricing at $0.25/$1.25 per MTok). _The 12-message estimate derives from the Story 11-1 discovery prompt design: 6 phases x ~2 exchanges (1 user + 1 AI) per phase, with average ~200 input tokens and ~300 output tokens per exchange based on product requirements for a concise discovery flow. Validate against real usage after launch and update the cost model if average message count differs._

## Tasks / Subtasks

- [x] Task 1: Database migrations for discovery mode (AC: #1, #4, #5)
  - [x] 1.1 Create migration `20260211000001_discovery_mode.sql`:
    - Add `discovery_completed_at TIMESTAMPTZ DEFAULT NULL` column to `context_profiles` table
    - Add `type TEXT DEFAULT 'coaching' CHECK (type IN ('coaching', 'discovery'))` column to `conversations` table
    - Create index `idx_conversations_type` on `conversations(type)`
    - Create index `idx_context_profiles_discovery` on `context_profiles(discovery_completed_at)` WHERE `discovery_completed_at IS NOT NULL`
  - [x] 1.2 Verify migration is idempotent (use `IF NOT EXISTS` patterns)

- [x] Task 2: Implement user state loading in chat-stream (AC: #1, #2, #4)
  - [x] 2.1 In `chat-stream/index.ts`, after auth verification (line ~32), query `users` table for `subscription_status` and `trial_ends_at`
  - [x] 2.2 Extend existing `context_profiles` query to include `discovery_completed_at` in the SELECT
  - [x] 2.3 Create `determineSessionMode()` function returning `'discovery' | 'coaching' | 'blocked'`:
    - `hasSubscription` (trial or active) -> `'coaching'`
    - `!discoveryDone` -> `'discovery'`
    - else -> `'blocked'`
    - **Expired-subscription routing note**: `determineSessionMode()` treats `subscription_status` values like `'expired'` as `hasSubscription = false`. Combined with a `NULL` `discovery_completed_at`, this routes former subscribers back into `'discovery'` mode. This is **intentional** — it lets lapsed users re-experience discovery rather than hitting a hard paywall. If product later wants to distinguish "never subscribed" vs "expired", consider setting `discovery_completed_at` when users first subscribe (to record "discovery skipped") and adding an `'expired'` check before the `!discoveryDone` branch. Key symbols: `determineSessionMode()`, `subscription_status` field, `discovery_completed_at` column.
  - [x] 2.4 If mode is `'blocked'`, return 403 with `{ error: "subscription_required", discovery_completed: true }` before any streaming logic

- [x] Task 3: Implement model routing and prompt selection (AC: #1, #2, #6, #7)
  - [x] 3.1 Replace hardcoded model (line ~283) with conditional: discovery -> `claude-haiku-4-5-20251001`, coaching -> `claude-sonnet-4-5-20250929`
  - [x] 3.2 Replace system prompt construction with conditional: discovery -> `buildDiscoveryPrompt(crisisDetected)`, coaching -> existing `buildCoachingPrompt(...)`
  - [x] 3.3 In discovery mode, SKIP expensive operations: domain classification, cross-domain patterns, pattern summaries, coaching preferences, style analysis, pattern engagement tracking. KEEP: crisis detection, conversation history, message persistence, usage logging
  - [x] 3.4 Ensure crisis detection still runs in discovery mode with crisis prompt overriding discovery prompt if `crisisDetected === true`

- [x] Task 4: Implement `[DISCOVERY_COMPLETE]` detection and processing (AC: #3)
  - [x] 4.1 After streaming completes, check for `[DISCOVERY_COMPLETE]` signal in `fullContent` using `hasDiscoveryComplete()` from prompt-builder.ts (Story 11-1)
  - [x] 4.2 If detected: extract profile JSON via `extractDiscoveryProfile()`, strip tags via `stripDiscoveryTags()`, set `discovery_completed_at = NOW()` on context_profiles, send SSE metadata with `discovery_complete: true` and extracted profile
  - [x] 4.3 Add `discovery_complete` flag to SSE event metadata (same pattern as `memory_moment` and `pattern_insight` flags on lines 318-326)

- [x] Task 5: Conversation type tagging (AC: #5, #6)
  - [x] 5.1 When creating a conversation in discovery mode, set `type = 'discovery'`
  - [x] 5.2 When loading conversation at start of chat-stream, include `type` field in SELECT
  - [x] 5.3 If conversation is 'discovery' type and user now has subscription, continue in same thread with coaching prompt/model

- [x] Task 6: Update usage logging for model tracking (AC: #8)
  - [x] 6.1 Verify `logUsage()` correctly logs the dynamically-selected model variable
  - [x] 6.2 Add Sonnet pricing to `calculateCost()` if missing: `'claude-sonnet-4-5-20250929': { input: 3.0, output: 15.0 }`
  - [x] 6.3 Add `// TODO(Epic-10): bypass message counting for discovery mode` comment

- [x] Task 7: Write tests (AC: #1-#8)
  - [x] 7.1 Test `determineSessionMode()` with all combinations: `(null, null)` -> discovery, `('trial', null)` -> coaching, `('active', null)` -> coaching, `(null, timestamp)` -> blocked, `('active', timestamp)` -> coaching, `('expired', null)` -> discovery, `('cancelled', null)` -> discovery
  - [x] 7.2 Test model selection: discovery -> Haiku, coaching -> Sonnet
  - [x] 7.3 Test blocked mode returns 403
  - [x] 7.4 Test `[DISCOVERY_COMPLETE]` SSE suppression (`computeVisibleContent`) and discovery→blocked flow — 9 tests in session-mode.test.ts; helper functions in prompt-builder.test.ts
  - [x] 7.5 Test conversation type tagging (`shouldUpdateConversationType`) — 6 tests in session-mode.test.ts
  - [x] 7.6 Test crisis override in discovery mode — covered by `buildDiscoveryPrompt(true)` tests in prompt-builder.test.ts (Story 11-1)

## Dev Notes

### Architecture & Patterns

- **Model routing is the PRIMARY purpose** -- Haiku for discovery, Sonnet for paid coaching. Core cost optimization making onboarding viable (~$0.035/user vs ~$0.50/user with Sonnet).
- **`users.subscription_status` already exists** in the DB with CHECK constraint: `('trial', 'active', 'expired', 'cancelled')`. NULL = no subscription. The Edge Function currently does NOT query this -- this story adds that query.
- **`context_profiles` is already loaded** in chat-stream/index.ts (line ~80-90). Add `discovery_completed_at` to the existing SELECT rather than a separate query.
- **`buildDiscoveryPrompt()` is created in Story 11-1** (dependency). If 11-1 is not yet implemented, create a stub: `export function buildDiscoveryPrompt(crisisDetected: boolean): string { return 'Discovery mode prompt stub'; }` and replace when 11-1 lands.
- **SSE metadata events** follow the existing pattern on lines 318-326 where `memory_moment` and `pattern_insight` flags are sent.
- **`conversations` table has no `type` column** currently. Migration adds it with default `'coaching'` so existing conversations are unaffected.

### Critical Implementation Details

1. **Discovery mode SKIPS expensive operations**: Domain classification, cross-domain patterns, pattern summaries, coaching preferences, style analysis, pattern engagement tracking. Both a performance optimization (fewer DB queries) and semantic (discovery has no coaching framework context yet).

2. **Discovery mode KEEPS**: Crisis detection (safety), conversation history (context continuity within discovery), message persistence (for later extraction by Story 11-4), usage logging (cost tracking).

3. **`determineSessionMode()` is the routing brain**:
   - Has active subscription -> coaching (always, regardless of discovery state)
   - No subscription + no discovery completed -> discovery (free)
   - No subscription + discovery completed -> blocked (must subscribe)
   - `expired` and `cancelled` count as "no active subscription"

4. **Sonnet model**: Use `claude-sonnet-4-5-20250929`. Verify the model ID exists in `calculateCost()` pricing and add if missing: `{ input: 3.0, output: 15.0 }`.

5. **After `[DISCOVERY_COMPLETE]` detected**: DB update AND SSE metadata happen in the post-stream phase (non-blocking). User-visible response sent first with discovery tags stripped.

### Existing Code References

| File | Lines | What's There | What Changes |
|------|-------|-------------|--------------|
| `chat-stream/index.ts` | ~32 | `verifyAuth(req)` | Add `users` table query after auth |
| `chat-stream/index.ts` | ~80-90 | `context_profiles` query | Add `discovery_completed_at` to SELECT |
| `chat-stream/index.ts` | ~283 | `const model = 'claude-haiku-...'` | Conditional model selection |
| `chat-stream/index.ts` | ~285-288 | `buildCoachingPrompt(...)` | Conditional prompt selection |
| `chat-stream/index.ts` | ~295-326 | Memory/pattern tag detection | Add `[DISCOVERY_COMPLETE]` detection |
| `chat-stream/index.ts` | ~379-391 | `logUsage(...)` | Verify model variable is dynamic |
| `_shared/prompt-builder.ts` | ~527-597 | Tag helpers pattern | Story 11-1 adds discovery helpers here |
| `_shared/llm-client.ts` | ~237-256 | `calculateCost()` pricing | Add Sonnet pricing if missing |

### Dependency Chain

```text
Story 11-1 (Discovery System Prompt) <-- THIS STORY DEPENDS ON 11-1
  Creates: buildDiscoveryPrompt(), hasDiscoveryComplete(),
           extractDiscoveryProfile(), stripDiscoveryTags()

Story 11-2 (THIS STORY)
  Consumes: buildDiscoveryPrompt() from 11-1
  Adds: Model routing, session mode detection, subscription check,
        [DISCOVERY_COMPLETE] processing, conversation type tagging

Story 11-3 (Onboarding Flow UI) <-- DEPENDS ON THIS STORY
  Consumes: discovery_complete SSE metadata, 403 blocked response

Story 11-4 (Discovery-to-Profile Pipeline) <-- DEPENDS ON THIS STORY
  Consumes: discovery_completed_at, extracted profile JSON
```

### Database Migration Details

```sql
-- Migration: 20260211000001_discovery_mode.sql

ALTER TABLE public.context_profiles
ADD COLUMN IF NOT EXISTS discovery_completed_at TIMESTAMPTZ DEFAULT NULL;

ALTER TABLE public.conversations
ADD COLUMN IF NOT EXISTS type TEXT DEFAULT 'coaching'
CHECK (type IN ('coaching', 'discovery'));

CREATE INDEX IF NOT EXISTS idx_context_profiles_discovery
ON public.context_profiles (discovery_completed_at)
WHERE discovery_completed_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_conversations_type
ON public.conversations (type);
```

### Model Pricing Reference

| Model | Input (per MTok) | Output (per MTok) | Use Case |
|-------|------------------|--------------------|----------|
| `claude-haiku-4-5-20251001` | $0.25 | $1.25 | Discovery (free onboarding) |
| `claude-sonnet-4-5-20250929` | $3.00 | $15.00 | Paid coaching |

### Epic 10 Integration (Future)

When Epic 10 (Message Rate Limiting) is implemented, discovery messages must NOT count against the 100-message trial limit. Epic 10 is currently `backlog`. Add a TODO comment for future integration.

### What This Story Does NOT Include

- **Discovery system prompt content** -- Story 11-1 (dependency)
- **iOS onboarding UI** (welcome screen, discovery flow) -- Story 11-3
- **Context profile extraction/population** from discovery data -- Story 11-4
- **Personalized paywall** -- Story 11-5
- **Message rate limiting or bypass** -- Epic 10

### Project Structure Notes

- All Edge Function changes in `CoachMe/Supabase/supabase/functions/`
- Migration in `CoachMe/Supabase/supabase/migrations/` (naming: `YYYYMMDD######_description.sql`)
- Tests follow existing patterns in `_shared/*.test.ts`
- No iOS code changes in this story -- SSE metadata consumed by Story 11-3

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Epic 11, Story 11.2]
- [Source: _bmad-output/planning-artifacts/architecture.md]
- [Source: _bmad-output/implementation-artifacts/stories/11-1-discovery-session-system-prompt.md]
- [Source: CoachMe/Supabase/supabase/functions/chat-stream/index.ts]
- [Source: CoachMe/Supabase/supabase/functions/_shared/prompt-builder.ts]
- [Source: CoachMe/Supabase/supabase/functions/_shared/llm-client.ts]
- [Source: supabase/migrations/20260205000001_initial_schema.sql]
- [Source: supabase/migrations/20260207000001_context_profiles.sql]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

No errors encountered during implementation.

### Implementation Plan

Restructured `chat-stream/index.ts` into a branching pipeline based on `sessionMode` (discovery vs coaching). Discovery mode runs a minimal pipeline (crisis detection + discovery prompt + Haiku) while coaching mode runs the full pipeline (all context loading, domain routing, patterns, reflections, style + Sonnet). Extracted `determineSessionMode()` into `_shared/session-mode.ts` for testability since `chat-stream/index.ts` calls `serve()` at import time.

### Completion Notes List

- **Task 1**: Created idempotent migration `20260211000001_discovery_mode.sql` adding `discovery_completed_at` column to `context_profiles` and `type` column (with CHECK constraint) to `conversations`, plus two indexes.
- **Task 2**: Added `users` table query for `subscription_status` after auth. Added separate `context_profiles` query for `discovery_completed_at`. Created `determineSessionMode()` in `_shared/session-mode.ts` with routing logic: trial/active → coaching, no subscription + no discovery → discovery, no subscription + discovery done → blocked. Blocked mode returns 403 with `{ error: "subscription_required", discovery_completed: true }`.
- **Task 3**: Discovery mode uses `claude-haiku-4-5-20251001` with `buildDiscoveryPrompt(crisisDetected)`. Coaching mode uses `claude-sonnet-4-5-20250929` with full `buildCoachingPrompt(...)`. Discovery mode skips domain classification, cross-domain patterns, pattern summaries, coaching preferences, style analysis, and pattern engagement tracking. Crisis detection runs in both modes (safety).
- **Task 4**: Added `[DISCOVERY_COMPLETE]` detection in streaming loop via `hasDiscoveryComplete()`. Post-stream processing extracts profile JSON via `extractDiscoveryProfile()`, strips tags via `stripDiscoveryTags()`, sets `discovery_completed_at = NOW()` on `context_profiles` (non-blocking), and includes `discovery_complete: true` + `discovery_profile` in SSE done event metadata.
- **Task 5**: Conversations in discovery mode are tagged with `type = 'discovery'` (non-blocking update). Conversation `type` field included in SELECT. If conversation is discovery type and user now has subscription, the pipeline routes to coaching mode seamlessly (AC #6, #7).
- **Task 6**: Added Sonnet pricing `'claude-sonnet-4-5-20250929': { input: 3.0, output: 15.0 }` to `calculateCost()` in `llm-client.ts`. Verified `logUsage()` uses dynamic `model` variable. Added `// TODO(Epic-10): bypass message counting for discovery mode` comment.
- **Task 7**: Created `session-mode.test.ts` with 30 unit tests. 17 tests for `determineSessionMode()` covering all subscription/discovery state combinations. 6 tests for `shouldUpdateConversationType()` covering discovery/coaching/blocked modes with all conversation type states. 7 tests for `computeVisibleContent()` covering SSE suppression: no block, chunk before/within/straddling block, boundary alignment, empty chunk, and 2 flow tests for discovery→blocked→coaching lifecycle. Discovery tag helpers tested in prompt-builder.test.ts (Story 11-1).

### File List

| Action | File |
|--------|------|
| NEW | `CoachMe/Supabase/supabase/migrations/20260211000001_discovery_mode.sql` |
| NEW | `CoachMe/Supabase/supabase/functions/_shared/session-mode.ts` |
| NEW | `CoachMe/Supabase/supabase/functions/_shared/session-mode.test.ts` |
| MODIFIED | `CoachMe/Supabase/supabase/functions/chat-stream/index.ts` |
| MODIFIED | `CoachMe/Supabase/supabase/functions/_shared/llm-client.ts` |

## Change Log

- **2026-02-10**: Story 11.2 implementation complete. Added discovery mode routing to chat-stream Edge Function: `determineSessionMode()` routes users to Haiku (discovery), Sonnet (coaching), or 403 (blocked) based on subscription state and discovery completion. Restructured pipeline to skip expensive operations in discovery mode. Added `[DISCOVERY_COMPLETE]` detection with profile extraction and SSE metadata. Added conversation type tagging, Sonnet pricing, and 17 unit tests.
- **2026-02-10 (Review)**: Adversarial code review found 3 HIGH, 3 MEDIUM, 1 LOW issues. Fixed: (H1) `[DISCOVERY_COMPLETE]` block now suppressed from SSE streaming tokens via `computeVisibleContent()`; (H2) Extracted `shouldUpdateConversationType()` and `computeVisibleContent()` into session-mode.ts with 15 new tests (6 + 7 + 2 flow); (H3) `discovery_completed_at` DB update changed from fire-and-forget to awaited; (M2) `ConversationRow` interface replaces inline type assertions; (M3) Test count corrected. Total tests: 30 (was 17).
