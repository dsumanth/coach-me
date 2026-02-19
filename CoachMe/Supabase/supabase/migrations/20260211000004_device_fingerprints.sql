-- Migration: 20260211000004_device_fingerprints.sql
-- Description: Create device_fingerprints table and check_device_trial_eligibility RPC
-- Author: Coach App Development Team
-- Date: 2026-02-10
-- Story: 10.2 - Device Fingerprint Tracking & Trial Abuse Prevention

-- ── Table ──────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.device_fingerprints (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    device_id TEXT NOT NULL,
    first_seen_at TIMESTAMPTZ DEFAULT NOW(),
    last_seen_at TIMESTAMPTZ DEFAULT NOW(),
    trial_used BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(device_id)
);

COMMENT ON TABLE public.device_fingerprints IS 'Tracks device identifiers (IDFV) alongside user IDs to detect trial abuse across multiple Apple IDs on the same physical device';

-- ── RLS ────────────────────────────────────────────────────────────────

ALTER TABLE public.device_fingerprints ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own device fingerprints"
    ON public.device_fingerprints FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own device fingerprints"
    ON public.device_fingerprints FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own device fingerprints"
    ON public.device_fingerprints FOR UPDATE
    USING (auth.uid() = user_id);

-- ── Indexes ────────────────────────────────────────────────────────────

CREATE INDEX idx_device_fingerprints_device_id
    ON public.device_fingerprints(device_id);

CREATE INDEX idx_device_fingerprints_user_id
    ON public.device_fingerprints(user_id);

-- ── updated_at trigger ─────────────────────────────────────────────────

DROP TRIGGER IF EXISTS device_fingerprints_updated_at ON public.device_fingerprints;
CREATE TRIGGER device_fingerprints_updated_at
    BEFORE UPDATE ON public.device_fingerprints
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ── RPC: check_device_trial_eligibility ────────────────────────────────

CREATE OR REPLACE FUNCTION public.check_device_trial_eligibility(
    p_device_id TEXT,
    p_user_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog, pg_temp
AS $$
DECLARE
    existing_record RECORD;
BEGIN
    SELECT user_id, trial_used INTO existing_record
    FROM public.device_fingerprints
    WHERE device_id = p_device_id
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eligible', true, 'reason', 'new_device');
    END IF;

    IF existing_record.user_id = p_user_id THEN
        RETURN json_build_object('eligible', true, 'reason', 'same_account');
    END IF;

    IF existing_record.trial_used THEN
        RETURN json_build_object('eligible', false, 'reason', 'trial_already_used');
    END IF;

    RETURN json_build_object('eligible', true, 'reason', 'device_transferred');
END;
$$;
