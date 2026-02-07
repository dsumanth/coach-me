-- Migration: 20260206000003_context_profiles.sql
-- Description: Create context_profiles table for storing user context (values, goals, situation)
-- Author: Coach App Development Team
-- Date: 2026-02-06
-- Story: 2.1 - Context Profile Data Model & Storage

-- ============================================================================
-- CONTEXT_PROFILES TABLE
-- Stores user's personal context for personalized coaching
-- JSONB columns provide flexible schema for values, goals, and situation
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.context_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,

    -- JSONB arrays for flexible context storage
    values JSONB DEFAULT '[]'::jsonb,              -- Array of ContextValue objects
    goals JSONB DEFAULT '[]'::jsonb,               -- Array of ContextGoal objects
    situation JSONB DEFAULT '{}'::jsonb,           -- ContextSituation object
    extracted_insights JSONB DEFAULT '[]'::jsonb,  -- Array of ExtractedInsight objects

    -- Context versioning and state tracking
    context_version INTEGER DEFAULT 1,
    first_session_complete BOOLEAN DEFAULT false,
    prompt_dismissed_count INTEGER DEFAULT 0,

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Ensure one profile per user
    UNIQUE(user_id)
);

-- Enable Row Level Security (CRITICAL: Must be enabled)
ALTER TABLE public.context_profiles ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- ROW LEVEL SECURITY POLICIES
-- Users can only access their own context profile
-- ============================================================================
DROP POLICY IF EXISTS "Users can view own context profile" ON public.context_profiles;
CREATE POLICY "Users can view own context profile"
    ON public.context_profiles FOR SELECT
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own context profile" ON public.context_profiles;
CREATE POLICY "Users can insert own context profile"
    ON public.context_profiles FOR INSERT
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own context profile" ON public.context_profiles;
CREATE POLICY "Users can update own context profile"
    ON public.context_profiles FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own context profile" ON public.context_profiles;
CREATE POLICY "Users can delete own context profile"
    ON public.context_profiles FOR DELETE
    USING (auth.uid() = user_id);

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_context_profiles_user_id
    ON public.context_profiles(user_id);

CREATE INDEX IF NOT EXISTS idx_context_profiles_updated_at
    ON public.context_profiles(updated_at DESC);

-- ============================================================================
-- UPDATED_AT TRIGGER
-- Automatically updates updated_at timestamp on row updates
-- ============================================================================
DROP TRIGGER IF EXISTS context_profiles_updated_at ON public.context_profiles;
CREATE TRIGGER context_profiles_updated_at
    BEFORE UPDATE ON public.context_profiles
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ============================================================================
-- TABLE AND COLUMN COMMENTS
-- ============================================================================
COMMENT ON TABLE public.context_profiles IS 'User context profile for personalized coaching - stores values, goals, and life situation';
COMMENT ON COLUMN public.context_profiles.values IS 'JSONB array of ContextValue objects: {id, content, source, confidence?, addedAt}';
COMMENT ON COLUMN public.context_profiles.goals IS 'JSONB array of ContextGoal objects: {id, content, domain?, source, status, addedAt}';
COMMENT ON COLUMN public.context_profiles.situation IS 'JSONB ContextSituation object: {lifeStage?, occupation?, relationships?, challenges?, freeform?}';
COMMENT ON COLUMN public.context_profiles.extracted_insights IS 'JSONB array of insights extracted from conversations';
COMMENT ON COLUMN public.context_profiles.context_version IS 'Schema version for migrations';
COMMENT ON COLUMN public.context_profiles.first_session_complete IS 'Flag indicating user completed first coaching session';
COMMENT ON COLUMN public.context_profiles.prompt_dismissed_count IS 'Number of times user dismissed context setup prompt';

-- ============================================================================
-- VERIFICATION QUERIES (run after migration to verify)
-- ============================================================================
-- SELECT * FROM information_schema.tables WHERE table_name = 'context_profiles';
-- SELECT * FROM information_schema.columns WHERE table_name = 'context_profiles';
-- SELECT tablename, rowsecurity FROM pg_tables WHERE tablename = 'context_profiles';
-- SELECT * FROM pg_policies WHERE tablename = 'context_profiles';
