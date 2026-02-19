/**
 * style-adapter.ts
 *
 * Story 8.6: Coaching Style Adaptation
 *
 * Shared helper module for coaching style analysis and instruction generation.
 * Called FROM chat-stream/index.ts, NOT deployed as standalone endpoint.
 *
 * Follows the same pattern as:
 * - pattern-analyzer.ts (Story 8.4)
 * - pattern-synthesizer.ts (Story 3.5)
 * - context-loader.ts (existing)
 *
 * Key design: Style preferences are read on the critical path (<50ms),
 * but analysis runs as background fire-and-forget after streaming completes.
 */

import { SupabaseClient } from 'npm:@supabase/supabase-js@2.94.1';

// MARK: - Types

/** Style preference dimensions (0.0–1.0 scale) */
export interface StylePreference {
  directVsExploratory: number;     // 0.0 = exploratory, 1.0 = direct
  briefVsDetailed: number;         // 0.0 = detailed, 1.0 = brief
  actionVsReflective: number;      // 0.0 = reflective, 1.0 = action
  challengingVsSupportive: number;  // 0.0 = supportive, 1.0 = challenging
  playfulHumor?: boolean;          // Optional manual preference for light humor
  concreteExamples?: boolean;      // Optional manual preference for practical examples
}

/** Raw coaching_preferences JSONB shape from context_profiles */
interface CoachingPreferencesRow {
  coaching_preferences: Record<string, unknown> | null;
}

// MARK: - Constants

/** Minimum sessions before style preferences activate (AC-4) */
const MIN_SESSIONS_FOR_STYLE = 5;

/** Minimum sessions in a domain before domain-specific style applies */
const MIN_DOMAIN_SESSIONS = 3;

/** Threshold for a dimension to be considered a "strong preference" */
const STRONG_PREFERENCE_HIGH = 0.65;
const STRONG_PREFERENCE_LOW = 0.35;

/** Number of sessions between style re-analyses */
const ANALYSIS_REFRESH_INTERVAL = 5;

/** Maximum sessions to analyze for style scoring */
const MAX_SESSIONS_TO_ANALYZE = 10;

/** Manual style presets that users can explicitly choose in the app */
const MANUAL_STYLE_PRESETS: Record<string, StylePreference> = {
  balanced: {
    directVsExploratory: 0.5,
    briefVsDetailed: 0.5,
    actionVsReflective: 0.5,
    challengingVsSupportive: 0.5,
  },
  direct: {
    directVsExploratory: 0.85,
    briefVsDetailed: 0.65,
    actionVsReflective: 0.8,
    challengingVsSupportive: 0.6,
  },
  compassionate: {
    directVsExploratory: 0.4,
    briefVsDetailed: 0.45,
    actionVsReflective: 0.4,
    challengingVsSupportive: 0.15,
  },
  supportive: {
    directVsExploratory: 0.4,
    briefVsDetailed: 0.45,
    actionVsReflective: 0.4,
    challengingVsSupportive: 0.15,
  },
  challenging: {
    directVsExploratory: 0.72,
    briefVsDetailed: 0.55,
    actionVsReflective: 0.78,
    challengingVsSupportive: 0.88,
  },
  exploratory: {
    directVsExploratory: 0.2,
    briefVsDetailed: 0.35,
    actionVsReflective: 0.32,
    challengingVsSupportive: 0.3,
  },
  playful: {
    directVsExploratory: 0.58,
    briefVsDetailed: 0.58,
    actionVsReflective: 0.62,
    challengingVsSupportive: 0.22,
    playfulHumor: true,
    concreteExamples: true,
  },
  humorous: {
    directVsExploratory: 0.58,
    briefVsDetailed: 0.58,
    actionVsReflective: 0.62,
    challengingVsSupportive: 0.22,
    playfulHumor: true,
    concreteExamples: true,
  },
  human: {
    directVsExploratory: 0.55,
    briefVsDetailed: 0.52,
    actionVsReflective: 0.58,
    challengingVsSupportive: 0.25,
    playfulHumor: true,
    concreteExamples: true,
  },
};

// MARK: - Get Style Preferences (Task 1.3)

/**
 * Get style preferences for a user, optionally domain-specific.
 * Loads coaching_preferences from DB then delegates to resolveStylePreferences.
 * Returns null when insufficient data (< 5 sessions) or no preferences exist.
 *
 * @param userId - User ID
 * @param supabase - Authenticated Supabase client
 * @param domain - Optional domain for domain-specific style
 * @returns StylePreference or null (null = use balanced default, AC-4)
 *
 * Performance: <50ms (single DB read)
 */
export async function getStylePreferences(
  userId: string,
  supabase: SupabaseClient,
  domain?: string,
): Promise<StylePreference | null> {
  const { data, error } = await supabase
    .from('context_profiles')
    .select('coaching_preferences')
    .eq('user_id', userId)
    .single();

  if (error || !data) {
    return null;
  }

  const prefs = (data as CoachingPreferencesRow).coaching_preferences;
  return resolveStylePreferences(prefs, domain);
}

/**
 * Resolve style preferences from pre-loaded coaching_preferences data.
 * Use when coaching_preferences is already loaded to avoid extra DB queries.
 *
 * Resolution order:
 * 1. Manual override preset (manual_override or manual_overrides.style) → preset style (always wins)
 * 2. Null/insufficient sessions → null (AC-4: balanced default)
 * 3. Domain-specific style → if domain provided and domain_styles[domain] exists
 * 4. Global style_dimensions → fallback
 *
 * @param coachingPreferences - Raw coaching_preferences JSONB, or null
 * @param domain - Optional domain for domain-specific style
 * @returns StylePreference or null (null = use balanced default)
 */
export function resolveStylePreferences(
  coachingPreferences: Record<string, unknown> | null,
  domain?: string,
): StylePreference | null {
  if (!coachingPreferences) {
    return null;
  }

  // Manual override always wins and bypasses minimum-session gating.
  const manualOverride = getManualOverrideValue(coachingPreferences);
  if (manualOverride) {
    const preset = parseManualOverrideStyle(manualOverride);
    if (preset) {
      return preset;
    }
  }

  // AC-4: Return null for users with fewer than 5 sessions
  const sessionCount = (coachingPreferences.session_count as number) ?? 0;
  if (sessionCount < MIN_SESSIONS_FOR_STYLE) {
    return null;
  }

  // Domain-specific style if domain provided and domain_styles[domain] exists
  if (domain) {
    const domainStyles = coachingPreferences.domain_styles as Record<string, Record<string, unknown>> | undefined;
    if (domainStyles && domainStyles[domain]) {
      return parseStyleDimensions(domainStyles[domain]);
    }
  }

  // Global style dimensions
  const styleDimensions = coachingPreferences.style_dimensions as Record<string, unknown> | undefined;
  if (styleDimensions) {
    return parseStyleDimensions(styleDimensions);
  }

  return null;
}

/**
 * Parse raw style dimensions object into StylePreference.
 * Clamps values to 0.0–1.0 range.
 */
function parseStyleDimensions(raw: Record<string, unknown>): StylePreference {
  return {
    directVsExploratory: clamp(typeof raw.direct_vs_exploratory === 'number' ? raw.direct_vs_exploratory : 0.5),
    briefVsDetailed: clamp(typeof raw.brief_vs_detailed === 'number' ? raw.brief_vs_detailed : 0.5),
    actionVsReflective: clamp(typeof raw.action_vs_reflective === 'number' ? raw.action_vs_reflective : 0.5),
    challengingVsSupportive: clamp(typeof raw.challenging_vs_supportive === 'number' ? raw.challenging_vs_supportive : 0.5),
    playfulHumor: raw.playful_humor === true,
    concreteExamples: raw.concrete_examples === true,
  };
}

/**
 * Extract manual style override string from either legacy/manual field.
 */
function getManualOverrideValue(
  coachingPreferences: Record<string, unknown>,
): string | null {
  if (typeof coachingPreferences.manual_override === 'string') {
    return coachingPreferences.manual_override;
  }

  const manualOverrides = coachingPreferences.manual_overrides as Record<string, unknown> | undefined;
  if (manualOverrides && typeof manualOverrides.style === 'string') {
    return manualOverrides.style;
  }

  return null;
}

/**
 * Convert manual style label into preset dimensions.
 */
function parseManualOverrideStyle(style: string): StylePreference | null {
  const normalized = style.trim().toLowerCase();
  return MANUAL_STYLE_PRESETS[normalized] ?? null;
}

function clamp(value: number): number {
  return Math.max(0, Math.min(1, value));
}

// MARK: - Format Style Instructions (Task 1.4)

/**
 * Convert style preferences to natural language coaching instructions.
 * Returns empty string when prefs is null (no injection, AC-4).
 *
 * Only describes dimensions with strong preferences (>0.65 or <0.35).
 * Near-0.5 values are omitted (balanced, no special instruction needed).
 *
 * @param prefs - Style preferences or null
 * @returns Coaching instruction string, or "" if null/balanced
 *
 * Performance: <1ms (string generation, no I/O)
 */
export function formatStyleInstructions(prefs: StylePreference | null): string {
  if (!prefs) return '';

  const instructions: string[] = [];

  // Direct vs Exploratory
  if (prefs.directVsExploratory > STRONG_PREFERENCE_HIGH) {
    instructions.push('Lead with concrete next steps rather than open-ended exploration.');
  } else if (prefs.directVsExploratory < STRONG_PREFERENCE_LOW) {
    instructions.push('Use open-ended questions to help them discover their own insights.');
  }

  // Brief vs Detailed
  if (prefs.briefVsDetailed > STRONG_PREFERENCE_HIGH) {
    instructions.push('Keep responses concise and focused.');
  } else if (prefs.briefVsDetailed < STRONG_PREFERENCE_LOW) {
    instructions.push('Provide detailed explanations and thorough exploration of topics.');
  }

  // Action vs Reflective
  if (prefs.actionVsReflective > STRONG_PREFERENCE_HIGH) {
    instructions.push('Keep recommendations specific and actionable.');
  } else if (prefs.actionVsReflective < STRONG_PREFERENCE_LOW) {
    instructions.push('Prioritize reflection and self-discovery over action items.');
  }

  // Challenging vs Supportive
  if (prefs.challengingVsSupportive > STRONG_PREFERENCE_HIGH) {
    instructions.push('Challenge assumptions and push for deeper thinking.');
  } else if (prefs.challengingVsSupportive < STRONG_PREFERENCE_LOW) {
    instructions.push('Prioritize empathy and validation before suggesting actions.');
  }

  if (prefs.playfulHumor) {
    instructions.push('Use light, kind humor occasionally when it fits naturally. Never use sarcasm or humor about pain.');
    instructions.push('Avoid therapy-style opener loops like repeatedly starting with "I hear you." Vary openings naturally.');
  }

  if (prefs.concreteExamples) {
    instructions.push('Use brief, relatable examples to make the coaching feel practical and human.');
  }

  if (instructions.length === 0) return '';

  // Build the style label from dominant dimensions
  const styleLabel = buildStyleLabel(prefs);

  return `This user prefers ${styleLabel} coaching.\n${instructions.join('\n')}`;
}

/**
 * Build a human-readable style label from preferences.
 * Only includes dimensions with strong preferences.
 */
function buildStyleLabel(prefs: StylePreference): string {
  const labels: string[] = [];

  if (prefs.directVsExploratory > STRONG_PREFERENCE_HIGH) {
    labels.push('direct');
  } else if (prefs.directVsExploratory < STRONG_PREFERENCE_LOW) {
    labels.push('exploratory');
  }

  if (prefs.actionVsReflective > STRONG_PREFERENCE_HIGH) {
    labels.push('action-oriented');
  } else if (prefs.actionVsReflective < STRONG_PREFERENCE_LOW) {
    labels.push('reflective');
  }

  if (prefs.challengingVsSupportive > STRONG_PREFERENCE_HIGH) {
    labels.push('challenging');
  } else if (prefs.challengingVsSupportive < STRONG_PREFERENCE_LOW) {
    labels.push('supportive');
  }

  if (prefs.briefVsDetailed > STRONG_PREFERENCE_HIGH) {
    labels.push('concise');
  } else if (prefs.briefVsDetailed < STRONG_PREFERENCE_LOW) {
    labels.push('detailed');
  }

  if (prefs.playfulHumor) {
    labels.push('playful');
  }

  return labels.length > 0 ? labels.join(', ') : 'balanced';
}

// MARK: - Should Refresh Style Analysis (Task 1.6)

/**
 * Determine whether style analysis should be re-run.
 * Returns true if never analyzed or session count has grown by 5+.
 *
 * @param coachingPreferences - Raw coaching_preferences JSONB, or null
 * @returns true if analysis should be triggered
 */
export function shouldRefreshStyleAnalysis(
  coachingPreferences: Record<string, unknown> | null,
): boolean {
  if (!coachingPreferences) return true;

  const lastAnalysisAt = coachingPreferences.last_style_analysis_at as string | null;
  if (!lastAnalysisAt) return true;

  const sessionCount = (coachingPreferences.session_count as number) ?? 0;
  const sessionCountAtLastAnalysis = (coachingPreferences.session_count_at_style_analysis as number) ?? 0;

  return (sessionCount - sessionCountAtLastAnalysis) >= ANALYSIS_REFRESH_INTERVAL;
}

// MARK: - Analyze Style Preferences (Task 1.5)

/**
 * Analyze user's engagement patterns and compute style preferences.
 * Queries learning_signals for session_completed records.
 * Writes results to coaching_preferences JSONB (merge, not overwrite).
 *
 * @param userId - User ID
 * @param supabase - Authenticated Supabase client
 *
 * Performance: <2s (background, non-blocking)
 */
export async function analyzeStylePreferences(
  userId: string,
  supabase: SupabaseClient,
): Promise<void> {
  // Query session_completed learning signals (last 10 sessions max)
  const { data: signals, error: signalsError } = await supabase
    .from('learning_signals')
    .select('signal_data')
    .eq('user_id', userId)
    .eq('signal_type', 'session_completed')
    .order('created_at', { ascending: false })
    .limit(MAX_SESSIONS_TO_ANALYZE);

  if (signalsError || !signals?.length) {
    return;
  }

  // Extract engagement metrics from signal_data
  const sessions = signals.map((s: { signal_data: Record<string, unknown> }) => ({
    messageCount: (s.signal_data.message_count as number) ?? 0,
    avgMessageLength: (s.signal_data.avg_message_length as number) ?? 0,
    durationSeconds: (s.signal_data.duration_seconds as number) ?? 0,
    domain: (s.signal_data.domain as string) ?? 'general',
  }));

  // Compute global style dimensions
  const globalStyle = computeStyleScores(sessions);

  // Compute per-domain styles (only domains with 3+ sessions)
  const domainStyles: Record<string, StylePreference> = {};
  const domainGroups = groupByDomain(sessions);
  for (const [domain, domainSessions] of Object.entries(domainGroups)) {
    if (domainSessions.length >= MIN_DOMAIN_SESSIONS) {
      domainStyles[domain] = computeStyleScores(domainSessions);
    }
  }

  // Derive preferred_style label from dominant dimensions
  const preferredStyle = buildStyleLabel(globalStyle);

  // Load current coaching_preferences to merge (not overwrite)
  const { data: profileData, error: profileError } = await supabase
    .from('context_profiles')
    .select('coaching_preferences')
    .eq('user_id', userId)
    .single();

  if (profileError || !profileData) {
    console.error(`analyzeStylePreferences: Failed to fetch profile for user ${userId}:`, profileError);
    return;
  }

  const existingPrefs = ((profileData as CoachingPreferencesRow).coaching_preferences ?? {}) as Record<string, unknown>;
  const currentSessionCount = (existingPrefs.session_count as number) ?? 0;

  // JSONB merge: preserve existing fields, update style-related ones
  const updatedPrefs: Record<string, unknown> = {
    ...existingPrefs,
    style_dimensions: {
      direct_vs_exploratory: globalStyle.directVsExploratory,
      brief_vs_detailed: globalStyle.briefVsDetailed,
      action_vs_reflective: globalStyle.actionVsReflective,
      challenging_vs_supportive: globalStyle.challengingVsSupportive,
    },
    domain_styles: Object.fromEntries(
      Object.entries(domainStyles).map(([domain, style]) => [
        domain,
        {
          direct_vs_exploratory: style.directVsExploratory,
          brief_vs_detailed: style.briefVsDetailed,
          action_vs_reflective: style.actionVsReflective,
          challenging_vs_supportive: style.challengingVsSupportive,
        },
      ]),
    ),
    preferred_style: preferredStyle,
    last_style_analysis_at: new Date().toISOString(),
    session_count_at_style_analysis: currentSessionCount,
  };

  const { error: updateError } = await supabase
    .from('context_profiles')
    .update({ coaching_preferences: updatedPrefs })
    .eq('user_id', userId);

  if (updateError) {
    console.error('Failed to update style preferences:', updateError);
  }
}

// MARK: - Style Scoring Algorithms (Task 1.7)

interface SessionMetrics {
  messageCount: number;
  avgMessageLength: number;
  durationSeconds: number;
  domain: string;
}

/**
 * Compute style dimension scores from session engagement metrics.
 * Each dimension is 0.0–1.0 with 0.5 as balanced default.
 *
 * Note: Current algorithms use proxy metrics based on available signal_data
 * (message_count, avg_message_length, duration_seconds). Richer algorithms
 * (action verb analysis, per-message follow-up tracking) require enhanced
 * signal_data from LearningSignalService. See Story 8.6 Task 1.7 for
 * ideal algorithms; this is a pragmatic first pass.
 */
function computeStyleScores(sessions: SessionMetrics[]): StylePreference {
  if (sessions.length === 0) {
    return { directVsExploratory: 0.5, briefVsDetailed: 0.5, actionVsReflective: 0.5, challengingVsSupportive: 0.5 };
  }

  // briefVsDetailed: Normalized average message length
  // Shorter average messages → higher brief score
  const avgMsgLens = sessions.map((s) => s.avgMessageLength).filter((l) => l > 0);
  let briefScore = 0.5;
  if (avgMsgLens.length > 0) {
    const meanLen = avgMsgLens.reduce((a, b) => a + b, 0) / avgMsgLens.length;
    // Normalize: ≤50 chars → 1.0 (brief), 150 chars → 0.5 (balanced), ≥250 chars → 0.0 (detailed)
    briefScore = clamp(1 - (meanLen - 50) / 200);
  }

  // directVsExploratory: Higher message count + shorter duration → more direct
  const avgMsgCount = sessions.reduce((a, s) => a + s.messageCount, 0) / sessions.length;
  const avgDuration = sessions.reduce((a, s) => a + s.durationSeconds, 0) / sessions.length;
  let directScore = 0.5;
  if (avgDuration > 0) {
    // Messages per minute — higher rate suggests directness
    const messagesPerMinute = avgMsgCount / (avgDuration / 60);
    // Normalize: >2 msg/min → direct (0.7+), <0.5 msg/min → exploratory (0.3-)
    directScore = clamp(0.3 + (messagesPerMinute - 0.5) * 0.25);
  }

  // actionVsReflective: Correlated with message count and brevity
  // Users who send many short messages tend toward action-oriented
  const actionScore = clamp(0.3 + (avgMsgCount / 20) * 0.4);

  // challengingVsSupportive: Derived from session duration
  // Longer sessions suggest openness to deeper exploration/challenge
  const durationMinutes = avgDuration / 60;
  const challengeScore = clamp(0.3 + (durationMinutes / 30) * 0.4);

  return {
    directVsExploratory: roundTo(directScore, 2),
    briefVsDetailed: roundTo(briefScore, 2),
    actionVsReflective: roundTo(actionScore, 2),
    challengingVsSupportive: roundTo(challengeScore, 2),
  };
}

function roundTo(value: number, decimals: number): number {
  const factor = Math.pow(10, decimals);
  return Math.round(value * factor) / factor;
}

function groupByDomain(sessions: SessionMetrics[]): Record<string, SessionMetrics[]> {
  const groups: Record<string, SessionMetrics[]> = {};
  for (const session of sessions) {
    const domain = session.domain || 'general';
    if (!groups[domain]) groups[domain] = [];
    groups[domain].push(session);
  }
  return groups;
}

// MARK: - Exports for Testing

export {
  computeStyleScores,
  buildStyleLabel,
  parseStyleDimensions,
  STRONG_PREFERENCE_HIGH,
  STRONG_PREFERENCE_LOW,
  MIN_SESSIONS_FOR_STYLE,
  MIN_DOMAIN_SESSIONS,
  ANALYSIS_REFRESH_INTERVAL,
};
