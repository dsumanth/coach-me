-- Story 3.5: Cross-Domain Pattern Synthesis
-- Creates increment_surface_count RPC for atomic surface_count increment
-- Used by pattern-synthesizer.ts recordSynthesisSurfaced()

CREATE OR REPLACE FUNCTION public.increment_surface_count(
  p_user_id UUID,
  p_theme TEXT
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog, pg_temp
AS $$
BEGIN
  UPDATE pattern_syntheses
  SET
    surface_count = COALESCE(surface_count, 0) + 1,
    last_surfaced_at = NOW(),
    updated_at = NOW()
  WHERE user_id = p_user_id
    AND theme = p_theme;
END;
$$;
