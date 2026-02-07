-- Story 3.5: Cross-Domain Pattern Synthesis
-- Creates pattern_syntheses table for caching cross-domain pattern analysis results
-- Task 8.1-8.5

-- Task 8.1: Create pattern_syntheses table
CREATE TABLE pattern_syntheses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  theme TEXT NOT NULL,
  domains TEXT[] NOT NULL,
  confidence DOUBLE PRECISION NOT NULL,
  evidence JSONB NOT NULL DEFAULT '[]',
  synthesis TEXT NOT NULL,
  surface_count INTEGER DEFAULT 0,
  last_surfaced_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Task 8.5: Add index on user_id for fast lookup
CREATE INDEX idx_pattern_syntheses_user ON pattern_syntheses(user_id);

-- Task 8.4: Enable RLS and add policy
ALTER TABLE pattern_syntheses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can only access own patterns" ON pattern_syntheses
  FOR ALL USING (auth.uid() = user_id);
