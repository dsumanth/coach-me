# Story 10.1: Message Rate Limiting Infrastructure

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **developer**,
I want **server-side message rate limiting enforced per billing cycle**,
so that **costs are bounded and margins are protected at every usage tier**.

## Acceptance Criteria

1. **Given** a paid subscriber **When** they send a message **Then** the system checks their message count against the 800/month limit before processing

2. **Given** a trial user **When** they send a message **Then** the system checks their message count against the 100-message trial limit before processing

3. **Given** a user has reached their message limit **When** they try to send another message **Then** the Edge Function returns a `rate_limited` response with remaining time until reset (paid) or upgrade CTA (trial)

4. **Given** a new billing cycle begins (paid) or trial starts **When** the counter resets **Then** the message count resets to 0 and the user can send messages again

5. **Given** the rate limit is hit **When** the client receives the `rate_limited` response **Then** the send button is disabled and a warm message appears: "We've had a lot of great conversations this month! Your next session refreshes on [date]." (paid) or "You've used your trial sessions — ready to continue? [Subscribe]" (trial)

6. **Given** a discovery session is active (`sessionMode === 'discovery'`) **When** the user sends a message **Then** the rate limiter is bypassed entirely — discovery messages do NOT count against any limit

## Tasks / Subtasks

- [x] Task 1: Create `message_usage` database table and migration (AC: #1, #2, #4)
  - [x] 1.1 Create migration file `CoachMe/Supabase/supabase/migrations/20260211000003_message_usage.sql`
  - [x] 1.2 Define `message_usage` table: `id` (UUID PK), `user_id` (UUID FK → users), `billing_period` (TEXT, e.g. 'YYYY-MM' for paid or 'trial' for trial), `message_count` (INTEGER DEFAULT 0), `limit_amount` (INTEGER), `updated_at` (TIMESTAMPTZ DEFAULT NOW())
  - [x] 1.3 Add unique constraint on `(user_id, billing_period)` — one row per user per period
  - [x] 1.4 Add index on `(user_id, billing_period)` for fast lookups
  - [x] 1.5 Enable RLS — SELECT policy for `auth.uid() = user_id`, no direct INSERT/UPDATE (use RPC only)
  - [x] 1.6 Mirror migration to `supabase/migrations/20260211000005_message_usage.sql` (root deploy path)

- [x] Task 2: Create `increment_and_check_usage` Supabase RPC function (AC: #1, #2, #3, #4)
  - [x] 2.1 Add RPC to the same migration file (or separate `20260211000004_message_usage_rpc.sql`)
  - [x] 2.2 Function signature: `increment_and_check_usage(p_user_id UUID, p_billing_period TEXT, p_limit INTEGER) RETURNS JSONB`
  - [x] 2.3 Implement atomic upsert + increment: INSERT on conflict UPDATE `message_count = message_count + 1`
  - [x] 2.4 Return `{ "allowed": boolean, "current_count": integer, "limit": integer, "remaining": integer }`
  - [x] 2.5 If `message_count >= p_limit`, return `allowed = false` WITHOUT incrementing
  - [x] 2.6 Use `SECURITY DEFINER` and `SET search_path = public, pg_catalog, pg_temp` (matches existing RPC pattern)

- [x] Task 3: Integrate rate limiting into `chat-stream` Edge Function (AC: #1, #2, #3, #6)
  - [x] 3.1 Create `_shared/rate-limiter.ts` utility module
  - [x] 3.2 Export `checkAndIncrementUsage(supabase, userId, subscriptionStatus, sessionMode)` function
  - [x] 3.3 Determine billing period: paid users → `YYYY-MM` format; trial users → `'trial'` (fixed string, no reset)
  - [x] 3.4 Determine limit: `'active'` → 800, `'trial'` → 100
  - [x] 3.5 Skip rate check entirely when `sessionMode === 'discovery'`
  - [x] 3.6 Call `increment_and_check_usage` RPC via `supabase.rpc()`
  - [x] 3.7 Return structured result: `{ allowed, currentCount, limit, remaining, billingPeriod }`
  - [x] 3.8 In `chat-stream/index.ts`, call rate limiter AFTER auth + session mode check (~line 83) but BEFORE user message DB insert (~line 109)
  - [x] 3.9 On rate limit hit, return HTTP 429 with JSON: `{ error: 'rate_limited', message: '...', remaining_until_reset: '...', is_trial: boolean }`

- [x] Task 4: iOS client — handle `rate_limited` response (AC: #5)
  - [x] 4.1 Add `rateLimited` case to `ChatStreamError` enum in `ChatStreamService.swift`
  - [x] 4.2 Handle HTTP 429 status code in `streamChat()` — parse JSON body for rate limit details
  - [x] 4.3 Add `ChatError.rateLimited(isTrial: Bool, resetDate: Date?)` case in `ChatViewModel.swift`
  - [x] 4.4 Display warm coaching-voice message in chat UI:
    - Paid: "We've had a lot of great conversations this month! Your next session refreshes on [date]."
    - Trial: "You've used your trial sessions — ready to continue? [Subscribe]"
  - [x] 4.5 Disable send button (set `canSendMessage = false`) when rate limited
  - [x] 4.6 Show paywall for trial users when rate limited (`showPaywall = true`)

- [x] Task 5: Write unit tests (AC: all)
  - [x] 5.1 Edge Function tests: `_shared/rate-limiter.test.ts` — test paid limits, trial limits, discovery bypass, limit exceeded, edge cases
  - [x] 5.2 RPC function test via Supabase: verify atomic increment, concurrent safety, upsert behavior
  - [x] 5.3 iOS tests: `CoachMeTests/RateLimitTests.swift` — test ChatStreamError.rateLimited parsing, warm message display, send button disabled state

## Dev Notes

### Design Principle
"Limits should feel like care, not walls." (Epic 10 design principle). All rate limit messages use warm, first-person coaching voice per UX-11 error guidelines.

### Revenue Model Context
- **Trial model:** Free discovery session (Epic 11) → $2.99/week paid trial (3 days, auto-upgrades to $19.99/month) → 100 messages during trial, 800/month after
- **Cost target:** <$2/user/month API cost (PRD NFR)
- **Rate limits protect margins** while keeping the user experience warm

### Architecture Patterns & Constraints

**Atomic Check-Before-Increment Pattern:**
The RPC function MUST check the count BEFORE incrementing. If the user is at limit, return `allowed: false` without bumping the counter. This prevents off-by-one errors where the count exceeds the limit.

**Edge Function Insertion Point:**
```
chat-stream/index.ts flow:
1. verifyAuth(req)                    ← line 42
2. Validate conversation              ← line 54
3. Load subscription status           ← line 57-69
4. Determine session mode             ← line 71-83
5. ★ CHECK RATE LIMIT HERE ★         ← NEW (after session mode, before message insert)
6. Insert user message to DB          ← line 109
7. Load context, domain routing       ← line 120+
8. Crisis detection                   ← line 180+
9. LLM streaming call                 ← line 200+
10. Log usage/cost                    ← line 574+
```

**Why before message insert:** Never burn DB writes or LLM tokens on a rate-limited message. Fail fast at step 5.

**Discovery Bypass Implementation:**
```typescript
// In rate-limiter.ts
if (sessionMode === 'discovery') {
  return { allowed: true, currentCount: 0, limit: 0, remaining: Infinity, billingPeriod: 'discovery' };
}
```
Reference: `_shared/session-mode.ts` — `SessionMode` type is `'discovery' | 'coaching' | 'blocked'`

**HTTP 429 Response Format:**
Follow existing error pattern from chat-stream (line 101-104 for 403):
```typescript
return new Response(
  JSON.stringify({
    error: 'rate_limited',
    message: subscriptionStatus === 'trial'
      ? "You've used your trial sessions — ready to continue?"
      : "We've had a lot of great conversations this month! Your next session refreshes on [date].",
    is_trial: subscriptionStatus === 'trial',
    remaining_until_reset: nextResetDate?.toISOString() ?? null,
    current_count: result.current_count,
    limit: result.limit,
  }),
  { status: 429, headers: { 'Content-Type': 'application/json' } },
);
```

### Existing RPC Pattern to Follow
[Source: CoachMe/Supabase/supabase/migrations/20260208000001_increment_surface_count_rpc.sql]
```sql
CREATE OR REPLACE FUNCTION public.increment_and_check_usage(
  p_user_id UUID,
  p_billing_period TEXT,
  p_limit INTEGER
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog, pg_temp
AS $$
DECLARE
  v_current_count INTEGER;
BEGIN
  -- Upsert: create row if not exists, lock existing row
  INSERT INTO message_usage (user_id, billing_period, message_count, limit_amount, updated_at)
  VALUES (p_user_id, p_billing_period, 0, p_limit, NOW())
  ON CONFLICT (user_id, billing_period)
  DO UPDATE SET updated_at = NOW()
  RETURNING message_count INTO v_current_count;

  -- Check BEFORE incrementing
  IF v_current_count >= p_limit THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'current_count', v_current_count,
      'limit', p_limit,
      'remaining', 0
    );
  END IF;

  -- Increment
  UPDATE message_usage
  SET message_count = message_count + 1, updated_at = NOW()
  WHERE user_id = p_user_id AND billing_period = p_billing_period;

  RETURN jsonb_build_object(
    'allowed', true,
    'current_count', v_current_count + 1,
    'limit', p_limit,
    'remaining', p_limit - (v_current_count + 1)
  );
END;
$$;
```

### Billing Period Determination
- **Paid subscribers (`subscription_status = 'active'`):** Use `YYYY-MM` format (e.g., `'2026-02'`) for monthly reset
- **Trial users (`subscription_status = 'trial'`):** Use fixed string `'trial'` — 100 messages total, never resets
- **Discovery users (no subscription):** Bypass rate limiting entirely
- **Expired/cancelled:** Should be blocked by subscription gating before reaching rate limiter (existing logic at ChatViewModel lines 208-230)

### iOS Error Handling Pattern
[Source: CoachMe/CoachMe/Core/Services/ChatStreamService.swift, lines 367-388]

Existing `ChatStreamError` enum:
```swift
enum ChatStreamError: LocalizedError, Equatable {
    case invalidResponse
    case httpError(statusCode: Int)
    case streamInterrupted
    case authenticationRequired
}
```

Add new case:
```swift
case rateLimited(isTrial: Bool, resetDate: Date?)
```

With warm error description:
```swift
case .rateLimited(let isTrial, let resetDate):
    if isTrial {
        return "You've used your trial sessions — ready to continue?"
    } else {
        let dateStr = resetDate.map { DateFormatter.localizedString(from: $0, dateStyle: .medium, timeStyle: .none) } ?? "soon"
        return "We've had a lot of great conversations this month! Your next session refreshes on \(dateStr)."
    }
```

### Subscription State Integration
[Source: CoachMe/Supabase/supabase/functions/chat-stream/index.ts, lines 57-69]

Subscription status is already loaded from `users.subscription_status`. The rate limiter receives this as a parameter — no additional DB query needed.

[Source: CoachMe/CoachMe/Features/Subscription/ViewModels/SubscriptionViewModel.swift]

Client-side subscription state:
- `isTrialActive` — trial period active
- `isSubscribed` — has active subscription (trial or paid)
- `shouldGateChat` — blocks chat for expired/cancelled

### Testing Standards
- **Edge Function tests:** Use Deno test runner, mock Supabase client, test all AC scenarios
- **iOS tests:** XCTest framework, `@MainActor` on test classes, mock services
- **Concurrency testing:** Verify atomic RPC handles concurrent requests (two messages sent simultaneously should not exceed limit)

### Project Structure Notes

**New files to create:**
- `CoachMe/Supabase/supabase/migrations/20260211000003_message_usage.sql` — table + RPC + RLS
- `CoachMe/Supabase/supabase/functions/_shared/rate-limiter.ts` — rate limit utility
- `CoachMe/Supabase/supabase/functions/_shared/rate-limiter.test.ts` — Edge Function tests
- `CoachMe/CoachMeTests/RateLimitTests.swift` — iOS unit tests
- `supabase/migrations/20260211000005_message_usage.sql` — root deploy mirror

**Existing files to modify:**
- `CoachMe/Supabase/supabase/functions/chat-stream/index.ts` — add rate limit check before message insert
- `CoachMe/CoachMe/Core/Services/ChatStreamService.swift` — add `rateLimited` error case, parse 429 response
- `CoachMe/CoachMe/Features/Chat/ViewModels/ChatViewModel.swift` — handle rate limit error, disable send, show warm message
- `CoachMe/CoachMe/Features/Chat/Views/ChatView.swift` — show rate limit message in UI, disable input when limited
- `CoachMe/CoachMe/Features/Chat/Views/MessageInput.swift` — disable send button when rate limited

**Alignment with existing patterns:**
- Migration naming: `YYYYMMDD00000N_description.sql` ✓
- RPC pattern: `SECURITY DEFINER` + `SET search_path` ✓
- RLS pattern: `auth.uid() = user_id` ✓
- Edge Function shared modules: `_shared/` directory ✓
- iOS error handling: warm first-person messages ✓
- iOS concurrency: `@MainActor` on all services/ViewModels ✓

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 10.1] — Story requirements, AC, technical notes
- [Source: _bmad-output/planning-artifacts/architecture.md#Rate Limiting] — Lines 238-241, rate limiting architecture
- [Source: _bmad-output/planning-artifacts/prd.md#FR45] — Rate limiting functional requirement
- [Source: _bmad-output/planning-artifacts/prd.md#NFR18] — Per-user rate limiting non-functional requirement
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Warning Feedback] — "Approaching limit" gentle notice pattern
- [Source: CoachMe/Supabase/supabase/functions/chat-stream/index.ts] — Edge Function flow, insertion point
- [Source: CoachMe/Supabase/supabase/functions/_shared/session-mode.ts] — Discovery mode bypass logic
- [Source: CoachMe/Supabase/supabase/functions/_shared/cost-tracker.ts] — Existing usage logging pattern
- [Source: CoachMe/Supabase/supabase/migrations/20260208000001_increment_surface_count_rpc.sql] — Atomic RPC pattern
- [Source: CoachMe/CoachMe/Core/Services/ChatStreamService.swift] — SSE error handling patterns
- [Source: CoachMe/CoachMe/Features/Chat/ViewModels/ChatViewModel.swift] — Send message flow
- [Source: CoachMe/CoachMe/Features/Subscription/ViewModels/SubscriptionViewModel.swift] — Subscription state

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

- Build succeeded with no errors after all changes

### Completion Notes List

- Task 1+2: Created `message_usage` table + `increment_and_check_usage` RPC in single migration file. Atomic check-before-increment pattern prevents off-by-one errors. RLS enabled with SELECT-only policy; writes go through SECURITY DEFINER RPC. Mirrored to root deploy path.
- Task 3: Created `_shared/rate-limiter.ts` with `checkAndIncrementUsage()` and `getNextResetDate()`. Discovery mode bypassed entirely (AC #6). Fail-open behavior on RPC error to prevent outage from blocking all users. Integrated into `chat-stream/index.ts` after session mode check, before message insert — fail fast pattern.
- Task 4: Added `ChatStreamError.rateLimited(isTrial:resetDate:)` with full 429 JSON body parsing including ISO8601 date. Added `ChatError.rateLimited` with warm UX-11 messages. `isRateLimited` flag on ChatViewModel disables send via MessageInput `canSend`. Rate limit prompt replaces composer in ChatView. Trial users see paywall CTA.
- Task 5: Edge Function tests cover discovery bypass, paid/trial limits, limit exceeded, fail-open, billing period format, RPC parameter verification. iOS tests cover error message content, equality, JSON parsing, ViewModel state defaults and reset.

### Change Log

- 2026-02-10: Story 10.1 implementation — message rate limiting infrastructure (all 5 tasks)

### File List

**New files:**
- CoachMe/Supabase/supabase/migrations/20260211000003_message_usage.sql
- CoachMe/Supabase/supabase/functions/_shared/rate-limiter.ts
- CoachMe/Supabase/supabase/functions/_shared/rate-limiter.test.ts
- CoachMe/CoachMeTests/RateLimitTests.swift
- supabase/migrations/20260211000005_message_usage.sql

**Modified files:**
- CoachMe/Supabase/supabase/functions/chat-stream/index.ts
- CoachMe/CoachMe/Core/Services/ChatStreamService.swift
- CoachMe/CoachMe/Features/Chat/ViewModels/ChatViewModel.swift
- CoachMe/CoachMe/Features/Chat/ViewModels/ChatError.swift
- CoachMe/CoachMe/Features/Chat/Views/ChatView.swift
- CoachMe/CoachMe/Features/Chat/Views/MessageInput.swift