-- Migration: 20260207000002_fix_messages_update_policy.sql
-- Description: Harden messages UPDATE RLS policy with WITH CHECK clause
-- Prevents user_id reassignment on update (same fix as context_profiles)

DROP POLICY IF EXISTS "Users can update own messages" ON public.messages;

CREATE POLICY "Users can update own messages"
    ON public.messages FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);
