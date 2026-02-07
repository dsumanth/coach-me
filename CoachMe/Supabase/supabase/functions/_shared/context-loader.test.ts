/**
 * context-loader.ts Tests
 * Story 2.4: Context Injection into Coaching Responses
 *
 * Run with: deno test --allow-env context-loader.test.ts
 */

import {
  assertEquals,
  assertExists,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts';

import {
  loadUserContext,
  formatContextForPrompt,
  type UserContext,
  type ContextValue,
  type ContextGoal,
  type ContextSituation,
  type ExtractedInsight,
} from './context-loader.ts';

// MARK: - Mock Supabase Client

interface MockQueryResult {
  data: unknown;
  error: { code: string; message: string } | null;
}

function createMockSupabase(mockResult: MockQueryResult) {
  return {
    from: (_table: string) => ({
      select: (_columns: string) => ({
        eq: (_col: string, _val: string) => ({
          single: async () => mockResult,
        }),
      }),
    }),
  };
}

// MARK: - Test Fixtures

const mockValues: ContextValue[] = [
  {
    id: '1',
    content: 'honesty',
    source: 'user',
    added_at: '2026-01-01T00:00:00Z',
  },
  {
    id: '2',
    content: 'growth',
    source: 'extracted',
    confidence: 0.9,
    added_at: '2026-01-02T00:00:00Z',
  },
];

const mockGoals: ContextGoal[] = [
  {
    id: '1',
    content: 'become a better leader',
    domain: 'career',
    source: 'user',
    status: 'active',
    added_at: '2026-01-01T00:00:00Z',
  },
  {
    id: '2',
    content: 'completed goal',
    source: 'user',
    status: 'completed',
    added_at: '2026-01-01T00:00:00Z',
  },
];

const mockSituation: ContextSituation = {
  life_stage: 'mid-career professional',
  occupation: 'software engineer',
  relationships: 'married with two kids',
  challenges: 'work-life balance',
  freeform: 'navigating a career transition',
};

const mockInsights: ExtractedInsight[] = [
  {
    id: '1',
    content: 'values deep work',
    category: 'value',
    confidence: 0.95,
    confirmed: true,
    extracted_at: '2026-01-03T00:00:00Z',
  },
  {
    id: '2',
    content: 'unconfirmed insight',
    category: 'pattern',
    confidence: 0.6,
    confirmed: false,
    extracted_at: '2026-01-03T00:00:00Z',
  },
];

const fullProfileRow = {
  values: mockValues,
  goals: mockGoals,
  situation: mockSituation,
  extracted_insights: mockInsights,
};

// MARK: - loadUserContext Tests

Deno.test('loadUserContext - loads profile with values, goals, situation', async () => {
  const mockSupabase = createMockSupabase({
    data: fullProfileRow,
    error: null,
  });

  // @ts-ignore - mock client
  const result = await loadUserContext(mockSupabase, 'user-123');

  assertExists(result);
  assertEquals(result.hasContext, true);
  assertEquals(result.values.length, 2);
  assertEquals(result.values[0].content, 'honesty');
  assertEquals(result.values[1].content, 'growth');
});

Deno.test('loadUserContext - only returns active goals', async () => {
  const mockSupabase = createMockSupabase({
    data: fullProfileRow,
    error: null,
  });

  // @ts-ignore - mock client
  const result = await loadUserContext(mockSupabase, 'user-123');

  // Should only include active goals, not completed ones
  assertEquals(result.goals.length, 1);
  assertEquals(result.goals[0].content, 'become a better leader');
  assertEquals(result.goals[0].status, 'active');
});

Deno.test('loadUserContext - includes situation context', async () => {
  const mockSupabase = createMockSupabase({
    data: fullProfileRow,
    error: null,
  });

  // @ts-ignore - mock client
  const result = await loadUserContext(mockSupabase, 'user-123');

  assertExists(result.situation);
  assertEquals(result.situation.occupation, 'software engineer');
  assertEquals(result.situation.life_stage, 'mid-career professional');
});

Deno.test('loadUserContext - only includes confirmed insights', async () => {
  const mockSupabase = createMockSupabase({
    data: fullProfileRow,
    error: null,
  });

  // @ts-ignore - mock client
  const result = await loadUserContext(mockSupabase, 'user-123');

  // Should only include confirmed insights
  assertEquals(result.confirmedInsights.length, 1);
  assertEquals(result.confirmedInsights[0].content, 'values deep work');
  assertEquals(result.confirmedInsights[0].confirmed, true);
});

Deno.test('loadUserContext - returns empty context for user without profile (PGRST116)', async () => {
  const mockSupabase = createMockSupabase({
    data: null,
    error: { code: 'PGRST116', message: 'No rows returned' },
  });

  // @ts-ignore - mock client
  const result = await loadUserContext(mockSupabase, 'user-without-profile');

  assertExists(result);
  assertEquals(result.hasContext, false);
  assertEquals(result.values.length, 0);
  assertEquals(result.goals.length, 0);
  assertEquals(result.confirmedInsights.length, 0);
});

Deno.test('loadUserContext - returns empty context on database error', async () => {
  const mockSupabase = createMockSupabase({
    data: null,
    error: { code: 'UNKNOWN', message: 'Database connection failed' },
  });

  // @ts-ignore - mock client
  const result = await loadUserContext(mockSupabase, 'user-123');

  // Should gracefully return empty context, not throw
  assertExists(result);
  assertEquals(result.hasContext, false);
  assertEquals(result.values.length, 0);
});

Deno.test('loadUserContext - handles null profile data', async () => {
  const mockSupabase = createMockSupabase({
    data: null,
    error: null,
  });

  // @ts-ignore - mock client
  const result = await loadUserContext(mockSupabase, 'user-123');

  assertEquals(result.hasContext, false);
  assertEquals(result.values.length, 0);
});

Deno.test('loadUserContext - handles empty arrays in profile', async () => {
  const mockSupabase = createMockSupabase({
    data: {
      values: [],
      goals: [],
      situation: {},
      extracted_insights: [],
    },
    error: null,
  });

  // @ts-ignore - mock client
  const result = await loadUserContext(mockSupabase, 'user-123');

  assertEquals(result.hasContext, false);
  assertEquals(result.values.length, 0);
  assertEquals(result.goals.length, 0);
});

Deno.test('loadUserContext - filters out values with empty content', async () => {
  const mockSupabase = createMockSupabase({
    data: {
      values: [
        { id: '1', content: 'valid', source: 'user', added_at: '2026-01-01' },
        { id: '2', content: '', source: 'user', added_at: '2026-01-01' },
        { id: '3', content: '   ', source: 'user', added_at: '2026-01-01' },
      ],
      goals: [],
      situation: {},
      extracted_insights: [],
    },
    error: null,
  });

  // @ts-ignore - mock client
  const result = await loadUserContext(mockSupabase, 'user-123');

  assertEquals(result.values.length, 1);
  assertEquals(result.values[0].content, 'valid');
});

// MARK: - formatContextForPrompt Tests

Deno.test('formatContextForPrompt - formats values section', () => {
  const context: UserContext = {
    values: mockValues,
    goals: [],
    situation: {},
    confirmedInsights: [],
    hasContext: true,
  };

  const formatted = formatContextForPrompt(context);

  assertEquals(formatted.valuesSection, 'honesty, growth');
});

Deno.test('formatContextForPrompt - formats goals section', () => {
  const context: UserContext = {
    values: [],
    goals: [mockGoals[0]], // Only active goal
    situation: {},
    confirmedInsights: [],
    hasContext: true,
  };

  const formatted = formatContextForPrompt(context);

  assertEquals(formatted.goalsSection, 'become a better leader');
});

Deno.test('formatContextForPrompt - formats situation section', () => {
  const context: UserContext = {
    values: [],
    goals: [],
    situation: mockSituation,
    confirmedInsights: [],
    hasContext: true,
  };

  const formatted = formatContextForPrompt(context);

  // Should combine all non-empty situation fields
  assertEquals(formatted.situationSection.includes('software engineer'), true);
  assertEquals(formatted.situationSection.includes('mid-career professional'), true);
  assertEquals(formatted.situationSection.includes('career transition'), true);
});

Deno.test('formatContextForPrompt - formats insights by category', () => {
  const context: UserContext = {
    values: [],
    goals: [],
    situation: {},
    confirmedInsights: [mockInsights[0]], // Only confirmed one
    hasContext: true,
  };

  const formatted = formatContextForPrompt(context);

  assertEquals(formatted.insightsSection.includes('values deep work'), true);
});

Deno.test('formatContextForPrompt - returns empty strings for empty context', () => {
  const context: UserContext = {
    values: [],
    goals: [],
    situation: {},
    confirmedInsights: [],
    hasContext: false,
  };

  const formatted = formatContextForPrompt(context);

  assertEquals(formatted.valuesSection, '');
  assertEquals(formatted.goalsSection, '');
  assertEquals(formatted.situationSection, '');
  assertEquals(formatted.insightsSection, '');
});
