import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

// ============ CORS ============
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function handleCors(req: Request): Response | null {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  return null;
}

// ============ SSE Headers ============
const sseHeaders = {
  ...corsHeaders,
  'Content-Type': 'text/event-stream',
  'Cache-Control': 'no-cache',
  'Connection': 'keep-alive',
};

// ============ Auth ============
async function verifyAuth(req: Request): Promise<{ userId: string; supabase: SupabaseClient }> {
  const authHeader = req.headers.get('Authorization');
  if (!authHeader?.startsWith('Bearer ')) {
    throw new Error('Missing or invalid authorization header');
  }

  const jwt = authHeader.replace('Bearer ', '');

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_ANON_KEY') ?? '',
    {
      global: { headers: { Authorization: `Bearer ${jwt}` } },
      auth: { persistSession: false },
    }
  );

  const { data: { user }, error } = await supabase.auth.getUser();

  if (error || !user) {
    throw new Error('Invalid or expired token');
  }

  return { userId: user.id, supabase };
}

// ============ Response Helpers ============
function errorResponse(message: string, status = 400): Response {
  return new Response(
    JSON.stringify({
      error: message,
      userMessage: getWarmErrorMessage(message)
    }),
    {
      status,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    }
  );
}

function getWarmErrorMessage(error: string): string {
  if (error.includes('authorization') || error.includes('token')) {
    return "I had trouble remembering you. Please sign in again.";
  }
  if (error.includes('rate') || error.includes('limit')) {
    return "Let's take a breath. You can continue in a moment.";
  }
  return "Coach is taking a moment. Let's try again.";
}

// ============ LLM Types ============
interface ChatMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

interface StreamChunk {
  type: 'token' | 'done' | 'error';
  content?: string;
  usage?: {
    prompt_tokens: number;
    completion_tokens: number;
    total_tokens: number;
  };
  error?: string;
}

// ============ LLM Client ============
async function* streamChatCompletion(
  messages: ChatMessage[],
  config: { model: string }
): AsyncGenerator<StreamChunk> {
  const startTime = Date.now();
  const timeout = 30000;

  try {
    const apiKey = Deno.env.get('ANTHROPIC_API_KEY');
    if (!apiKey) throw new Error('ANTHROPIC_API_KEY not configured');

    const systemMessage = messages.find(m => m.role === 'system')?.content ?? '';
    const conversationMessages = messages
      .filter(m => m.role !== 'system')
      .map(m => ({ role: m.role, content: m.content }));

    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: config.model,
        max_tokens: 4096,
        temperature: 0.7,
        system: systemMessage,
        messages: conversationMessages,
        stream: true,
      }),
    });

    if (!response.ok) {
      const error = await response.text();
      throw new Error(`Anthropic API error: ${error}`);
    }

    const reader = response.body?.getReader();
    if (!reader) throw new Error('No response body');

    const decoder = new TextDecoder();
    let buffer = '';
    let totalPromptTokens = 0;
    let totalCompletionTokens = 0;

    while (true) {
      if (Date.now() - startTime > timeout) {
        throw new Error('Stream timeout');
      }

      const { done, value } = await reader.read();
      if (done) break;

      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split('\n');
      buffer = lines.pop() ?? '';

      for (const line of lines) {
        if (!line.startsWith('data: ')) continue;
        const data = line.slice(6);
        if (data === '[DONE]') continue;

        try {
          const event = JSON.parse(data);

          if (event.type === 'content_block_delta' && event.delta?.text) {
            yield { type: 'token', content: event.delta.text };
          }

          if (event.type === 'message_start' && event.message?.usage) {
            totalPromptTokens = event.message.usage.input_tokens ?? 0;
          }

          if (event.type === 'message_delta' && event.usage) {
            totalCompletionTokens = event.usage.output_tokens ?? 0;
          }
        } catch {
          // Skip malformed JSON
        }
      }
    }

    yield {
      type: 'done',
      usage: {
        prompt_tokens: totalPromptTokens,
        completion_tokens: totalCompletionTokens,
        total_tokens: totalPromptTokens + totalCompletionTokens,
      },
    };
  } catch (error) {
    yield { type: 'error', error: (error as Error).message };
  }
}

// ============ Cost Calculation ============
function calculateCost(
  usage: { prompt_tokens: number; completion_tokens: number },
  model: string
): number {
  const pricing: Record<string, { input: number; output: number }> = {
    'claude-sonnet-4-20250514': { input: 3.0, output: 15.0 },
  };
  const price = pricing[model] ?? { input: 3.0, output: 15.0 };
  return (usage.prompt_tokens / 1_000_000) * price.input +
         (usage.completion_tokens / 1_000_000) * price.output;
}

// ============ Usage Logging ============
async function logUsage(
  supabase: SupabaseClient,
  data: {
    userId: string;
    conversationId: string;
    messageId: string;
    model: string;
    promptTokens: number;
    completionTokens: number;
    costUsd: number;
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
    created_at: new Date().toISOString(),
  });

  if (error) {
    console.error('Failed to log usage:', error);
  }
}

// ============ System Prompt ============
function buildSystemPrompt(): string {
  return `You are a warm, supportive life coach. Your role is to help users reflect, gain clarity, and take meaningful action in their lives.

Guidelines:
- Be warm, empathetic, and non-judgmental
- Ask thoughtful questions to help users explore their thoughts
- Never diagnose, prescribe, or claim clinical expertise
- If users mention crisis indicators (self-harm, suicide), acknowledge their feelings and encourage professional help
- Keep responses conversational and coaching-focused
- Reference previous parts of the conversation when relevant

Remember: You are a coach, not a therapist. Help users think through challenges and find their own insights.`;
}

// ============ Main Handler ============
interface ChatRequest {
  message: string;
  conversationId: string;
}

serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const { userId, supabase } = await verifyAuth(req);

    const body: ChatRequest = await req.json();
    const { message, conversationId } = body;

    if (!message?.trim() || !conversationId) {
      return errorResponse('Missing message or conversationId', 400);
    }

    const userMessageId = crypto.randomUUID();
    const { error: userMsgError } = await supabase.from('messages').insert({
      id: userMessageId,
      conversation_id: conversationId,
      role: 'user',
      content: message,
      user_id: userId,
    });

    if (userMsgError) {
      console.error('Failed to save user message:', userMsgError);
      return errorResponse('Failed to save message', 500);
    }

    const { data: historyMessages } = await supabase
      .from('messages')
      .select('role, content')
      .eq('conversation_id', conversationId)
      .order('created_at', { ascending: true })
      .limit(20);

    const systemPrompt = buildSystemPrompt();
    const messages: ChatMessage[] = [
      { role: 'system', content: systemPrompt },
      ...(historyMessages ?? []).map((m: { role: string; content: string }) => ({
        role: m.role as 'user' | 'assistant',
        content: m.content,
      })),
    ];

    const assistantMessageId = crypto.randomUUID();
    let fullContent = '';
    let tokenUsage = { prompt_tokens: 0, completion_tokens: 0, total_tokens: 0 };
    const model = 'claude-sonnet-4-20250514';

    const stream = new ReadableStream({
      async start(controller) {
        const encoder = new TextEncoder();

        try {
          for await (const chunk of streamChatCompletion(messages, { model })) {
            if (chunk.type === 'token' && chunk.content) {
              fullContent += chunk.content;
              const event = `data: ${JSON.stringify({ type: 'token', content: chunk.content })}\n\n`;
              controller.enqueue(encoder.encode(event));
            }

            if (chunk.type === 'done' && chunk.usage) {
              tokenUsage = chunk.usage;

              await supabase.from('messages').insert({
                id: assistantMessageId,
                conversation_id: conversationId,
                role: 'assistant',
                content: fullContent,
                user_id: userId,
                token_count: tokenUsage.completion_tokens,
              });

              const costUsd = calculateCost(tokenUsage, model);
              await logUsage(supabase, {
                userId,
                conversationId,
                messageId: assistantMessageId,
                model,
                promptTokens: tokenUsage.prompt_tokens,
                completionTokens: tokenUsage.completion_tokens,
                costUsd,
              });

              const doneEvent = `data: ${JSON.stringify({
                type: 'done',
                messageId: assistantMessageId,
                usage: tokenUsage
              })}\n\n`;
              controller.enqueue(encoder.encode(doneEvent));
            }

            if (chunk.type === 'error') {
              const errorEvent = `data: ${JSON.stringify({
                type: 'error',
                message: "Coach is taking a moment. Let's try again."
              })}\n\n`;
              controller.enqueue(encoder.encode(errorEvent));
            }
          }
        } catch (error) {
          console.error('Stream error:', error);
          const errorEvent = `data: ${JSON.stringify({
            type: 'error',
            message: "Coach is taking a moment. Let's try again."
          })}\n\n`;
          controller.enqueue(encoder.encode(errorEvent));
        } finally {
          controller.close();
        }
      },
    });

    return new Response(stream, { headers: sseHeaders });

  } catch (error) {
    console.error('Chat stream error:', error);
    const errorMessage = (error as Error).message;
    return errorResponse(errorMessage, errorMessage.includes('authorization') ? 401 : 500);
  }
});
