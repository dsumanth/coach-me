-- Migration: 20260211000003_fix_user_resync_trigger.sql
-- Description: Fix user sync trigger to handle re-signups after account deletion
-- Author: Coach App Development Team
-- Date: 2026-02-10
--
-- Problem: When a user deletes their account and signs back in with the same
-- Apple ID, Supabase Auth may UPDATE the existing auth.users row instead of
-- creating a new INSERT. The handle_new_user trigger only fires on INSERT,
-- so no public.users row is created for the returning user. This causes
-- FK violations when trying to create conversations.
--
-- Fix: Replace the INSERT-only trigger with an INSERT OR UPDATE trigger
-- and use ON CONFLICT ... DO UPDATE to re-create the public.users row
-- if it was CASCADE-deleted.

-- ============================================================================
-- UPDATED USER SYNC FUNCTION
-- Handles both new signups (INSERT) and re-signups after deletion (UPDATE)
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
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        display_name = COALESCE(EXCLUDED.display_name, public.users.display_name),
        updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_catalog;

-- ============================================================================
-- REPLACE TRIGGER: Fire on both INSERT and UPDATE
-- INSERT covers new signups, UPDATE covers re-signups after account deletion
-- ============================================================================
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT OR UPDATE ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================================
-- BACKFILL: Create public.users rows for any auth.users that are missing them
-- This fixes the current broken state immediately
-- ============================================================================
INSERT INTO public.users (id, email, display_name, trial_ends_at)
SELECT
    au.id,
    au.email,
    COALESCE(au.raw_user_meta_data->>'full_name', au.email),
    NOW() + INTERVAL '7 days'
FROM auth.users au
LEFT JOIN public.users pu ON au.id = pu.id
WHERE pu.id IS NULL
ON CONFLICT (id) DO NOTHING;
