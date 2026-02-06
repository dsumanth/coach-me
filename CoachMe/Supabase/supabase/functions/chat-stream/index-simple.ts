import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const sseHeaders = {
  ...corsHeaders,
  'Content-Type': 'text/event-stream',
  'Cache-Control': 'no-cache',
  'Connection': 'keep-alive',
};

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Auth
    const authHeader = req.headers.get('Authorization');
    if (!authHeader?.startsWith('Bearer ')) {
      return new Response(JSON.stringify({ error: 'Missing authorization' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
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

    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Invalid token' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const userId = user.id;

    // Parse body
    const { message, conversationId } = await req.json();
    if (!message?.trim() || !conversationId) {
      return new Response(JSON.stringify({ error: 'Missing message or conversationId' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Save user message
    const userMessageId = crypto.randomUUID();
    await supabase.from('messages').insert({
      id: userMessageId,
      conversation_id: conversationId,
      role: 'user',
      content: message,
      user_id: userId,
    });

    // Load history
    const { data: history } = await supabase
      .from('messages')
      .select('role, content')
      .eq('conversation_id', conversationId)
      .order('created_at', { ascending: true })
      .limit(20);

    const systemPrompt = `You are a warm, supportive life coach. Help users reflect and take action.
- Be empathetic and non-judgmental
- Ask thoughtful questions
- Never diagnose or prescribe
- If crisis indicators appear, encourage professional help`;

    const messages = [
      { role: 'system', content: systemPrompt },
      ...(history ?? []).map((m: { role: string; content: string }) => ({
        role: m.role,
        content: m.content,
      })),
    ];

    // Call Anthropic
    const apiKey = Deno.env.get('ANTHROPIC_API_KEY');
    if (!apiKey) {
      return new Response(JSON.stringify({ error: 'API key not configured' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const anthropicResponse = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: 'claude-sonnet-4-20250514',
        max_tokens: 4096,
        temperature: 0.7,
        system: systemPrompt,
        messages: messages.filter(m => m.role !== 'system'),
        stream: true,
      }),
    });

    if (!anthropicResponse.ok) {
      const err = await anthropicResponse.text();
      console.error('Anthropic error:', err);
      return new Response(JSON.stringify({ error: 'LLM error' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const assistantMessageId = crypto.randomUUID();
    let fullContent = '';
    let promptTokens = 0;
    let completionTokens = 0;

    const stream = new ReadableStream({
      async start(controller) {
        const encoder = new TextEncoder();
        const reader = anthropicResponse.body!.getReader();
        const decoder = new TextDecoder();
        let buffer = '';

        try {
          while (true) {
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
                  fullContent += event.delta.text;
                  controller.enqueue(encoder.encode(
                    `data: ${JSON.stringify({ type: 'token', content: event.delta.text })}\n\n`
                  ));
                }

                if (event.type === 'message_start' && event.message?.usage) {
                  promptTokens = event.message.usage.input_tokens ?? 0;
                }

                if (event.type === 'message_delta' && event.usage) {
                  completionTokens = event.usage.output_tokens ?? 0;
                }
              } catch {
                // Skip
              }
            }
          }

          // Save assistant message
          await supabase.from('messages').insert({
            id: assistantMessageId,
            conversation_id: conversationId,
            role: 'assistant',
            content: fullContent,
            user_id: userId,
            token_count: completionTokens,
          });

          // Log usage
          const costUsd = (promptTokens / 1_000_000) * 3.0 + (completionTokens / 1_000_000) * 15.0;
          await supabase.from('usage_logs').insert({
            user_id: userId,
            conversation_id: conversationId,
            message_id: assistantMessageId,
            model: 'claude-sonnet-4-20250514',
            tokens_in: promptTokens,
            tokens_out: completionTokens,
            cost_usd: costUsd,
          });

          controller.enqueue(encoder.encode(
            `data: ${JSON.stringify({ type: 'done', messageId: assistantMessageId })}\n\n`
          ));
        } catch (e) {
          console.error('Stream error:', e);
          controller.enqueue(encoder.encode(
            `data: ${JSON.stringify({ type: 'error', message: "Coach is taking a moment." })}\n\n`
          ));
        } finally {
          controller.close();
        }
      },
    });

    return new Response(stream, { headers: sseHeaders });

  } catch (e) {
    console.error('Error:', e);
    return new Response(JSON.stringify({ error: "Coach is taking a moment." }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
