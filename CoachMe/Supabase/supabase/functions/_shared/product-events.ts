import type { SupabaseClient } from 'npm:@supabase/supabase-js@2.94.1';

export interface ProductEventInput {
  userId: string;
  eventName: string;
  conversationId?: string | null;
  messageId?: string | null;
  properties?: Record<string, unknown>;
}

/**
 * Best-effort product event logging.
 * Never throws so analytics writes do not impact user-facing chat latency.
 */
export async function logProductEvent(
  supabase: SupabaseClient,
  input: ProductEventInput,
): Promise<void> {
  try {
    const row = {
      user_id: input.userId,
      event_name: input.eventName,
      conversation_id: input.conversationId ?? null,
      message_id: input.messageId ?? null,
      properties: input.properties ?? {},
    };

    const { error } = await supabase
      .from('product_events')
      .insert(row);

    if (error) {
      console.error('Failed to log product event:', input.eventName, error.message);
    }
  } catch (err) {
    console.error('Product event logging threw unexpectedly:', input.eventName, err);
  }
}
