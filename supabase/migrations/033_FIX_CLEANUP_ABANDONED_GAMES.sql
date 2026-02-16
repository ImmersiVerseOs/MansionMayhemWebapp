-- ============================================================================
-- FIX CLEANUP ABANDONED GAMES - Don't delete games with players!
-- ============================================================================

CREATE OR REPLACE FUNCTION public.cleanup_abandoned_games()
RETURNS JSONB AS $$
DECLARE
  v_deleted_count INTEGER := 0;
  v_game RECORD;
  v_result JSONB := '[]'::JSONB;
BEGIN
  -- Find games that should be deleted:
  -- 1. Status is 'recruiting' or 'waiting_lobby' or 'lobby'
  -- 2. Have 0 players in mm_game_cast
  -- 3. Created more than 30 minutes ago (to avoid deleting brand new games)
  -- 4. Haven't started yet (game_starts_at is in the future or NULL)

  -- IMPORTANT: Only delete if there are NO players!

  FOR v_game IN
    SELECT g.id, g.title, g.status, g.created_at
    FROM mm_games g
    WHERE g.status IN ('recruiting', 'waiting_lobby', 'lobby')
      AND g.created_at < NOW() - INTERVAL '30 minutes'
      -- ONLY delete if there are NO players
      AND NOT EXISTS (
        SELECT 1 FROM mm_game_cast gc
        WHERE gc.game_id = g.id
      )
      -- Don't delete if close to start time (within 1 hour of starting)
      AND (
        g.game_starts_at IS NULL
        OR g.game_starts_at > NOW() + INTERVAL '1 hour'
      )
  LOOP
    -- Delete the game
    DELETE FROM mm_games WHERE id = v_game.id;

    v_deleted_count := v_deleted_count + 1;

    -- Add to result
    v_result := v_result || jsonb_build_object(
      'game_id', v_game.id,
      'title', v_game.title,
      'status', v_game.status,
      'created_at', v_game.created_at
    );

    RAISE NOTICE 'Deleted abandoned game: % (%) created at %',
      v_game.title, v_game.id, v_game.created_at;
  END LOOP;

  RETURN jsonb_build_object(
    'deleted_count', v_deleted_count,
    'deleted_games', v_result,
    'cleaned_at', NOW()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Success message
DO $$
BEGIN
  RAISE NOTICE '✅ cleanup_abandoned_games() function fixed!';
  RAISE NOTICE '📍 Will ONLY delete games with 0 players';
  RAISE NOTICE '📍 Games with players are now safe from cleanup';
END $$;
