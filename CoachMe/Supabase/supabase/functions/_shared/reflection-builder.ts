/**
 * reflection-builder.ts
 *
 * Story 8.5: Progress Tracking & Coaching Reflections
 *
 * Pure helper functions for building reflection prompts.
 * No side effects, no DB calls — all data passed in from chat-stream/index.ts.
 *
 * Exports:
 * - shouldOfferReflection() — eligibility check (AC: 2,6)
 * - buildSessionCheckIn() — previous session topic prompt (AC: 1)
 * - buildMonthlyReflection() — monthly reflection offer prompt (AC: 2,3)
 * - buildReflectionDeclineInstruction() — graceful pivot prompt (AC: 4)
 */

// MARK: - Types

/** Status of a user goal for reflection context */
export interface GoalStatus {
  content: string;
  domain?: string;
  status: 'active' | 'completed' | 'paused';
}

/** Context needed to build a monthly reflection */
export interface ReflectionContext {
  sessionCount: number;
  lastReflectionAt: string | null;
  patternSummary: string;
  goalStatus: GoalStatus[];
  domainUsage: Record<string, number>;
  recentThemes: string[];
  previousSessionTopic: string | null;
  /** Whether the caller determined a monthly reflection should be offered (via shouldOfferReflection) */
  offerMonthlyReflection: boolean;
}

// MARK: - Constants

/** Minimum sessions before offering a reflection (AC: 2) */
const MIN_SESSIONS_FOR_REFLECTION = 8;

/** Minimum days between reflections (AC: 6) */
const MIN_DAYS_BETWEEN_REFLECTIONS = 25;

// MARK: - Eligibility (Task 1.2, AC: 2,6)

/**
 * Determine if a monthly reflection should be offered.
 *
 * @param sessionCount - Total coaching sessions for this user
 * @param lastReflectionAt - ISO timestamp of last reflection, or null
 * @returns true if reflection is eligible
 *
 * Logic:
 * - Must have >= 8 sessions (AC: 2)
 * - Must be >= 25 days since last reflection (AC: 6)
 * - First reflection: always eligible after 8 sessions
 */
export function shouldOfferReflection(
  sessionCount: number,
  lastReflectionAt: string | null,
): boolean {
  if (sessionCount < MIN_SESSIONS_FOR_REFLECTION) return false;
  if (!lastReflectionAt) return true; // Never reflected before
  const daysSince =
    (Date.now() - new Date(lastReflectionAt).getTime()) / (1000 * 60 * 60 * 24);
  return daysSince >= MIN_DAYS_BETWEEN_REFLECTIONS;
}

// MARK: - Session Check-In (Task 1.3, AC: 1)

/**
 * Build a session check-in prompt section for the system prompt.
 * Instructs the LLM to naturally ask about a previous session's topic.
 *
 * @param previousConversationSummary - Summary of the user's last conversation
 * @param patternSummary - Pattern summary string for additional context
 * @returns Prompt section string for session check-in
 */
export function buildSessionCheckIn(
  previousConversationSummary: string,
  patternSummary: string,
): string {
  let section = `\n\n## SESSION CHECK-IN\n`;
  section += `The user previously discussed: "${previousConversationSummary}". `;
  section += `Consider naturally asking how things went, but only if it feels relevant to today's conversation opening.\n`;
  section += `Keep it brief and warm: "Last time we talked about X. How did it go?"\n`;
  section += `Do NOT force the check-in — if the user opens with a new topic, follow their lead.\n`;

  if (patternSummary) {
    section += `\nAdditional pattern context: ${patternSummary}\n`;
  }

  return section;
}

// MARK: - Monthly Reflection (Task 1.4, AC: 2,3)

/**
 * Build a monthly reflection offer prompt section.
 * Instructs the LLM to offer a warm, coaching-voice reflection.
 *
 * @param context - ReflectionContext with all needed data
 * @returns Prompt section string for monthly reflection
 */
export function buildMonthlyReflection(context: ReflectionContext): string {
  const weeksActive = Math.floor(context.sessionCount / 2); // Rough approximation

  let section = `\n\n## COACHING REFLECTION OPPORTUNITY\n`;
  section += `This user has had ${context.sessionCount} coaching sessions over approximately ${weeksActive} weeks.\n\n`;
  section += `Consider offering a brief, warm reflection:\n`;
  section += `"Before we dive in today — it's been about ${weeksActive} weeks since we started. `;
  section += `Can I share something I've noticed about your journey so far?"\n\n`;

  section += `If the user says yes, reflect on:\n`;

  // Top themes
  if (context.recentThemes.length > 0) {
    section += `- Top themes: ${context.recentThemes.join(', ')}\n`;
  }

  // Growth signals from pattern summary
  if (context.patternSummary) {
    section += `- Growth signals: ${context.patternSummary}\n`;
  }

  // Domain engagement
  const domainEntries = Object.entries(context.domainUsage);
  if (domainEntries.length > 0) {
    const domainList = domainEntries
      .sort(([, a], [, b]) => b - a)
      .map(([domain, count]) => `${domain} (${count} sessions)`)
      .join(', ');
    section += `- Domain engagement: ${domainList}\n`;
  }

  // Goal progress
  const activeGoals = context.goalStatus.filter((g) => g.status === 'active');
  const completedGoals = context.goalStatus.filter((g) => g.status === 'completed');
  if (activeGoals.length > 0 || completedGoals.length > 0) {
    section += `- Active goals: ${activeGoals.map((g) => g.content).join(', ') || 'none'}\n`;
    if (completedGoals.length > 0) {
      section += `- Completed goals: ${completedGoals.map((g) => g.content).join(', ')}\n`;
    }
  }

  section += `\nUse your warm coaching voice. This is a coaching moment, NOT an analytics report.\n`;
  section += `\nCRITICAL RULES:\n`;
  section += `- Keep reflection under 150 words\n`;
  section += `- Use "I've noticed..." and "I'm hearing..." framing\n`;
  section += `- Never reference "data", "metrics", or "tracking"\n`;
  section += `- Never use clinical or analytical language\n\n`;

  // Tag instruction for acceptance/decline detection
  section += `After delivering or offering the reflection, emit exactly one of these tags `;
  section += `(hidden from the user — will be stripped by the system):\n`;
  section += `- If the user engages with the reflection: [REFLECTION_ACCEPTED]\n`;
  section += `- If the user declines or redirects: [REFLECTION_DECLINED]\n`;

  return section;
}

// MARK: - Decline Instruction (Task 1.5, AC: 4)

/**
 * Build instruction for gracefully handling a user declining a reflection.
 *
 * @returns Prompt section string for graceful decline handling
 */
export function buildReflectionDeclineInstruction(): string {
  let section = `\n\n## REFLECTION DECLINE HANDLING\n`;
  section += `If the user declines the reflection or redirects the conversation `;
  section += `(e.g., "actually I need to talk about something", "not now", "let's talk about X"):\n`;
  section += `1. Pivot immediately and gracefully: "Of course — what's on your mind?"\n`;
  section += `2. Do NOT insist on the reflection or bring it up again this session\n`;
  section += `3. Do NOT show disappointment or make the user feel guilty\n`;
  section += `4. Emit the tag [REFLECTION_DECLINED] (will be stripped by the system)\n`;
  section += `5. Resume normal coaching flow immediately\n`;

  return section;
}

// MARK: - Exports for testing

export const REFLECTION_CONSTANTS = {
  MIN_SESSIONS_FOR_REFLECTION,
  MIN_DAYS_BETWEEN_REFLECTIONS,
};
