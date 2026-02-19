-- Migration: Create push_log table for proactive coaching notifications
-- Story 8-7: Smart Proactive Push Notifications
--
-- Tracks push notification history: type, content, delivery time, and open tracking.
-- Used by push-trigger Edge Function for frequency compliance and analytics.

CREATE TABLE IF NOT EXISTS public.push_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    push_type TEXT NOT NULL CHECK (push_type IN ('event_based', 'pattern_based', 're_engagement')),
    content TEXT NOT NULL,
    sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    opened BOOLEAN NOT NULL DEFAULT false,
    metadata JSONB DEFAULT '{}'::jsonb
);

ALTER TABLE public.push_log ENABLE ROW LEVEL SECURITY;

-- Index for frequency lookups: "when was the last push sent to this user?"
CREATE INDEX idx_push_log_user_sent ON public.push_log(user_id, sent_at DESC);

-- Users can read their own push log entries
CREATE POLICY "Users can read own push logs"
    ON public.push_log FOR SELECT
    USING (auth.uid() = user_id);

-- Service role manages all push log operations (insert, update from push-trigger)
CREATE POLICY "Service role manages push logs"
    ON public.push_log FOR ALL
    TO service_role
    USING (true);

COMMENT ON TABLE public.push_log IS 'Push notification history for proactive coaching nudges (Story 8.7)';
