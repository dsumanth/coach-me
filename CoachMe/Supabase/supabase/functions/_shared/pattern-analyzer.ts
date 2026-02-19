/**
 * pattern-analyzer.ts
 *
 * Story 8.4: In-Conversation Pattern Recognition Engine
 *
 * Queries learning signals + pattern_syntheses to generate enriched pattern
 * summaries for system prompt injection. Uses session-count-based caching
 * (refresh when 3+ new conversations since last analysis).
 *
 * Key design: NOT on the critical chat path — runs in parallel via Promise.all().
 * Graceful degradation: always returns [] on error, never blocks coaching.
 */

import { SupabaseClient } from 'npm:@supabase/supabase-js@2.94.1';

// MARK: - Types

/** A pattern summary ready for system prompt injection */
export interface PatternSummary {
  theme: string;
  occurrenceCount: number;
  domains: string[];
  confidence: number;
  synthesis: string;
  lastSeenAt: string;
}

/** Raw pattern_syntheses row */
interface PatternSynthesisRow {
  theme: string;
  domains: string[];
  confidence: number;
  evidence: Array<{ domain: string; summary: string }>;
  synthesis: string;
  surface_count: number;
  last_surfaced_at: string | null;
  updated_at: string;
}

/** Cached pattern summary row from pattern_cache */
interface PatternCacheRow {
  summaries: PatternSummary[];
  session_count_at_analysis: number;
}

// MARK: - Constants

/** Minimum sessions required before pattern summaries are included (AC #1) */
const MIN_SESSIONS_FOR_PATTERNS = 5;

/** Number of new conversations before cache is refreshed (Task 1.3) */
const CACHE_REFRESH_THRESHOLD = 3;

/** Minimum occurrences for high-confidence patterns (AC #4) */
const MIN_OCCURRENCE_COUNT = 3;

/** Minimum confidence threshold for pattern inclusion (Task 1.5) */
const CONFIDENCE_THRESHOLD = 0.85;

/** Maximum patterns to include in prompt (Task 1.6) */
const MAX_PATTERNS_IN_PROMPT = 3;

// MARK: - Main Entry Point (Task 1.2)

/**
 * Generate pattern summaries for system prompt injection.
 * Cache-first with session-count-based TTL.
 *
 * @param userId - User to analyze
 * @param supabase - Authenticated Supabase client
 * @returns PatternSummary[] — empty array if insufficient data or on error
 *
 * Performance: <3s total (runs async in parallel, cached).
 * Cache lookup: <50ms. Session count check: <50ms.
 */
export async function generatePatternSummary(
  userId: string,
  supabase: SupabaseClient,
): Promise<PatternSummary[]> {
  try {
    // Task 1.3: Get current session count
    const sessionCount = await getSessionCount(userId, supabase);

    // AC #1: Need 5+ sessions before including patterns
    if (sessionCount < MIN_SESSIONS_FOR_PATTERNS) {
      return [];
    }

    // Task 1.3: Check cache — refresh only when 3+ new conversations
    const cached = await getCachedSummaries(userId, supabase);
    if (cached && (sessionCount - cached.session_count_at_analysis) < CACHE_REFRESH_THRESHOLD) {
      return cached.summaries;
    }

    // Build fresh summaries from pattern_syntheses + learning_signals
    const aggregated = await aggregatePatternData(userId, supabase);

    // Task 1.4: Rank by frequency and recency
    const ranked = rankPatterns(aggregated);

    // Task 1.5: Filter to high-confidence patterns (3+ occurrences, >= 0.85)
    const filtered = ranked.filter(
      (p) => p.occurrenceCount >= MIN_OCCURRENCE_COUNT && p.confidence >= CONFIDENCE_THRESHOLD,
    );

    // Task 1.6: Take top patterns and generate coaching-ready summaries
    const summaries = filtered.slice(0, MAX_PATTERNS_IN_PROMPT).map((p) => ({
      theme: p.theme,
      occurrenceCount: p.occurrenceCount,
      domains: p.domains,
      confidence: p.confidence,
      synthesis: p.synthesis,
      lastSeenAt: p.lastSeenAt,
    }));

    // Cache for future requests
    await cacheSummaries(userId, summaries, sessionCount, supabase);

    return summaries;
  } catch (error) {
    // Graceful degradation: pattern analysis MUST never block coaching
    console.error('Pattern analysis failed:', error);
    return [];
  }
}

// MARK: - Session Count (Task 1.3)

/**
 * Get total conversation count for a user via RPC.
 * Falls back to direct query if RPC is unavailable.
 */
async function getSessionCount(
  userId: string,
  supabase: SupabaseClient,
): Promise<number> {
  // Try RPC first (faster, indexed)
  const { data: rpcResult, error: rpcError } = await supabase.rpc('get_session_count', {
    p_user_id: userId,
  });

  if (!rpcError && typeof rpcResult === 'number') {
    return rpcResult;
  }

  // RPC failed — log for debugging before falling back
  if (rpcError) {
    console.warn(`getSessionCount: RPC fallback for user ${userId}:`, rpcError);
  }

  // Fallback: direct count query
  const { count, error } = await supabase
    .from('conversations')
    .select('id', { count: 'exact', head: true })
    .eq('user_id', userId);

  if (error) {
    console.error('Failed to get session count:', error);
    return 0;
  }

  if (count == null) {
    console.warn(`getSessionCount: count is null for user ${userId} — returning 0`);
  }

  return count ?? 0;
}

// MARK: - Cache Management (Task 1.3)

/**
 * Get cached pattern summaries from pattern_cache table.
 * Returns null if no cache exists.
 */
async function getCachedSummaries(
  userId: string,
  supabase: SupabaseClient,
): Promise<PatternCacheRow | null> {
  const { data, error } = await supabase
    .from('pattern_cache')
    .select('summaries, session_count_at_analysis')
    .eq('user_id', userId)
    .single();

  if (error || !data) {
    return null;
  }

  return data as PatternCacheRow;
}

/**
 * Store pattern summaries in pattern_cache.
 * Upserts to handle both create and update cases.
 */
async function cacheSummaries(
  userId: string,
  summaries: PatternSummary[],
  sessionCount: number,
  supabase: SupabaseClient,
): Promise<void> {
  const { error } = await supabase
    .from('pattern_cache')
    .upsert(
      {
        user_id: userId,
        summaries,
        session_count_at_analysis: sessionCount,
      },
      { onConflict: 'user_id' },
    );

  if (error) {
    console.error('Failed to cache pattern summaries:', error);
  }
}

// MARK: - Pattern Aggregation (Task 1.1)

/** Intermediate type for aggregation before ranking */
interface AggregatedPattern {
  theme: string;
  occurrenceCount: number;
  domains: string[];
  confidence: number;
  synthesis: string;
  lastSeenAt: string;
  engagementCount: number;
}

/**
 * Aggregate pattern data from pattern_syntheses and learning_signals.
 * Computes occurrence counts from conversation frequency per domain.
 */
async function aggregatePatternData(
  userId: string,
  supabase: SupabaseClient,
): Promise<AggregatedPattern[]> {
  // Query pattern_syntheses for existing cross-domain patterns
  const { data: syntheses, error: synthError } = await supabase
    .from('pattern_syntheses')
    .select('theme, domains, confidence, evidence, synthesis, surface_count, last_surfaced_at, updated_at')
    .eq('user_id', userId)
    .order('confidence', { ascending: false });

  if (synthError || !syntheses?.length) {
    return [];
  }

  // Get learning signals for pattern engagement enrichment (M2: isolated failure)
  let signals: Array<{ signal_type: string; signal_data: Record<string, unknown> }> = [];
  try {
    const { data } = await supabase
      .from('learning_signals')
      .select('signal_type, signal_data')
      .eq('user_id', userId)
      .eq('signal_type', 'pattern_engaged')
      .limit(200);
    signals = (data ?? []) as typeof signals;
  } catch {
    // learning_signals table may not exist yet (Story 8.1 dependency)
    // Degrade gracefully — pattern summaries still work without engagement data
  }

  // Build aggregated patterns
  return (syntheses as PatternSynthesisRow[]).map((s) => {
    // H3 FIX: Use evidence array length + surface_count as actual pattern occurrence count
    // (not total domain conversations, which inflates counts)
    const occurrenceCount = Math.max(s.evidence.length, s.surface_count ?? 0);

    // Engagement signals for this theme
    const engagementCount = signals.filter(
      (sig) => sig.signal_data?.pattern_theme === s.theme,
    ).length;

    return {
      theme: s.theme,
      occurrenceCount,
      domains: s.domains,
      confidence: s.confidence,
      synthesis: s.synthesis,
      lastSeenAt: s.updated_at,
      engagementCount,
    };
  });
}

// MARK: - Ranking (Task 1.4)

/**
 * Rank patterns by frequency (occurrence count) and recency (last seen).
 * Patterns with more occurrences rank higher; ties broken by recency.
 * Engagement count provides a bonus to the ranking.
 */
function rankPatterns(patterns: AggregatedPattern[]): AggregatedPattern[] {
  return [...patterns].sort((a, b) => {
    // Primary: occurrence count (higher is better)
    const occDiff = b.occurrenceCount - a.occurrenceCount;
    if (occDiff !== 0) return occDiff;

    // Secondary: engagement count (higher is better)
    const engDiff = b.engagementCount - a.engagementCount;
    if (engDiff !== 0) return engDiff;

    // Tertiary: recency (newer is better)
    return new Date(b.lastSeenAt).getTime() - new Date(a.lastSeenAt).getTime();
  });
}

// Export for testing
export { rankPatterns };
export type { AggregatedPattern };
export const PATTERN_ANALYZER_CONSTANTS = {
  MIN_SESSIONS_FOR_PATTERNS,
  CACHE_REFRESH_THRESHOLD,
  MIN_OCCURRENCE_COUNT,
  CONFIDENCE_THRESHOLD,
  MAX_PATTERNS_IN_PROMPT,
};
