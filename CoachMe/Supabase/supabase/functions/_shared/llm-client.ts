/**
 * Provider-agnostic LLM client
 * Per architecture.md: NFR31 requires provider-agnostic integration
 * Supports streaming responses via AsyncIterableIterator
 */

export interface ChatMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

export interface StreamChunk {
  type: 'token' | 'done' | 'error';
  content?: string;
  usage?: {
    prompt_tokens: number;
    completion_tokens: number;
    total_tokens: number;
  };
  error?: string;
}

export interface LLMConfig {
  provider: 'anthropic' | 'openai';
  model: string;
  maxTokens: number;
  temperature?: number;
}

const DEFAULT_CONFIG: LLMConfig = {
  provider: 'anthropic',
  model: 'claude-sonnet-4-20250514',
  maxTokens: 4096,
  temperature: 0.7,
};

/**
 * Stream chat completion from LLM provider
 * Returns async iterator yielding StreamChunks
 */
export async function* streamChatCompletion(
  messages: ChatMessage[],
  config: Partial<LLMConfig> = {}
): AsyncGenerator<StreamChunk> {
  const finalConfig = { ...DEFAULT_CONFIG, ...config };

  const startTime = Date.now();
  const timeout = 30000; // 30 second timeout

  try {
    if (finalConfig.provider === 'anthropic') {
      yield* streamAnthropic(messages, finalConfig, startTime, timeout);
    } else if (finalConfig.provider === 'openai') {
      yield* streamOpenAI(messages, finalConfig, startTime, timeout);
    } else {
      throw new Error(`Unsupported provider: ${finalConfig.provider}`);
    }
  } catch (error) {
    // Per architecture.md: Return graceful error within 3 seconds
    const elapsed = Date.now() - startTime;
    if (elapsed > 3000) {
      console.error(`LLM timeout after ${elapsed}ms:`, error);
    }
    yield { type: 'error', error: (error as Error).message };
  }
}

async function* streamAnthropic(
  messages: ChatMessage[],
  config: LLMConfig,
  startTime: number,
  timeout: number
): AsyncGenerator<StreamChunk> {
  const apiKey = Deno.env.get('ANTHROPIC_API_KEY');
  if (!apiKey) throw new Error('ANTHROPIC_API_KEY not configured');

  // Extract system message
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
      max_tokens: config.maxTokens,
      temperature: config.temperature,
      system: systemMessage,
      messages: conversationMessages,
      stream: true,
    }),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Anthropic API error: ${error}`);
  }

  if (!response.body) throw new Error('No response body');
  const reader = response.body.getReader();

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
}

async function* streamOpenAI(
  messages: ChatMessage[],
  config: LLMConfig,
  startTime: number,
  timeout: number
): AsyncGenerator<StreamChunk> {
  const apiKey = Deno.env.get('OPENAI_API_KEY');
  if (!apiKey) throw new Error('OPENAI_API_KEY not configured');

  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model: config.model,
      max_tokens: config.maxTokens,
      temperature: config.temperature,
      messages,
      stream: true,
      stream_options: { include_usage: true },
    }),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`OpenAI API error: ${error}`);
  }

  if (!response.body) throw new Error('No response body');
  const reader = response.body.getReader();

  const decoder = new TextDecoder();
  let buffer = '';
  let usage = { prompt_tokens: 0, completion_tokens: 0, total_tokens: 0 };

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

        if (event.choices?.[0]?.delta?.content) {
          yield { type: 'token', content: event.choices[0].delta.content };
        }

        if (event.usage) {
          usage = event.usage;
        }
      } catch {
        // Skip malformed JSON
      }
    }
  }

  yield { type: 'done', usage };
}

/**
 * Calculate cost in USD based on token usage
 * Prices as of 2026-02 (update as needed)
 */
export function calculateCost(
  usage: { prompt_tokens: number; completion_tokens: number },
  model: string
): number {
  const pricing: Record<string, { input: number; output: number }> = {
    // Anthropic pricing per 1M tokens
    'claude-sonnet-4-20250514': { input: 3.0, output: 15.0 },
    'claude-opus-4-5-20251101': { input: 15.0, output: 75.0 },
    'claude-haiku-4-5-20251001': { input: 0.25, output: 1.25 },
    // OpenAI pricing per 1M tokens
    'gpt-4o': { input: 2.5, output: 10.0 },
    'gpt-4o-mini': { input: 0.15, output: 0.6 },
  };

  const price = pricing[model] ?? { input: 5.0, output: 15.0 }; // Default fallback

  const inputCost = (usage.prompt_tokens / 1_000_000) * price.input;
  const outputCost = (usage.completion_tokens / 1_000_000) * price.output;

  return inputCost + outputCost;
}
