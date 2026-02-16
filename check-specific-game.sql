-- Check if you're in game: 8f31b3f0-1b4f-4607-bc23-ce3a7799b269

-- 1. Check the game details
SELECT 
  id,
  game_name,
  status,
  host_user_id,
  created_at
FROM mm_games
WHERE id = '8f31b3f0-1b4f-4607-bc23-ce3a7799b269';

-- 2. Check ALL cast members in this game
SELECT 
  gc.cast_member_id,
  cm.display_name,
  cm.full_name,
  cm.user_id,
  gc.status,
  gc.joined_at
FROM mm_game_cast gc
JOIN cast_members cm ON gc.cast_member_id = cm.id
WHERE gc.game_id = '8f31b3f0-1b4f-4607-bc23-ce3a7799b269'
ORDER BY gc.joined_at DESC;

-- 3. Check YOUR cast members (replace YOUR_USER_ID with actual user_id from auth)
-- To find your user_id, run: SELECT auth.uid();
SELECT 
  cm.id as cast_member_id,
  cm.display_name,
  cm.full_name,
  cm.user_id,
  gc.game_id,
  g.game_name,
  gc.status as game_cast_status
FROM cast_members cm
LEFT JOIN mm_game_cast gc ON cm.id = gc.cast_member_id
LEFT JOIN mm_games g ON gc.game_id = g.id
WHERE cm.user_id = (SELECT auth.uid())
ORDER BY gc.joined_at DESC;
