-- Check mm_alliance_rooms table structure and constraints

-- 1. Check all columns
SELECT 
  column_name, 
  data_type, 
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_name = 'mm_alliance_rooms'
ORDER BY ordinal_position;

-- 2. Check constraints
SELECT
  con.conname as constraint_name,
  con.contype as constraint_type,
  pg_get_constraintdef(con.oid) as definition
FROM pg_constraint con
JOIN pg_class rel ON rel.oid = con.conrelid
WHERE rel.relname = 'mm_alliance_rooms';

-- 3. Check RLS policies
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
WHERE tablename = 'mm_alliance_rooms';
