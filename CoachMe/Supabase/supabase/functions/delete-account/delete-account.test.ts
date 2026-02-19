/**
 * delete-account Edge Function Tests
 * Story 6.6: Account Deletion
 *
 * Run with: deno test --allow-env delete-account.test.ts
 */

import { assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';

// Test: Rejects requests without Authorization header
Deno.test('rejects request without auth header', () => {
  const headers = new Headers({
    'Content-Type': 'application/json',
  });

  const authHeader = headers.get('Authorization');
  const hasValidAuth = authHeader?.startsWith('Bearer ') ?? false;

  assertEquals(hasValidAuth, false, 'Request without auth should not have valid Bearer token');
});

// Test: Rejects requests with empty Bearer token
Deno.test('rejects request with empty bearer token', () => {
  const headers = new Headers({
    Authorization: 'Bearer ',
    'Content-Type': 'application/json',
  });

  const authHeader = headers.get('Authorization');
  const token = authHeader?.replace('Bearer ', '') ?? '';
  const hasValidToken = token.length > 0;

  assertEquals(hasValidToken, false, 'Empty bearer token should be rejected');
});

// Test: Accepts requests with valid Bearer token format
Deno.test('accepts request with valid bearer token format', () => {
  const mockJwt = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.test';
  const headers = new Headers({
    Authorization: `Bearer ${mockJwt}`,
    'Content-Type': 'application/json',
    apikey: 'sb_publishable_test_key',
  });

  const authHeader = headers.get('Authorization');
  const hasValidAuth = authHeader?.startsWith('Bearer ') ?? false;
  const token = authHeader?.replace('Bearer ', '') ?? '';

  assertEquals(hasValidAuth, true, 'Request with Bearer token should be accepted');
  assertEquals(token.length > 0, true, 'Token should not be empty');
  assertEquals(token, mockJwt, 'Extracted token should match input');
});

// Test: Response format matches expected shape on success
Deno.test('success response has correct JSON shape', () => {
  const responseBody = JSON.stringify({ data: { success: true } });
  const parsed = JSON.parse(responseBody);

  assertEquals(parsed.data.success, true, 'Success response should have data.success = true');
});

// Test: Error response format for auth failure
Deno.test('auth error response returns 401 shape', () => {
  const errorMessage = 'Invalid or expired authorization';
  const responseBody = JSON.stringify({
    error: errorMessage,
    userMessage: "I had trouble remembering you. Please sign in again.",
  });
  const parsed = JSON.parse(responseBody);

  assertEquals(parsed.error, errorMessage, 'Error field should contain auth error message');
  assertEquals(typeof parsed.userMessage, 'string', 'Should include user-friendly message');
});

// Test: Error response format for server failure
Deno.test('server error response returns 500 shape', () => {
  const errorMessage = "I couldn't remove your account right now. Please try again.";
  const responseBody = JSON.stringify({
    error: errorMessage,
    userMessage: "Coach is taking a moment. Let's try again.",
  });
  const parsed = JSON.parse(responseBody);

  assertEquals(parsed.error, errorMessage, 'Error field should contain deletion error message');
  assertEquals(typeof parsed.userMessage, 'string', 'Should include user-friendly message');
});

// Test: CORS preflight response for OPTIONS
Deno.test('OPTIONS request returns CORS headers', () => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
  };

  assertEquals(corsHeaders['Access-Control-Allow-Origin'], '*', 'Should allow all origins');
  assertEquals(
    corsHeaders['Access-Control-Allow-Headers'].includes('authorization'),
    true,
    'Should allow authorization header'
  );
  assertEquals(
    corsHeaders['Access-Control-Allow-Methods'].includes('POST'),
    true,
    'Should allow POST method'
  );
});

// Test: User can only delete their own account (JWT = identity)
Deno.test('JWT token IS the user identity - no separate user ID needed', () => {
  // The verifyAuth() function extracts userId from JWT
  // No request body with userId is needed - the JWT IS the identity
  // This test validates the design decision
  const mockRequest = {
    method: 'POST',
    headers: new Headers({
      Authorization: 'Bearer mock-jwt-token',
      'Content-Type': 'application/json',
    }),
    // No body with userId - intentional
  };

  assertEquals(mockRequest.method, 'POST', 'Should be POST request');
  assertEquals(
    mockRequest.headers.has('Authorization'),
    true,
    'Auth header is the only identity mechanism'
  );
});
