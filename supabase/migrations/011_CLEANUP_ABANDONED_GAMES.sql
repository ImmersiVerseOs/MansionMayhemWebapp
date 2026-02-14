-- ============================================================================
-- CLEANUP ABANDONED GAMES
-- Automatically delete games that were created but abandoned
-- ============================================================================

-- Function to clean up abandoned games
CREATE OR REPLACE FUNCTION public.cleanup_abandoned_games()
RETURNS JSONB AS $$
DECLARE
  v_deleted_count INTEGER := 0;
  v_game RECORD;
  v_result JSONB := '[]'::JSONB;
BEGIN
  -- Find games that should be deleted:
  -- 1. Status is 'recruiting' or 'waiting_lobby'
  -- 2. Have 0 players in mm_game_cast
  -- 3. Created more than 30 minutes ago (to avoid deleting brand new games)
  -- 4. Haven't started yet (waiting_lobby_ends_at is in the future)

  FOR v_game IN
    SELECT g.id, g.title, g.status, g.created_at
    FROM mm_games g
    WHERE g.status IN ('recruiting', 'waiting_lobby', 'lobby')
      AND g.created_at < NOW() - INTERVAL '30 minutes'
      AND (
        -- No players in game
        NOT EXISTS (
          SELECT 1 FROM mm_game_cast gc
          WHERE gc.game_id = g.id
        )
        -- OR game hasn't been updated in 2 hours
        OR g.updated_at < NOW() - INTERVAL '2 hours'
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

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.cleanup_abandoned_games() TO authenticated;
GRANT EXECUTE ON FUNCTION public.cleanup_abandoned_games() TO service_role;

-- ============================================================================
-- SCHEDULE CRON JOB
-- Run cleanup every 15 minutes
-- ============================================================================

-- Note: This requires pg_cron extension
-- The cron job will run: cleanup_abandoned_games()

SELECT cron.schedule(
  'cleanup_abandoned_games',
  '*/15 * * * *', -- Every 15 minutes
  $$SELECT public.cleanup_abandoned_games()$$
);

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Test the function manually (safe - only deletes abandoned games)
-- SELECT public.cleanup_abandoned_games();

-- Check cron job
SELECT
  jobid,
  jobname,
  schedule,
  active,
  'Every 15 minutes' as description
FROM cron.job
WHERE jobname = 'cleanup_abandoned_games';

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON FUNCTION public.cleanup_abandoned_games() IS
'Cleans up abandoned games that have no players or havent been updated in 2 hours.
Runs every 15 minutes via cron job. Only deletes games in recruiting/waiting_lobby status
that are older than 30 minutes and not within 1 hour of starting.';
