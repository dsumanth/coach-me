import { corsHeaders } from './cors.ts';

/**
 * Standardized error response
 * Per architecture.md: Warm, first-person error messages
 */
export function errorResponse(message: string, status = 400): Response {
  return new Response(
    JSON.stringify({
      error: message,
      // User-friendly message for client display
      userMessage: getWarmErrorMessage(message)
    }),
    {
      status,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    }
  );
}

function getWarmErrorMessage(error: string): string {
  if (error.includes('authorization') || error.includes('token')) {
    return "I had trouble remembering you. Please sign in again.";
  }
  if (error.includes('rate') || error.includes('limit')) {
    return "Let's take a breath. You can continue in a moment.";
  }
  return "Coach is taking a moment. Let's try again.";
}

/**
 * SSE headers for streaming responses
 */
export const sseHeaders = {
  ...corsHeaders,
  'Content-Type': 'text/event-stream',
  'Cache-Control': 'no-cache',
  'Connection': 'keep-alive',
};
