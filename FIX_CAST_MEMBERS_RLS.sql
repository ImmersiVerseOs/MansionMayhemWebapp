-- Fix RLS policies for cast_members table
-- Allow authenticated users to read cast members in their games

-- Drop existing policies if any
DROP POLICY IF EXISTS "Users can view cast members in their games" ON cast_members;
DROP POLICY IF EXISTS "Users can view their own cast member" ON cast_members;

-- Enable RLS
ALTER TABLE cast_members ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own cast member record
CREATE POLICY "Users can view their own cast member"
ON cast_members
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- Policy: Users can view all cast members in games they're part of
CREATE POLICY "Users can view cast members in their games"
ON cast_members
FOR SELECT
TO authenticated
USING (
  game_id IN (
    SELECT game_id
    FROM cast_members
    WHERE user_id = auth.uid()
  )
);

-- Policy: Users can update their own cast member record
DROP POLICY IF EXISTS "Users can update their own cast member" ON cast_members;
CREATE POLICY "Users can update their own cast member"
ON cast_members
FOR UPDATE
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Verify policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies
WHERE tablename = 'cast_members'
ORDER BY policyname;
