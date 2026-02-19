import { assertEquals, assertExists } from 'https://deno.land/std@0.208.0/assert/mod.ts';
import { buildCommitmentReminderDraft } from './commitment-reminders.ts';

Deno.test('buildCommitmentReminderDraft - builds reminder for after lunch commitment', () => {
  const now = new Date('2026-02-18T10:00:00Z');
  const draft = buildCommitmentReminderDraft("I'll do a 5-minute walk after lunch.", now);

  assertExists(draft);
  assertEquals(draft.reminderType, 'commitment_checkin');
  assertEquals(draft.title, 'Coach check-in');
  assertEquals(draft.remindAt.startsWith('2026-02-18T13:30:00'), true);
});

Deno.test('buildCommitmentReminderDraft - uses tomorrow when explicitly stated', () => {
  const now = new Date('2026-02-18T22:00:00Z');
  const draft = buildCommitmentReminderDraft('I will journal tomorrow morning.', now);

  assertExists(draft);
  assertEquals(draft.remindAt.startsWith('2026-02-19T09:00:00'), true);
});

Deno.test('buildCommitmentReminderDraft - returns null without commitment language', () => {
  const now = new Date('2026-02-18T10:00:00Z');
  const draft = buildCommitmentReminderDraft('After lunch sounds hard lately.', now);

  assertEquals(draft, null);
});
