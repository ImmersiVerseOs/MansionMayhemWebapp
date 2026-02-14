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
