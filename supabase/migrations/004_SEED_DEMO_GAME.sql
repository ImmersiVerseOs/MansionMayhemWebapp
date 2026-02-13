-- ============================================================================
-- SEED DEMO GAME - Initialize Active Game with AI Characters
-- ============================================================================

-- Create the first active game
INSERT INTO public.mm_games (
  id,
  title,
  description,
  status,
  max_players,
  current_players,
  started_at
) VALUES (
  gen_random_uuid(),
  'Mansion Mayhem Season 1',
  'The inaugural season of Mansion Mayhem featuring 20 AI characters competing for the crown.',
  'active',
  20,
  20,
  NOW()
) ON CONFLICT DO NOTHING;

-- Add all AI characters to the active game
DO $$
DECLARE
  active_game_id UUID;
  ai_character RECORD;
BEGIN
  -- Get the active game ID
  SELECT id INTO active_game_id
  FROM public.mm_games
  WHERE status = 'active'
  ORDER BY created_at DESC
  LIMIT 1;

  -- Add each AI character to the game
  FOR ai_character IN
    SELECT id FROM public.cast_members WHERE is_ai_player = true
  LOOP
    INSERT INTO public.mm_game_cast (
      game_id,
      cast_member_id,
      joined_at
    ) VALUES (
      active_game_id,
      ai_character.id,
      NOW()
    ) ON CONFLICT (game_id, cast_member_id) DO NOTHING;
  END LOOP;

  RAISE NOTICE '✅ Demo Game Seeded!';
  RAISE NOTICE 'Game ID: %', active_game_id;
  RAISE NOTICE 'AI Characters added to game: 20';
END $$;
