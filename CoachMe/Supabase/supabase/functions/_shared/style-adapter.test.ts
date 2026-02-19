/**
 * style-adapter.ts Tests
 * Story 8.6: Coaching Style Adaptation
 *
 * Run with: deno test --allow-read --allow-env --allow-net style-adapter.test.ts
 */

import {
  assertEquals,
  assertStringIncludes,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts';

import {
  formatStyleInstructions,
  shouldRefreshStyleAnalysis,
  resolveStylePreferences,
  computeStyleScores,
  buildStyleLabel,
  parseStyleDimensions,
  STRONG_PREFERENCE_HIGH,
  STRONG_PREFERENCE_LOW,
  MIN_SESSIONS_FOR_STYLE,
  MIN_DOMAIN_SESSIONS,
  ANALYSIS_REFRESH_INTERVAL,
} from './style-adapter.ts';

import type { StylePreference } from './style-adapter.ts';

// MARK: - formatStyleInstructions Tests

Deno.test('formatStyleInstructions - returns empty string for null prefs (AC-4)', () => {
  const result = formatStyleInstructions(null);
  assertEquals(result, '');
});

Deno.test('formatStyleInstructions - returns empty string for all-balanced prefs (near 0.5)', () => {
  const balanced: StylePreference = {
    directVsExploratory: 0.5,
    briefVsDetailed: 0.5,
    actionVsReflective: 0.5,
    challengingVsSupportive: 0.5,
  };
  const result = formatStyleInstructions(balanced);
  assertEquals(result, '');
});

Deno.test('formatStyleInstructions - generates text for strong direct preference', () => {
  const prefs: StylePreference = {
    directVsExploratory: 0.8,
    briefVsDetailed: 0.5,
    actionVsReflective: 0.7,
    challengingVsSupportive: 0.5,
  };
  const result = formatStyleInstructions(prefs);
  assertStringIncludes(result, 'direct');
  assertStringIncludes(result, 'concrete next steps');
  assertStringIncludes(result, 'action-oriented');
  assertStringIncludes(result, 'actionable');
});

Deno.test('formatStyleInstructions - generates text for exploratory + supportive preference', () => {
  const prefs: StylePreference = {
    directVsExploratory: 0.2,
    briefVsDetailed: 0.5,
    actionVsReflective: 0.5,
    challengingVsSupportive: 0.2,
  };
  const result = formatStyleInstructions(prefs);
  assertStringIncludes(result, 'exploratory');
  assertStringIncludes(result, 'open-ended questions');
  assertStringIncludes(result, 'supportive');
  assertStringIncludes(result, 'empathy and validation');
});

Deno.test('formatStyleInstructions - includes brief instruction when briefVsDetailed is high', () => {
  const prefs: StylePreference = {
    directVsExploratory: 0.5,
    briefVsDetailed: 0.8,
    actionVsReflective: 0.5,
    challengingVsSupportive: 0.5,
  };
  const result = formatStyleInstructions(prefs);
  assertStringIncludes(result, 'concise');
});

Deno.test('formatStyleInstructions - includes detailed instruction when briefVsDetailed is low', () => {
  const prefs: StylePreference = {
    directVsExploratory: 0.5,
    briefVsDetailed: 0.2,
    actionVsReflective: 0.5,
    challengingVsSupportive: 0.5,
  };
  const result = formatStyleInstructions(prefs);
  assertStringIncludes(result, 'detailed explanations');
});

Deno.test('formatStyleInstructions - includes challenging instruction when high', () => {
  const prefs: StylePreference = {
    directVsExploratory: 0.5,
    briefVsDetailed: 0.5,
    actionVsReflective: 0.5,
    challengingVsSupportive: 0.8,
  };
  const result = formatStyleInstructions(prefs);
  assertStringIncludes(result, 'Challenge assumptions');
});

Deno.test('formatStyleInstructions - includes reflective instruction when actionVsReflective is low', () => {
  const prefs: StylePreference = {
    directVsExploratory: 0.5,
    briefVsDetailed: 0.5,
    actionVsReflective: 0.2,
    challengingVsSupportive: 0.5,
  };
  const result = formatStyleInstructions(prefs);
  assertStringIncludes(result, 'reflection and self-discovery');
});

Deno.test('formatStyleInstructions - threshold boundary: 0.65 does NOT trigger instruction', () => {
  const prefs: StylePreference = {
    directVsExploratory: 0.65,
    briefVsDetailed: 0.5,
    actionVsReflective: 0.5,
    challengingVsSupportive: 0.5,
  };
  const result = formatStyleInstructions(prefs);
  assertEquals(result, '');
});

Deno.test('formatStyleInstructions - threshold boundary: 0.66 DOES trigger instruction', () => {
  const prefs: StylePreference = {
    directVsExploratory: 0.66,
    briefVsDetailed: 0.5,
    actionVsReflective: 0.5,
    challengingVsSupportive: 0.5,
  };
  const result = formatStyleInstructions(prefs);
  assertStringIncludes(result, 'direct');
});

Deno.test('formatStyleInstructions - threshold boundary: 0.35 does NOT trigger low instruction', () => {
  const prefs: StylePreference = {
    directVsExploratory: 0.35,
    briefVsDetailed: 0.5,
    actionVsReflective: 0.5,
    challengingVsSupportive: 0.5,
  };
  const result = formatStyleInstructions(prefs);
  assertEquals(result, '');
});

Deno.test('formatStyleInstructions - threshold boundary: 0.34 DOES trigger low instruction', () => {
  const prefs: StylePreference = {
    directVsExploratory: 0.34,
    briefVsDetailed: 0.5,
    actionVsReflective: 0.5,
    challengingVsSupportive: 0.5,
  };
  const result = formatStyleInstructions(prefs);
  assertStringIncludes(result, 'exploratory');
});

Deno.test('formatStyleInstructions - includes playful humor and example guidance when enabled', () => {
  const prefs: StylePreference = {
    directVsExploratory: 0.5,
    briefVsDetailed: 0.5,
    actionVsReflective: 0.5,
    challengingVsSupportive: 0.5,
    playfulHumor: true,
    concreteExamples: true,
  };
  const result = formatStyleInstructions(prefs);
  assertStringIncludes(result, 'playful');
  assertStringIncludes(result, 'light, kind humor');
  assertStringIncludes(result, 'relatable examples');
  assertStringIncludes(result, 'Avoid therapy-style opener loops');
});

// MARK: - shouldRefreshStyleAnalysis Tests

Deno.test('shouldRefreshStyleAnalysis - returns true for null prefs (never analyzed)', () => {
  assertEquals(shouldRefreshStyleAnalysis(null), true);
});

Deno.test('shouldRefreshStyleAnalysis - returns true when last_style_analysis_at is null', () => {
  assertEquals(shouldRefreshStyleAnalysis({ session_count: 10 }), true);
});

Deno.test('shouldRefreshStyleAnalysis - returns true when session count grew by 5+', () => {
  const prefs = {
    session_count: 15,
    session_count_at_style_analysis: 10,
    last_style_analysis_at: '2026-02-01T00:00:00Z',
  };
  assertEquals(shouldRefreshStyleAnalysis(prefs), true);
});

Deno.test('shouldRefreshStyleAnalysis - returns false when session count grew by <5', () => {
  const prefs = {
    session_count: 12,
    session_count_at_style_analysis: 10,
    last_style_analysis_at: '2026-02-01T00:00:00Z',
  };
  assertEquals(shouldRefreshStyleAnalysis(prefs), false);
});

Deno.test('shouldRefreshStyleAnalysis - returns true when session count grew by exactly 5', () => {
  const prefs = {
    session_count: 15,
    session_count_at_style_analysis: 10,
    last_style_analysis_at: '2026-02-01T00:00:00Z',
  };
  assertEquals(shouldRefreshStyleAnalysis(prefs), true);
});

Deno.test('shouldRefreshStyleAnalysis - returns false for recent analysis with no growth', () => {
  const prefs = {
    session_count: 10,
    session_count_at_style_analysis: 10,
    last_style_analysis_at: '2026-02-08T00:00:00Z',
  };
  assertEquals(shouldRefreshStyleAnalysis(prefs), false);
});

// MARK: - computeStyleScores Tests

Deno.test('computeStyleScores - returns balanced for empty sessions', () => {
  const result = computeStyleScores([]);
  assertEquals(result.directVsExploratory, 0.5);
  assertEquals(result.briefVsDetailed, 0.5);
  assertEquals(result.actionVsReflective, 0.5);
  assertEquals(result.challengingVsSupportive, 0.5);
});

Deno.test('computeStyleScores - short messages produce higher brief score', () => {
  const sessions = [
    { messageCount: 10, avgMessageLength: 30, durationSeconds: 300, domain: 'career' },
    { messageCount: 8, avgMessageLength: 40, durationSeconds: 240, domain: 'career' },
  ];
  const result = computeStyleScores(sessions);
  // Short messages (avg ~35) → brief score should be > 0.5
  assertEquals(result.briefVsDetailed > 0.5, true);
});

Deno.test('computeStyleScores - long messages produce lower brief score', () => {
  const sessions = [
    { messageCount: 5, avgMessageLength: 250, durationSeconds: 600, domain: 'life' },
    { messageCount: 4, avgMessageLength: 300, durationSeconds: 900, domain: 'life' },
  ];
  const result = computeStyleScores(sessions);
  // Long messages (avg ~275) → brief score should be < 0.5
  assertEquals(result.briefVsDetailed < 0.5, true);
});

Deno.test('computeStyleScores - all scores are clamped between 0 and 1', () => {
  const sessions = [
    { messageCount: 100, avgMessageLength: 500, durationSeconds: 10, domain: 'career' },
    { messageCount: 0, avgMessageLength: 0, durationSeconds: 0, domain: 'general' },
  ];
  const result = computeStyleScores(sessions);
  assertEquals(result.directVsExploratory >= 0 && result.directVsExploratory <= 1, true);
  assertEquals(result.briefVsDetailed >= 0 && result.briefVsDetailed <= 1, true);
  assertEquals(result.actionVsReflective >= 0 && result.actionVsReflective <= 1, true);
  assertEquals(result.challengingVsSupportive >= 0 && result.challengingVsSupportive <= 1, true);
});

// MARK: - buildStyleLabel Tests

Deno.test('buildStyleLabel - returns "balanced" for all-0.5 prefs', () => {
  const prefs: StylePreference = {
    directVsExploratory: 0.5,
    briefVsDetailed: 0.5,
    actionVsReflective: 0.5,
    challengingVsSupportive: 0.5,
  };
  assertEquals(buildStyleLabel(prefs), 'balanced');
});

Deno.test('buildStyleLabel - returns "direct, action-oriented" for high direct + action', () => {
  const prefs: StylePreference = {
    directVsExploratory: 0.8,
    briefVsDetailed: 0.5,
    actionVsReflective: 0.8,
    challengingVsSupportive: 0.5,
  };
  assertEquals(buildStyleLabel(prefs), 'direct, action-oriented');
});

Deno.test('buildStyleLabel - returns "exploratory, supportive" for low direct + low challenging', () => {
  const prefs: StylePreference = {
    directVsExploratory: 0.2,
    briefVsDetailed: 0.5,
    actionVsReflective: 0.5,
    challengingVsSupportive: 0.2,
  };
  assertEquals(buildStyleLabel(prefs), 'exploratory, supportive');
});

// MARK: - parseStyleDimensions Tests

Deno.test('parseStyleDimensions - parses snake_case keys correctly', () => {
  const raw = {
    direct_vs_exploratory: 0.8,
    brief_vs_detailed: 0.3,
    action_vs_reflective: 0.7,
    challenging_vs_supportive: 0.4,
  };
  const result = parseStyleDimensions(raw);
  assertEquals(result.directVsExploratory, 0.8);
  assertEquals(result.briefVsDetailed, 0.3);
  assertEquals(result.actionVsReflective, 0.7);
  assertEquals(result.challengingVsSupportive, 0.4);
});

Deno.test('parseStyleDimensions - defaults missing keys to 0.5', () => {
  const raw = {};
  const result = parseStyleDimensions(raw);
  assertEquals(result.directVsExploratory, 0.5);
  assertEquals(result.briefVsDetailed, 0.5);
  assertEquals(result.actionVsReflective, 0.5);
  assertEquals(result.challengingVsSupportive, 0.5);
});

Deno.test('parseStyleDimensions - clamps out-of-range values', () => {
  const raw = {
    direct_vs_exploratory: 1.5,
    brief_vs_detailed: -0.3,
    action_vs_reflective: 0.7,
    challenging_vs_supportive: 2.0,
  };
  const result = parseStyleDimensions(raw);
  assertEquals(result.directVsExploratory, 1.0);
  assertEquals(result.briefVsDetailed, 0);
  assertEquals(result.actionVsReflective, 0.7);
  assertEquals(result.challengingVsSupportive, 1.0);
});

// MARK: - Constants verification

Deno.test('style adapter constants have expected values', () => {
  assertEquals(STRONG_PREFERENCE_HIGH, 0.65);
  assertEquals(STRONG_PREFERENCE_LOW, 0.35);
  assertEquals(MIN_SESSIONS_FOR_STYLE, 5);
  assertEquals(MIN_DOMAIN_SESSIONS, 3);
  assertEquals(ANALYSIS_REFRESH_INTERVAL, 5);
});

// MARK: - resolveStylePreferences Tests (covers getStylePreferences core logic without DB)

Deno.test('resolveStylePreferences - returns null for null preferences', () => {
  assertEquals(resolveStylePreferences(null), null);
});

Deno.test('resolveStylePreferences - returns null for <5 sessions (AC-4)', () => {
  const prefs = {
    session_count: 3,
    style_dimensions: {
      direct_vs_exploratory: 0.8,
      brief_vs_detailed: 0.3,
      action_vs_reflective: 0.7,
      challenging_vs_supportive: 0.4,
    },
  };
  assertEquals(resolveStylePreferences(prefs), null);
});

Deno.test('resolveStylePreferences - returns null for exactly 4 sessions (boundary)', () => {
  const prefs = {
    session_count: 4,
    style_dimensions: {
      direct_vs_exploratory: 0.8,
      brief_vs_detailed: 0.3,
      action_vs_reflective: 0.7,
      challenging_vs_supportive: 0.4,
    },
  };
  assertEquals(resolveStylePreferences(prefs), null);
});

Deno.test('resolveStylePreferences - returns style for exactly 5 sessions (boundary)', () => {
  const prefs = {
    session_count: 5,
    style_dimensions: {
      direct_vs_exploratory: 0.8,
      brief_vs_detailed: 0.3,
      action_vs_reflective: 0.7,
      challenging_vs_supportive: 0.4,
    },
  };
  const result = resolveStylePreferences(prefs);
  assertEquals(result?.directVsExploratory, 0.8);
  assertEquals(result?.briefVsDetailed, 0.3);
});

Deno.test('resolveStylePreferences - returns global style when no domain specified', () => {
  const prefs = {
    session_count: 10,
    style_dimensions: {
      direct_vs_exploratory: 0.7,
      brief_vs_detailed: 0.4,
      action_vs_reflective: 0.6,
      challenging_vs_supportive: 0.3,
    },
  };
  const result = resolveStylePreferences(prefs);
  assertEquals(result?.directVsExploratory, 0.7);
  assertEquals(result?.actionVsReflective, 0.6);
});

Deno.test('resolveStylePreferences - returns domain-specific style when domain matches', () => {
  const prefs = {
    session_count: 10,
    style_dimensions: {
      direct_vs_exploratory: 0.5,
      brief_vs_detailed: 0.5,
      action_vs_reflective: 0.5,
      challenging_vs_supportive: 0.5,
    },
    domain_styles: {
      career: {
        direct_vs_exploratory: 0.9,
        brief_vs_detailed: 0.2,
        action_vs_reflective: 0.8,
        challenging_vs_supportive: 0.3,
      },
    },
  };
  const result = resolveStylePreferences(prefs, 'career');
  assertEquals(result?.directVsExploratory, 0.9);
  assertEquals(result?.briefVsDetailed, 0.2);
});

Deno.test('resolveStylePreferences - falls back to global when domain not in domain_styles', () => {
  const prefs = {
    session_count: 10,
    style_dimensions: {
      direct_vs_exploratory: 0.5,
      brief_vs_detailed: 0.5,
      action_vs_reflective: 0.5,
      challenging_vs_supportive: 0.5,
    },
    domain_styles: {
      career: {
        direct_vs_exploratory: 0.9,
        brief_vs_detailed: 0.2,
        action_vs_reflective: 0.8,
        challenging_vs_supportive: 0.3,
      },
    },
  };
  const result = resolveStylePreferences(prefs, 'life');
  assertEquals(result?.directVsExploratory, 0.5); // global fallback, not career
});

Deno.test('resolveStylePreferences - manual override preset wins over domain style', () => {
  const prefs = {
    session_count: 10,
    manual_override: 'direct',
    style_dimensions: {
      direct_vs_exploratory: 0.9,
      brief_vs_detailed: 0.2,
      action_vs_reflective: 0.8,
      challenging_vs_supportive: 0.3,
    },
    domain_styles: {
      career: {
        direct_vs_exploratory: 0.3,
        brief_vs_detailed: 0.8,
        action_vs_reflective: 0.2,
        challenging_vs_supportive: 0.7,
      },
    },
  };
  const result = resolveStylePreferences(prefs, 'career');
  assertEquals(result?.directVsExploratory, 0.85); // preset for "direct"
  assertEquals(result?.challengingVsSupportive, 0.6); // preset, not career's 0.7
});

Deno.test('resolveStylePreferences - manual override maps even without style_dimensions', () => {
  const prefs = {
    session_count: 10,
    manual_override: 'direct',
    // No style_dimensions needed for manual presets
  };
  const result = resolveStylePreferences(prefs);
  assertEquals(result?.directVsExploratory, 0.85);
  assertEquals(result?.actionVsReflective, 0.8);
});

Deno.test('resolveStylePreferences - manual override bypasses min-session gating', () => {
  const prefs = {
    session_count: 1,
    manual_override: 'challenging',
  };
  const result = resolveStylePreferences(prefs);
  assertEquals(result?.challengingVsSupportive, 0.88);
});

Deno.test('resolveStylePreferences - accepts compassionate alias via legacy supportive', () => {
  const prefs = {
    session_count: 10,
    manual_override: 'supportive',
  };
  const result = resolveStylePreferences(prefs);
  assertEquals(result?.challengingVsSupportive, 0.15);
  assertEquals(result?.directVsExploratory, 0.4);
});

Deno.test('resolveStylePreferences - maps playful manual override and enables humor flags', () => {
  const prefs = {
    session_count: 10,
    manual_override: 'playful',
  };
  const result = resolveStylePreferences(prefs);
  assertEquals(result?.playfulHumor, true);
  assertEquals(result?.concreteExamples, true);
});

Deno.test('resolveStylePreferences - reads manual_overrides.style fallback', () => {
  const prefs = {
    session_count: 10,
    manual_overrides: { style: 'Compassionate' },
  };
  const result = resolveStylePreferences(prefs);
  assertEquals(result?.challengingVsSupportive, 0.15);
});

Deno.test('resolveStylePreferences - returns null when no style_dimensions and no domain_styles', () => {
  const prefs = {
    session_count: 10,
  };
  assertEquals(resolveStylePreferences(prefs), null);
});
