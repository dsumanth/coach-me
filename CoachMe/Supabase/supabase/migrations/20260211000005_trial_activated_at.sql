-- Story 10.3: Add trial_activated_at to users table
ALTER TABLE auth.users ADD COLUMN IF NOT EXISTS trial_activated_at TIMESTAMPTZ DEFAULT NULL;

CREATE INDEX IF NOT EXISTS idx_users_trial_activated_at
  ON auth.users (trial_activated_at)
  WHERE trial_activated_at IS NOT NULL;

CREATE OR REPLACE FUNCTION public.activate_trial()
RETURNS TIMESTAMPTZ
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  activated_at TIMESTAMPTZ;
BEGIN
  activated_at := NOW();
  UPDATE auth.users
  SET trial_activated_at = activated_at
  WHERE id = auth.uid()
    AND trial_activated_at IS NULL;
  RETURN activated_at;
END;
$$;

REVOKE ALL ON FUNCTION public.activate_trial() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.activate_trial() TO authenticated;
