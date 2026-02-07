import { createClient, SupabaseClient } from 'npm:@supabase/supabase-js@2.94.1';

/**
 * Verify JWT and extract user ID
 * Per architecture.md: All Edge Functions verify JWT before processing
 */
export async function verifyAuth(req: Request): Promise<{ userId: string; supabase: SupabaseClient }> {
  const authHeader = req.headers.get('Authorization');
  if (!authHeader?.startsWith('Bearer ')) {
    throw new Error('Missing or invalid authorization header');
  }

  const jwt = authHeader.replace('Bearer ', '');

  // Use apikey from request header to support new publishable key format
  // See: https://github.com/supabase/supabase/issues/37648
  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
  const supabaseKey = req.headers.get('apikey') || (Deno.env.get('SUPABASE_ANON_KEY') ?? '');

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
    throw new Error(`Invalid or expired token: ${error?.message}`);
  }

  return { userId: user.id, supabase };
}
