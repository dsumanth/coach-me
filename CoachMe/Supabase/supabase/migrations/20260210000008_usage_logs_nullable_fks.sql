-- Migration: 20260210000008_usage_logs_nullable_fks.sql
-- Description: Make conversation_id and message_id nullable on usage_logs
--   to support non-conversation LLM usage (e.g., push notification generation).
-- Author: Coach App Development Team
-- Date: 2026-02-10
-- Story: 8.7 - Smart Proactive Push Notifications

-- ============================================================================
-- ALLOW NULL FK COLUMNS
-- Push notification LLM calls have no associated conversation or message.
-- ============================================================================
ALTER TABLE public.usage_logs ALTER COLUMN conversation_id DROP NOT NULL;
ALTER TABLE public.usage_logs ALTER COLUMN message_id DROP NOT NULL;

COMMENT ON COLUMN public.usage_logs.conversation_id IS 'Conversation FK — NULL for non-conversation events (e.g., push notifications)';
COMMENT ON COLUMN public.usage_logs.message_id IS 'Message FK — NULL for non-conversation events (e.g., push notifications)';
