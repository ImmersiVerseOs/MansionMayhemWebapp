-- =====================================================
-- AI DIRECTOR CONTEXT FUNCTION
-- Returns comprehensive game state for Claude analysis
-- =====================================================

CREATE OR REPLACE FUNCTION get_director_context(p_game_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_game RECORD;
  v_result JSONB;
BEGIN
  -- Get game info
  SELECT * INTO v_game FROM mm_games WHERE id = p_game_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Game not found: %', p_game_id;
  END IF;

  SELECT jsonb_build_object(
    -- Basic game info
    'game', jsonb_build_object(
      'id', v_game.id,
      'status', v_game.status,
      'started_at', v_game.started_at,
      'current_week', v_game.current_week,
      'days_running', EXTRACT(DAY FROM NOW() - v_game.started_at)
    ),

    -- Cast members with personality and stats
    'cast_members', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'id', cm.id,
        'display_name', cm.display_name,
        'full_name', cm.full_name,
        'archetype', cm.archetype,
        'status', cm.status,
        'is_ai_player', cm.is_ai_player,
        'drama_score', cm.drama_score,
        'influence_score', cm.influence_score,
        'screen_time_score', cm.screen_time_score,
        'personality_traits', cm.personality_traits,
        'backstory', cm.backstory
      ) ORDER BY cm.drama_score DESC), '[]'::jsonb)
      FROM cast_members cm
      JOIN mm_game_cast gc ON cm.id = gc.cast_member_id
      WHERE gc.game_id = p_game_id AND cm.status = 'active'
    ),

    -- Top conflicts/rivalries (drama potential)
    'conflicts', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'player_a_id', cma.id,
        'player_a_name', cma.display_name,
        'player_b_id', cmb.id,
        'player_b_name', cmb.display_name,
        'rivalry_level', re.rivalry_level,
        'trust_score', re.trust_score,
        'alliance_strength', re.alliance_strength,
        'last_updated', re.updated_at
      ) ORDER BY re.rivalry_level DESC), '[]'::jsonb)
      FROM mm_relationship_edges re
      JOIN cast_members cma ON re.cast_member_a_id = cma.id
      JOIN cast_members cmb ON re.cast_member_b_id = cmb.id
      WHERE re.game_id = p_game_id
        AND cma.status = 'active'
        AND cmb.status = 'active'
        AND re.rivalry_level > 30  -- Only significant rivalries
      LIMIT 10
    ),

    -- Active alliances
    'alliances', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'id', ar.id,
        'room_name', ar.room_name,
        'room_type', ar.room_type,
        'member_count', array_length(ar.member_ids, 1),
        'members', (
          SELECT jsonb_agg(jsonb_build_object(
            'id', cm.id,
            'name', cm.display_name
          ))
          FROM cast_members cm
          WHERE cm.id = ANY(ar.member_ids)
        ),
        'recent_messages', (
          SELECT COUNT(*)
          FROM mm_alliance_messages
          WHERE room_id = ar.id
            AND created_at > NOW() - INTERVAL '24 hours'
        ),
        'created_at', ar.created_at
      ) ORDER BY ar.created_at DESC), '[]'::jsonb)
      FROM mm_alliance_rooms ar
      WHERE ar.game_id = p_game_id AND ar.status = 'active'
    ),

    -- Recent Tea Spot drama (high engagement posts)
    'recent_drama', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'post_id', trp.id,
        'author_id', cm.id,
        'author_name', cm.display_name,
        'post_text', trp.post_text,
        'post_type', trp.post_type,
        'likes', trp.likes_count,
        'comments', trp.comments_count,
        'engagement_score', (trp.likes_count + trp.comments_count * 2),
        'created_at', trp.created_at,
        'top_comments', (
          SELECT COALESCE(jsonb_agg(comment_obj), '[]'::jsonb)
          FROM (
            SELECT jsonb_build_object(
              'commenter', cm2.display_name,
              'text', tsc.comment_text
            ) as comment_obj
            FROM mm_tea_spot_comments tsc
            JOIN cast_members cm2 ON tsc.cast_member_id = cm2.id
            WHERE tsc.post_id = trp.id
            ORDER BY tsc.created_at
            LIMIT 3
          ) comments
        )
      ) ORDER BY (trp.likes_count + trp.comments_count * 2) DESC), '[]'::jsonb)
      FROM mm_tea_room_posts trp
      JOIN cast_members cm ON trp.cast_member_id = cm.id
      WHERE trp.game_id = p_game_id
        AND trp.created_at > NOW() - INTERVAL '48 hours'
        AND cm.status = 'active'
      LIMIT 15
    ),

    -- Recent scenarios and their responses
    'recent_scenarios', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'id', s.id,
        'title', s.title,
        'description', s.description,
        'scenario_type', s.scenario_type,
        'status', s.status,
        'assigned_count', s.assigned_count,
        'responses_received', s.responses_received,
        'response_rate', CASE
          WHEN s.assigned_count > 0 THEN ROUND((s.responses_received::NUMERIC / s.assigned_count) * 100, 1)
          ELSE 0
        END,
        'context_notes', s.context_notes,
        'created_at', s.created_at,
        'targets', (
          SELECT jsonb_agg(cm.display_name)
          FROM scenario_targets st
          JOIN cast_members cm ON st.cast_member_id = cm.id
          WHERE st.scenario_id = s.id
        )
      ) ORDER BY s.created_at DESC), '[]'::jsonb)
      FROM scenarios s
      WHERE s.game_id = p_game_id
      LIMIT 10
    ),

    -- Voting/elimination history
    'eliminations', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'round', vr.round_number,
        'eliminated_player', cm.display_name,
        'votes_for_a', vr.votes_for_a,
        'votes_for_b', vr.votes_for_b,
        'elimination_date', vr.created_at
      ) ORDER BY vr.round_number DESC), '[]'::jsonb)
      FROM mm_voting_rounds vr
      LEFT JOIN cast_members cm ON vr.eliminated_id = cm.id
      WHERE vr.game_id = p_game_id
        AND vr.eliminated_id IS NOT NULL
      LIMIT 5
    ),

    -- Pacing metrics (scenarios per week, last scenario time)
    'pacing_metrics', jsonb_build_object(
      'scenarios_this_week', (
        SELECT COUNT(*)
        FROM scenarios
        WHERE game_id = p_game_id
          AND created_at > date_trunc('week', NOW())
      ),
      'scenarios_last_7_days', (
        SELECT COUNT(*)
        FROM scenarios
        WHERE game_id = p_game_id
          AND created_at > NOW() - INTERVAL '7 days'
      ),
      'hours_since_last_scenario', (
        SELECT EXTRACT(EPOCH FROM (NOW() - MAX(created_at))) / 3600
        FROM scenarios
        WHERE game_id = p_game_id
      ),
      'active_scenarios', (
        SELECT COUNT(*)
        FROM scenarios
        WHERE game_id = p_game_id AND status = 'active'
      ),
      'avg_response_rate', (
        SELECT ROUND(AVG(
          CASE WHEN assigned_count > 0
          THEN (responses_received::NUMERIC / assigned_count) * 100
          ELSE 0 END
        ), 1)
        FROM scenarios
        WHERE game_id = p_game_id
          AND created_at > NOW() - INTERVAL '7 days'
      )
    )

  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- Grant access
GRANT EXECUTE ON FUNCTION get_director_context(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_director_context(UUID) TO anon;
GRANT EXECUTE ON FUNCTION get_director_context(UUID) TO service_role;
