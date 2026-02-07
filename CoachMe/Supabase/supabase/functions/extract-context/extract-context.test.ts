/**
 * extract-context Edge Function Tests
 * Story 2.3: Progressive Context Extraction
 *
 * Run with: deno test --allow-env extract-context.test.ts
 */

import { assertEquals, assertExists } from 'https://deno.land/std@0.168.0/testing/asserts.ts';

// Test types matching the Edge Function
interface ExtractedInsight {
  id: string;
  content: string;
  category: 'value' | 'goal' | 'situation';
  confidence: number;
  source_conversation_id: string;
  confirmed: boolean;
  extracted_at: string;
}

// Extraction logic extracted for testing
function parseAndFilterInsights(
  responseText: string,
  conversationId: string
): ExtractedInsight[] {
  let parsedInsights: { content: string; category: string; confidence: number }[] = [];

  try {
    const parsed = JSON.parse(responseText);
    parsedInsights = parsed.insights ?? [];
  } catch {
    return [];
  }

  const now = new Date().toISOString();
  return parsedInsights
    .filter(i => i.confidence >= 0.7)
    .filter(i => ['value', 'goal', 'situation'].includes(i.category))
    .map(i => ({
      id: crypto.randomUUID(),
      content: i.content,
      category: i.category as 'value' | 'goal' | 'situation',
      confidence: i.confidence,
      source_conversation_id: conversationId,
      confirmed: false,
      extracted_at: now,
    }));
}

// Test: Parse valid LLM response
Deno.test('parseAndFilterInsights - parses valid response', () => {
  const response = JSON.stringify({
    insights: [
      { content: 'values honesty', category: 'value', confidence: 0.85 },
      { content: 'career change', category: 'goal', confidence: 0.9 },
    ],
  });

  const result = parseAndFilterInsights(response, 'test-conv-id');

  assertEquals(result.length, 2);
  assertEquals(result[0].content, 'values honesty');
  assertEquals(result[0].category, 'value');
  assertEquals(result[0].confidence, 0.85);
  assertEquals(result[0].confirmed, false);
  assertEquals(result[0].source_conversation_id, 'test-conv-id');
  assertExists(result[0].id);
  assertExists(result[0].extracted_at);
});

// Test: Filters low confidence insights
Deno.test('parseAndFilterInsights - filters low confidence', () => {
  const response = JSON.stringify({
    insights: [
      { content: 'high confidence', category: 'value', confidence: 0.85 },
      { content: 'low confidence', category: 'goal', confidence: 0.5 },
      { content: 'borderline', category: 'situation', confidence: 0.7 },
    ],
  });

  const result = parseAndFilterInsights(response, 'test-conv-id');

  assertEquals(result.length, 2);
  assertEquals(result[0].content, 'high confidence');
  assertEquals(result[1].content, 'borderline');
});

// Test: Filters invalid categories
Deno.test('parseAndFilterInsights - filters invalid categories', () => {
  const response = JSON.stringify({
    insights: [
      { content: 'valid value', category: 'value', confidence: 0.9 },
      { content: 'invalid category', category: 'invalid', confidence: 0.95 },
      { content: 'pattern type', category: 'pattern', confidence: 0.8 },
    ],
  });

  const result = parseAndFilterInsights(response, 'test-conv-id');

  assertEquals(result.length, 1);
  assertEquals(result[0].content, 'valid value');
});

// Test: Handles empty insights array
Deno.test('parseAndFilterInsights - handles empty insights', () => {
  const response = JSON.stringify({ insights: [] });

  const result = parseAndFilterInsights(response, 'test-conv-id');

  assertEquals(result.length, 0);
});

// Test: Handles malformed JSON
Deno.test('parseAndFilterInsights - handles malformed JSON', () => {
  const response = 'not valid json {';

  const result = parseAndFilterInsights(response, 'test-conv-id');

  assertEquals(result.length, 0);
});

// Test: Handles missing insights field
Deno.test('parseAndFilterInsights - handles missing insights field', () => {
  const response = JSON.stringify({ other: 'data' });

  const result = parseAndFilterInsights(response, 'test-conv-id');

  assertEquals(result.length, 0);
});

// Test: All insights set confirmed to false
Deno.test('parseAndFilterInsights - all insights unconfirmed', () => {
  const response = JSON.stringify({
    insights: [
      { content: 'test1', category: 'value', confidence: 0.9 },
      { content: 'test2', category: 'goal', confidence: 0.8 },
    ],
  });

  const result = parseAndFilterInsights(response, 'test-conv-id');

  result.forEach(insight => {
    assertEquals(insight.confirmed, false);
  });
});

// Test: Each insight gets unique ID
Deno.test('parseAndFilterInsights - unique IDs', () => {
  const response = JSON.stringify({
    insights: [
      { content: 'test1', category: 'value', confidence: 0.9 },
      { content: 'test2', category: 'goal', confidence: 0.8 },
    ],
  });

  const result = parseAndFilterInsights(response, 'test-conv-id');

  const ids = result.map(i => i.id);
  const uniqueIds = new Set(ids);
  assertEquals(uniqueIds.size, ids.length);
});

// Test: Prompt construction (validates conversation format)
Deno.test('conversation text formatting', () => {
  const messages = [
    { role: 'user' as const, content: 'I value honesty above all else.' },
    { role: 'assistant' as const, content: 'That\'s wonderful to hear.' },
  ];

  const conversationText = messages
    .map(m => `${m.role.toUpperCase()}: ${m.content}`)
    .join('\n\n');

  assertEquals(
    conversationText,
    'USER: I value honesty above all else.\n\nASSISTANT: That\'s wonderful to hear.'
  );
});
