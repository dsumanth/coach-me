/**
 * push-send Edge Function (Story 8.2)
 *
 * Sends push notifications to a user's registered devices via APNs HTTP/2.
 *
 * Auth modes:
 *   1. Service-role key — server-to-server (e.g., push-trigger, scheduled functions).
 *      Can send to any user_id, no rate limits.
 *   2. User JWT — "send test push" in non-production only.
 *      JWT userId must match payload user_id. Rate-limited to 10/hour.
 *
 * Required secrets:
 *   APNS_KEY_ID, APNS_TEAM_ID, APNS_PRIVATE_KEY, APNS_BUNDLE_ID,
 *   APNS_ENVIRONMENT (sandbox | production),
 *   SUPABASE_SERVICE_ROLE_KEY
 */

import { createClient } from "npm:@supabase/supabase-js@2.94.1";
import { handleCors, corsHeaders } from "../_shared/cors.ts";
import { errorResponse } from "../_shared/response.ts";
import { SignJWT, importPKCS8 } from "npm:jose@5.9.6";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface PushRequest {
  user_id: string;
  title: string;
  body: string;
  data?: {
    conversation_id?: string;
    domain?: string;
    action?: string;
  };
}

interface PushToken {
  id: string;
  device_token: string;
}

// ---------------------------------------------------------------------------
// APNs JWT cache (valid for up to 50 min to stay under APNs 60 min limit)
// ---------------------------------------------------------------------------

let cachedJwt: string | null = null;
let cachedJwtExpiry = 0;

async function getApnsJwt(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedJwt && now < cachedJwtExpiry) return cachedJwt;

  const keyId = Deno.env.get("APNS_KEY_ID");
  const teamId = Deno.env.get("APNS_TEAM_ID");
  const privateKeyPem = Deno.env.get("APNS_PRIVATE_KEY");

  if (!keyId || !teamId || !privateKeyPem) {
    throw new Error("APNs credentials not configured");
  }

  const privateKey = await importPKCS8(privateKeyPem, "ES256");

  const jwt = await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: keyId })
    .setIssuer(teamId)
    .setIssuedAt(now)
    .sign(privateKey);

  cachedJwt = jwt;
  cachedJwtExpiry = now + 50 * 60; // refresh 10 min before APNs deadline
  return jwt;
}

// ---------------------------------------------------------------------------
// APNs send
// ---------------------------------------------------------------------------

const APNS_HOSTS: Record<string, string> = {
  sandbox: "https://api.sandbox.push.apple.com",
  production: "https://api.push.apple.com",
};

interface ApnsSendResult {
  token: string;
  success: boolean;
  reason?: string;
  statusCode?: number;
}

async function sendToApns(
  deviceToken: string,
  payload: object
): Promise<ApnsSendResult> {
  const env = Deno.env.get("APNS_ENVIRONMENT") ?? "sandbox";
  const bundleId = Deno.env.get("APNS_BUNDLE_ID");
  if (!bundleId) throw new Error("APNS_BUNDLE_ID not configured");

  const jwt = await getApnsJwt();
  const url = `${APNS_HOSTS[env] ?? APNS_HOSTS.sandbox}/3/device/${deviceToken}`;

  const res = await fetch(url, {
    method: "POST",
    headers: {
      authorization: `bearer ${jwt}`,
      "apns-topic": bundleId,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "content-type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  if (res.ok) {
    return { token: deviceToken, success: true };
  }

  const body = await res.json().catch(() => ({}));
  return {
    token: deviceToken,
    success: false,
    reason: body?.reason ?? "unknown",
    statusCode: res.status,
  };
}

// ---------------------------------------------------------------------------
// Auth helpers
// ---------------------------------------------------------------------------

function isServiceRoleRequest(req: Request): boolean {
  const authHeader = req.headers.get("Authorization");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  return !!serviceRoleKey && authHeader === `Bearer ${serviceRoleKey}`;
}

async function verifyUserJwt(
  req: Request
): Promise<{ userId: string }> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    throw new Error("Missing authorization header");
  }
  const jwt = authHeader.replace("Bearer ", "");

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const supabaseKey =
    req.headers.get("apikey") ?? Deno.env.get("SUPABASE_ANON_KEY")!;
  const supabase = createClient(supabaseUrl, supabaseKey, {
    global: { headers: { Authorization: `Bearer ${jwt}` } },
    auth: { persistSession: false },
  });

  const {
    data: { user },
    error,
  } = await supabase.auth.getUser(jwt);
  if (error || !user) throw new Error("Invalid or expired token");
  return { userId: user.id };
}

// ---------------------------------------------------------------------------
// Rate limiting (in-memory, per-invocation lifetime)
// ---------------------------------------------------------------------------

// KNOWN LIMITATION: In-memory rate limiting provides warm-instance protection
// only. Deno Edge Functions are stateless — the map resets on each cold start.
// This is acceptable because user-JWT requests are gated to non-production
// environments (dev/sandbox test-push only). For production user-facing rate
// limiting, replace with a persistent store (e.g., Supabase table or KV).
const rateLimitMap = new Map<string, number[]>();
const RATE_LIMIT_MAX = 10;
const RATE_LIMIT_WINDOW_MS = 60 * 60 * 1000; // 1 hour

function checkRateLimit(userId: string): boolean {
  const now = Date.now();
  const timestamps = (rateLimitMap.get(userId) ?? []).filter(
    (t) => now - t < RATE_LIMIT_WINDOW_MS
  );
  if (timestamps.length >= RATE_LIMIT_MAX) return false;
  timestamps.push(now);
  rateLimitMap.set(userId, timestamps);
  return true;
}

// ---------------------------------------------------------------------------
// Main handler
// ---------------------------------------------------------------------------

Deno.serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    // ── Auth branching ──
    const serviceRole = isServiceRoleRequest(req);
    let authedUserId: string | null = null;

    if (!serviceRole) {
      const { userId } = await verifyUserJwt(req);
      authedUserId = userId;

      // Gate user-JWT requests to non-production
      const apnsEnv = Deno.env.get("APNS_ENVIRONMENT") ?? "sandbox";
      if (apnsEnv === "production") {
        return errorResponse(
          "Test push is only available in development environments.",
          403
        );
      }
    }

    // ── Parse request body ──
    const payload: PushRequest = await req.json();
    if (!payload.user_id || !payload.title || !payload.body) {
      return errorResponse("Missing required fields: user_id, title, body", 400);
    }

    // Validate user_id is a well-formed UUID
    const UUID_REGEX =
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    if (!UUID_REGEX.test(payload.user_id)) {
      return errorResponse("Invalid user_id format — must be a valid UUID", 400);
    }

    // ── User-JWT restrictions ──
    if (authedUserId) {
      if (authedUserId !== payload.user_id) {
        return errorResponse("You can only send test pushes to yourself.", 403);
      }
      if (!checkRateLimit(authedUserId)) {
        return errorResponse(
          "Rate limit reached — max 10 test pushes per hour.",
          429
        );
      }
    }

    // ── Look up device tokens ──
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceRoleKey) {
      const missing = [
        !supabaseUrl && "SUPABASE_URL",
        !serviceRoleKey && "SUPABASE_SERVICE_ROLE_KEY",
      ].filter(Boolean).join(", ");
      console.error(`push-send: Missing required env vars: ${missing}`);
      return new Response(
        JSON.stringify({ error: `Missing configuration: ${missing}` }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }
    const adminSupabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false },
    });

    const { data: tokens, error: fetchError } = await adminSupabase
      .from("push_tokens")
      .select("id, device_token")
      .eq("user_id", payload.user_id);

    if (fetchError) throw fetchError;
    if (!tokens || tokens.length === 0) {
      return new Response(
        JSON.stringify({
          success: true,
          sent: 0,
          message: "No registered devices for this user.",
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // ── Build APNs payload ──
    const apnsPayload = {
      aps: {
        alert: { title: payload.title, body: payload.body },
        sound: "default",
        badge: 1,
      },
      ...(payload.data ?? {}),
    };

    // ── Send to all device tokens ──
    const results = await Promise.all(
      (tokens as PushToken[]).map((t) => sendToApns(t.device_token, apnsPayload))
    );

    // ── Clean up invalid tokens ──
    const invalidTokens = results.filter(
      (r) =>
        !r.success &&
        (r.reason === "BadDeviceToken" ||
          r.reason === "Unregistered" ||
          r.reason === "ExpiredToken" ||
          r.statusCode === 410)
    );

    if (invalidTokens.length > 0) {
      const staleTokenValues = invalidTokens.map((r) => r.token);
      const { error: deleteError } = await adminSupabase
        .from("push_tokens")
        .delete()
        .eq("user_id", payload.user_id)
        .in("device_token", staleTokenValues);

      if (deleteError) {
        console.error("Failed to delete stale tokens:", deleteError);
      } else {
        console.log(
          `Deleted ${staleTokenValues.length} stale token(s) for user ${payload.user_id}`
        );
      }
    }

    // ── Response summary ──
    const sent = results.filter((r) => r.success).length;
    const failed = results.filter((r) => !r.success).length;

    return new Response(
      JSON.stringify({
        success: true,
        sent,
        failed,
        stale_tokens_removed: invalidTokens.length,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("push-send error:", error);
    return errorResponse(
      "I couldn't send the notification right now. Please try again.",
      500
    );
  }
});
