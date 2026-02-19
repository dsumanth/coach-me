import { assertEquals, assert } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import {
  selectChatModel,
  selectBackgroundModel,
  enforceInputTokenBudget,
} from './model-routing.ts';

Deno.test('selectChatModel - discovery defaults to claude-haiku-4.5 with tighter budget', () => {
  const result = selectChatModel({
    sessionMode: 'discovery',
    message: 'I want to feel more confident speaking up at work.',
    recentUserMessages: [],
    crisisDetected: false,
    crisisConfidence: 0,
  });

  assertEquals(result.model, 'claude-haiku-4-5-20251001');
  assertEquals(result.routeTier, 'primary');
  assertEquals(result.maxOutputTokens, 900);
});

Deno.test('selectChatModel - coaching defaults to claude-haiku-4.5', () => {
  const result = selectChatModel({
    sessionMode: 'coaching',
    message: 'I want to plan my week better and stay consistent.',
    recentUserMessages: ['I feel a bit scattered lately.'],
    crisisDetected: false,
    crisisConfidence: 0.1,
  });

  assertEquals(result.model, 'claude-haiku-4-5-20251001');
  assertEquals(result.routeTier, 'primary');
  assertEquals(result.routeReason, 'primary:coaching_default');
});

Deno.test('selectChatModel - crisis signal escalates to Sonnet', () => {
  const result = selectChatModel({
    sessionMode: 'coaching',
    message: 'I do not want to live anymore.',
    recentUserMessages: ['Everything feels impossible.'],
    crisisDetected: true,
    crisisConfidence: 0.95,
  });

  assertEquals(result.model, 'claude-sonnet-4-5-20250929');
  assertEquals(result.routeTier, 'escalation');
  assert(result.routeReason.includes('crisis_detected'));
});

Deno.test('selectChatModel - high-stakes terms escalate to Sonnet', () => {
  const result = selectChatModel({
    sessionMode: 'coaching',
    message: 'I am overwhelmed after the divorce and this trauma keeps repeating.',
    recentUserMessages: ['I have not been sleeping.'],
    crisisDetected: false,
    crisisConfidence: 0.2,
  });

  assertEquals(result.model, 'claude-sonnet-4-5-20250929');
  assertEquals(result.routeTier, 'escalation');
  assert(result.routeReason.includes('high_stakes'));
});

Deno.test('selectBackgroundModel - context extraction uses gpt-5-nano', () => {
  const result = selectBackgroundModel('context_extraction');
  assertEquals(result.model, 'gpt-5-nano');
  assertEquals(result.routeTier, 'background');
  assertEquals(result.maxOutputTokens, 900);
});

Deno.test('enforceInputTokenBudget - keeps system and latest turns', () => {
  const messages = [
    { role: 'system' as const, content: 'system prompt text' },
    { role: 'user' as const, content: 'old '.repeat(600) },
    { role: 'assistant' as const, content: 'older assistant '.repeat(600) },
    { role: 'user' as const, content: 'latest user message' },
  ];

  const budgeted = enforceInputTokenBudget(messages, 500);
  assertEquals(budgeted[0].role, 'system');
  assertEquals(budgeted[budgeted.length - 1].content, 'latest user message');
  assert(budgeted.length < messages.length);
});

Deno.test('enforceInputTokenBudget - truncates oversized latest turn', () => {
  const messages = [
    { role: 'system' as const, content: 'system prompt text' },
    { role: 'user' as const, content: 'x'.repeat(6000) },
  ];

  const budgeted = enforceInputTokenBudget(messages, 300);
  assertEquals(budgeted.length, 2);
  assert(budgeted[1].content.length < messages[1].content.length);
});
