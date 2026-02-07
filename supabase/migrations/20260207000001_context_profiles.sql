-- Migration: 20260207000001_context_profiles.sql
-- Description: Create context_profiles table for user context storage (Epic 2)
-- Author: Coach App Development Team
-- Date: 2026-02-07
--
-- Stores the user's coaching context: values, goals, life situation, and
-- AI-extracted insights. All complex nested data stored as JSONB columns.
-- One profile per user (unique constraint on user_id).

-- ============================================================================
-- CONTEXT_PROFILES TABLE
-- Stores user coaching context for personalized responses
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.context_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    values JSONB DEFAULT '[]'::jsonb,
    goals JSONB DEFAULT '[]'::jsonb,
    situation JSONB DEFAULT '{}'::jsonb,
    extracted_insights JSONB DEFAULT '[]'::jsonb,
    context_version INTEGER DEFAULT 1,
    first_session_complete BOOLEAN DEFAULT false,
    prompt_dismissed_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- One profile per user
    CONSTRAINT context_profiles_user_id_unique UNIQUE (user_id)
);

-- Enable Row Level Security (CRITICAL)
ALTER TABLE public.context_profiles ENABLE ROW LEVEL SECURITY;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_context_profiles_user_id ON public.context_profiles(user_id);

-- Comments
COMMENT ON TABLE public.context_profiles IS 'User coaching context profiles with values, goals, situation, and extracted insights';
COMMENT ON COLUMN public.context_profiles.values IS 'JSONB array of ContextValue objects: [{id, content, source, confidence, added_at}]';
COMMENT ON COLUMN public.context_profiles.goals IS 'JSONB array of ContextGoal objects: [{id, content, domain, source, status, added_at}]';
COMMENT ON COLUMN public.context_profiles.situation IS 'JSONB object of ContextSituation: {life_stage, occupation, relationships, challenges, freeform}';
COMMENT ON COLUMN public.context_profiles.extracted_insights IS 'JSONB array of ExtractedInsight objects: [{id, content, category, confidence, source_conversation_id, confirmed, extracted_at}]';
COMMENT ON COLUMN public.context_profiles.context_version IS 'Schema version for forward compatibility';
COMMENT ON COLUMN public.context_profiles.first_session_complete IS 'Whether the user has completed their first coaching session';
COMMENT ON COLUMN public.context_profiles.prompt_dismissed_count IS 'Number of times user dismissed the context setup prompt';

-- Apply updated_at trigger (function already exists from initial_schema migration)
DROP TRIGGER IF EXISTS context_profiles_updated_at ON public.context_profiles;
CREATE TRIGGER context_profiles_updated_at
    BEFORE UPDATE ON public.context_profiles
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ============================================================================
-- ROW LEVEL SECURITY POLICIES
-- Users can only access their own context profile
-- ============================================================================

-- Drop any existing policies (from earlier migration 20260206000003 or prior runs)
DROP POLICY IF EXISTS "Users can view own context profile" ON public.context_profiles;
DROP POLICY IF EXISTS "Users can insert own context profile" ON public.context_profiles;
DROP POLICY IF EXISTS "Users can create own context profile" ON public.context_profiles;
DROP POLICY IF EXISTS "Users can update own context profile" ON public.context_profiles;
DROP POLICY IF EXISTS "Users can delete own context profile" ON public.context_profiles;

CREATE POLICY "Users can view own context profile"
    ON public.context_profiles FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can create own context profile"
    ON public.context_profiles FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own context profile"
    ON public.context_profiles FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own context profile"
    ON public.context_profiles FOR DELETE
    USING (auth.uid() = user_id);
