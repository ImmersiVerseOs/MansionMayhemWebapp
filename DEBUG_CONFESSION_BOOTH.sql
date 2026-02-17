-- Debug Confession Booth Issues
-- Run these queries in Supabase SQL editor

-- 1. Check if cast member exists for your user
-- Replace YOUR_USER_ID with the actual UUID from the error log
SELECT
  id,
  full_name,
  display_name,
  user_id,
  status,
  confession_booth_avatar_url,
  confession_avatar_source
FROM cast_members
WHERE user_id = '3748bd6f-b6ec-4124-a5bb-ecb5915423eb';

-- 2. Check all RLS policies on cast_members
SELECT
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'cast_members'
ORDER BY policyname;

-- 3. Check if RLS is enabled on cast_members
SELECT
  schemaname,
  tablename,
  rowsecurity
FROM pg_tables
WHERE tablename = 'cast_members';

-- 4. Get all cast members (to see if table has data)
SELECT
  id,
  full_name,
  display_name,
  user_id,
  status
FROM cast_members
LIMIT 10;

-- 5. Check if there's a mm_game_cast junction table
SELECT EXISTS (
  SELECT FROM information_schema.tables
  WHERE table_name = 'mm_game_cast'
) AS mm_game_cast_exists;

-- 6. If mm_game_cast exists, check its structure
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'mm_game_cast'
ORDER BY ordinal_position;
