-- Migration: 20260208000002_add_crisis_to_usage_logs.sql
-- Description: Add crisis_detected column to usage_logs for crisis monitoring
-- Author: Coach App Development Team
-- Date: 2026-02-08
-- Story: 4.1 - Crisis Detection Pipeline

-- ============================================================================
-- ADD CRISIS DETECTION FLAG TO USAGE LOGS
-- Tracks whether crisis was detected for monitoring and analytics.
-- Only logs boolean flag — never stores message content (NFR14: no PII in logs).
-- ============================================================================
ALTER TABLE public.usage_logs
  ADD COLUMN IF NOT EXISTS crisis_detected BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN public.usage_logs.crisis_detected IS 'Whether crisis indicators were detected in this message (Story 4.1)';
