-- Migration: 20260210000001_learning_signals.sql
-- Description: Create learning_signals table for behavioral signal tracking
-- Author: Coach App Development Team
-- Date: 2026-02-10
-- Story: 8.1 - Learning Signals Infrastructure

CREATE TABLE IF NOT EXISTS public.learning_signals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    signal_type TEXT NOT NULL CHECK (signal_type IN (
        'insight_confirmed', 'insight_dismissed', 'session_completed', 'domain_used'
    )),
    signal_data JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.learning_signals ENABLE ROW LEVEL SECURITY;

-- RLS: users can only read their own signals
CREATE POLICY "Users can view own learning signals"
    ON public.learning_signals FOR SELECT
    USING (auth.uid() = user_id);

-- RLS: users can only insert their own signals
CREATE POLICY "Users can insert own learning signals"
    ON public.learning_signals FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Performance indexes for 200ms query target (AC-4)
CREATE INDEX idx_learning_signals_user_type
    ON public.learning_signals(user_id, signal_type);
CREATE INDEX idx_learning_signals_user_created
    ON public.learning_signals(user_id, created_at DESC);

-- updated_at trigger
DROP TRIGGER IF EXISTS learning_signals_updated_at ON public.learning_signals;
CREATE TRIGGER learning_signals_updated_at
    BEFORE UPDATE ON public.learning_signals
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

COMMENT ON TABLE public.learning_signals IS 'Behavioral signals from user interactions for coaching intelligence';
COMMENT ON COLUMN public.learning_signals.signal_type IS 'Type of signal: insight_confirmed, insight_dismissed, session_completed, domain_used';
COMMENT ON COLUMN public.learning_signals.signal_data IS 'JSONB payload with signal-specific data';
