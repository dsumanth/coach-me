/**
 * prompt-builder.ts Tests
 * Story 2.4: Context Injection into Coaching Responses
 * Story 3.2: Config-driven domain prompts (no hardcoded domain text)
 *
 * Run with: deno test --allow-read --allow-env prompt-builder.test.ts
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
  hasPatternInsights,
  extractPatternInsights,
  stripPatternTags,
} from './prompt-builder.ts';

import type {
  UserContext,
  ContextValue,
  ContextGoal,
  ContextSituation,
  ExtractedInsight,
  PastConversation,
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

// MARK: - Story 3.2: Config-Driven Domain Prompt Tests

Deno.test('buildCoachingPrompt - career domain includes config-driven content', () => {
  const result = buildCoachingPrompt(null, 'career');
  assertStringIncludes(result, 'specializing in career coaching');
  assertStringIncludes(result, 'Coaching tone: professional, encouraging, action-oriented');
  assertStringIncludes(result, 'Methodology: goal-setting, accountability');
  assertStringIncludes(result, 'Personality: experienced career mentor');
});

Deno.test('buildCoachingPrompt - relationships domain includes config-driven content', () => {
  const result = buildCoachingPrompt(null, 'relationships');
  assertStringIncludes(result, 'specializing in relationship coaching');
  assertStringIncludes(result, 'Coaching tone: empathetic, perspective-taking');
  assertStringIncludes(result, 'Methodology: perspective-taking, active listening');
});

Deno.test('buildCoachingPrompt - mindset domain includes config-driven content', () => {
  const result = buildCoachingPrompt(null, 'mindset');
  assertStringIncludes(result, 'specializing in mindset coaching');
  assertStringIncludes(result, 'Coaching tone: cognitive, reframing');
  assertStringIncludes(result, 'Methodology: cognitive reframing');
});

Deno.test('buildCoachingPrompt - creativity domain includes config-driven content', () => {
  const result = buildCoachingPrompt(null, 'creativity');
  assertStringIncludes(result, 'specializing in creativity coaching');
  assertStringIncludes(result, 'Coaching tone: generative, expansive');
  assertStringIncludes(result, 'Methodology: divergent thinking');
});

Deno.test('buildCoachingPrompt - fitness domain includes config-driven content', () => {
  const result = buildCoachingPrompt(null, 'fitness');
  assertStringIncludes(result, 'specializing in fitness and wellness coaching');
  assertStringIncludes(result, 'Coaching tone: motivational, habit-focused');
  assertStringIncludes(result, 'Methodology: habit stacking');
});

Deno.test('buildCoachingPrompt - leadership domain includes config-driven content', () => {
  const result = buildCoachingPrompt(null, 'leadership');
  assertStringIncludes(result, 'specializing in leadership coaching');
  assertStringIncludes(result, 'Coaching tone: strategic, systems-thinking');
  assertStringIncludes(result, 'Methodology: systems thinking');
});

Deno.test('buildCoachingPrompt - life domain includes config-driven content', () => {
  const result = buildCoachingPrompt(null, 'life');
  assertStringIncludes(result, 'specializing in life coaching');
  assertStringIncludes(result, 'Coaching tone: reflective, exploratory');
  assertStringIncludes(result, 'Methodology: values clarification');
});

Deno.test('buildCoachingPrompt - general domain has tone but no systemPromptAddition', () => {
  const result = buildCoachingPrompt(null, 'general');
  // General has empty systemPromptAddition, so no specialization text
  assertEquals(result.includes('specializing in'), false);
  // But tone/methodology/personality from config are included
  assertStringIncludes(result, 'Coaching tone: warm, supportive, curious');
  assertStringIncludes(result, 'Methodology: active listening');
});

Deno.test('buildCoachingPrompt - all domains include transition instruction', () => {
  const domains = ['life', 'career', 'relationships', 'mindset', 'creativity', 'fitness', 'leadership', 'general'] as const;
  for (const domain of domains) {
    const result = buildCoachingPrompt(null, domain);
    assertStringIncludes(result, 'adapt naturally without announcing a mode change');
  }
});

Deno.test('buildCoachingPrompt - each domain produces distinct prompt', () => {
  const prompts = new Set<string>();
  const domains = ['life', 'career', 'relationships', 'mindset', 'creativity', 'fitness', 'leadership', 'general'] as const;
  for (const domain of domains) {
    prompts.add(buildCoachingPrompt(null, domain));
  }
  // All 8 domains should produce distinct prompts
  assertEquals(prompts.size, 8);
});

Deno.test('buildCoachingPrompt - shouldClarify adds clarification instruction', () => {
  const result = buildCoachingPrompt(null, 'general', true);
  assertStringIncludes(result, 'grounding question');
  assertStringIncludes(result, 'what feels most important');
});

Deno.test('buildCoachingPrompt - shouldClarify false omits clarification instruction', () => {
  const result = buildCoachingPrompt(null, 'general', false);
  assertEquals(result.includes('grounding question'), false);
});

Deno.test('buildCoachingPrompt - domain with context includes both domain and context sections', () => {
  const result = buildCoachingPrompt(fullContext, 'career');
  // Has domain config content
  assertStringIncludes(result, 'specializing in career coaching');
  assertStringIncludes(result, 'Coaching tone:');
  // Has context section
  assertStringIncludes(result, 'core values');
  assertStringIncludes(result, 'honesty');
  // Has memory tag instruction
  assertStringIncludes(result, '[MEMORY:');
});

Deno.test('buildCoachingPrompt - defaults to general when no domain specified', () => {
  const result = buildCoachingPrompt(null);
  // Defaults to general config (no systemPromptAddition)
  assertEquals(result.includes('specializing in'), false);
  assertStringIncludes(result, 'Coaching tone: warm, supportive, curious');
});

// MARK: - Story 3.3: Cross-Session History Tests

const mockPastConversations: PastConversation[] = [
  {
    conversationId: 'conv-1',
    title: 'Career planning',
    domain: 'career',
    summary: 'Career: Discussed upcoming promotion interview',
    lastMessageAt: '2026-02-01T10:00:00Z',
  },
  {
    conversationId: 'conv-2',
    title: 'Stress management',
    domain: 'mindset',
    summary: 'Mindset: Feeling overwhelmed at work',
    lastMessageAt: '2026-01-30T10:00:00Z',
  },
];

Deno.test('buildCoachingPrompt - includes PREVIOUS CONVERSATIONS section when history present', () => {
  const result = buildCoachingPrompt(null, 'general', false, mockPastConversations);

  assertStringIncludes(result, '## PREVIOUS CONVERSATIONS');
  assertStringIncludes(result, 'Career planning');
  assertStringIncludes(result, 'Stress management');
});

Deno.test('buildCoachingPrompt - omits history section entirely when history empty', () => {
  const result = buildCoachingPrompt(null, 'general', false, []);

  assertEquals(result.includes('PREVIOUS CONVERSATIONS'), false);
});

Deno.test('buildCoachingPrompt - includes memory tag instruction for cross-session references', () => {
  const result = buildCoachingPrompt(null, 'general', false, mockPastConversations);

  assertStringIncludes(result, '[MEMORY: ...]');
  assertStringIncludes(result, 'Reference them naturally');
});

Deno.test('buildCoachingPrompt - includes natural-reference instruction (no forced references)', () => {
  const result = buildCoachingPrompt(null, 'general', false, mockPastConversations);

  assertStringIncludes(result, 'Do NOT force references');
  assertStringIncludes(result, 'genuinely connects');
});

Deno.test('buildCoachingPrompt - formats each conversation with title, domain, and summary', () => {
  const result = buildCoachingPrompt(null, 'general', false, mockPastConversations);

  assertStringIncludes(result, 'Career planning (career)');
  assertStringIncludes(result, 'Discussed upcoming promotion interview');
  assertStringIncludes(result, 'Stress management (mindset)');
  assertStringIncludes(result, 'Feeling overwhelmed at work');
});

Deno.test('buildCoachingPrompt - history works alongside context', () => {
  const result = buildCoachingPrompt(fullContext, 'career', false, mockPastConversations);

  // Has context section
  assertStringIncludes(result, 'core values');
  assertStringIncludes(result, 'honesty');
  // Has history section
  assertStringIncludes(result, 'PREVIOUS CONVERSATIONS');
  assertStringIncludes(result, 'Career planning');
  // Has domain
  assertStringIncludes(result, 'specializing in career coaching');
});

Deno.test('buildCoachingPrompt - handles conversation without domain', () => {
  const noDomainConvs: PastConversation[] = [
    {
      conversationId: 'conv-3',
      title: null,
      domain: null,
      summary: 'General coaching conversation',
      lastMessageAt: '2026-01-28T10:00:00Z',
    },
  ];

  const result = buildCoachingPrompt(null, 'general', false, noDomainConvs);

  assertStringIncludes(result, 'PREVIOUS CONVERSATIONS');
  // Should use "Untitled conversation" for null title
  assertStringIncludes(result, 'Untitled conversation');
  // Should not have domain in parentheses
  assertEquals(result.includes('(null)'), false);
});

// MARK: - Story 3.4: Pattern Recognition Instruction Tests

Deno.test('buildCoachingPrompt - includes PATTERN_TAG_INSTRUCTION when pastConversations is non-empty', () => {
  const result = buildCoachingPrompt(null, 'general', false, mockPastConversations);

  assertStringIncludes(result, 'PATTERN RECOGNITION');
  assertStringIncludes(result, '[PATTERN:');
});

Deno.test('buildCoachingPrompt - does NOT include PATTERN_TAG_INSTRUCTION when pastConversations is empty', () => {
  const result = buildCoachingPrompt(null, 'general', false, []);

  assertEquals(result.includes('PATTERN RECOGNITION'), false);
  assertEquals(result.includes('[PATTERN:'), false);
});

Deno.test('buildCoachingPrompt - includes 3+ times threshold in pattern instruction', () => {
  const result = buildCoachingPrompt(null, 'general', false, mockPastConversations);

  assertStringIncludes(result, '3 or more times');
  assertStringIncludes(result, '3+ times');
});

Deno.test('buildCoachingPrompt - includes natural framing guidance (I have noticed, not Analysis shows)', () => {
  const result = buildCoachingPrompt(null, 'general', false, mockPastConversations);

  assertStringIncludes(result, "I've noticed");
  assertStringIncludes(result, 'warm, curious framing');
  assertStringIncludes(result, 'reflecting, not diagnosing');
});

Deno.test('buildCoachingPrompt - includes anti-forcing instruction', () => {
  const result = buildCoachingPrompt(null, 'general', false, mockPastConversations);

  assertStringIncludes(result, 'NEVER force pattern observations');
});

Deno.test('buildCoachingPrompt - includes pattern instruction with context present', () => {
  const result = buildCoachingPrompt(fullContext, 'career', false, mockPastConversations);

  // Has context section
  assertStringIncludes(result, 'core values');
  // Has history section
  assertStringIncludes(result, 'PREVIOUS CONVERSATIONS');
  // Has pattern recognition instruction
  assertStringIncludes(result, 'PATTERN RECOGNITION');
});

Deno.test('buildCoachingPrompt - pattern instruction works without user context', () => {
  const result = buildCoachingPrompt(emptyContext, 'general', false, mockPastConversations);

  // No context section
  assertEquals(result.includes('core values'), false);
  // Has history section
  assertStringIncludes(result, 'PREVIOUS CONVERSATIONS');
  // Has pattern recognition instruction
  assertStringIncludes(result, 'PATTERN RECOGNITION');
});

// MARK: - Story 3.4: hasPatternInsights Tests

Deno.test('hasPatternInsights - detects [PATTERN: content] tags', () => {
  const text = "I've noticed [PATTERN: you feel stuck before transitions]. What does that mean?";
  assertEquals(hasPatternInsights(text), true);
});

Deno.test('hasPatternInsights - returns false for [MEMORY: content] tags', () => {
  const text = 'Given your value of [MEMORY: honesty], what would you do?';
  assertEquals(hasPatternInsights(text), false);
});

Deno.test('hasPatternInsights - returns false for plain text', () => {
  const text = 'This is a regular coaching response.';
  assertEquals(hasPatternInsights(text), false);
});

Deno.test('hasPatternInsights - detects multiple [PATTERN: ...] tags', () => {
  const text = "I see [PATTERN: fear of change] and [PATTERN: desire for control].";
  assertEquals(hasPatternInsights(text), true);
});

Deno.test('hasPatternInsights - handles whitespace in tag', () => {
  const text = 'I noticed [PATTERN:  stuck before transitions  ].';
  assertEquals(hasPatternInsights(text), true);
});

// MARK: - Story 3.4: extractPatternInsights Tests

Deno.test('extractPatternInsights - extracts content from [PATTERN: ...] tags', () => {
  const text = "I've noticed [PATTERN: you feel stuck before transitions].";
  const insights = extractPatternInsights(text);

  assertEquals(insights.length, 1);
  assertEquals(insights[0], 'you feel stuck before transitions');
});

Deno.test('extractPatternInsights - returns empty array for text without pattern tags', () => {
  const text = 'This has no pattern references.';
  const insights = extractPatternInsights(text);

  assertEquals(insights.length, 0);
});

Deno.test('extractPatternInsights - extracts multiple pattern contents', () => {
  const text = "There's [PATTERN: fear of change] and [PATTERN: desire for control].";
  const insights = extractPatternInsights(text);

  assertEquals(insights.length, 2);
  assertEquals(insights[0], 'fear of change');
  assertEquals(insights[1], 'desire for control');
});

Deno.test('extractPatternInsights - trims whitespace from content', () => {
  const text = '[PATTERN:   stuck before transitions   ]';
  const insights = extractPatternInsights(text);

  assertEquals(insights[0], 'stuck before transitions');
});

Deno.test('extractPatternInsights - does not extract [MEMORY:] tags', () => {
  const text = 'Given [MEMORY: honesty] and your [PATTERN: fear of change].';
  const insights = extractPatternInsights(text);

  assertEquals(insights.length, 1);
  assertEquals(insights[0], 'fear of change');
});

// MARK: - Story 3.4: stripPatternTags Tests

Deno.test('stripPatternTags - removes [PATTERN: ...] wrapper but preserves content', () => {
  const text = "I noticed [PATTERN: you feel stuck before transitions] in your conversations.";
  const result = stripPatternTags(text);

  assertEquals(result, "I noticed you feel stuck before transitions in your conversations.");
});

Deno.test('stripPatternTags - handles multiple tags in same text', () => {
  const text = "There's [PATTERN: fear of change] and [PATTERN: desire for control].";
  const result = stripPatternTags(text);

  assertEquals(result, "There's fear of change and desire for control.");
});

Deno.test('stripPatternTags - returns unchanged text when no tags present', () => {
  const text = 'No pattern tags here.';
  const result = stripPatternTags(text);

  assertEquals(result, text);
});

Deno.test('stripPatternTags - does not strip [MEMORY:] tags', () => {
  const text = 'Given [MEMORY: honesty] and [PATTERN: fear of change].';
  const result = stripPatternTags(text);

  assertEquals(result, 'Given [MEMORY: honesty] and fear of change.');
});

// MARK: - Story 3.5: Cross-Domain Pattern Injection Tests (Task 10.4)

import type { CrossDomainPattern } from './pattern-synthesizer.ts';

const mockCrossDomainPatterns: CrossDomainPattern[] = [
  {
    theme: 'control and perfectionism',
    domains: ['career', 'relationships'],
    confidence: 0.92,
    evidence: [
      { domain: 'career', summary: 'Need to control outcomes at work' },
      { domain: 'relationships', summary: 'Control patterns in personal relationships' },
    ],
    synthesis: 'A need for control appears in both your career decisions and personal relationships',
  },
];

Deno.test('buildCoachingPrompt - includes CROSS-DOMAIN PATTERNS section when patterns provided', () => {
  const result = buildCoachingPrompt(null, 'general', false, [], mockCrossDomainPatterns);

  assertStringIncludes(result, 'CROSS-DOMAIN PATTERNS DETECTED');
  assertStringIncludes(result, 'A need for control appears in both your career decisions and personal relationships');
});

Deno.test('buildCoachingPrompt - includes domain names in cross-domain section', () => {
  const result = buildCoachingPrompt(null, 'general', false, [], mockCrossDomainPatterns);

  assertStringIncludes(result, 'career and relationships');
});

Deno.test('buildCoachingPrompt - omits cross-domain section when no patterns', () => {
  const result = buildCoachingPrompt(null, 'general', false, [], []);

  assertEquals(result.includes('CROSS-DOMAIN PATTERNS DETECTED'), false);
});

Deno.test('buildCoachingPrompt - cross-domain patterns work alongside context', () => {
  const result = buildCoachingPrompt(fullContext, 'career', false, mockPastConversations, mockCrossDomainPatterns);

  // Has context section
  assertStringIncludes(result, 'core values');
  // Has history section
  assertStringIncludes(result, 'PREVIOUS CONVERSATIONS');
  // Has cross-domain pattern section
  assertStringIncludes(result, 'CROSS-DOMAIN PATTERNS DETECTED');
  assertStringIncludes(result, 'career and relationships');
});

Deno.test('buildCoachingPrompt - cross-domain patterns work without context', () => {
  const result = buildCoachingPrompt(emptyContext, 'general', false, [], mockCrossDomainPatterns);

  // No context section
  assertEquals(result.includes('core values'), false);
  // Has cross-domain pattern section
  assertStringIncludes(result, 'CROSS-DOMAIN PATTERNS DETECTED');
});

Deno.test('buildCoachingPrompt - cross-domain section includes curiosity framing instruction', () => {
  const result = buildCoachingPrompt(null, 'general', false, [], mockCrossDomainPatterns);

  assertStringIncludes(result, 'curiosity');
  assertStringIncludes(result, 'not as a diagnosis');
});

Deno.test('buildCoachingPrompt - cross-domain section instructs max ONE pattern per conversation', () => {
  const result = buildCoachingPrompt(null, 'general', false, [], mockCrossDomainPatterns);

  assertStringIncludes(result, 'ONE');
});
