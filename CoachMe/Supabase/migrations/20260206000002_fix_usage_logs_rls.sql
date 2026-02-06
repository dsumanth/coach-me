-- Migration: 20260206000002_fix_usage_logs_rls.sql
-- Description: Fix RLS policy for usage_logs to prevent any user from inserting for any user_id
-- Author: Code Review Fix
-- Date: 2026-02-06
-- Story: 1.6 - Chat Streaming Edge Function (Code Review Fix)

-- Drop the overly permissive policy
DROP POLICY IF EXISTS "Service role can insert usage logs" ON public.usage_logs;

-- Create a more secure policy that restricts inserts to own user_id
CREATE POLICY "Users can insert own usage logs"
    ON public.usage_logs
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);
