-- Fix RLS policies for cast_members table (correct schema)
-- Drop existing policies
DROP POLICY IF EXISTS "Users can view cast members in their games" ON cast_members;
DROP POLICY IF EXISTS "Users can view their own cast member" ON cast_members;
DROP POLICY IF EXISTS "Users can update their own cast member" ON cast_members;
DROP POLICY IF EXISTS "Allow authenticated users to read cast members" ON cast_members;
DROP POLICY IF EXISTS "Allow authenticated users to update their cast member" ON cast_members;

-- Enable RLS
ALTER TABLE cast_members ENABLE ROW LEVEL SECURITY;

-- Policy: Allow authenticated users to view their own cast member
CREATE POLICY "Users can view their own cast member"
ON cast_members
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- Policy: Allow authenticated users to view all cast members (for game features)
CREATE POLICY "Allow authenticated users to read cast members"
ON cast_members
FOR SELECT
TO authenticated
USING (true);

-- Policy: Users can update their own cast member record
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
