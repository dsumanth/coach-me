/**
 * pattern-analyzer.ts Tests
 * Story 8.4: In-Conversation Pattern Recognition Engine
 *
 * Run with: deno test --allow-read --allow-env pattern-analyzer.test.ts
 */

import {
  assertEquals,
  assertExists,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts';

import type { PatternSummary, AggregatedPattern } from './pattern-analyzer.ts';
import { PATTERN_ANALYZER_CONSTANTS, rankPatterns } from './pattern-analyzer.ts';

// MARK: - Constants Tests (Task 1.5)

Deno.test('PATTERN_ANALYZER_CONSTANTS - MIN_SESSIONS_FOR_PATTERNS is 5 (AC #1)', () => {
  assertEquals(PATTERN_ANALYZER_CONSTANTS.MIN_SESSIONS_FOR_PATTERNS, 5);
});

Deno.test('PATTERN_ANALYZER_CONSTANTS - CACHE_REFRESH_THRESHOLD is 3 (Task 1.3)', () => {
  assertEquals(PATTERN_ANALYZER_CONSTANTS.CACHE_REFRESH_THRESHOLD, 3);
});

Deno.test('PATTERN_ANALYZER_CONSTANTS - MIN_OCCURRENCE_COUNT is 3 (AC #4)', () => {
  assertEquals(PATTERN_ANALYZER_CONSTANTS.MIN_OCCURRENCE_COUNT, 3);
});

Deno.test('PATTERN_ANALYZER_CONSTANTS - CONFIDENCE_THRESHOLD is 0.85 (Task 1.5)', () => {
  assertEquals(PATTERN_ANALYZER_CONSTANTS.CONFIDENCE_THRESHOLD, 0.85);
});

Deno.test('PATTERN_ANALYZER_CONSTANTS - MAX_PATTERNS_IN_PROMPT is 3 (Task 1.6)', () => {
  assertEquals(PATTERN_ANALYZER_CONSTANTS.MAX_PATTERNS_IN_PROMPT, 3);
});

// MARK: - PatternSummary Type Tests

const mockHighConfidencePattern: PatternSummary = {
  theme: 'Control and Perfectionism',
  occurrenceCount: 5,
  domains: ['career', 'relationships', 'personal'],
  confidence: 0.92,
  synthesis: 'A need for control appears across career decisions, relationships, and personal projects. User tends to seek control when feeling uncertain.',
  lastSeenAt: '2026-02-08T10:00:00Z',
};

const mockMediumPattern: PatternSummary = {
  theme: 'Self-Doubt in Leadership',
  occurrenceCount: 3,
  domains: ['career', 'leadership'],
  confidence: 0.88,
  synthesis: 'When discussing leadership roles, frequently questions readiness despite strong evidence of competence.',
  lastSeenAt: '2026-02-07T10:00:00Z',
};

const mockLowOccurrencePattern: PatternSummary = {
  theme: 'Vague Stress Pattern',
  occurrenceCount: 2,
  domains: ['mindset', 'fitness'],
  confidence: 0.90,
  synthesis: 'Stress might affect fitness routine.',
  lastSeenAt: '2026-02-06T10:00:00Z',
};

const mockLowConfidencePattern: PatternSummary = {
  theme: 'Weak Connection',
  occurrenceCount: 5,
  domains: ['mindset', 'fitness'],
  confidence: 0.70,
  synthesis: 'Loose connection between mindset and fitness.',
  lastSeenAt: '2026-02-05T10:00:00Z',
};

Deno.test('PatternSummary - has required fields', () => {
  assertExists(mockHighConfidencePattern.theme);
  assertExists(mockHighConfidencePattern.occurrenceCount);
  assertExists(mockHighConfidencePattern.domains);
  assertExists(mockHighConfidencePattern.confidence);
  assertExists(mockHighConfidencePattern.synthesis);
  assertExists(mockHighConfidencePattern.lastSeenAt);
});

Deno.test('PatternSummary - domains is a non-empty array', () => {
  assertEquals(Array.isArray(mockHighConfidencePattern.domains), true);
  assertEquals(mockHighConfidencePattern.domains.length > 0, true);
});

Deno.test('PatternSummary - confidence is a number between 0 and 1', () => {
  assertEquals(typeof mockHighConfidencePattern.confidence, 'number');
  assertEquals(mockHighConfidencePattern.confidence >= 0, true);
  assertEquals(mockHighConfidencePattern.confidence <= 1, true);
});

// MARK: - Filtering Tests (Task 1.5)

Deno.test('filter - high-confidence pattern with 3+ occurrences passes', () => {
  const threshold = PATTERN_ANALYZER_CONSTANTS.CONFIDENCE_THRESHOLD;
  const minOcc = PATTERN_ANALYZER_CONSTANTS.MIN_OCCURRENCE_COUNT;
  assertEquals(
    mockHighConfidencePattern.occurrenceCount >= minOcc && mockHighConfidencePattern.confidence >= threshold,
    true,
  );
});

Deno.test('filter - low occurrence pattern is filtered out (< 3 occurrences)', () => {
  const minOcc = PATTERN_ANALYZER_CONSTANTS.MIN_OCCURRENCE_COUNT;
  assertEquals(mockLowOccurrencePattern.occurrenceCount >= minOcc, false);
});

Deno.test('filter - low confidence pattern is filtered out (< 0.85)', () => {
  const threshold = PATTERN_ANALYZER_CONSTANTS.CONFIDENCE_THRESHOLD;
  assertEquals(mockLowConfidencePattern.confidence >= threshold, false);
});

Deno.test('filter - combined filter keeps only qualifying patterns', () => {
  const threshold = PATTERN_ANALYZER_CONSTANTS.CONFIDENCE_THRESHOLD;
  const minOcc = PATTERN_ANALYZER_CONSTANTS.MIN_OCCURRENCE_COUNT;
  const patterns = [
    mockHighConfidencePattern,
    mockMediumPattern,
    mockLowOccurrencePattern,
    mockLowConfidencePattern,
  ];
  const filtered = patterns.filter(
    (p) => p.occurrenceCount >= minOcc && p.confidence >= threshold,
  );
  assertEquals(filtered.length, 2);
  assertEquals(filtered[0].theme, 'Control and Perfectionism');
  assertEquals(filtered[1].theme, 'Self-Doubt in Leadership');
});

// MARK: - Ranking Tests (Task 1.4) — using actual rankPatterns()

const makeAggregated = (overrides: Partial<AggregatedPattern> & { theme: string }): AggregatedPattern => ({
  occurrenceCount: 3,
  domains: ['career'],
  confidence: 0.90,
  synthesis: 'test',
  lastSeenAt: '2026-02-08T10:00:00Z',
  engagementCount: 0,
  ...overrides,
});

Deno.test('rankPatterns - sorts by occurrence count descending', () => {
  const patterns: AggregatedPattern[] = [
    makeAggregated({ theme: 'Low', occurrenceCount: 2 }),
    makeAggregated({ theme: 'High', occurrenceCount: 8 }),
    makeAggregated({ theme: 'Mid', occurrenceCount: 5 }),
  ];
  const ranked = rankPatterns(patterns);
  assertEquals(ranked[0].theme, 'High');
  assertEquals(ranked[1].theme, 'Mid');
  assertEquals(ranked[2].theme, 'Low');
});

Deno.test('rankPatterns - breaks occurrence ties by engagement count', () => {
  const patterns: AggregatedPattern[] = [
    makeAggregated({ theme: 'Less Engaged', occurrenceCount: 5, engagementCount: 1 }),
    makeAggregated({ theme: 'More Engaged', occurrenceCount: 5, engagementCount: 4 }),
  ];
  const ranked = rankPatterns(patterns);
  assertEquals(ranked[0].theme, 'More Engaged');
  assertEquals(ranked[1].theme, 'Less Engaged');
});

Deno.test('rankPatterns - breaks full ties by recency (newer first)', () => {
  const patterns: AggregatedPattern[] = [
    makeAggregated({ theme: 'Older', occurrenceCount: 5, engagementCount: 2, lastSeenAt: '2026-02-01T10:00:00Z' }),
    makeAggregated({ theme: 'Newer', occurrenceCount: 5, engagementCount: 2, lastSeenAt: '2026-02-08T10:00:00Z' }),
  ];
  const ranked = rankPatterns(patterns);
  assertEquals(ranked[0].theme, 'Newer');
  assertEquals(ranked[1].theme, 'Older');
});

Deno.test('rankPatterns - does not mutate original array', () => {
  const patterns: AggregatedPattern[] = [
    makeAggregated({ theme: 'B', occurrenceCount: 1 }),
    makeAggregated({ theme: 'A', occurrenceCount: 10 }),
  ];
  const ranked = rankPatterns(patterns);
  assertEquals(patterns[0].theme, 'B'); // Original unchanged
  assertEquals(ranked[0].theme, 'A');
});

Deno.test('rankPatterns - returns empty array for empty input', () => {
  const ranked = rankPatterns([]);
  assertEquals(ranked.length, 0);
});

// MARK: - Max Patterns Limit Tests (Task 1.6)

Deno.test('max patterns - limits to MAX_PATTERNS_IN_PROMPT (3)', () => {
  const manyPatterns = Array.from({ length: 10 }, (_, i) => ({
    ...mockHighConfidencePattern,
    theme: `Pattern ${i + 1}`,
    occurrenceCount: 10 - i,
  }));
  const limited = manyPatterns.slice(0, PATTERN_ANALYZER_CONSTANTS.MAX_PATTERNS_IN_PROMPT);
  assertEquals(limited.length, 3);
});

// MARK: - Synthesis String Tests (Task 1.6)

Deno.test('synthesis - coaching-ready summary is non-empty', () => {
  assertEquals(mockHighConfidencePattern.synthesis.length > 0, true);
});

Deno.test('synthesis - summary length is reasonable (~100 tokens ≈ ~400 chars)', () => {
  // ~100 tokens is approximately 400 characters
  assertEquals(mockHighConfidencePattern.synthesis.length < 500, true);
  assertEquals(mockHighConfidencePattern.synthesis.length > 10, true);
});

// MARK: - Session Count Threshold Tests (AC #1)

Deno.test('session threshold - 4 sessions returns empty (need 5+)', () => {
  const sessionCount = 4;
  assertEquals(sessionCount < PATTERN_ANALYZER_CONSTANTS.MIN_SESSIONS_FOR_PATTERNS, true);
});

Deno.test('session threshold - 5 sessions qualifies for patterns', () => {
  const sessionCount = 5;
  assertEquals(sessionCount >= PATTERN_ANALYZER_CONSTANTS.MIN_SESSIONS_FOR_PATTERNS, true);
});

Deno.test('session threshold - 10 sessions qualifies for patterns', () => {
  const sessionCount = 10;
  assertEquals(sessionCount >= PATTERN_ANALYZER_CONSTANTS.MIN_SESSIONS_FOR_PATTERNS, true);
});

// MARK: - Cache Refresh Tests (Task 1.3)

Deno.test('cache refresh - 0 new conversations uses cache', () => {
  const sessionCountAtAnalysis = 10;
  const currentSessionCount = 10;
  const needsRefresh = (currentSessionCount - sessionCountAtAnalysis) >= PATTERN_ANALYZER_CONSTANTS.CACHE_REFRESH_THRESHOLD;
  assertEquals(needsRefresh, false);
});

Deno.test('cache refresh - 2 new conversations uses cache', () => {
  const sessionCountAtAnalysis = 10;
  const currentSessionCount = 12;
  const needsRefresh = (currentSessionCount - sessionCountAtAnalysis) >= PATTERN_ANALYZER_CONSTANTS.CACHE_REFRESH_THRESHOLD;
  assertEquals(needsRefresh, false);
});

Deno.test('cache refresh - 3 new conversations triggers refresh', () => {
  const sessionCountAtAnalysis = 10;
  const currentSessionCount = 13;
  const needsRefresh = (currentSessionCount - sessionCountAtAnalysis) >= PATTERN_ANALYZER_CONSTANTS.CACHE_REFRESH_THRESHOLD;
  assertEquals(needsRefresh, true);
});

Deno.test('cache refresh - 5 new conversations triggers refresh', () => {
  const sessionCountAtAnalysis = 10;
  const currentSessionCount = 15;
  const needsRefresh = (currentSessionCount - sessionCountAtAnalysis) >= PATTERN_ANALYZER_CONSTANTS.CACHE_REFRESH_THRESHOLD;
  assertEquals(needsRefresh, true);
});

// MARK: - Empty State Tests

Deno.test('empty state - no patterns returns empty array shape', () => {
  const emptyResult: PatternSummary[] = [];
  assertEquals(emptyResult.length, 0);
  assertEquals(Array.isArray(emptyResult), true);
});
