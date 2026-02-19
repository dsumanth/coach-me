import { createClient, SupabaseClient } from 'npm:@supabase/supabase-js@2.94.1';

/**
 * Typed error for authorization failures.
 * Allows catch blocks to use `instanceof` instead of brittle string matching.
 */
export class AuthorizationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'AuthorizationError';
  }
}

/**
 * Verify JWT and extract user ID
 * Per architecture.md: All Edge Functions verify JWT before processing
 */
export async function verifyAuth(req: Request): Promise<{ userId: string; supabase: SupabaseClient }> {
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    throw new AuthorizationError('Missing or invalid authorization header');
  }

  const bearerMatch = authHeader.match(/^Bearer\s+(.+)$/i);
  if (!bearerMatch) {
    throw new AuthorizationError('Missing or invalid authorization header');
  }

  const jwt = bearerMatch[1]?.trim();
  if (!jwt) {
    throw new AuthorizationError('Missing bearer token');
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  if (!supabaseUrl) {
    throw new Error('SUPABASE_URL environment variable is not configured');
  }

  // Validate the user JWT with a trusted server key.
  // Using service role avoids edge cases where client publishable keys
  // can fail auth.getUser(jwt) validation on edge runtime.
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const requestApiKey = req.headers.get('apikey');
  const verificationKey = serviceRoleKey || anonKey || requestApiKey;

  if (!verificationKey) {
    throw new Error('Missing API key for token verification');
  }

  const verificationClient = createClient(
    supabaseUrl,
    verificationKey,
    {
      auth: { persistSession: false },
    }
  );

  const { data: { user }, error } = await verificationClient.auth.getUser(jwt);

  if (error || !user) {
    console.error('Auth error:', error?.message, error?.status);
    throw new AuthorizationError(`Invalid or expired token: ${error?.message}`);
  }

  // Use a user-scoped client for DB access so RLS remains effective.
  const rlsKey = anonKey || requestApiKey || verificationKey;
  const supabase = createClient(
    supabaseUrl,
    rlsKey,
    {
      global: { headers: { Authorization: `Bearer ${jwt}` } },
      auth: { persistSession: false },
    }
  );

  return { userId: user.id, supabase };
}
