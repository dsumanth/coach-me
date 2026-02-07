/**
 * prompt-builder.ts
 *
 * Story 2.4: Context Injection into Coaching Responses
 * Builds context-aware system prompts for personalized coaching
 *
 * Key feature: Instructs LLM to wrap context references in [MEMORY: ...] tags
 * for client-side visual highlighting (UX-4)
 */

import { UserContext, formatContextForPrompt } from './context-loader.ts';

// MARK: - Types

/** Coaching domain for specialized prompts (future: Story 3.1) */
export type CoachingDomain =
  | 'life'
  | 'career'
  | 'relationships'
  | 'mindset'
  | 'creativity'
  | 'fitness'
  | 'leadership'
  | 'general';

// MARK: - Prompt Templates

/** Base coaching system prompt */
const BASE_COACHING_PROMPT = `You are a warm, supportive life coach. Your role is to help users reflect, gain clarity, and take meaningful action in their lives.

Guidelines:
- Be warm, empathetic, and non-judgmental
- Ask thoughtful questions to help users explore their thoughts
- Never diagnose, prescribe, or claim clinical expertise
- If users mention crisis indicators (self-harm, suicide), acknowledge their feelings and encourage professional help
- Keep responses conversational and coaching-focused
- Reference previous parts of the conversation when relevant

Remember: You are a coach, not a therapist. Help users think through challenges and find their own insights.`;

/** Memory tagging instruction - appended when user has context */
const MEMORY_TAG_INSTRUCTION = `

IMPORTANT: When you reference the user's values, goals, life situation, or any personal context in your response, wrap that specific reference in [MEMORY: your reference here] tags. This helps highlight personalized moments in the conversation. Only tag direct references to their context, not general advice.

Examples:
- "Given that you value [MEMORY: honesty and authenticity], how does this situation align with that?"
- "I remember you mentioned [MEMORY: you're navigating a career transition] - how does this relate to that journey?"
- "Thinking about your goal of [MEMORY: becoming a better leader], what would that version of you do here?"`;

// MARK: - Prompt Building

/**
 * Build a personalized coaching system prompt with user context injected
 *
 * @param context - User's context (values, goals, situation, insights)
 * @param domain - Coaching domain (optional, defaults to 'general')
 * @returns Complete system prompt with context and memory tag instructions
 *
 * AC #1: Responses reference values, goals, or situation when relevant
 * AC #3: Handles empty context gracefully (omits empty sections)
 */
export function buildCoachingPrompt(
  context: UserContext | null,
  domain: CoachingDomain = 'general'
): string {
  let prompt = BASE_COACHING_PROMPT;

  // If no context or context is empty, return base prompt without memory tags
  if (!context || !context.hasContext) {
    return prompt;
  }

  // Format context sections
  const formatted = formatContextForPrompt(context);

  // Build context section - only include non-empty parts
  const contextParts: string[] = [];

  if (formatted.valuesSection) {
    contextParts.push(`User's core values: ${formatted.valuesSection}`);
  }

  if (formatted.goalsSection) {
    contextParts.push(`User's active goals: ${formatted.goalsSection}`);
  }

  if (formatted.situationSection) {
    contextParts.push(`User's life situation: ${formatted.situationSection}`);
  }

  if (formatted.insightsSection) {
    contextParts.push(`Additional context from conversations: ${formatted.insightsSection}`);
  }

  // Append context section if we have any content
  if (contextParts.length > 0) {
    prompt += `

---
USER CONTEXT (use this to personalize your coaching):

${contextParts.join('\n\n')}
---`;

    // Add memory tagging instruction when user has context
    prompt += MEMORY_TAG_INSTRUCTION;
  }

  return prompt;
}

/**
 * Build a minimal system prompt without context (for fallback/testing)
 * @returns Base coaching prompt without personalization
 */
export function buildBasePrompt(): string {
  return BASE_COACHING_PROMPT;
}

/**
 * Check if a response contains memory moment tags
 *
 * @param text - Response text to check
 * @returns true if text contains [MEMORY: ...] tags
 */
export function hasMemoryMoments(text: string): boolean {
  return /\[MEMORY:\s*.+?\s*\]/i.test(text);
}

/**
 * Extract memory moment content from tags
 *
 * @param text - Response text with memory tags
 * @returns Array of memory moment contents
 */
export function extractMemoryMoments(text: string): string[] {
  const pattern = /\[MEMORY:\s*(.+?)\s*\]/gi;
  const moments: string[] = [];
  let match;

  while ((match = pattern.exec(text)) !== null) {
    moments.push(match[1]);
  }

  return moments;
}

/**
 * Strip memory tags from text (for clean display)
 *
 * @param text - Text with [MEMORY: ...] tags
 * @returns Text with tags removed, content preserved
 */
export function stripMemoryTags(text: string): string {
  return text.replace(/\[MEMORY:\s*(.+?)\s*\]/gi, '$1');
}
