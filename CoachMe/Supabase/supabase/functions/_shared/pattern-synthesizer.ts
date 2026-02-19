/**
 * pattern-synthesizer.ts
 *
 * Story 3.5: Cross-Domain Pattern Synthesis
 *
 * Detects patterns that span multiple coaching domains for the same user.
 * Uses a low-cost background model for cost-efficient analysis.
 * Results are cached in pattern_syntheses table (24h TTL).
 *
 * Key design: NOT on the critical chat path — can run async.
 * Cache-first strategy: check DB cache, only call LLM if cache expired.
 */

import { SupabaseClient } from 'npm:@supabase/supabase-js@2.94.1';
import { streamChatCompletion, type ChatMessage } from './llm-client.ts';
import { selectBackgroundModel, enforceInputTokenBudget } from './model-routing.ts';

// MARK: - Types

/** A cross-domain pattern detected across coaching conversations */
export interface CrossDomainPattern {
  theme: string;
  domains: string[];
  confidence: number;
  evidence: PatternEvidence[];
  synthesis: string;
}

/** Evidence supporting a cross-domain pattern */
interface PatternEvidence {
  domain: string;
  summary: string;
}

/** Result of cross-domain pattern detection */
export interface PatternSynthesisResult {
  patterns: CrossDomainPattern[];
  fromCache: boolean;
}

/** Row from pattern_syntheses table */
interface PatternSynthesisRow {
  id: string;
  user_id: string;
  theme: string;
  domains: string[];
  confidence: number;
  evidence: PatternEvidence[];
  synthesis: string;
  surface_count: number;
  last_surfaced_at: string | null;
  created_at: string;
  updated_at: string;
}

/** Conversation grouped by domain for analysis */
interface DomainConversationGroup {
  domain: string;
  summaries: string[];
}

// MARK: - Constants

/** Cache TTL: 24 hours in milliseconds */
const CACHE_TTL_MS = 24 * 60 * 60 * 1000;

/** Minimum domains required for cross-domain pattern */
const MIN_DOMAINS = 2;

/** Minimum messages per domain to consider for analysis */
const MIN_MESSAGES_PER_DOMAIN = 3;

/** Maximum conversations per domain to limit token usage (Task 2.5) */
const MAX_CONVERSATIONS_PER_DOMAIN = 10;

/** Minimum confidence threshold for surfacing patterns (AC #3) */
const CONFIDENCE_THRESHOLD = 0.85;

/** Maximum cross-domain syntheses per conversation (AC #4) */
export const MAX_SYNTHESES_PER_SESSION = 1;

/** Minimum sessions between same-theme synthesis (AC #4) */
export const MIN_SESSIONS_BETWEEN_SYNTHESIS = 3;

// MARK: - Synthesis System Prompt (Task 2.1-2.3)

const SYNTHESIS_SYSTEM_PROMPT = `You are a pattern analysis assistant for a coaching application.
Analyze conversations from DIFFERENT coaching domains for the SAME user.

Your task: Identify themes, behaviors, or emotional patterns that appear
across multiple domains. These cross-domain patterns are the most valuable
insights for coaching because they reveal core patterns the user may not see.

Rules:
- Only identify patterns that genuinely span 2+ different domains
- Require strong evidence (specific quotes or themes from each domain)
- Confidence must be >= 0.85 — do NOT surface weak connections
- Focus on behavioral patterns, emotional themes, and recurring dynamics
- Frame insights with curiosity, not diagnosis

Response format (respond with ONLY valid JSON, no other text):
{
  "patterns": [
    {
      "theme": "Brief description of the cross-domain pattern",
      "domains": ["domain1", "domain2"],
      "confidence": 0.92,
      "evidence": [
        {"domain": "domain1", "summary": "In domain1 conversations, user frequently mentions..."},
        {"domain": "domain2", "summary": "In domain2 discussions, similar theme of..."}
      ],
      "synthesis": "A coaching-ready synthesis statement connecting the dots"
    }
  ]
}

If no genuine cross-domain patterns exist, respond with: {"patterns": []}`;

// MARK: - Main Detection Function (Task 1.2)

/**
 * Detect cross-domain patterns for a user.
 * Cache-first: returns cached patterns if within 24h TTL.
 * Otherwise runs LLM analysis and caches results.
 *
 * @param userId - User to analyze
 * @param supabase - Authenticated Supabase client
 * @returns PatternSynthesisResult with patterns and cache status
 *
 * Performance: Not on critical chat path. Cache lookup <50ms, full analysis ~2-5s.
 */
export async function detectCrossDomainPatterns(
  userId: string,
  supabase: SupabaseClient,
): Promise<PatternSynthesisResult> {
  try {
    // Task 1.7: Check cache first (24h TTL)
    const cached = await getCachedPatterns(userId, supabase);
    if (cached) {
      return { patterns: cached, fromCache: true };
    }

    // Task 1.3: Query conversations grouped by domain
    const domainGroups = await getConversationsByDomain(userId, supabase);

    // Need at least 2 domains with sufficient messages
    if (domainGroups.length < MIN_DOMAINS) {
      return { patterns: [], fromCache: false };
    }

    // Task 1.4: Use LLM to analyze cross-domain themes
    const patterns = await analyzePatterns(domainGroups);

    // Task 1.6: Filter by confidence threshold
    const highConfidencePatterns = patterns.filter(
      (p) => p.confidence >= CONFIDENCE_THRESHOLD && p.domains.length >= MIN_DOMAINS,
    );

    // Cache results in DB for future requests
    await cachePatterns(userId, highConfidencePatterns, supabase);

    return { patterns: highConfidencePatterns, fromCache: false };
  } catch (error) {
    // Graceful degradation: pattern detection should never block chat
    console.error('Cross-domain pattern detection failed:', error);
    return { patterns: [], fromCache: false };
  }
}

// MARK: - Cache Management (Task 1.7)

/**
 * Get cached patterns from pattern_syntheses table.
 * Returns null if cache is expired (>24h) or empty.
 */
async function getCachedPatterns(
  userId: string,
  supabase: SupabaseClient,
): Promise<CrossDomainPattern[] | null> {
  const { data, error } = await supabase
    .from('pattern_syntheses')
    .select('*')
    .eq('user_id', userId)
    .order('created_at', { ascending: false });

  if (error || !data?.length) {
    return null;
  }

  // Check if most recent entry is within TTL
  const rows = data as PatternSynthesisRow[];
  const mostRecent = rows[0];
  const age = Date.now() - new Date(mostRecent.updated_at).getTime();

  if (age > CACHE_TTL_MS) {
    return null; // Cache expired
  }

  // Convert cached rows to CrossDomainPattern[]
  return rows.map((row) => ({
    theme: row.theme,
    domains: row.domains,
    confidence: row.confidence,
    evidence: row.evidence,
    synthesis: row.synthesis,
  }));
}

/**
 * Store detected patterns in pattern_syntheses table for caching.
 * Replaces all existing patterns for this user (full refresh on analysis).
 */
async function cachePatterns(
  userId: string,
  patterns: CrossDomainPattern[],
  supabase: SupabaseClient,
): Promise<void> {
  // Delete existing patterns for this user (fresh cache)
  await supabase.from('pattern_syntheses').delete().eq('user_id', userId);

  if (patterns.length === 0) return;

  // Insert new patterns
  const rows = patterns.map((p) => ({
    user_id: userId,
    theme: p.theme,
    domains: p.domains,
    confidence: p.confidence,
    evidence: p.evidence,
    synthesis: p.synthesis,
    surface_count: 0,
    last_surfaced_at: null,
  }));

  const { error } = await supabase.from('pattern_syntheses').insert(rows);

  if (error) {
    console.error('Failed to cache patterns:', error);
  }
}

// MARK: - Conversation Querying (Task 1.3)

/**
 * Query conversations grouped by domain.
 * Only includes domains with minimum message threshold.
 * Limits to MAX_CONVERSATIONS_PER_DOMAIN per domain (Task 2.5).
 */
async function getConversationsByDomain(
  userId: string,
  supabase: SupabaseClient,
): Promise<DomainConversationGroup[]> {
  // Get conversations with a domain assigned, grouped by domain
  const { data: conversations, error } = await supabase
    .from('conversations')
    .select('id, domain, title')
    .eq('user_id', userId)
    .not('domain', 'is', null)
    .order('last_message_at', { ascending: false });

  if (error || !conversations?.length) {
    return [];
  }

  // Group by domain
  const domainMap = new Map<string, string[]>();
  const convsByDomain = new Map<string, Array<{ id: string; title: string | null }>>();

  for (const conv of conversations as Array<{ id: string; domain: string; title: string | null }>) {
    if (!conv.domain) continue;

    if (!convsByDomain.has(conv.domain)) {
      convsByDomain.set(conv.domain, []);
    }

    const domainConvs = convsByDomain.get(conv.domain)!;
    // Limit per domain (Task 2.5)
    if (domainConvs.length < MAX_CONVERSATIONS_PER_DOMAIN) {
      domainConvs.push({ id: conv.id, title: conv.title });
    }
  }

  // For each domain with enough conversations, build summaries
  const domainGroups: DomainConversationGroup[] = [];

  for (const [domain, convs] of convsByDomain.entries()) {
    // Fetch recent messages for each conversation in this domain
    const summaries: string[] = [];

    for (const conv of convs) {
      const { data: messages } = await supabase
        .from('messages')
        .select('role, content')
        .eq('conversation_id', conv.id)
        .order('created_at', { ascending: false })
        .limit(5);

      if (messages?.length) {
        const messageCount = messages.length;
        const contentSnippet = messages
          .filter((m: { role: string; content: string }) => m.role === 'user')
          .map((m: { role: string; content: string }) => m.content)
          .slice(0, 3)
          .join(' | ');

        const title = conv.title || 'Untitled';
        summaries.push(`[${title}] ${contentSnippet}`);
      }
    }

    // Only include domains with minimum message threshold (Task 1.3)
    if (summaries.length >= MIN_MESSAGES_PER_DOMAIN) {
      domainGroups.push({ domain, summaries });
    }
  }

  return domainGroups;
}

// MARK: - LLM Pattern Analysis (Task 1.4, 2.1-2.4)

/**
 * Call LLM to analyze cross-domain conversation patterns.
 * Uses background model routing policy for cost efficiency.
 */
async function analyzePatterns(
  domainGroups: DomainConversationGroup[],
): Promise<CrossDomainPattern[]> {
  // Build the user message with domain-grouped summaries
  const userMessage = domainGroups
    .map(
      (group) =>
        `## ${group.domain.toUpperCase()} DOMAIN\n${group.summaries.map((s, i) => `${i + 1}. ${s}`).join('\n')}`,
    )
    .join('\n\n');

  const messages: ChatMessage[] = [
    { role: 'system', content: SYNTHESIS_SYSTEM_PROMPT },
    {
      role: 'user',
      content: `Analyze the following conversations across ${domainGroups.length} coaching domains for cross-domain patterns:\n\n${userMessage}`,
    },
  ];
  const route = selectBackgroundModel('pattern_synthesis');
  const budgetedMessages = enforceInputTokenBudget(messages, route.inputBudgetTokens);

  // Collect full response from streaming API
  let fullResponse = '';
  for await (const chunk of streamChatCompletion(budgetedMessages, {
    provider: route.provider,
    model: route.model,
    maxTokens: route.maxOutputTokens,
    temperature: route.temperature,
  })) {
    if (chunk.type === 'token' && chunk.content) {
      fullResponse += chunk.content;
    }
    if (chunk.type === 'error') {
      console.error('LLM analysis error:', chunk.error);
      return [];
    }
  }

  // Parse JSON response (Task 2.3)
  try {
    const parsed = JSON.parse(fullResponse.trim());
    if (!parsed.patterns || !Array.isArray(parsed.patterns)) {
      return [];
    }

    // Validate and filter each pattern
    return parsed.patterns
      .filter(
        (p: CrossDomainPattern) =>
          p.theme &&
          p.synthesis &&
          Array.isArray(p.domains) &&
          p.domains.length >= MIN_DOMAINS &&
          typeof p.confidence === 'number' &&
          Array.isArray(p.evidence),
      )
      .map((p: CrossDomainPattern) => ({
        theme: p.theme,
        domains: p.domains,
        confidence: p.confidence,
        evidence: p.evidence,
        synthesis: p.synthesis,
      }));
  } catch {
    console.error('Failed to parse LLM pattern analysis response:', fullResponse.slice(0, 200));
    return [];
  }
}

// MARK: - Rate Limiting (Task 4.6, 4.7)

/**
 * Check if a cross-domain synthesis can be surfaced for this conversation.
 * Enforces: max 1 per session, minimum 3-session gap for same theme.
 *
 * @param userId - User to check
 * @param theme - Pattern theme to check for gap
 * @param supabase - Authenticated Supabase client
 * @returns true if synthesis can be surfaced
 */
export async function canSurfaceSynthesis(
  userId: string,
  theme: string,
  supabase: SupabaseClient,
): Promise<boolean> {
  // Check minimum session gap for this specific theme
  const { data: existing } = await supabase
    .from('pattern_syntheses')
    .select('surface_count, last_surfaced_at')
    .eq('user_id', userId)
    .eq('theme', theme)
    .single();

  if (existing?.last_surfaced_at) {
    // Count sessions since last surfacing
    const { count } = await supabase
      .from('conversations')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', userId)
      .gt('created_at', existing.last_surfaced_at);

    if ((count ?? 0) < MIN_SESSIONS_BETWEEN_SYNTHESIS) {
      return false; // Too soon — need more sessions between same-theme synthesis
    }
  }

  return true;
}

/**
 * Record that a synthesis was surfaced to the user.
 * Updates surface_count and last_surfaced_at.
 */
export async function recordSynthesisSurfaced(
  userId: string,
  theme: string,
  supabase: SupabaseClient,
): Promise<void> {
  // Try atomic increment via RPC (handles surface_count = COALESCE(surface_count,0) + 1)
  const { error: rpcError } = await supabase.rpc('increment_surface_count', {
    p_user_id: userId,
    p_theme: theme,
  });

  if (!rpcError) {
    // RPC handled both surface_count increment and last_surfaced_at atomically
    return;
  }

  console.warn('increment_surface_count RPC failed, using fallback:', rpcError.message);

  // Fallback: read-modify-write. There is a small TOCTOU race window between
  // the SELECT and UPDATE below — concurrent calls for the same user+theme could
  // lose an increment. This is tolerated because surface_count is informational
  // (used for analytics, not correctness) and the RPC path above is the expected
  // production path; this fallback only runs if the RPC is missing or broken.
  const { data, error: selectError } = await supabase
    .from('pattern_syntheses')
    .select('surface_count')
    .eq('user_id', userId)
    .eq('theme', theme)
    .single();

  if (selectError) {
    console.error('Failed to read surface_count for fallback increment:', selectError.message);
    // Abort: proceeding would reset surface_count to 1, losing existing value
    return;
  }

  const { error: updateError } = await supabase
    .from('pattern_syntheses')
    .update({
      last_surfaced_at: new Date().toISOString(),
      surface_count: (data?.surface_count ?? 0) + 1,
    })
    .eq('user_id', userId)
    .eq('theme', theme);

  if (updateError) {
    console.error('Failed to update pattern synthesis surfacing:', updateError.message);
  }
}

/**
 * Filter patterns based on rate limiting rules.
 * Returns at most 1 pattern that passes the session gap check.
 */
export async function filterByRateLimit(
  userId: string,
  patterns: CrossDomainPattern[],
  supabase: SupabaseClient,
): Promise<CrossDomainPattern[]> {
  if (patterns.length === 0) return [];

  // Check each pattern against rate limit, return first eligible
  for (const pattern of patterns) {
    const canSurface = await canSurfaceSynthesis(userId, pattern.theme, supabase);
    if (canSurface) {
      return [pattern]; // Max 1 per session (AC #4)
    }
  }

  return []; // All patterns rate-limited
}
