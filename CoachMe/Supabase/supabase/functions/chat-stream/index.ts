import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { SupabaseClient } from 'npm:@supabase/supabase-js@2.94.1';
import { handleCors } from '../_shared/cors.ts';
import { verifyAuth, AuthorizationError } from '../_shared/auth.ts';
import { errorResponse, sseHeaders } from '../_shared/response.ts';
import { streamChatCompletion, calculateCost, type ChatMessage } from '../_shared/llm-client.ts';
import { logUsage } from '../_shared/cost-tracker.ts';
import { loadUserContext, loadRelevantHistory } from '../_shared/context-loader.ts';
import { buildCoachingPrompt, buildDiscoveryPrompt, hasMemoryMoments, hasPatternInsights, extractPatternInsights, hasDiscoveryComplete, extractDiscoveryProfile, stripDiscoveryTags } from '../_shared/prompt-builder.ts';
import { determineDomain } from '../_shared/domain-router.ts';
import { detectCrossDomainPatterns, filterByRateLimit } from '../_shared/pattern-synthesizer.ts';
import { generatePatternSummary } from '../_shared/pattern-analyzer.ts';
import { detectCrisis } from '../_shared/crisis-detector.ts';
import { shouldOfferReflection } from '../_shared/reflection-builder.ts';
import { resolveStylePreferences, formatStyleInstructions, shouldRefreshStyleAnalysis, analyzeStylePreferences } from '../_shared/style-adapter.ts';
import { selectChatModel, enforceInputTokenBudget, type ModelSelection } from '../_shared/model-routing.ts';
import type { CoachingDomain, DiscoveryProfile, ReflectionContext, PatternSummary } from '../_shared/prompt-builder.ts';
import type { CrossDomainPattern } from '../_shared/pattern-synthesizer.ts';
import type { UserContext } from '../_shared/context-loader.ts';
import type { GoalStatus } from '../_shared/reflection-builder.ts';
import { determineSessionMode, shouldUpdateConversationType, computeVisibleContent } from '../_shared/session-mode.ts';
import { checkAndIncrementUsage, getNextResetDate } from '../_shared/rate-limiter.ts';
import { buildCommitmentReminderDraft } from '../_shared/commitment-reminders.ts';

interface ChatRequest {
  message: string;
  conversation_id?: string;  // snake_case from iOS client
  conversationId?: string;   // camelCase fallback
  first_message?: boolean;   // Story 11.3: coach speaks first (discovery mode)
}

/** Review fix M2: Typed conversation row from SELECT query */
interface ConversationRow {
  id: string;
  domain: string | null;
  type: string | null;
}

serve(async (req: Request) => {
  // Handle CORS preflight
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    // AC1: Verify JWT and extract user ID
    const { userId, supabase } = await verifyAuth(req);

    // Parse request body
    const body: ChatRequest = await req.json();
    const message = typeof body.message === 'string' ? body.message : '';
    // Support both snake_case (iOS) and camelCase
    const conversationId = body.conversation_id || body.conversationId;
    // Story 11.3: When true, coach speaks first — no user message required
    const firstMessage = body.first_message === true;

    if (!conversationId || (!firstMessage && !message?.trim())) {
      return errorResponse('Missing message or conversationId', 400);
    }

    // Story 11.2: Load user subscription state for session mode routing (AC #1, #2, #4)
    const { data: userData, error: userError } = await supabase
      .from('users')
      .select('subscription_status')
      .eq('id', userId)
      .single();

    if (userError) {
      console.error('Failed to load user data:', userError);
      return errorResponse('An unexpected error occurred', 500);
    }

    const subscriptionStatus: string | null = userData?.subscription_status ?? null;

    // Issue #4 FIX: Validate conversation ownership before inserting
    // Story 3.1: Also select domain for routing continuity
    // Story 11.2: Also select type for discovery/coaching conversation tracking (AC #5)
    const { data: conversation, error: convError } = await supabase
      .from('conversations')
      .select('id, domain, type')
      .eq('id', conversationId)
      .eq('user_id', userId)
      .single();

    if (convError || !conversation) {
      return errorResponse('Conversation not found or access denied', 404);
    }

    // Story 11.2: Load discovery_completed_at from context_profiles (AC #1, #4)
    const { data: profileData } = await supabase
      .from('context_profiles')
      .select('discovery_completed_at')
      .eq('user_id', userId)
      .single();

    const discoveryCompletedAt: string | null = profileData?.discovery_completed_at ?? null;

    // Story 11.2: Determine session mode (AC #1, #2, #4, #6, #7)
    const conversationType = (conversation as ConversationRow).type;
    // If user now has subscription and conversation is discovery type, upgrade to coaching (AC #6, #7)
    const sessionMode = determineSessionMode(subscriptionStatus, discoveryCompletedAt);

    // Story 11.2: Block users who completed discovery but haven't subscribed (AC #4)
    if (sessionMode === 'blocked') {
      return new Response(
        JSON.stringify({ error: 'subscription_required', discovery_completed: true }),
        { status: 403, headers: { 'Content-Type': 'application/json' } },
      );
    }

    // Story 10.1: Check rate limit BEFORE message insert (AC #1, #2, #3, #6)
    // Fail fast: never burn DB writes or LLM tokens on a rate-limited message
    if (!firstMessage) {
      const rateLimitResult = await checkAndIncrementUsage(
        supabase,
        userId,
        subscriptionStatus,
        sessionMode,
      );

      if (!rateLimitResult.allowed) {
        const nextResetDate = getNextResetDate(subscriptionStatus);
        const isTrial = subscriptionStatus === 'trial';
        return new Response(
          JSON.stringify({
            error: 'rate_limited',
            message: isTrial
              ? "You've used your trial sessions — ready to continue?"
              : "We've had a lot of great conversations this month! Your next session refreshes on " +
                (nextResetDate?.toISOString() ?? 'soon') + ".",
            is_trial: isTrial,
            remaining_until_reset: nextResetDate?.toISOString() ?? null,
            current_count: rateLimitResult.currentCount,
            limit: rateLimitResult.limit,
          }),
          { status: 429, headers: { 'Content-Type': 'application/json' } },
        );
      }
    }

    // Save user message to database (skip for first_message — coach speaks first, no user input)
    const userMessageId = crypto.randomUUID();
    if (!firstMessage) {
      // Issue #5 FIX: Check insert result and handle error
      const { error: userMsgError } = await supabase.from('messages').insert({
        id: userMessageId,
        conversation_id: conversationId,
        role: 'user',
        content: message,
        user_id: userId,
      });

      if (userMsgError) {
        console.error('Failed to save user message:', userMsgError);
        return errorResponse('Failed to save message', 500);
      }
    }

    // Story 11.2: Discovery mode SKIPS expensive operations (AC #1, Dev Notes)
    // SKIPS: domain classification, cross-domain patterns, pattern summaries,
    //        coaching preferences, style analysis, pattern engagement tracking
    // KEEPS: crisis detection, conversation history, message persistence, usage logging

    // Load conversation history (needed for both modes: crisis detection + Anthropic messages)
    const rawHistory = await supabase
      .from('messages')
      .select('role, content')
      .eq('conversation_id', conversationId)
      .order('created_at', { ascending: false })
      .limit(20)
      .then((res: { data: { role: string; content: string }[] | null }) => res.data);

    // Story 4.1: Crisis detection with recent message context (runs in BOTH modes — safety)
    const recentForCrisis = (rawHistory ?? [])
      .slice(0, 3)
      .map((m: { role: string; content: string }) => ({ role: m.role, content: m.content }));
    const crisisResult = await detectCrisis(message, recentForCrisis);

    // Filter empty messages, reverse to chronological, and ensure alternating roles
    // (Previous blank responses left orphaned user messages in DB)
    const filtered = (rawHistory ?? [])
      .reverse()
      .filter((m: { role: string; content: string }) => m.content?.trim());

    // Enforce alternating user/assistant roles for Anthropic API compliance
    const historyMessages: { role: string; content: string }[] = [];
    for (const m of filtered) {
      const lastRole = historyMessages.length > 0
        ? historyMessages[historyMessages.length - 1].role
        : null;
      if (m.role === lastRole) {
        // Consecutive same role: merge content (keeps most recent context)
        historyMessages[historyMessages.length - 1] = {
          role: m.role,
          content: historyMessages[historyMessages.length - 1].content + '\n\n' + m.content,
        };
      } else {
        historyMessages.push({ role: m.role, content: m.content });
      }
    }

    // Story 11.2: Branch pipeline based on session mode
    let systemPrompt: string;
    let reflectionContext: ReflectionContext | null = null;
    let reflectionOffered = false;
    let domainResult = { domain: 'general' as CoachingDomain, shouldClarify: false };
    let eligiblePatterns: CrossDomainPattern[] = [];
    let patternSummaries: PatternSummary[] = [];
    let coachingPrefs: Record<string, unknown> = {};
    let userContext: UserContext | null = null;
    let conversationHistory = { conversations: [] as import('../_shared/context-loader.ts').PastConversation[], hasHistory: false };

    // Count user messages for discovery phase tracking and hard limit enforcement
    const userMessageCount = historyMessages.filter(
      (m: { role: string }) => m.role === 'user'
    ).length;

    // Safety net: Force discovery completion after this many user messages
    // if the AI hasn't emitted [DISCOVERY_COMPLETE] on its own
    const DISCOVERY_HARD_LIMIT = 17;
    let forceDiscoveryComplete = false;

    if (sessionMode === 'discovery') {
      // ── DISCOVERY MODE ──
      // Minimal pipeline: crisis detection + discovery prompt
      systemPrompt = buildDiscoveryPrompt(crisisResult.crisisDetected, userMessageCount);

      // Check if we've exceeded the hard limit — will force completion after streaming
      forceDiscoveryComplete = userMessageCount >= DISCOVERY_HARD_LIMIT;

      // Story 11.2: Tag conversation as 'discovery' type if not already (AC #5)
      if (shouldUpdateConversationType(sessionMode, conversationType)) {
        supabase
          .from('conversations')
          .update({ type: 'discovery' })
          .eq('id', conversationId)
          .then(({ error: typeErr }: { error: unknown }) => {
            if (typeErr) console.error('Conversation type update failed:', typeErr);
          });
      }
    } else {
      // ── COACHING MODE ──
      // Full pipeline: all context loading, domain routing, patterns, reflections, style

      // Story 2.4 + 3.3 + 3.5 + 8.4 + 8.5: Load user context, history, patterns, coaching prefs in parallel
      // Target <200ms combined per architecture NFR
      // Story 4.5: Crisis detection is per-message only.
      const [loadedContext, loadedHistory, patternResult, loadedSummaries, loadedPrefs] = await Promise.all([
        loadUserContext(supabase, userId),
        loadRelevantHistory(supabase, userId, conversationId),
        detectCrossDomainPatterns(userId, supabase),
        generatePatternSummary(userId, supabase).catch((error) => {
          console.error('Pattern summary generation failed:', error);
          return [];
        }),
        supabase
          .from('context_profiles')
          .select('coaching_preferences')
          .eq('user_id', userId)
          .single()
          .then((res: { data: { coaching_preferences: Record<string, unknown> } | null; error: unknown }) => {
            if (res.error || !res.data) return {};
            return (res.data.coaching_preferences ?? {}) as Record<string, unknown>;
          })
          .catch(() => ({} as Record<string, unknown>)),
      ]);

      userContext = loadedContext;
      conversationHistory = loadedHistory;
      patternSummaries = loadedSummaries;
      coachingPrefs = loadedPrefs;

      // Story 8.4: Pattern engagement tracking (AC #3) — fire-and-forget
      trackPatternEngagement(rawHistory ?? [], userId, conversationId, supabase).catch((err) => {
        console.error('Pattern engagement tracking failed (non-blocking):', err);
      });

      // Story 3.1: Determine coaching domain (target <100ms)
      const currentDomain = (conversation as ConversationRow).domain as CoachingDomain | null;
      const recentForRouting = historyMessages
        .slice(-3)
        .map((m) => ({ role: m.role, content: m.content }));

      domainResult = await determineDomain(message, {
        currentDomain,
        recentMessages: recentForRouting,
      });

      // Story 3.1: Update conversation domain in DB (async, non-blocking) (AC #4)
      if (domainResult.domain !== currentDomain) {
        supabase
          .from('conversations')
          .update({ domain: domainResult.domain })
          .eq('id', conversationId)
          .then(({ error: domainErr }: { error: unknown }) => {
            if (domainErr) console.error('Domain update failed:', domainErr);
          });
      }

      // Story 3.5: Apply rate limiting to cross-domain patterns (AC #4)
      eligiblePatterns = await filterByRateLimit(
        userId,
        patternResult.patterns,
        supabase,
      );

      // Story 8.5: Build reflection context (only when NOT in crisis)
      if (!crisisResult.crisisDetected) {
        const sessionCount = (coachingPrefs.session_count as number) ?? 0;
        const lastReflectionAt = (coachingPrefs.last_reflection_at as string) ?? null;

        if (shouldOfferReflection(sessionCount, lastReflectionAt)) {
          const previousSessionTopic = conversationHistory.conversations.length > 0
            ? conversationHistory.conversations[0].summary
            : null;

          const goalStatus: GoalStatus[] = (userContext?.goals ?? []).map((g: { content: string; domain?: string; status: string }) => ({
            content: g.content,
            domain: g.domain,
            status: g.status as 'active' | 'completed' | 'paused',
          }));

          const domainUsage: Record<string, number> = {};
          for (const p of patternResult.patterns) {
            for (const d of p.domains) {
              domainUsage[d] = (domainUsage[d] ?? 0) + 1;
            }
          }

          const recentThemes = patternSummaries
            .slice(0, 3)
            .map((s: { theme: string }) => s.theme);

          const patternSummaryStr = patternSummaries
            .slice(0, 2)
            .map((s: { synthesis: string }) => s.synthesis)
            .join('; ') || '';

          reflectionContext = {
            sessionCount,
            lastReflectionAt,
            patternSummary: patternSummaryStr,
            goalStatus,
            domainUsage,
            recentThemes,
            previousSessionTopic,
            offerMonthlyReflection: true,
          };
          reflectionOffered = true;
        } else if (conversationHistory.conversations.length > 0) {
          reflectionContext = {
            sessionCount: (coachingPrefs.session_count as number) ?? 0,
            lastReflectionAt: (coachingPrefs.last_reflection_at as string) ?? null,
            patternSummary: '',
            goalStatus: [],
            domainUsage: {},
            recentThemes: [],
            previousSessionTopic: conversationHistory.conversations[0].summary,
            offerMonthlyReflection: false,
          };
        }
      }

      // Story 8.6: Resolve style preferences
      const stylePrefs = resolveStylePreferences(coachingPrefs, domainResult.domain);
      const styleInstructionStr = formatStyleInstructions(stylePrefs);

      // Build context-aware, domain-specific system prompt
      systemPrompt = buildCoachingPrompt(
        userContext,
        domainResult.domain,
        domainResult.shouldClarify,
        conversationHistory.conversations,
        eligiblePatterns,
        crisisResult.crisisDetected,
        patternSummaries,
        reflectionContext,
        styleInstructionStr,
      );

      // Story 8.6: Background style analysis — fire-and-forget
      if (shouldRefreshStyleAnalysis(coachingPrefs)) {
        analyzeStylePreferences(userId, supabase).catch((err) =>
          console.error('Style analysis failed (non-blocking):', err),
        );
      }
    }

    // Story 11.3: For first_message (coach speaks first), inject a minimal user
    // turn so the model API has a valid messages array. The discovery system
    // prompt instructs the coach to begin the conversation warmly.
    const routedHistory = firstMessage && historyMessages.length === 0
      ? [{ role: 'user' as const, content: 'Begin' }]
      : historyMessages.map((m) => ({
          role: m.role as 'user' | 'assistant',
          content: m.content,
        }));

    const messages: ChatMessage[] = [
      { role: 'system', content: systemPrompt },
      ...routedHistory,
    ];

    // Centralized model routing policy:
    // - Primary: claude-haiku-4.5
    // - Escalation: claude-sonnet-4-5 for high-stakes emotional/safety turns
    const recentUserMessages = historyMessages
      .filter((m) => m.role === 'user')
      .map((m) => m.content)
      .slice(-3);
    const recentAssistantMessages = historyMessages
      .filter((m) => m.role === 'assistant')
      .map((m) => m.content)
      .slice(-3);
    const modelSelection = selectChatModel({
      sessionMode,
      message: message ?? '',
      recentUserMessages,
      crisisDetected: crisisResult.crisisDetected,
      crisisConfidence: crisisResult.confidence,
    });
    const humanFeelGuard = shouldApplyHumanFeelGuard({
      sessionMode,
      crisisDetected: crisisResult.crisisDetected,
      message: message ?? '',
      recentUserMessages,
      recentAssistantMessages,
    });
    if (humanFeelGuard.enabled) {
      console.log(`chat-stream human-feel guard enabled: ${humanFeelGuard.reason}`);
    }
    console.log(`chat-stream model route: ${modelSelection.routeTier} ${modelSelection.model} (${modelSelection.routeReason})`);
    const budgetedMessages = enforceInputTokenBudget(messages, modelSelection.inputBudgetTokens);
    const selectedModel = modelSelection.model;

    // AC2: Stream response via SSE
    const assistantMessageId = crypto.randomUUID();
    let fullContent = '';
    let memoryMomentFound = false;
    let patternInsightFound = false;  // Story 3.4: Track pattern insight detection
    let reflectionAccepted: boolean | null = null; // Story 8.5: Track reflection acceptance
    let discoveryCompleteFound = false; // Story 11.2: Track discovery completion signal
    let discoveryBlockIdx = -1; // Review fix H1: character index where [DISCOVERY_COMPLETE] starts in fullContent
    let tokenUsage = { prompt_tokens: 0, completion_tokens: 0, total_tokens: 0 };

    const stream = new ReadableStream({
      async start(controller) {
        const encoder = new TextEncoder();
        const sendStreamError = (message: string) => {
          const errorEvent = `data: ${JSON.stringify({
            type: 'error',
            message,
          })}\n\n`;
          controller.enqueue(encoder.encode(errorEvent));
        };

        const updateResponseSignals = () => {
          if (!memoryMomentFound) {
            memoryMomentFound = hasMemoryMoments(fullContent);
          }
          if (!patternInsightFound) {
            patternInsightFound = hasPatternInsights(fullContent);
          }
          if (reflectionOffered && reflectionAccepted === null) {
            if (fullContent.includes('[REFLECTION_ACCEPTED]')) {
              reflectionAccepted = true;
            } else if (fullContent.includes('[REFLECTION_DECLINED]')) {
              reflectionAccepted = false;
            }
          }
          if (sessionMode === 'discovery' && !discoveryCompleteFound) {
            discoveryCompleteFound = hasDiscoveryComplete(fullContent);
          }
          if (sessionMode === 'discovery' && discoveryBlockIdx === -1) {
            const idx = fullContent.indexOf('[DISCOVERY_COMPLETE]');
            if (idx !== -1) discoveryBlockIdx = idx;
          }
        };

        const emitTokenEvent = (rawChunkContent: string) => {
          let clientContent = computeVisibleContent(
            fullContent.length,
            rawChunkContent,
            discoveryBlockIdx,
          );

          clientContent = clientContent
            .replace(/\[REFLECTION_ACCEPTED\]/g, '')
            .replace(/\[REFLECTION_DECLINED\]/g, '');

          if (!clientContent) return;

          const event = `data: ${JSON.stringify({
            type: 'token',
            content: clientContent,
            memory_moment: memoryMomentFound,
            pattern_insight: patternInsightFound,
            crisis_detected: crisisResult.crisisDetected,
            reflection_offered: reflectionOffered,
          })}\n\n`;
          controller.enqueue(encoder.encode(event));
        };

        const handleCompletion = async (): Promise<boolean> => {
          // Don't save empty responses to DB — prevents poisoning future history
          if (!fullContent.trim()) {
            console.warn('Empty LLM response, skipping DB save');
            sendStreamError("Coach's response was empty. Let's try again.");
            return false;
          }

          // Story 8.5: Strip reflection tags before saving to DB (never visible to user)
          // Story 11.2: Strip discovery tags from saved content (AC #3)
          let contentToSave = fullContent
            .replace(/\[REFLECTION_ACCEPTED\]/g, '')
            .replace(/\[REFLECTION_DECLINED\]/g, '');
          if (discoveryCompleteFound) {
            contentToSave = stripDiscoveryTags(contentToSave);
          }
          contentToSave = contentToSave.trim();

          // Story 11.2 + 11.4: Process [DISCOVERY_COMPLETE] signal (AC #3)
          // Extract profile JSON, write all discovery fields to context_profiles, prepare SSE metadata
          let discoveryProfile: DiscoveryProfile | null = null;
          let discoveryProfileSaved = false;
          if (discoveryCompleteFound) {
            discoveryProfile = extractDiscoveryProfile(fullContent);

            // Story 11.4: Build the full discovery profile update payload
            // Includes all extracted fields + raw JSON for audit trail (AC #1, #5)
            const discoveryUpdate: Record<string, unknown> = {
              discovery_completed_at: new Date().toISOString(),
            };

            if (discoveryProfile) {
              discoveryUpdate.aha_insight = discoveryProfile.aha_insight || null;
              discoveryUpdate.coaching_domains = discoveryProfile.coaching_domains;
              discoveryUpdate.current_challenges = discoveryProfile.current_challenges;
              discoveryUpdate.emotional_baseline = discoveryProfile.emotional_baseline || null;
              discoveryUpdate.communication_style = discoveryProfile.communication_style || null;
              discoveryUpdate.key_themes = discoveryProfile.key_themes;
              discoveryUpdate.strengths_identified = discoveryProfile.strengths_identified;
              discoveryUpdate.vision = discoveryProfile.vision || null;

              // L1 fix: Store actual raw JSON from AI, not the parsed/defaulted object
              const rawJsonMatch = fullContent.match(
                /\[DISCOVERY_COMPLETE\]([\s\S]*?)\[\/DISCOVERY_COMPLETE\]/i,
              );
              discoveryUpdate.raw_discovery_data = rawJsonMatch?.[1]?.trim() ?? JSON.stringify(discoveryProfile);
            }

            // Story 11.4 AC #1: Upsert all discovery fields into context_profiles
            // Story 11.4 AC #5: Partial extraction handled — missing fields default to null/[]
            // Increment context_version to signal profile change to iOS client
            const { data: currentProfile, error: profileVersionErr } = await supabase
              .from('context_profiles')
              .select('context_version, values')
              .eq('user_id', userId)
              .single();

            if (profileVersionErr) {
              console.error('Failed to read context_version:', profileVersionErr.message);
            }
            // Always set context_version — fallback to 1 when profile is missing or errored
            discoveryUpdate.context_version = ((currentProfile?.context_version as number | null) ?? 0) + 1;

            // Story 11.4 AC #1: Merge discovered values into existing ContextValue[] array
            // Discovery values are plain strings; DB values column stores ContextValue objects
            if (
              discoveryProfile !== null &&
              Array.isArray(discoveryProfile.values) &&
              discoveryProfile.values.length > 0 &&
              currentProfile
            ) {
              const dp = discoveryProfile; // narrow type for closures
              const existingValues = (currentProfile.values ?? []) as Array<{
                id: string; content: string; source: string; confidence?: number; added_at: string;
              }>;
              const existingContents = new Set(
                existingValues.map((v: { content: string }) => v.content.toLowerCase()),
              );
              const newValues = dp.values
                .filter((v: string) => !existingContents.has(v.toLowerCase()))
                .map((v: string) => ({
                  id: crypto.randomUUID(),
                  content: v,
                  source: 'extracted' as const,
                  confidence: dp.confidence ?? 0.8,
                  added_at: new Date().toISOString(),
                }));
              if (newValues.length > 0) {
                discoveryUpdate.values = [...existingValues, ...newValues];
              }
            }

            const { error: dcErr } = await supabase
              .from('context_profiles')
              .update(discoveryUpdate)
              .eq('user_id', userId);

            if (dcErr) {
              // Story 11.4 AC #5: Log error but don't block user — paywall still shows
              console.error('Failed to save discovery profile:', dcErr);
            } else {
              discoveryProfileSaved = true;
            }
          }

          // Safety net: Force discovery completion if AI didn't emit the signal
          // after exceeding the hard message limit (graceful degradation — no profile data)
          if (forceDiscoveryComplete && !discoveryCompleteFound) {
            console.warn(`[discovery] Hard limit reached (${userMessageCount} user messages) — forcing completion`);
            discoveryCompleteFound = true;

            const { data: forceProfile, error: forceVersionErr } = await supabase
              .from('context_profiles')
              .select('context_version')
              .eq('user_id', userId)
              .single();

            if (forceVersionErr) {
              console.error('Failed to read context_version for force-complete:', forceVersionErr.message);
            }

            const { error: forceErr } = await supabase
              .from('context_profiles')
              .update({
                discovery_completed_at: new Date().toISOString(),
                context_version: ((forceProfile?.context_version as number | null) ?? 0) + 1,
              })
              .eq('user_id', userId);

            if (forceErr) {
              console.error('Failed to force-complete discovery:', forceErr);
            } else {
              discoveryProfileSaved = true;
            }
          }

          // Story 8.5: Default to decline when no tag detected (safe default)
          // Review fix M1: Removed incorrect fallback heuristic that checked the user's
          // CURRENT message instead of their response to the reflection offer
          if (reflectionOffered && reflectionAccepted === null) {
            reflectionAccepted = false;
          }

          // AC3: Save assistant message to database
          // Issue #7 FIX: Handle save error and report to user
          const { error: assistantMsgError } = await supabase.from('messages').insert({
            id: assistantMessageId,
            conversation_id: conversationId,
            role: 'assistant',
            content: contentToSave,
            user_id: userId,
            token_count: tokenUsage.completion_tokens,
          });

          if (assistantMsgError) {
            console.error('Failed to save assistant message:', assistantMsgError);
            sendStreamError("Coach's response couldn't be saved. Please try again.");
            return false;
          }

          // Send reactive push for coach reply and queue follow-up reminder if
          // the latest user message contains a concrete commitment.
          await Promise.allSettled([
            !firstMessage
              ? sendReactiveReplyPush(userId, conversationId, contentToSave)
              : Promise.resolve(),
            (!firstMessage && sessionMode === 'coaching')
              ? queueCommitmentReminder(
                  supabase,
                  userId,
                  conversationId,
                  userMessageId,
                  message,
                )
              : Promise.resolve(),
          ]);

          // AC3: Log usage and cost
          // TODO(Epic-10): bypass message counting for discovery mode
          const costUsd = calculateCost(tokenUsage, selectedModel);
          // Story 4.1: Include crisis_detected in usage logging for monitoring
          await logUsage(supabase, {
            userId,
            conversationId,
            messageId: assistantMessageId,
            model: selectedModel,
            promptTokens: tokenUsage.prompt_tokens,
            completionTokens: tokenUsage.completion_tokens,
            costUsd,
            crisisDetected: crisisResult.crisisDetected,
          });

          // Story 8.5: Non-blocking post-stream updates (fire-and-forget, coaching mode only)
          if (sessionMode === 'coaching') {
            // Review fix C1: Only increment session_count on first exchange in a conversation
            // Review fix H2: Merged into single read-modify-write to prevent race condition
            const isFirstExchange = !(rawHistory ?? []).some(
              (m: { role: string; content: string }) => m.role === 'assistant',
            );
            const shouldUpdateReflectionTimestamp = reflectionOffered && reflectionAccepted === true;

            if (isFirstExchange || shouldUpdateReflectionTimestamp) {
              supabase
                .from('context_profiles')
                .select('coaching_preferences')
                .eq('user_id', userId)
                .single()
                .then((res: { data: { coaching_preferences: Record<string, unknown> } | null; error: unknown }) => {
                  if (res.error || !res.data) return;
                  const prefs = (res.data.coaching_preferences ?? {}) as Record<string, unknown>;
                  const updates: Record<string, unknown> = { ...prefs };

                  if (isFirstExchange) {
                    updates.session_count = ((prefs.session_count as number) ?? 0) + 1;
                  }
                  if (shouldUpdateReflectionTimestamp) {
                    updates.last_reflection_at = new Date().toISOString();
                  }

                  return supabase
                    .from('context_profiles')
                    .update({ coaching_preferences: updates })
                    .eq('user_id', userId);
                })
                .then((res: { error: unknown } | undefined) => {
                  if (res?.error) console.error('Coaching preferences update error:', res.error);
                })
                .catch((err: unknown) => console.error('Coaching preferences update failed:', err));
            }
          }

          // Send done event (use snake_case to match iOS client decoder)
          // Story 3.1: Include domain in metadata for future history view badges
          // Story 4.1: Include crisis_detected flag for iOS client
          // Story 8.5: Include reflection_offered and reflection_accepted flags
          // Story 11.2 + 11.4: Include discovery flags and profile for iOS client (AC #3)
          // Story 11.4 AC #6: discovery_profile_saved tells iOS client the DB write succeeded
          const doneEvent = `data: ${JSON.stringify({
            type: 'done',
            message_id: assistantMessageId,
            usage: tokenUsage,
            domain: domainResult.domain,
            crisis_detected: crisisResult.crisisDetected,
            reflection_offered: reflectionOffered,
            reflection_accepted: reflectionAccepted ?? false,
            discovery_complete: discoveryCompleteFound,
            discovery_profile_saved: discoveryProfileSaved,
            ...(discoveryProfile ? { discovery_profile: discoveryProfile } : {}),
          })}\n\n`;
          controller.enqueue(encoder.encode(doneEvent));
          return true;
        };

        try {
          if (humanFeelGuard.enabled) {
            const guardedResult = await generateHumanFeelGuardedResponse({
              messages: budgetedMessages,
              modelSelection,
              userMessage: message ?? '',
              recentAssistantMessages,
            });

            if (guardedResult.error || !guardedResult.content.trim()) {
              console.error('Human-feel guard generation failed:', guardedResult.error ?? 'empty output');
              sendStreamError("Coach is taking a moment. Let's try again.");
              return;
            }

            fullContent = guardedResult.content;
            tokenUsage = guardedResult.usage;
            updateResponseSignals();
            emitTokenEvent(fullContent);

            const completed = await handleCompletion();
            if (!completed) return;
            return;
          }

          for await (const chunk of streamChatCompletion(budgetedMessages, {
            provider: modelSelection.provider,
            model: modelSelection.model,
            maxTokens: modelSelection.maxOutputTokens,
            temperature: modelSelection.temperature,
          })) {
            if (chunk.type === 'token' && chunk.content) {
              fullContent += chunk.content;
              updateResponseSignals();
              emitTokenEvent(chunk.content);
            }

            if (chunk.type === 'done' && chunk.usage) {
              tokenUsage = chunk.usage;
              const completed = await handleCompletion();
              if (!completed) return;
            }

            if (chunk.type === 'error') {
              sendStreamError("Coach is taking a moment. Let's try again.");
            }
          }
        } catch (error) {
          console.error('Stream error:', error);
          sendStreamError("Coach is taking a moment. Let's try again.");
        } finally {
          controller.close();
        }
      },
    });

    return new Response(stream, { headers: sseHeaders });

  } catch (error) {
    console.error('Chat stream error:', error);
    // AC4: Return graceful error
    if (error instanceof AuthorizationError) {
      return errorResponse((error as Error).message, 401);
    }
    // Don't leak internal error details for 500s
    return errorResponse('An unexpected error occurred', 500);
  }
});

// MARK: - Human Feel Guard (Selective strictness with timeout)

interface HumanFeelGuardInput {
  sessionMode: 'discovery' | 'coaching' | 'blocked';
  crisisDetected: boolean;
  message: string;
  recentUserMessages: string[];
  recentAssistantMessages: string[];
}

interface HumanFeelGuardDecision {
  enabled: boolean;
  reason: string;
}

interface TokenUsage {
  prompt_tokens: number;
  completion_tokens: number;
  total_tokens: number;
}

interface CollectedLLMResponse {
  content: string;
  usage: TokenUsage;
  error?: string;
}

interface HumanFeelValidation {
  passed: boolean;
  violations: string[];
}

interface GuardedResponse {
  content: string;
  usage: TokenUsage;
  error?: string;
}

const HUMAN_GUARD_COMPLAINT_TERMS = [
  'robotic',
  'feels robotic',
  'be human',
  'more human',
  'no personality',
  'same opener',
  'same opening',
  'sounds like ai',
  'sounds ai',
  'i hear you',
  'annoying',
];

const HUMAN_GUARD_EMPATHY_OPENERS = [
  /^i hear you\b/i,
  /^it sounds like\b/i,
  /^that sounds\b/i,
  /^i can hear\b/i,
];

function shouldApplyHumanFeelGuard(input: HumanFeelGuardInput): HumanFeelGuardDecision {
  const mode = (Deno.env.get('STRICT_HUMAN_FEEL_MODE') ?? 'selective').toLowerCase();
  if (mode === 'off') return { enabled: false, reason: 'mode_off' };

  if (input.sessionMode !== 'coaching' || input.crisisDetected) {
    return { enabled: false, reason: 'not_coaching_or_crisis' };
  }

  if (mode === 'always') {
    return { enabled: true, reason: 'mode_always' };
  }

  const complaintSource = [input.message, ...input.recentUserMessages].join('\n').toLowerCase();
  const hasComplaint = HUMAN_GUARD_COMPLAINT_TERMS.some((term) => complaintSource.includes(term));
  if (hasComplaint) {
    return { enabled: true, reason: 'user_feedback_signal' };
  }

  const recentOpeners = input.recentAssistantMessages
    .map(extractOpeningSignature)
    .filter(Boolean);
  const openerCounts = new Map<string, number>();
  for (const opener of recentOpeners) {
    openerCounts.set(opener, (openerCounts.get(opener) ?? 0) + 1);
  }
  const repeatedOpeners = Array.from(openerCounts.values()).some((count) => count >= 2);
  if (repeatedOpeners) {
    return { enabled: true, reason: 'repeated_openers' };
  }

  return { enabled: false, reason: 'no_trigger' };
}

async function generateHumanFeelGuardedResponse(input: {
  messages: ChatMessage[];
  modelSelection: ModelSelection;
  userMessage: string;
  recentAssistantMessages: string[];
}): Promise<GuardedResponse> {
  const base = await collectModelOutput(input.messages, input.modelSelection);
  if (base.error) return { content: '', usage: base.usage, error: base.error };

  const firstPassValidation = evaluateHumanFeelDraft(base.content, input.recentAssistantMessages);
  if (firstPassValidation.passed) {
    return { content: base.content, usage: base.usage };
  }

  const timeoutMsRaw = Number.parseInt(Deno.env.get('HUMAN_FEEL_REWRITE_TIMEOUT_MS') ?? '', 10);
  const timeoutMs = Number.isFinite(timeoutMsRaw) && timeoutMsRaw > 0 ? timeoutMsRaw : 600;
  const rewriteAttempt = await withTimeout(
    rewriteDraftForHumanFeel(
      base.content,
      firstPassValidation.violations,
      input.userMessage,
      input.recentAssistantMessages,
      input.modelSelection,
    ),
    timeoutMs,
  );

  if (!rewriteAttempt || rewriteAttempt.error || !rewriteAttempt.content.trim()) {
    return { content: base.content, usage: base.usage };
  }

  const rewriteValidation = evaluateHumanFeelDraft(rewriteAttempt.content, input.recentAssistantMessages);
  const combinedUsage = sumUsage(base.usage, rewriteAttempt.usage);

  // Accept rewrite if it passes, or if it clearly reduces violations.
  if (
    rewriteValidation.passed ||
    rewriteValidation.violations.length < firstPassValidation.violations.length
  ) {
    return { content: rewriteAttempt.content, usage: combinedUsage };
  }

  return { content: base.content, usage: combinedUsage };
}

async function rewriteDraftForHumanFeel(
  draft: string,
  violations: string[],
  userMessage: string,
  recentAssistantMessages: string[],
  modelSelection: ModelSelection,
): Promise<CollectedLLMResponse> {
  const rewriteSystem = [
    'You are a coaching response rewriter.',
    'Rewrite the draft to feel more human and natural while preserving meaning and safety.',
    'Rules:',
    '- Do not start with "I hear you".',
    '- Vary opener style and avoid boilerplate.',
    '- Keep warmth, clarity, and practical specificity.',
    '- Keep tags like [MEMORY:], [PATTERN:], [DISCOVERY_COMPLETE], [REFLECTION_ACCEPTED], [REFLECTION_DECLINED] if present.',
    '- Return ONLY the rewritten response text.',
  ].join('\n');

  const recentOpeners = recentAssistantMessages
    .map(extractOpeningSignature)
    .filter(Boolean)
    .join(', ') || '(none)';

  const rewriteUser = [
    `Violations to fix: ${violations.join('; ')}`,
    `User message: ${userMessage || '(none)'}`,
    `Recent assistant openers: ${recentOpeners}`,
    '',
    'Draft:',
    draft,
  ].join('\n');

  const rewriteMessages: ChatMessage[] = [
    { role: 'system', content: rewriteSystem },
    { role: 'user', content: rewriteUser },
  ];

  return collectModelOutput(rewriteMessages, {
    ...modelSelection,
    maxOutputTokens: Math.min(modelSelection.maxOutputTokens, 900),
    temperature: Math.max(modelSelection.temperature ?? 0.65, 0.6),
  });
}

function evaluateHumanFeelDraft(
  draft: string,
  recentAssistantMessages: string[],
): HumanFeelValidation {
  const text = draft.trim();
  if (!text) {
    return { passed: false, violations: ['empty_draft'] };
  }

  const violations: string[] = [];
  if (/^i hear you\b/i.test(text)) {
    violations.push('starts_with_i_hear_you');
  }

  const opener = extractOpeningSignature(text);
  const recentOpeners = recentAssistantMessages
    .map(extractOpeningSignature)
    .filter(Boolean);
  if (opener && recentOpeners.includes(opener)) {
    violations.push('repeated_recent_opener');
  }

  if (HUMAN_GUARD_EMPATHY_OPENERS.some((pattern) => pattern.test(text))) {
    const recentEmpathy = recentAssistantMessages.some((msg) =>
      HUMAN_GUARD_EMPATHY_OPENERS.some((pattern) => pattern.test(msg.trim())),
    );
    if (recentEmpathy) {
      violations.push('repeated_empathy_boilerplate');
    }
  }

  return {
    passed: violations.length === 0,
    violations,
  };
}

function extractOpeningSignature(text: string): string {
  return text
    .trim()
    .split(/\s+/)
    .slice(0, 4)
    .join(' ')
    .replace(/[^\w\s']/g, '')
    .toLowerCase();
}

async function collectModelOutput(
  messages: ChatMessage[],
  modelSelection: Pick<ModelSelection, 'provider' | 'model' | 'maxOutputTokens' | 'temperature'>,
): Promise<CollectedLLMResponse> {
  let content = '';
  let usage: TokenUsage = { prompt_tokens: 0, completion_tokens: 0, total_tokens: 0 };

  for await (const chunk of streamChatCompletion(messages, {
    provider: modelSelection.provider,
    model: modelSelection.model,
    maxTokens: modelSelection.maxOutputTokens,
    temperature: modelSelection.temperature,
  })) {
    if (chunk.type === 'token' && chunk.content) {
      content += chunk.content;
    } else if (chunk.type === 'done' && chunk.usage) {
      usage = chunk.usage;
    } else if (chunk.type === 'error') {
      return { content: '', usage, error: chunk.error ?? 'generation_error' };
    }
  }

  return { content, usage };
}

function sumUsage(base: TokenUsage, extra: TokenUsage): TokenUsage {
  return {
    prompt_tokens: base.prompt_tokens + extra.prompt_tokens,
    completion_tokens: base.completion_tokens + extra.completion_tokens,
    total_tokens: base.total_tokens + extra.total_tokens,
  };
}

async function withTimeout<T>(promise: Promise<T>, timeoutMs: number): Promise<T | null> {
  let timeoutId: number | undefined;
  try {
    return await Promise.race([
      promise,
      new Promise<null>((resolve) => {
        timeoutId = setTimeout(() => resolve(null), timeoutMs);
      }),
    ]);
  } finally {
    if (timeoutId !== undefined) clearTimeout(timeoutId);
  }
}

// MARK: - Story 8.4: Pattern Engagement Tracking (AC #3)

/** Minimum user messages after pattern surfacing to count as engagement */
const PATTERN_ENGAGEMENT_THRESHOLD = 2;

/**
 * Track pattern engagement: when a pattern was surfaced by the assistant
 * and the user subsequently engages with it (2+ messages after surfacing).
 *
 * Scans recent conversation history (newest-first) for:
 * 1. An assistant message containing [PATTERN: ...] tags
 * 2. User messages that came AFTER that assistant message
 * If user message count >= 2, records a 'pattern_engaged' learning signal.
 *
 * Non-blocking: called as fire-and-forget, never blocks the response pipeline.
 */
async function trackPatternEngagement(
  rawHistory: Array<{ role: string; content: string }>,
  userId: string,
  conversationId: string,
  supabase: SupabaseClient,
): Promise<void> {
  if (!rawHistory?.length) return;

  // rawHistory is newest-first from the DB query
  // Walk backwards (newest first) to find the most recent assistant message with [PATTERN: ...]
  let patternAssistantIdx = -1;
  let patternThemes: string[] = [];

  for (let i = 0; i < rawHistory.length; i++) {
    const msg = rawHistory[i];
    if (msg.role === 'assistant' && hasPatternInsights(msg.content)) {
      patternAssistantIdx = i;
      patternThemes = extractPatternInsights(msg.content);
      break; // Most recent pattern-containing assistant message
    }
  }

  // No pattern was surfaced in recent history
  if (patternAssistantIdx === -1 || patternThemes.length === 0) return;

  // Count user messages that came AFTER the pattern-containing assistant message
  // In newest-first order, messages at index < patternAssistantIdx are newer
  let userMessageCount = 0;
  for (let i = 0; i < patternAssistantIdx; i++) {
    if (rawHistory[i].role === 'user') {
      userMessageCount++;
    }
  }

  // Engagement threshold: 2+ user messages after pattern surfacing (AC #3)
  if (userMessageCount < PATTERN_ENGAGEMENT_THRESHOLD) return;

  // Check if we already recorded engagement for this pattern in this conversation
  // to avoid duplicate signals
  const { data: existing } = await supabase
    .from('learning_signals')
    .select('id')
    .eq('user_id', userId)
    .eq('signal_type', 'pattern_engaged')
    .contains('signal_data', { conversation_id: conversationId })
    .limit(1);

  if (existing && existing.length > 0) return; // Already recorded

  // Record pattern_engaged learning signal
  const { error } = await supabase.from('learning_signals').insert({
    user_id: userId,
    signal_type: 'pattern_engaged',
    signal_data: {
      pattern_theme: patternThemes[0],
      engagement_depth: userMessageCount,
      conversation_id: conversationId,
    },
  });

  if (error) {
    console.error('Failed to record pattern engagement signal:', error);
  }
}

// MARK: - Reactive Push + Scheduled Reminder Queue

function buildReactivePushBody(content: string): string {
  const normalized = content.replace(/\s+/g, ' ').trim();
  if (!normalized) return 'Your coach replied.';
  if (normalized.length <= 140) return normalized;
  return `${normalized.slice(0, 139).trimEnd()}…`;
}

async function sendReactiveReplyPush(
  userId: string,
  conversationId: string,
  assistantContent: string,
): Promise<void> {
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !serviceRoleKey) {
    console.warn('Reactive push skipped: missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
    return;
  }

  const timeoutMs = Number.parseInt(Deno.env.get('REACTIVE_PUSH_TIMEOUT_MS') ?? '', 10);
  const effectiveTimeout = Number.isFinite(timeoutMs) && timeoutMs > 0 ? timeoutMs : 4000;
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), effectiveTimeout);

  try {
    const response = await fetch(`${supabaseUrl}/functions/v1/push-send`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${serviceRoleKey}`,
      },
      body: JSON.stringify({
        user_id: userId,
        title: 'Coach',
        body: buildReactivePushBody(assistantContent),
        data: {
          conversation_id: conversationId,
          action: 'open_conversation',
          notification_type: 'reactive_reply',
        },
      }),
      signal: controller.signal,
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error(`Reactive push failed for user ${userId}: ${response.status} ${errorText}`);
    }
  } catch (error) {
    if (error instanceof DOMException && error.name === 'AbortError') {
      console.error(`Reactive push timed out for user ${userId} after ${effectiveTimeout}ms`);
    } else {
      console.error(`Reactive push request failed for user ${userId}:`, error);
    }
  } finally {
    clearTimeout(timeoutId);
  }
}

async function queueCommitmentReminder(
  supabase: SupabaseClient,
  userId: string,
  conversationId: string,
  sourceMessageId: string,
  userMessage: string,
): Promise<void> {
  const draft = buildCommitmentReminderDraft(userMessage);
  if (!draft) return;

  const { error } = await supabase
    .from('scheduled_reminders')
    .insert({
      user_id: userId,
      conversation_id: conversationId,
      source_message_id: sourceMessageId,
      reminder_type: draft.reminderType,
      title: draft.title,
      body: draft.body,
      remind_at: draft.remindAt,
      status: 'pending',
      metadata: draft.metadata,
    });

  if (error) {
    const errorCode = (error as { code?: string }).code;
    if (errorCode === '23505') return;
    console.error('Failed to queue commitment reminder:', error);
  }
}

// Note: System prompt building moved to _shared/prompt-builder.ts (Story 2.4)
// Domain routing added in Story 3.1 via _shared/domain-router.ts
// Cross-domain pattern synthesis added in Story 3.5 via _shared/pattern-synthesizer.ts
// Crisis detection pipeline added in Story 4.1 via _shared/crisis-detector.ts
// Pattern recognition engine added in Story 8.4 via _shared/pattern-analyzer.ts
// Reflection builder added in Story 8.5 via _shared/reflection-builder.ts
// Style adaptation added in Story 8.6 via _shared/style-adapter.ts
// Discovery mode routing added in Story 11.2, now managed by model-routing.ts
