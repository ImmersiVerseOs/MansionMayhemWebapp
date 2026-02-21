-- ============================================================================
-- MIGRATION 046: EVENT HANDLER FUNCTIONS
-- ============================================================================
-- Thin wrapper functions that delegate to existing game logic.
-- Each handler is called by process_game_events() in migration 045.
-- Handlers check game_mode to adjust behavior for blitz/sprint.
-- ============================================================================

-- ============================================================================
-- 1. handle_event_lobby_check - Delegates to check_and_launch_sunday_games()
-- ============================================================================
CREATE OR REPLACE FUNCTION public.handle_event_lobby_check(
  p_game_id UUID,
  p_payload JSONB DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_game RECORD;
BEGIN
  SELECT * INTO v_game FROM mm_games WHERE id = p_game_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('skipped', true, 'reason', 'game_not_found');
  END IF;

  -- Only check lobbies for games in lobby states
  IF v_game.status NOT IN ('waiting_lobby', 'active_lobby') THEN
    -- Cancel recurring lobby checks once game is past lobby
    UPDATE game_events
    SET status = 'cancelled'
    WHERE game_id = p_game_id
      AND event_type = 'lobby_check'
      AND status = 'scheduled';

    RETURN jsonb_build_object('skipped', true, 'reason', 'not_in_lobby', 'status', v_game.status);
  END IF;

  -- Delegate to existing function (works on all games, but we only care about this one)
  PERFORM check_and_launch_sunday_games();

  RETURN jsonb_build_object('success', true, 'game_status', v_game.status);
END;
$$;

-- ============================================================================
-- 2. handle_event_lobby_fill - Delegates to fill_lobbies_to_20() / spawn_ai
-- ============================================================================
CREATE OR REPLACE FUNCTION public.handle_event_lobby_fill(
  p_game_id UUID,
  p_payload JSONB DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_game RECORD;
  v_mode TEXT;
BEGIN
  SELECT * INTO v_game FROM mm_games WHERE id = p_game_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('skipped', true, 'reason', 'game_not_found');
  END IF;

  v_mode := COALESCE(v_game.game_mode, 'weekly');

  -- For blitz/sprint, fill immediately to speed up start
  IF v_mode IN ('blitz', 'sprint') THEN
    -- Use auto_fill directly for this specific game
    PERFORM auto_fill_ai_cast(p_game_id, v_game.max_players);
  ELSE
    -- Weekly mode: use global fill function
    PERFORM fill_lobbies_to_20();
    PERFORM spawn_ai_into_lobbies();
  END IF;

  RETURN jsonb_build_object('success', true, 'mode', v_mode);
END;
$$;

-- ============================================================================
-- 3. handle_event_game_start - Activates game, schedules events
-- ============================================================================
CREATE OR REPLACE FUNCTION public.handle_event_game_start(
  p_game_id UUID,
  p_payload JSONB DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_game RECORD;
  v_mode TEXT;
BEGIN
  SELECT * INTO v_game FROM mm_games WHERE id = p_game_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('skipped', true, 'reason', 'game_not_found');
  END IF;

  -- Only start if game is in lobby state
  IF v_game.status NOT IN ('active_lobby', 'waiting_lobby', 'recruiting') THEN
    RETURN jsonb_build_object('skipped', true, 'reason', 'not_in_lobby', 'status', v_game.status);
  END IF;

  v_mode := COALESCE(v_game.game_mode, 'weekly');

  -- Transition to active
  UPDATE mm_games
  SET status = 'active',
      started_at = COALESCE(started_at, NOW()),
      current_week = 1,
      current_phase = CASE v_mode
        WHEN 'blitz' THEN 'act_1_alliance_hour'
        WHEN 'sprint' THEN 'day_1_alliances'
        ELSE 'gameplay_week_1'
      END,
      phase_started_at = NOW()
  WHERE id = p_game_id;

  -- Cancel lobby-related recurring events
  UPDATE game_events
  SET status = 'cancelled'
  WHERE game_id = p_game_id
    AND event_type IN ('lobby_check', 'lobby_fill')
    AND status = 'scheduled';

  RETURN jsonb_build_object('success', true, 'mode', v_mode, 'started_at', NOW());
END;
$$;

-- ============================================================================
-- 4. handle_event_scenario_distribute - Per-game scenario distribution
-- ============================================================================
CREATE OR REPLACE FUNCTION public.handle_event_scenario_distribute(
  p_game_id UUID,
  p_payload JSONB DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_game RECORD;
  v_mode TEXT;
  v_deadline_hours INTEGER;
  v_result JSON;
BEGIN
  SELECT * INTO v_game FROM mm_games WHERE id = p_game_id;

  IF NOT FOUND OR v_game.status NOT IN ('active', 'final_three', 'finale') THEN
    RETURN jsonb_build_object('skipped', true, 'reason', 'game_not_active');
  END IF;

  v_mode := COALESCE(v_game.game_mode, 'weekly');

  -- Mode-specific deadline
  v_deadline_hours := CASE v_mode
    WHEN 'blitz' THEN COALESCE((p_payload->>'deadline_hours')::INTEGER, 1)
    WHEN 'sprint' THEN COALESCE((p_payload->>'deadline_hours')::INTEGER, 4)
    ELSE 120  -- 5 days for weekly
  END;

  -- Delegate to existing global function
  -- (distribute_daily_scenarios works across all active games)
  v_result := distribute_daily_scenarios();

  RETURN jsonb_build_object(
    'success', true,
    'mode', v_mode,
    'deadline_hours', v_deadline_hours,
    'distribution_result', v_result::jsonb
  );
END;
$$;

-- ============================================================================
-- 5. handle_event_queen_selection - Per-game queen selection
-- ============================================================================
CREATE OR REPLACE FUNCTION public.handle_event_queen_selection(
  p_game_id UUID,
  p_payload JSONB DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_game RECORD;
  v_result JSONB;
BEGIN
  SELECT * INTO v_game FROM mm_games WHERE id = p_game_id;

  IF NOT FOUND OR v_game.status NOT IN ('active', 'final_three', 'finale') THEN
    RETURN jsonb_build_object('skipped', true, 'reason', 'game_not_active');
  END IF;

  -- Delegate to existing per-game function
  v_result := start_queen_selection(p_game_id);

  RETURN jsonb_build_object('success', true, 'result', v_result);
END;
$$;

-- ============================================================================
-- 6. handle_event_hot_seat - Per-game hot seat nominations
-- ============================================================================
CREATE OR REPLACE FUNCTION public.handle_event_hot_seat(
  p_game_id UUID,
  p_payload JSONB DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_game RECORD;
  v_mode TEXT;
  v_result JSONB;
BEGIN
  SELECT * INTO v_game FROM mm_games WHERE id = p_game_id;

  IF NOT FOUND OR v_game.status NOT IN ('active', 'final_three') THEN
    RETURN jsonb_build_object('skipped', true, 'reason', 'game_not_active');
  END IF;

  v_mode := COALESCE(v_game.game_mode, 'weekly');

  -- Delegate to existing per-game function
  v_result := start_saturday_hot_seat(p_game_id);

  -- For blitz/sprint, the payload carries shortened deadlines
  -- The handler functions in 026 use fixed times, but the payload
  -- is available for future override logic

  RETURN jsonb_build_object(
    'success', true,
    'mode', v_mode,
    'nomination_hours', COALESCE((p_payload->>'nomination_hours')::INTEGER,
      CASE v_mode WHEN 'blitz' THEN 1 WHEN 'sprint' THEN 2 ELSE 4 END),
    'vote_hours', COALESCE((p_payload->>'vote_hours')::INTEGER,
      CASE v_mode WHEN 'blitz' THEN 2 WHEN 'sprint' THEN 4 ELSE 12 END),
    'result', v_result
  );
END;
$$;

-- ============================================================================
-- 7. handle_event_voting_open - Start voting round
-- ============================================================================
CREATE OR REPLACE FUNCTION public.handle_event_voting_open(
  p_game_id UUID,
  p_payload JSONB DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_game RECORD;
  v_mode TEXT;
  v_voting_hours INTEGER;
  v_is_finale BOOLEAN;
BEGIN
  SELECT * INTO v_game FROM mm_games WHERE id = p_game_id;

  IF NOT FOUND OR v_game.status NOT IN ('active', 'final_three', 'finale') THEN
    RETURN jsonb_build_object('skipped', true, 'reason', 'game_not_active');
  END IF;

  v_mode := COALESCE(v_game.game_mode, 'weekly');
  v_is_finale := COALESCE((p_payload->>'finale_vote')::BOOLEAN, false);
  v_voting_hours := COALESCE(
    (p_payload->>'voting_hours')::INTEGER,
    CASE v_mode WHEN 'blitz' THEN 2 WHEN 'sprint' THEN 6 ELSE 48 END
  );

  -- Create a voting round
  INSERT INTO mm_voting_rounds (
    game_id,
    week_number,
    status,
    voting_opens_at,
    voting_closes_at,
    round_type
  ) VALUES (
    p_game_id,
    COALESCE(v_game.current_week, 1),
    'open',
    NOW(),
    NOW() + (v_voting_hours * INTERVAL '1 hour'),
    CASE WHEN v_is_finale THEN 'finale' ELSE 'elimination' END
  );

  -- If finale, update game status
  IF v_is_finale THEN
    UPDATE mm_games SET status = 'finale' WHERE id = p_game_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'mode', v_mode,
    'voting_hours', v_voting_hours,
    'is_finale', v_is_finale,
    'closes_at', NOW() + (v_voting_hours * INTERVAL '1 hour')
  );
END;
$$;

-- ============================================================================
-- 8. handle_event_voting_close - Close voting and tally
-- ============================================================================
CREATE OR REPLACE FUNCTION public.handle_event_voting_close(
  p_game_id UUID,
  p_payload JSONB DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_game RECORD;
  v_round RECORD;
BEGIN
  SELECT * INTO v_game FROM mm_games WHERE id = p_game_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('skipped', true, 'reason', 'game_not_found');
  END IF;

  -- Find the most recent open voting round for this game
  SELECT * INTO v_round
  FROM mm_voting_rounds
  WHERE game_id = p_game_id
    AND status = 'open'
  ORDER BY created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('skipped', true, 'reason', 'no_open_voting_round');
  END IF;

  -- Close the voting round
  UPDATE mm_voting_rounds
  SET status = 'closed',
      voting_closes_at = NOW()
  WHERE id = v_round.id;

  RETURN jsonb_build_object(
    'success', true,
    'round_id', v_round.id,
    'week', v_round.week_number
  );
END;
$$;

-- ============================================================================
-- 9. handle_event_elimination - Announce elimination
-- ============================================================================
CREATE OR REPLACE FUNCTION public.handle_event_elimination(
  p_game_id UUID,
  p_payload JSONB DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_game RECORD;
  v_mode TEXT;
  v_result JSONB;
  v_chain_next BOOLEAN;
BEGIN
  SELECT * INTO v_game FROM mm_games WHERE id = p_game_id;

  IF NOT FOUND OR v_game.status NOT IN ('active', 'final_three', 'finale') THEN
    RETURN jsonb_build_object('skipped', true, 'reason', 'game_not_active');
  END IF;

  v_mode := COALESCE(v_game.game_mode, 'weekly');
  v_chain_next := COALESCE((p_payload->>'chain_next_week')::BOOLEAN, false);

  -- Delegate to existing per-game function
  v_result := announce_elimination(p_game_id);

  -- For weekly mode: chain to next week if flag is set
  IF v_mode = 'weekly' AND v_chain_next THEN
    PERFORM chain_next_week(p_game_id);
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'mode', v_mode,
    'chained_next_week', v_chain_next,
    'result', v_result
  );
END;
$$;

-- ============================================================================
-- 10. handle_event_ai_director - HTTP POST to ai-director edge function
-- ============================================================================
CREATE OR REPLACE FUNCTION public.handle_event_ai_director(
  p_game_id UUID,
  p_payload JSONB DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_game RECORD;
  v_mode TEXT;
BEGIN
  SELECT * INTO v_game FROM mm_games WHERE id = p_game_id;

  IF NOT FOUND OR v_game.status NOT IN ('active', 'final_three', 'finale') THEN
    RETURN jsonb_build_object('skipped', true, 'reason', 'game_not_active');
  END IF;

  v_mode := COALESCE(v_game.game_mode, 'weekly');

  -- HTTP POST to ai-director edge function with game context
  PERFORM net.http_post(
    url := current_setting('app.supabase_url', true) || '/functions/v1/ai-director',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.supabase_anon_key', true)
    ),
    body := jsonb_build_object(
      'game_id', p_game_id,
      'game_mode', v_mode,
      'priority_boost', CASE v_mode
        WHEN 'blitz' THEN 3
        WHEN 'sprint' THEN 1
        ELSE 0
      END
    )
  );

  RETURN jsonb_build_object('success', true, 'mode', v_mode, 'dispatched', true);
EXCEPTION WHEN OTHERS THEN
  -- Fallback: try with hardcoded URL if app settings not available
  BEGIN
    PERFORM net.http_post(
      url := 'https://fpxbhqibimekjhlumnmc.supabase.co/functions/v1/ai-director',
      headers := '{"Content-Type": "application/json"}'::jsonb,
      body := jsonb_build_object('game_id', p_game_id, 'game_mode', v_mode)
    );
    RETURN jsonb_build_object('success', true, 'mode', v_mode, 'dispatched', true, 'fallback', true);
  EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
  END;
END;
$$;

-- ============================================================================
-- 11. handle_event_ai_tea - Per-game tea room posts
-- ============================================================================
CREATE OR REPLACE FUNCTION public.handle_event_ai_tea(
  p_game_id UUID,
  p_payload JSONB DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_game RECORD;
BEGIN
  SELECT * INTO v_game FROM mm_games WHERE id = p_game_id;

  IF NOT FOUND OR v_game.status NOT IN ('active', 'final_three', 'finale') THEN
    RETURN jsonb_build_object('skipped', true, 'reason', 'game_not_active');
  END IF;

  -- Delegate to existing function (queues tea posts for all active games)
  PERFORM queue_ai_tea_room_posts();

  RETURN jsonb_build_object('success', true);
END;
$$;

-- ============================================================================
-- 12. handle_event_ai_linkups - Per-game link-up requests
-- ============================================================================
CREATE OR REPLACE FUNCTION public.handle_event_ai_linkups(
  p_game_id UUID,
  p_payload JSONB DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_game RECORD;
BEGIN
  SELECT * INTO v_game FROM mm_games WHERE id = p_game_id;

  IF NOT FOUND OR v_game.status NOT IN ('active', 'final_three', 'finale') THEN
    RETURN jsonb_build_object('skipped', true, 'reason', 'game_not_active');
  END IF;

  -- Delegate to existing function
  PERFORM queue_ai_link_up_requests();

  RETURN jsonb_build_object('success', true);
END;
$$;

-- ============================================================================
-- 13. handle_event_ai_process - HTTP POST to ai-agent-processor
-- ============================================================================
CREATE OR REPLACE FUNCTION public.handle_event_ai_process(
  p_game_id UUID,
  p_payload JSONB DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_game RECORD;
  v_mode TEXT;
BEGIN
  SELECT * INTO v_game FROM mm_games WHERE id = p_game_id;

  IF NOT FOUND OR v_game.status NOT IN ('active', 'active_lobby', 'final_three', 'finale') THEN
    RETURN jsonb_build_object('skipped', true, 'reason', 'game_not_active');
  END IF;

  v_mode := COALESCE(v_game.game_mode, 'weekly');

  -- HTTP POST to ai-agent-processor edge function
  PERFORM net.http_post(
    url := current_setting('app.supabase_url', true) || '/functions/v1/ai-agent-processor',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.supabase_anon_key', true)
    ),
    body := jsonb_build_object(
      'game_id', p_game_id,
      'game_mode', v_mode
    )
  );

  RETURN jsonb_build_object('success', true, 'mode', v_mode, 'dispatched', true);
EXCEPTION WHEN OTHERS THEN
  BEGIN
    PERFORM net.http_post(
      url := 'https://fpxbhqibimekjhlumnmc.supabase.co/functions/v1/ai-agent-processor',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZweGJocWliaW1la2pobHVtbm1jIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEwMjUwODYsImV4cCI6MjA4NjYwMTA4Nn0.0BmbaObOERMZ5r4znb5BQbrGpB5lE5Fq6KnEzxA0YhY'
      ),
      body := jsonb_build_object('game_id', p_game_id, 'game_mode', v_mode)
    );
    RETURN jsonb_build_object('success', true, 'mode', v_mode, 'dispatched', true, 'fallback', true);
  EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
  END;
END;
$$;

-- ============================================================================
-- 14. handle_event_cleanup - Cleanup old AI actions
-- ============================================================================
CREATE OR REPLACE FUNCTION public.handle_event_cleanup(
  p_game_id UUID,
  p_payload JSONB DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Delegate to existing cleanup function
  PERFORM cleanup_ai_action_queue();

  -- Also clean up completed game events older than 30 days
  DELETE FROM game_events
  WHERE status IN ('completed', 'cancelled')
    AND completed_at < NOW() - INTERVAL '30 days';

  RETURN jsonb_build_object('success', true);
END;
$$;

-- ============================================================================
-- 15. handle_event_game_end - Complete the game
-- ============================================================================
CREATE OR REPLACE FUNCTION public.handle_event_game_end(
  p_game_id UUID,
  p_payload JSONB DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_game RECORD;
  v_reason TEXT;
  v_cancelled_count INTEGER;
BEGIN
  SELECT * INTO v_game FROM mm_games WHERE id = p_game_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('skipped', true, 'reason', 'game_not_found');
  END IF;

  -- Don't end a game that's already completed
  IF v_game.status IN ('completed', 'cancelled') THEN
    RETURN jsonb_build_object('skipped', true, 'reason', 'already_ended');
  END IF;

  v_reason := COALESCE(p_payload->>'reason', 'event_triggered');

  -- Mark game as completed
  UPDATE mm_games
  SET status = 'completed',
      completed_at = NOW(),
      current_phase = 'completed'
  WHERE id = p_game_id;

  -- Cancel all remaining scheduled events
  v_cancelled_count := cancel_game_events(p_game_id);

  RETURN jsonb_build_object(
    'success', true,
    'reason', v_reason,
    'events_cancelled', v_cancelled_count,
    'completed_at', NOW()
  );
END;
$$;

-- ============================================================================
-- 16. handle_event_party_round - Start a new party round
-- ============================================================================
CREATE OR REPLACE FUNCTION public.handle_event_party_round(
  p_game_id UUID,
  p_payload JSONB DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_game RECORD;
  v_round INTEGER;
  v_active_count INTEGER;
  v_survivor RECORD;
BEGIN
  SELECT * INTO v_game FROM mm_games WHERE id = p_game_id;

  IF NOT FOUND OR v_game.status NOT IN ('active', 'final_three', 'finale') THEN
    RETURN jsonb_build_object('skipped', true, 'reason', 'game_not_active');
  END IF;

  v_round := COALESCE((p_payload->>'round')::INTEGER, 1);

  -- Initialize leaderboard on round 1
  IF v_round = 1 THEN
    PERFORM init_party_leaderboard(p_game_id);
  END IF;

  -- Update game phase
  UPDATE mm_games
  SET current_phase = 'round_' || v_round,
      current_week = v_round,
      phase_started_at = NOW()
  WHERE id = p_game_id;

  -- Count active (non-eliminated) players
  SELECT count(*) INTO v_active_count
  FROM party_leaderboard
  WHERE game_id = p_game_id AND is_eliminated = false;

  -- Award survival points to everyone still alive (rounds 2+)
  IF v_round > 1 THEN
    FOR v_survivor IN
      SELECT cast_member_id FROM party_leaderboard
      WHERE game_id = p_game_id AND is_eliminated = false
    LOOP
      PERFORM party_award_points(p_game_id, v_survivor.cast_member_id, 'survived_round', 3, v_round);
    END LOOP;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'round', v_round,
    'active_players', v_active_count
  );
END;
$$;

-- ============================================================================
-- 17. handle_event_random_event - Trigger a random party event
-- ============================================================================
CREATE OR REPLACE FUNCTION public.handle_event_random_event(
  p_game_id UUID,
  p_payload JSONB DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_game RECORD;
  v_round INTEGER;
  v_event_name TEXT;
  v_display_name TEXT;
  v_description TEXT;
  v_event_names TEXT[] := ARRAY[
    'spill_or_be_spilled',
    'alliance_auction',
    'the_receipt',
    'immunity_idol',
    'double_or_nothing'
  ];
  v_display_names TEXT[] := ARRAY[
    'Spill or Be Spilled',
    'Alliance Auction',
    'The Receipt',
    'Immunity Idol',
    'Double or Nothing'
  ];
  v_descriptions TEXT[] := ARRAY[
    'Answer a drama question about another player. Best answer wins +5 points.',
    'Bid your points to steal someone''s alliance member. Highest bid wins.',
    'A random alliance chat gets EXPOSED to everyone. Chaos incoming.',
    'Quick reaction challenge. Winner cannot be eliminated this round.',
    'Bet your points on who gets eliminated. Win = double, lose = zero.'
  ];
  v_idx INTEGER;
  v_winner_id UUID;
  v_active_cast UUID[];
BEGIN
  SELECT * INTO v_game FROM mm_games WHERE id = p_game_id;

  IF NOT FOUND OR v_game.status NOT IN ('active', 'final_three', 'finale') THEN
    RETURN jsonb_build_object('skipped', true, 'reason', 'game_not_active');
  END IF;

  v_round := COALESCE((p_payload->>'round')::INTEGER, 1);

  -- Pick a random event
  v_idx := 1 + floor(random() * 5)::INTEGER;
  IF v_idx > 5 THEN v_idx := 5; END IF;
  v_event_name := v_event_names[v_idx];
  v_display_name := v_display_names[v_idx];
  v_description := v_descriptions[v_idx];

  -- Get active (non-eliminated) cast members
  SELECT array_agg(cast_member_id) INTO v_active_cast
  FROM party_leaderboard
  WHERE game_id = p_game_id AND is_eliminated = false;

  -- For AI-driven resolution: pick a random winner from active cast
  -- (In production, this would involve actual player interaction)
  IF v_active_cast IS NOT NULL AND array_length(v_active_cast, 1) > 0 THEN
    v_winner_id := v_active_cast[1 + floor(random() * array_length(v_active_cast, 1))::INTEGER];

    -- Award event win points
    PERFORM party_award_points(p_game_id, v_winner_id, 'event_win', 5, v_round);
  END IF;

  -- Log the random event
  INSERT INTO party_random_events (
    game_id, round_number, event_name, display_name, description,
    status, winner_cast_id, started_at, completed_at,
    payload, result
  ) VALUES (
    p_game_id, v_round, v_event_name, v_display_name, v_description,
    'completed', v_winner_id, NOW(), NOW(),
    p_payload,
    jsonb_build_object('winner_id', v_winner_id)
  );

  RETURN jsonb_build_object(
    'success', true,
    'round', v_round,
    'event', v_event_name,
    'display_name', v_display_name,
    'winner_id', v_winner_id
  );
END;
$$;

-- ============================================================================
-- 18. handle_event_party_elimination - Eliminate 3 cast per round
-- ============================================================================
CREATE OR REPLACE FUNCTION public.handle_event_party_elimination(
  p_game_id UUID,
  p_payload JSONB DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_game RECORD;
  v_round INTEGER;
  v_eliminate_count INTEGER;
  v_queen_id UUID;
  v_queen_pick UUID;
  v_cast_picks UUID[];
  v_eliminated UUID[] := ARRAY[]::UUID[];
  v_active_cast RECORD;
  v_active_count INTEGER;
  v_vote_counts RECORD;
  v_remaining INTEGER;
BEGIN
  SELECT * INTO v_game FROM mm_games WHERE id = p_game_id;

  IF NOT FOUND OR v_game.status NOT IN ('active', 'final_three', 'finale') THEN
    RETURN jsonb_build_object('skipped', true, 'reason', 'game_not_active');
  END IF;

  v_round := COALESCE((p_payload->>'round')::INTEGER, 1);
  v_eliminate_count := COALESCE((p_payload->>'eliminate_count')::INTEGER, 3);

  -- Count active players
  SELECT count(*) INTO v_active_count
  FROM party_leaderboard
  WHERE game_id = p_game_id AND is_eliminated = false;

  -- If 2 or fewer remain, don't eliminate - game should end
  IF v_active_count <= 2 THEN
    RETURN jsonb_build_object(
      'skipped', true,
      'reason', 'too_few_players',
      'active_count', v_active_count
    );
  END IF;

  -- Don't eliminate more than would leave 2 players
  IF v_active_count - v_eliminate_count < 2 THEN
    v_eliminate_count := v_active_count - 2;
  END IF;

  -- Get current queen (most recent queen selection for this game)
  SELECT qs.cast_member_id INTO v_queen_id
  FROM mm_queen_selections qs
  WHERE qs.game_id = p_game_id
  ORDER BY qs.created_at DESC
  LIMIT 1;

  -- QUEEN PICKS 1: Lowest score non-queen active player gets picked by queen
  -- (In production, queen would actually choose - for AI, pick lowest scorer)
  IF v_queen_id IS NOT NULL THEN
    SELECT pl.cast_member_id INTO v_queen_pick
    FROM party_leaderboard pl
    WHERE pl.game_id = p_game_id
      AND pl.is_eliminated = false
      AND pl.cast_member_id != v_queen_id
    ORDER BY pl.total_score ASC
    LIMIT 1;

    IF v_queen_pick IS NOT NULL THEN
      v_eliminated := array_append(v_eliminated, v_queen_pick);

      -- Mark eliminated
      UPDATE party_leaderboard
      SET is_eliminated = true, eliminated_in_round = v_round, updated_at = NOW()
      WHERE game_id = p_game_id AND cast_member_id = v_queen_pick;

      -- Update cast status
      UPDATE mm_game_cast
      SET status = 'eliminated'
      WHERE game_id = p_game_id AND cast_member_id = v_queen_pick;
    END IF;
  END IF;

  -- CAST VOTES FOR 2 MORE: Next 2 lowest scorers who aren't queen or already eliminated
  FOR v_active_cast IN
    SELECT pl.cast_member_id, pl.total_score
    FROM party_leaderboard pl
    WHERE pl.game_id = p_game_id
      AND pl.is_eliminated = false
      AND pl.cast_member_id != COALESCE(v_queen_id, '00000000-0000-0000-0000-000000000000'::UUID)
    ORDER BY pl.total_score ASC
    LIMIT (v_eliminate_count - array_length(v_eliminated, 1))
  LOOP
    v_eliminated := array_append(v_eliminated, v_active_cast.cast_member_id);

    UPDATE party_leaderboard
    SET is_eliminated = true, eliminated_in_round = v_round, updated_at = NOW()
    WHERE game_id = p_game_id AND cast_member_id = v_active_cast.cast_member_id;

    UPDATE mm_game_cast
    SET status = 'eliminated'
    WHERE game_id = p_game_id AND cast_member_id = v_active_cast.cast_member_id;
  END LOOP;

  -- Count remaining
  SELECT count(*) INTO v_remaining
  FROM party_leaderboard
  WHERE game_id = p_game_id AND is_eliminated = false;

  -- If only 2 left, update game status
  IF v_remaining <= 2 THEN
    UPDATE mm_games
    SET status = 'finale',
        current_phase = 'finale'
    WHERE id = p_game_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'round', v_round,
    'eliminated', to_jsonb(v_eliminated),
    'eliminated_count', array_length(v_eliminated, 1),
    'queen_pick', v_queen_pick,
    'remaining_players', v_remaining
  );
END;
$$;

-- ============================================================================
-- VERIFICATION
-- ============================================================================
SELECT proname AS handler_function
FROM pg_proc
WHERE proname LIKE 'handle_event_%'
ORDER BY proname;
