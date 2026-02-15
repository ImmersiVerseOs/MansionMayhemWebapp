-- =====================================================
-- INTENSE DRAMA MODE - DEFAULT FOR ALL GAMES
-- Keep drama at tipping point (75-84 range)
-- =====================================================

-- Update default column values for all future games
ALTER TABLE public.ai_director_config
  ALTER COLUMN drama_index_high SET DEFAULT 85,     -- was 90
  ALTER COLUMN drama_index_low SET DEFAULT 35,      -- was 20
  ALTER COLUMN max_scenarios_per_week SET DEFAULT 20,    -- was 15
  ALTER COLUMN min_hours_between_scenarios SET DEFAULT 8;  -- was 12

-- Update all existing game configs
UPDATE ai_director_config
SET
  drama_index_high = 85,
  drama_index_low = 35,
  max_scenarios_per_week = 20,
  min_hours_between_scenarios = 8,
  updated_at = NOW();

-- Add comment explaining strategy
COMMENT ON TABLE ai_director_config IS
'AI Director configuration with INTENSE DRAMA MODE defaults.
Target: Keep drama index at 75-84 (maximum intensity before tipping to chaos).
Strategy: More scenarios (20/week), shorter cooldowns (8h), tighter thresholds (35-85).';

COMMENT ON COLUMN ai_director_config.drama_index_high IS
'Emergency "breather" threshold (default 85). Deploy calming scenarios if exceeded.
Target range: 75-84 for maximum intensity without chaos.';

COMMENT ON COLUMN ai_director_config.drama_index_low IS
'Emergency "twist" threshold (default 35). Deploy explosive scenarios if below.
Never let drama get boring. Mansion Mayhem is INTENSE.';

-- Show updated defaults
SELECT
  column_name,
  column_default,
  data_type
FROM information_schema.columns
WHERE table_name = 'ai_director_config'
  AND column_name IN (
    'drama_index_high',
    'drama_index_low',
    'max_scenarios_per_week',
    'min_hours_between_scenarios'
  )
ORDER BY ordinal_position;
