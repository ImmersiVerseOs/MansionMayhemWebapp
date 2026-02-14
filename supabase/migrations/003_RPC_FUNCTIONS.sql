-- ============================================================================
-- MANSION MAYHEM - RPC FUNCTIONS
-- ============================================================================
-- PostgreSQL functions called by the frontend
-- ============================================================================

-- ============================================================================
-- 1. GET CHARACTER DASHBOARD
-- ============================================================================
-- Returns user stats including games played, alliances, votes cast, etc.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_character_dashboard(p_user_id UUID)
RETURNS JSON AS $$
DECLARE
  v_result JSON;
BEGIN
  SELECT json_build_object(
    'user_id', p.id,
    'display_name', p.display_name,
    'avatar_url', p.avatar_url,
    'role', p.role,
    'total_games', p.total_games_played,
    'games_won', p.games_won,
    'alliances_formed', p.alliances_formed,
    'scenarios_completed', p.scenarios_completed,
    'votes_cast', p.votes_cast,
    'created_at', p.created_at,

    -- Active game info
    'active_game', (
      SELECT json_build_object(
        'game_id', g.id,
        'season', g.season,
        'status', g.status,
        'current_stage', gs.stage_name,
        'stage_number', gs.stage_number
      )
      FROM mm_games g
      LEFT JOIN mm_game_stages gs ON gs.game_id = g.id AND gs.is_current = true
      WHERE g.status = 'active'
      LIMIT 1
    ),

    -- Recent alliances
    'recent_alliances', (
      SELECT json_agg(
        json_build_object(
          'room_id', ar.id,
          'room_name', ar.room_name,
          'members', ar.member_count,
          'created_at', ar.created_at
        )
      )
      FROM mm_alliance_rooms ar
      WHERE ar.created_by_user_id = p_user_id
        OR ar.id IN (
          SELECT room_id
          FROM mm_link_up_responses lr
          WHERE lr.invitee_id = p_user_id
            AND lr.response_status = 'accepted'
        )
      ORDER BY ar.created_at DESC
      LIMIT 5
    ),

    -- Pending scenarios
    'pending_scenarios', (
      SELECT COUNT(*)::integer
      FROM scenarios s
      WHERE s.status = 'active'
        AND s.deadline_at > NOW()
        AND NOT EXISTS (
          SELECT 1
          FROM scenario_responses sr
          WHERE sr.scenario_id = s.id
            AND sr.user_id = p_user_id
        )
    )
  ) INTO v_result
  FROM profiles p
  WHERE p.id = p_user_id;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 2. GET ACTIVE SCENARIOS
-- ============================================================================
-- Returns all active scenarios that the user hasn't responded to yet
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_active_scenarios(p_user_id UUID)
RETURNS JSON AS $$
DECLARE
  v_result JSON;
BEGIN
  SELECT json_agg(
    json_build_object(
      'id', s.id,
      'title', s.title,
      'description', s.description,
      'prompt', s.prompt,
      'scenario_type', s.scenario_type,
      'requires_voice', s.requires_voice,
      'deadline_at', s.deadline_at,
      'created_at', s.created_at,
      'context_notes', s.context_notes,
      'game_id', s.game_id,

      -- Check if user has already responded
      'has_responded', EXISTS (
        SELECT 1
        FROM scenario_responses sr
        WHERE sr.scenario_id = s.id
          AND sr.user_id = p_user_id
      ),

      -- Time remaining
      'hours_remaining', EXTRACT(EPOCH FROM (s.deadline_at - NOW())) / 3600,

      -- Total responses count
      'response_count', (
        SELECT COUNT(*)::integer
        FROM scenario_responses sr
        WHERE sr.scenario_id = s.id
      )
    )
    ORDER BY s.deadline_at ASC
  ) INTO v_result
  FROM scenarios s
  WHERE s.status = 'active'
    AND s.deadline_at > NOW();

  -- Return empty array if no scenarios
  RETURN COALESCE(v_result, '[]'::json);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 3. SUBMIT SCENARIO RESPONSE
-- ============================================================================
-- Creates a scenario response and returns the response ID
-- ============================================================================
CREATE OR REPLACE FUNCTION public.submit_scenario_response(
  p_scenario_id UUID,
  p_user_id UUID,
  p_response_text TEXT,
  p_is_ai_generated BOOLEAN DEFAULT false
)
RETURNS UUID AS $$
DECLARE
  v_response_id UUID;
BEGIN
  -- Insert response
  INSERT INTO scenario_responses (
    scenario_id,
    user_id,
    response_text,
    is_ai_generated,
    submitted_at
  ) VALUES (
    p_scenario_id,
    p_user_id,
    p_response_text,
    p_is_ai_generated,
    NOW()
  )
  RETURNING id INTO v_response_id;

  -- Update profile stats
  UPDATE profiles
  SET scenarios_completed = scenarios_completed + 1
  WHERE id = p_user_id;

  RETURN v_response_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 4. CREATE VOICE NOTE
-- ============================================================================
-- Creates a voice note submission (requires moderation before visible)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.create_voice_note(
  p_user_id UUID,
  p_note_type TEXT,
  p_audio_url TEXT,
  p_duration INTEGER,
  p_caption TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_note_id UUID;
BEGIN
  INSERT INTO voice_notes (
    user_id,
    note_type,
    audio_url,
    duration_seconds,
    caption,
    status
  ) VALUES (
    p_user_id,
    p_note_type,
    p_audio_url,
    p_duration,
    p_caption,
    'pending'  -- Requires moderation
  )
  RETURNING id INTO v_note_id;

  RETURN v_note_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 5. REACT TO VOICE NOTE
-- ============================================================================
-- Adds a reaction to a voice note (fire, drama, laugh, shocked)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.react_to_voice_note(
  p_voice_note_id UUID,
  p_user_id UUID,
  p_reaction_type TEXT
)
RETURNS BOOLEAN AS $$
BEGIN
  -- Upsert reaction (user can only have one reaction per voice note)
  INSERT INTO voice_note_reactions (
    voice_note_id,
    user_id,
    reaction_type
  ) VALUES (
    p_voice_note_id,
    p_user_id,
    p_reaction_type
  )
  ON CONFLICT (voice_note_id, user_id)
  DO UPDATE SET
    reaction_type = EXCLUDED.reaction_type,
    created_at = NOW();

  RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 6. SEARCH VOICE NOTES
-- ============================================================================
-- Full-text search across voice notes (approved only)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.search_voice_notes(
  p_query TEXT,
  p_limit INTEGER DEFAULT 20
)
RETURNS JSON AS $$
DECLARE
  v_result JSON;
BEGIN
  SELECT json_agg(
    json_build_object(
      'id', vn.id,
      'user_id', vn.user_id,
      'note_type', vn.note_type,
      'audio_url', vn.audio_url,
      'duration_seconds', vn.duration_seconds,
      'caption', vn.caption,
      'created_at', vn.created_at,

      -- User info
      'user', json_build_object(
        'display_name', p.display_name,
        'avatar_url', p.avatar_url
      ),

      -- Reaction counts
      'reactions', (
        SELECT json_object_agg(reaction_type, count)
        FROM (
          SELECT reaction_type, COUNT(*)::integer as count
          FROM voice_note_reactions
          WHERE voice_note_id = vn.id
          GROUP BY reaction_type
        ) reaction_counts
      )
    )
  ) INTO v_result
  FROM voice_notes vn
  JOIN profiles p ON p.id = vn.user_id
  WHERE vn.status = 'approved'
    AND (
      vn.caption ILIKE '%' || p_query || '%'
      OR p.display_name ILIKE '%' || p_query || '%'
    )
  ORDER BY vn.created_at DESC
  LIMIT p_limit;

  RETURN COALESCE(v_result, '[]'::json);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 7. FLAG CONTENT FOR MODERATION
-- ============================================================================
-- Creates a content report for admin review
-- ============================================================================
CREATE OR REPLACE FUNCTION public.flag_content(
  p_reporter_id UUID,
  p_content_type TEXT,
  p_content_id UUID,
  p_reason TEXT,
  p_description TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_report_id UUID;
BEGIN
  INSERT INTO content_reports (
    reporter_id,
    content_type,
    content_id,
    reason,
    description,
    status
  ) VALUES (
    p_reporter_id,
    p_content_type,
    p_content_id,
    p_reason,
    p_description,
    'pending'
  )
  RETURNING id INTO v_report_id;

  RETURN v_report_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 8. CALCULATE CHARACTER EARNINGS
-- ============================================================================
-- Calculates total earnings for a character in a date range
-- ============================================================================
CREATE OR REPLACE FUNCTION public.calculate_character_earnings(
  p_user_id UUID,
  p_start_date DATE,
  p_end_date DATE
)
RETURNS JSON AS $$
DECLARE
  v_result JSON;
BEGIN
  SELECT json_build_object(
    'user_id', p_user_id,
    'start_date', p_start_date,
    'end_date', p_end_date,
    'total_earnings', COALESCE(SUM(e.amount), 0),
    'earnings_by_type', (
      SELECT json_object_agg(earning_type, total)
      FROM (
        SELECT earning_type, SUM(amount) as total
        FROM earnings
        WHERE user_id = p_user_id
          AND created_at::date BETWEEN p_start_date AND p_end_date
        GROUP BY earning_type
      ) by_type
    ),
    'payment_count', COUNT(*)::integer
  ) INTO v_result
  FROM earnings e
  WHERE e.user_id = p_user_id
    AND e.created_at::date BETWEEN p_start_date AND p_end_date;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 9. GET ADMIN ANALYTICS
-- ============================================================================
-- Returns platform-wide analytics for admin dashboard
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_admin_analytics(p_days INTEGER DEFAULT 30)
RETURNS JSON AS $$
DECLARE
  v_result JSON;
  v_start_date TIMESTAMPTZ;
BEGIN
  v_start_date := NOW() - (p_days || ' days')::interval;

  SELECT json_build_object(
    'period_days', p_days,
    'start_date', v_start_date,
    'end_date', NOW(),

    -- User stats
    'total_users', (SELECT COUNT(*)::integer FROM profiles),
    'new_users', (SELECT COUNT(*)::integer FROM profiles WHERE created_at >= v_start_date),
    'active_users', (SELECT COUNT(DISTINCT user_id)::integer FROM scenario_responses WHERE submitted_at >= v_start_date),

    -- Game stats
    'total_games', (SELECT COUNT(*)::integer FROM mm_games),
    'active_games', (SELECT COUNT(*)::integer FROM mm_games WHERE status = 'active'),

    -- Content stats
    'total_scenarios', (SELECT COUNT(*)::integer FROM scenarios),
    'total_responses', (SELECT COUNT(*)::integer FROM scenario_responses WHERE submitted_at >= v_start_date),
    'total_voice_notes', (SELECT COUNT(*)::integer FROM voice_notes WHERE created_at >= v_start_date),
    'pending_voice_notes', (SELECT COUNT(*)::integer FROM voice_notes WHERE status = 'pending'),

    -- Alliance stats
    'total_alliances', (SELECT COUNT(*)::integer FROM mm_alliance_rooms WHERE created_at >= v_start_date),
    'total_link_up_requests', (SELECT COUNT(*)::integer FROM mm_link_up_requests WHERE created_at >= v_start_date),

    -- Moderation stats
    'pending_reports', (SELECT COUNT(*)::integer FROM content_reports WHERE status = 'pending')
  ) INTO v_result;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 10. COMPLETE CHARACTER SETUP
-- ============================================================================
-- One-transaction character onboarding (creates cast member + updates profile)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.complete_character_setup(
  p_user_id UUID,
  p_character_data JSON,
  p_facecast_data JSON DEFAULT NULL,
  p_personality_data JSON DEFAULT NULL,
  p_consent_data JSON DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_cast_member_id UUID;
BEGIN
  -- Create cast member
  INSERT INTO cast_members (
    full_name,
    display_name,
    avatar_url,
    archetype,
    personality_traits,
    backstory,
    bio,
    screen_time_score,
    is_ai_player,
    facecast_id
  ) VALUES (
    p_character_data->>'full_name',
    p_character_data->>'display_name',
    p_character_data->>'avatar_url',
    p_character_data->>'archetype',
    ARRAY(SELECT json_array_elements_text(p_character_data->'personality_traits')),
    p_character_data->>'backstory',
    p_character_data->>'bio',
    COALESCE(p_character_data->>'screen_time_score', 'medium'),
    false,  -- Not AI player
    (p_facecast_data->>'id')::uuid
  )
  RETURNING id INTO v_cast_member_id;

  -- Update profile with cast member link
  UPDATE profiles
  SET
    display_name = p_character_data->>'display_name',
    avatar_url = p_character_data->>'avatar_url'
  WHERE id = p_user_id;

  -- Add to active game if one exists
  INSERT INTO mm_game_cast (game_id, cast_member_id, is_ai_player)
  SELECT g.id, v_cast_member_id, false
  FROM mm_games g
  WHERE g.status = 'active'
  LIMIT 1
  ON CONFLICT DO NOTHING;

  RETURN v_cast_member_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 11. INITIALIZE GAME LOBBIES (Two-Stage Lobby System)
-- ============================================================================
-- Initialize game with 3hr waiting lobby + 48hr active lobby
-- ============================================================================
CREATE OR REPLACE FUNCTION public.initialize_game_lobbies(p_game_id UUID)
RETURNS VOID AS $$
DECLARE
  v_waiting_ends TIMESTAMPTZ;
  v_active_ends TIMESTAMPTZ;
BEGIN
  v_waiting_ends := NOW() + INTERVAL '3 hours';
  v_active_ends := v_waiting_ends + INTERVAL '48 hours';

  UPDATE mm_games SET
    status = 'waiting_lobby',
    waiting_lobby_starts_at = NOW(),
    waiting_lobby_ends_at = v_waiting_ends,
    active_lobby_starts_at = v_waiting_ends,
    active_lobby_ends_at = v_active_ends,
    updated_at = NOW()
  WHERE id = p_game_id;

  -- Create waiting lobby stage
  INSERT INTO mm_game_stages (game_id, stage_name, stage_number, stage_type, status, started_at, stage_ends_at, auto_advance, min_players)
  VALUES (p_game_id, 'Waiting Room', 1, 'waiting_lobby', 'active', NOW(), v_waiting_ends, TRUE, 2);

  -- Pre-create active lobby stage
  INSERT INTO mm_game_stages (game_id, stage_name, stage_number, stage_type, status, started_at, stage_ends_at, auto_advance)
  VALUES (p_game_id, 'Alliance Lobby', 2, 'active_lobby', 'pending', v_waiting_ends, v_active_ends, TRUE);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 11A. AUTO-FILL AI CAST
-- ============================================================================
-- Automatically fills empty cast slots with AI characters
-- Ensures every game has full 20-person cast
-- ============================================================================
CREATE OR REPLACE FUNCTION public.auto_fill_ai_cast(
  p_game_id UUID,
  p_target_count INTEGER DEFAULT 20
)
RETURNS INTEGER AS $$
DECLARE
  v_current_count INTEGER;
  v_needed_count INTEGER;
  v_ai_added INTEGER := 0;
  v_ai_character RECORD;
BEGIN
  -- Count current players in game
  SELECT COUNT(*) INTO v_current_count
  FROM mm_game_cast
  WHERE game_id = p_game_id;

  -- Calculate how many AI needed
  v_needed_count := p_target_count - v_current_count;

  -- If game is already full or over capacity, do nothing
  IF v_needed_count <= 0 THEN
    RAISE NOTICE 'Game already has % players (target: %). No AI needed.', v_current_count, p_target_count;
    RETURN 0;
  END IF;

  RAISE NOTICE 'Game has % players. Adding % AI characters to reach %...', v_current_count, v_needed_count, p_target_count;

  -- Add random AI characters until we reach target count
  FOR v_ai_character IN
    SELECT cm.id
    FROM cast_members cm
    WHERE cm.is_ai_player = true
      AND cm.status = 'active'
      -- Exclude AI already in this game
      AND cm.id NOT IN (
        SELECT cast_member_id
        FROM mm_game_cast
        WHERE game_id = p_game_id
      )
    ORDER BY RANDOM()
    LIMIT v_needed_count
  LOOP
    -- Add AI character to game cast
    INSERT INTO mm_game_cast (game_id, cast_member_id, status, joined_at)
    VALUES (p_game_id, v_ai_character.id, 'active', NOW())
    ON CONFLICT (game_id, cast_member_id) DO NOTHING;

    v_ai_added := v_ai_added + 1;
  END LOOP;

  -- Update game's current_players count
  UPDATE mm_games
  SET current_players = current_players + v_ai_added,
      updated_at = NOW()
  WHERE id = p_game_id;

  RAISE NOTICE 'Successfully added % AI characters to game', v_ai_added;
  RETURN v_ai_added;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 12. ADVANCE TO ACTIVE LOBBY
-- ============================================================================
-- Transition from 3hr waiting room to 48hr alliance lobby
-- Auto-fills AI characters to reach 20-person cast
-- ============================================================================
CREATE OR REPLACE FUNCTION public.advance_to_active_lobby(p_game_id UUID)
RETURNS VOID AS $$
DECLARE
  v_ai_added INTEGER;
BEGIN
  -- Complete waiting lobby
  UPDATE mm_game_stages SET status = 'completed', completed_at = NOW()
  WHERE game_id = p_game_id AND stage_type = 'waiting_lobby';

  -- AUTO-FILL: Add AI characters to reach 20-person cast
  SELECT auto_fill_ai_cast(p_game_id, 20) INTO v_ai_added;
  RAISE NOTICE 'Auto-filled % AI characters', v_ai_added;

  -- Activate alliance lobby
  UPDATE mm_game_stages SET status = 'active'
  WHERE game_id = p_game_id AND stage_type = 'active_lobby';

  UPDATE mm_games SET status = 'active_lobby', updated_at = NOW()
  WHERE id = p_game_id;

  -- Notify ALL players (real + AI)
  INSERT INTO notifications (user_id, notification_type, title, message, link_url)
  SELECT p.id, 'game_phase_change', 'Alliance Lobby Now Open!',
    'The 48-hour alliance phase has begun. Form alliances and record your introduction!',
    '/lobby.html?game=' || p_game_id
  FROM mm_game_cast gc
  JOIN cast_members cm ON cm.id = gc.cast_member_id
  JOIN profiles p ON p.id = cm.user_id
  WHERE gc.game_id = p_game_id
    AND cm.user_id IS NOT NULL; -- Only notify real players, not AI
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 13. START ACTIVE GAME PHASE
-- ============================================================================
-- Transition from alliance lobby to active gameplay
-- ============================================================================
CREATE OR REPLACE FUNCTION public.start_game_active_phase(p_game_id UUID)
RETURNS VOID AS $$
BEGIN
  -- Complete active lobby
  UPDATE mm_game_stages SET status = 'completed', completed_at = NOW()
  WHERE game_id = p_game_id AND stage_type = 'active_lobby';

  UPDATE mm_games SET
    status = 'active',
    game_starts_at = NOW(),
    started_at = NOW(),
    updated_at = NOW()
  WHERE id = p_game_id;

  -- Create gameplay stage
  INSERT INTO mm_game_stages (game_id, stage_name, stage_number, stage_type, status, started_at)
  VALUES (p_game_id, 'Week 1 - Gameplay', 3, 'gameplay', 'active', NOW());

  -- Initialize scenario quotas for all cast members
  INSERT INTO mm_scenario_quotas (game_id, cast_member_id, week_number, max_scenarios_total, max_scenarios_per_day)
  SELECT p_game_id, cast_member_id, 1, 5, 3
  FROM mm_game_cast
  WHERE game_id = p_game_id;

  -- Notify players
  INSERT INTO notifications (user_id, notification_type, title, message, link_url)
  SELECT p.id, 'game_started', 'The Game Has Begun!',
    'Mansion Mayhem is now live. Check your scenarios!',
    '/pages/player-dashboard.html?game=' || p_game_id
  FROM mm_game_cast gc
  JOIN cast_members cm ON cm.id = gc.cast_member_id
  JOIN profiles p ON p.id = cm.user_id
  WHERE gc.game_id = p_game_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 14. CHECK AND ADVANCE LOBBIES (Cron Job)
-- ============================================================================
-- Check and advance lobbies when timers expire
-- ============================================================================
CREATE OR REPLACE FUNCTION public.check_and_advance_lobbies()
RETURNS VOID AS $$
DECLARE
  v_game RECORD;
BEGIN
  -- Advance waiting lobbies to active lobbies
  FOR v_game IN
    SELECT id FROM mm_games
    WHERE status = 'waiting_lobby' AND waiting_lobby_ends_at <= NOW()
  LOOP
    PERFORM advance_to_active_lobby(v_game.id);
  END LOOP;

  -- Advance active lobbies to game start
  FOR v_game IN
    SELECT id FROM mm_games
    WHERE status = 'active_lobby' AND active_lobby_ends_at <= NOW()
  LOOP
    PERFORM start_game_active_phase(v_game.id);
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 15. DISTRIBUTE DAILY SCENARIOS
-- ============================================================================
-- Distribute 2-3 scenarios per day with 3-5 max total per cast member
-- ============================================================================
CREATE OR REPLACE FUNCTION public.distribute_daily_scenarios()
RETURNS JSON AS $$
DECLARE
  v_game RECORD;
  v_cast_member RECORD;
  v_scenario RECORD;
  v_daily_limit INTEGER := 3;
  v_total_limit INTEGER := 5;
  v_result JSONB := '[]'::JSONB;
BEGIN
  FOR v_game IN SELECT id FROM mm_games WHERE status = 'active' LOOP

    -- Get undistributed scenarios
    FOR v_scenario IN
      SELECT s.* FROM scenarios s
      WHERE s.game_id = v_game.id
        AND s.status = 'queued'
        AND s.distribution_date IS NULL
      ORDER BY s.created_at ASC
      LIMIT 10
    LOOP

      -- Find eligible cast members (under quota)
      FOR v_cast_member IN
        SELECT
          gc.cast_member_id,
          cm.archetype,
          COALESCE(sq.total_assigned, 0) as total_assigned
        FROM mm_game_cast gc
        JOIN cast_members cm ON cm.id = gc.cast_member_id
        LEFT JOIN mm_scenario_quotas sq ON sq.cast_member_id = gc.cast_member_id AND sq.game_id = v_game.id
        WHERE gc.game_id = v_game.id
          AND gc.status = 'active'
          AND COALESCE(sq.total_assigned, 0) < v_total_limit
          AND (v_scenario.target_archetype IS NULL OR v_scenario.target_archetype = cm.archetype)
        ORDER BY COALESCE(sq.total_assigned, 0) ASC, RANDOM()
        LIMIT v_daily_limit
      LOOP

        -- Assign scenario to cast member
        INSERT INTO scenario_targets (scenario_id, cast_member_id)
        VALUES (v_scenario.id, v_cast_member.cast_member_id)
        ON CONFLICT DO NOTHING;

        -- Update quota
        INSERT INTO mm_scenario_quotas (game_id, cast_member_id, week_number, total_assigned, week_assigned, max_scenarios_total, max_scenarios_per_day)
        VALUES (v_game.id, v_cast_member.cast_member_id, 1, 1, 1, v_total_limit, v_daily_limit)
        ON CONFLICT (game_id, cast_member_id, week_number)
        DO UPDATE SET
          total_assigned = mm_scenario_quotas.total_assigned + 1,
          week_assigned = mm_scenario_quotas.week_assigned + 1,
          updated_at = NOW();

        v_result := v_result || jsonb_build_object(
          'scenario_id', v_scenario.id,
          'cast_member_id', v_cast_member.cast_member_id
        );
      END LOOP;

      -- Mark scenario as distributed with 24hr deadline
      UPDATE scenarios SET
        status = 'active',
        distribution_date = CURRENT_DATE,
        deadline_at = NOW() + INTERVAL '24 hours',
        assigned_count = (SELECT COUNT(*) FROM scenario_targets WHERE scenario_id = v_scenario.id)
      WHERE id = v_scenario.id;

    END LOOP;
  END LOOP;

  RETURN json_build_object('success', true, 'distributions', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 16. TRIGGER QUEEN SELECTION (Weekly)
-- ============================================================================
-- Weekly queen selection (runs on Sundays at 8 PM UTC)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.trigger_queen_selection()
RETURNS JSON AS $$
DECLARE
  v_game RECORD;
  v_week_number INTEGER;
  v_selected_queen UUID;
  v_result JSONB := '[]'::JSONB;
BEGIN
  FOR v_game IN SELECT id, started_at FROM mm_games WHERE status = 'active' LOOP

    v_week_number := FLOOR(EXTRACT(EPOCH FROM (NOW() - v_game.started_at)) / (7 * 24 * 3600)) + 1;

    -- Skip if already selected for this week
    IF EXISTS (SELECT 1 FROM mm_queen_selections WHERE game_id = v_game.id AND week_number = v_week_number) THEN
      CONTINUE;
    END IF;

    -- Random lottery selection
    SELECT cast_member_id INTO v_selected_queen
    FROM mm_game_cast
    WHERE game_id = v_game.id AND status = 'active' AND eliminated_at IS NULL
    ORDER BY RANDOM()
    LIMIT 1;

    IF v_selected_queen IS NULL THEN CONTINUE; END IF;

    -- Insert selection record
    INSERT INTO mm_queen_selections (game_id, week_number, round_number, selected_queen_id, selection_method, selected_at, nomination_deadline)
    VALUES (v_game.id, v_week_number, v_week_number, v_selected_queen, 'random_lottery', NOW(), NOW() + INTERVAL '48 hours');

    -- Notify players
    INSERT INTO notifications (user_id, notification_type, title, message, link_url)
    SELECT p.id, 'queen_selected', 'Week ' || v_week_number || ' Queen Announced!',
      'Check who has the power this week!', '/queen-selection.html?game=' || v_game.id
    FROM mm_game_cast gc
    JOIN cast_members cm ON cm.id = gc.cast_member_id
    JOIN profiles p ON p.id = cm.user_id
    WHERE gc.game_id = v_game.id;

    v_result := v_result || jsonb_build_object('game_id', v_game.id, 'week', v_week_number, 'queen_id', v_selected_queen);
  END LOOP;

  RETURN json_build_object('selections', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- Grant execute permissions to authenticated users
-- ============================================================================
GRANT EXECUTE ON FUNCTION public.get_character_dashboard(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_active_scenarios(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_scenario_response(UUID, UUID, TEXT, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_voice_note(UUID, TEXT, TEXT, INTEGER, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.react_to_voice_note(UUID, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.search_voice_notes(TEXT, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.flag_content(UUID, TEXT, UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.calculate_character_earnings(UUID, DATE, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_admin_analytics(INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.complete_character_setup(UUID, JSON, JSON, JSON, JSON) TO authenticated;
GRANT EXECUTE ON FUNCTION public.initialize_game_lobbies(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.auto_fill_ai_cast(UUID, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.advance_to_active_lobby(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.start_game_active_phase(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_and_advance_lobbies() TO authenticated;
GRANT EXECUTE ON FUNCTION public.distribute_daily_scenarios() TO authenticated;
GRANT EXECUTE ON FUNCTION public.trigger_queen_selection() TO authenticated;
