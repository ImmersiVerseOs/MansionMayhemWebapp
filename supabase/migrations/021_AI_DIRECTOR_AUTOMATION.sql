-- =====================================================
-- AI DIRECTOR AUTOMATION & CONFIGURATION
-- Cron jobs, thresholds, monitoring
-- =====================================================

-- ============================================================================
-- 1. AI DIRECTOR CONFIGURATION TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.ai_director_config (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id UUID UNIQUE NOT NULL REFERENCES public.mm_games(id) ON DELETE CASCADE,

  -- Automation settings
  auto_enabled BOOLEAN DEFAULT true,
  run_frequency_hours INTEGER DEFAULT 6 CHECK (run_frequency_hours > 0),
  last_run_at TIMESTAMPTZ,
  next_run_at TIMESTAMPTZ,

  -- Drama thresholds
  drama_index_high INTEGER DEFAULT 90 CHECK (drama_index_high >= 0 AND drama_index_high <= 100),
  drama_index_low INTEGER DEFAULT 20 CHECK (drama_index_low >= 0 AND drama_index_low <= 100),

  -- Scenario frequency limits
  max_scenarios_per_week INTEGER DEFAULT 15,
  min_hours_between_scenarios INTEGER DEFAULT 12,

  -- Targeting rules
  invisible_player_threshold INTEGER DEFAULT 2, -- Scenarios in last 7 days
  invisible_player_priority BOOLEAN DEFAULT true,

  -- Response tracking
  min_response_rate_threshold INTEGER DEFAULT 50, -- Percentage

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ai_director_config_game_id ON public.ai_director_config(game_id);
CREATE INDEX IF NOT EXISTS idx_ai_director_config_next_run ON public.ai_director_config(next_run_at);

-- ============================================================================
-- 2. SCENARIO RESPONSE TRACKING VIEW
-- ============================================================================

CREATE OR REPLACE VIEW scenario_response_metrics AS
SELECT
  s.id,
  s.game_id,
  s.title,
  s.scenario_type,
  s.status,
  s.assigned_count,
  s.responses_received,
  s.voice_notes_received,

  -- Response rate
  CASE
    WHEN s.assigned_count > 0
    THEN ROUND((s.responses_received::NUMERIC / s.assigned_count) * 100, 1)
    ELSE 0
  END as response_rate_pct,

  -- Voice note rate
  CASE
    WHEN s.responses_received > 0
    THEN ROUND((s.voice_notes_received::NUMERIC / s.responses_received) * 100, 1)
    ELSE 0
  END as voice_note_rate_pct,

  -- Time metrics
  s.created_at,
  s.deadline_at,
  s.closed_at,
  EXTRACT(EPOCH FROM (s.deadline_at - s.created_at)) / 3600 as hours_to_deadline,

  -- AI-generated flag
  CASE
    WHEN s.context_notes LIKE '[AI DIRECTOR]%' THEN true
    ELSE false
  END as is_ai_generated,

  -- Target cast members
  (
    SELECT jsonb_agg(cm.display_name)
    FROM scenario_targets st
    JOIN cast_members cm ON st.cast_member_id = cm.id
    WHERE st.scenario_id = s.id
  ) as target_names

FROM scenarios s;

GRANT SELECT ON scenario_response_metrics TO authenticated;
GRANT SELECT ON scenario_response_metrics TO anon;

-- ============================================================================
-- 3. DRAMA INDEX CALCULATION FUNCTION
-- ============================================================================

CREATE OR REPLACE FUNCTION calculate_drama_index(p_game_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_drama_index INTEGER;
BEGIN
  SELECT ROUND(
    (
      -- Average drama scores (0-100, weight 30%)
      (COALESCE(AVG(cm.drama_score), 50) * 0.3) +

      -- Recent Tea Spot activity (0-100, weight 25%)
      (LEAST(COUNT(DISTINCT CASE
        WHEN trp.created_at > NOW() - INTERVAL '24 hours' THEN trp.id
      END) * 10, 100) * 0.25) +

      -- Average rivalry level (0-100, weight 25%)
      (COALESCE(
        (SELECT AVG(rivalry_level) FROM mm_relationship_edges WHERE game_id = p_game_id),
        30
      ) * 0.25) +

      -- Active scenario engagement (0-100, weight 20%)
      (LEAST(
        (SELECT AVG(
          CASE WHEN assigned_count > 0
          THEN (responses_received::NUMERIC / assigned_count) * 100
          ELSE 0 END
        ) FROM scenarios
        WHERE game_id = p_game_id
          AND created_at > NOW() - INTERVAL '7 days'
        ),
        100
      ) * 0.2)
    )
  )::INTEGER INTO v_drama_index
  FROM cast_members cm
  JOIN mm_game_cast gc ON cm.id = gc.cast_member_id
  LEFT JOIN mm_tea_room_posts trp ON trp.cast_member_id = cm.id AND trp.game_id = p_game_id
  WHERE gc.game_id = p_game_id AND cm.status = 'active';

  RETURN COALESCE(v_drama_index, 50);
END;
$$;

GRANT EXECUTE ON FUNCTION calculate_drama_index(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION calculate_drama_index(UUID) TO service_role;

-- ============================================================================
-- 4. AI DIRECTOR SCHEDULER FUNCTION
-- ============================================================================

CREATE OR REPLACE FUNCTION schedule_ai_director_run(p_game_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_config RECORD;
BEGIN
  -- Get or create config
  INSERT INTO ai_director_config (game_id)
  VALUES (p_game_id)
  ON CONFLICT (game_id) DO NOTHING;

  SELECT * INTO v_config FROM ai_director_config WHERE game_id = p_game_id;

  -- Update next run time
  UPDATE ai_director_config
  SET
    last_run_at = NOW(),
    next_run_at = NOW() + (v_config.run_frequency_hours || ' hours')::INTERVAL,
    updated_at = NOW()
  WHERE game_id = p_game_id;
END;
$$;

-- ============================================================================
-- 5. CRON JOB SETUP (pg_cron)
-- ============================================================================

-- Enable pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Remove old AI Director cron jobs if they exist
DO $$
DECLARE
  v_jobid BIGINT;
BEGIN
  FOR v_jobid IN
    SELECT jobid FROM cron.job WHERE jobname LIKE 'ai-director-%'
  LOOP
    PERFORM cron.unschedule(v_jobid);
  END LOOP;
END $$;

-- AI Director runs every 6 hours (4 times per day: 12am, 6am, 12pm, 6pm UTC)
SELECT cron.schedule(
  'ai-director-midnight',
  '0 0 * * *', -- Every day at midnight UTC
  $$
  SELECT net.http_post(
    url := 'https://fpxbhqibimekjhlumnmc.supabase.co/functions/v1/ai-director',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key')
    ),
    body := jsonb_build_object('manualTrigger', false)
  ) as request_id;
  $$
);

SELECT cron.schedule(
  'ai-director-morning',
  '0 6 * * *', -- Every day at 6am UTC
  $$
  SELECT net.http_post(
    url := 'https://fpxbhqibimekjhlumnmc.supabase.co/functions/v1/ai-director',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key')
    ),
    body := jsonb_build_object('manualTrigger', false)
  ) as request_id;
  $$
);

SELECT cron.schedule(
  'ai-director-noon',
  '0 12 * * *', -- Every day at noon UTC
  $$
  SELECT net.http_post(
    url := 'https://fpxbhqibimekjhlumnmc.supabase.co/functions/v1/ai-director',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key')
    ),
    body := jsonb_build_object('manualTrigger', false)
  ) as request_id;
  $$
);

SELECT cron.schedule(
  'ai-director-evening',
  '0 18 * * *', -- Every day at 6pm UTC
  $$
  SELECT net.http_post(
    url := 'https://fpxbhqibimekjhlumnmc.supabase.co/functions/v1/ai-director',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key')
    ),
    body := jsonb_build_object('manualTrigger', false)
  ) as request_id;
  $$
);

-- ============================================================================
-- 6. MONITORING QUERIES (Helper Functions)
-- ============================================================================

-- Function to get AI Director dashboard metrics
CREATE OR REPLACE FUNCTION get_ai_director_dashboard(p_game_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT jsonb_build_object(
    'game_id', p_game_id,
    'drama_index', calculate_drama_index(p_game_id),

    'config', (
      SELECT row_to_json(c)
      FROM ai_director_config c
      WHERE c.game_id = p_game_id
    ),

    'scenarios_this_week', (
      SELECT COUNT(*)
      FROM scenarios
      WHERE game_id = p_game_id
        AND created_at > date_trunc('week', NOW())
        AND context_notes LIKE '[AI DIRECTOR]%'
    ),

    'avg_response_rate', (
      SELECT ROUND(AVG(response_rate_pct), 1)
      FROM scenario_response_metrics
      WHERE game_id = p_game_id
        AND created_at > NOW() - INTERVAL '7 days'
        AND is_ai_generated = true
    ),

    'invisible_players', (
      SELECT jsonb_agg(jsonb_build_object(
        'name', cm.display_name,
        'drama_score', cm.drama_score,
        'recent_scenarios', (
          SELECT COUNT(*)
          FROM scenario_targets st
          JOIN scenarios s ON st.scenario_id = s.id
          WHERE st.cast_member_id = cm.id
            AND s.created_at > NOW() - INTERVAL '7 days'
        )
      ))
      FROM cast_members cm
      JOIN mm_game_cast gc ON cm.id = gc.cast_member_id
      WHERE gc.game_id = p_game_id
        AND cm.status = 'active'
        AND (
          SELECT COUNT(*)
          FROM scenario_targets st
          JOIN scenarios s ON st.scenario_id = s.id
          WHERE st.cast_member_id = cm.id
            AND s.created_at > NOW() - INTERVAL '7 days'
        ) < 2
    ),

    'recent_decisions', (
      SELECT jsonb_agg(
        jsonb_build_object(
          'created_at', created_at,
          'should_create', decision->>'should_create',
          'title', decision->'scenario'->>'title',
          'scenario_id', scenario_created_id
        ) ORDER BY created_at DESC
      )
      FROM (
        SELECT * FROM ai_director_log
        WHERE game_id = p_game_id
        ORDER BY created_at DESC
        LIMIT 5
      ) recent
    ),

    'hours_since_last_scenario', (
      SELECT EXTRACT(EPOCH FROM (NOW() - MAX(created_at))) / 3600
      FROM scenarios
      WHERE game_id = p_game_id
    )

  ) INTO v_result;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION get_ai_director_dashboard(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_ai_director_dashboard(UUID) TO service_role;

-- ============================================================================
-- 7. DEFAULT CONFIGURATION FOR TEST GAME
-- ============================================================================

-- Create config for our test game
INSERT INTO ai_director_config (game_id, auto_enabled, run_frequency_hours)
SELECT id, true, 6
FROM mm_games
WHERE title = 'Mansion Mayhem - Season 1'
ON CONFLICT (game_id) DO NOTHING;

-- ============================================================================
-- DONE
-- ============================================================================

-- View cron jobs
SELECT jobid, jobname, schedule, active
FROM cron.job
WHERE jobname LIKE 'ai-director-%';
