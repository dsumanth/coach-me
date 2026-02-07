-- Migration: 20260207000004_fix_usage_logs_message_fk.sql
-- Description: Add missing FK on usage_logs.message_id to public.messages
-- Prevents orphaned message references and ensures cascade consistency

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'usage_logs_message_id_fkey'
          AND conrelid = 'public.usage_logs'::regclass
    ) THEN
        ALTER TABLE public.usage_logs
            ADD CONSTRAINT usage_logs_message_id_fkey
            FOREIGN KEY (message_id) REFERENCES public.messages(id) ON DELETE CASCADE;
    END IF;
END$$;
