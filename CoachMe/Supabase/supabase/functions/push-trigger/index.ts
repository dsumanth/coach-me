/**
 * push-trigger Edge Function (Story 8.7)
 *
 * Scheduled daily orchestrator for proactive coaching push notifications.
 * Evaluates eligible users, determines push type, generates personalized
 * content via low-cost background model, and delivers via push-send Edge Function.
 *
 * Auth: Service-role key ONLY (server-to-server, NOT user JWT).
 * Schedule: Daily at 10:00 AM UTC via pg_cron or Supabase scheduled function.
 *
 * Safety: PUSH_TRIGGER_ENABLED env var must be "true" to send pushes.
 */

import { createClient } from "npm:@supabase/supabase-js@2.94.1";
import { handleCors, corsHeaders } from "../_shared/cors.ts";
import { errorResponse } from "../_shared/response.ts";
import { determinePushType, buildPushPrompt, PushDecision } from "../_shared/push-intelligence.ts";
import { loadUserContext, formatContextForPrompt } from "../_shared/context-loader.ts";
import { getStylePreferences, formatStyleInstructions } from "../_shared/style-adapter.ts";
import { streamChatCompletion, calculateCost } from "../_shared/llm-client.ts";
import { logUsage } from "../_shared/cost-tracker.ts";
import { selectBackgroundModel, enforceInputTokenBudget } from "../_shared/model-routing.ts";

// MARK: - Types

interface EligibleUser {
  user_id: string;
  frequency: string;
}

interface PushContent {
  title: string;
  body: string;
}

interface ProcessingResult {
  userId: string;
  status: 'sent' | 'skipped' | 'error';
  pushType?: string;
  error?: string;
}

interface ScheduledReminderRow {
  id: string;
  user_id: string;
  conversation_id: string;
  title: string;
  body: string;
  remind_at: string;
  metadata: Record<string, unknown> | null;
}

interface ScheduledReminderSummary {
  processed: number;
  sent: number;
  skipped: number;
  failed: number;
}

// MARK: - Constants

const BATCH_SIZE_DEFAULT = 50;
const BATCH_DELAY_DEFAULT = 500;
const REMINDER_BATCH_DEFAULT = 200;
const parsedBatchSize = parseInt(Deno.env.get("PUSH_BATCH_SIZE") || "", 10);
const parsedBatchDelay = parseInt(Deno.env.get("PUSH_BATCH_DELAY_MS") || "", 10);
const parsedReminderBatch = parseInt(Deno.env.get("REMINDER_BATCH_SIZE") || "", 10);
const BATCH_SIZE = Number.isFinite(parsedBatchSize) && parsedBatchSize > 0 ? parsedBatchSize : BATCH_SIZE_DEFAULT;
const BATCH_DELAY_MS = Number.isFinite(parsedBatchDelay) && parsedBatchDelay > 0 ? parsedBatchDelay : BATCH_DELAY_DEFAULT;
const REMINDER_BATCH_SIZE = Number.isFinite(parsedReminderBatch) && parsedReminderBatch > 0
  ? parsedReminderBatch
  : REMINDER_BATCH_DEFAULT;
if (!Number.isFinite(parsedBatchSize) && Deno.env.get("PUSH_BATCH_SIZE")) {
  console.warn(`push-trigger: Invalid PUSH_BATCH_SIZE "${Deno.env.get("PUSH_BATCH_SIZE")}", using default ${BATCH_SIZE_DEFAULT}`);
}
if (!Number.isFinite(parsedBatchDelay) && Deno.env.get("PUSH_BATCH_DELAY_MS")) {
  console.warn(`push-trigger: Invalid PUSH_BATCH_DELAY_MS "${Deno.env.get("PUSH_BATCH_DELAY_MS")}", using default ${BATCH_DELAY_DEFAULT}`);
}
if (!Number.isFinite(parsedReminderBatch) && Deno.env.get("REMINDER_BATCH_SIZE")) {
  console.warn(`push-trigger: Invalid REMINDER_BATCH_SIZE "${Deno.env.get("REMINDER_BATCH_SIZE")}", using default ${REMINDER_BATCH_DEFAULT}`);
}
// Frequency interval mapping (in days)
const FREQUENCY_INTERVALS: Record<string, number> = {
  daily: 1,
  few_times_a_week: 2,
  weekly: 7,
};

// MARK: - Main Handler

Deno.serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    // Safety gate: only run when explicitly enabled
    const enabled = Deno.env.get("PUSH_TRIGGER_ENABLED");
    if (enabled !== "true") {
      return new Response(
        JSON.stringify({ success: true, message: "Push trigger is disabled. Set PUSH_TRIGGER_ENABLED=true to enable." }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // Service role auth (NOT user JWT — this is server-to-server)
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceRoleKey) {
      const missing = [
        !supabaseUrl && "SUPABASE_URL",
        !serviceRoleKey && "SUPABASE_SERVICE_ROLE_KEY",
      ].filter(Boolean).join(", ");
      console.error(`push-trigger: Missing required env vars: ${missing}`);
      return new Response(
        JSON.stringify({ error: `Missing configuration: ${missing}` }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }
    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false },
    });

    // Process due coach commitment reminders first (time-sensitive).
    const reminderSummary = await processDueScheduledReminders(supabase, supabaseUrl, serviceRoleKey);

    // Task 4.3: Query eligible users
    const eligibleUsers = await getEligibleUsers(supabase);

    if (eligibleUsers.length === 0) {
      return new Response(
        JSON.stringify({
          success: true,
          processed: 0,
          message: "No eligible users for proactive push notifications.",
          scheduled_reminders: reminderSummary,
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // Task 4.10: Batch processing — sequential within each batch to avoid
    // overwhelming LLM rate limits and Supabase connection pools
    const results: ProcessingResult[] = [];
    for (let i = 0; i < eligibleUsers.length; i += BATCH_SIZE) {
      const batch = eligibleUsers.slice(i, i + BATCH_SIZE);

      for (const user of batch) {
        const result = await processUser(user, supabase, supabaseUrl, serviceRoleKey);
        results.push(result);
      }

      // Delay between batches to prevent resource exhaustion
      // Adaptive backoff: increase delay if errors occurred in this batch
      if (i + BATCH_SIZE < eligibleUsers.length) {
        const batchErrors = results.slice(-batch.length).filter((r) => r.status === 'error').length;
        const delay = batchErrors > 0 ? BATCH_DELAY_MS * Math.min(2 ** batchErrors, 8) : BATCH_DELAY_MS;
        await new Promise((resolve) => setTimeout(resolve, delay));
      }
    }

    // Summary
    const sent = results.filter((r) => r.status === 'sent').length;
    const skipped = results.filter((r) => r.status === 'skipped').length;
    const errors = results.filter((r) => r.status === 'error').length;

    return new Response(
      JSON.stringify({
        success: true,
        processed: results.length,
        sent,
        skipped,
        errors,
        scheduled_reminders: reminderSummary,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (error) {
    console.error("push-trigger fatal error:", error);
    return errorResponse(
      "I couldn't process push notifications right now. Please check the logs.",
      500,
    );
  }
});

// MARK: - Scheduled Reminder Dispatch

async function processDueScheduledReminders(
  supabase: ReturnType<typeof createClient>,
  supabaseUrl: string,
  serviceRoleKey: string,
): Promise<ScheduledReminderSummary> {
  const summary: ScheduledReminderSummary = { processed: 0, sent: 0, skipped: 0, failed: 0 };

  const nowIso = new Date().toISOString();
  const { data, error } = await supabase
    .from('scheduled_reminders')
    .select('id, user_id, conversation_id, title, body, remind_at, metadata')
    .eq('status', 'pending')
    .lte('remind_at', nowIso)
    .order('remind_at', { ascending: true })
    .limit(REMINDER_BATCH_SIZE);

  if (error) {
    console.error('push-trigger: failed loading scheduled reminders:', error);
    return summary;
  }

  const reminders = (data ?? []) as ScheduledReminderRow[];
  if (reminders.length === 0) return summary;

  summary.processed = reminders.length;

  for (const reminder of reminders) {
    const allowed = await checkCheckInsEnabled(reminder.user_id, supabase);
    if (!allowed) {
      summary.skipped += 1;
      await supabase
        .from('scheduled_reminders')
        .update({ status: 'cancelled', last_error: 'check_ins_disabled' })
        .eq('id', reminder.id);
      continue;
    }

    const delivered = await sendScheduledReminderPush(
      reminder,
      supabaseUrl,
      serviceRoleKey,
    );

    if (delivered) {
      summary.sent += 1;
      await supabase
        .from('scheduled_reminders')
        .update({ status: 'sent', sent_at: new Date().toISOString(), last_error: null })
        .eq('id', reminder.id);
    } else {
      summary.failed += 1;
      await supabase
        .from('scheduled_reminders')
        .update({ status: 'failed', last_error: 'push_send_failed' })
        .eq('id', reminder.id);
    }
  }

  return summary;
}

async function checkCheckInsEnabled(
  userId: string,
  supabase: ReturnType<typeof createClient>,
): Promise<boolean> {
  const { data, error } = await supabase
    .from('context_profiles')
    .select('notification_preferences')
    .eq('user_id', userId)
    .single();

  if (error || !data) return true;

  const prefs = (data as { notification_preferences?: Record<string, unknown> | null }).notification_preferences;
  if (!prefs) return true;
  if (prefs.check_ins_enabled === false) return false;
  return true;
}

async function sendScheduledReminderPush(
  reminder: ScheduledReminderRow,
  supabaseUrl: string,
  serviceRoleKey: string,
): Promise<boolean> {
  const pushSendUrl = `${supabaseUrl}/functions/v1/push-send`;
  const timeoutMs = Number.parseInt(Deno.env.get('PUSH_SEND_TIMEOUT_MS') ?? '', 10);
  const effectiveTimeout = Number.isFinite(timeoutMs) && timeoutMs > 0 ? timeoutMs : 10000;
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), effectiveTimeout);

  try {
    const response = await fetch(pushSendUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${serviceRoleKey}`,
      },
      body: JSON.stringify({
        user_id: reminder.user_id,
        title: reminder.title,
        body: reminder.body,
        data: {
          conversation_id: reminder.conversation_id,
          action: 'open_conversation',
          notification_type: 'proactive_commitment',
          reminder_id: reminder.id,
        },
      }),
      signal: controller.signal,
    });
    clearTimeout(timeoutId);

    if (!response.ok) {
      const text = await response.text();
      console.error(`push-trigger: scheduled reminder push failed ${reminder.id}: ${response.status} ${text}`);
      return false;
    }

    return true;
  } catch (error) {
    clearTimeout(timeoutId);
    if (error instanceof DOMException && error.name === 'AbortError') {
      console.error(`push-trigger: scheduled reminder push timed out ${reminder.id}`);
    } else {
      console.error(`push-trigger: scheduled reminder push errored ${reminder.id}:`, error);
    }
    return false;
  }
}

// MARK: - Eligible User Query (Task 4.3)

/**
 * Query users who have push enabled, active tokens, and meet frequency criteria.
 * Single query with JOINs for efficiency.
 */
async function getEligibleUsers(
  supabase: ReturnType<typeof createClient>,
): Promise<EligibleUser[]> {
  // Get all users with active push tokens
  const { data: tokenUsers, error: tokenError } = await supabase
    .from('push_tokens')
    .select('user_id')
    .order('user_id');

  if (tokenError || !tokenUsers?.length) return [];

  const userIds = [...new Set((tokenUsers as Array<{ user_id: string }>).map((t) => t.user_id))];

  // Get notification preferences for those users
  const { data: profiles, error: profileError } = await supabase
    .from('context_profiles')
    .select('user_id, notification_preferences')
    .in('user_id', userIds);

  if (profileError || !profiles?.length) return [];

  // Filter to users with check_ins_enabled
  const eligible: EligibleUser[] = [];
  for (const profile of profiles as Array<{ user_id: string; notification_preferences: Record<string, unknown> | null }>) {
    const prefs = profile.notification_preferences;
    if (!prefs || prefs.check_ins_enabled !== true) continue;

    eligible.push({
      user_id: profile.user_id,
      frequency: (prefs.frequency as string) || 'weekly',
    });
  }

  return eligible;
}

// MARK: - Per-User Processing (Task 4.4 - 4.9)

/**
 * Process a single user: frequency check, push intelligence, content generation, delivery.
 * Wrapped in try/catch for error isolation (Task 4.9).
 */
async function processUser(
  user: EligibleUser,
  supabase: ReturnType<typeof createClient>,
  supabaseUrl: string,
  serviceRoleKey: string,
): Promise<ProcessingResult> {
  try {
    // Task 4.4: Frequency check
    const frequencyOk = await checkFrequency(user.user_id, user.frequency, supabase);
    if (!frequencyOk) {
      return { userId: user.user_id, status: 'skipped' };
    }

    // Check if user had a session today
    const hadSessionToday = await checkSessionToday(user.user_id, supabase);
    if (hadSessionToday) {
      return { userId: user.user_id, status: 'skipped' };
    }

    // Task 4.5: Determine push type
    const decision = await determinePushType(user.user_id, supabase);
    if (!decision) {
      return { userId: user.user_id, status: 'skipped' };
    }

    // Task 4.6: Generate content
    const content = await generatePushContent(user.user_id, decision, supabase);
    if (!content) {
      // LLM failed — skip user entirely per anti-pattern #8
      return { userId: user.user_id, status: 'skipped', pushType: decision.pushType };
    }

    // Task 4.8: Record in push_log FIRST (get the ID for open tracking)
    const pushLogId = await recordPushLog(user.user_id, decision, content, supabase);

    // Task 4.7: Deliver via push-send Edge Function
    await deliverPush(user.user_id, content, decision, pushLogId, supabaseUrl, serviceRoleKey);

    return { userId: user.user_id, status: 'sent', pushType: decision.pushType };
  } catch (error) {
    // Task 4.9: Error isolation — one failure must not block others
    console.error(`push-trigger: Failed processing user ${user.user_id}:`, error);
    return { userId: user.user_id, status: 'error', error: (error as Error).message };
  }
}

// MARK: - Frequency Check (Task 4.4)

/**
 * Check if enough time has passed since the last push for this user.
 */
async function checkFrequency(
  userId: string,
  frequency: string,
  supabase: ReturnType<typeof createClient>,
): Promise<boolean> {
  const intervalDays = FREQUENCY_INTERVALS[frequency] ?? 7;
  const cutoff = new Date();
  cutoff.setDate(cutoff.getDate() - intervalDays);

  const { data, error } = await supabase
    .from('push_log')
    .select('sent_at')
    .eq('user_id', userId)
    .gte('sent_at', cutoff.toISOString())
    .limit(1);

  if (error) {
    console.error(`Frequency check failed for ${userId}:`, error);
    return false; // Fail closed — don't send if we can't check
  }

  // If any push was sent within the interval, user is not eligible
  return !data || data.length === 0;
}

/**
 * Check if user had a conversation created today (skip push if so).
 */
async function checkSessionToday(
  userId: string,
  supabase: ReturnType<typeof createClient>,
): Promise<boolean> {
  const today = new Date();
  today.setUTCHours(0, 0, 0, 0);

  const { data, error } = await supabase
    .from('conversations')
    .select('id')
    .eq('user_id', userId)
    .gte('created_at', today.toISOString())
    .limit(1);

  if (error) return true; // Fail closed — don't send if we can't verify
  return data !== null && data.length > 0;
}

// MARK: - Content Generation (Task 4.6)

/**
 * Generate personalized push notification content via background model routing.
 * Returns null on LLM failure (do NOT send generic fallback).
 */
async function generatePushContent(
  userId: string,
  decision: PushDecision,
  supabase: ReturnType<typeof createClient>,
): Promise<PushContent | null> {
  // Load user context for personalization
  const userContext = await loadUserContext(supabase, userId);
  const formattedContext = formatContextForPrompt(userContext);
  const contextSummary = [
    formattedContext.valuesSection && `Values: ${formattedContext.valuesSection}`,
    formattedContext.goalsSection && `Goals: ${formattedContext.goalsSection}`,
    formattedContext.situationSection && `Situation: ${formattedContext.situationSection}`,
  ].filter(Boolean).join('\n') || 'No detailed context available.';

  // Get style preferences
  const stylePrefs = await getStylePreferences(userId, supabase, decision.conversationDomain);
  const styleInstructions = formatStyleInstructions(stylePrefs);

  // Build prompt
  const prompt = buildPushPrompt(decision, contextSummary, styleInstructions);

  const modelSelection = selectBackgroundModel('push_generation');
  const llmMessages: Array<{ role: 'system' | 'user'; content: string }> = [
    { role: 'system', content: 'You are a coaching push notification composer. Respond ONLY with valid JSON.' },
    { role: 'user', content: prompt },
  ];
  const budgetedMessages = enforceInputTokenBudget(llmMessages, modelSelection.inputBudgetTokens);

  // Call routed model via llm-client.ts (streaming → collect)
  try {
    let fullResponse = '';
    const stream = streamChatCompletion(
      budgetedMessages,
      {
        provider: modelSelection.provider,
        model: modelSelection.model,
        maxTokens: modelSelection.maxOutputTokens,
        temperature: modelSelection.temperature,
      },
    );

    let usage = { prompt_tokens: 0, completion_tokens: 0, total_tokens: 0 };
    for await (const chunk of stream) {
      if (chunk.type === 'token' && chunk.content) {
        fullResponse += chunk.content;
      }
      if (chunk.type === 'error') {
        console.error(`LLM error for user ${userId}:`, chunk.error);
        return null;
      }
      if (chunk.type === 'done' && chunk.usage) {
        usage = chunk.usage;
      }
    }

    // Track cost (non-critical — FK on conversation_id means we can't use a
    // sentinel string, so catch and log rather than blocking push delivery)
    try {
      const cost = calculateCost(usage, modelSelection.model);
      await logUsage(supabase, {
        userId,
        conversationId: null,
        messageId: null,
        model: modelSelection.model,
        promptTokens: usage.prompt_tokens,
        completionTokens: usage.completion_tokens,
        costUsd: cost,
      });
    } catch (costErr) {
      console.error(`push-trigger: cost logging failed for ${userId} (non-blocking):`, costErr);
    }

    // Parse JSON response
    return parsePushContent(fullResponse);
  } catch (error) {
    console.error(`LLM call failed for user ${userId}:`, error);
    return null;
  }
}

/**
 * Parse LLM response into title + body, enforcing length limits.
 */
function parsePushContent(response: string): PushContent | null {
  try {
    // Extract JSON from response (may have markdown backticks)
    const jsonMatch = response.match(/\{[\s\S]*\}/);
    if (!jsonMatch) return null;

    const parsed = JSON.parse(jsonMatch[0]);
    if (!parsed.title || !parsed.body) return null;

    return {
      title: String(parsed.title).slice(0, 50),
      body: String(parsed.body).slice(0, 200),
    };
  } catch {
    return null;
  }
}

// MARK: - Push Log (Task 4.8)

/**
 * Record push in push_log table. Returns the push_log ID for open tracking.
 */
async function recordPushLog(
  userId: string,
  decision: PushDecision,
  content: PushContent,
  supabase: ReturnType<typeof createClient>,
): Promise<string | null> {
  const { data, error } = await supabase
    .from('push_log')
    .insert({
      user_id: userId,
      push_type: decision.pushType,
      content: `${content.title}: ${content.body}`,
      metadata: {
        layer: decision.pushType,
        pattern_theme: decision.patternTheme || null,
        event_description: decision.eventDescription || null,
        domain: decision.conversationDomain || null,
      },
    })
    .select('id')
    .single();

  if (error) {
    console.error(`Failed to record push_log for ${userId}:`, error);
    return null;
  }

  return (data as { id: string })?.id ?? null;
}

// MARK: - Push Delivery (Task 4.7)

/**
 * Deliver push notification via push-send Edge Function (Story 8.2).
 * Fire-and-forget: delivery failures are logged but don't block processing.
 */
async function deliverPush(
  userId: string,
  content: PushContent,
  decision: PushDecision,
  pushLogId: string | null,
  supabaseUrl: string,
  serviceRoleKey: string,
): Promise<void> {
  const pushSendUrl = `${supabaseUrl}/functions/v1/push-send`;

  const payload = {
    user_id: userId,
    title: content.title,
    body: content.body,
    data: {
      domain: decision.conversationDomain || null,
      action: 'new_conversation',
      push_type: decision.pushType,
      push_log_id: pushLogId,
    },
  };

  const SEND_TIMEOUT_DEFAULT = 10000;
  const parsedTimeout = parseInt(Deno.env.get("PUSH_SEND_TIMEOUT_MS") || "", 10);
  const SEND_TIMEOUT_MS = Number.isFinite(parsedTimeout) && parsedTimeout > 0 ? parsedTimeout : SEND_TIMEOUT_DEFAULT;
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), SEND_TIMEOUT_MS);

  try {
    const response = await fetch(pushSendUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${serviceRoleKey}`,
      },
      body: JSON.stringify(payload),
      signal: controller.signal,
    });
    clearTimeout(timeoutId);

    if (!response.ok) {
      const errorText = await response.text();
      console.error(`push-send failed for ${userId}: ${response.status} ${errorText}`);
    }
  } catch (error) {
    clearTimeout(timeoutId);
    if (error instanceof DOMException && error.name === 'AbortError') {
      console.error(`push-send timed out for ${userId} after ${SEND_TIMEOUT_MS}ms`);
    } else {
      console.error(`push-send request failed for ${userId}:`, error);
    }
  }
}
