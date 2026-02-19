-- Migration: 20260210000005_pattern_cache.sql
-- Description: Create pattern_cache table for session-count-based pattern summary caching
-- Author: Coach App Development Team
-- Date: 2026-02-10
-- Story: 8.4 - In-Conversation Pattern Recognition Engine

-- pattern_cache: Stores pre-computed pattern summaries per user.
-- Unlike pattern_syntheses (24h TTL), this uses conversation-count-based TTL:
-- cache refreshes when 3+ new conversations occur since last analysis.

CREATE TABLE IF NOT EXISTS public.pattern_cache (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    summaries JSONB NOT NULL DEFAULT '[]'::jsonb,
    session_count_at_analysis INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT pattern_cache_one_per_user UNIQUE (user_id)
);

ALTER TABLE public.pattern_cache ENABLE ROW LEVEL SECURITY;

-- RLS: users can only read their own pattern cache
CREATE POLICY "Users can view own pattern cache"
    ON public.pattern_cache FOR SELECT
    USING (auth.uid() = user_id);

-- RLS: users can insert their own pattern cache
CREATE POLICY "Users can insert own pattern cache"
    ON public.pattern_cache FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- RLS: users can update their own pattern cache
CREATE POLICY "Users can update own pattern cache"
    ON public.pattern_cache FOR UPDATE
    USING (auth.uid() = user_id);

-- RLS: users can delete their own pattern cache
CREATE POLICY "Users can delete own pattern cache"
    ON public.pattern_cache FOR DELETE
    USING (auth.uid() = user_id);

-- Performance index on user_id (also covered by unique constraint, but explicit for clarity)
CREATE INDEX IF NOT EXISTS idx_pattern_cache_user_id
    ON public.pattern_cache(user_id);

-- updated_at trigger
DROP TRIGGER IF EXISTS pattern_cache_updated_at ON public.pattern_cache;
CREATE TRIGGER pattern_cache_updated_at
    BEFORE UPDATE ON public.pattern_cache
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- RPC: get_session_count — returns count of conversations for a user.
-- Used by pattern-analyzer to determine if cache needs refresh.
CREATE OR REPLACE FUNCTION public.get_session_count(p_user_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
BEGIN
    -- Security: only allow users to query their own session count
    IF auth.uid() IS DISTINCT FROM p_user_id THEN
        RETURN 0;
    END IF;

    RETURN (
        SELECT COUNT(*)::INTEGER
        FROM public.conversations
        WHERE user_id = p_user_id
    );
END;
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION public.get_session_count(UUID) TO authenticated;

-- Also add 'pattern_engaged' to learning_signals CHECK constraint
-- so Task 5 can record pattern engagement signals.
ALTER TABLE public.learning_signals
    DROP CONSTRAINT IF EXISTS learning_signals_signal_type_check;
ALTER TABLE public.learning_signals
    ADD CONSTRAINT learning_signals_signal_type_check
    CHECK (signal_type IN (
        'insight_confirmed', 'insight_dismissed', 'session_completed', 'domain_used', 'pattern_engaged'
    ));

COMMENT ON TABLE public.pattern_cache IS 'Cached pattern summaries for prompt injection (Story 8.4). Uses session-count-based TTL instead of time-based.';
COMMENT ON COLUMN public.pattern_cache.summaries IS 'JSONB array of PatternSummary objects for prompt injection';
COMMENT ON COLUMN public.pattern_cache.session_count_at_analysis IS 'Total conversation count at time of last analysis — used for 3-session TTL';
COMMENT ON FUNCTION public.get_session_count IS 'Returns total conversation count for a user (Story 8.4 cache TTL)';
