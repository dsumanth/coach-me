/**
 * rate-limiter.test.ts
 *
 * Story 10.1: Unit tests for message rate limiting infrastructure
 * Tests: paid limits, trial limits, discovery bypass, limit exceeded, edge cases
 */

import { assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { checkAndIncrementUsage, getNextResetDate } from './rate-limiter.ts';
import type { SessionMode } from './session-mode.ts';

// ── Mock Supabase Client ──

function createMockSupabase(rpcResult: { data: unknown; error: unknown }) {
  return {
    rpc: (_name: string, _params: Record<string, unknown>) => {
      return Promise.resolve(rpcResult);
    },
  } as unknown as import('npm:@supabase/supabase-js@2.94.1').SupabaseClient;
}

// ── Discovery Bypass Tests (AC #6) ──

Deno.test('discovery mode bypasses rate limiting entirely', async () => {
  // RPC should never be called in discovery mode
  const supabase = createMockSupabase({
    data: null,
    error: { message: 'should not be called' },
  });

  const result = await checkAndIncrementUsage(
    supabase,
    'user-123',
    null,
    'discovery' as SessionMode,
  );

  assertEquals(result.allowed, true);
  assertEquals(result.billingPeriod, 'discovery');
  assertEquals(result.remaining, Infinity);
  assertEquals(result.currentCount, 0);
});

// ── Paid User Tests (AC #1) ──

Deno.test('paid user allowed when under 800 limit', async () => {
  const supabase = createMockSupabase({
    data: { allowed: true, current_count: 50, limit: 800, remaining: 750 },
    error: null,
  });

  const result = await checkAndIncrementUsage(
    supabase,
    'user-123',
    'active',
    'coaching' as SessionMode,
  );

  assertEquals(result.allowed, true);
  assertEquals(result.currentCount, 50);
  assertEquals(result.limit, 800);
  assertEquals(result.remaining, 750);
  // Billing period should be YYYY-MM format
  assertEquals(result.billingPeriod.match(/^\d{4}-\d{2}$/) !== null, true);
});

Deno.test('paid user blocked when at 800 limit', async () => {
  const supabase = createMockSupabase({
    data: { allowed: false, current_count: 800, limit: 800, remaining: 0 },
    error: null,
  });

  const result = await checkAndIncrementUsage(
    supabase,
    'user-123',
    'active',
    'coaching' as SessionMode,
  );

  assertEquals(result.allowed, false);
  assertEquals(result.currentCount, 800);
  assertEquals(result.remaining, 0);
});

// ── Trial User Tests (AC #2) ──

Deno.test('trial user allowed when under 100 limit', async () => {
  const supabase = createMockSupabase({
    data: { allowed: true, current_count: 30, limit: 100, remaining: 70 },
    error: null,
  });

  const result = await checkAndIncrementUsage(
    supabase,
    'user-123',
    'trial',
    'coaching' as SessionMode,
  );

  assertEquals(result.allowed, true);
  assertEquals(result.currentCount, 30);
  assertEquals(result.limit, 100);
  assertEquals(result.remaining, 70);
  assertEquals(result.billingPeriod, 'trial');
});

Deno.test('trial user blocked when at 100 limit', async () => {
  const supabase = createMockSupabase({
    data: { allowed: false, current_count: 100, limit: 100, remaining: 0 },
    error: null,
  });

  const result = await checkAndIncrementUsage(
    supabase,
    'user-123',
    'trial',
    'coaching' as SessionMode,
  );

  assertEquals(result.allowed, false);
  assertEquals(result.currentCount, 100);
  assertEquals(result.remaining, 0);
});

// ── Fail-Open Behavior ──

Deno.test('RPC failure fails open — allows the message', async () => {
  const supabase = createMockSupabase({
    data: null,
    error: { message: 'database timeout' },
  });

  const result = await checkAndIncrementUsage(
    supabase,
    'user-123',
    'active',
    'coaching' as SessionMode,
  );

  // Fail open: allow message even if rate limiter is down
  assertEquals(result.allowed, true);
  assertEquals(result.limit, 800);
});

// ── getNextResetDate Tests (AC #4) ──

Deno.test('paid user gets next month reset date', () => {
  const resetDate = getNextResetDate('active');
  assertEquals(resetDate !== null, true);

  if (resetDate) {
    const now = new Date();
    // Reset date should be first of next month
    assertEquals(resetDate.getUTCDate(), 1);
    // Reset date should be in the future
    assertEquals(resetDate.getTime() > now.getTime(), true);
  }
});

Deno.test('trial user gets no reset date', () => {
  const resetDate = getNextResetDate('trial');
  assertEquals(resetDate, null);
});

Deno.test('null subscription gets no reset date', () => {
  const resetDate = getNextResetDate(null);
  assertEquals(resetDate, null);
});

// ── Billing Period Tests ──

Deno.test('active subscription uses YYYY-MM billing period', async () => {
  let capturedParams: Record<string, unknown> | null = null;
  const supabase = {
    rpc: (_name: string, params: Record<string, unknown>) => {
      capturedParams = params;
      return Promise.resolve({
        data: { allowed: true, current_count: 1, limit: 800, remaining: 799 },
        error: null,
      });
    },
  } as unknown as import('npm:@supabase/supabase-js@2.94.1').SupabaseClient;

  await checkAndIncrementUsage(supabase, 'user-123', 'active', 'coaching' as SessionMode);

  // Verify billing period format
  const period = capturedParams?.p_billing_period as string;
  assertEquals(period.match(/^\d{4}-\d{2}$/) !== null, true);
  assertEquals(capturedParams?.p_limit, 800);
});

Deno.test('trial subscription uses fixed trial billing period', async () => {
  let capturedParams: Record<string, unknown> | null = null;
  const supabase = {
    rpc: (_name: string, params: Record<string, unknown>) => {
      capturedParams = params;
      return Promise.resolve({
        data: { allowed: true, current_count: 1, limit: 100, remaining: 99 },
        error: null,
      });
    },
  } as unknown as import('npm:@supabase/supabase-js@2.94.1').SupabaseClient;

  await checkAndIncrementUsage(supabase, 'user-123', 'trial', 'coaching' as SessionMode);

  assertEquals(capturedParams?.p_billing_period, 'trial');
  assertEquals(capturedParams?.p_limit, 100);
});
