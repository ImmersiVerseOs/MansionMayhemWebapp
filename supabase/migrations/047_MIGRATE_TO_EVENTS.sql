-- ============================================================================
-- MIGRATION 047: MIGRATE TO EVENT SYSTEM & CUTOVER
-- ============================================================================
-- 1. Set game_mode = 'weekly' on all existing games
-- 2. Schedule events for active games based on current_week
-- 3. Unschedule old 19 cron jobs
-- 4. Schedule new single processor cron
-- ============================================================================

-- ============================================================================
-- 1. Set game_mode on all existing games
-- ============================================================================
UPDATE mm_games
SET game_mode = 'weekly',
    mode_template_id = (SELECT id FROM game_mode_templates WHERE mode_name = 'weekly'),
    current_phase = CASE
      WHEN status IN ('waiting_lobby', 'active_lobby') THEN 'lobby'
      WHEN status = 'active' THEN 'gameplay_week_' || COALESCE(current_week, 1)
      WHEN status IN ('final_three', 'finale') THEN 'finale'
      WHEN status = 'completed' THEN 'completed'
      ELSE 'lobby'
    END
WHERE game_mode IS NULL;

-- ============================================================================
-- 2. Schedule events for currently active games
-- ============================================================================
DO $$
DECLARE
  v_game RECORD;
  v_week_start TIMESTAMPTZ;
  v_result JSONB;
BEGIN
  -- For each active game, schedule remaining weekly events
  FOR v_game IN
    SELECT id, current_week, started_at, status
    FROM mm_games
    WHERE status IN ('active', 'final_three', 'active_lobby', 'waiting_lobby')
  LOOP
    IF v_game.status IN ('waiting_lobby', 'active_lobby') THEN
      -- Game is still in lobby - schedule lobby events + week 1
      INSERT INTO game_events (game_id, event_type, scheduled_for, priority, is_recurring, recurring_interval, payload)
      VALUES
        (v_game.id, 'lobby_check', NOW() + INTERVAL '1 minute', 7, true, INTERVAL '1 minute',
         '{"mode": "weekly"}'::jsonb),
        (v_game.id, 'lobby_fill', NOW(), 8, false, NULL,
         '{"mode": "weekly"}'::jsonb);

      -- Schedule recurring AI events
      INSERT INTO game_events (game_id, event_type, scheduled_for, priority, is_recurring, recurring_interval, payload)
      VALUES
        (v_game.id, 'ai_agent_process', NOW() + INTERVAL '5 minutes', 5, true, INTERVAL '3 minutes',
         '{"mode": "weekly"}'::jsonb);

    ELSIF v_game.status IN ('active', 'final_three') THEN
      -- Game is active - schedule current week events + recurring AI
      v_week_start := v_game.started_at + ((COALESCE(v_game.current_week, 1) - 1) * INTERVAL '7 days');

      -- Schedule remaining events for current week
      PERFORM schedule_next_week_events(v_game.id, COALESCE(v_game.current_week, 1), v_week_start);

      -- Schedule recurring AI events
      INSERT INTO game_events (game_id, event_type, scheduled_for, priority, is_recurring, recurring_interval, payload)
      VALUES
        (v_game.id, 'ai_agent_process', NOW() + INTERVAL '3 minutes', 5, true, INTERVAL '3 minutes',
         '{"mode": "weekly"}'::jsonb),
        (v_game.id, 'ai_tea_posts', NOW() + INTERVAL '30 minutes', 4, true, INTERVAL '120 minutes',
         '{"mode": "weekly"}'::jsonb),
        (v_game.id, 'ai_link_ups', NOW() + INTERVAL '15 minutes', 5, true, INTERVAL '60 minutes',
         '{"mode": "weekly"}'::jsonb),
        (v_game.id, 'ai_director_run', NOW() + INTERVAL '1 hour', 6, true, INTERVAL '360 minutes',
         '{"mode": "weekly"}'::jsonb),
        (v_game.id, 'cleanup', NOW() + INTERVAL '3 hours', 2, true, INTERVAL '24 hours',
         '{"mode": "weekly"}'::jsonb);
    END IF;

    RAISE NOTICE 'Scheduled events for game %: status=%, week=%', v_game.id, v_game.status, v_game.current_week;
  END LOOP;
END $$;

-- ============================================================================
-- 3. Unschedule old 19 cron jobs
-- ============================================================================
-- Safely unschedule each job (no error if it doesn't exist)
DO $$
DECLARE
  v_job_name TEXT;
  v_job_names TEXT[] := ARRAY[
    'ai_agent_processor',
    'check_lobby_timers',
    'cleanup_abandoned_games',
    'queue_ai_link_ups',
    'queue_ai_tea_posts',
    'spawn_ai_into_lobbies',
    'ai-director-midnight',
    'ai-director-morning',
    'ai-director-noon',
    'ai-director-evening',
    'game-manager-daily',
    'weekly_elimination',
    'weekly_queen_selection',
    'distribute_daily_scenarios',
    'pre_launch_fill_to_20',
    'elimination-sunday',
    'queen-selection-sunday',
    'hot-seat-saturday',
    'cleanup_ai_actions'
  ];
BEGIN
  FOREACH v_job_name IN ARRAY v_job_names
  LOOP
    BEGIN
      PERFORM cron.unschedule(v_job_name);
      RAISE NOTICE 'Unscheduled cron job: %', v_job_name;
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'Cron job % not found or already removed: %', v_job_name, SQLERRM;
    END;
  END LOOP;
END $$;

-- ============================================================================
-- 4. Schedule new single processor cron (runs every minute)
-- ============================================================================
SELECT cron.schedule(
  'game_event_processor',
  '* * * * *',
  $$ SELECT process_game_events(); $$
);

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Check old crons are gone
SELECT jobname, schedule, active
FROM cron.job
WHERE jobname IN (
  'ai_agent_processor', 'check_lobby_timers', 'cleanup_abandoned_games',
  'queue_ai_link_ups', 'queue_ai_tea_posts', 'spawn_ai_into_lobbies',
  'ai-director-midnight', 'ai-director-morning', 'ai-director-noon', 'ai-director-evening',
  'game-manager-daily', 'weekly_elimination', 'weekly_queen_selection',
  'distribute_daily_scenarios', 'pre_launch_fill_to_20',
  'elimination-sunday', 'queen-selection-sunday', 'hot-seat-saturday', 'cleanup_ai_actions'
);

-- Check new processor cron exists
SELECT jobname, schedule, active
FROM cron.job
WHERE jobname = 'game_event_processor';

-- Check all games have game_mode set
SELECT id, title, status, game_mode, current_phase
FROM mm_games
WHERE game_mode IS NULL;

-- Check scheduled events
SELECT game_id, event_type, status, scheduled_for, is_recurring
FROM game_events
WHERE status = 'scheduled'
ORDER BY scheduled_for ASC
LIMIT 20;

-- Summary
SELECT
  (SELECT count(*) FROM game_events WHERE status = 'scheduled') AS scheduled_events,
  (SELECT count(*) FROM mm_games WHERE game_mode = 'weekly') AS weekly_games,
  (SELECT count(*) FROM cron.job WHERE jobname = 'game_event_processor') AS processor_crons;
