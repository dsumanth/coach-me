/**
 * commitment-reminders.ts
 *
 * Detects actionable user commitments and builds scheduled reminder drafts.
 * Used by chat-stream to queue proactive coach check-ins.
 */

export interface CommitmentReminderDraft {
  reminderType: 'commitment_checkin';
  title: string;
  body: string;
  remindAt: string;
  metadata: Record<string, unknown>;
}

interface ResolvedReminderTime {
  remindAt: Date;
  cue: string;
}

const COMMITMENT_REGEX = /\b(i(?:'m| am)?\s+(?:going to|gonna|will|plan to|intend to|need to|want to|have to)|i['’]ll)\b/i;
const FIRST_PERSON_REGEX = /\b(i|i'm|im|i['’]ll|i am)\b/i;

/**
 * Build a scheduled reminder draft when a user message includes both:
 * 1) a concrete temporal cue and
 * 2) commitment intent.
 */
export function buildCommitmentReminderDraft(
  message: string,
  now: Date = new Date(),
): CommitmentReminderDraft | null {
  const normalized = normalize(message);
  if (!normalized) return null;

  const resolved = resolveReminderTime(normalized, now);
  if (!resolved) return null;

  const hasCommitmentLanguage =
    COMMITMENT_REGEX.test(normalized) ||
    (FIRST_PERSON_REGEX.test(normalized) && containsActionVerb(normalized));

  if (!hasCommitmentLanguage) return null;

  const action = extractActionSummary(normalized);
  const safeAction = action.length > 0 ? action : 'your plan';

  return {
    reminderType: 'commitment_checkin',
    title: 'Coach check-in',
    body: truncate(`Quick check-in on ${safeAction}: how did it go?`, 180),
    remindAt: resolved.remindAt.toISOString(),
    metadata: {
      cue: resolved.cue,
      action: safeAction,
      source_preview: truncate(normalized, 160),
    },
  };
}

function normalize(input: string): string {
  return input.replace(/\s+/g, ' ').trim();
}

function resolveReminderTime(text: string, now: Date): ResolvedReminderTime | null {
  const lower = text.toLowerCase();
  const explicitTime = resolveExplicitClockTime(lower, now);
  if (explicitTime) return explicitTime;

  if (/\bafter lunch\b/.test(lower)) {
    return { remindAt: nextOccurrence(now, 13, 30), cue: 'after_lunch' };
  }
  if (/\bafter dinner\b/.test(lower)) {
    return { remindAt: nextOccurrence(now, 20, 0), cue: 'after_dinner' };
  }
  if (/\btonight\b|\bthis evening\b/.test(lower)) {
    return { remindAt: nextOccurrence(now, 20, 0), cue: 'tonight' };
  }
  if (/\bthis afternoon\b/.test(lower)) {
    return { remindAt: nextOccurrence(now, 15, 0), cue: 'this_afternoon' };
  }
  if (/\btomorrow\b/.test(lower)) {
    return { remindAt: tomorrowAt(now, 9, 0), cue: 'tomorrow' };
  }
  if (/\btoday\b/.test(lower)) {
    return { remindAt: todayOrTomorrow(now, 18, 0), cue: 'today' };
  }

  return null;
}

function resolveExplicitClockTime(text: string, now: Date): ResolvedReminderTime | null {
  const match = text.match(/\b(?:at|around)\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\b/i);
  if (!match) return null;

  let hour = parseInt(match[1], 10);
  const minute = match[2] ? parseInt(match[2], 10) : 0;
  const meridiem = match[3]?.toLowerCase() ?? null;
  if (!Number.isFinite(hour) || !Number.isFinite(minute) || hour < 1 || hour > 12 || minute < 0 || minute > 59) {
    return null;
  }

  if (meridiem === 'am') {
    hour = hour % 12;
  } else if (meridiem === 'pm') {
    hour = (hour % 12) + 12;
  } else if (hour <= 7) {
    // Ambiguous "at 6" usually means evening in casual commitments.
    hour += 12;
  }

  const hasTomorrow = /\btomorrow\b/.test(text);
  const target = new Date(now);
  if (hasTomorrow) target.setDate(target.getDate() + 1);
  target.setHours(hour, minute, 0, 0);

  if (!hasTomorrow && target.getTime() <= now.getTime() + 15 * 60 * 1000) {
    target.setDate(target.getDate() + 1);
  }

  return { remindAt: target, cue: hasTomorrow ? 'tomorrow_at_time' : 'at_time' };
}

function nextOccurrence(now: Date, hour: number, minute: number): Date {
  const target = new Date(now);
  target.setHours(hour, minute, 0, 0);
  if (target.getTime() <= now.getTime()) {
    target.setDate(target.getDate() + 1);
  }
  return target;
}

function tomorrowAt(now: Date, hour: number, minute: number): Date {
  const target = new Date(now);
  target.setDate(target.getDate() + 1);
  target.setHours(hour, minute, 0, 0);
  return target;
}

function todayOrTomorrow(now: Date, fallbackHour: number, fallbackMinute: number): Date {
  const target = new Date(now);
  target.setHours(fallbackHour, fallbackMinute, 0, 0);
  if (target.getTime() <= now.getTime() + 30 * 60 * 1000) {
    target.setDate(target.getDate() + 1);
  }
  return target;
}

function containsActionVerb(text: string): boolean {
  return /\b(walk|run|work\s?out|exercise|stretch|meditate|journal|study|practice|call|text|sleep|eat|drink|start|finish|do|go)\b/i
    .test(text);
}

function extractActionSummary(text: string): string {
  let cleaned = text;
  cleaned = cleaned.replace(/\b(i(?:'m| am)?\s+(?:going to|gonna|will|plan to|intend to|need to|want to|have to)|i['’]ll)\b/gi, '');
  cleaned = cleaned.replace(/\b(today|tomorrow|tonight|this evening|this afternoon|after lunch|after dinner)\b/gi, '');
  cleaned = cleaned.replace(/\b(?:at|around)\s+\d{1,2}(?::\d{2})?\s*(?:am|pm)?\b/gi, '');
  cleaned = cleaned.replace(/\s+/g, ' ').trim();

  if (!cleaned) return '';

  const sentence = cleaned.split(/[.!?]/)[0]?.trim() ?? '';
  return truncate(sentence, 72);
}

function truncate(text: string, maxLength: number): string {
  if (text.length <= maxLength) return text;
  return `${text.slice(0, maxLength - 1).trimEnd()}…`;
}
