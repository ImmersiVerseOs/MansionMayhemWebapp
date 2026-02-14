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
