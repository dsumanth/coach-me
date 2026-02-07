-- Migration: 20260205000003_user_sync_trigger.sql
-- Description: Auto-create public.users row when auth.users row is created
-- Author: Coach App Development Team
-- Date: 2026-02-05
--
-- This trigger ensures that when a user signs up via Supabase Auth,
-- a corresponding row is automatically created in public.users with
-- app-specific defaults (trial subscription, 7-day trial period).

-- ============================================================================
-- USER SYNC FUNCTION
-- Creates a public.users row when a new auth.users row is inserted
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

-- SECURITY DEFINER: This function runs with elevated privileges because
-- it needs to insert into public.users on behalf of the new auth user.
-- This is necessary since RLS would otherwise prevent the insert.

-- ============================================================================
-- TRIGGER ON AUTH.USERS
-- Fires after a new user signs up
-- ============================================================================
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================================
-- VERIFICATION
-- ============================================================================
-- To test: Sign up a new user via the app or Supabase Auth UI
-- Then verify: SELECT * FROM public.users;

COMMENT ON FUNCTION public.handle_new_user() IS 'Syncs new auth.users to public.users with app defaults';
