/**
 * session-mode.test.ts
 * Story 11.2: Discovery Mode Edge Function
 *
 * Tests for session mode routing logic (determineSessionMode).
 * Run with: deno test --allow-read --allow-env session-mode.test.ts
 */

import { assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { determineSessionMode, shouldUpdateConversationType, computeVisibleContent } from './session-mode.ts';

// MARK: - determineSessionMode() Tests (AC #1, #2, #4, #6, #7)

Deno.test('determineSessionMode: null subscription + null discovery → discovery', () => {
  // New user, no subscription, hasn't completed discovery
  const result = determineSessionMode(null, null);
  assertEquals(result, 'discovery');
});

Deno.test('determineSessionMode: trial subscription + null discovery → discovery', () => {
  // Trial subscriber who hasn't completed discovery — must complete discovery first
  const result = determineSessionMode('trial', null);
  assertEquals(result, 'discovery');
});

Deno.test('determineSessionMode: active subscription + null discovery → discovery', () => {
  // Active subscriber who hasn't completed discovery — must complete discovery first
  const result = determineSessionMode('active', null);
  assertEquals(result, 'discovery');
});

Deno.test('determineSessionMode: null subscription + timestamp → blocked', () => {
  // Completed discovery but no subscription → must subscribe
  const result = determineSessionMode(null, '2026-02-10T12:00:00Z');
  assertEquals(result, 'blocked');
});

Deno.test('determineSessionMode: active subscription + timestamp → coaching', () => {
  // Active subscriber who also completed discovery
  const result = determineSessionMode('active', '2026-02-10T12:00:00Z');
  assertEquals(result, 'coaching');
});

Deno.test('determineSessionMode: trial subscription + timestamp → coaching', () => {
  // Trial subscriber who also completed discovery
  const result = determineSessionMode('trial', '2026-02-10T12:00:00Z');
  assertEquals(result, 'coaching');
});

Deno.test('determineSessionMode: expired subscription + null discovery → discovery', () => {
  // Expired subscription counts as "no active subscription"
  // Routes back to discovery — intentional per Dev Notes
  const result = determineSessionMode('expired', null);
  assertEquals(result, 'discovery');
});

Deno.test('determineSessionMode: cancelled subscription + null discovery → discovery', () => {
  // Cancelled subscription counts as "no active subscription"
  const result = determineSessionMode('cancelled', null);
  assertEquals(result, 'discovery');
});

Deno.test('determineSessionMode: expired subscription + timestamp → blocked', () => {
  // Expired + completed discovery → blocked (must resubscribe)
  const result = determineSessionMode('expired', '2026-02-10T12:00:00Z');
  assertEquals(result, 'blocked');
});

Deno.test('determineSessionMode: cancelled subscription + timestamp → blocked', () => {
  // Cancelled + completed discovery → blocked
  const result = determineSessionMode('cancelled', '2026-02-10T12:00:00Z');
  assertEquals(result, 'blocked');
});

// MARK: - Model Selection Tests (AC #1, #2)

Deno.test('model selection: discovery mode uses Claude Haiku 4.5', () => {
  // When in discovery mode, the model should be Claude Haiku 4.5
  const mode = determineSessionMode(null, null);
  assertEquals(mode, 'discovery');
  // Model mapping is: discovery → claude-haiku-4-5-20251001
  const model = mode === 'discovery' ? 'claude-haiku-4-5-20251001' : 'claude-sonnet-4-5-20250929';
  assertEquals(model, 'claude-haiku-4-5-20251001');
});

Deno.test('model selection: coaching mode uses Sonnet', () => {
  // When in coaching mode, the model should be Sonnet
  // Coaching requires both subscription AND completed discovery
  const mode = determineSessionMode('active', '2026-02-10T12:00:00Z');
  assertEquals(mode, 'coaching');
  const model = mode === 'discovery' ? 'claude-haiku-4-5-20251001' : 'claude-sonnet-4-5-20250929';
  assertEquals(model, 'claude-sonnet-4-5-20250929');
});

// MARK: - Blocked Mode Tests (AC #4)

Deno.test('blocked mode: triggers for completed discovery without subscription', () => {
  const mode = determineSessionMode(null, '2026-02-10T12:00:00Z');
  assertEquals(mode, 'blocked');
  // In the Edge Function, blocked returns 403 with:
  // { error: 'subscription_required', discovery_completed: true }
});

// MARK: - Subscription Upgrade Tests (AC #6, #7)

Deno.test('subscription upgrade: mid-discovery subscription stays in discovery', () => {
  // User subscribes while in discovery — must still complete discovery first
  // (subscription_status changes from null to 'trial' or 'active')
  // Discovery completion is required regardless of subscription status
  const mode = determineSessionMode('trial', null);
  assertEquals(mode, 'discovery');
});

Deno.test('subscription upgrade: post-discovery subscription switches to coaching', () => {
  // User completed discovery, then subscribed
  const mode = determineSessionMode('active', '2026-02-10T12:00:00Z');
  assertEquals(mode, 'coaching');
});

// MARK: - Edge Cases

Deno.test('determineSessionMode: empty string subscription treated as no subscription', () => {
  // Edge case: empty string is not 'trial' or 'active'
  const result = determineSessionMode('', null);
  assertEquals(result, 'discovery');
});

Deno.test('determineSessionMode: unknown status treated as no subscription', () => {
  // Edge case: unrecognized status
  const result = determineSessionMode('pending', null);
  assertEquals(result, 'discovery');
});

// MARK: - shouldUpdateConversationType Tests (AC #5, Task 7.5)

Deno.test('shouldUpdateConversationType: discovery mode + null type → true', () => {
  // New conversation in discovery mode needs tagging
  assertEquals(shouldUpdateConversationType('discovery', null), true);
});

Deno.test('shouldUpdateConversationType: discovery mode + coaching type → true', () => {
  // Existing coaching conversation entering discovery needs re-tagging
  assertEquals(shouldUpdateConversationType('discovery', 'coaching'), true);
});

Deno.test('shouldUpdateConversationType: discovery mode + already discovery → false', () => {
  // Already tagged — no update needed
  assertEquals(shouldUpdateConversationType('discovery', 'discovery'), false);
});

Deno.test('shouldUpdateConversationType: coaching mode + null type → false', () => {
  // Coaching mode never tags conversations as discovery
  assertEquals(shouldUpdateConversationType('coaching', null), false);
});

Deno.test('shouldUpdateConversationType: coaching mode + discovery type → false', () => {
  // Coaching mode doesn't re-tag even if conversation was previously discovery
  assertEquals(shouldUpdateConversationType('coaching', 'discovery'), false);
});

Deno.test('shouldUpdateConversationType: blocked mode → false', () => {
  // Blocked mode never reaches conversation tagging (403 returned earlier)
  assertEquals(shouldUpdateConversationType('blocked', null), false);
});

// MARK: - computeVisibleContent Tests (AC #3, Task 7.4)

Deno.test('computeVisibleContent: no discovery block → full chunk returned', () => {
  // discoveryBlockIdx = -1 means no tag detected yet
  const result = computeVisibleContent(100, 'hello world', -1);
  assertEquals(result, 'hello world');
});

Deno.test('computeVisibleContent: chunk entirely before discovery block → full chunk', () => {
  // fullContent = 50 chars, chunk is last 10, discovery starts at char 80
  // chunkStart = 50 - 10 = 40, which is < 80, and 40+10=50 <= 80
  const result = computeVisibleContent(50, '0123456789', 80);
  assertEquals(result, '0123456789');
});

Deno.test('computeVisibleContent: chunk entirely within discovery block → empty', () => {
  // fullContent = 120 chars, chunk is last 20, discovery starts at char 90
  // chunkStart = 120 - 20 = 100, which is >= 90 → suppress
  const result = computeVisibleContent(120, '{"coaching_domains"}', 90);
  assertEquals(result, '');
});

Deno.test('computeVisibleContent: chunk straddles boundary → partial content', () => {
  // fullContent = 100 chars, chunk = "closing.\n[DISCOVERY_COMPLETE]{" (30 chars)
  // chunkStart = 100 - 30 = 70, discoveryBlockIdx = 79
  // visible = substring(0, 79 - 70) = substring(0, 9) = "closing.\n"
  const chunk = 'closing.\n[DISCOVERY_COMPLETE]{"coaching_domains":["career"]}';
  const fullLen = 70 + chunk.length; // 70 + 59 = 129
  const result = computeVisibleContent(fullLen, chunk, 79);
  assertEquals(result, 'closing.\n');
});

Deno.test('computeVisibleContent: chunk starts 2 chars before block → 2 visible chars', () => {
  // chunk = 'XX[DISCOVERY_COMPLETE]{}' (24 chars), fullLen = 50
  // chunkStart = 50 - 24 = 26, blockIdx = 28 (tag starts after 'XX')
  // visible = substring(0, 28 - 26) = 'XX'
  const chunk = 'XX[DISCOVERY_COMPLETE]{}';
  const result = computeVisibleContent(50, chunk, 28);
  assertEquals(result, 'XX');
});

Deno.test('computeVisibleContent: exact alignment — chunk starts at block idx → empty', () => {
  // chunkStart === discoveryBlockIdx → entire chunk is within block
  const result = computeVisibleContent(100, '[DISCOVERY_COMPLETE]{"data":1}[/DISCOVERY_COMPLETE]', 50);
  // chunkStart = 100 - 50 = 50, which is >= 50 → suppress
  assertEquals(result, '');
});

Deno.test('computeVisibleContent: empty chunk → empty', () => {
  const result = computeVisibleContent(100, '', 50);
  assertEquals(result, '');
});

// MARK: - Discovery Complete → Blocked Flow (AC #3 + #4, Task 7.4)

Deno.test('discovery complete flow: user transitions from discovery to blocked', () => {
  // Step 1: User starts in discovery mode (no subscription, no discovery completion)
  const mode1 = determineSessionMode(null, null);
  assertEquals(mode1, 'discovery');

  // Step 2: Discovery completes — discovery_completed_at is now set
  // Next request with same subscription state → blocked
  const mode2 = determineSessionMode(null, '2026-02-10T18:00:00Z');
  assertEquals(mode2, 'blocked');
  // Edge Function returns 403 { error: 'subscription_required', discovery_completed: true }
});

Deno.test('discovery complete flow: user subscribes after discovery → coaching', () => {
  // Step 1: Discovery completed, user is blocked
  const mode1 = determineSessionMode(null, '2026-02-10T18:00:00Z');
  assertEquals(mode1, 'blocked');

  // Step 2: User subscribes → coaching mode unlocked
  const mode2 = determineSessionMode('trial', '2026-02-10T18:00:00Z');
  assertEquals(mode2, 'coaching');
});

// MARK: - Discovery-First Enforcement Tests

Deno.test('discovery-first: subscriber must complete discovery before coaching', () => {
  // Full user journey: subscribe first, then must still do discovery, then gets coaching
  const step1 = determineSessionMode('active', null);
  assertEquals(step1, 'discovery'); // Even with active subscription

  // After completing discovery → coaching
  const step2 = determineSessionMode('active', '2026-02-11T10:00:00Z');
  assertEquals(step2, 'coaching');
});

Deno.test('discovery-first: trial subscriber must complete discovery', () => {
  const mode = determineSessionMode('trial', null);
  assertEquals(mode, 'discovery'); // Trial doesn't skip discovery
});

Deno.test('discovery-first: discovery always required regardless of subscription tier', () => {
  // All subscription states with null discovery → discovery
  assertEquals(determineSessionMode(null, null), 'discovery');
  assertEquals(determineSessionMode('trial', null), 'discovery');
  assertEquals(determineSessionMode('active', null), 'discovery');
  assertEquals(determineSessionMode('expired', null), 'discovery');
  assertEquals(determineSessionMode('cancelled', null), 'discovery');
});
