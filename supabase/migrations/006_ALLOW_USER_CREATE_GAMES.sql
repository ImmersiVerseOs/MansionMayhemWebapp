-- ============================================================================
-- Allow authenticated users to create games
-- Fix for RLS policy preventing game creation from player dashboard
-- ============================================================================

-- Allow authenticated users to INSERT games
DROP POLICY IF EXISTS "authenticated_create" ON public.mm_games;
CREATE POLICY "authenticated_create" ON public.mm_games
  FOR INSERT TO authenticated
  WITH CHECK (true);

-- Grant INSERT permission to authenticated users
GRANT INSERT ON public.mm_games TO authenticated;
