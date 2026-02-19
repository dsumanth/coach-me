import { SupabaseClient } from 'npm:@supabase/supabase-js@2.94.1';

/**
 * Log API usage and cost to usage_logs table
 * Per architecture.md: Per-user API cost tracking embedded in backend
 *
 * conversationId and messageId are nullable for non-conversation events
 * (e.g., push notification LLM calls that have no associated conversation).
 */
export async function logUsage(
  supabase: SupabaseClient,
  data: {
    userId: string;
    conversationId: string | null;
    messageId: string | null;
    model: string;
    promptTokens: number;
    completionTokens: number;
    costUsd: number;
    crisisDetected?: boolean;  // Story 4.1: Crisis detection flag for monitoring
  }
): Promise<void> {
  const row: Record<string, unknown> = {
    user_id: data.userId,
    model: data.model,
    tokens_in: data.promptTokens,
    tokens_out: data.completionTokens,
    cost_usd: data.costUsd,
    crisis_detected: data.crisisDetected ?? false,  // Story 4.1
    created_at: new Date().toISOString(),
  };

  // Only include FK columns when non-null to avoid FK constraint violations
  if (data.conversationId) {
    row.conversation_id = data.conversationId;
  }
  if (data.messageId) {
    row.message_id = data.messageId;
  }

  const { error } = await supabase.from('usage_logs').insert(row);

  if (error) {
    // Log but don't fail the request
    console.error('Failed to log usage:', error);
  }
}
