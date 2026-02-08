import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { handleCors } from '../_shared/cors.ts';
import { verifyAuth, AuthorizationError } from '../_shared/auth.ts';
import { errorResponse, sseHeaders } from '../_shared/response.ts';
import { streamChatCompletion, calculateCost, type ChatMessage } from '../_shared/llm-client.ts';
import { logUsage } from '../_shared/cost-tracker.ts';
import { loadUserContext, loadRelevantHistory } from '../_shared/context-loader.ts';
import { buildCoachingPrompt, hasMemoryMoments, hasPatternInsights } from '../_shared/prompt-builder.ts';
import { determineDomain } from '../_shared/domain-router.ts';
import { detectCrossDomainPatterns, filterByRateLimit } from '../_shared/pattern-synthesizer.ts';
import type { CoachingDomain } from '../_shared/prompt-builder.ts';

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
    // Story 3.1: Also select domain for routing continuity
    const { data: conversation, error: convError } = await supabase
      .from('conversations')
      .select('id, domain')
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

    // Story 2.4 + 3.3 + 3.5: Load user context, history, and cross-domain patterns in parallel
    // Target <200ms combined per architecture NFR
    // Story 3.5: Pattern detection runs in parallel (not on critical path)
    const [userContext, conversationHistory, patternResult] = await Promise.all([
      loadUserContext(supabase, userId),
      loadRelevantHistory(supabase, userId, conversationId),
      detectCrossDomainPatterns(userId, supabase),
    ]);

    // Load conversation history for context (most recent 20 messages)
    // Fetch newest first, then reverse to chronological order
    const { data: rawHistory } = await supabase
      .from('messages')
      .select('role, content')
      .eq('conversation_id', conversationId)
      .order('created_at', { ascending: false })
      .limit(20);

    // Filter empty messages, reverse to chronological, and ensure alternating roles
    // (Previous blank responses left orphaned user messages in DB)
    const filtered = (rawHistory ?? [])
      .reverse()
      .filter((m: { role: string; content: string }) => m.content?.trim());

    // Enforce alternating user/assistant roles for Anthropic API compliance
    const historyMessages: { role: string; content: string }[] = [];
    for (const m of filtered) {
      const lastRole = historyMessages.length > 0
        ? historyMessages[historyMessages.length - 1].role
        : null;
      if (m.role === lastRole) {
        // Consecutive same role: merge content (keeps most recent context)
        historyMessages[historyMessages.length - 1] = {
          role: m.role,
          content: historyMessages[historyMessages.length - 1].content + '\n\n' + m.content,
        };
      } else {
        historyMessages.push({ role: m.role, content: m.content });
      }
    }

    // Story 3.1: Determine coaching domain (target <100ms)
    const currentDomain = (conversation as { id: string; domain: string | null }).domain as CoachingDomain | null;
    const recentForRouting = historyMessages
      .slice(-3)
      .map((m) => ({ role: m.role, content: m.content }));

    const domainResult = await determineDomain(message, {
      currentDomain,
      recentMessages: recentForRouting,
    });

    // Story 3.1: Update conversation domain in DB (async, non-blocking) (AC #4)
    if (domainResult.domain !== currentDomain) {
      supabase
        .from('conversations')
        .update({ domain: domainResult.domain })
        .eq('id', conversationId)
        .then(({ error: domainErr }: { error: unknown }) => {
          if (domainErr) console.error('Domain update failed:', domainErr);
        });
    }

    // Story 3.5: Apply rate limiting to cross-domain patterns (AC #4)
    // Max 1 per session, minimum 3-session gap for same theme
    const eligiblePatterns = await filterByRateLimit(
      userId,
      patternResult.patterns,
      supabase,
    );

    // Story 3.1 + 3.3 + 3.5: Build context-aware, domain-specific system prompt
    const systemPrompt = buildCoachingPrompt(
      userContext,
      domainResult.domain,
      domainResult.shouldClarify,
      conversationHistory.conversations,
      eligiblePatterns,
    );
    const messages: ChatMessage[] = [
      { role: 'system', content: systemPrompt },
      ...historyMessages.map((m) => ({
        role: m.role as 'user' | 'assistant',
        content: m.content,
      })),
    ];

    // AC2: Stream response via SSE
    const assistantMessageId = crypto.randomUUID();
    let fullContent = '';
    let memoryMomentFound = false;
    let patternInsightFound = false;  // Story 3.4: Track pattern insight detection
    let tokenUsage = { prompt_tokens: 0, completion_tokens: 0, total_tokens: 0 };
    const model = 'claude-haiku-4-5-20251001';

    const stream = new ReadableStream({
      async start(controller) {
        const encoder = new TextEncoder();

        try {
          for await (const chunk of streamChatCompletion(messages, { model })) {
            if (chunk.type === 'token' && chunk.content) {
              fullContent += chunk.content;
              // Story 2.4: Detect memory moments in streamed content (AC #4)
              // Short-circuit: skip scanning once a memory moment is found
              if (!memoryMomentFound) {
                memoryMomentFound = hasMemoryMoments(fullContent);
              }
              // Story 3.4: Detect pattern insights in streamed content
              // Short-circuit: skip scanning once a pattern insight is found
              if (!patternInsightFound) {
                patternInsightFound = hasPatternInsights(fullContent);
              }
              // Send SSE event with memory_moment and pattern_insight flags
              const event = `data: ${JSON.stringify({
                type: 'token',
                content: chunk.content,
                memory_moment: memoryMomentFound,
                pattern_insight: patternInsightFound,
              })}\n\n`;
              controller.enqueue(encoder.encode(event));
            }

            if (chunk.type === 'done' && chunk.usage) {
              tokenUsage = chunk.usage;

              // Don't save empty responses to DB — prevents poisoning future history
              if (!fullContent.trim()) {
                console.warn('Empty LLM response, skipping DB save');
                const errorEvent = `data: ${JSON.stringify({
                  type: 'error',
                  message: "Coach's response was empty. Let's try again."
                })}\n\n`;
                controller.enqueue(encoder.encode(errorEvent));
                controller.close();
                return;
              }

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
              // Story 3.1: Include domain in metadata for future history view badges
              const doneEvent = `data: ${JSON.stringify({
                type: 'done',
                message_id: assistantMessageId,
                usage: tokenUsage,
                domain: domainResult.domain,
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
    if (error instanceof AuthorizationError) {
      return errorResponse((error as Error).message, 401);
    }
    // Don't leak internal error details for 500s
    return errorResponse('An unexpected error occurred', 500);
  }
});

// Note: System prompt building moved to _shared/prompt-builder.ts (Story 2.4)
// Domain routing added in Story 3.1 via _shared/domain-router.ts
// Cross-domain pattern synthesis added in Story 3.5 via _shared/pattern-synthesizer.ts
