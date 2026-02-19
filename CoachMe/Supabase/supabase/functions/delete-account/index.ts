import { createClient } from 'npm:@supabase/supabase-js@2.94.1';
import { handleCors, corsHeaders } from '../_shared/cors.ts';
import { verifyAuth, AuthorizationError } from '../_shared/auth.ts';
import { errorResponse } from '../_shared/response.ts';

/**
 * Account Deletion Edge Function (Story 6.6)
 *
 * Deletes the authenticated user's account using admin privileges.
 * The CASCADE chain on auth.users removes all related data:
 *   auth.users → public.users → conversations → messages → usage_logs
 *                             → context_profiles → pattern_syntheses
 *
 * Requires: SUPABASE_SERVICE_ROLE_KEY (admin operations)
 * Auth: JWT Bearer token (user can only delete their own account)
 */
Deno.serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const { userId } = await verifyAuth(req);

    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!supabaseUrl || !serviceRoleKey) {
      throw new Error('Server configuration missing');
    }

    // Admin client with service role key for auth.admin operations
    const adminSupabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false },
    });

    const { error } = await adminSupabase.auth.admin.deleteUser(userId);
    if (error) throw error;

    console.log(`Account deleted: ${userId}`);

    return new Response(
      JSON.stringify({ data: { success: true } }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  } catch (error) {
    console.error('Account deletion failed:', error);

    if (error instanceof AuthorizationError) {
      return errorResponse('Invalid or expired authorization', 401);
    }

    return errorResponse(
      "I couldn't remove your account right now. Please try again.",
      500
    );
  }
});
