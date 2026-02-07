/**
 * prompt-builder.ts Tests
 * Story 2.4: Context Injection into Coaching Responses
 *
 * Run with: deno test --allow-env prompt-builder.test.ts
 */

import {
  assertEquals,
  assertStringIncludes,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts';

import {
  buildCoachingPrompt,
  buildBasePrompt,
  hasMemoryMoments,
  extractMemoryMoments,
  stripMemoryTags,
} from './prompt-builder.ts';

import type {
  UserContext,
  ContextValue,
  ContextGoal,
  ContextSituation,
  ExtractedInsight,
} from './context-loader.ts';

// MARK: - Test Fixtures
// Types match context-loader.ts definitions exactly

const fullContext: UserContext = {
  values: [
    { id: '1', content: 'honesty', source: 'user', added_at: '2026-01-01T00:00:00Z' },
    { id: '2', content: 'growth', source: 'extracted', confidence: 0.9, added_at: '2026-01-02T00:00:00Z' },
  ] as ContextValue[],
  goals: [
    { id: '1', content: 'become a better leader', domain: 'career', source: 'user', status: 'active', added_at: '2026-01-01T00:00:00Z' },
  ] as ContextGoal[],
  situation: {
    life_stage: 'mid-career professional',
    freeform: 'navigating a career transition',
  } as ContextSituation,
  confirmedInsights: [
    {
      id: '1',
      content: 'values work-life balance',
      category: 'value',
      confidence: 0.9,
      confirmed: true,
      extracted_at: '2026-01-03T00:00:00Z',
    },
  ] as ExtractedInsight[],
  hasContext: true,
};

const emptyContext: UserContext = {
  values: [],
  goals: [],
  situation: {},
  confirmedInsights: [],
  hasContext: false,
};

const partialContext: UserContext = {
  values: [{ id: '1', content: 'creativity', source: 'user', added_at: '2026-01-01T00:00:00Z' }] as ContextValue[],
  goals: [],
  situation: {},
  confirmedInsights: [],
  hasContext: true,
};

// MARK: - buildCoachingPrompt Tests

Deno.test('buildCoachingPrompt - includes base coaching prompt', () => {
  const result = buildCoachingPrompt(fullContext);

  assertStringIncludes(result, 'warm, supportive life coach');
  assertStringIncludes(result, 'coaching-focused');
});

Deno.test('buildCoachingPrompt - includes values section when present', () => {
  const result = buildCoachingPrompt(fullContext);

  assertStringIncludes(result, 'core values');
  assertStringIncludes(result, 'honesty');
  assertStringIncludes(result, 'growth');
});

Deno.test('buildCoachingPrompt - includes goals section when present', () => {
  const result = buildCoachingPrompt(fullContext);

  assertStringIncludes(result, 'active goals');
  assertStringIncludes(result, 'become a better leader');
});

Deno.test('buildCoachingPrompt - includes situation section when present', () => {
  const result = buildCoachingPrompt(fullContext);

  assertStringIncludes(result, 'life situation');
  assertStringIncludes(result, 'career transition');
});

Deno.test('buildCoachingPrompt - includes memory tag instruction when context present', () => {
  const result = buildCoachingPrompt(fullContext);

  assertStringIncludes(result, '[MEMORY:');
  assertStringIncludes(result, 'wrap that specific reference');
});

Deno.test('buildCoachingPrompt - excludes memory tag instruction when no context', () => {
  const result = buildCoachingPrompt(emptyContext);

  // Should not include the memory tag instruction
  assertEquals(result.includes('[MEMORY:'), false);
});

Deno.test('buildCoachingPrompt - handles null context', () => {
  const result = buildCoachingPrompt(null);

  // Should return base prompt without context sections
  assertStringIncludes(result, 'warm, supportive life coach');
  assertEquals(result.includes('core values'), false);
  assertEquals(result.includes('[MEMORY:'), false);
});

Deno.test('buildCoachingPrompt - handles partial context', () => {
  const result = buildCoachingPrompt(partialContext);

  // Should include values but not goals or situation
  assertStringIncludes(result, 'creativity');
  // Should still include memory tag instruction since hasContext is true
  assertStringIncludes(result, '[MEMORY:');
});

Deno.test('buildCoachingPrompt - includes confirmed insights', () => {
  const result = buildCoachingPrompt(fullContext);

  assertStringIncludes(result, 'work-life balance');
});

// MARK: - buildBasePrompt Tests

Deno.test('buildBasePrompt - returns base coaching prompt', () => {
  const result = buildBasePrompt();

  assertStringIncludes(result, 'warm, supportive life coach');
  assertStringIncludes(result, 'coaching-focused');
  assertEquals(result.includes('[MEMORY:'), false);
});

// MARK: - hasMemoryMoments Tests

Deno.test('hasMemoryMoments - returns true when tag present', () => {
  const text = 'Given your value of [MEMORY: honesty], what would you do?';
  assertEquals(hasMemoryMoments(text), true);
});

Deno.test('hasMemoryMoments - returns false when no tag', () => {
  const text = 'This is a regular coaching response.';
  assertEquals(hasMemoryMoments(text), false);
});

Deno.test('hasMemoryMoments - returns true for multiple tags', () => {
  const text = 'You value [MEMORY: honesty] and [MEMORY: growth].';
  assertEquals(hasMemoryMoments(text), true);
});

Deno.test('hasMemoryMoments - case insensitive', () => {
  const text = 'You value [memory: honesty].';
  assertEquals(hasMemoryMoments(text), true);
});

Deno.test('hasMemoryMoments - handles whitespace in tag', () => {
  const text = 'You value [MEMORY:  honesty  ].';
  assertEquals(hasMemoryMoments(text), true);
});

// MARK: - extractMemoryMoments Tests

Deno.test('extractMemoryMoments - extracts single moment', () => {
  const text = 'Given [MEMORY: honesty], what matters?';
  const moments = extractMemoryMoments(text);

  assertEquals(moments.length, 1);
  assertEquals(moments[0], 'honesty');
});

Deno.test('extractMemoryMoments - extracts multiple moments', () => {
  const text = 'You value [MEMORY: honesty] and [MEMORY: growth mindset].';
  const moments = extractMemoryMoments(text);

  assertEquals(moments.length, 2);
  assertEquals(moments[0], 'honesty');
  assertEquals(moments[1], 'growth mindset');
});

Deno.test('extractMemoryMoments - returns empty array when no moments', () => {
  const text = 'This has no memory references.';
  const moments = extractMemoryMoments(text);

  assertEquals(moments.length, 0);
});

Deno.test('extractMemoryMoments - trims whitespace from content', () => {
  const text = '[MEMORY:   career transition   ]';
  const moments = extractMemoryMoments(text);

  assertEquals(moments[0], 'career transition');
});

// MARK: - stripMemoryTags Tests

Deno.test('stripMemoryTags - removes single tag', () => {
  const text = 'You value [MEMORY: honesty] deeply.';
  const result = stripMemoryTags(text);

  assertEquals(result, 'You value honesty deeply.');
});

Deno.test('stripMemoryTags - removes multiple tags', () => {
  const text = 'Your [MEMORY: values] guide your [MEMORY: goals].';
  const result = stripMemoryTags(text);

  assertEquals(result, 'Your values guide your goals.');
});

Deno.test('stripMemoryTags - preserves text without tags', () => {
  const text = 'No memory tags here.';
  const result = stripMemoryTags(text);

  assertEquals(result, text);
});

Deno.test('stripMemoryTags - handles complex content', () => {
  const text = 'Given [MEMORY: work-life balance & self-care], how do you feel?';
  const result = stripMemoryTags(text);

  assertEquals(result, 'Given work-life balance & self-care, how do you feel?');
});
