-- ============================================================================
-- 050: Fix mm_game_cast RLS to allow joining active games
-- ============================================================================
-- Party/Blitz/Sprint modes create games as 'active' immediately.
-- The old policy only allowed joining 'recruiting'/'waiting_lobby' games.
-- This adds 'active' to the allowed statuses.
-- ============================================================================

DROP POLICY IF EXISTS "authenticated_users_can_join_games" ON public.mm_game_cast;
CREATE POLICY "authenticated_users_can_join_games" ON public.mm_game_cast
  FOR INSERT TO authenticated
  WITH CHECK (
    -- User must have a cast_member profile
    EXISTS (
      SELECT 1 FROM cast_members cm
      WHERE cm.id = mm_game_cast.cast_member_id
        AND cm.user_id = auth.uid()
    )
    -- Game must be open for joining
    AND EXISTS (
      SELECT 1 FROM mm_games g
      WHERE g.id = mm_game_cast.game_id
        AND g.status IN ('recruiting', 'waiting_lobby', 'lobby', 'setup', 'active')
    )
  );

-- Also allow users to DELETE their own game_cast records (for leaving games)
DROP POLICY IF EXISTS "users_can_leave_games" ON public.mm_game_cast;
CREATE POLICY "users_can_leave_games" ON public.mm_game_cast
  FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM cast_members cm
      WHERE cm.id = mm_game_cast.cast_member_id
        AND cm.user_id = auth.uid()
    )
  );

GRANT DELETE ON public.mm_game_cast TO authenticated;
