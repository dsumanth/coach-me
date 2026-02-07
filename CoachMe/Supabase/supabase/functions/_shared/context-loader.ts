/**
 * context-loader.ts
 *
 * Story 2.4: Context Injection into Coaching Responses
 * Loads user context from context_profiles table for personalized coaching
 *
 * Target: <200ms load time per architecture NFR
 */

import { SupabaseClient } from 'npm:@supabase/supabase-js@2.94.1';
import { summarizeConversation } from './conversation-summarizer.ts';

// MARK: - Types

/** Past conversation summary for cross-session references (Story 3.3) */
export interface PastConversation {
  conversationId: string;
  title: string | null;
  domain: string | null;
  summary: string;
  lastMessageAt: string;
}

/** Conversation history result (Story 3.3) */
export interface ConversationHistory {
  conversations: PastConversation[];
  hasHistory: boolean;
}

/** Context value from user's profile */
export interface ContextValue {
  id: string;
  content: string;
  source: 'user' | 'extracted';
  confidence?: number;
  added_at: string;
}

/** Context goal from user's profile */
export interface ContextGoal {
  id: string;
  content: string;
  domain?: string;
  source: 'user' | 'extracted';
  status: 'active' | 'completed' | 'paused';
  added_at: string;
}

/** Life situation context */
export interface ContextSituation {
  life_stage?: string;
  occupation?: string;
  relationships?: string;
  challenges?: string;
  freeform?: string;
}

/** Extracted insight from conversations */
export interface ExtractedInsight {
  id: string;
  content: string;
  category: 'value' | 'goal' | 'situation' | 'pattern';
  confidence: number;
  source_conversation_id?: string;
  confirmed: boolean;
  extracted_at: string;
}

/** User context for prompt injection */
export interface UserContext {
  values: ContextValue[];
  goals: ContextGoal[];
  situation: ContextSituation;
  confirmedInsights: ExtractedInsight[];
  hasContext: boolean;
}

/** Raw row from context_profiles table */
interface ContextProfileRow {
  values: ContextValue[] | null;
  goals: ContextGoal[] | null;
  situation: ContextSituation | null;
  extracted_insights: ExtractedInsight[] | null;
}

// MARK: - Context Loading

/**
 * Load user context from database
 *
 * @param supabase - Supabase client with user auth
 * @param userId - User ID to load context for
 * @returns UserContext with values, goals, situation, and confirmed insights
 *
 * Performance: Targets <200ms total load time
 * Graceful degradation: Returns empty context on error (doesn't block chat)
 */
export async function loadUserContext(
  supabase: SupabaseClient,
  userId: string
): Promise<UserContext> {
  const emptyContext: UserContext = {
    values: [],
    goals: [],
    situation: {},
    confirmedInsights: [],
    hasContext: false,
  };

  try {
    // Single query to get all context data
    const { data: profile, error } = await supabase
      .from('context_profiles')
      .select('values, goals, situation, extracted_insights')
      .eq('user_id', userId)
      .single();

    if (error) {
      // PGRST116 = no rows returned (user has no profile yet)
      if (error.code === 'PGRST116') {
        return emptyContext;
      }
      console.error('Error loading context:', error.message);
      return emptyContext;
    }

    if (!profile) {
      return emptyContext;
    }

    const row = profile as ContextProfileRow;

    // Extract values - filter out empty
    const values = (row.values ?? []).filter(v => v.content?.trim());

    // Extract goals - only active ones for prompt injection
    const goals = (row.goals ?? []).filter(
      g => g.content?.trim() && g.status === 'active'
    );

    // Extract situation
    const situation = row.situation ?? {};

    // Extract ONLY confirmed insights for prompt injection
    const confirmedInsights = (row.extracted_insights ?? []).filter(
      i => i.confirmed === true && i.content?.trim()
    );

    // Check if user has any meaningful context
    const hasContext =
      values.length > 0 ||
      goals.length > 0 ||
      Object.values(situation).some(v => v?.trim()) ||
      confirmedInsights.length > 0;

    return {
      values,
      goals,
      situation,
      confirmedInsights,
      hasContext,
    };
  } catch (error) {
    // Log but don't throw - context loading should never block chat
    console.error('Unexpected error loading context:', error);
    return emptyContext;
  }
}

/**
 * Format context for display in system prompt
 *
 * @param context - UserContext to format
 * @returns Formatted string sections for prompt injection
 */
export function formatContextForPrompt(context: UserContext): {
  valuesSection: string;
  goalsSection: string;
  situationSection: string;
  insightsSection: string;
} {
  // Format values
  const valuesSection =
    context.values.length > 0
      ? context.values.map(v => v.content).join(', ')
      : '';

  // Format goals
  const goalsSection =
    context.goals.length > 0
      ? context.goals.map(g => g.content).join(', ')
      : '';

  // Format situation - combine all non-empty fields
  const situationParts: string[] = [];
  const s = context.situation;
  if (s.occupation) situationParts.push(s.occupation);
  if (s.life_stage) situationParts.push(s.life_stage);
  if (s.relationships) situationParts.push(s.relationships);
  if (s.challenges) situationParts.push(s.challenges);
  if (s.freeform) situationParts.push(s.freeform);
  const situationSection = situationParts.join('. ');

  // Format confirmed insights by category
  const insightsByCategory = context.confirmedInsights.reduce(
    (acc, insight) => {
      if (!acc[insight.category]) {
        acc[insight.category] = [];
      }
      acc[insight.category].push(insight.content);
      return acc;
    },
    {} as Record<string, string[]>
  );

  const insightParts: string[] = [];
  if (insightsByCategory.value?.length) {
    insightParts.push(`Values: ${insightsByCategory.value.join(', ')}`);
  }
  if (insightsByCategory.goal?.length) {
    insightParts.push(`Goals: ${insightsByCategory.goal.join(', ')}`);
  }
  if (insightsByCategory.situation?.length) {
    insightParts.push(`Context: ${insightsByCategory.situation.join(', ')}`);
  }
  if (insightsByCategory.pattern?.length) {
    insightParts.push(`Patterns: ${insightsByCategory.pattern.join(', ')}`);
  }
  const insightsSection = insightParts.join('; ');

  return {
    valuesSection,
    goalsSection,
    situationSection,
    insightsSection,
  };
}

// MARK: - Cross-Session History Loading (Story 3.3)

/**
 * Load relevant conversation history for cross-session references
 *
 * @param supabase - Supabase client with user auth
 * @param userId - User ID to load history for
 * @param currentConversationId - Current conversation to exclude from results
 * @returns ConversationHistory with up to 5 most recent past conversations
 *
 * Performance: Targets <100ms (runs in parallel with context profile load)
 * Graceful degradation: Returns empty history on any error (AC #6)
 */
export async function loadRelevantHistory(
  supabase: SupabaseClient,
  userId: string,
  currentConversationId: string,
): Promise<ConversationHistory> {
  try {
    const { data: conversations } = await supabase
      .from('conversations')
      .select('id, title, domain, last_message_at')
      .eq('user_id', userId)
      .neq('id', currentConversationId)
      .order('last_message_at', { ascending: false })
      .limit(5);

    if (!conversations?.length) {
      return { conversations: [], hasHistory: false };
    }

    const summaries = await Promise.all(
      conversations.map(async (conv: { id: string; title: string | null; domain: string | null; last_message_at: string }) => {
        const { data: messages } = await supabase
          .from('messages')
          .select('role, content')
          .eq('conversation_id', conv.id)
          .order('created_at', { ascending: false })
          .limit(3);

        return {
          conversationId: conv.id,
          title: conv.title,
          domain: conv.domain,
          summary: summarizeConversation(messages ?? [], conv.title, conv.domain),
          lastMessageAt: conv.last_message_at,
        };
      }),
    );

    return { conversations: summaries, hasHistory: true };
  } catch (error) {
    console.error('Failed to load history, proceeding without:', error);
    return { conversations: [], hasHistory: false };
  }
}
