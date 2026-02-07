-- Migration: 20260206000001_usage_logs.sql
-- Description: Create usage_logs table for API cost tracking
-- Author: Coach App Development Team
-- Date: 2026-02-06
-- Story: 1.6 - Chat Streaming Edge Function

-- ============================================================================
-- USAGE LOGS TABLE
-- Per-request LLM cost tracking
-- Per architecture.md: Per-user API cost tracking embedded in backend
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.usage_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
    message_id UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
    model TEXT NOT NULL,
    tokens_in INTEGER NOT NULL DEFAULT 0,
    tokens_out INTEGER NOT NULL DEFAULT 0,
    cost_usd DECIMAL(10, 6) NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable Row Level Security (CRITICAL: Must be enabled on all tables)
ALTER TABLE public.usage_logs ENABLE ROW LEVEL SECURITY;

-- Index for per-user cost queries
CREATE INDEX IF NOT EXISTS idx_usage_logs_user_id ON public.usage_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_usage_logs_created_at ON public.usage_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_usage_logs_conversation_id ON public.usage_logs(conversation_id);

-- RLS policy: users can only read their own usage logs
CREATE POLICY "Users can view own usage logs"
    ON public.usage_logs
    FOR SELECT
    USING (auth.uid() = user_id);

-- Users can only insert usage logs for themselves (Edge Functions pass user context)
CREATE POLICY "Users can insert own usage logs"
    ON public.usage_logs
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

COMMENT ON TABLE public.usage_logs IS 'API usage and cost tracking per request';
COMMENT ON COLUMN public.usage_logs.model IS 'LLM model used (e.g., claude-sonnet-4-20250514)';
COMMENT ON COLUMN public.usage_logs.tokens_in IS 'Input/prompt tokens consumed';
COMMENT ON COLUMN public.usage_logs.tokens_out IS 'Output/completion tokens generated';
COMMENT ON COLUMN public.usage_logs.cost_usd IS 'Calculated cost in USD';

-- ============================================================================
-- VERIFICATION QUERIES (run after migration to verify)
-- ============================================================================
-- SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';
-- SELECT * FROM public.usage_logs LIMIT 5;
