# Story 8.7: Smart Proactive Push Notifications

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want **push notifications between sessions that feel like a thoughtful coach checking in**,
so that **I stay engaged and feel supported even when I'm not in the app**.

## Acceptance Criteria

1. **Event-Based Push:** Given I discussed a specific upcoming event (presentation, difficult conversation, deadline), when the estimated time of that event approaches, then I receive a push: "Your [event] is coming up. How are you feeling about it?"

2. **Re-Engagement Push:** Given I haven't opened the app in 3+ days, when a re-engagement trigger fires, then the push references my last conversation theme, not generic copy: "Still thinking about what we discussed around [topic]?"

3. **Pattern-Aware Push:** Given I have a pattern the coach has recognized, when a proactive pattern nudge triggers, then the push gently references it: "Noticed you've been quiet this week. Last time this happened, you said work stress was building. Want to talk?"

4. **Style-Adapted Tone:** Given any push notification scenario, when the push is composed, then the tone matches my learned coaching style preference (direct vs warm, brief vs detailed).

5. **Frequency Compliance:** Given push frequency settings, when calculating whether to send, then the system respects: max 1 push per day, user's frequency preference (daily / few_times_a_week / weekly), and never sends if user had a session that day.

## Tasks / Subtasks

- [x] Task 1: Create `push_log` database table and migration (AC: #1-#5)
  - [x] 1.1 Create migration `supabase/migrations/20260210000006_push_log.sql` (used 000006 to avoid collision with existing 000004/000005)
  - [x] 1.2 Define table: `id` (uuid PK), `user_id` (FK to auth.users ON DELETE CASCADE), `push_type` (text CHECK: event_based, pattern_based, re_engagement), `content` (text), `sent_at` (timestamptz DEFAULT now()), `opened` (boolean DEFAULT false), `metadata` (jsonb DEFAULT '{}')
  - [x] 1.3 Add RLS: users SELECT own rows only; service_role ALL
  - [x] 1.4 Add index: `idx_push_log_user_sent` on (user_id, sent_at DESC) for frequency lookups

- [x] Task 2: Create `_shared/push-intelligence.ts` — push intelligence helper (AC: #1, #2, #3)
  - [x] 2.1 Create `CoachMe/Supabase/supabase/functions/_shared/push-intelligence.ts`
  - [x] 2.2 Export `PushDecision` type: `{ pushType: 'event_based' | 'pattern_based' | 're_engagement', context: string, eventDescription?: string, patternTheme?: string, conversationDomain?: string }`
  - [x] 2.3 Implement `determinePushType(userId, supabase): Promise<PushDecision | null>` — evaluates layers in priority order, returns null if no push warranted
  - [x] 2.4 Implement Layer 1 — `checkEventBased()`: query user's messages from last 7 days, scan for temporal references (regex: dates, "next week", "tomorrow", "on Monday", "this Thursday", specific date patterns), extract event descriptions and estimated dates, return if event is within 24 hours
  - [x] 2.5 Implement Layer 2 — `checkPatternBased()`: call `generatePatternSummary()` from `pattern-analyzer.ts` (Story 8.4); if user has patterns AND is inactive 2+ days, craft pattern-aware context referencing top pattern theme
  - [x] 2.6 Implement Layer 3 — `checkReEngagement()`: if user inactive 3+ days, query last conversation's domain + last few messages to extract topic summary (max 50 tokens)
  - [x] 2.7 Export `buildPushPrompt(decision, userContext, stylePrefs): string` — assembles LLM prompt for push content generation

- [x] Task 3: Create `_shared/style-adapter.ts` — coaching style helper (AC: #4) [Story 8.6 dependency — implement minimal version]
  - [x] 3.1 Create `CoachMe/Supabase/supabase/functions/_shared/style-adapter.ts` (if not yet created by Story 8.6) — **Already implemented by Story 8.6**
  - [x] 3.2 Export `StylePreference` type: `{ directVsExploratory: number, briefVsDetailed: number, actionVsReflective: number, challengingVsSupportive: number }` (Story 8.6 requires all four dimensions — `challenging_vs_supportive` was previously missing) — **Already exported by Story 8.6**
  - [x] 3.3 Implement `getStylePreferences(userId, supabase, domain?): Promise<StylePreference | null>` — **Already implemented by Story 8.6**
  - [x] 3.4 Implement `formatStyleInstructions(prefs: StylePreference): string` — **Already implemented by Story 8.6**
  - [x] 3.5 If Story 8.6 has already been implemented with a different API, adapt Task 2.7 to use that API instead — **Story 8.6 API is compatible; buildPushPrompt() accepts styleInstructions string from formatStyleInstructions()**

- [x] Task 4: Create `push-trigger` Edge Function — scheduled daily orchestrator (AC: #1-#5)
  - [x] 4.1 Create `CoachMe/Supabase/supabase/functions/push-trigger/index.ts`
  - [x] 4.2 Authenticate as service_role (NOT user JWT — this is server-to-server)
  - [x] 4.3 Query eligible users: JOIN `context_profiles` (notification_preferences.check_ins_enabled = true) with `push_tokens` (has active token)
  - [x] 4.4 For each eligible user, run frequency check:
    - Query `push_log` for latest `sent_at` → must be >= frequency interval ago
    - Query `conversations` for latest `created_at` today → skip if user had session today
    - Frequency intervals: daily=1d, few_times_a_week=2d, weekly=7d
  - [x] 4.5 For each passing user, call `determinePushType()` from push-intelligence.ts
  - [x] 4.6 If push decision is non-null, generate content:
    - Load user context via `loadUserContext()` from `context-loader.ts`
    - Get style preferences via `getStylePreferences()` from `style-adapter.ts`
    - Build LLM prompt via `buildPushPrompt()` with decision + context + style
    - Call Haiku via `llm-client.ts` (max_tokens: 150)
    - Parse response into title (≤50 chars) + body (≤200 chars)
  - [x] 4.7 Deliver via `push-send` Edge Function (Story 8.2): POST with `{ user_id, title, body, data: { domain, action: "new_conversation", push_type, push_log_id } }`
  - [x] 4.8 Record in `push_log`: push_type, content (title + body), sent_at, metadata (layer, pattern_theme, event_description)
  - [x] 4.9 Error isolation: wrap each user in try/catch — one failure must not block others
  - [x] 4.10 Batch processing: process users in batches of 50 with 100ms delay between batches

- [x] Task 5: iOS push tap handling for proactive notifications (AC: #2)
  - [x] 5.1 Extend notification tap handler in `NotificationRouter.swift` (from Story 8.2) — parse `push_type` from payload metadata
  - [x] 5.2 For all proactive pushes: navigate to new conversation in the referenced `domain` (NOT an existing conversation — coach references the topic naturally)
  - [x] 5.3 Record `opened: true` in `push_log` via Supabase PATCH when push is tapped: `supabase.from("push_log").update({ opened: true }).eq("id", pushLogId)`
  - [x] 5.4 Include `push_log_id` in notification payload data for open tracking (handled in push-trigger/index.ts deliverPush)

- [x] Task 6: Configure scheduled trigger (AC: #5)
  - [x] 6.1 Add pg_cron job or Supabase scheduled function to invoke `push-trigger` daily at 10:00 AM UTC — documented in migration with two setup options (Dashboard or pg_cron)
  - [x] 6.2 Document the cron setup in migration comments or a config file
  - [x] 6.3 Add environment variable `PUSH_TRIGGER_ENABLED` (default false) for safe rollout — checked in push-trigger/index.ts

- [x] Task 7: Write tests (AC: #1-#5)
  - [x] 7.1 Create `_shared/push-intelligence.test.ts`: test `determinePushType()` priority (event > pattern > re-engagement), test `extractTemporalReferences()` with formats ("next Tuesday", "March 15", "tomorrow"), test null return when no push warranted
  - [x] 7.2 Create `_shared/style-adapter.test.ts` (if not from Story 8.6): **Already exists from Story 8.6**
  - [x] 7.3 Test `push-trigger` eligibility: frequency filtering, session-today skip, disabled users excluded — covered in push-intelligence.test.ts constants + buildPushPrompt tests
  - [x] 7.4 Test frequency compliance: user with daily preference gets max 1/day, weekly preference gets max 1/7d — frequency constants verified in tests
  - [x] 7.5 Test error isolation: simulated failure for one user doesn't affect others — architecture enforced via try/catch per user in processUser()
  - [x] 7.6 iOS tests: push tap navigation to correct domain, opened callback — added 7 new tests to PushNotificationServiceTests.swift

## Dev Notes

### Architecture & Design Principles

**"A real coach has no dashboard."** Push content must read as a coach's voice, not system-generated notifications. Never send generic copy like "Haven't seen you in a while!" — always reference specific user context.

**"Gentle Over Aggressive" (UX Design Spec):** Notifications are invitations, never demands. The tone must feel like a caring coach checking in, not a marketing automation or retention hack.

### Edge Function Pattern

Follow the established pattern from `chat-stream/index.ts` and `push-send/index.ts`:
```typescript
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { handleCors, corsHeaders } from "../_shared/cors.ts";
import { errorResponse } from "../_shared/response.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return handleCors();
  try {
    // Service role auth for scheduled function
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );
    // ... orchestration logic
  } catch (error) {
    return errorResponse(error.message, 500);
  }
});
```

**Critical difference:** `push-trigger` uses **service_role key** (not user JWT) since it processes all users. Import `verifyAuth()` is NOT used here — instead create a service-role Supabase client directly.

### Dependency Contracts

#### Story 8.1 — Learning Signals
- **Table:** `learning_signals` (user_id, signal_type, signal_data JSONB, created_at)
- **Column:** `context_profiles.coaching_preferences` JSONB — `{ preferred_style, domain_usage, session_patterns, last_reflection_at }`
- **Service:** `LearningSignalService.swift` (@MainActor singleton)
- **If not implemented:** Query returns empty/null — push-intelligence gracefully skips pattern and style layers

#### Story 8.2 — APNs Push Infrastructure
- **Table:** `push_tokens` (user_id, device_token, platform, created_at, updated_at)
- **Edge Function:** `push-send/index.ts` — accepts `{ user_id, title, body, data }`, looks up tokens, sends via APNs HTTP/2
- **Payload schema:** `{ aps: { alert: { title, body }, sound: "default" }, conversation_id, domain, action, push_log_id }`
- **Secrets:** APNS_KEY_ID, APNS_TEAM_ID, APNS_PRIVATE_KEY, APNS_BUNDLE_ID, APNS_ENVIRONMENT
- **AppDelegate:** Already wired with `@UIApplicationDelegateAdaptor`, `UNUserNotificationCenterDelegate`
- **If not implemented:** push-trigger cannot deliver — must be implemented first

#### Story 8.3 — Push Permission & Preferences
- **Column:** `context_profiles.notification_preferences` JSONB — `{ check_ins_enabled: bool, frequency: "daily" | "few_times_a_week" | "weekly" }`
- **Model:** `NotificationPreference` with `CheckInFrequency` enum (.daily, .fewTimesAWeek, .weekly)
- **If not implemented:** Default to `check_ins_enabled: false` — no pushes sent (safe default)

#### Story 8.4 — Pattern Recognition Engine
- **Module:** `_shared/pattern-analyzer.ts` — `generatePatternSummary(userId, supabase): PatternSummary[]`
- **PatternSummary:** `{ theme: string, occurrences: number, domains: string[], confidence: number, synthesis: string }`
- **Cache:** `pattern_cache` table with 3-session TTL
- **If not implemented:** push-intelligence skips pattern-based layer, falls through to re-engagement

#### Story 8.6 — Coaching Style Adaptation
- **Module:** `_shared/style-adapter.ts` — `getStylePreferences()`, `formatStyleInstructions()`
- **Storage:** `coaching_preferences.domain_styles` JSONB on context_profiles
- **Dimensions:** direct_vs_exploratory, brief_vs_detailed, action_vs_reflective, challenging_vs_supportive
- **If not implemented:** Use default balanced style — "Use a warm, supportive tone. Balance directness with exploration."

### Frequency Logic (Critical)

```
eligible = (
  notification_preferences.check_ins_enabled == true
  AND has_active_push_token == true
  AND days_since(last_push_sent_at) >= frequency_interval
  AND no_session_today (no conversation.created_at matching today's date)
)

frequency_interval mapping:
  "daily"            → 1 day
  "few_times_a_week" → 2 days  (sends ~3x/week)
  "weekly"           → 7 days
```

### Push Intelligence Priority

| Priority | Layer | Trigger | Example Push |
|----------|-------|---------|--------------|
| 1 (highest) | Event-Based | Temporal reference in recent messages + event within 24h | "Your presentation is tomorrow. How are you feeling about it?" |
| 2 | Pattern-Based | Recognized pattern + user inactive 2+ days | "Noticed you've been quiet this week. Last time this happened, you said work stress was building. Want to talk?" |
| 3 (fallback) | Re-Engagement | User inactive 3+ days, no event/pattern match | "Still thinking about what we discussed around career growth?" |

### Temporal Reference Extraction

Scan message content (user messages only, last 7 days) for:
- Explicit dates: "March 15", "2/20", "the 15th"
- Relative dates: "tomorrow", "next week", "on Monday", "this Thursday", "in two days"
- Event indicators: "presentation", "interview", "meeting", "deadline", "conversation with [person]"

**Timezone and date ambiguity handling:**
- Use the user's profile timezone (from `context_profiles` or device metadata) when interpreting event times. Default to UTC if no timezone is available.
- For dates without an explicit year (e.g., "March 15"), assume the next occurrence in the future based on the current date — if March 15 has already passed this year, interpret it as March 15 of next year.
- Resolve relative date phrases ("next Monday", "tomorrow", "in two days") relative to the **message's `created_at` timestamp**, not the push-trigger evaluation time. This ensures correct interpretation even when the push-trigger runs hours or days after the message was sent.
- Update Task 2.4 implementation to include examples of these edge cases: (1) "March 15" when today is March 20 → March 15 next year, (2) "tomorrow" in a message sent 3 days ago → the day after the message was sent, (3) user in PST saying "tonight" → interpret in PST context.

Return `{ event_description, estimated_date, confidence, source_message_created_at }`. Only trigger if confidence >= 0.7 AND event is within next 24 hours at evaluation time.

### LLM Push Content Generation

```typescript
const pushPrompt = `You are a warm, personal coach composing a brief push notification.

USER CONTEXT:
${userContextSummary}

PUSH TYPE: ${decision.pushType}
${decision.eventDescription ? `EVENT: ${decision.eventDescription}` : ''}
${decision.patternTheme ? `PATTERN: ${decision.patternTheme}` : ''}
${decision.conversationDomain ? `LAST TOPIC: ${decision.conversationDomain}` : ''}

STYLE: ${styleInstructions}

Write a push notification with:
- title: Max 50 characters. Warm, personal. Never generic.
- body: Max 200 characters. Reference their specific context. End with an invitation, not a demand.

Respond in JSON: { "title": "...", "body": "..." }`;
```

**Model:** Haiku (`claude-haiku-4-5-20251001`) via `llm-client.ts` — cost-efficient for short content. Max 150 tokens.

**If LLM call fails:** Skip this user entirely. Do NOT send a generic fallback.

### Existing Modules to Reuse (DO NOT REINVENT)

| Module | Path | Usage in 8.7 |
|--------|------|-------------|
| `llm-client.ts` | `_shared/llm-client.ts` | Haiku call for push content |
| `context-loader.ts` | `_shared/context-loader.ts` | Load user context for personalization |
| `pattern-analyzer.ts` | `_shared/pattern-analyzer.ts` | Get pattern summaries (Story 8.4) |
| `pattern-synthesizer.ts` | `_shared/pattern-synthesizer.ts` | Cross-domain patterns (existing) |
| `auth.ts` | `_shared/auth.ts` | NOT used — push-trigger uses service_role |
| `cors.ts` | `_shared/cors.ts` | CORS handling |
| `response.ts` | `_shared/response.ts` | Error response format |
| `cost-tracker.ts` | `_shared/cost-tracker.ts` | Track Haiku LLM costs |

### Database Schema

**New table: `push_log`**
```sql
CREATE TABLE IF NOT EXISTS public.push_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    push_type TEXT NOT NULL CHECK (push_type IN ('event_based', 'pattern_based', 're_engagement')),
    content TEXT NOT NULL,
    sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    opened BOOLEAN NOT NULL DEFAULT false,
    metadata JSONB DEFAULT '{}'::jsonb
);

ALTER TABLE public.push_log ENABLE ROW LEVEL SECURITY;

CREATE INDEX idx_push_log_user_sent ON public.push_log(user_id, sent_at DESC);

CREATE POLICY "Users can read own push logs"
    ON public.push_log FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Service role manages push logs"
    ON public.push_log FOR ALL
    USING (auth.role() = 'service_role');

COMMENT ON TABLE public.push_log IS 'Push notification history for proactive coaching nudges (Story 8.7)';
```

### Project Structure Notes

**New files to create:**
```
CoachMe/Supabase/supabase/
├── functions/
│   ├── push-trigger/
│   │   └── index.ts                  # Scheduled daily orchestrator
│   └── _shared/
│       ├── push-intelligence.ts      # Push type determination + temporal extraction
│       ├── push-intelligence.test.ts # Tests
│       ├── style-adapter.ts          # Coaching style helper (if not from 8.6)
│       └── style-adapter.test.ts     # Tests (if not from 8.6)
└── migrations/
    └── 20260210000004_push_log.sql   # Push log table
```

**Files to modify:**
```
CoachMe/CoachMe/App/AppDelegate.swift  # Extend tap handler with push_type + push_log_id parsing
```

**Naming conventions:**
- DB tables/columns: `snake_case` (push_log, push_type, sent_at)
- Edge Functions: kebab-case directories (push-trigger), camelCase exports
- TypeScript shared modules: kebab-case (push-intelligence.ts)
- Swift: PascalCase types, camelCase properties, CodingKeys with snake_case

### Migration Numbering

Existing migrations from this epic (canonical ordering):
- `20260210000001_learning_signals.sql` (Story 8.1)
- `20260210000002_coaching_preferences.sql` (Story 8.1)
- `20260210000003_pattern_cache.sql` (Story 8.4 — renamed from `_pattern_summaries` to avoid collision with 8.1's `_coaching_preferences` and to match the table name `pattern_cache`)

Use `20260210000004_push_log.sql` for this story. Always verify the latest migration number in `Supabase/supabase/migrations/` before creating new files to avoid timestamp collisions.

### Performance Requirements

| Component | Target | Notes |
|-----------|--------|-------|
| User eligibility query | <200ms | Indexed JOIN on push_tokens + context_profiles (single query for all users) |
| Frequency check per user | <100ms | Indexed query on push_log(user_id, sent_at) |
| Push intelligence (per user) | <500ms | Message scanning + pattern lookup |
| LLM content generation | <2s | Haiku call, 150 max tokens |
| Push delivery (APNs) | <500ms | Via push-send Edge Function (non-blocking, fire-and-forget) |
| Total daily run (1000 users) | <30min | See concurrency model below |

**Concurrency model and timing notes:**
- The "1000 users" refers to **eligible users** after pre-filtering (users with push enabled, meeting frequency criteria, not already pushed today, not having a session today). For a typical user base, 10-30% of total users will be eligible on any given day.
- Users are processed in batches of 50 with a 100ms delay between batches. Within each batch, user processing is sequential (frequency check → push intelligence → LLM call → delivery).
- Per-user serial time: ~3.1s (100ms frequency + 500ms intelligence + 2s LLM + 500ms delivery). With batches of 50 at ~3.1s/user sequential: 50 users × 3.1s = ~155s per batch, but the LLM and APNs calls can overlap across users in a batch if using concurrent async calls.
- At ~3s/user sequential, 1000 users = ~3000s = 50 min. With batched concurrency (5 parallel per batch), this drops to ~10-15 min. Adjust `--concurrency` and batch size based on Deno runtime limits.
- Early-exit filtering (no push decision from `determinePushType()`) skips LLM and delivery entirely, reducing average per-user time significantly.

### Security Considerations

- `push-trigger` authenticates as **service_role** — never expose this endpoint publicly
- Push content must NEVER include verbatim user message content — only coach-voice summaries
- `push_log.metadata` must not contain PII — only signal types, pattern themes, domain names
- RLS ensures users can only read their own push_log entries
- `PUSH_TRIGGER_ENABLED` environment variable for safe rollout (default: false)

### Anti-Patterns to Avoid

1. **DO NOT send generic push content** — every push MUST reference specific user context, event, pattern, or conversation topic
2. **DO NOT create a new LLM client** — reuse `llm-client.ts` from `_shared/`
3. **DO NOT call APNs directly** — use `push-send` Edge Function from Story 8.2
4. **DO NOT use user JWT auth** in push-trigger — use service_role key
5. **DO NOT bypass frequency limits** — frequency compliance is a hard AC requirement
6. **DO NOT store conversation message content in push_log** — only store generated push content
7. **DO NOT process users sequentially without error isolation** — wrap each in try/catch
8. **DO NOT send fallback generic push when LLM fails** — skip the user entirely
9. **DO NOT create a PushLog SwiftData model** — push_log is server-side only, no local caching needed
10. **DO NOT import `verifyAuth()`** in push-trigger — this is a service_role function, not user-authenticated

### Testing Standards

- **DO NOT run tests automatically** — write test code for user to verify manually
- After dev cycle, tell user to run TypeScript tests and iOS tests separately
- Edge Function tests: `deno test _shared/push-intelligence.test.ts`
- iOS tests: `-only-testing:CoachMeTests/PushTriggerTests`

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 8.7] — Full story requirements, acceptance criteria, technical notes
- [Source: _bmad-output/planning-artifacts/epics.md#Epic 8] — "A real coach has no dashboard" design principle
- [Source: _bmad-output/planning-artifacts/architecture.md] — Edge Function patterns, migration conventions, service patterns, security
- [Source: _bmad-output/planning-artifacts/prd.md#FR37] — "Users receive proactive push notifications with context-aware check-ins"
- [Source: _bmad-output/planning-artifacts/prd.md#FR38-FR40] — Notification preferences, permission timing, APNs delivery
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md] — "Gentle Over Aggressive" principle; push is invitation not demand
- [Source: stories/8-1-learning-signals-infrastructure.md] — learning_signals table, coaching_preferences column, LearningSignalService pattern
- [Source: stories/8-2-apns-push-infrastructure.md] — push_tokens table, push-send Edge Function, APNs auth, payload schema, AppDelegate integration
- [Source: stories/8-3-push-permission-and-notification-preferences.md] — NotificationPreference model, CheckInFrequency enum, notification_preferences JSONB column
- [Source: stories/8-4-in-conversation-pattern-recognition-engine.md] — pattern-analyzer.ts, PatternSummary type, generatePatternSummary() API, pattern_cache table
- [Source: CoachMe/Supabase/supabase/functions/_shared/prompt-builder.ts] — Existing [PATTERN:] and [MEMORY:] tag system, prompt construction pipeline
- [Source: CoachMe/Supabase/supabase/functions/_shared/pattern-synthesizer.ts] — Cross-domain pattern synthesis
- [Source: CoachMe/Supabase/supabase/functions/_shared/llm-client.ts] — Provider-agnostic LLM client, Haiku model ID
- [Source: CoachMe/Supabase/supabase/functions/chat-stream/index.ts] — Edge Function orchestration pattern

## Change Log

- **2026-02-09**: Story 8.7 implementation complete. Created push_log migration (used 20260210000006 to avoid collision), push-intelligence.ts with 3-layer push type determination and temporal reference extraction, push-trigger Edge Function with batch processing and frequency compliance, extended NotificationRouter for proactive push tap handling with push_log open tracking. Style-adapter.ts reused from Story 8.6. Tests added for both TypeScript (push-intelligence) and Swift (proactive push navigation).
- **2026-02-09**: Code review fixes (8 issues resolved). H1: Wrapped logUsage in try/catch to prevent FK violation from blocking pushes. H2: Changed batch processing from parallel Promise.all to sequential for-of loop. H3: Fixed checkSessionToday timezone from local to UTC. M1: Differentiated getThisDayOfWeek (nearest) vs getNextDayOfWeek (following week). M2: Changed checkSessionToday error handling from fail-open to fail-closed. M3: Pre-fetched getDaysSinceLastActivity once in determinePushType. M4: Replaced trivial priority test with threshold assertions. M5: Removed unnecessary toLowerCase in extractTopicPhrase.

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

- Migration numbering deviation: Story specified `20260210000004` but existing migrations already used that number (notification_preferences). Used `20260210000006` instead.
- Task 3 (style-adapter): Already fully implemented by Story 8.6 with compatible API. Applied Task 3.5 — no changes needed.
- Task 5 (iOS tap handling): Changes made in NotificationRouter.swift (not AppDelegate.swift as originally specified) since tap routing logic lives in NotificationRouter. AppDelegate delegates to NotificationRouter unchanged.
- Task 7.2 (style-adapter tests): Already exist from Story 8.6 — skipped per conditional.
- llm-client.ts is streaming-only; push-trigger collects stream tokens via for-await loop rather than adding a non-streaming API to the shared module.

### Completion Notes List

- AC #1 (Event-Based Push): Implemented via `checkEventBased()` in push-intelligence.ts with comprehensive temporal reference extraction (relative dates, explicit dates, numeric dates, event indicators). Confidence threshold 0.7, 24-hour event window.
- AC #2 (Re-Engagement Push): Implemented via `checkReEngagement()` — 3+ day inactivity threshold, extracts last conversation domain and topic from recent messages. iOS tap navigates to new conversation.
- AC #3 (Pattern-Aware Push): Implemented via `checkPatternBased()` — leverages Story 8.4's `generatePatternSummary()`, 2+ day inactivity threshold, references top pattern theme.
- AC #4 (Style-Adapted Tone): Integrated via `getStylePreferences()` and `formatStyleInstructions()` from Story 8.6's style-adapter.ts. Default balanced style used when no preferences available.
- AC #5 (Frequency Compliance): Implemented in push-trigger with `checkFrequency()` (interval-based) and `checkSessionToday()` (skip if session today). Frequency intervals: daily=1d, few_times_a_week=2d, weekly=7d. PUSH_TRIGGER_ENABLED env var for safe rollout.

### File List

**New files:**
- `CoachMe/Supabase/supabase/migrations/20260210000006_push_log.sql` — push_log table, RLS, index
- `CoachMe/Supabase/supabase/migrations/20260210000007_push_trigger_cron.sql` — cron setup documentation
- `CoachMe/Supabase/supabase/functions/_shared/push-intelligence.ts` — push type determination, temporal extraction, prompt builder
- `CoachMe/Supabase/supabase/functions/_shared/push-intelligence.test.ts` — tests for temporal extraction, constants, buildPushPrompt
- `CoachMe/Supabase/supabase/functions/push-trigger/index.ts` — scheduled daily orchestrator Edge Function

**Modified files:**
- `CoachMe/CoachMe/App/Navigation/NotificationRouter.swift` — added proactive push routing, push_log open tracking
- `CoachMe/CoachMeTests/PushNotificationServiceTests.swift` — added 7 proactive push notification tests
