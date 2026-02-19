-- Story 10.1: Message Usage Rate Limiting Infrastructure
-- Creates the message_usage table, RPC function, RLS policies, and indexes
-- for per-user message rate limiting by billing period.

-- ── Table: message_usage ──
CREATE TABLE IF NOT EXISTS public.message_usage (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  billing_period TEXT NOT NULL,  -- 'YYYY-MM' for paid, 'trial' for trial
  message_count INTEGER NOT NULL DEFAULT 0,
  limit_amount INTEGER NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- One row per user per billing period
  CONSTRAINT message_usage_user_period_unique UNIQUE (user_id, billing_period)
);

-- Index for fast lookups by user + period (covers the unique constraint)
CREATE INDEX IF NOT EXISTS idx_message_usage_user_period
  ON public.message_usage (user_id, billing_period);

-- ── RLS ──
ALTER TABLE public.message_usage ENABLE ROW LEVEL SECURITY;

-- Users can read their own usage (for UI display)
CREATE POLICY "Users can view own usage"
  ON public.message_usage FOR SELECT
  USING (auth.uid() = user_id);

-- No direct INSERT/UPDATE — all writes go through the RPC function (SECURITY DEFINER)

-- ── RPC: increment_and_check_usage ──
-- Atomic check-before-increment pattern:
-- 1. Upsert row (create if not exists)
-- 2. Check if at/over limit BEFORE incrementing
-- 3. Only increment if under limit
-- Returns JSONB: { allowed, current_count, limit, remaining }
CREATE OR REPLACE FUNCTION public.increment_and_check_usage(
  p_user_id UUID,
  p_billing_period TEXT,
  p_limit INTEGER
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog, pg_temp
AS $$
DECLARE
  v_current_count INTEGER;
BEGIN
  -- Upsert: create row if not exists, lock existing row
  INSERT INTO message_usage (user_id, billing_period, message_count, limit_amount, updated_at)
  VALUES (p_user_id, p_billing_period, 0, p_limit, NOW())
  ON CONFLICT (user_id, billing_period)
  DO UPDATE SET updated_at = NOW()
  RETURNING message_count INTO v_current_count;

  -- Check BEFORE incrementing
  IF v_current_count >= p_limit THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'current_count', v_current_count,
      'limit', p_limit,
      'remaining', 0
    );
  END IF;

  -- Increment
  UPDATE message_usage
  SET message_count = message_count + 1, updated_at = NOW()
  WHERE user_id = p_user_id AND billing_period = p_billing_period;

  RETURN jsonb_build_object(
    'allowed', true,
    'current_count', v_current_count + 1,
    'limit', p_limit,
    'remaining', p_limit - (v_current_count + 1)
  );
END;
$$;
