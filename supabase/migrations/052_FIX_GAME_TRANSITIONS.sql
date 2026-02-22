-- ============================================================================
-- MIGRATION 052: FIX GAME STATE MACHINE & JOIN GAME RPC
-- ============================================================================
-- Completes handle_event_lobby_check (count players, auto-start)
-- Completes handle_event_voting_close (tally votes, mark eliminated)
-- Completes handle_event_elimination (update cast, chain next round)
-- Creates join_game() RPC for clean player onboarding
-- ============================================================================

-- ============================================================================
-- 1. FIXED: handle_event_lobby_check
-- Counts mm_game_cast rows, auto-starts when minimum reached
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
  v_mode TEXT;
  v_cast_count INTEGER;
  v_min_players INTEGER;
  v_max_players INTEGER;
  v_ai_count INTEGER;
BEGIN
  SELECT * INTO v_game FROM mm_games WHERE id = p_game_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('skipped', true, 'reason', 'game_not_found');
  END IF;

  -- Only process games in lobby states
  IF v_game.status NOT IN ('waiting_lobby', 'active_lobby', 'recruiting') THEN
    -- Cancel recurring lobby checks
    UPDATE game_events SET status = 'cancelled'
    WHERE game_id = p_game_id AND event_type = 'lobby_check' AND status = 'scheduled';
    RETURN jsonb_build_object('skipped', true, 'reason', 'not_in_lobby', 'status', v_game.status);
  END IF;

  v_mode := COALESCE(v_game.game_mode, 'weekly');

  -- Count current cast (humans + AI)
  SELECT count(*) INTO v_cast_count
  FROM mm_game_cast WHERE game_id = p_game_id AND status = 'active';

  -- Count AI specifically
  SELECT count(*) INTO v_ai_count
  FROM mm_game_cast gc
  JOIN cast_members cm ON cm.id = gc.cast_member_id
  WHERE gc.game_id = p_game_id AND gc.status = 'active' AND cm.is_ai_player = true;

  -- Mode-specific minimum players
  v_min_players := CASE v_mode
    WHEN 'party' THEN 8
    WHEN 'blitz' THEN 6
    WHEN 'sprint' THEN 4
    ELSE v_game.max_players -- weekly waits for full
  END;

  v_max_players := COALESCE(v_game.max_players, 20);

  -- Check lobby timeout (auto-start with AI fill)
  -- Party: 2 min timeout, Blitz: 5 min, Sprint: 10 min
  IF v_game.phase_started_at IS NOT NULL THEN
    DECLARE
      v_elapsed_secs INTEGER;
      v_timeout_secs INTEGER;
    BEGIN
      v_elapsed_secs := EXTRACT(EPOCH FROM (NOW() - v_game.phase_started_at))::INTEGER;
      v_timeout_secs := CASE v_mode
        WHEN 'party' THEN 120
        WHEN 'blitz' THEN 300
        WHEN 'sprint' THEN 600
        ELSE 86400 -- weekly: 24hr lobby
      END;

      -- If timeout reached AND we have at least 2 human players, auto-fill and start
      IF v_elapsed_secs >= v_timeout_secs AND (v_cast_count - v_ai_count) >= 1 THEN
        -- Fill remaining slots with AI (cap at 6 AI agents)
        DECLARE
          v_fill_count INTEGER;
          v_ai_to_add INTEGER;
          v_ai_cast RECORD;
        BEGIN
          v_fill_count := LEAST(v_max_players, 12) - v_cast_count; -- Target 12 max for faster games
          v_ai_to_add := LEAST(v_fill_count, 6 - v_ai_count); -- Cap total AI at 6

          IF v_ai_to_add > 0 THEN
            FOR v_ai_cast IN
              SELECT id FROM cast_members
              WHERE is_ai_player = true AND status = 'active'
              AND id NOT IN (SELECT cast_member_id FROM mm_game_cast WHERE game_id = p_game_id)
              LIMIT v_ai_to_add
            LOOP
              INSERT INTO mm_game_cast (game_id, cast_member_id, status)
              VALUES (p_game_id, v_ai_cast.id, 'active')
              ON CONFLICT (game_id, cast_member_id) DO NOTHING;
            END LOOP;
          END IF;
        END;

        -- Recount after fill
        SELECT count(*) INTO v_cast_count
        FROM mm_game_cast WHERE game_id = p_game_id AND status = 'active';
      END IF;
    END;
  END IF;

  -- If enough players, transition to active
  IF v_cast_count >= v_min_players OR (v_mode != 'weekly' AND v_cast_count >= 4) THEN
    -- Update game status
    UPDATE mm_games
    SET status = 'active',
        started_at = COALESCE(started_at, NOW()),
        current_week = 1,
        current_phase = 'arrival',
        phase_started_at = NOW(),
        current_players = v_cast_count
    WHERE id = p_game_id;

    -- Cancel lobby events
    UPDATE game_events SET status = 'cancelled'
    WHERE game_id = p_game_id
      AND event_type IN ('lobby_check', 'lobby_fill')
      AND status = 'scheduled';

    RETURN jsonb_build_object(
      'success', true,
      'action', 'game_started',
      'cast_count', v_cast_count,
      'ai_count', v_ai_count,
      'mode', v_mode
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'action', 'waiting',
    'cast_count', v_cast_count,
    'min_players', v_min_players,
    'mode', v_mode
  );
END;
$$;

-- ============================================================================
-- 2. FIXED: handle_event_voting_close
-- Tallies mm_elimination_votes, identifies eliminated player
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
  v_eliminated_id UUID;
  v_eliminated_name TEXT;
  v_votes_a INTEGER;
  v_votes_b INTEGER;
  v_vote_results JSONB;
BEGIN
  SELECT * INTO v_game FROM mm_games WHERE id = p_game_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('skipped', true, 'reason', 'game_not_found');
  END IF;

  -- Find the most recent open voting round
  SELECT * INTO v_round
  FROM mm_voting_rounds
  WHERE game_id = p_game_id AND status IN ('open', 'active')
  ORDER BY created_at DESC LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('skipped', true, 'reason', 'no_open_voting_round');
  END IF;

  -- Tally votes
  IF v_round.nominee_a_id IS NOT NULL AND v_round.nominee_b_id IS NOT NULL THEN
    -- Binary vote (A vs B nominees)
    SELECT count(*) INTO v_votes_a
    FROM mm_elimination_votes
    WHERE round_id = v_round.id AND voted_for_id = v_round.nominee_a_id;

    SELECT count(*) INTO v_votes_b
    FROM mm_elimination_votes
    WHERE round_id = v_round.id AND voted_for_id = v_round.nominee_b_id;

    -- Fewer votes = eliminated (they had less support to stay)
    IF v_votes_a <= v_votes_b THEN
      v_eliminated_id := v_round.nominee_a_id;
    ELSE
      v_eliminated_id := v_round.nominee_b_id;
    END IF;

    v_vote_results := jsonb_build_object(
      'nominee_a_votes', v_votes_a,
      'nominee_b_votes', v_votes_b,
      'method', 'binary'
    );
  ELSE
    -- Free-form vote (everyone can be voted for) — used in episode mode
    SELECT voted_for_id INTO v_eliminated_id
    FROM mm_elimination_votes
    WHERE round_id = v_round.id
    GROUP BY voted_for_id
    ORDER BY count(*) DESC
    LIMIT 1;

    SELECT jsonb_agg(jsonb_build_object('target', voted_for_id, 'votes', cnt))
    INTO v_vote_results
    FROM (
      SELECT voted_for_id, count(*) as cnt
      FROM mm_elimination_votes
      WHERE round_id = v_round.id
      GROUP BY voted_for_id
      ORDER BY count(*) DESC
    ) vote_tally;
  END IF;

  -- Get eliminated player name
  SELECT display_name INTO v_eliminated_name
  FROM cast_members WHERE id = v_eliminated_id;

  -- Update voting round
  UPDATE mm_voting_rounds
  SET status = 'completed',
      voting_closes_at = NOW(),
      votes_for_a = COALESCE(v_votes_a, 0),
      votes_for_b = COALESCE(v_votes_b, 0),
      eliminated_id = v_eliminated_id,
      house_vote_eliminated_id = v_eliminated_id
  WHERE id = v_round.id;

  -- Eliminate the player
  IF v_eliminated_id IS NOT NULL THEN
    UPDATE mm_game_cast
    SET status = 'eliminated', eliminated_at = NOW()
    WHERE game_id = p_game_id AND cast_member_id = v_eliminated_id;

    -- Update game player count
    UPDATE mm_games
    SET current_players = (
      SELECT count(*) FROM mm_game_cast
      WHERE game_id = p_game_id AND status = 'active'
    )
    WHERE id = p_game_id;
  END IF;

  -- Check if game should end (2 or fewer remaining)
  DECLARE
    v_remaining INTEGER;
  BEGIN
    SELECT count(*) INTO v_remaining
    FROM mm_game_cast WHERE game_id = p_game_id AND status = 'active';

    IF v_remaining <= 2 THEN
      UPDATE mm_games SET status = 'finale', current_phase = 'finale'
      WHERE id = p_game_id;
    END IF;
  END;

  RETURN jsonb_build_object(
    'success', true,
    'round_id', v_round.id,
    'eliminated_id', v_eliminated_id,
    'eliminated_name', v_eliminated_name,
    'vote_results', v_vote_results
  );
END;
$$;

-- ============================================================================
-- 3. FIXED: handle_event_elimination
-- Updates cast status, sends notification, chains to next round/week
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
  v_chain_next BOOLEAN;
  v_round RECORD;
  v_remaining INTEGER;
  v_eliminated_name TEXT;
BEGIN
  SELECT * INTO v_game FROM mm_games WHERE id = p_game_id;

  IF NOT FOUND OR v_game.status NOT IN ('active', 'final_three', 'finale') THEN
    RETURN jsonb_build_object('skipped', true, 'reason', 'game_not_active');
  END IF;

  v_mode := COALESCE(v_game.game_mode, 'weekly');
  v_chain_next := COALESCE((p_payload->>'chain_next_week')::BOOLEAN, false);

  -- Get most recent completed voting round for context
  SELECT vr.*, cm.display_name as eliminated_name
  INTO v_round
  FROM mm_voting_rounds vr
  LEFT JOIN cast_members cm ON cm.id = vr.eliminated_id
  WHERE vr.game_id = p_game_id AND vr.status = 'completed'
  ORDER BY vr.created_at DESC LIMIT 1;

  IF v_round IS NOT NULL THEN
    v_eliminated_name := v_round.eliminated_name;
  END IF;

  -- Count remaining active players
  SELECT count(*) INTO v_remaining
  FROM mm_game_cast WHERE game_id = p_game_id AND status = 'active';

  -- Create notification for all players
  INSERT INTO notifications (user_id, type, title, body, data)
  SELECT
    p.id,
    'elimination',
    '🔻 Elimination Results',
    COALESCE(v_eliminated_name, 'A cast member') || ' has been eliminated from the Mansion!',
    jsonb_build_object('game_id', p_game_id, 'eliminated_name', v_eliminated_name, 'remaining', v_remaining)
  FROM profiles p
  WHERE p.id IN (
    SELECT cm.user_id FROM cast_members cm
    JOIN mm_game_cast gc ON gc.cast_member_id = cm.id
    WHERE gc.game_id = p_game_id AND cm.user_id IS NOT NULL
  );

  -- For weekly mode: chain to next week
  IF v_mode = 'weekly' AND v_chain_next THEN
    PERFORM chain_next_week(p_game_id);
  END IF;

  -- Check for game end
  IF v_remaining <= 2 THEN
    UPDATE mm_games SET status = 'finale', current_phase = 'finale' WHERE id = p_game_id;

    -- Schedule game end event
    INSERT INTO game_events (game_id, event_type, scheduled_for, priority, payload)
    VALUES (p_game_id, 'game_end', NOW() + INTERVAL '5 minutes', 10,
            jsonb_build_object('reason', 'final_two', 'mode', v_mode));
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'eliminated_name', v_eliminated_name,
    'remaining', v_remaining,
    'mode', v_mode,
    'chained_next_week', v_chain_next
  );
END;
$$;

-- ============================================================================
-- 4. join_game() RPC — Clean player onboarding
-- Creates cast_member + mm_game_cast entry in one call
-- ============================================================================
CREATE OR REPLACE FUNCTION public.join_game(
  p_game_id UUID,
  p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_game RECORD;
  v_profile RECORD;
  v_cast_member_id UUID;
  v_existing RECORD;
  v_cast_count INTEGER;
  v_archetypes TEXT[] := ARRAY['wildcard', 'strategist', 'sweetheart', 'villain', 'comedian', 'troublemaker', 'diva', 'hothead'];
  v_random_archetype TEXT;
BEGIN
  -- Validate game exists and is joinable
  SELECT * INTO v_game FROM mm_games WHERE id = p_game_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Game not found');
  END IF;

  IF v_game.status NOT IN ('recruiting', 'waiting_lobby', 'active_lobby') THEN
    RETURN jsonb_build_object('error', 'Game is not accepting players', 'status', v_game.status);
  END IF;

  -- Check capacity
  SELECT count(*) INTO v_cast_count
  FROM mm_game_cast WHERE game_id = p_game_id AND status = 'active';

  IF v_cast_count >= v_game.max_players THEN
    RETURN jsonb_build_object('error', 'Game is full', 'current', v_cast_count, 'max', v_game.max_players);
  END IF;

  -- Get user profile
  SELECT * INTO v_profile FROM profiles WHERE id = p_user_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'User profile not found');
  END IF;

  -- Check if user already has a cast member
  SELECT cm.id INTO v_existing
  FROM cast_members cm
  JOIN mm_game_cast gc ON gc.cast_member_id = cm.id
  WHERE cm.user_id = p_user_id AND gc.game_id = p_game_id;

  IF v_existing IS NOT NULL THEN
    RETURN jsonb_build_object('success', true, 'cast_member_id', v_existing.id, 'already_joined', true);
  END IF;

  -- Pick random archetype
  v_random_archetype := v_archetypes[1 + floor(random() * array_length(v_archetypes, 1))::INTEGER];

  -- Create cast member for this user
  INSERT INTO cast_members (
    user_id, full_name, display_name, avatar_url, archetype,
    personality_traits, bio, status, is_ai_player
  ) VALUES (
    p_user_id,
    COALESCE(v_profile.display_name, 'Player'),
    COALESCE(v_profile.display_name, 'Player'),
    v_profile.avatar_url,
    v_random_archetype,
    ARRAY[v_random_archetype],
    'A new contestant enters the Mansion...',
    'active',
    false
  )
  RETURNING id INTO v_cast_member_id;

  -- Add to game cast
  INSERT INTO mm_game_cast (game_id, cast_member_id, status)
  VALUES (p_game_id, v_cast_member_id, 'active');

  -- Update player count
  UPDATE mm_games
  SET current_players = current_players + 1
  WHERE id = p_game_id;

  RETURN jsonb_build_object(
    'success', true,
    'cast_member_id', v_cast_member_id,
    'game_id', p_game_id,
    'archetype', v_random_archetype,
    'player_number', v_cast_count + 1
  );
END;
$$;

-- ============================================================================
-- VERIFICATION
-- ============================================================================
SELECT proname FROM pg_proc
WHERE proname IN ('handle_event_lobby_check', 'handle_event_voting_close', 'handle_event_elimination', 'join_game')
ORDER BY proname;
