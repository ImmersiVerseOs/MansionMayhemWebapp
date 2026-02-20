-- ============================================================================
-- 040: FIX ALLIANCE QUOTA RLS POLICY
-- Bug: Old policy only checked if ONE member was below quota, not ALL
-- ============================================================================

-- Fix alliance room creation to check ALL members are below quota
DROP POLICY IF EXISTS "Users can create alliance rooms" ON public.mm_alliance_rooms;
CREATE POLICY "Users can create alliance rooms" ON public.mm_alliance_rooms
  FOR INSERT TO authenticated
  WITH CHECK (
    -- Verify the creator (auth user) is in the member list
    EXISTS (
      SELECT 1 FROM cast_members cm
      WHERE cm.user_id = auth.uid()
        AND cm.id = ANY(mm_alliance_rooms.member_ids)
    )
    -- Verify NO members are over their alliance quota
    AND NOT EXISTS (
      SELECT 1 FROM cast_members cm
      LEFT JOIN mm_alliance_quotas aq ON aq.cast_member_id = cm.id
        AND aq.game_id = mm_alliance_rooms.game_id
      WHERE cm.id = ANY(mm_alliance_rooms.member_ids)
        AND COALESCE(aq.active_alliances, 0) >= COALESCE(aq.max_alliances, 5)
    )
    -- Verify room has max 5 members
    AND array_length(mm_alliance_rooms.member_ids, 1) <= 5
  );

-- Also add service role bypass
DROP POLICY IF EXISTS "service_role_all" ON public.mm_alliance_rooms;
CREATE POLICY "service_role_all" ON public.mm_alliance_rooms
  FOR ALL USING (auth.role() = 'service_role');
