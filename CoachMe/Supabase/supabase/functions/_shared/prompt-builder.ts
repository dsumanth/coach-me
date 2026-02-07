/**
 * prompt-builder.ts
 *
 * Story 2.4: Context Injection into Coaching Responses
 * Story 3.1: Invisible Domain Routing — domain-specific coaching prompts
 * Story 3.2: Config-driven domain prompts (no hardcoded domain text)
 * Story 3.4: Pattern Recognition Across Conversations
 * Story 3.5: Cross-Domain Pattern Synthesis
 *
 * Builds context-aware, domain-specific system prompts for personalized coaching.
 * Key feature: Instructs LLM to wrap context references in [MEMORY: ...] tags
 * for client-side visual highlighting (UX-4) and recurring patterns in
 * [PATTERN: ...] tags for pattern insight highlighting (UX-5)
 */

import { UserContext, formatContextForPrompt } from './context-loader.ts';
import type { PastConversation } from './context-loader.ts';
import { getDomainConfig } from './domain-configs.ts';
import type { CrossDomainPattern } from './pattern-synthesizer.ts';

// MARK: - Types

/** Coaching domain for specialized prompts */
export type CoachingDomain =
  | 'life'
  | 'career'
  | 'relationships'
  | 'mindset'
  | 'creativity'
  | 'fitness'
  | 'leadership'
  | 'general';

/** Domain transition instruction — appended to all domain prompts (Task 2.4) */
const DOMAIN_TRANSITION_INSTRUCTION = `

IMPORTANT: If the user shifts topics during the conversation, adapt naturally without announcing a mode change. Never say things like "switching to career coaching mode" or "let me put on my relationships hat." Just follow the user's lead seamlessly.`;

/** Clarifying question instruction — used when domain confidence is low (Task 2.5) */
export const CLARIFY_INSTRUCTION = `

The coaching topic isn't entirely clear yet. Before diving deep, ask ONE natural grounding question to better understand what the user needs help with. Keep it warm and conversational — not a quiz. Example: "It sounds like there's a lot on your mind — what feels most important to explore right now?"`;

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

/** Pattern recognition instruction — appended when pastConversations is non-empty (Story 3.4) */
const PATTERN_TAG_INSTRUCTION = `

## PATTERN RECOGNITION

You have access to the user's conversation history across sessions. Look for RECURRING THEMES — topics, emotions, situations, or concerns that appear repeatedly (3 or more times across different conversations).

When you detect a genuine pattern with high confidence:
1. Surface it naturally using reflective coaching language: "I've noticed...", "This seems to come up for you...", "There's something I keep hearing..."
2. Wrap the core insight in [PATTERN: description] tags so it receives distinct visual treatment
3. Follow the pattern observation with a reflective question that invites the user to explore it

Examples:
- "I've noticed [PATTERN: you often describe feeling stuck right before a big transition]. What do you think that pattern means for you?"
- "There's something [PATTERN: about how you describe your relationship with control — it comes up in your work, your fitness goals, and your partnerships]. I'm curious what you make of that."

CRITICAL RULES:
- Only surface patterns when you're genuinely confident (theme appears 3+ times)
- NEVER force pattern observations — if there's no clear pattern, don't mention one
- Use warm, curious framing — you're reflecting, not diagnosing
- One pattern insight per response maximum — space them out for impact
- Pattern insights should feel like a moment of pause, not data analysis`;

/** Cross-domain pattern injection — appended when cross-domain patterns exist (Story 3.5, Task 3.2-3.5) */
const CROSS_DOMAIN_PATTERN_INSTRUCTION = `

## CROSS-DOMAIN PATTERNS DETECTED

The following patterns span multiple coaching domains for this user.
If relevant to the current conversation, you may reference ONE of them using
[PATTERN: your synthesis here] tags. Present with gentle curiosity,
not as a diagnosis. Surface at most ONE pattern per conversation.
Use phrasing like "I've noticed something interesting..." or "There's a thread I see across different areas of your life..."

Patterns:
`;

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
 * @param shouldClarify - Whether to add clarifying question instruction
 * @param pastConversations - Past conversation summaries for cross-session references
 * @param crossDomainPatterns - Cross-domain patterns to inject (Story 3.5)
 * @returns Complete system prompt with context and memory tag instructions
 *
 * AC #1: Responses reference values, goals, or situation when relevant
 * AC #3: Handles empty context gracefully (omits empty sections)
 */
export function buildCoachingPrompt(
  context: UserContext | null,
  domain: CoachingDomain = 'general',
  shouldClarify: boolean = false,
  pastConversations: PastConversation[] = [],
  crossDomainPatterns: CrossDomainPattern[] = [],
): string {
  let prompt = BASE_COACHING_PROMPT;

  // Story 3.2: Add domain-specific coaching from config (replaces hardcoded DOMAIN_PROMPTS)
  const domainConfig = getDomainConfig(domain);
  if (domainConfig.systemPromptAddition) {
    prompt += `\n\n${domainConfig.systemPromptAddition}`;
  }
  if (domainConfig.tone) {
    prompt += `\nCoaching tone: ${domainConfig.tone}`;
  }
  if (domainConfig.methodology) {
    prompt += `\nMethodology: ${domainConfig.methodology}`;
  }
  if (domainConfig.personality) {
    prompt += `\nPersonality: ${domainConfig.personality}`;
  }
  prompt += DOMAIN_TRANSITION_INSTRUCTION;

  // Add clarifying question instruction when confidence is low
  if (shouldClarify) {
    prompt += CLARIFY_INSTRUCTION;
  }

  // If no context or context is empty, skip context section but still add history
  if (!context || !context.hasContext) {
    // Story 3.3: Add cross-session history even without user context
    prompt += formatHistorySection(pastConversations);
    // Story 3.4: Add pattern recognition instruction when cross-session history exists
    if (pastConversations.length > 0) {
      prompt += PATTERN_TAG_INSTRUCTION;
    }
    // Story 3.5: Inject cross-domain patterns when available
    prompt += formatCrossDomainPatterns(crossDomainPatterns);
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

  // Story 3.3: Add cross-session history section
  prompt += formatHistorySection(pastConversations);

  // Story 3.4: Add pattern recognition instruction when cross-session history exists
  if (pastConversations.length > 0) {
    prompt += PATTERN_TAG_INSTRUCTION;
  }

  // Story 3.5: Inject cross-domain patterns when available
  prompt += formatCrossDomainPatterns(crossDomainPatterns);

  return prompt;
}

// MARK: - Cross-Session History (Story 3.3)

/**
 * Format past conversations into a PREVIOUS CONVERSATIONS section for the system prompt.
 * Omits the section entirely when no conversations are provided (AC #3).
 * Caps total section to ~500 tokens.
 *
 * @param pastConversations - Array of past conversation summaries
 * @returns Formatted history section string, or empty string if no history
 */
function formatHistorySection(pastConversations: PastConversation[]): string {
  if (!pastConversations.length) return '';

  let section = '\n\n## PREVIOUS CONVERSATIONS\n';
  section += 'The user has had these recent coaching conversations with you. ';
  section += 'Reference them naturally when relevant using [MEMORY: ...] tags, exactly as you do for context profile references.\n';
  section += 'Do NOT force references — only mention past conversations when the current topic genuinely connects.\n\n';

  for (const conv of pastConversations) {
    const domain = conv.domain ? ` (${conv.domain})` : '';
    const title = conv.title || 'Untitled conversation';
    section += `- ${title}${domain}: ${conv.summary}\n`;
  }

  return section;
}

// MARK: - Cross-Domain Pattern Injection (Story 3.5)

/**
 * Format cross-domain patterns into a prompt section.
 * Omits section entirely when no patterns are provided.
 * Instructs LLM to reference patterns with [PATTERN: ...] tags.
 *
 * @param patterns - Cross-domain patterns to inject
 * @returns Formatted pattern section string, or empty string if no patterns
 */
function formatCrossDomainPatterns(patterns: CrossDomainPattern[]): string {
  if (!patterns.length) return '';

  let section = CROSS_DOMAIN_PATTERN_INSTRUCTION;

  for (const pattern of patterns) {
    section += `- ${pattern.synthesis} (across ${pattern.domains.join(' and ')})\n`;
  }

  section += `\nPresent cross-domain insights with curiosity, not diagnosis. `;
  section += `Use reflective phrasing: "I've noticed something interesting..." or "There's a thread I see..."`;

  return section;
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

// MARK: - Pattern Insight Utilities (Story 3.4)

/**
 * Check if a response contains pattern insight tags
 *
 * @param text - Response text to check
 * @returns true if text contains [PATTERN: ...] tags
 */
export function hasPatternInsights(text: string): boolean {
  return /\[PATTERN:\s*.+?\s*\]/i.test(text);
}

/**
 * Extract pattern insight content from tags
 *
 * @param text - Response text with pattern tags
 * @returns Array of pattern insight contents
 */
export function extractPatternInsights(text: string): string[] {
  const pattern = /\[PATTERN:\s*(.+?)\s*\]/gi;
  const insights: string[] = [];
  let match;

  while ((match = pattern.exec(text)) !== null) {
    insights.push(match[1]);
  }

  return insights;
}

/**
 * Strip pattern tags from text (for clean display)
 *
 * @param text - Text with [PATTERN: ...] tags
 * @returns Text with tags removed, content preserved
 */
export function stripPatternTags(text: string): string {
  return text.replace(/\[PATTERN:\s*(.+?)\s*\]/gi, '$1');
}
