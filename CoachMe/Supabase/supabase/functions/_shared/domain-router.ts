/**
 * domain-router.ts
 *
 * Story 3.1: Invisible Domain Routing
 * Story 3.2: Config-driven keywords (no hardcoded keyword arrays)
 *
 * Classifies coaching domain from conversation content using a fast LLM call.
 * Domain routing is invisible to the user — no UI changes.
 *
 * Performance budget: <100ms total for classification
 * Confidence threshold: 0.7 for initial, 0.85 for domain switch
 */

import type { CoachingDomain } from './prompt-builder.ts';
import { getDomainKeywords, getAllDomainConfigs } from './domain-configs.ts';

// MARK: - Types

/** Result of domain classification */
export interface DomainResult {
  domain: CoachingDomain;
  confidence: number;
  shouldClarify: boolean;
}

/** Conversation context for domain routing */
export interface ConversationDomainContext {
  currentDomain: CoachingDomain | null;
  recentMessages: Array<{ role: string; content: string }>;
}

// MARK: - Constants

const INITIAL_CONFIDENCE_THRESHOLD = 0.7;
const DOMAIN_SWITCH_CONFIDENCE_THRESHOLD = 0.85;

// MARK: - Classification Prompt

/**
 * Build the classification prompt for the LLM.
 * Kept minimal (<200 tokens input) for speed.
 */
export function buildClassificationPrompt(
  message: string,
  recentMessages: Array<{ role: string; content: string }>,
  currentDomain: CoachingDomain | null,
): string {
  const contextLines = recentMessages
    .slice(-3)
    .map((m) => `${m.role}: ${m.content}`)
    .join('\n');

  const currentDomainHint = currentDomain
    ? `\nCurrent conversation domain: ${currentDomain}`
    : '';

  return `Classify the coaching domain for this user message. Respond with ONLY valid JSON.

Domains: life, career, relationships, mindset, creativity, fitness, leadership, general

Rules:
- "general" means the message doesn't clearly fit any specific domain
- Confidence is 0.0 to 1.0 (how certain you are)
- Consider conversation context for continuity${currentDomainHint}

Recent context:
${contextLines}

Current message: ${message}

Respond with JSON only: {"domain":"<domain>","confidence":<number>}`;
}

// MARK: - Topic Shift Detection (Task 1.7)

/**
 * Lightweight shift-detection gate.
 * Checks whether the new message likely shifted topics from the current domain.
 * This is a cheap binary gate — NOT a domain classifier.
 *
 * Returns true if a potential shift is detected (should trigger LLM re-classification).
 * Returns false if the message appears to stay in the current domain (skip LLM call).
 */
export function detectTopicShift(
  message: string,
  currentDomain: CoachingDomain | null,
): boolean {
  // No existing domain — always classify
  if (!currentDomain || currentDomain === 'general') {
    return true;
  }

  const lowerMessage = message.toLowerCase();
  const currentKeywords = getDomainKeywords(currentDomain);

  // Check if message contains any keywords from current domain
  const hasCurrentDomainKeyword = currentKeywords.some((kw) =>
    lowerMessage.includes(kw.toLowerCase())
  );

  // Check if message contains keywords from a different domain (config-driven)
  const allConfigs = getAllDomainConfigs();
  const hasOtherDomainKeyword = Array.from(allConfigs.entries()).some(
    ([domain, config]) => {
      if (domain === currentDomain) return false;
      return config.domainKeywords.some((kw) => lowerMessage.includes(kw.toLowerCase()));
    },
  );

  // Potential shift: no current domain keywords AND has other domain keywords
  if (!hasCurrentDomainKeyword && hasOtherDomainKeyword) {
    return true;
  }

  return false;
}

// MARK: - LLM Classification

/**
 * Call a fast LLM to classify the domain.
 * Uses the cheapest/fastest model for <100ms classification.
 */
async function classifyWithLLM(
  message: string,
  recentMessages: Array<{ role: string; content: string }>,
  currentDomain: CoachingDomain | null,
): Promise<DomainResult> {
  const apiKey = Deno.env.get('ANTHROPIC_API_KEY');
  if (!apiKey) {
    console.error('ANTHROPIC_API_KEY not configured for domain classification');
    return { domain: 'general', confidence: 0, shouldClarify: false };
  }

  const classificationPrompt = buildClassificationPrompt(
    message,
    recentMessages,
    currentDomain,
  );

  try {
    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: 'claude-haiku-4-5-20251001',
        max_tokens: 50,
        temperature: 0,
        messages: [{ role: 'user', content: classificationPrompt }],
      }),
    });

    if (!response.ok) {
      console.error('Domain classification API error:', response.status);
      return { domain: 'general', confidence: 0, shouldClarify: false };
    }

    const data = await response.json();
    const text = data.content?.[0]?.text ?? '';

    return parseLLMResponse(text, currentDomain);
  } catch (error) {
    console.error('Domain classification failed:', error);
    return { domain: 'general', confidence: 0, shouldClarify: false };
  }
}

// MARK: - Response Parsing

/**
 * Parse the LLM's JSON response into a DomainResult.
 * Handles malformed responses gracefully by falling back to 'general'.
 *
 * Confidence handling:
 * - Missing or non-numeric confidence is treated as invalid: falls back to
 *   domain='general', shouldClarify=true so the coach can gather more context.
 * - Out-of-range values (< 0 or > 1) are coerced to a neutral default of 0.5
 *   (midpoint chosen to avoid optimistic or pessimistic bias). The parsed domain
 *   is preserved since the LLM did provide one.
 */
export function parseLLMResponse(
  text: string,
  currentDomain: CoachingDomain | null,
): DomainResult {
  const validDomains = [
    'life', 'career', 'relationships', 'mindset',
    'creativity', 'fitness', 'leadership', 'general',
  ];

  try {
    // Extract JSON from potential markdown code blocks
    const jsonMatch = text.match(/\{[^}]+\}/);
    if (!jsonMatch) {
      return { domain: 'general', confidence: 0, shouldClarify: false };
    }

    const parsed = JSON.parse(jsonMatch[0]);
    const domain = parsed.domain as string;
    const rawConfidence = parsed.confidence;
    const confidence = Number(rawConfidence);

    // Validate domain
    if (!validDomains.includes(domain)) {
      console.warn(`Invalid domain returned: ${domain}, using general`);
      return { domain: 'general', confidence: 0, shouldClarify: false };
    }

    // Missing or non-numeric confidence → treat as unknown, fall back to general
    if (rawConfidence === undefined || rawConfidence === null || isNaN(confidence)) {
      return { domain: 'general', confidence: 0, shouldClarify: true };
    }

    // Out-of-range confidence → coerce to neutral 0.5 default, preserve domain
    if (confidence < 0 || confidence > 1) {
      return { domain: domain as CoachingDomain, confidence: 0.5, shouldClarify: false };
    }

    // Determine threshold based on whether this is a domain switch
    const threshold = currentDomain && currentDomain !== 'general' && domain !== currentDomain
      ? DOMAIN_SWITCH_CONFIDENCE_THRESHOLD
      : INITIAL_CONFIDENCE_THRESHOLD;

    // Below threshold: use general with clarify instruction
    if (confidence < threshold) {
      // If switching domain but below switch threshold, keep current domain
      if (currentDomain && currentDomain !== 'general' && domain !== currentDomain) {
        return {
          domain: currentDomain,
          confidence,
          shouldClarify: false,
        };
      }
      return {
        domain: 'general',
        confidence,
        shouldClarify: true,
      };
    }

    return {
      domain: domain as CoachingDomain,
      confidence,
      shouldClarify: false,
    };
  } catch {
    return { domain: 'general', confidence: 0, shouldClarify: false };
  }
}

// MARK: - Main Entry Point

/**
 * Determine the coaching domain for a message.
 *
 * Pipeline:
 * 1. If no existing domain → full LLM classification
 * 2. If existing domain → run shift-detection gate
 * 3. If shift detected → LLM re-classification with higher threshold
 * 4. If no shift → keep current domain (zero latency)
 *
 * @param message - The user's current message
 * @param context - Conversation context (current domain, recent messages)
 * @returns DomainResult with classified domain, confidence, and clarify flag
 */
export async function determineDomain(
  message: string,
  context: ConversationDomainContext,
): Promise<DomainResult> {
  const { currentDomain, recentMessages } = context;

  // First message or no domain — always classify
  if (!currentDomain || currentDomain === 'general') {
    return await classifyWithLLM(message, recentMessages, currentDomain);
  }

  // Existing domain — check for topic shift first (cheap gate)
  const shifted = detectTopicShift(message, currentDomain);

  if (!shifted) {
    // No shift detected — keep current domain, zero additional latency
    return {
      domain: currentDomain,
      confidence: 1.0,
      shouldClarify: false,
    };
  }

  // Potential shift detected — run full LLM classification with higher threshold
  return await classifyWithLLM(message, recentMessages, currentDomain);
}
