/**
 * prompt-sanitizer.ts
 *
 * Shared safeguards for injecting untrusted user-derived text into prompts.
 * These helpers preserve semantic meaning while neutralizing common
 * prompt-control patterns (role spoofing, control tags, fenced blocks).
 */

const CONTROL_CHARS_REGEX = /[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/g;
const RESERVED_TAG_REGEX =
  /\[(\/?)(MEMORY|PATTERN|DISCOVERY_COMPLETE|REFLECTION_ACCEPTED|REFLECTION_DECLINED)\b([^\]]*)\]/gi;
const ROLE_PREFIX_REGEX = /^(\s*)(system|assistant|user)\s*:/gim;

/**
 * Sanitize untrusted prompt text while retaining user meaning.
 *
 * @param input - Raw user-derived text
 * @param maxLength - Maximum output length before truncation
 * @returns Sanitized text safe for prompt interpolation
 */
export function sanitizeUntrustedPromptText(
  input: string,
  maxLength: number = 1200,
): string {
  if (!input) return '';

  let cleaned = input
    .replace(/\r\n?/g, '\n')
    .replace(CONTROL_CHARS_REGEX, ' ')
    .replace(/```/g, "'''")
    .replace(ROLE_PREFIX_REGEX, '$1$2 (quoted):')
    .replace(RESERVED_TAG_REGEX, '($1$2$3)')
    .replace(/\n{3,}/g, '\n\n')
    .trim();

  if (cleaned.length > maxLength) {
    const safeLength = Math.max(maxLength - 12, 0);
    cleaned = `${cleaned.slice(0, safeLength).trimEnd()} [truncated]`;
  }

  return cleaned;
}

