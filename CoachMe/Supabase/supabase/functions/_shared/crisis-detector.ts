/**
 * crisis-detector.ts
 *
 * Story 4.1: Crisis Detection Pipeline
 *
 * Two-tier crisis detection for user messages:
 * - Tier 1: Keyword/phrase matching (fast path, <10ms)
 * - Tier 2: LLM classification for ambiguous messages (<150ms)
 *
 * Design principle: False positives are acceptable; false negatives are not.
 * Fail-open: On any error, returns crisisDetected = false (never block coaching).
 */

import { streamChatCompletion, type ChatMessage } from './llm-client.ts';
import { selectSafetyClassifierModel, enforceInputTokenBudget } from './model-routing.ts';

// MARK: - Types

/** Crisis category classification */
export type CrisisCategory =
  | 'self_harm'
  | 'suicidal_ideation'
  | 'abuse'
  | 'severe_distress'
  | 'other';

/** Result of crisis detection analysis */
export interface CrisisDetectionResult {
  crisisDetected: boolean;
  confidence: number;
  indicators: string[];
  category: CrisisCategory | null;
}

// MARK: - Crisis Resources

/** Crisis resource contact information */
export const CRISIS_RESOURCES = {
  lifeline: {
    name: '988 Suicide & Crisis Lifeline',
    phone: '988',
    text: null,
  },
  crisisText: {
    name: 'Crisis Text Line',
    phone: null,
    text: 'Text HOME to 741741',
  },
} as const;

// MARK: - Keyword Detection (Tier 1)

/** High-signal crisis keywords/phrases — case-insensitive matching */
const CRISIS_KEYWORDS = [
  // Self-harm
  'kill myself', 'hurt myself', 'cutting myself', 'self-harm', 'self harm',
  'harming myself', 'injure myself',
  // Suicidal ideation
  'want to die', 'wanna die', 'better off dead', 'end it all', 'end my life',
  'no reason to live', 'no point in living', 'suicide', 'suicidal',
  "can't go on", 'rather be dead', 'wish i was dead', 'wish i were dead',
  'take my own life', "don't want to be alive", "don't want to live",
  // Abuse
  'being abused', 'he hits me', 'she hits me', 'they hit me',
  'sexual abuse', 'domestic violence', 'being hurt by',
  // Severe distress
  'going to hurt someone', 'want to hurt someone',
];

/** Map keywords to crisis categories */
function categorizeKeyword(keyword: string): CrisisCategory {
  const selfHarm = ['kill myself', 'hurt myself', 'cutting myself', 'self-harm', 'self harm', 'harming myself', 'injure myself'];
  const suicidal = [
    'want to die', 'wanna die', 'better off dead', 'end it all', 'end my life',
    'no reason to live', 'no point in living', 'suicide', 'suicidal',
    "can't go on", 'rather be dead', 'wish i was dead', 'wish i were dead',
    'take my own life', "don't want to be alive", "don't want to live",
  ];
  const abuse = ['being abused', 'he hits me', 'she hits me', 'they hit me', 'sexual abuse', 'domestic violence', 'being hurt by'];

  if (selfHarm.includes(keyword)) return 'self_harm';
  if (suicidal.includes(keyword)) return 'suicidal_ideation';
  if (abuse.includes(keyword)) return 'abuse';
  return 'severe_distress';
}

// MARK: - LLM Classification (Tier 2)

const CRISIS_CLASSIFICATION_PROMPT = `You are a crisis detection system for an AI coaching app.
Analyze the user's message (and recent conversation context if provided) to determine if the user is experiencing a mental health crisis that requires professional intervention.

Crisis indicators include:
- Suicidal ideation or self-harm intent
- Abuse (physical, sexual, emotional) — being experienced or witnessed
- Severe psychological distress beyond normal stress/frustration
- Intent to harm others

Important:
- A user discussing career frustration, relationship problems, or general sadness is NOT a crisis
- A user who says "this job is killing me" is using a figure of speech, NOT a crisis
- Context matters: escalating desperation across messages IS a signal
- When uncertain, err toward flagging as crisis (safety first)

Return ONLY valid JSON:
{ "crisis": boolean, "confidence": 0.0-1.0, "category": "self_harm"|"suicidal_ideation"|"abuse"|"severe_distress"|"none", "reasoning": "brief explanation" }`;

/**
 * Classify a message using a lightweight LLM call.
 * Uses safety classifier routing policy.
 */
async function classifyWithLLM(
  message: string,
  recentMessages: { role: string; content: string }[],
): Promise<CrisisDetectionResult> {
  if (!Deno.env.get('OPENAI_API_KEY')) {
    // Fail-open: no API key means we can't classify
    return { crisisDetected: false, confidence: 0, indicators: [], category: null };
  }

  // Build context from recent messages
  let userContent = `Current message: "${message}"`;
  if (recentMessages.length > 0) {
    const contextStr = recentMessages
      .map((m) => `${m.role}: ${m.content}`)
      .join('\n');
    userContent += `\n\nRecent conversation context:\n${contextStr}`;
  }

  const route = selectSafetyClassifierModel();
  const messages: ChatMessage[] = [
    { role: 'system', content: CRISIS_CLASSIFICATION_PROMPT },
    { role: 'user', content: userContent },
  ];
  const budgetedMessages = enforceInputTokenBudget(messages, route.inputBudgetTokens);

  let text = '';
  for await (const chunk of streamChatCompletion(budgetedMessages, {
    provider: route.provider,
    model: route.model,
    maxTokens: route.maxOutputTokens,
    temperature: route.temperature,
  })) {
    if (chunk.type === 'token' && chunk.content) {
      text += chunk.content;
    }
    if (chunk.type === 'error') {
      return { crisisDetected: false, confidence: 0, indicators: [], category: null };
    }
  }

  // Parse the JSON response — fail-open on malformed LLM output
  let confidence = 0;
  let category: CrisisCategory | null = null;
  let indicators: string[] = [];

  try {
    const parsed = JSON.parse(text);
    confidence = typeof parsed.confidence === 'number' ? parsed.confidence : 0;
    category = parsed.category !== 'none' ? (parsed.category as CrisisCategory) : null;
    indicators = parsed.reasoning ? [parsed.reasoning] : [];
  } catch (parseError) {
    console.error('Crisis detector: failed to parse LLM response:', parseError, '| Raw text:', text);
    // Safe defaults — fail-open (no crisis detected)
  }

  return {
    crisisDetected: confidence >= 0.6, // Err on side of caution (AC #4)
    confidence,
    indicators,
    category: confidence >= 0.6 ? category : null,
  };
}

// MARK: - Ambiguity Detection

/** Indicators that a message might warrant LLM classification */
const AMBIGUITY_INDICATORS = [
  "don't see the point",
  'nothing matters',
  'i give up',
  "can't take it",
  "can't do this anymore",
  'no way out',
  'trapped',
  'hopeless',
  'worthless',
  'nobody cares',
  'alone in this',
  "can't breathe",
  'falling apart',
  'breaking down',
  'losing it',
];

/**
 * Check if a message has ambiguous indicators that warrant LLM classification.
 */
function hasAmbiguousIndicators(messageLower: string): boolean {
  return AMBIGUITY_INDICATORS.some((indicator) => messageLower.includes(indicator));
}

// MARK: - Main Detection Function

/**
 * Detect crisis indicators in a user message.
 *
 * Two-tier approach:
 * 1. Keyword scan (<10ms) — high-confidence phrases
 * 2. LLM classification (<150ms) — ambiguous messages with context
 *
 * Fail-open: On any error, returns crisisDetected = false.
 *
 * @param message - The user's message to analyze
 * @param recentMessages - Last 2-3 messages for context (optional)
 * @returns CrisisDetectionResult with detection status and details
 */
export async function detectCrisis(
  message: string,
  recentMessages: { role: string; content: string }[] = [],
): Promise<CrisisDetectionResult> {
  try {
    const messageLower = message.toLowerCase();

    // Tier 1: Keyword/phrase matching (fast path, <10ms)
    for (const keyword of CRISIS_KEYWORDS) {
      if (messageLower.includes(keyword)) {
        return {
          crisisDetected: true,
          confidence: 0.9,
          indicators: [keyword],
          category: categorizeKeyword(keyword),
        };
      }
    }

    // Check for ambiguous indicators that might need LLM classification
    if (hasAmbiguousIndicators(messageLower)) {
      // Tier 2: LLM classification for ambiguous messages
      return await classifyWithLLM(message, recentMessages);
    }

    // Check recent messages for escalating distress patterns
    if (recentMessages.length >= 2) {
      const recentContent = recentMessages
        .filter((m) => m.role === 'user')
        .map((m) => m.content.toLowerCase())
        .join(' ');

      if (hasAmbiguousIndicators(recentContent)) {
        // Context shows concerning pattern — classify with LLM
        return await classifyWithLLM(message, recentMessages);
      }
    }

    // No crisis indicators detected
    return {
      crisisDetected: false,
      confidence: 0,
      indicators: [],
      category: null,
    };
  } catch (_error) {
    // Fail-open: on any error, allow normal coaching to proceed (AC #7)
    console.error('Crisis detection error (fail-open):', _error);
    return {
      crisisDetected: false,
      confidence: 0,
      indicators: [],
      category: null,
    };
  }
}
