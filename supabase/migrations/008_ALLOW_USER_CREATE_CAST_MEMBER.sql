-- ============================================================================
-- Allow authenticated users to create their own cast_member profile
-- Fix for "Cast member profile not found" error
-- ============================================================================

-- Allow authenticated users to INSERT their own cast_member profile
DROP POLICY IF EXISTS "users_can_create_own_profile" ON public.cast_members;
CREATE POLICY "users_can_create_own_profile" ON public.cast_members
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Allow authenticated users to UPDATE their own cast_member profile
DROP POLICY IF EXISTS "users_can_update_own_profile" ON public.cast_members;
CREATE POLICY "users_can_update_own_profile" ON public.cast_members
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Grant INSERT and UPDATE permissions
GRANT INSERT, UPDATE ON public.cast_members TO authenticated;
