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
  if (!authHeader?.startsWith('Bearer ')) {
    throw new AuthorizationError('Missing or invalid authorization header');
  }

  const jwt = authHeader.replace('Bearer ', '');

  // Use apikey from request header to support new publishable key format
  // See: https://github.com/supabase/supabase/issues/37648
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  if (!supabaseUrl) {
    throw new Error('SUPABASE_URL environment variable is not configured');
  }
  const supabaseKey = req.headers.get('apikey') || Deno.env.get('SUPABASE_ANON_KEY');
  if (!supabaseKey) {
    throw new Error('Missing API key: neither apikey header nor SUPABASE_ANON_KEY is set');
  }

  const supabase = createClient(
    supabaseUrl,
    supabaseKey,
    {
      global: { headers: { Authorization: `Bearer ${jwt}` } },
      auth: { persistSession: false },
    }
  );

  const { data: { user }, error } = await supabase.auth.getUser(jwt);

  if (error || !user) {
    console.error('Auth error:', error?.message, error?.status);
    throw new AuthorizationError(`Invalid or expired token: ${error?.message}`);
  }

  return { userId: user.id, supabase };
}
