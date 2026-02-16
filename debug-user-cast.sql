-- Debug: Check if your cast member exists in the game

-- 1. First, find your user_id (replace with actual user_id if known)
-- Check what cast members you have
SELECT 
  cm.id,
  cm.display_name,
  cm.full_name,
  cm.user_id,
  cm.created_at
FROM cast_members cm
WHERE cm.user_id = 'YOUR_USER_ID_HERE'  -- Replace with your actual user_id
ORDER BY cm.created_at DESC;

-- 2. Check which games your cast members are in
SELECT 
  gc.game_id,
  g.game_name,
  gc.cast_member_id,
  cm.display_name,
  gc.status,
  cm.user_id
FROM mm_game_cast gc
JOIN cast_members cm ON gc.cast_member_id = cm.id
JOIN mm_games g ON gc.game_id = g.id
WHERE cm.user_id = 'YOUR_USER_ID_HERE'  -- Replace with your actual user_id
ORDER BY gc.joined_at DESC;

-- 3. Check if the specific game exists and has cast
SELECT 
  g.id,
  g.game_name,
  g.status,
  COUNT(gc.cast_member_id) as total_cast_members
FROM mm_games g
LEFT JOIN mm_game_cast gc ON g.id = gc.game_id
WHERE g.id = 'YOUR_GAME_ID_HERE'  -- Replace with the game_id from the URL
GROUP BY g.id, g.game_name, g.status;
