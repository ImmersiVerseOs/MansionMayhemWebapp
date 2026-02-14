-- ============================================================================
-- CREATE mm_voice_introductions TABLE
-- Stores voice introduction recordings from cast members
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.mm_voice_introductions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cast_member_id UUID NOT NULL REFERENCES public.cast_members(id) ON DELETE CASCADE,
  storage_path TEXT NOT NULL,
  duration_seconds INTEGER NOT NULL,
  file_size_bytes INTEGER NOT NULL,
  mime_type TEXT NOT NULL DEFAULT 'audio/webm',
  moderation_status TEXT NOT NULL DEFAULT 'pending' CHECK (moderation_status IN ('pending', 'approved', 'rejected')),
  moderator_notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- One introduction per cast member (can be replaced)
  UNIQUE(cast_member_id)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_mm_voice_introductions_cast_member_id
  ON public.mm_voice_introductions(cast_member_id);
CREATE INDEX IF NOT EXISTS idx_mm_voice_introductions_moderation_status
  ON public.mm_voice_introductions(moderation_status);
CREATE INDEX IF NOT EXISTS idx_mm_voice_introductions_created_at
  ON public.mm_voice_introductions(created_at DESC);

-- Enable RLS
ALTER TABLE public.mm_voice_introductions ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- RLS POLICIES
-- ============================================================================

-- Service role bypass
DROP POLICY IF EXISTS "service_role_all" ON public.mm_voice_introductions;
CREATE POLICY "service_role_all" ON public.mm_voice_introductions
  FOR ALL TO service_role
  USING (true)
  WITH CHECK (true);

-- Public can read approved introductions
DROP POLICY IF EXISTS "public_read_approved" ON public.mm_voice_introductions;
CREATE POLICY "public_read_approved" ON public.mm_voice_introductions
  FOR SELECT TO public
  USING (moderation_status = 'approved');

-- Authenticated users can read all (for their own game context)
DROP POLICY IF EXISTS "authenticated_read_all" ON public.mm_voice_introductions;
CREATE POLICY "authenticated_read_all" ON public.mm_voice_introductions
  FOR SELECT TO authenticated
  USING (true);

-- Users can insert their own introductions
DROP POLICY IF EXISTS "users_can_insert_own_intro" ON public.mm_voice_introductions;
CREATE POLICY "users_can_insert_own_intro" ON public.mm_voice_introductions
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM cast_members cm
      WHERE cm.id = mm_voice_introductions.cast_member_id
        AND cm.user_id = auth.uid()
    )
  );

-- Users can update their own introductions (for re-recording)
DROP POLICY IF EXISTS "users_can_update_own_intro" ON public.mm_voice_introductions;
CREATE POLICY "users_can_update_own_intro" ON public.mm_voice_introductions
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM cast_members cm
      WHERE cm.id = mm_voice_introductions.cast_member_id
        AND cm.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM cast_members cm
      WHERE cm.id = mm_voice_introductions.cast_member_id
        AND cm.user_id = auth.uid()
    )
  );

-- Users can delete their own introductions
DROP POLICY IF EXISTS "users_can_delete_own_intro" ON public.mm_voice_introductions;
CREATE POLICY "users_can_delete_own_intro" ON public.mm_voice_introductions
  FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM cast_members cm
      WHERE cm.id = mm_voice_introductions.cast_member_id
        AND cm.user_id = auth.uid()
    )
  );

-- Admins can manage all introductions
DROP POLICY IF EXISTS "admin_all" ON public.mm_voice_introductions;
CREATE POLICY "admin_all" ON public.mm_voice_introductions
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role IN ('admin', 'super_admin')
    )
  );

-- Grant permissions
GRANT SELECT ON public.mm_voice_introductions TO public;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.mm_voice_introductions TO authenticated;

-- ============================================================================
-- TRIGGER FOR updated_at
-- ============================================================================

CREATE OR REPLACE FUNCTION public.update_mm_voice_introductions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_mm_voice_introductions_updated_at ON public.mm_voice_introductions;
CREATE TRIGGER update_mm_voice_introductions_updated_at
  BEFORE UPDATE ON public.mm_voice_introductions
  FOR EACH ROW
  EXECUTE FUNCTION public.update_mm_voice_introductions_updated_at();

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Check table created
SELECT
  table_name,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_name = 'mm_voice_introductions'
ORDER BY ordinal_position;

-- Check RLS policies
SELECT
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd
FROM pg_policies
WHERE tablename = 'mm_voice_introductions'
ORDER BY policyname;

-- Check permissions
SELECT
  grantee,
  privilege_type
FROM information_schema.role_table_grants
WHERE table_name = 'mm_voice_introductions'
ORDER BY grantee, privilege_type;
