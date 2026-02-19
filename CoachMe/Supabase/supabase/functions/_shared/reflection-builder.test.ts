/**
 * reflection-builder.test.ts
 *
 * Story 8.5: Progress Tracking & Coaching Reflections
 *
 * Tests for reflection eligibility, session check-in, monthly reflection,
 * and graceful decline instruction builders.
 *
 * Run with: deno test --allow-read --allow-env reflection-builder.test.ts
 */

import {
  assertEquals,
  assertStringIncludes,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts';

import {
  shouldOfferReflection,
  buildSessionCheckIn,
  buildMonthlyReflection,
  buildReflectionDeclineInstruction,
  REFLECTION_CONSTANTS,
} from './reflection-builder.ts';

import type { ReflectionContext, GoalStatus } from './reflection-builder.ts';

// MARK: - Test Fixtures

const baseReflectionContext: ReflectionContext = {
  sessionCount: 12,
  lastReflectionAt: null,
  patternSummary: 'User shows growing confidence in career decisions',
  goalStatus: [
    { content: 'become a better leader', domain: 'career', status: 'active' },
    { content: 'improve work-life balance', domain: 'life', status: 'active' },
    { content: 'learn public speaking', domain: 'career', status: 'completed' },
  ] as GoalStatus[],
  domainUsage: { career: 5, life: 3, relationships: 2, mindset: 2 },
  recentThemes: ['career confidence', 'work-life balance', 'leadership growth'],
  previousSessionTopic: 'presentation anxiety at work',
  offerMonthlyReflection: true,
};

// MARK: - shouldOfferReflection Tests

Deno.test('shouldOfferReflection - returns false when session_count < 8', () => {
  assertEquals(shouldOfferReflection(7, null), false);
  assertEquals(shouldOfferReflection(0, null), false);
  assertEquals(shouldOfferReflection(1, null), false);
});

Deno.test('shouldOfferReflection - returns true when eligible (>= 8 sessions, no prior reflection)', () => {
  assertEquals(shouldOfferReflection(8, null), true);
  assertEquals(shouldOfferReflection(12, null), true);
  assertEquals(shouldOfferReflection(100, null), true);
});

Deno.test('shouldOfferReflection - returns true when lastReflectionAt is null (first reflection)', () => {
  assertEquals(shouldOfferReflection(10, null), true);
});

Deno.test('shouldOfferReflection - returns false when last reflection < 25 days ago', () => {
  // 10 days ago
  const tenDaysAgo = new Date(Date.now() - 10 * 24 * 60 * 60 * 1000).toISOString();
  assertEquals(shouldOfferReflection(10, tenDaysAgo), false);

  // 24 days ago (just under threshold)
  const twentyFourDaysAgo = new Date(Date.now() - 24 * 24 * 60 * 60 * 1000).toISOString();
  assertEquals(shouldOfferReflection(10, twentyFourDaysAgo), false);
});

Deno.test('shouldOfferReflection - returns true when >= 25 days since last reflection', () => {
  // Exactly 25 days ago
  const twentyFiveDaysAgo = new Date(Date.now() - 25 * 24 * 60 * 60 * 1000).toISOString();
  assertEquals(shouldOfferReflection(10, twentyFiveDaysAgo), true);

  // 30 days ago
  const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();
  assertEquals(shouldOfferReflection(10, thirtyDaysAgo), true);
});

Deno.test('shouldOfferReflection - constants match expected values', () => {
  assertEquals(REFLECTION_CONSTANTS.MIN_SESSIONS_FOR_REFLECTION, 8);
  assertEquals(REFLECTION_CONSTANTS.MIN_DAYS_BETWEEN_REFLECTIONS, 25);
});

// MARK: - buildSessionCheckIn Tests

Deno.test('buildSessionCheckIn - references previous session topic', () => {
  const result = buildSessionCheckIn('presentation anxiety at work', '');

  assertStringIncludes(result, 'SESSION CHECK-IN');
  assertStringIncludes(result, 'presentation anxiety at work');
  assertStringIncludes(result, 'naturally asking how things went');
});

Deno.test('buildSessionCheckIn - includes brief warm example', () => {
  const result = buildSessionCheckIn('career transition planning', '');

  assertStringIncludes(result, 'Last time we talked about X. How did it go?');
});

Deno.test('buildSessionCheckIn - includes anti-forcing instruction', () => {
  const result = buildSessionCheckIn('work stress', '');

  assertStringIncludes(result, 'Do NOT force the check-in');
  assertStringIncludes(result, 'follow their lead');
});

Deno.test('buildSessionCheckIn - includes pattern context when provided', () => {
  const result = buildSessionCheckIn(
    'leadership challenges',
    'User shows growing confidence in decisions',
  );

  assertStringIncludes(result, 'Additional pattern context');
  assertStringIncludes(result, 'growing confidence in decisions');
});

Deno.test('buildSessionCheckIn - omits pattern context section when empty', () => {
  const result = buildSessionCheckIn('career planning', '');

  assertEquals(result.includes('Additional pattern context'), false);
});

// MARK: - buildMonthlyReflection Tests

Deno.test('buildMonthlyReflection - includes top themes', () => {
  const result = buildMonthlyReflection(baseReflectionContext);

  assertStringIncludes(result, 'career confidence');
  assertStringIncludes(result, 'work-life balance');
  assertStringIncludes(result, 'leadership growth');
});

Deno.test('buildMonthlyReflection - includes growth signals from pattern summary', () => {
  const result = buildMonthlyReflection(baseReflectionContext);

  assertStringIncludes(result, 'growing confidence in career decisions');
});

Deno.test('buildMonthlyReflection - includes domain engagement', () => {
  const result = buildMonthlyReflection(baseReflectionContext);

  assertStringIncludes(result, 'career');
  assertStringIncludes(result, 'Domain engagement');
});

Deno.test('buildMonthlyReflection - includes active and completed goals', () => {
  const result = buildMonthlyReflection(baseReflectionContext);

  assertStringIncludes(result, 'become a better leader');
  assertStringIncludes(result, 'improve work-life balance');
  assertStringIncludes(result, 'learn public speaking');
  assertStringIncludes(result, 'Completed goals');
});

Deno.test('buildMonthlyReflection - uses coach voice (no analytics language)', () => {
  const result = buildMonthlyReflection(baseReflectionContext);

  assertStringIncludes(result, "I've noticed");
  assertStringIncludes(result, "I'm hearing");
  assertStringIncludes(result, 'warm coaching voice');
  assertStringIncludes(result, 'NOT an analytics report');
  // Must explicitly ban data/metrics language
  assertStringIncludes(result, 'Never reference "data", "metrics", or "tracking"');
});

Deno.test('buildMonthlyReflection - includes 150-word limit instruction', () => {
  const result = buildMonthlyReflection(baseReflectionContext);

  assertStringIncludes(result, 'under 150 words');
});

Deno.test('buildMonthlyReflection - includes COACHING REFLECTION OPPORTUNITY header', () => {
  const result = buildMonthlyReflection(baseReflectionContext);

  assertStringIncludes(result, 'COACHING REFLECTION OPPORTUNITY');
});

Deno.test('buildMonthlyReflection - includes reflection offer phrasing', () => {
  const result = buildMonthlyReflection(baseReflectionContext);

  assertStringIncludes(result, 'Before we dive in today');
  assertStringIncludes(result, 'Can I share something');
});

Deno.test('buildMonthlyReflection - includes session count', () => {
  const result = buildMonthlyReflection(baseReflectionContext);

  assertStringIncludes(result, '12 coaching sessions');
});

Deno.test('buildMonthlyReflection - includes REFLECTION_ACCEPTED/DECLINED tags', () => {
  const result = buildMonthlyReflection(baseReflectionContext);

  assertStringIncludes(result, '[REFLECTION_ACCEPTED]');
  assertStringIncludes(result, '[REFLECTION_DECLINED]');
});

Deno.test('buildMonthlyReflection - handles empty themes gracefully', () => {
  const context: ReflectionContext = {
    ...baseReflectionContext,
    recentThemes: [],
  };
  const result = buildMonthlyReflection(context);

  // Should not include Top themes line when empty
  assertEquals(result.includes('Top themes:'), false);
  // Should still include other sections
  assertStringIncludes(result, 'COACHING REFLECTION OPPORTUNITY');
});

Deno.test('buildMonthlyReflection - handles empty domain usage gracefully', () => {
  const context: ReflectionContext = {
    ...baseReflectionContext,
    domainUsage: {},
  };
  const result = buildMonthlyReflection(context);

  assertEquals(result.includes('Domain engagement:'), false);
  assertStringIncludes(result, 'COACHING REFLECTION OPPORTUNITY');
});

Deno.test('buildMonthlyReflection - handles no goals gracefully', () => {
  const context: ReflectionContext = {
    ...baseReflectionContext,
    goalStatus: [],
  };
  const result = buildMonthlyReflection(context);

  assertEquals(result.includes('Active goals:'), false);
  assertStringIncludes(result, 'COACHING REFLECTION OPPORTUNITY');
});

// MARK: - buildReflectionDeclineInstruction Tests

Deno.test('buildReflectionDeclineInstruction - includes graceful pivot instruction', () => {
  const result = buildReflectionDeclineInstruction();

  assertStringIncludes(result, 'REFLECTION DECLINE HANDLING');
  assertStringIncludes(result, "Of course — what's on your mind?");
});

Deno.test('buildReflectionDeclineInstruction - instructs immediate pivot', () => {
  const result = buildReflectionDeclineInstruction();

  assertStringIncludes(result, 'Pivot immediately and gracefully');
});

Deno.test('buildReflectionDeclineInstruction - forbids insistence and guilt', () => {
  const result = buildReflectionDeclineInstruction();

  assertStringIncludes(result, 'Do NOT insist');
  assertStringIncludes(result, 'Do NOT show disappointment');
});

Deno.test('buildReflectionDeclineInstruction - includes REFLECTION_DECLINED tag instruction', () => {
  const result = buildReflectionDeclineInstruction();

  assertStringIncludes(result, '[REFLECTION_DECLINED]');
});

Deno.test('buildReflectionDeclineInstruction - resumes normal coaching', () => {
  const result = buildReflectionDeclineInstruction();

  assertStringIncludes(result, 'Resume normal coaching flow');
});
