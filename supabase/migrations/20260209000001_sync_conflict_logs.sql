-- Story 7.4: Sync Conflict Resolution
-- Table for logging sync conflict resolutions (monitoring and debugging)
-- No PII stored — only record IDs, timestamps, and resolution types

CREATE TABLE IF NOT EXISTS public.sync_conflict_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    record_type TEXT NOT NULL,        -- 'conversation', 'message', 'context_profile'
    record_id UUID NOT NULL,
    conflict_type TEXT NOT NULL,      -- 'timestamp_mismatch', 'missing_local', 'missing_remote'
    resolution TEXT NOT NULL,         -- 'server_wins', 'local_wins', 'skipped'
    local_timestamp TIMESTAMPTZ,
    remote_timestamp TIMESTAMPTZ,
    resolved_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS: users can insert their own logs
ALTER TABLE public.sync_conflict_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can insert own sync logs"
    ON public.sync_conflict_logs FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Service role can read all (for monitoring)
CREATE POLICY "Service role can read all sync logs"
    ON public.sync_conflict_logs FOR SELECT
    USING (auth.role() = 'service_role');

-- Index for monitoring queries
CREATE INDEX idx_sync_conflict_logs_user_resolved
    ON public.sync_conflict_logs(user_id, resolved_at DESC);
