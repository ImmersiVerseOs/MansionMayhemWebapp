-- ============================================================================
-- 041: FIX get_character_dashboard() RPC
-- Fixes column name mismatches and references to non-existent columns
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

    -- Recent alliances (use array_length instead of member_count)
    'recent_alliances', (
      SELECT COALESCE(json_agg(
        json_build_object(
          'room_id', ar.id,
          'room_name', ar.room_name,
          'members', COALESCE(array_length(ar.member_ids, 1), 0),
          'created_at', ar.created_at
        )
      ), '[]'::json)
      FROM mm_alliance_rooms ar
      JOIN cast_members cm ON cm.id = ANY(ar.member_ids)
      WHERE cm.user_id = p_user_id
      ORDER BY ar.created_at DESC
      LIMIT 5
    )
  )
  INTO v_result
  FROM profiles p
  WHERE p.id = p_user_id;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_character_dashboard(UUID) TO authenticated;
