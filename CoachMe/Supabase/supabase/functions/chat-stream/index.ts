import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { handleCors } from '../_shared/cors.ts';
import { verifyAuth } from '../_shared/auth.ts';
import { errorResponse, sseHeaders } from '../_shared/response.ts';
import { streamChatCompletion, calculateCost, type ChatMessage } from '../_shared/llm-client.ts';
import { logUsage } from '../_shared/cost-tracker.ts';
import { loadUserContext } from '../_shared/context-loader.ts';
import { buildCoachingPrompt, hasMemoryMoments } from '../_shared/prompt-builder.ts';

interface ChatRequest {
  message: string;
  conversation_id?: string;  // snake_case from iOS client
  conversationId?: string;   // camelCase fallback
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
    const message = body.message;
    // Support both snake_case (iOS) and camelCase
    const conversationId = body.conversation_id || body.conversationId;

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

    // Story 2.4: Load user context for personalized coaching
    // Target <200ms per architecture NFR
    const userContext = await loadUserContext(supabase, userId);

    // Load conversation history for context
    const { data: historyMessages } = await supabase
      .from('messages')
      .select('role, content')
      .eq('conversation_id', conversationId)
      .order('created_at', { ascending: true })
      .limit(20); // Limit history to prevent token overflow

    // Story 2.4: Build context-aware system prompt
    const systemPrompt = buildCoachingPrompt(userContext);
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
              // Story 2.4: Detect memory moments in streamed content (AC #4)
              const memoryMoment = hasMemoryMoments(fullContent);
              // Send SSE event with memory_moment flag
              const event = `data: ${JSON.stringify({
                type: 'token',
                content: chunk.content,
                memory_moment: memoryMoment
              })}\n\n`;
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

              // Send done event (use snake_case to match iOS client decoder)
              const doneEvent = `data: ${JSON.stringify({
                type: 'done',
                message_id: assistantMessageId,
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

// Note: System prompt building moved to _shared/prompt-builder.ts (Story 2.4)
// Domain routing will be added in Story 3.1
