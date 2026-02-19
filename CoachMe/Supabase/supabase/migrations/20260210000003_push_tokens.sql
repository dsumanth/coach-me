-- Push Tokens table (Story 8.2)
-- Stores APNs device tokens for push notification delivery.
-- Each row maps a user to one device token; upsert semantics let the
-- iOS client re-register the current token on every launch without
-- duplicating rows.

CREATE TABLE IF NOT EXISTS public.push_tokens (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    device_token TEXT NOT NULL,
    platform    TEXT NOT NULL DEFAULT 'ios',
    created_at  TIMESTAMPTZ DEFAULT now(),
    updated_at  TIMESTAMPTZ DEFAULT now(),
    UNIQUE(user_id, device_token)
);

COMMENT ON TABLE  public.push_tokens IS 'APNs device tokens for push notification delivery';
COMMENT ON COLUMN public.push_tokens.user_id      IS 'Owner of this device token';
COMMENT ON COLUMN public.push_tokens.device_token  IS 'Hex-encoded APNs device token';
COMMENT ON COLUMN public.push_tokens.platform      IS 'Device platform (currently always ios)';

-- Index for efficient token lookup by user
CREATE INDEX IF NOT EXISTS idx_push_tokens_user_id ON public.push_tokens(user_id);

-- Row Level Security
ALTER TABLE public.push_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own tokens"
    ON public.push_tokens FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own tokens"
    ON public.push_tokens FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own tokens"
    ON public.push_tokens FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own tokens"
    ON public.push_tokens FOR DELETE
    USING (auth.uid() = user_id);

-- Note: The push-send Edge Function uses SUPABASE_SERVICE_ROLE_KEY which
-- bypasses RLS by default. No additional service-role policy is needed.

-- Automatic updated_at trigger — reuses the project-wide function
CREATE TRIGGER update_push_tokens_updated_at
    BEFORE UPDATE ON public.push_tokens
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();
