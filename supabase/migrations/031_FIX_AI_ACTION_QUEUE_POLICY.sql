-- ============================================================================
-- FIX ai_action_queue RLS POLICY
-- Allow authenticated users to insert AI actions
-- ============================================================================

-- Drop existing restrictive insert policy if it exists
DROP POLICY IF EXISTS "ai_action_queue_insert_policy" ON ai_action_queue;

-- Create permissive insert policy for authenticated users
CREATE POLICY "authenticated_users_can_insert"
ON ai_action_queue
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Also ensure SELECT policy exists for users to see their queued actions
DROP POLICY IF EXISTS "authenticated_users_can_select" ON ai_action_queue;

CREATE POLICY "authenticated_users_can_select"
ON ai_action_queue
FOR SELECT
TO authenticated
USING (true);

-- Success message
DO $$
BEGIN
  RAISE NOTICE '✅ ai_action_queue RLS policies fixed!';
  RAISE NOTICE '📍 Authenticated users can now INSERT';
  RAISE NOTICE '📍 Authenticated users can now SELECT';
  RAISE NOTICE '';
  RAISE NOTICE '🤝 Link-up requests should now work!';
END $$;
