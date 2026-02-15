-- ============================================================================
-- Migration 015: Tea Room Posts & Double Elimination Voting
-- ============================================================================
-- Creates public tea room for drama posts
-- Updates voting system for double elimination (Queen's choice + House vote)
-- ============================================================================

-- ============================================================================
-- PART 1: Tea Room Posts Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.mm_tea_room_posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id UUID NOT NULL REFERENCES public.mm_games(id) ON DELETE CASCADE,
  cast_member_id UUID NOT NULL REFERENCES public.cast_members(id) ON DELETE CASCADE,

  -- Content
  post_text TEXT,
  voice_note_url TEXT,
  voice_note_duration_seconds INTEGER,
  post_type TEXT NOT NULL DEFAULT 'drama' CHECK (post_type IN ('drama', 'strategy', 'shade', 'confession', 'reaction')),

  -- Engagement
  likes_count INTEGER DEFAULT 0,
  comments_count INTEGER DEFAULT 0,

  -- Moderation
  is_flagged BOOLEAN DEFAULT false,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tea_room_game ON public.mm_tea_room_posts(game_id);
CREATE INDEX IF NOT EXISTS idx_tea_room_cast_member ON public.mm_tea_room_posts(cast_member_id);
CREATE INDEX IF NOT EXISTS idx_tea_room_created ON public.mm_tea_room_posts(created_at DESC);

COMMENT ON TABLE public.mm_tea_room_posts IS 'Public drama feed where cast members post tea, shade, and confessionals';

-- ============================================================================
-- PART 2: RLS Policies for Tea Room
-- ============================================================================

ALTER TABLE public.mm_tea_room_posts ENABLE ROW LEVEL SECURITY;

-- Public read access (everyone can see the drama)
DROP POLICY IF EXISTS "public_read_tea_room" ON public.mm_tea_room_posts;
CREATE POLICY "public_read_tea_room" ON public.mm_tea_room_posts
  FOR SELECT USING (true);

-- Authenticated users can post if they own the cast member
DROP POLICY IF EXISTS "authenticated_insert_tea_room" ON public.mm_tea_room_posts;
CREATE POLICY "authenticated_insert_tea_room" ON public.mm_tea_room_posts
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.cast_members cm
      WHERE cm.id = mm_tea_room_posts.cast_member_id
        AND cm.user_id = auth.uid()
    )
  );

-- Users can update their own posts (for likes/flags)
DROP POLICY IF EXISTS "authenticated_update_tea_room" ON public.mm_tea_room_posts;
CREATE POLICY "authenticated_update_tea_room" ON public.mm_tea_room_posts
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.cast_members cm
      WHERE cm.id = mm_tea_room_posts.cast_member_id
        AND cm.user_id = auth.uid()
    )
  );

GRANT SELECT, INSERT, UPDATE ON public.mm_tea_room_posts TO authenticated;
GRANT SELECT ON public.mm_tea_room_posts TO anon;

-- ============================================================================
-- PART 3: Update Voting Rounds for Double Elimination
-- ============================================================================

-- Add queen_direct_elimination_id column for direct elimination power
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'mm_voting_rounds'
      AND column_name = 'queen_direct_elimination_id'
  ) THEN
    ALTER TABLE public.mm_voting_rounds
      ADD COLUMN queen_direct_elimination_id UUID REFERENCES public.cast_members(id) ON DELETE SET NULL;

    COMMENT ON COLUMN public.mm_voting_rounds.queen_direct_elimination_id IS
      'Cast member directly eliminated by the Queen (1st elimination of the week)';
  END IF;
END $$;

-- Ensure house_vote_eliminated_id exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'mm_voting_rounds'
      AND column_name = 'house_vote_eliminated_id'
  ) THEN
    ALTER TABLE public.mm_voting_rounds
      ADD COLUMN house_vote_eliminated_id UUID REFERENCES public.cast_members(id) ON DELETE SET NULL;

    COMMENT ON COLUMN public.mm_voting_rounds.house_vote_eliminated_id IS
      'Cast member eliminated by house vote (2nd elimination of the week)';
  END IF;
END $$;

-- Rename old eliminated_id if it exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'mm_voting_rounds'
      AND column_name = 'eliminated_id'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'mm_voting_rounds'
      AND column_name = 'eliminated_id_old'
  ) THEN
    ALTER TABLE public.mm_voting_rounds
      RENAME COLUMN eliminated_id TO eliminated_id_old;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_voting_rounds_queen_elim ON public.mm_voting_rounds(queen_direct_elimination_id);
CREATE INDEX IF NOT EXISTS idx_voting_rounds_house_elim ON public.mm_voting_rounds(house_vote_eliminated_id);

-- ============================================================================
-- PART 4: Storage Bucket for Voice Notes
-- ============================================================================

-- Create voice-notes bucket if it doesn't exist
DO $$
BEGIN
  INSERT INTO storage.buckets (id, name, public)
  VALUES ('voice-notes', 'voice-notes', true);
EXCEPTION
  WHEN unique_violation THEN
    NULL; -- Bucket already exists
END $$;

-- Allow public read access to voice notes
DROP POLICY IF EXISTS "public_read_voice_notes" ON storage.objects;
CREATE POLICY "public_read_voice_notes" ON storage.objects
  FOR SELECT USING (bucket_id = 'voice-notes');

-- Allow authenticated users to upload voice notes
DROP POLICY IF EXISTS "authenticated_upload_voice_notes" ON storage.objects;
CREATE POLICY "authenticated_upload_voice_notes" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'voice-notes');

-- ============================================================================
-- PART 5: Update Comments
-- ============================================================================

COMMENT ON TABLE public.mm_voting_rounds IS
  'Weekly voting rounds with DOUBLE ELIMINATION: Queen directly eliminates 1, then nominates 2 for house vote';
