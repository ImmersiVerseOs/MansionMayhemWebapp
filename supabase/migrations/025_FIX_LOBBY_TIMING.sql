-- =====================================================
-- FIX LOBBY TIMING - Proper timezone handling
-- Correct Sunday 7pm ET close and 8:30pm ET reopen
-- =====================================================

CREATE OR REPLACE FUNCTION public.initialize_week_long_lobby(p_game_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_now TIMESTAMPTZ := NOW();
  v_et_now TIMESTAMP;
  v_next_sunday_7pm_et TIMESTAMP;
  v_next_sunday_7pm_utc TIMESTAMPTZ;
  v_next_sunday_830pm_utc TIMESTAMPTZ;
  v_monday_9am_utc TIMESTAMPTZ;
  v_days_until_sunday INTEGER;
BEGIN

  -- Get current time in Eastern Time
  v_et_now := v_now AT TIME ZONE 'America/New_York';

  -- Calculate days until next Sunday (0 = Sunday, 6 = Saturday)
  v_days_until_sunday := (7 - EXTRACT(DOW FROM v_et_now)::INTEGER) % 7;

  -- If it's already Sunday and past 7pm, go to next week
  IF EXTRACT(DOW FROM v_et_now) = 0 AND EXTRACT(HOUR FROM v_et_now) >= 19 THEN
    v_days_until_sunday := 7;
  ELSIF v_days_until_sunday = 0 THEN
    -- If it's Sunday but before 7pm, use today
    v_days_until_sunday := 0;
  END IF;

  -- Calculate next Sunday at 7 PM Eastern Time
  v_next_sunday_7pm_et := date_trunc('day', v_et_now)
    + (v_days_until_sunday || ' days')::INTERVAL
    + interval '19 hours';  -- 7 PM = 19:00

  -- Convert to UTC for storage (CRITICAL for proper timezone handling)
  v_next_sunday_7pm_utc := v_next_sunday_7pm_et AT TIME ZONE 'America/New_York';

  -- Sunday 8:30 PM ET (90 minutes after lobby closes for queen selection)
  v_next_sunday_830pm_utc := v_next_sunday_7pm_utc + interval '1 hour 30 minutes';

  -- Monday 9 AM ET (first scenarios)
  v_monday_9am_utc := v_next_sunday_830pm_utc + interval '12 hours 30 minutes';

  -- Update game with correct timestamps
  UPDATE mm_games SET
    status = 'waiting_lobby',
    waiting_lobby_starts_at = v_now,
    waiting_lobby_ends_at = v_next_sunday_7pm_utc,
    game_starts_at = v_next_sunday_830pm_utc,
    updated_at = NOW()
  WHERE id = p_game_id;

  RETURN jsonb_build_object(
    'game_id', p_game_id,
    'current_time_et', v_et_now,
    'lobby_opens', v_now,
    'lobby_closes_utc', v_next_sunday_7pm_utc,
    'lobby_closes_et', v_next_sunday_7pm_utc AT TIME ZONE 'America/New_York',
    'queen_selection_utc', v_next_sunday_830pm_utc,
    'queen_selection_et', v_next_sunday_830pm_utc AT TIME ZONE 'America/New_York',
    'first_scenarios_utc', v_monday_9am_utc,
    'first_scenarios_et', v_monday_9am_utc AT TIME ZONE 'America/New_York',
    'hours_until_close', ROUND(EXTRACT(EPOCH FROM (v_next_sunday_7pm_utc - v_now)) / 3600, 1)
  );

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update check_and_launch function to handle 8:30pm start
CREATE OR REPLACE FUNCTION public.check_and_launch_sunday_games()
RETURNS JSONB AS $$
DECLARE
  v_game RECORD;
  v_launched_games JSONB := '[]'::JSONB;
BEGIN

  -- Find games ready to launch (lobby closed at 7pm ET, now it's 8:30pm ET)
  FOR v_game IN
    SELECT id, title, waiting_lobby_ends_at, game_starts_at
    FROM mm_games
    WHERE status = 'waiting_lobby'
      AND waiting_lobby_ends_at < NOW()
      AND game_starts_at <= NOW()
  LOOP
    -- Launch the game to active status
    UPDATE mm_games
    SET
      status = 'active',
      started_at = NOW(),
      updated_at = NOW()
    WHERE id = v_game.id;

    v_launched_games := v_launched_games || jsonb_build_object(
      'game_id', v_game.id,
      'title', v_game.title,
      'launched_at', NOW()
    );

    RAISE NOTICE '🎬 Game launched: % (ID: %)', v_game.title, v_game.id;
  END LOOP;

  RETURN jsonb_build_object(
    'launched_count', jsonb_array_length(v_launched_games),
    'games', v_launched_games,
    'checked_at', NOW()
  );

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
