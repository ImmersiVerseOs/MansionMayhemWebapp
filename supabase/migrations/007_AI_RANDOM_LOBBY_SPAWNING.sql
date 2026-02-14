-- ============================================================================
-- AI Random Lobby Spawning System
-- Gradually adds AI characters to lobbies throughout the week
-- Prevents empty lobbies while waiting for Sunday launch
-- ============================================================================

-- Function to randomly spawn AI characters into open lobbies
CREATE OR REPLACE FUNCTION public.spawn_ai_into_lobbies()
RETURNS JSONB AS $$
DECLARE
  v_game RECORD;
  v_ai_character RECORD;
  v_spawned_count INTEGER := 0;
  v_max_spawn_per_run INTEGER := 2; -- Spawn 1-2 AI per run
  v_spawn_count INTEGER;
  v_result JSONB := '[]'::JSONB;
BEGIN

  -- Loop through all open lobbies (waiting for Sunday launch)
  FOR v_game IN
    SELECT id, title, max_players, current_players
    FROM mm_games
    WHERE status IN ('waiting_lobby', 'recruiting')
      AND (waiting_lobby_ends_at IS NULL OR waiting_lobby_ends_at > NOW())
  LOOP

    -- Get current player count
    SELECT COUNT(*) INTO v_game.current_players
    FROM mm_game_cast
    WHERE game_id = v_game.id;

    -- Don't spawn if lobby is full or nearly full (leave room for real players)
    IF v_game.current_players >= (v_game.max_players - 5) THEN
      CONTINUE;
    END IF;

    -- Randomly decide how many AI to spawn (0-2, weighted toward 1)
    v_spawn_count := FLOOR(RANDOM() * 3)::INTEGER; -- 0, 1, or 2

    -- 30% chance of spawning 0 (keeps it feeling organic, not forced)
    IF RANDOM() < 0.3 THEN
      v_spawn_count := 0;
    END IF;

    -- Cap at max_spawn_per_run
    v_spawn_count := LEAST(v_spawn_count, v_max_spawn_per_run);

    -- Spawn AI characters
    FOR i IN 1..v_spawn_count LOOP
      -- Select a random AI character that's NOT already in this game
      SELECT cm.id, cm.display_name, cm.archetype
      INTO v_ai_character
      FROM cast_members cm
      WHERE cm.is_ai_player = true
        AND cm.status = 'active'
        AND NOT EXISTS (
          SELECT 1 FROM mm_game_cast gc
          WHERE gc.game_id = v_game.id
            AND gc.cast_member_id = cm.id
        )
      ORDER BY RANDOM()
      LIMIT 1;

      -- If we found an AI character, add them to the game
      IF v_ai_character.id IS NOT NULL THEN
        INSERT INTO mm_game_cast (game_id, cast_member_id, status, joined_at)
        VALUES (v_game.id, v_ai_character.id, 'joined', NOW())
        ON CONFLICT DO NOTHING;

        v_spawned_count := v_spawned_count + 1;

        v_result := v_result || jsonb_build_object(
          'game_id', v_game.id,
          'game_title', v_game.title,
          'ai_name', v_ai_character.display_name,
          'ai_archetype', v_ai_character.archetype,
          'spawned_at', NOW()
        );

        -- Log the spawn
        RAISE NOTICE '🤖 AI Spawned: % (%) joined "%"',
          v_ai_character.display_name,
          v_ai_character.archetype,
          v_game.title;
      END IF;
    END LOOP;

  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'total_spawned', v_spawned_count,
    'spawns', v_result
  );

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.spawn_ai_into_lobbies() TO authenticated;

-- ============================================================================
-- Update cron jobs to include AI spawning
-- Runs every 4 hours to gradually populate lobbies
-- ============================================================================

-- AI spawning job: Runs every 4 hours
SELECT cron.schedule(
  'spawn_ai_into_lobbies',
  '0 */4 * * *', -- Every 4 hours (00:00, 04:00, 08:00, 12:00, 16:00, 20:00)
  $$ SELECT public.spawn_ai_into_lobbies(); $$
);

COMMENT ON FUNCTION public.spawn_ai_into_lobbies() IS
  'Randomly spawns 0-2 AI characters into open lobbies every 4 hours.
   Creates organic lobby population throughout the week before Sunday launch.
   Prevents spawning if lobby is nearly full (leaves room for real players).';

-- ============================================================================
-- Manual AI Spawn Function (for specific game)
-- Useful for testing or immediately populating a new lobby
-- ============================================================================

CREATE OR REPLACE FUNCTION public.spawn_ai_for_game(
  p_game_id UUID,
  p_count INTEGER DEFAULT 3
)
RETURNS JSONB AS $$
DECLARE
  v_ai_character RECORD;
  v_spawned INTEGER := 0;
  v_result JSONB := '[]'::JSONB;
BEGIN

  -- Spawn the requested number of AI characters
  FOR i IN 1..p_count LOOP
    -- Select a random AI character NOT already in this game
    SELECT cm.id, cm.display_name, cm.archetype
    INTO v_ai_character
    FROM cast_members cm
    WHERE cm.is_ai_player = true
      AND cm.status = 'active'
      AND NOT EXISTS (
        SELECT 1 FROM mm_game_cast gc
        WHERE gc.game_id = p_game_id
          AND gc.cast_member_id = cm.id
      )
    ORDER BY RANDOM()
    LIMIT 1;

    -- Add AI to game
    IF v_ai_character.id IS NOT NULL THEN
      INSERT INTO mm_game_cast (game_id, cast_member_id, status, joined_at)
      VALUES (p_game_id, v_ai_character.id, 'joined', NOW())
      ON CONFLICT DO NOTHING;

      v_spawned := v_spawned + 1;

      v_result := v_result || jsonb_build_object(
        'ai_name', v_ai_character.display_name,
        'ai_archetype', v_ai_character.archetype
      );

      RAISE NOTICE '🤖 AI Added: % (%)', v_ai_character.display_name, v_ai_character.archetype;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'game_id', p_game_id,
    'spawned_count', v_spawned,
    'ai_characters', v_result
  );

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.spawn_ai_for_game(UUID, INTEGER) TO authenticated;

COMMENT ON FUNCTION public.spawn_ai_for_game(UUID, INTEGER) IS
  'Manually spawn AI characters into a specific game.
   Usage: SELECT spawn_ai_for_game(''game-uuid-here'', 5);
   Useful for testing or immediately populating new lobbies.';
