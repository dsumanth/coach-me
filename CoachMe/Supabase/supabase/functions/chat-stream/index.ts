import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { handleCors } from '../_shared/cors.ts';
import { verifyAuth } from '../_shared/auth.ts';
import { errorResponse, sseHeaders } from '../_shared/response.ts';
import { streamChatCompletion, calculateCost, type ChatMessage } from '../_shared/llm-client.ts';
import { logUsage } from '../_shared/cost-tracker.ts';

interface ChatRequest {
  message: string;
  conversationId: string;
}

serve(async (req: Request) => {
  // Handle CORS preflight
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    // AC1: Verify JWT and extract user ID
    const { userId, supabase } = await verifyAuth(req);

    // Parse request body
    const body: ChatRequest = await req.json();
    const { message, conversationId } = body;

    if (!message?.trim() || !conversationId) {
      return errorResponse('Missing message or conversationId', 400);
    }

    // Issue #4 FIX: Validate conversation ownership before inserting
    const { data: conversation, error: convError } = await supabase
      .from('conversations')
      .select('id')
      .eq('id', conversationId)
      .eq('user_id', userId)
      .single();

    if (convError || !conversation) {
      return errorResponse('Conversation not found or access denied', 404);
    }

    // Save user message to database
    const userMessageId = crypto.randomUUID();
    // Issue #5 FIX: Check insert result and handle error
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

    // Load conversation history for context
    const { data: historyMessages } = await supabase
      .from('messages')
      .select('role, content')
      .eq('conversation_id', conversationId)
      .order('created_at', { ascending: true })
      .limit(20); // Limit history to prevent token overflow

    // Build message array for LLM
    const systemPrompt = buildSystemPrompt();
    const messages: ChatMessage[] = [
      { role: 'system', content: systemPrompt },
      ...(historyMessages ?? []).map((m: { role: string; content: string }) => ({
        role: m.role as 'user' | 'assistant',
        content: m.content,
      })),
    ];

    // AC2: Stream response via SSE
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
              // Send SSE event
              const event = `data: ${JSON.stringify({ type: 'token', content: chunk.content })}\n\n`;
              controller.enqueue(encoder.encode(event));
            }

            if (chunk.type === 'done' && chunk.usage) {
              tokenUsage = chunk.usage;

              // AC3: Save assistant message to database
              // Issue #7 FIX: Handle save error and report to user
              const { error: assistantMsgError } = await supabase.from('messages').insert({
                id: assistantMessageId,
                conversation_id: conversationId,
                role: 'assistant',
                content: fullContent,
                user_id: userId,
                token_count: tokenUsage.completion_tokens,
              });

              if (assistantMsgError) {
                console.error('Failed to save assistant message:', assistantMsgError);
                // Send error event instead of done
                const errorEvent = `data: ${JSON.stringify({
                  type: 'error',
                  message: "Coach's response couldn't be saved. Please try again."
                })}\n\n`;
                controller.enqueue(encoder.encode(errorEvent));
                return;
              }

              // AC3: Log usage and cost
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

              // Send done event
              const doneEvent = `data: ${JSON.stringify({
                type: 'done',
                messageId: assistantMessageId,
                usage: tokenUsage
              })}\n\n`;
              controller.enqueue(encoder.encode(doneEvent));
            }

            if (chunk.type === 'error') {
              // AC4: Graceful error handling
              const errorEvent = `data: ${JSON.stringify({
                type: 'error',
                message: "Coach is taking a moment. Let's try again."
              })}\n\n`;
              controller.enqueue(encoder.encode(errorEvent));
            }
          }
        } catch (error) {
          console.error('Stream error:', error);
          // AC4: Send error event
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
    // AC4: Return graceful error
    const errorMessage = (error as Error).message;
    return errorResponse(errorMessage, errorMessage.includes('authorization') ? 401 : 500);
  }
});

/**
 * Build system prompt for coaching
 * Will be enhanced in Story 3.1 with domain routing
 */
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
