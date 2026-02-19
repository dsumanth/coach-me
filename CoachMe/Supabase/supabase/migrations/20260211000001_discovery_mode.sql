-- Migration: 20260211000001_discovery_mode.sql
-- Story 11.2: Discovery Mode Edge Function
--
-- Adds:
--   1. discovery_completed_at column to context_profiles (tracks when discovery flow finishes)
--   2. type column to conversations (distinguishes 'coaching' vs 'discovery' conversations)
--   3. Indexes for efficient querying

-- 1. Add discovery_completed_at to context_profiles
ALTER TABLE public.context_profiles
ADD COLUMN IF NOT EXISTS discovery_completed_at TIMESTAMPTZ DEFAULT NULL;

-- 2. Add type column to conversations (default 'coaching' so existing rows are unaffected)
-- Split into two idempotent steps so the constraint is added even if the column
-- was created by a prior partial run.
DO $$
BEGIN
  -- Step 1: Add column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'conversations'
      AND column_name = 'type'
  ) THEN
    ALTER TABLE public.conversations
    ADD COLUMN type TEXT DEFAULT 'coaching';
  END IF;

  -- Step 2: Add CHECK constraint if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'conversations_type_check'
      AND conrelid = 'public.conversations'::regclass
  ) THEN
    ALTER TABLE public.conversations
    ADD CONSTRAINT conversations_type_check CHECK (type IN ('coaching', 'discovery'));
  END IF;
END $$;

-- 3. Partial index on context_profiles for discovery completion lookups
CREATE INDEX IF NOT EXISTS idx_context_profiles_discovery
ON public.context_profiles (discovery_completed_at)
WHERE discovery_completed_at IS NOT NULL;

-- 4. Index on conversations type for filtering
CREATE INDEX IF NOT EXISTS idx_conversations_type
ON public.conversations (type);
