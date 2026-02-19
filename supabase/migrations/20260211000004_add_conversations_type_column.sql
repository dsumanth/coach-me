-- Migration: 20260211000004_add_conversations_type_column.sql
-- Description: Add type column to conversations (was missing from 20260211000001_discovery_mode.sql)
-- Story 11.2: Distinguishes 'coaching' vs 'discovery' conversations

-- Add type column to conversations (default 'coaching' so existing rows are unaffected)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'conversations'
      AND column_name = 'type'
  ) THEN
    ALTER TABLE public.conversations
    ADD COLUMN type TEXT DEFAULT 'coaching';

    ALTER TABLE public.conversations
    ADD CONSTRAINT conversations_type_check CHECK (type IN ('coaching', 'discovery'));
  END IF;
END $$;

-- Index on conversations type for filtering
CREATE INDEX IF NOT EXISTS idx_conversations_type
ON public.conversations (type);
