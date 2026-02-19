-- Migration: 20260219000001_product_events.sql
-- Description: Product analytics events for experimentation and quality tuning
-- Author: Coach App Development Team
-- Date: 2026-02-19

CREATE TABLE IF NOT EXISTS public.product_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    conversation_id UUID REFERENCES public.conversations(id) ON DELETE SET NULL,
    message_id UUID REFERENCES public.messages(id) ON DELETE SET NULL,
    event_name TEXT NOT NULL,
    properties JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.product_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own product events"
    ON public.product_events FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own product events"
    ON public.product_events FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_product_events_user_created
    ON public.product_events(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_product_events_name_created
    ON public.product_events(event_name, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_product_events_conversation_created
    ON public.product_events(conversation_id, created_at DESC);

COMMENT ON TABLE public.product_events IS 'Low-latency product analytics events for coaching quality and retention experiments';
COMMENT ON COLUMN public.product_events.event_name IS 'Event key, for example chat_model_selected or discovery_completed';
COMMENT ON COLUMN public.product_events.properties IS 'Event metadata payload';
