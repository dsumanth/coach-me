/**
 * rate-limiter.ts
 *
 * Story 10.1: Message rate limiting infrastructure
 *
 * Checks and increments per-user message usage against billing-period limits.
 * Discovery sessions bypass rate limiting entirely.
 */

import { SupabaseClient } from 'npm:@supabase/supabase-js@2.94.1';
import type { SessionMode } from './session-mode.ts';

/** Rate limit check result */
export interface RateLimitResult {
  allowed: boolean;
  currentCount: number;
  limit: number;
  remaining: number;
  billingPeriod: string;
}

/** Message limits per subscription tier */
const PAID_MESSAGE_LIMIT = 800;
const TRIAL_MESSAGE_LIMIT = 100;

/**
 * Check and increment message usage for a user.
 *
 * - Discovery mode: bypasses rate limiting entirely (AC #6)
 * - Paid users (active): 800 messages/month, resets each billing cycle (AC #1)
 * - Trial users: 100 messages total, never resets (AC #2)
 *
 * @returns RateLimitResult with allowed status and usage counts
 */
export async function checkAndIncrementUsage(
  supabase: SupabaseClient,
  userId: string,
  subscriptionStatus: string | null,
  sessionMode: SessionMode,
): Promise<RateLimitResult> {
  // AC #6: Discovery sessions bypass rate limiting entirely
  if (sessionMode === 'discovery') {
    return {
      allowed: true,
      currentCount: 0,
      limit: 0,
      remaining: Infinity,
      billingPeriod: 'discovery',
    };
  }

  // Determine billing period and limit based on subscription status
  const billingPeriod = determineBillingPeriod(subscriptionStatus);
  const limit = determineLimit(subscriptionStatus);

  // Call atomic RPC function
  const { data, error } = await supabase.rpc('increment_and_check_usage', {
    p_user_id: userId,
    p_billing_period: billingPeriod,
    p_limit: limit,
  });

  if (error) {
    console.error('Rate limit RPC failed:', error);
    // Fail open: allow the message if the rate limiter is down
    // This prevents a rate limiter outage from blocking all users
    return {
      allowed: true,
      currentCount: 0,
      limit,
      remaining: limit,
      billingPeriod,
    };
  }

  return {
    allowed: data.allowed,
    currentCount: data.current_count,
    limit: data.limit,
    remaining: data.remaining,
    billingPeriod,
  };
}

/**
 * Determine billing period string for the usage counter.
 * - Paid subscribers: 'YYYY-MM' format for monthly reset
 * - Trial users: fixed 'trial' string (never resets)
 */
function determineBillingPeriod(subscriptionStatus: string | null): string {
  if (subscriptionStatus === 'active') {
    const now = new Date();
    const year = now.getUTCFullYear();
    const month = String(now.getUTCMonth() + 1).padStart(2, '0');
    return `${year}-${month}`;
  }
  // Trial users get a fixed period that never resets
  return 'trial';
}

/**
 * Determine message limit based on subscription tier.
 * - Active paid: 800/month
 * - Trial: 100 total
 */
function determineLimit(subscriptionStatus: string | null): number {
  if (subscriptionStatus === 'active') {
    return PAID_MESSAGE_LIMIT;
  }
  return TRIAL_MESSAGE_LIMIT;
}

/**
 * Calculate the next billing period reset date for paid users.
 * Returns the first day of the next month at midnight UTC.
 * Returns null for trial users (no reset).
 */
export function getNextResetDate(subscriptionStatus: string | null): Date | null {
  if (subscriptionStatus !== 'active') {
    return null;
  }
  const now = new Date();
  // First day of next month, midnight UTC
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 1));
}
