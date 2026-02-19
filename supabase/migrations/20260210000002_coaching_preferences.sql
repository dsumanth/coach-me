-- Migration: 20260210000002_coaching_preferences.sql
-- Description: Add coaching_preferences JSONB column to context_profiles
-- Author: Coach App Development Team
-- Date: 2026-02-10
-- Story: 8.1 - Learning Signals Infrastructure

ALTER TABLE public.context_profiles
    ADD COLUMN IF NOT EXISTS coaching_preferences JSONB DEFAULT '{}'::jsonb;

COMMENT ON COLUMN public.context_profiles.coaching_preferences IS 'JSONB storing user coaching preferences: preferred_style, domain_usage, session_patterns, last_reflection_at. Populated by Stories 8.4-8.8.';
