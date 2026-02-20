-- ============================================================================
-- 042: FIX RPC COLUMN NAMES
-- Fixes voted_for_cast_member_id → voted_for_id in update_vote_counts
-- Fixes GROUP BY issue in get_character_dashboard
-- ============================================================================

-- ─── Fix update_vote_counts ─────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.update_vote_counts(
  p_game_id UUID,
  p_vote_type TEXT DEFAULT 'elimination'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result JSONB;
BEGIN
  SELECT jsonb_agg(
    jsonb_build_object(
      'target_cast_member_id', ev.voted_for_id,
      'display_name', cm.display_name,
      'vote_count', ev.cnt,
      'percentage', ROUND((ev.cnt::NUMERIC / NULLIF(ev.total, 0)) * 100, 1)
    )
  )
  INTO result
  FROM (
    SELECT
      voted_for_id,
      COUNT(*) AS cnt,
      SUM(COUNT(*)) OVER () AS total
    FROM mm_elimination_votes
    WHERE round_id IN (
      SELECT id FROM mm_voting_rounds
      WHERE game_id = p_game_id
        AND status = 'active'
    )
    GROUP BY voted_for_id
  ) ev
  JOIN cast_members cm ON cm.id = ev.voted_for_id;

  RETURN COALESCE(result, '[]'::JSONB);
END;
$$;

-- ─── Fix get_character_dashboard ────────────────────────────────────────────
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
    'total_games', COALESCE(p.games_played, 0),
    'games_won', COALESCE(p.games_won, 0),
    'alliances_formed', COALESCE(p.alliances_formed, 0),
    'scenarios_completed', COALESCE(p.scenarios_completed, 0),
    'votes_cast', COALESCE(p.votes_cast, 0),
    'created_at', p.created_at,

    -- Active game info
    'active_game', (
      SELECT json_build_object(
        'game_id', g.id,
        'title', g.title,
        'status', g.status,
        'current_week', g.current_week
      )
      FROM mm_games g
      JOIN mm_game_cast gc ON gc.game_id = g.id
      JOIN cast_members cm ON cm.id = gc.cast_member_id
      WHERE cm.user_id = p_user_id
        AND g.status IN ('active', 'active_lobby')
        AND gc.status = 'active'
      LIMIT 1
    ),

    -- Recent alliances
    'recent_alliances', (
      SELECT COALESCE(json_agg(sub), '[]'::json)
      FROM (
        SELECT
          ar.id AS room_id,
          ar.room_name,
          COALESCE(array_length(ar.member_ids, 1), 0) AS members,
          ar.created_at
        FROM mm_alliance_rooms ar
        WHERE EXISTS (
          SELECT 1 FROM cast_members cm
          WHERE cm.id = ANY(ar.member_ids)
            AND cm.user_id = p_user_id
        )
        ORDER BY ar.created_at DESC
        LIMIT 5
      ) sub
    )
  )
  INTO v_result
  FROM profiles p
  WHERE p.id = p_user_id;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
