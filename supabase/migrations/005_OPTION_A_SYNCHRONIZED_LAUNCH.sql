-- ============================================================================
-- OPTION A: SYNCHRONIZED LAUNCH SYSTEM
-- ============================================================================
-- All games launch on Sundays at 8 PM ET
-- Week-long lobbies close Sunday 7 PM ET
-- First scenarios distributed Monday 9 AM ET
-- ============================================================================

-- ============================================================================
-- STEP 1: UPDATE CRON JOBS TO EASTERN TIME
-- ============================================================================

-- NOTE: Cron runs in UTC, so we convert ET to UTC
-- EST (Nov-Mar): UTC-5 (add 5 hours)
-- EDT (Mar-Nov): UTC-4 (add 4 hours)
-- Currently using EST conversion

-- 1. WEEKLY ELIMINATION - Sunday 7:30 PM ET
-- Sunday 7:30 PM ET = Monday 12:30 AM UTC (during EST)
SELECT cron.unschedule('weekly_elimination')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'weekly_elimination');

SELECT cron.schedule(
  'weekly_elimination',
  '30 0 * * 1',  -- Monday 12:30 AM UTC = Sunday 7:30 PM ET
  $$ SELECT public.process_weekly_elimination(); $$
);

-- 2. QUEEN SELECTION - Sunday 8 PM ET (Game Launch!)
-- Sunday 8 PM ET = Monday 1 AM UTC (during EST)
SELECT cron.unschedule('weekly_queen_selection')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'weekly_queen_selection');

SELECT cron.schedule(
  'weekly_queen_selection',
  '0 1 * * 1',  -- Monday 1 AM UTC = Sunday 8 PM ET
  $$ SELECT public.trigger_queen_selection(); $$
);

-- 3. DISTRIBUTE SCENARIOS - Monday 9 AM ET
-- Monday 9 AM ET = Monday 2 PM UTC (during EST)
SELECT cron.unschedule('distribute_daily_scenarios')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'distribute_daily_scenarios');

SELECT cron.schedule(
  'distribute_daily_scenarios',
  '0 14 * * 1',  -- Monday 2 PM UTC = Monday 9 AM ET
  $$ SELECT public.distribute_daily_scenarios(); $$
);

-- ============================================================================
-- STEP 2: WEEK-LONG LOBBY SYSTEM
-- ============================================================================

-- Initialize week-long lobby when creating new game
-- Lobby stays open until NEXT Sunday 7 PM ET
CREATE OR REPLACE FUNCTION public.initialize_week_long_lobby(p_game_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_now TIMESTAMPTZ := NOW();
  v_next_sunday_7pm TIMESTAMPTZ;
  v_next_sunday_8pm TIMESTAMPTZ;
  v_monday_9am TIMESTAMPTZ;
BEGIN

  -- Calculate next Sunday 7 PM ET (convert to UTC)
  -- Sunday is day 0 in PostgreSQL
  v_next_sunday_7pm := date_trunc('week', v_now AT TIME ZONE 'America/New_York')
    + interval '6 days'  -- Go to Saturday
    + interval '1 day'   -- Go to Sunday
    + interval '19 hours'; -- 7 PM ET in UTC (19:00 local)

  -- If we're past this Sunday 7 PM, go to next week
  IF v_now AT TIME ZONE 'America/New_York' > v_next_sunday_7pm AT TIME ZONE 'America/New_York' THEN
    v_next_sunday_7pm := v_next_sunday_7pm + interval '7 days';
  END IF;

  -- Sunday 8 PM ET (1 hour after lobby closes)
  v_next_sunday_8pm := v_next_sunday_7pm + interval '1 hour';

  -- Monday 9 AM ET (first scenarios)
  v_monday_9am := v_next_sunday_8pm + interval '13 hours';

  -- Update game with lobby timestamps
  UPDATE mm_games SET
    status = 'waiting_lobby',
    waiting_lobby_starts_at = v_now,
    waiting_lobby_ends_at = v_next_sunday_7pm,
    game_starts_at = v_next_sunday_8pm,
    updated_at = NOW()
  WHERE id = p_game_id;

  RETURN jsonb_build_object(
    'game_id', p_game_id,
    'lobby_opens', v_now,
    'lobby_closes', v_next_sunday_7pm,
    'queen_selection', v_next_sunday_8pm,
    'first_scenarios', v_monday_9am,
    'days_until_launch', EXTRACT(days FROM (v_next_sunday_8pm - v_now))
  );

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Check and launch games when Sunday 7 PM ET arrives
-- Runs every minute via check_lobby_timers cron
CREATE OR REPLACE FUNCTION public.check_and_launch_sunday_games()
RETURNS JSONB AS $$
DECLARE
  v_game RECORD;
  v_launched_games JSONB := '[]'::JSONB;
BEGIN

  -- Find games ready to launch (lobby closed, waiting for queen selection)
  FOR v_game IN
    SELECT id, title, waiting_lobby_ends_at
    FROM mm_games
    WHERE status = 'waiting_lobby'
      AND waiting_lobby_ends_at <= NOW()
  LOOP

    -- Update game status to active_lobby (queen will be selected in 1 hour)
    UPDATE mm_games
    SET
      status = 'active_lobby',
      updated_at = NOW()
    WHERE id = v_game.id;

    -- Notify all players
    INSERT INTO notifications (user_id, notification_type, title, message, link_url)
    SELECT
      cm.user_id,
      'game_starting',
      'Game Launching Soon!',
      'Lobby closed! Queen selection in 1 hour at 8 PM ET. Get ready!',
      '/pages/player-dashboard.html?game=' || v_game.id
    FROM mm_game_cast gc
    JOIN cast_members cm ON cm.id = gc.cast_member_id
    WHERE gc.game_id = v_game.id AND cm.user_id IS NOT NULL;

    v_launched_games := v_launched_games || jsonb_build_object(
      'game_id', v_game.id,
      'title', v_game.title,
      'lobby_closed_at', v_game.waiting_lobby_ends_at
    );

  END LOOP;

  RETURN jsonb_build_object('launched_games', v_launched_games);

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update lobby timer cron to use new function
SELECT cron.unschedule('check_lobby_timers')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'check_lobby_timers');

SELECT cron.schedule(
  'check_lobby_timers',
  '* * * * *',  -- Every minute
  $$
  SELECT public.check_and_launch_sunday_games();
  $$
);

-- ============================================================================
-- GRANTS
-- ============================================================================
GRANT EXECUTE ON FUNCTION public.initialize_week_long_lobby(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_and_launch_sunday_games() TO authenticated;

-- ============================================================================
-- VERIFICATION
-- ============================================================================
SELECT
  jobid,
  jobname,
  schedule,
  active,
  CASE jobname
    WHEN 'weekly_elimination' THEN 'Sunday 7:30 PM ET'
    WHEN 'weekly_queen_selection' THEN 'Sunday 8 PM ET (GAME LAUNCH)'
    WHEN 'distribute_daily_scenarios' THEN 'Monday 9 AM ET'
    WHEN 'ai_agent_processor' THEN 'Every 3 minutes'
    WHEN 'check_lobby_timers' THEN 'Every minute'
    ELSE 'Other'
  END as eastern_time
FROM cron.job
ORDER BY jobname;
