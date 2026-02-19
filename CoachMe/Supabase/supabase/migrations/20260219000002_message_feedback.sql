-- Migration: 20260219000002_message_feedback.sql
-- Description: Per-message assistant feedback (thumbs up/down) for response quality loop
-- Author: Coach App Development Team
-- Date: 2026-02-19

CREATE TABLE IF NOT EXISTS public.message_feedback (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
    message_id UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
    sentiment TEXT NOT NULL CHECK (sentiment IN ('up', 'down')),
    feedback_text TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, message_id)
);

ALTER TABLE public.message_feedback ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own message feedback"
    ON public.message_feedback FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own message feedback"
    ON public.message_feedback FOR INSERT
    WITH CHECK (
        auth.uid() = user_id
        AND EXISTS (
            SELECT 1
            FROM public.messages m
            WHERE m.id = message_id
              AND m.user_id = auth.uid()
        )
        AND EXISTS (
            SELECT 1
            FROM public.conversations c
            WHERE c.id = conversation_id
              AND c.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update own message feedback"
    ON public.message_feedback FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own message feedback"
    ON public.message_feedback FOR DELETE
    USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_message_feedback_user_created
    ON public.message_feedback(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_message_feedback_message
    ON public.message_feedback(message_id);

DROP TRIGGER IF EXISTS message_feedback_updated_at ON public.message_feedback;
CREATE TRIGGER message_feedback_updated_at
    BEFORE UPDATE ON public.message_feedback
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

COMMENT ON TABLE public.message_feedback IS 'User feedback on assistant messages for quality adaptation';
COMMENT ON COLUMN public.message_feedback.sentiment IS 'up = helpful response, down = unhelpful response';
