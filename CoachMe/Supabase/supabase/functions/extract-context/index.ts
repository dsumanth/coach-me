/**
 * extract-context Edge Function
 * Story 2.3: Progressive Context Extraction
 *
 * Analyzes conversation messages to extract values, goals, and situation mentions.
 * Uses a low-cost background model for extraction (not user-facing).
 * Returns insights with confidence scores, filtering >= 0.7.
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { handleCors, corsHeaders } from '../_shared/cors.ts';
import { verifyAuth, AuthorizationError } from '../_shared/auth.ts';
import { errorResponse } from '../_shared/response.ts';
import { streamChatCompletion, calculateCost, type ChatMessage } from '../_shared/llm-client.ts';
import { logUsage } from '../_shared/cost-tracker.ts';
import { selectBackgroundModel, enforceInputTokenBudget } from '../_shared/model-routing.ts';

// Request types
interface ExtractRequest {
  conversation_id: string;
  messages: Array<{
    role: 'user' | 'assistant';
    content: string;
  }>;
}

// Response types
interface ExtractedInsight {
  id: string;
  content: string;
  category: 'value' | 'goal' | 'situation';
  confidence: number;
  source_conversation_id: string;
  confirmed: boolean;
  extracted_at: string;
}

interface ExtractResponse {
  insights: ExtractedInsight[];
}

// Extraction prompt - focuses on explicit mentions only
const EXTRACTION_SYSTEM_PROMPT = `You are a context extraction assistant for a personal coaching app. Analyze the conversation and identify:

1. VALUES: Things the user considers important (honesty, family, growth, creativity, independence, etc.)
2. GOALS: Things the user is working toward (career change, better health, learning a skill, improving relationships, etc.)
3. SITUATION: Life circumstances mentioned (parent, student, career stage, location, relationship status, etc.)

CRITICAL RULES:
- Only extract CLEAR, EXPLICIT mentions. Do not infer or assume.
- The user must have directly stated or clearly implied the information.
- Each insight should be a brief, factual statement (not a full sentence).
- Assign confidence scores (0.0-1.0) based on how explicit the mention was.
- Only include insights with confidence >= 0.7.
- Return empty array if no clear context is found.
- Keep insights concise (under 50 characters when possible).

Response format (JSON only, no markdown):
{
  "insights": [
    { "content": "values honesty", "category": "value", "confidence": 0.85 },
    { "content": "working toward career change", "category": "goal", "confidence": 0.9 },
    { "content": "parent of two children", "category": "situation", "confidence": 0.95 }
  ]
}

If no insights found, return: { "insights": [] }`;

serve(async (req: Request) => {
  // Handle CORS preflight
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    // Verify auth and extract user ID
    const { userId, supabase } = await verifyAuth(req);

    // Parse request body
    const body: ExtractRequest = await req.json();
    const { conversation_id, messages } = body;

    if (!conversation_id || !messages?.length) {
      return errorResponse('Missing conversation_id or messages', 400);
    }

    // Build message content for extraction
    const conversationText = messages
      .map(m => `${m.role.toUpperCase()}: ${m.content}`)
      .join('\n\n');

    // Background extraction model routing
    if (!Deno.env.get('OPENAI_API_KEY')) {
      return errorResponse('LLM service not configured', 500);
    }

    const modelSelection = selectBackgroundModel('context_extraction');
    const llmMessages: ChatMessage[] = [
      { role: 'system', content: EXTRACTION_SYSTEM_PROMPT },
      {
        role: 'user',
        content: `Analyze this conversation and extract any context about the user's values, goals, or life situation:\n\n${conversationText}`,
      },
    ];
    const budgetedMessages = enforceInputTokenBudget(llmMessages, modelSelection.inputBudgetTokens);

    let responseText = '';
    let usage = { prompt_tokens: 0, completion_tokens: 0, total_tokens: 0 };
    for await (const chunk of streamChatCompletion(budgetedMessages, {
      provider: modelSelection.provider,
      model: modelSelection.model,
      maxTokens: modelSelection.maxOutputTokens,
      temperature: modelSelection.temperature,
    })) {
      if (chunk.type === 'token' && chunk.content) {
        responseText += chunk.content;
      }
      if (chunk.type === 'done' && chunk.usage) {
        usage = chunk.usage;
      }
      if (chunk.type === 'error') {
        console.error('extract-context LLM error:', chunk.error);
        return errorResponse('Failed to analyze conversation', 500);
      }
    }

    if (!responseText.trim()) {
      responseText = '{"insights":[]}';
    }

    // Parse LLM response
    let parsedInsights: { content: string; category: string; confidence: number }[] = [];
    try {
      const parsed = JSON.parse(responseText);
      parsedInsights = parsed.insights ?? [];
    } catch (parseError) {
      console.error('Failed to parse LLM response:', responseText);
      // Return empty insights on parse failure (graceful degradation)
      parsedInsights = [];
    }

    // Filter and transform insights
    const now = new Date().toISOString();
    const insights: ExtractedInsight[] = parsedInsights
      .filter(i => i.confidence >= 0.7)
      .filter(i => ['value', 'goal', 'situation'].includes(i.category))
      .map(i => ({
        id: crypto.randomUUID(),
        content: i.content,
        category: i.category as 'value' | 'goal' | 'situation',
        confidence: i.confidence,
        source_conversation_id: conversation_id,
        confirmed: false,
        extracted_at: now,
      }));

    // Log usage for cost tracking
    const cost = calculateCost(
      { prompt_tokens: usage.prompt_tokens, completion_tokens: usage.completion_tokens },
      modelSelection.model,
    );

    await logUsage(supabase, {
      userId,
      conversationId: conversation_id,
      messageId: null, // Extraction has no associated message row
      model: modelSelection.model,
      promptTokens: usage.prompt_tokens,
      completionTokens: usage.completion_tokens,
      costUsd: cost,
    });

    // Return extracted insights
    const responseBody: ExtractResponse = { insights };
    return new Response(JSON.stringify(responseBody), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (error) {
    console.error('extract-context error:', error);

    if (error instanceof AuthorizationError) {
      return errorResponse('Not authorized', 401);
    }

    return errorResponse('Failed to extract context', 500);
  }
});
