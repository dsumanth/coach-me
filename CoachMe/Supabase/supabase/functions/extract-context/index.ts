/**
 * extract-context Edge Function
 * Story 2.3: Progressive Context Extraction
 *
 * Analyzes conversation messages to extract values, goals, and situation mentions.
 * Uses Claude Haiku for cost efficiency (extraction is not user-facing).
 * Returns insights with confidence scores, filtering >= 0.7.
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { handleCors, corsHeaders } from '../_shared/cors.ts';
import { verifyAuth, AuthorizationError } from '../_shared/auth.ts';
import { errorResponse } from '../_shared/response.ts';
import { calculateCost } from '../_shared/llm-client.ts';
import { logUsage } from '../_shared/cost-tracker.ts';

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

    // Call Anthropic API (non-streaming for extraction)
    const apiKey = Deno.env.get('ANTHROPIC_API_KEY');
    if (!apiKey) {
      return errorResponse('LLM service not configured', 500);
    }

    const model = 'claude-haiku-4-5-20251001'; // Cost-efficient for extraction

    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model,
        max_tokens: 1024,
        temperature: 0.3, // Lower temperature for consistent extraction
        system: EXTRACTION_SYSTEM_PROMPT,
        messages: [
          {
            role: 'user',
            content: `Analyze this conversation and extract any context about the user's values, goals, or life situation:\n\n${conversationText}`,
          },
        ],
      }),
    });

    if (!response.ok) {
      const error = await response.text();
      console.error('Anthropic API error:', error);
      return errorResponse('Failed to analyze conversation', 500);
    }

    const llmResponse = await response.json();
    const responseText = llmResponse.content?.[0]?.text ?? '{"insights":[]}';

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
    const usage = llmResponse.usage ?? { input_tokens: 0, output_tokens: 0 };
    const cost = calculateCost(
      { prompt_tokens: usage.input_tokens, completion_tokens: usage.output_tokens },
      model
    );

    await logUsage(supabase, {
      userId,
      conversationId: conversation_id,
      messageId: crypto.randomUUID(), // Extraction doesn't have a message ID
      model,
      promptTokens: usage.input_tokens,
      completionTokens: usage.output_tokens,
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
