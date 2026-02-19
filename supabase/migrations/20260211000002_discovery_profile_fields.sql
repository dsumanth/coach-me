-- Migration: 20260211000002_discovery_profile_fields.sql
-- Description: Add discovery session fields to context_profiles for onboarding pipeline
-- Author: Coach App Development Team
-- Date: 2026-02-10
-- Story: 11.4 - Discovery-to-Profile Pipeline

-- ============================================================================
-- ADD DISCOVERY FIELDS TO CONTEXT_PROFILES
-- These fields store the context extracted during the discovery onboarding session.
-- All fields are nullable for backward compatibility with existing users.
-- ============================================================================
ALTER TABLE public.context_profiles
  ADD COLUMN IF NOT EXISTS discovery_completed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS aha_insight TEXT,
  ADD COLUMN IF NOT EXISTS coaching_domains JSONB DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS current_challenges JSONB DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS emotional_baseline TEXT,
  ADD COLUMN IF NOT EXISTS communication_style TEXT,
  ADD COLUMN IF NOT EXISTS key_themes JSONB DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS strengths_identified JSONB DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS vision TEXT,
  ADD COLUMN IF NOT EXISTS raw_discovery_data JSONB;

-- ============================================================================
-- INDEX: Partial index on discovery_completed_at for efficient lookup
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_context_profiles_discovery
  ON public.context_profiles(discovery_completed_at)
  WHERE discovery_completed_at IS NOT NULL;

-- ============================================================================
-- COLUMN COMMENTS
-- ============================================================================
COMMENT ON COLUMN public.context_profiles.discovery_completed_at IS 'Timestamp when discovery session completed and profile was extracted';
COMMENT ON COLUMN public.context_profiles.aha_insight IS 'Key synthesized insight from discovery conversation (Phase 4 peak moment)';
COMMENT ON COLUMN public.context_profiles.coaching_domains IS 'Array of coaching domains identified: ["career","relationships","mindset",...]';
COMMENT ON COLUMN public.context_profiles.current_challenges IS 'Array of specific challenges in user own words';
COMMENT ON COLUMN public.context_profiles.emotional_baseline IS 'General emotional state/pattern observed during discovery';
COMMENT ON COLUMN public.context_profiles.communication_style IS 'Preferred communication style: direct/gentle, analytical/emotional';
COMMENT ON COLUMN public.context_profiles.key_themes IS 'Recurring topics and patterns from the conversation';
COMMENT ON COLUMN public.context_profiles.strengths_identified IS 'Strengths the coach noticed during discovery';
COMMENT ON COLUMN public.context_profiles.vision IS 'User ideal future in their own words';
COMMENT ON COLUMN public.context_profiles.raw_discovery_data IS 'Complete JSON extraction from AI for audit/debugging';

-- ============================================================================
-- RLS NOTE: Existing RLS policies on context_profiles apply to the entire row
-- (auth.uid() = user_id), so new columns are automatically covered.
-- No policy changes needed.
-- ============================================================================
