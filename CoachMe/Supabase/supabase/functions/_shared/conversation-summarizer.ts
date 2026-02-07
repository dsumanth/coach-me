/**
 * conversation-summarizer.ts
 *
 * Story 3.3: Cross-Session Memory References
 * Simple conversation summary extraction — NO LLM calls.
 * Takes last messages from a conversation and produces a brief ~80 char summary.
 */

/** Message shape from database query */
interface MessageRow {
  role: string;
  content: string;
}

/**
 * Create a brief summary of a conversation from its messages.
 *
 * Uses simple text extraction (no LLM call) to keep latency low and cost zero.
 * Extracts the user's last message topic as the primary summary content.
 *
 * @param messages - Last few messages from the conversation (ordered newest first from DB)
 * @param title - Optional conversation title
 * @param domain - Optional coaching domain (e.g., 'career', 'relationships')
 * @returns Summary string, truncated to ~80 characters
 */
export function summarizeConversation(
  messages: MessageRow[],
  title?: string | null,
  domain?: string | null,
): string {
  const MAX_LENGTH = 80;

  // Find the most recent user message for topic extraction.
  // Messages are ordered newest-first from the DB.
  const userMessages = messages.filter((m) => m.role === 'user');
  const lastUserMessage = userMessages.length > 0
    ? userMessages[0].content
    : null;

  // Build domain prefix
  const domainPrefix = domain
    ? `${domain.charAt(0).toUpperCase() + domain.slice(1)}: `
    : '';

  // Priority: last user message topic > title > generic fallback
  let summary: string;

  if (lastUserMessage) {
    // Extract a brief topic from the user's last message
    const topic = lastUserMessage.trim();
    summary = `${domainPrefix}${topic}`;
  } else if (title) {
    summary = `${domainPrefix}${title}`;
  } else {
    summary = `${domainPrefix}General coaching conversation`;
  }

  // Truncate to ~80 chars, breaking at word boundary
  if (summary.length > MAX_LENGTH) {
    const truncated = summary.substring(0, MAX_LENGTH - 3);
    const lastSpace = truncated.lastIndexOf(' ');
    summary = lastSpace > MAX_LENGTH / 2
      ? truncated.substring(0, lastSpace) + '...'
      : truncated + '...';
  }

  return summary;
}
