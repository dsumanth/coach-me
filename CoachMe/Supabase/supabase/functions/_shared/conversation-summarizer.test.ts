/**
 * conversation-summarizer.ts Tests
 * Story 3.3: Cross-Session Memory References
 *
 * Run with: deno test --allow-read --allow-env conversation-summarizer.test.ts
 */

import {
  assertEquals,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts';

import { summarizeConversation } from './conversation-summarizer.ts';

// MARK: - summarizeConversation Tests

Deno.test('summarizeConversation - creates summary from user+assistant messages', () => {
  const messages = [
    { role: 'user', content: 'I want to talk about my upcoming promotion interview' },
    { role: 'assistant', content: 'That sounds exciting! Let me help you prepare for it.' },
    { role: 'user', content: 'I feel nervous about salary negotiation' },
  ];

  const result = summarizeConversation(messages);

  // Should produce a non-empty summary
  assertEquals(result.length > 0, true);
  assertEquals(result.length <= 80, true);
});

Deno.test('summarizeConversation - includes domain label when provided', () => {
  const messages = [
    { role: 'user', content: 'How do I handle my team conflicts?' },
    { role: 'assistant', content: 'Let me help you navigate that.' },
  ];

  const result = summarizeConversation(messages, 'Team dynamics', 'career');

  assertEquals(result.includes('Career'), true);
});

Deno.test('summarizeConversation - handles empty messages array', () => {
  const result = summarizeConversation([]);

  assertEquals(result.length > 0, true);
  assertEquals(result.length <= 80, true);
});

Deno.test('summarizeConversation - handles single message', () => {
  const messages = [
    { role: 'user', content: 'I want to improve my work-life balance' },
  ];

  const result = summarizeConversation(messages);

  assertEquals(result.length > 0, true);
  assertEquals(result.length <= 80, true);
});

Deno.test('summarizeConversation - truncates long summaries to ~80 chars', () => {
  const messages = [
    { role: 'user', content: 'I have been thinking about a really long and complex topic involving multiple aspects of my life including career, relationships, health, and personal growth all at once' },
    { role: 'assistant', content: 'That is a lot to process. Let us break it down into manageable pieces and explore each area.' },
  ];

  const result = summarizeConversation(messages);

  assertEquals(result.length <= 80, true);
});

Deno.test('summarizeConversation - handles messages with only system role', () => {
  const messages = [
    { role: 'system', content: 'You are a helpful coach.' },
  ];

  const result = summarizeConversation(messages);

  assertEquals(result.length > 0, true);
  assertEquals(result.length <= 80, true);
});

Deno.test('summarizeConversation - uses title when available and no user messages', () => {
  const messages = [
    { role: 'system', content: 'System prompt here' },
  ];

  const result = summarizeConversation(messages, 'Career planning session');

  assertEquals(result.includes('Career planning session'), true);
});

Deno.test('summarizeConversation - extracts topic from last user message', () => {
  // Messages ordered newest-first to match DB ordering
  const messages = [
    { role: 'user', content: 'I struggle with managing stress at work' },
    { role: 'assistant', content: 'Meditation is a wonderful practice.' },
    { role: 'user', content: 'Tell me about meditation' },
  ];

  const result = summarizeConversation(messages);

  // Should reference the last user message topic
  assertEquals(result.includes('stress') || result.includes('work'), true);
});
