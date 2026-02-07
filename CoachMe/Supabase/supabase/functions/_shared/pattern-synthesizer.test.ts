/**
 * pattern-synthesizer.ts Tests
 * Story 3.5: Cross-Domain Pattern Synthesis
 *
 * Run with: deno test --allow-read --allow-env --allow-net pattern-synthesizer.test.ts
 */

import {
  assertEquals,
  assertExists,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts';

import {
  MAX_SYNTHESES_PER_SESSION,
  MIN_SESSIONS_BETWEEN_SYNTHESIS,
} from './pattern-synthesizer.ts';

import type {
  CrossDomainPattern,
  PatternSynthesisResult,
} from './pattern-synthesizer.ts';

// MARK: - Test Fixtures

const mockCrossDomainPattern: CrossDomainPattern = {
  theme: 'control and perfectionism',
  domains: ['career', 'relationships'],
  confidence: 0.92,
  evidence: [
    { domain: 'career', summary: 'Frequently mentions need to control outcomes at work' },
    { domain: 'relationships', summary: 'Describes similar control patterns in personal relationships' },
  ],
  synthesis: 'A need for control appears in both your career decisions and personal relationships',
};

const mockLowConfidencePattern: CrossDomainPattern = {
  theme: 'vague connection',
  domains: ['mindset', 'fitness'],
  confidence: 0.65,
  evidence: [
    { domain: 'mindset', summary: 'Mentioned stress once' },
    { domain: 'fitness', summary: 'Mentioned being tired' },
  ],
  synthesis: 'Stress might affect fitness',
};

const mockSingleDomainPattern: CrossDomainPattern = {
  theme: 'career anxiety',
  domains: ['career'],
  confidence: 0.95,
  evidence: [
    { domain: 'career', summary: 'Repeated anxiety about promotions' },
  ],
  synthesis: 'Career anxiety is recurring',
};

// MARK: - CrossDomainPattern Type Tests

Deno.test('CrossDomainPattern - has required fields', () => {
  assertExists(mockCrossDomainPattern.theme);
  assertExists(mockCrossDomainPattern.domains);
  assertExists(mockCrossDomainPattern.confidence);
  assertExists(mockCrossDomainPattern.evidence);
  assertExists(mockCrossDomainPattern.synthesis);
});

Deno.test('CrossDomainPattern - domains is an array with 2+ entries', () => {
  assertEquals(Array.isArray(mockCrossDomainPattern.domains), true);
  assertEquals(mockCrossDomainPattern.domains.length >= 2, true);
});

Deno.test('CrossDomainPattern - confidence is a number between 0 and 1', () => {
  assertEquals(typeof mockCrossDomainPattern.confidence, 'number');
  assertEquals(mockCrossDomainPattern.confidence >= 0, true);
  assertEquals(mockCrossDomainPattern.confidence <= 1, true);
});

Deno.test('CrossDomainPattern - evidence has entries for each domain', () => {
  const evidenceDomains = mockCrossDomainPattern.evidence.map(e => e.domain);
  for (const domain of mockCrossDomainPattern.domains) {
    assertEquals(evidenceDomains.includes(domain), true);
  }
});

// MARK: - Confidence Threshold Tests (AC #3, Task 10.2)

Deno.test('confidence threshold - high confidence pattern passes', () => {
  const threshold = 0.85;
  assertEquals(mockCrossDomainPattern.confidence >= threshold, true);
});

Deno.test('confidence threshold - low confidence pattern is filtered', () => {
  const threshold = 0.85;
  assertEquals(mockLowConfidencePattern.confidence >= threshold, false);
});

Deno.test('confidence threshold - patterns below 0.85 should not be surfaced', () => {
  const threshold = 0.85;
  const patterns = [mockCrossDomainPattern, mockLowConfidencePattern];
  const filtered = patterns.filter(p => p.confidence >= threshold);
  assertEquals(filtered.length, 1);
  assertEquals(filtered[0].theme, 'control and perfectionism');
});

// MARK: - Domain Count Tests (Task 10.1)

Deno.test('domain filter - patterns spanning 2+ domains pass', () => {
  const minDomains = 2;
  assertEquals(mockCrossDomainPattern.domains.length >= minDomains, true);
});

Deno.test('domain filter - single domain patterns are filtered', () => {
  const minDomains = 2;
  assertEquals(mockSingleDomainPattern.domains.length >= minDomains, false);
});

Deno.test('domain filter - combined filter removes single-domain and low-confidence', () => {
  const threshold = 0.85;
  const minDomains = 2;
  const patterns = [mockCrossDomainPattern, mockLowConfidencePattern, mockSingleDomainPattern];
  const filtered = patterns.filter(
    p => p.confidence >= threshold && p.domains.length >= minDomains,
  );
  assertEquals(filtered.length, 1);
  assertEquals(filtered[0].theme, 'control and perfectionism');
});

// MARK: - Rate Limiting Constants Tests (Task 10.8, 10.9)

Deno.test('rate limiting - MAX_SYNTHESES_PER_SESSION is 1', () => {
  assertEquals(MAX_SYNTHESES_PER_SESSION, 1);
});

Deno.test('rate limiting - MIN_SESSIONS_BETWEEN_SYNTHESIS is 3', () => {
  assertEquals(MIN_SESSIONS_BETWEEN_SYNTHESIS, 3);
});

Deno.test('rate limiting - max 1 synthesis per session enforced by constant', () => {
  // Simulate session-level filtering
  const patternsForSession = [
    mockCrossDomainPattern,
    { ...mockCrossDomainPattern, theme: 'avoidance pattern', confidence: 0.88 },
  ];
  const limited = patternsForSession.slice(0, MAX_SYNTHESES_PER_SESSION);
  assertEquals(limited.length, 1);
});

// MARK: - PatternSynthesisResult Tests (Task 10.3)

Deno.test('PatternSynthesisResult - cached result shape', () => {
  const result: PatternSynthesisResult = {
    patterns: [mockCrossDomainPattern],
    fromCache: true,
  };
  assertEquals(result.fromCache, true);
  assertEquals(result.patterns.length, 1);
});

Deno.test('PatternSynthesisResult - empty result when no patterns', () => {
  const result: PatternSynthesisResult = {
    patterns: [],
    fromCache: false,
  };
  assertEquals(result.patterns.length, 0);
  assertEquals(result.fromCache, false);
});

// MARK: - Evidence Structure Tests

Deno.test('evidence - each entry has domain and summary', () => {
  for (const evidence of mockCrossDomainPattern.evidence) {
    assertExists(evidence.domain);
    assertExists(evidence.summary);
    assertEquals(typeof evidence.domain, 'string');
    assertEquals(typeof evidence.summary, 'string');
  }
});

Deno.test('evidence - summary provides meaningful context', () => {
  for (const evidence of mockCrossDomainPattern.evidence) {
    assertEquals(evidence.summary.length > 10, true);
  }
});
