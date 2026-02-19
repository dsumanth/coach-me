/**
 * push-intelligence.ts Tests
 * Story 8.7: Smart Proactive Push Notifications
 *
 * Run with: deno test --allow-read --allow-env push-intelligence.test.ts
 */

import {
  assertEquals,
  assertExists,
  assert,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts';

import {
  extractTemporalReferences,
  buildPushPrompt,
  TEMPORAL_CONFIDENCE_THRESHOLD,
  EVENT_WINDOW_HOURS,
  PATTERN_INACTIVITY_DAYS,
  RE_ENGAGEMENT_INACTIVITY_DAYS,
  TEMPORAL_SCAN_DAYS,
} from './push-intelligence.ts';

import type { PushDecision } from './push-intelligence.ts';

// MARK: - Constants Tests

Deno.test('TEMPORAL_CONFIDENCE_THRESHOLD is 0.7', () => {
  assertEquals(TEMPORAL_CONFIDENCE_THRESHOLD, 0.7);
});

Deno.test('EVENT_WINDOW_HOURS is 24', () => {
  assertEquals(EVENT_WINDOW_HOURS, 24);
});

Deno.test('PATTERN_INACTIVITY_DAYS is 2', () => {
  assertEquals(PATTERN_INACTIVITY_DAYS, 2);
});

Deno.test('RE_ENGAGEMENT_INACTIVITY_DAYS is 3', () => {
  assertEquals(RE_ENGAGEMENT_INACTIVITY_DAYS, 3);
});

Deno.test('TEMPORAL_SCAN_DAYS is 7', () => {
  assertEquals(TEMPORAL_SCAN_DAYS, 7);
});

// MARK: - extractTemporalReferences Tests

Deno.test('extractTemporalReferences - detects "tomorrow" relative to message date', () => {
  const messageDate = new Date('2026-02-09T10:00:00Z');
  const refs = extractTemporalReferences(
    'I have a big presentation tomorrow',
    messageDate,
  );

  assertExists(refs);
  assert(refs.length > 0, 'Should detect at least one temporal reference');

  const ref = refs[0];
  // "tomorrow" relative to message date (Feb 9) = Feb 10
  const expectedDate = new Date('2026-02-10T10:00:00Z');
  assertEquals(ref.estimatedDate.getDate(), expectedDate.getDate());
  assertEquals(ref.estimatedDate.getMonth(), expectedDate.getMonth());
  assert(ref.confidence >= 0.7, 'Confidence should be >= 0.7');
});

Deno.test('extractTemporalReferences - "tomorrow" in old message resolves from message timestamp', () => {
  // Edge case: message sent 3 days ago saying "tomorrow"
  // Should resolve to day after message, NOT day after evaluation
  const messageDate = new Date('2026-02-06T10:00:00Z'); // 3 days ago
  const refs = extractTemporalReferences(
    'I have a meeting tomorrow morning',
    messageDate,
  );

  assertExists(refs);
  assert(refs.length > 0);

  const ref = refs[0];
  // "tomorrow" from Feb 6 = Feb 7 (NOT Feb 10)
  assertEquals(ref.estimatedDate.getDate(), 7);
  assertEquals(ref.estimatedDate.getMonth(), 1); // February
});

Deno.test('extractTemporalReferences - detects "next Tuesday"', () => {
  // Feb 9, 2026 is a Monday
  const messageDate = new Date('2026-02-09T10:00:00Z');
  const refs = extractTemporalReferences(
    'My interview is next Tuesday',
    messageDate,
  );

  assertExists(refs);
  assert(refs.length > 0);

  const ref = refs[0];
  // Next Tuesday from Monday Feb 9 = Feb 10
  assertEquals(ref.estimatedDate.getDay(), 2); // Tuesday
  assert(ref.confidence >= 0.7);
});

Deno.test('extractTemporalReferences - detects "this Thursday"', () => {
  const messageDate = new Date('2026-02-09T10:00:00Z'); // Monday
  const refs = extractTemporalReferences(
    'I have a call this Thursday',
    messageDate,
  );

  assertExists(refs);
  assert(refs.length > 0);

  const ref = refs[0];
  assertEquals(ref.estimatedDate.getDay(), 4); // Thursday
});

Deno.test('extractTemporalReferences - detects "on Monday"', () => {
  const messageDate = new Date('2026-02-09T10:00:00Z'); // Monday
  const refs = extractTemporalReferences(
    'The deadline is on Monday',
    messageDate,
  );

  assertExists(refs);
  assert(refs.length > 0);

  const ref = refs[0];
  assertEquals(ref.estimatedDate.getDay(), 1); // Monday
});

Deno.test('extractTemporalReferences - detects "in two days"', () => {
  const messageDate = new Date('2026-02-09T10:00:00Z');
  const refs = extractTemporalReferences(
    'My exam is in two days',
    messageDate,
  );

  assertExists(refs);
  assert(refs.length > 0);

  const ref = refs[0];
  assertEquals(ref.estimatedDate.getDate(), 11); // Feb 9 + 2 = Feb 11
});

Deno.test('extractTemporalReferences - detects "in 3 days"', () => {
  const messageDate = new Date('2026-02-09T10:00:00Z');
  const refs = extractTemporalReferences(
    'Conference in 3 days',
    messageDate,
  );

  assertExists(refs);
  assert(refs.length > 0);

  const ref = refs[0];
  assertEquals(ref.estimatedDate.getDate(), 12); // Feb 9 + 3 = Feb 12
});

Deno.test('extractTemporalReferences - detects explicit "March 15"', () => {
  const messageDate = new Date('2026-02-09T10:00:00Z');
  const refs = extractTemporalReferences(
    'The presentation is on March 15',
    messageDate,
  );

  assertExists(refs);
  assert(refs.length > 0);

  const ref = refs[0];
  assertEquals(ref.estimatedDate.getMonth(), 2); // March
  assertEquals(ref.estimatedDate.getDate(), 15);
  assert(ref.confidence >= 0.8);
});

Deno.test('extractTemporalReferences - "March 15" when already passed resolves to next year', () => {
  // Edge case: message sent on March 20 mentioning "March 15"
  const messageDate = new Date('2026-03-20T10:00:00Z');
  const refs = extractTemporalReferences(
    'Remember that meeting on March 15',
    messageDate,
  );

  assertExists(refs);
  assert(refs.length > 0);

  const ref = refs[0];
  // March 15 already passed → resolves to March 15 next year
  assertEquals(ref.estimatedDate.getMonth(), 2); // March
  assertEquals(ref.estimatedDate.getDate(), 15);
  assertEquals(ref.estimatedDate.getFullYear(), 2027);
});

Deno.test('extractTemporalReferences - detects numeric date "2/20"', () => {
  const messageDate = new Date('2026-02-09T10:00:00Z');
  const refs = extractTemporalReferences(
    'Deadline is 2/20',
    messageDate,
  );

  assertExists(refs);
  assert(refs.length > 0);

  const ref = refs[0];
  assertEquals(ref.estimatedDate.getMonth(), 1); // February
  assertEquals(ref.estimatedDate.getDate(), 20);
});

Deno.test('extractTemporalReferences - detects "the 15th"', () => {
  const messageDate = new Date('2026-02-09T10:00:00Z');
  const refs = extractTemporalReferences(
    'My review is on the 15th',
    messageDate,
  );

  assertExists(refs);
  assert(refs.length > 0);

  const ref = refs[0];
  assertEquals(ref.estimatedDate.getDate(), 15);
});

Deno.test('extractTemporalReferences - extracts event context (presentation)', () => {
  const messageDate = new Date('2026-02-09T10:00:00Z');
  const refs = extractTemporalReferences(
    'I have a really important presentation tomorrow and I am nervous',
    messageDate,
  );

  assertExists(refs);
  assert(refs.length > 0);
  assertExists(refs[0].eventDescription);
  assert(
    refs[0].eventDescription!.includes('presentation'),
    'Event description should include "presentation"',
  );
});

Deno.test('extractTemporalReferences - returns empty for no temporal content', () => {
  const messageDate = new Date('2026-02-09T10:00:00Z');
  const refs = extractTemporalReferences(
    'I feel stressed about work in general',
    messageDate,
  );

  assertEquals(refs.length, 0);
});

Deno.test('extractTemporalReferences - handles multiple references in one message', () => {
  const messageDate = new Date('2026-02-09T10:00:00Z');
  const refs = extractTemporalReferences(
    'I have a presentation tomorrow and an interview on March 15',
    messageDate,
  );

  assert(refs.length >= 2, 'Should detect at least 2 temporal references');
});

Deno.test('extractTemporalReferences - detects "next week"', () => {
  const messageDate = new Date('2026-02-09T10:00:00Z'); // Monday
  const refs = extractTemporalReferences(
    'The deadline is next week',
    messageDate,
  );

  assertExists(refs);
  assert(refs.length > 0);

  const ref = refs[0];
  // "next week" from Monday → next Monday (at least 3+ days ahead)
  assert(ref.estimatedDate.getTime() > messageDate.getTime());
});

// MARK: - determinePushType Priority Tests

// Note: determinePushType requires Supabase so integration tests need mocking.
// The layer functions are exported for unit-level testing of the priority pipeline.

// MARK: - buildPushPrompt Tests

Deno.test('buildPushPrompt - includes push type in prompt', () => {
  const decision: PushDecision = {
    pushType: 'event_based',
    context: 'Upcoming presentation',
    eventDescription: 'team presentation',
  };

  const prompt = buildPushPrompt(decision, 'Goals: career growth', 'Use a direct tone.');
  assert(prompt.includes('event_based'));
  assert(prompt.includes('team presentation'));
  assert(prompt.includes('career growth'));
  assert(prompt.includes('direct tone'));
});

Deno.test('buildPushPrompt - event_based includes EVENT field', () => {
  const decision: PushDecision = {
    pushType: 'event_based',
    context: 'Upcoming interview',
    eventDescription: 'job interview at Google',
  };

  const prompt = buildPushPrompt(decision, '', '');
  assert(prompt.includes('EVENT: job interview at Google'));
});

Deno.test('buildPushPrompt - pattern_based includes PATTERN field', () => {
  const decision: PushDecision = {
    pushType: 'pattern_based',
    context: 'Recognized pattern',
    patternTheme: 'Avoidance under stress',
    conversationDomain: 'career',
  };

  const prompt = buildPushPrompt(decision, '', '');
  assert(prompt.includes('PATTERN: Avoidance under stress'));
  assert(prompt.includes('LAST TOPIC: career'));
});

Deno.test('buildPushPrompt - re_engagement includes LAST TOPIC', () => {
  const decision: PushDecision = {
    pushType: 're_engagement',
    context: 'Last topic: career growth',
    conversationDomain: 'career',
  };

  const prompt = buildPushPrompt(decision, '', '');
  assert(prompt.includes('LAST TOPIC: career'));
});

Deno.test('buildPushPrompt - uses default style when no style instructions', () => {
  const decision: PushDecision = {
    pushType: 're_engagement',
    context: 'test',
  };

  const prompt = buildPushPrompt(decision, '', '');
  assert(prompt.includes('warm, supportive tone'));
});

Deno.test('buildPushPrompt - includes JSON format instruction', () => {
  const decision: PushDecision = {
    pushType: 'event_based',
    context: 'test',
  };

  const prompt = buildPushPrompt(decision, '', '');
  assert(prompt.includes('Respond in JSON'));
  assert(prompt.includes('"title"'));
  assert(prompt.includes('"body"'));
});

Deno.test('buildPushPrompt - specifies character limits', () => {
  const decision: PushDecision = {
    pushType: 'event_based',
    context: 'test',
  };

  const prompt = buildPushPrompt(decision, '', '');
  assert(prompt.includes('Max 50 characters'));
  assert(prompt.includes('Max 200 characters'));
});

Deno.test('buildPushPrompt - includes user context summary', () => {
  const decision: PushDecision = {
    pushType: 're_engagement',
    context: 'test',
  };

  const contextSummary = 'Values: integrity, growth\nGoals: become team lead';
  const prompt = buildPushPrompt(decision, contextSummary, '');
  assert(prompt.includes('integrity, growth'));
  assert(prompt.includes('become team lead'));
});

// MARK: - Inactivity threshold verification

Deno.test('Pattern-based requires >= 2 days inactivity', () => {
  assert(
    PATTERN_INACTIVITY_DAYS >= 2,
    'Pattern layer must require at least 2 days of inactivity',
  );
  assert(
    PATTERN_INACTIVITY_DAYS < RE_ENGAGEMENT_INACTIVITY_DAYS,
    'Pattern threshold must be lower than re-engagement threshold',
  );
});

Deno.test('Re-engagement requires >= 3 days inactivity', () => {
  assert(
    RE_ENGAGEMENT_INACTIVITY_DAYS >= 3,
    'Re-engagement layer must require at least 3 days of inactivity',
  );
});
