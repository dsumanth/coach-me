/**
 * session-mode.ts
 *
 * Story 11.2: Discovery Mode Edge Function
 *
 * Determines session mode (discovery | coaching | blocked) based on
 * user subscription state and discovery completion status.
 */

/** Session mode determines model, prompt, and feature set */
export type SessionMode = 'discovery' | 'coaching' | 'blocked';

/**
 * Determine session mode based on user subscription state and discovery completion.
 *
 * Routing logic:
 * - Discovery NOT completed → discovery (always, even for subscribers)
 * - Discovery completed + active subscription (trial/active) → coaching
 * - Discovery completed + no subscription → blocked (must subscribe)
 * - Expired/cancelled subscriptions count as "no active subscription"
 *
 * AC #1, #2, #4
 */
export function determineSessionMode(
  subscriptionStatus: string | null,
  discoveryCompletedAt: string | null,
): SessionMode {
  // Discovery must be completed first, regardless of subscription status
  if (!discoveryCompletedAt) return 'discovery';

  const hasSubscription =
    subscriptionStatus === 'trial' || subscriptionStatus === 'active';

  if (hasSubscription) return 'coaching';
  return 'blocked';
}

/**
 * Whether a conversation should be tagged as 'discovery' type.
 * Discovery conversations need the type column set for tracking and to
 * support seamless upgrade when user subscribes (AC #5, #6).
 */
export function shouldUpdateConversationType(
  sessionMode: SessionMode,
  currentType: string | null,
): boolean {
  return sessionMode === 'discovery' && currentType !== 'discovery';
}

/**
 * Compute the visible portion of a streaming chunk, suppressing content
 * from the [DISCOVERY_COMPLETE] block onward.
 *
 * The discovery block at the end of the AI's response contains internal
 * JSON profile data delivered via SSE metadata (AC #3), not chat UI.
 *
 * @param fullContentLength Total length of accumulated content (after appending chunk)
 * @param chunkContent The current streaming chunk
 * @param discoveryBlockIdx Character index where [DISCOVERY_COMPLETE] starts, or -1
 * @returns Portion of chunkContent visible to the client
 */
export function computeVisibleContent(
  fullContentLength: number,
  chunkContent: string,
  discoveryBlockIdx: number,
): string {
  if (discoveryBlockIdx === -1) return chunkContent;
  const chunkStart = fullContentLength - chunkContent.length;
  if (chunkStart >= discoveryBlockIdx) return '';
  if (chunkStart + chunkContent.length > discoveryBlockIdx) {
    return chunkContent.substring(0, discoveryBlockIdx - chunkStart);
  }
  return chunkContent;
}
