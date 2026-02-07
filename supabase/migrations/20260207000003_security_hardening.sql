-- Migration: 20260207000003_security_hardening.sql
-- Description: Security hardening fixes from code review
-- Author: Coach App Development Team
-- Date: 2026-02-07
--
-- Fixes:
--   1. Conversations UPDATE policy missing WITH CHECK
--   2. handle_new_user trigger: ON CONFLICT for idempotency
--   3. handle_new_user trigger: explicit search_path for SECURITY DEFINER
--   4. usage_logs FK references auth.users instead of public.users

-- ============================================================================
-- FIX 1: Conversations UPDATE policy - add WITH CHECK
-- Prevents user_id reassignment on update
-- ============================================================================
DROP POLICY IF EXISTS "Users can update own conversations" ON public.conversations;

CREATE POLICY "Users can update own conversations"
    ON public.conversations FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- ============================================================================
-- FIX 2 & 3: handle_new_user - ON CONFLICT + search_path
-- ON CONFLICT prevents failure if user row already exists
-- SET search_path prevents privilege escalation in SECURITY DEFINER
-- ============================================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.users (id, email, display_name, trial_ends_at)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email),
        NOW() + INTERVAL '7 days'
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_catalog;

-- ============================================================================
-- FIX 4: usage_logs FK - change from auth.users to public.users
-- Ensures consistent cascade behavior across all tables
-- ============================================================================
ALTER TABLE public.usage_logs DROP CONSTRAINT IF EXISTS usage_logs_user_id_fkey;

ALTER TABLE public.usage_logs
    ADD CONSTRAINT usage_logs_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;
