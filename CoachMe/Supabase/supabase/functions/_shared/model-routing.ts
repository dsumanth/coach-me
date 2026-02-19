/**
 * model-routing.ts
 *
 * Centralized LLM routing policy for chat + background tasks.
 * This keeps model decisions explicit, testable, and consistent across functions.
 */

import type { ChatMessage, LLMConfig } from './llm-client.ts';

export type SessionMode = 'discovery' | 'coaching' | 'blocked';

export type BackgroundTask =
  | 'domain_classification'
  | 'pattern_synthesis'
  | 'context_extraction'
  | 'push_generation'
  | 'summary'
  | 'labeling'
  | 'memory_compression';

export interface ModelSelection {
  provider: LLMConfig['provider'];
  model: string;
  maxOutputTokens: number;
  temperature: number;
  inputBudgetTokens: number;
  routeTier: 'primary' | 'escalation' | 'background' | 'safety';
  routeReason: string;
}

export interface ChatRoutingInput {
  sessionMode: SessionMode;
  message: string;
  recentUserMessages: string[];
  crisisDetected: boolean;
  crisisConfidence: number;
}

const PRIMARY_CHAT_MODEL: Omit<ModelSelection, 'routeReason'> = {
  provider: 'anthropic',
  model: 'claude-haiku-4-5-20251001',
  maxOutputTokens: 1300,
  temperature: 0.65,
  inputBudgetTokens: 5600,
  routeTier: 'primary',
};

const DISCOVERY_CHAT_MODEL: Omit<ModelSelection, 'routeReason'> = {
  provider: 'anthropic',
  model: 'claude-haiku-4-5-20251001',
  maxOutputTokens: 900,
  temperature: 0.7,
  inputBudgetTokens: 4200,
  routeTier: 'primary',
};

const ESCALATION_CHAT_MODEL: Omit<ModelSelection, 'routeReason'> = {
  provider: 'anthropic',
  model: 'claude-sonnet-4-5-20250929',
  maxOutputTokens: 2200,
  temperature: 0.55,
  inputBudgetTokens: 8400,
  routeTier: 'escalation',
};

const SAFETY_CLASSIFIER_MODEL: Omit<ModelSelection, 'routeReason'> = {
  provider: 'openai',
  model: 'gpt-5-mini',
  maxOutputTokens: 140,
  temperature: 0,
  inputBudgetTokens: 1600,
  routeTier: 'safety',
};

const BACKGROUND_MODEL_BASE = {
  provider: 'openai' as const,
  model: 'gpt-5-nano',
  routeTier: 'background' as const,
};

const BACKGROUND_TASK_CONFIG: Record<
  BackgroundTask,
  Pick<ModelSelection, 'maxOutputTokens' | 'temperature' | 'inputBudgetTokens'>
> = {
  domain_classification: { maxOutputTokens: 80, temperature: 0, inputBudgetTokens: 1300 },
  pattern_synthesis: { maxOutputTokens: 900, temperature: 0.2, inputBudgetTokens: 4200 },
  context_extraction: { maxOutputTokens: 900, temperature: 0.2, inputBudgetTokens: 3600 },
  push_generation: { maxOutputTokens: 180, temperature: 0.7, inputBudgetTokens: 1200 },
  summary: { maxOutputTokens: 300, temperature: 0.2, inputBudgetTokens: 2200 },
  labeling: { maxOutputTokens: 120, temperature: 0, inputBudgetTokens: 1000 },
  memory_compression: { maxOutputTokens: 450, temperature: 0.2, inputBudgetTokens: 2400 },
};

const ACUTE_RISK_TERMS = [
  'kill myself',
  'end my life',
  'suicide',
  'suicidal',
  'hurt myself',
  'self-harm',
  'self harm',
  'i want to die',
  'i dont want to live',
  'i do not want to live',
  'going to hurt someone',
];

const HIGH_STAKES_TERMS = [
  'panic attack',
  'abuse',
  'assault',
  'addiction',
  'relapse',
  'overwhelmed',
  'hopeless',
  'trauma',
  'grief',
  'divorce',
  'custody',
  'fired',
  'laid off',
  'bankrupt',
  'evicted',
  'can’t cope',
  "can't cope",
];

const DISTRESS_TERMS = [
  'stuck',
  'burned out',
  'burnt out',
  'numb',
  'anxious',
  'anxiety',
  'depressed',
  'exhausted',
  'ashamed',
  'alone',
  'i give up',
  'no way out',
];

const DEPTH_REQUEST_TERMS = [
  'be honest with me',
  'tell me the hard truth',
  'call me out',
  'push me',
  'don\'t sugarcoat',
  'dont sugarcoat',
  'be direct with me',
  'challenge me',
];

const CHARS_PER_TOKEN_APPROX = 4;

export function selectChatModel(input: ChatRoutingInput): ModelSelection {
  const message = (input.message || '').toLowerCase();
  const recentMessages = input.recentUserMessages.map((m) => m.toLowerCase());
  const triggers: string[] = [];
  let riskScore = 0;

  const acuteHits = countTermHits(message, ACUTE_RISK_TERMS);
  const highStakesHits = countTermHits(message, HIGH_STAKES_TERMS);
  const distressHits = countTermHits(message, DISTRESS_TERMS);
  const depthRequestHits = countTermHits(message, DEPTH_REQUEST_TERMS);
  const hasRecentDistress = recentMessages
    .slice(-2)
    .some((m) => countTermHits(m, DISTRESS_TERMS) > 0);
  const isEarlyConversation = input.sessionMode === 'coaching' && input.recentUserMessages.length <= 2;

  // Trigger rule 1: explicit crisis detector signal.
  if (input.crisisDetected) {
    triggers.push('crisis_detected');
    riskScore += 4;
  }

  // Trigger rule 2: crisis confidence gate, even when detector is uncertain.
  if (input.crisisConfidence >= 0.55) {
    triggers.push(`crisis_confidence_${input.crisisConfidence.toFixed(2)}`);
    riskScore += 2;
  }

  // Trigger rule 3: acute safety language.
  if (acuteHits > 0) {
    triggers.push(`acute_terms_${acuteHits}`);
    riskScore += 3;
  }

  // Trigger rule 4: high-stakes personal content.
  if (highStakesHits >= 2) {
    triggers.push(`high_stakes_terms_${highStakesHits}`);
    riskScore += 2;
  } else if (highStakesHits === 1) {
    triggers.push('high_stakes_term_single');
    riskScore += 1;
  }

  // Trigger rule 5: sustained distress pattern (current + recent turns).
  if (distressHits > 0 && hasRecentDistress) {
    triggers.push('distress_persistence');
    riskScore += 1;
  }

  // Trigger rule 6: unusually long high-load message.
  if (message.length >= 900) {
    triggers.push('long_message_900_plus');
    riskScore += 1;
  }

  // Trigger rule 7: users explicitly asking for high-accountability coaching depth.
  if (depthRequestHits > 0) {
    triggers.push(`depth_request_${depthRequestHits}`);
    riskScore += 1;
  }

  // Trigger rule 8: early conversation quality boost for dense emotional/complex turns.
  if (
    isEarlyConversation &&
    message.length >= 220 &&
    (highStakesHits > 0 || distressHits >= 2 || depthRequestHits > 0)
  ) {
    triggers.push('early_depth_turn');
    riskScore += 1;
  }

  const shouldEscalate = riskScore >= 2 || input.crisisDetected;
  if (shouldEscalate) {
    return {
      ...ESCALATION_CHAT_MODEL,
      routeReason: `escalated:${triggers.join('|') || 'risk_score'}`,
    };
  }

  // Discovery still uses primary model, but with tighter output budget.
  if (input.sessionMode === 'discovery') {
    return {
      ...DISCOVERY_CHAT_MODEL,
      routeReason: 'primary:discovery',
    };
  }

  return {
    ...PRIMARY_CHAT_MODEL,
    routeReason: 'primary:coaching_default',
  };
}

export function selectSafetyClassifierModel(): ModelSelection {
  return {
    ...SAFETY_CLASSIFIER_MODEL,
    routeReason: 'safety:crisis_classifier',
  };
}

export function selectBackgroundModel(task: BackgroundTask): ModelSelection {
  const taskConfig = BACKGROUND_TASK_CONFIG[task];
  return {
    ...BACKGROUND_MODEL_BASE,
    ...taskConfig,
    routeReason: `background:${task}`,
  };
}

/**
 * Trim oldest non-system messages so estimated input tokens fit budget.
 * Uses lightweight estimation (chars / 4) to avoid tokenizer dependency.
 */
export function enforceInputTokenBudget(
  messages: ChatMessage[],
  maxInputTokens: number,
): ChatMessage[] {
  if (messages.length <= 1) return messages;

  const systemMessages = messages.filter((m) => m.role === 'system');
  const nonSystem = messages.filter((m) => m.role !== 'system');

  const kept: ChatMessage[] = [];
  let usedTokens = systemMessages.reduce((sum, m) => sum + estimateTokens(m.content) + 8, 0);

  for (let i = nonSystem.length - 1; i >= 0; i--) {
    const message = nonSystem[i];
    const messageTokens = estimateTokens(message.content) + 8;

    if (usedTokens + messageTokens <= maxInputTokens) {
      kept.push(message);
      usedTokens += messageTokens;
      continue;
    }

    // Keep at least the newest turn by truncating it into remaining budget.
    if (kept.length === 0) {
      const remaining = Math.max(120, maxInputTokens - usedTokens - 8);
      kept.push({
        ...message,
        content: truncateToTokenBudget(message.content, remaining),
      });
      usedTokens = maxInputTokens;
    }
    break;
  }

  const selectedSystem = systemMessages.length > 0 ? [systemMessages[0]] : [];
  return [...selectedSystem, ...kept.reverse()];
}

function estimateTokens(text: string): number {
  if (!text) return 0;
  return Math.ceil(text.length / CHARS_PER_TOKEN_APPROX);
}

function truncateToTokenBudget(text: string, tokenBudget: number): string {
  const maxChars = Math.max(80, tokenBudget * CHARS_PER_TOKEN_APPROX);
  if (text.length <= maxChars) return text;
  return `${text.slice(0, Math.max(0, maxChars - 1)).trimEnd()}…`;
}

function countTermHits(text: string, terms: string[]): number {
  let hits = 0;
  for (const term of terms) {
    if (text.includes(term)) hits++;
  }
  return hits;
}
