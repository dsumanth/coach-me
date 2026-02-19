-- Migration: 20260210000009_fix_deployed_migrations.sql
-- Description: Corrective fixes for CodeRabbit review items on already-deployed migrations
-- Author: Coach App Development Team
-- Date: 2026-02-10

-- ============================================================================
-- Fix 1: push_log FK should reference public.users, not auth.users (from 000006)
-- The original migration used auth.users(id) but our schema uses public.users
-- ============================================================================
ALTER TABLE public.push_log DROP CONSTRAINT IF EXISTS push_log_user_id_fkey;
ALTER TABLE public.push_log
    ADD CONSTRAINT push_log_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

-- ============================================================================
-- Fix 2: push_log service role policy — use TO clause instead of deprecated auth.role()
-- ============================================================================
DROP POLICY IF EXISTS "Service role manages push logs" ON public.push_log;
CREATE POLICY "Service role manages push logs"
    ON public.push_log FOR ALL
    TO service_role
    USING (true);

-- ============================================================================
-- Fix 3: pattern_cache missing DELETE RLS policy (from 000005)
-- ============================================================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE tablename = 'pattern_cache'
        AND policyname = 'Users can delete own pattern cache'
    ) THEN
        CREATE POLICY "Users can delete own pattern cache"
            ON public.pattern_cache FOR DELETE
            USING (auth.uid() = user_id);
    END IF;
END $$;

-- ============================================================================
-- Fix 4: notification_preferences comments used unqualified table name (from 000004)
-- Re-apply comments with public. prefix (harmless if already correct)
-- ============================================================================
COMMENT ON COLUMN public.context_profiles.notification_preferences IS
    'User notification preferences (check-in toggle, frequency)';
