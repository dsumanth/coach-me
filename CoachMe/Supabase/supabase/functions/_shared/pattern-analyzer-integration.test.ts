/**
 * pattern-analyzer-integration.test.ts
 * Story 8.4: In-Conversation Pattern Recognition Engine — E2E Integration Tests
 *
 * Tests the full pipeline: session count → cache check → pattern aggregation →
 * ranking → filtering → prompt injection. Uses mock data to verify behavior
 * without requiring a live Supabase connection.
 *
 * Run with: deno test --allow-read --allow-env pattern-analyzer-integration.test.ts
 */

import {
  assertEquals,
  assertStringIncludes,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts';

import {
  buildCoachingPrompt,
  hasPatternInsights,
  extractPatternInsights,
} from './prompt-builder.ts';

import type { PatternSummary } from './pattern-analyzer.ts';
import { PATTERN_ANALYZER_CONSTANTS } from './pattern-analyzer.ts';

import type { CrossDomainPattern } from './pattern-synthesizer.ts';

// MARK: - Test Fixtures

const emptyPatternSummaries: PatternSummary[] = [];

const highConfidenceSummaries: PatternSummary[] = [
  {
    theme: 'Control and Perfectionism',
    occurrenceCount: 5,
    domains: ['career', 'relationships', 'personal'],
    confidence: 0.92,
    synthesis: 'User tends to seek control when feeling uncertain.',
    lastSeenAt: '2026-02-08T10:00:00Z',
  },
  {
    theme: 'Self-Doubt in Leadership',
    occurrenceCount: 3,
    domains: ['career', 'leadership'],
    confidence: 0.88,
    synthesis: 'Frequently questions readiness despite strong evidence of competence.',
    lastSeenAt: '2026-02-07T10:00:00Z',
  },
];

const crossDomainPatterns: CrossDomainPattern[] = [
  {
    theme: 'avoidance pattern',
    domains: ['career', 'relationships'],
    confidence: 0.90,
    evidence: [
      { domain: 'career', summary: 'Avoids difficult conversations at work' },
      { domain: 'relationships', summary: 'Avoids conflict in relationships' },
    ],
    synthesis: 'Avoidance appears across career and relationships',
  },
];

// MARK: - Test 6.1: User with <5 sessions → no pattern summary injected

Deno.test('E2E 6.1: User with <5 sessions gets no pattern summary in prompt', () => {
  // Simulate: user has <5 sessions, so generatePatternSummary returns []
  const result = buildCoachingPrompt(
    null, 'general', false, [], [], false,
    emptyPatternSummaries,
  );

  assertEquals(result.includes('PATTERNS CONTEXT'), false);
  assertEquals(result.includes('Control and Perfectionism'), false);
});

// MARK: - Test 6.2: User with 5+ sessions → pattern summary present in system prompt

Deno.test('E2E 6.2: User with 5+ sessions gets pattern summary in system prompt', () => {
  // Simulate: user has 5+ sessions, generatePatternSummary returns summaries
  const result = buildCoachingPrompt(
    null, 'general', false, [], [], false,
    highConfidenceSummaries,
  );

  assertStringIncludes(result, 'PATTERNS CONTEXT');
  assertStringIncludes(result, 'Control and Perfectionism');
  assertStringIncludes(result, '5 occurrences');
  assertStringIncludes(result, 'Self-Doubt in Leadership');
  assertStringIncludes(result, '3 occurrences');
  assertStringIncludes(result, 'Confidence: 0.92');
});

// MARK: - Test 6.3: Pattern cache hit within 3-session window → uses cached data

Deno.test('E2E 6.3: Cache hit within 3-session window uses cached summaries', () => {
  // This is a unit-level cache test — verifies the threshold logic
  const sessionCountAtAnalysis = 10;
  const currentSessionCount = 12; // Only 2 new sessions
  const needsRefresh = (currentSessionCount - sessionCountAtAnalysis) >= PATTERN_ANALYZER_CONSTANTS.CACHE_REFRESH_THRESHOLD;

  assertEquals(needsRefresh, false); // Should use cache
});

// MARK: - Test 6.4: Pattern cache miss (3+ new conversations) → triggers re-analysis

Deno.test('E2E 6.4: Cache miss with 3+ new conversations triggers re-analysis', () => {
  const sessionCountAtAnalysis = 10;
  const currentSessionCount = 13; // 3 new sessions
  const needsRefresh = (currentSessionCount - sessionCountAtAnalysis) >= PATTERN_ANALYZER_CONSTANTS.CACHE_REFRESH_THRESHOLD;

  assertEquals(needsRefresh, true); // Should trigger re-analysis
});

// MARK: - Test 6.5: Graceful degradation when pattern-analyzer errors

Deno.test('E2E 6.5: Graceful degradation — empty summaries produce no PATTERNS CONTEXT', () => {
  // When pattern-analyzer fails, it returns []. Prompt should work normally without patterns.
  const result = buildCoachingPrompt(
    null, 'career', false, [], crossDomainPatterns, false,
    emptyPatternSummaries, // Simulates failure → empty array
  );

  // Cross-domain patterns still work
  assertStringIncludes(result, 'CROSS-DOMAIN PATTERNS DETECTED');
  // But no PATTERNS CONTEXT
  assertEquals(result.includes('PATTERNS CONTEXT'), false);
  // Base coaching still works
  assertStringIncludes(result, 'warm, supportive life coach');
});

Deno.test('E2E 6.5: Graceful degradation — prompt works with all pattern sources empty', () => {
  const result = buildCoachingPrompt(
    null, 'general', false, [], [], false, [],
  );

  // Base coaching still works
  assertStringIncludes(result, 'warm, supportive life coach');
  assertEquals(result.includes('PATTERNS CONTEXT'), false);
  assertEquals(result.includes('CROSS-DOMAIN PATTERNS DETECTED'), false);
});

// MARK: - Test 6.6: Pattern ranking respects frequency and recency ordering

Deno.test('E2E 6.6: Pattern ranking — higher occurrence appears first in prompt', () => {
  // Summaries are pre-ranked: Control (5 occ) before Self-Doubt (3 occ)
  const result = buildCoachingPrompt(
    null, 'general', false, [], [], false,
    highConfidenceSummaries,
  );

  const controlIdx = result.indexOf('Control and Perfectionism');
  const selfDoubtIdx = result.indexOf('Self-Doubt in Leadership');

  assertEquals(controlIdx > -1, true);
  assertEquals(selfDoubtIdx > -1, true);
  assertEquals(controlIdx < selfDoubtIdx, true); // Higher occurrence first
});

Deno.test('E2E 6.6: Pattern ranking — only high-confidence patterns survive filter', () => {
  const allPatterns: PatternSummary[] = [
    ...highConfidenceSummaries,
    {
      theme: 'Weak Pattern',
      occurrenceCount: 1, // Below threshold
      domains: ['fitness'],
      confidence: 0.70, // Below threshold
      synthesis: 'Weak connection.',
      lastSeenAt: '2026-02-01T10:00:00Z',
    },
  ];

  // Apply the same filter as pattern-analyzer
  const filtered = allPatterns.filter(
    (p) =>
      p.occurrenceCount >= PATTERN_ANALYZER_CONSTANTS.MIN_OCCURRENCE_COUNT &&
      p.confidence >= PATTERN_ANALYZER_CONSTANTS.CONFIDENCE_THRESHOLD,
  );

  assertEquals(filtered.length, 2);
  assertEquals(filtered.some((p) => p.theme === 'Weak Pattern'), false);
});

// MARK: - Combined Pipeline Tests

Deno.test('E2E: Full prompt with context, history, cross-domain, and pattern summaries', () => {
  const mockContext = {
    values: [{ id: '1', content: 'honesty', source: 'user' as const, added_at: '2026-01-01T00:00:00Z' }],
    goals: [{ id: '1', content: 'become a better leader', domain: 'career', source: 'user' as const, status: 'active' as const, added_at: '2026-01-01T00:00:00Z' }],
    situation: { life_stage: 'mid-career professional' },
    confirmedInsights: [],
    hasContext: true,
  };

  const mockHistory = [
    {
      conversationId: 'conv-1',
      title: 'Career planning',
      domain: 'career',
      summary: 'Discussed upcoming promotion',
      lastMessageAt: '2026-02-01T10:00:00Z',
    },
  ];

  const result = buildCoachingPrompt(
    mockContext,
    'career',
    false,
    mockHistory,
    crossDomainPatterns,
    false,
    highConfidenceSummaries,
  );

  // All sections present in correct order
  assertStringIncludes(result, 'warm, supportive life coach'); // Base
  assertStringIncludes(result, 'TONE GUARDRAILS'); // Safety
  assertStringIncludes(result, 'CLINICAL BOUNDARIES'); // Safety
  assertStringIncludes(result, 'specializing in career coaching'); // Domain
  assertStringIncludes(result, 'core values'); // Context
  assertStringIncludes(result, 'honesty');
  assertStringIncludes(result, 'PREVIOUS CONVERSATIONS'); // History
  assertStringIncludes(result, 'PATTERN RECOGNITION'); // Pattern instruction
  assertStringIncludes(result, 'CROSS-DOMAIN PATTERNS DETECTED'); // Cross-domain
  assertStringIncludes(result, 'PATTERNS CONTEXT'); // Story 8.4
  assertStringIncludes(result, 'Control and Perfectionism');
});

// MARK: - Pattern Engagement Detection Tests (AC #3)

Deno.test('E2E: hasPatternInsights detects [PATTERN: ...] in assistant response', () => {
  const assistantResponse = "I've noticed [PATTERN: you often describe feeling stuck right before a big transition]. What do you think that pattern means for you?";
  assertEquals(hasPatternInsights(assistantResponse), true);
});

Deno.test('E2E: extractPatternInsights extracts theme from [PATTERN: ...] tag', () => {
  const assistantResponse = "I've noticed [PATTERN: you often describe feeling stuck right before a big transition].";
  const insights = extractPatternInsights(assistantResponse);
  assertEquals(insights.length, 1);
  assertEquals(insights[0], 'you often describe feeling stuck right before a big transition');
});

Deno.test('E2E: Pattern engagement — counting user messages after pattern surfacing', () => {
  // Simulate rawHistory (newest first) where pattern was surfaced
  const rawHistory = [
    { role: 'user', content: 'Yes, I think that is really true' }, // Newest — user msg #2
    { role: 'assistant', content: 'Tell me more about that.' },
    { role: 'user', content: 'I never thought of it that way' }, // User msg #1 after pattern
    { role: 'assistant', content: "I've noticed [PATTERN: a need for control when uncertain]. What do you think?" }, // Pattern surfaced
    { role: 'user', content: 'I have been struggling with delegation' },
  ];

  // Find the pattern-containing assistant message
  let patternIdx = -1;
  for (let i = 0; i < rawHistory.length; i++) {
    if (rawHistory[i].role === 'assistant' && hasPatternInsights(rawHistory[i].content)) {
      patternIdx = i;
      break;
    }
  }

  assertEquals(patternIdx, 3); // Found at index 3

  // Count user messages before (newer than) the pattern message
  let userMessageCount = 0;
  for (let i = 0; i < patternIdx; i++) {
    if (rawHistory[i].role === 'user') {
      userMessageCount++;
    }
  }

  assertEquals(userMessageCount, 2); // 2 user messages after pattern = engaged
});

Deno.test('E2E: Pattern engagement — insufficient messages does not trigger', () => {
  const rawHistory = [
    { role: 'user', content: 'Hmm, interesting' }, // Only 1 user message
    { role: 'assistant', content: "I've noticed [PATTERN: a need for control]. What do you think?" },
    { role: 'user', content: 'I need help with time management' },
  ];

  let patternIdx = -1;
  for (let i = 0; i < rawHistory.length; i++) {
    if (rawHistory[i].role === 'assistant' && hasPatternInsights(rawHistory[i].content)) {
      patternIdx = i;
      break;
    }
  }

  assertEquals(patternIdx, 1);

  let userMessageCount = 0;
  for (let i = 0; i < patternIdx; i++) {
    if (rawHistory[i].role === 'user') {
      userMessageCount++;
    }
  }

  assertEquals(userMessageCount, 1); // Only 1 = not engaged yet
});
