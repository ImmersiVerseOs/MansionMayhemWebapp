-- ============================================================================
-- Fix mm_game_cast RLS Policy - Allow Authenticated Users to Join Games
-- Critical fix for "403 Forbidden" error when joining games
-- ============================================================================

-- Allow authenticated users to insert into mm_game_cast when joining games
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
    -- Game must be open for joining (recruiting or waiting_lobby)
    AND EXISTS (
      SELECT 1 FROM mm_games g
      WHERE g.id = mm_game_cast.game_id
        AND g.status IN ('recruiting', 'waiting_lobby', 'lobby', 'setup')
    )
  );

-- Allow users to update their own game_cast records (for status changes)
DROP POLICY IF EXISTS "users_can_update_own_game_cast" ON public.mm_game_cast;
CREATE POLICY "users_can_update_own_game_cast" ON public.mm_game_cast
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM cast_members cm
      WHERE cm.id = mm_game_cast.cast_member_id
        AND cm.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM cast_members cm
      WHERE cm.id = mm_game_cast.cast_member_id
        AND cm.user_id = auth.uid()
    )
  );

-- Grant necessary permissions
GRANT INSERT, UPDATE ON public.mm_game_cast TO authenticated;

COMMENT ON POLICY "authenticated_users_can_join_games" ON public.mm_game_cast IS
  'Allows authenticated users to join games by inserting their own cast_member_id.
   Users can only join games in recruiting/lobby phases.
   Prevents users from adding other people to games.';

COMMENT ON POLICY "users_can_update_own_game_cast" ON public.mm_game_cast IS
  'Allows users to update their own game_cast records (status changes, etc.).
   Users can only update records where they are the cast_member.';
-- ============================================================================
-- Fix Missing Admin Write Policies for 4 Tables
-- Ensures admins can manage scenario_targets, quotas, and queen selections
-- ============================================================================

-- scenario_targets: Admin write access
DROP POLICY IF EXISTS "admin_write" ON public.scenario_targets;
CREATE POLICY "admin_write" ON public.scenario_targets
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role IN ('admin', 'super_admin')
    )
  );

-- mm_scenario_quotas: Admin write access
DROP POLICY IF EXISTS "admin_write" ON public.mm_scenario_quotas;
CREATE POLICY "admin_write" ON public.mm_scenario_quotas
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role IN ('admin', 'super_admin')
    )
  );

-- mm_alliance_quotas: Admin write access
DROP POLICY IF EXISTS "admin_write" ON public.mm_alliance_quotas;
CREATE POLICY "admin_write" ON public.mm_alliance_quotas
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role IN ('admin', 'super_admin')
    )
  );

-- mm_queen_selections: Admin write access
DROP POLICY IF EXISTS "admin_write" ON public.mm_queen_selections;
CREATE POLICY "admin_write" ON public.mm_queen_selections
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role IN ('admin', 'super_admin')
    )
  );

-- Grant permissions
GRANT INSERT, UPDATE, DELETE ON public.scenario_targets TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.mm_scenario_quotas TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.mm_alliance_quotas TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.mm_queen_selections TO authenticated;

-- Comments
COMMENT ON POLICY "admin_write" ON public.scenario_targets IS
  'Allows admins to manage scenario target assignments';

COMMENT ON POLICY "admin_write" ON public.mm_scenario_quotas IS
  'Allows admins to manage scenario quotas for cast members';

COMMENT ON POLICY "admin_write" ON public.mm_alliance_quotas IS
  'Allows admins to manage alliance participation quotas';

COMMENT ON POLICY "admin_write" ON public.mm_queen_selections IS
  'Allows admins to manage queen selections and nominations';
