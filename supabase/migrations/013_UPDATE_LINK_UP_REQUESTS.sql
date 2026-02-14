-- ============================================================================
-- UPDATE mm_link_up_requests TABLE
-- Add invited_cast_ids array for multi-person invitations
-- ============================================================================

-- Add invited_cast_ids column (array of UUIDs)
ALTER TABLE public.mm_link_up_requests
ADD COLUMN IF NOT EXISTS invited_cast_ids UUID[] NOT NULL DEFAULT '{}';

-- Add accept_count column (tracks how many have accepted)
ALTER TABLE public.mm_link_up_requests
ADD COLUMN IF NOT EXISTS accept_count INTEGER NOT NULL DEFAULT 0;

-- Create index on invited_cast_ids for faster lookups
CREATE INDEX IF NOT EXISTS idx_mm_link_up_requests_invited_cast_ids
  ON public.mm_link_up_requests USING GIN (invited_cast_ids);

-- Update existing data: populate invited_cast_ids from to_cast_member_id
UPDATE public.mm_link_up_requests
SET invited_cast_ids = ARRAY[to_cast_member_id]
WHERE invited_cast_ids = '{}' AND to_cast_member_id IS NOT NULL;

-- ============================================================================
-- UPDATE RLS POLICIES for invited_cast_ids
-- ============================================================================

-- Users can see requests where they are invited (checking array)
DROP POLICY IF EXISTS "users_read_their_requests" ON public.mm_link_up_requests;
CREATE POLICY "users_read_their_requests" ON public.mm_link_up_requests
  FOR SELECT TO authenticated
  USING (
    -- User is the sender
    EXISTS (
      SELECT 1 FROM cast_members cm
      WHERE cm.id = mm_link_up_requests.from_cast_member_id
        AND cm.user_id = auth.uid()
    )
    -- OR user is in the invited list
    OR EXISTS (
      SELECT 1 FROM cast_members cm
      WHERE cm.user_id = auth.uid()
        AND cm.id = ANY(mm_link_up_requests.invited_cast_ids)
    )
    -- OR user is the single recipient (backwards compatibility)
    OR EXISTS (
      SELECT 1 FROM cast_members cm
      WHERE cm.id = mm_link_up_requests.to_cast_member_id
        AND cm.user_id = auth.uid()
    )
  );

-- Users can create link-up requests
DROP POLICY IF EXISTS "users_create_requests" ON public.mm_link_up_requests;
CREATE POLICY "users_create_requests" ON public.mm_link_up_requests
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM cast_members cm
      WHERE cm.id = mm_link_up_requests.from_cast_member_id
        AND cm.user_id = auth.uid()
    )
  );

-- Users can update requests they sent or received
DROP POLICY IF EXISTS "users_update_requests" ON public.mm_link_up_requests;
CREATE POLICY "users_update_requests" ON public.mm_link_up_requests
  FOR UPDATE TO authenticated
  USING (
    -- User is the sender
    EXISTS (
      SELECT 1 FROM cast_members cm
      WHERE cm.id = mm_link_up_requests.from_cast_member_id
        AND cm.user_id = auth.uid()
    )
    -- OR user is in the invited list
    OR EXISTS (
      SELECT 1 FROM cast_members cm
      WHERE cm.user_id = auth.uid()
        AND cm.id = ANY(mm_link_up_requests.invited_cast_ids)
    )
    -- OR user is the single recipient
    OR EXISTS (
      SELECT 1 FROM cast_members cm
      WHERE cm.id = mm_link_up_requests.to_cast_member_id
        AND cm.user_id = auth.uid()
    )
  );

-- Grant permissions
GRANT SELECT, INSERT, UPDATE ON public.mm_link_up_requests TO authenticated;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Check column added
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'mm_link_up_requests'
  AND column_name IN ('invited_cast_ids', 'accept_count')
ORDER BY column_name;

-- Check policies
SELECT policyname, cmd
FROM pg_policies
WHERE tablename = 'mm_link_up_requests'
ORDER BY policyname;

-- Check indexes
SELECT indexname
FROM pg_indexes
WHERE tablename = 'mm_link_up_requests'
  AND indexname LIKE '%invited%';
