/**
 * push-intelligence.ts
 *
 * Story 8.7: Smart Proactive Push Notifications
 *
 * Determines whether a user should receive a proactive push notification,
 * and what type. Three layers evaluated in priority order:
 *   1. Event-Based — upcoming event detected in recent messages
 *   2. Pattern-Based — recognized coaching pattern + user inactive 2+ days
 *   3. Re-Engagement — user inactive 3+ days, references last topic
 *
 * Returns null if no push is warranted.
 */

import { SupabaseClient } from 'npm:@supabase/supabase-js@2.94.1';
import { generatePatternSummary, PatternSummary } from './pattern-analyzer.ts';

// MARK: - Types

export interface PushDecision {
  pushType: 'event_based' | 'pattern_based' | 're_engagement';
  context: string;
  eventDescription?: string;
  patternTheme?: string;
  conversationDomain?: string;
}

interface TemporalReference {
  eventDescription: string;
  estimatedDate: Date;
  confidence: number;
  sourceMessageCreatedAt: string;
}

interface MessageRow {
  content: string;
  created_at: string;
  role: string;
}

interface ConversationRow {
  id: string;
  domain: string | null;
  created_at: string;
  last_message_at: string | null;
}

// MARK: - Constants

/** Minimum confidence for temporal reference to trigger event push */
const TEMPORAL_CONFIDENCE_THRESHOLD = 0.7;

/** Hours before event to trigger push */
const EVENT_WINDOW_HOURS = 24;

/** Days of inactivity before pattern-based push */
const PATTERN_INACTIVITY_DAYS = 2;

/** Days of inactivity before re-engagement push */
const RE_ENGAGEMENT_INACTIVITY_DAYS = 3;

/** Days to look back for messages with temporal references */
const TEMPORAL_SCAN_DAYS = 7;

// MARK: - Main Entry Point (Task 2.3)

/**
 * Evaluate push layers in priority order. Returns null if no push warranted.
 *
 * @param userId - User to evaluate
 * @param supabase - Service-role Supabase client
 * @returns PushDecision or null
 */
export async function determinePushType(
  userId: string,
  supabase: SupabaseClient,
): Promise<PushDecision | null> {
  // Layer 1: Event-Based (highest priority)
  const eventDecision = await checkEventBased(userId, supabase);
  if (eventDecision) return eventDecision;

  // Pre-fetch activity days once for layers 2 & 3 (avoids duplicate query)
  const daysSinceActive = await getDaysSinceLastActivity(userId, supabase);

  // Layer 2: Pattern-Based
  const patternDecision = await checkPatternBased(userId, supabase, daysSinceActive);
  if (patternDecision) return patternDecision;

  // Layer 3: Re-Engagement (fallback)
  const reEngagementDecision = await checkReEngagement(userId, supabase, daysSinceActive);
  if (reEngagementDecision) return reEngagementDecision;

  return null;
}

// MARK: - Layer 1: Event-Based (Task 2.4)

/**
 * Scan user messages from last 7 days for temporal references.
 * Trigger if event is within 24 hours and confidence >= 0.7.
 */
async function checkEventBased(
  userId: string,
  supabase: SupabaseClient,
): Promise<PushDecision | null> {
  const cutoff = new Date();
  cutoff.setDate(cutoff.getDate() - TEMPORAL_SCAN_DAYS);

  // Get user's conversations from last 7 days
  const { data: conversations } = await supabase
    .from('conversations')
    .select('id')
    .eq('user_id', userId)
    .gte('last_message_at', cutoff.toISOString())
    .order('last_message_at', { ascending: false })
    .limit(10);

  if (!conversations?.length) return null;

  const conversationIds = conversations.map((c: { id: string }) => c.id);

  // Get user messages (not assistant) from those conversations
  const { data: messages } = await supabase
    .from('messages')
    .select('content, created_at, role')
    .in('conversation_id', conversationIds)
    .eq('role', 'user')
    .gte('created_at', cutoff.toISOString())
    .order('created_at', { ascending: false })
    .limit(100);

  if (!messages?.length) return null;

  // Extract temporal references from message content
  const now = new Date();
  const refs = (messages as MessageRow[]).flatMap((msg) =>
    extractTemporalReferences(msg.content, new Date(msg.created_at))
  );

  // Find the best event within 24 hours
  const upcoming = refs
    .filter((ref) => {
      const hoursUntil = (ref.estimatedDate.getTime() - now.getTime()) / (1000 * 60 * 60);
      return hoursUntil > 0 && hoursUntil <= EVENT_WINDOW_HOURS && ref.confidence >= TEMPORAL_CONFIDENCE_THRESHOLD;
    })
    .sort((a, b) => a.estimatedDate.getTime() - b.estimatedDate.getTime());

  if (upcoming.length === 0) return null;

  const best = upcoming[0];
  return {
    pushType: 'event_based',
    context: `Upcoming event: ${best.eventDescription}`,
    eventDescription: best.eventDescription,
  };
}

// MARK: - Temporal Reference Extraction (Task 2.4)

/**
 * Extract temporal references from message content.
 * Resolves relative dates relative to the message's created_at timestamp.
 *
 * Edge cases handled:
 * - "March 15" when today is March 20 → March 15 next year
 * - "tomorrow" in a message sent 3 days ago → the day after the message
 * - Relative phrases resolve from message timestamp, not evaluation time
 */
export function extractTemporalReferences(
  content: string,
  messageCreatedAt: Date,
): TemporalReference[] {
  const refs: TemporalReference[] = [];

  // --- Relative date patterns ---

  // "tomorrow"
  const tomorrowMatch = content.match(/\btomorrow\b/i);
  if (tomorrowMatch) {
    const eventDate = new Date(messageCreatedAt);
    eventDate.setDate(eventDate.getDate() + 1);
    const eventDesc = extractEventContext(content, tomorrowMatch.index!);
    refs.push({
      eventDescription: eventDesc || 'upcoming event',
      estimatedDate: eventDate,
      confidence: 0.8,
      sourceMessageCreatedAt: messageCreatedAt.toISOString(),
    });
  }

  // "next [day]" — next Monday, next Tuesday, etc.
  const nextDayRegex = /\bnext\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b/gi;
  let nextDayMatch;
  while ((nextDayMatch = nextDayRegex.exec(content)) !== null) {
    const targetDay = dayNameToNumber(nextDayMatch[1]);
    if (targetDay !== null) {
      const eventDate = getNextDayOfWeek(messageCreatedAt, targetDay);
      const eventDesc = extractEventContext(content, nextDayMatch.index);
      refs.push({
        eventDescription: eventDesc || 'upcoming event',
        estimatedDate: eventDate,
        confidence: 0.75,
        sourceMessageCreatedAt: messageCreatedAt.toISOString(),
      });
    }
  }

  // "this [day]" — this Monday, this Thursday, etc.
  const thisDayRegex = /\bthis\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b/gi;
  let thisDayMatch;
  while ((thisDayMatch = thisDayRegex.exec(content)) !== null) {
    const targetDay = dayNameToNumber(thisDayMatch[1]);
    if (targetDay !== null) {
      const eventDate = getThisDayOfWeek(messageCreatedAt, targetDay);
      const eventDesc = extractEventContext(content, thisDayMatch.index);
      refs.push({
        eventDescription: eventDesc || 'upcoming event',
        estimatedDate: eventDate,
        confidence: 0.75,
        sourceMessageCreatedAt: messageCreatedAt.toISOString(),
      });
    }
  }

  // "on [day]" — on Monday, on Friday, etc. (nearest upcoming occurrence)
  const onDayRegex = /\bon\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b/gi;
  let onDayMatch;
  while ((onDayMatch = onDayRegex.exec(content)) !== null) {
    const targetDay = dayNameToNumber(onDayMatch[1]);
    if (targetDay !== null) {
      const eventDate = getUpcomingDayOfWeek(messageCreatedAt, targetDay);
      const eventDesc = extractEventContext(content, onDayMatch.index);
      refs.push({
        eventDescription: eventDesc || 'upcoming event',
        estimatedDate: eventDate,
        confidence: 0.7,
        sourceMessageCreatedAt: messageCreatedAt.toISOString(),
      });
    }
  }

  // "in [N] days" / "in [N] day"
  const inDaysRegex = /\bin\s+(\d+|two|three|four|five|six|seven)\s+days?\b/gi;
  let inDaysMatch;
  while ((inDaysMatch = inDaysRegex.exec(content)) !== null) {
    const num = parseWordNumber(inDaysMatch[1]);
    if (num !== null) {
      const eventDate = new Date(messageCreatedAt);
      eventDate.setDate(eventDate.getDate() + num);
      const eventDesc = extractEventContext(content, inDaysMatch.index);
      refs.push({
        eventDescription: eventDesc || 'upcoming event',
        estimatedDate: eventDate,
        confidence: 0.8,
        sourceMessageCreatedAt: messageCreatedAt.toISOString(),
      });
    }
  }

  // "next week" (Monday of next week from message date)
  const nextWeekMatch = content.match(/\bnext\s+week\b/i);
  if (nextWeekMatch) {
    const eventDate = getNextDayOfWeek(messageCreatedAt, 1); // Next Monday
    if (eventDate.getTime() - messageCreatedAt.getTime() < 2 * 24 * 60 * 60 * 1000) {
      // If "next Monday" is only 1-2 days away, push it to the Monday after
      eventDate.setDate(eventDate.getDate() + 7);
    }
    const eventDesc = extractEventContext(content, nextWeekMatch.index!);
    refs.push({
      eventDescription: eventDesc || 'upcoming event',
      estimatedDate: eventDate,
      confidence: 0.6,
      sourceMessageCreatedAt: messageCreatedAt.toISOString(),
    });
  }

  // --- Explicit date patterns ---

  // "Month Day" — "March 15", "January 3rd", "Feb 20th"
  const monthDayRegex = /\b(january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\s+(\d{1,2})(?:st|nd|rd|th)?\b/gi;
  let monthDayMatch;
  while ((monthDayMatch = monthDayRegex.exec(content)) !== null) {
    const month = monthNameToNumber(monthDayMatch[1]);
    const day = parseInt(monthDayMatch[2], 10);
    if (month !== null && day >= 1 && day <= 31) {
      const eventDate = resolveExplicitDate(messageCreatedAt, month, day);
      const eventDesc = extractEventContext(content, monthDayMatch.index);
      refs.push({
        eventDescription: eventDesc || 'upcoming event',
        estimatedDate: eventDate,
        confidence: 0.85,
        sourceMessageCreatedAt: messageCreatedAt.toISOString(),
      });
    }
  }

  // "M/D" or "M-D" numeric dates — "2/20", "3-15"
  // Validated against temporal cues and filtered for false positives (ratios, measurements)
  const numericDateRegex = /\b(\d{1,2})[/\-](\d{1,2})\b/g;
  const temporalCues = /\b(on|by|due|next|this|meeting|appointment|schedule|month|day|tomorrow|today|before|after|until|deadline|event|session|call)\b/i;
  const unitMarkers = /\b(cup|cups|oz|tbsp|tsp|ml|lb|lbs|kg|px|pt|em|rem|%|aspect|ratio|iOS|Android|x\d|\d+p)\b/i;
  let numericMatch;
  while ((numericMatch = numericDateRegex.exec(content)) !== null) {
    const month = parseInt(numericMatch[1], 10);
    const day = parseInt(numericMatch[2], 10);
    if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
      // Check surrounding context (40 chars each side) for temporal cues vs unit markers
      const start = Math.max(0, numericMatch.index - 40);
      const end = Math.min(content.length, numericMatch.index + numericMatch[0].length + 40);
      const surroundingText = content.substring(start, end);

      // Skip if adjacent to known unit/ratio markers
      if (unitMarkers.test(surroundingText)) continue;

      // Require temporal cues nearby — otherwise skip (likely a measurement or ratio)
      if (!temporalCues.test(surroundingText)) continue;

      const eventDate = resolveExplicitDate(messageCreatedAt, month - 1, day);
      const eventDesc = extractEventContext(content, numericMatch.index);
      refs.push({
        eventDescription: eventDesc || 'upcoming event',
        estimatedDate: eventDate,
        confidence: 0.7,
        sourceMessageCreatedAt: messageCreatedAt.toISOString(),
      });
    }
  }

  // "the [N]th" — "the 15th", "the 3rd"
  const theNthRegex = /\bthe\s+(\d{1,2})(?:st|nd|rd|th)\b/gi;
  let theNthMatch;
  while ((theNthMatch = theNthRegex.exec(content)) !== null) {
    const day = parseInt(theNthMatch[1], 10);
    if (day >= 1 && day <= 31) {
      // Assume current or next month
      const eventDate = new Date(messageCreatedAt);
      eventDate.setDate(day);
      if (eventDate.getTime() < messageCreatedAt.getTime()) {
        eventDate.setMonth(eventDate.getMonth() + 1);
      }
      const eventDesc = extractEventContext(content, theNthMatch.index);
      refs.push({
        eventDescription: eventDesc || 'upcoming event',
        estimatedDate: eventDate,
        confidence: 0.6,
        sourceMessageCreatedAt: messageCreatedAt.toISOString(),
      });
    }
  }

  return refs;
}

// MARK: - Temporal Helpers

function dayNameToNumber(name: string): number | null {
  const map: Record<string, number> = {
    sunday: 0, monday: 1, tuesday: 2, wednesday: 3,
    thursday: 4, friday: 5, saturday: 6,
  };
  return map[name.toLowerCase()] ?? null;
}

function monthNameToNumber(name: string): number | null {
  const map: Record<string, number> = {
    january: 0, jan: 0, february: 1, feb: 1, march: 2, mar: 2,
    april: 3, apr: 3, may: 4, june: 5, jun: 5,
    july: 6, jul: 6, august: 7, aug: 7, september: 8, sep: 8,
    october: 9, oct: 9, november: 10, nov: 10, december: 11, dec: 11,
  };
  return map[name.toLowerCase()] ?? null;
}

function parseWordNumber(word: string): number | null {
  const parsed = parseInt(word, 10);
  if (!isNaN(parsed)) return parsed;
  const map: Record<string, number> = {
    two: 2, three: 3, four: 4, five: 5, six: 6, seven: 7,
  };
  return map[word.toLowerCase()] ?? null;
}

/**
 * Get the upcoming occurrence of a day of week from a reference date.
 * Used for "on [day]" — returns the nearest future occurrence.
 */
function getUpcomingDayOfWeek(from: Date, targetDay: number): Date {
  const result = new Date(from);
  const currentDay = result.getDay();
  let daysAhead = targetDay - currentDay;
  if (daysAhead <= 0) daysAhead += 7;
  result.setDate(result.getDate() + daysAhead);
  return result;
}

/**
 * Get "next [day]" — the occurrence in the FOLLOWING week.
 * "next Thursday" from Monday = 10 days (not 3).
 */
function getNextDayOfWeek(from: Date, targetDay: number): Date {
  const upcoming = getUpcomingDayOfWeek(from, targetDay);
  // Use UTC-midnight dates to avoid DST fractional-day issues
  const fromUTC = Date.UTC(from.getFullYear(), from.getMonth(), from.getDate());
  const upcomingUTC = Date.UTC(upcoming.getFullYear(), upcoming.getMonth(), upcoming.getDate());
  const msPerDay = 24 * 60 * 60 * 1000;
  const daysUntil = Math.floor((upcomingUTC - fromUTC) / msPerDay);
  // If the upcoming occurrence is within the same week (< 7 days), push to next week
  if (daysUntil < 7) {
    upcoming.setDate(upcoming.getDate() + 7);
  }
  return upcoming;
}

/**
 * Get "this [day]" — the nearest upcoming occurrence (this week).
 * "this Thursday" from Monday = 3 days.
 */
function getThisDayOfWeek(from: Date, targetDay: number): Date {
  return getUpcomingDayOfWeek(from, targetDay);
}

/**
 * Resolve explicit Month/Day to the next future occurrence.
 * If the date has already passed this year, use next year.
 */
function resolveExplicitDate(reference: Date, month: number, day: number): Date {
  const thisYear = new Date(reference.getFullYear(), month, day);
  if (thisYear.getTime() > reference.getTime()) {
    return thisYear;
  }
  return new Date(reference.getFullYear() + 1, month, day);
}

/**
 * Extract event context near a temporal reference by looking for event indicator words.
 * Returns a short description or null.
 */
function extractEventContext(content: string, matchIndex: number): string | null {
  const eventIndicators = [
    'presentation', 'interview', 'meeting', 'deadline', 'conversation',
    'review', 'appointment', 'exam', 'test', 'call', 'session',
    'conference', 'workshop', 'talk', 'pitch', 'demo',
  ];

  // Search within ±100 chars of the temporal match
  const windowStart = Math.max(0, matchIndex - 100);
  const windowEnd = Math.min(content.length, matchIndex + 100);
  const window = content.slice(windowStart, windowEnd).toLowerCase();

  for (const indicator of eventIndicators) {
    if (window.includes(indicator)) {
      // Extract a short phrase around the indicator
      const indicatorIndex = window.indexOf(indicator);
      const phraseStart = Math.max(0, indicatorIndex - 20);
      const phraseEnd = Math.min(window.length, indicatorIndex + indicator.length + 30);
      let phrase = window.slice(phraseStart, phraseEnd).trim();
      // Clean up partial words at edges
      if (phraseStart > 0) phrase = phrase.replace(/^\S*\s/, '');
      if (phraseEnd < window.length) phrase = phrase.replace(/\s\S*$/, '');
      return phrase;
    }
  }

  return null;
}

// MARK: - Layer 2: Pattern-Based (Task 2.5)

/**
 * Check for pattern-based push: user has recognized patterns AND is inactive 2+ days.
 */
async function checkPatternBased(
  userId: string,
  supabase: SupabaseClient,
  daysSinceActive: number,
): Promise<PushDecision | null> {
  if (daysSinceActive < PATTERN_INACTIVITY_DAYS) return null;

  // Get pattern summaries (from Story 8.4)
  let patterns: PatternSummary[];
  try {
    patterns = await generatePatternSummary(userId, supabase);
  } catch {
    return null;
  }

  if (patterns.length === 0) return null;

  // Use top pattern for the push
  const topPattern = patterns[0];
  return {
    pushType: 'pattern_based',
    context: `Recognized pattern: ${topPattern.theme}`,
    patternTheme: topPattern.theme,
    conversationDomain: topPattern.domains[0],
  };
}

// MARK: - Layer 3: Re-Engagement (Task 2.6)

/**
 * Check for re-engagement push: user inactive 3+ days, references last conversation topic.
 */
async function checkReEngagement(
  userId: string,
  supabase: SupabaseClient,
  daysSinceActive: number,
): Promise<PushDecision | null> {
  if (daysSinceActive < RE_ENGAGEMENT_INACTIVITY_DAYS) return null;

  // Get last conversation's domain and recent messages for topic extraction
  const { data: lastConversation } = await supabase
    .from('conversations')
    .select('id, domain, created_at, last_message_at')
    .eq('user_id', userId)
    .order('last_message_at', { ascending: false })
    .limit(1)
    .single();

  if (!lastConversation) return null;

  const conv = lastConversation as ConversationRow;

  // Get the last few user messages for topic summary
  const { data: messages } = await supabase
    .from('messages')
    .select('content, created_at, role')
    .eq('conversation_id', conv.id)
    .eq('role', 'user')
    .order('created_at', { ascending: false })
    .limit(3);

  // Build a brief topic summary from the last messages (max 50 tokens ≈ ~200 chars)
  let topicSummary = conv.domain || 'your coaching journey';
  if (messages?.length) {
    const lastContent = (messages as MessageRow[])
      .map((m) => m.content)
      .join(' ')
      .slice(0, 200)
      .trim();
    if (lastContent.length > 20) {
      // Extract a key phrase from the content
      topicSummary = extractTopicPhrase(lastContent) || conv.domain || 'our last conversation';
    }
  }

  return {
    pushType: 're_engagement',
    context: `Last topic: ${topicSummary}`,
    conversationDomain: conv.domain || undefined,
  };
}

// MARK: - Activity Check Helper

/**
 * Get days since user's last conversation activity.
 */
async function getDaysSinceLastActivity(
  userId: string,
  supabase: SupabaseClient,
): Promise<number> {
  const { data } = await supabase
    .from('conversations')
    .select('last_message_at')
    .eq('user_id', userId)
    .order('last_message_at', { ascending: false })
    .limit(1)
    .single();

  if (!data?.last_message_at) return Infinity;

  const lastActive = new Date(data.last_message_at as string);
  const now = new Date();
  return (now.getTime() - lastActive.getTime()) / (1000 * 60 * 60 * 24);
}

/**
 * Extract a brief topic phrase from message content.
 * Returns a concise topic description or null.
 */
function extractTopicPhrase(content: string): string | null {
  // Take the first meaningful sentence or phrase
  const sentences = content.split(/[.!?]+/).filter((s) => s.trim().length > 10);
  if (sentences.length === 0) return null;

  // Take first sentence, truncate to ~50 chars
  let phrase = sentences[0].trim();
  if (phrase.length > 60) {
    phrase = phrase.slice(0, 57) + '...';
  }
  return phrase;
}

// MARK: - Push Prompt Builder (Task 2.7)

/**
 * Build LLM prompt for push notification content generation.
 * Uses style instructions from style-adapter.ts (Story 8.6).
 *
 * @param decision - Push type decision from determinePushType
 * @param userContextSummary - Formatted user context string
 * @param styleInstructions - Style instructions from formatStyleInstructions()
 * @returns Prompt string for Haiku LLM call
 */
export function buildPushPrompt(
  decision: PushDecision,
  userContextSummary: string,
  styleInstructions: string,
): string {
  return `You are a warm, personal coach composing a brief push notification.

USER CONTEXT:
${userContextSummary}

PUSH TYPE: ${decision.pushType}
${decision.eventDescription ? `EVENT: ${decision.eventDescription}` : ''}
${decision.patternTheme ? `PATTERN: ${decision.patternTheme}` : ''}
${decision.conversationDomain ? `LAST TOPIC: ${decision.conversationDomain}` : ''}

STYLE: ${styleInstructions || 'Use a warm, supportive tone. Balance directness with exploration.'}

Write a push notification with:
- title: Max 50 characters. Warm, personal. Never generic.
- body: Max 200 characters. Reference their specific context. End with an invitation, not a demand.

Respond in JSON: { "title": "...", "body": "..." }`;
}

// MARK: - Exports for Testing

export {
  checkEventBased,
  checkPatternBased,
  checkReEngagement,
  getDaysSinceLastActivity,
  extractEventContext,
  TEMPORAL_CONFIDENCE_THRESHOLD,
  EVENT_WINDOW_HOURS,
  PATTERN_INACTIVITY_DAYS,
  RE_ENGAGEMENT_INACTIVITY_DAYS,
  TEMPORAL_SCAN_DAYS,
};
