import { SupabaseClient } from 'npm:@supabase/supabase-js@2.94.1';

/**
 * Log API usage and cost to usage_logs table
 * Per architecture.md: Per-user API cost tracking embedded in backend
 */
export async function logUsage(
  supabase: SupabaseClient,
  data: {
    userId: string;
    conversationId: string;
    messageId: string;
    model: string;
    promptTokens: number;
    completionTokens: number;
    costUsd: number;
    crisisDetected?: boolean;  // Story 4.1: Crisis detection flag for monitoring
  }
): Promise<void> {
  const { error } = await supabase.from('usage_logs').insert({
    user_id: data.userId,
    conversation_id: data.conversationId,
    message_id: data.messageId,
    model: data.model,
    tokens_in: data.promptTokens,
    tokens_out: data.completionTokens,
    cost_usd: data.costUsd,
    crisis_detected: data.crisisDetected ?? false,  // Story 4.1
    created_at: new Date().toISOString(),
  });

  if (error) {
    // Log but don't fail the request
    console.error('Failed to log usage:', error);
  }
}
