-- ============================================================================
-- Migration 034: Confession Booth Video System
-- ============================================================================
-- Adds HeyGen-powered video confession booth feature
-- Players set up avatar once, then create 20-second confession videos
-- Videos posted to dedicated confession booth gallery
-- ============================================================================

-- ============================================================================
-- PART 1: Extend cast_members Table for Confession Booth Avatars
-- ============================================================================

-- Add confession booth avatar fields to cast_members
DO $$
BEGIN
  -- Avatar URL (stored still image used for video generation)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'cast_members' AND column_name = 'confession_booth_avatar_url'
  ) THEN
    ALTER TABLE public.cast_members
      ADD COLUMN confession_booth_avatar_url TEXT;

    COMMENT ON COLUMN public.cast_members.confession_booth_avatar_url IS
      'Still image used for HeyGen video generation in confession booth';
  END IF;

  -- Avatar source tracking
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'cast_members' AND column_name = 'confession_avatar_source'
  ) THEN
    ALTER TABLE public.cast_members
      ADD COLUMN confession_avatar_source TEXT
        CHECK (confession_avatar_source IN (
          'flow_generated',
          'user_upload',
          'facecast_still',
          'cameo_character'
        ));

    COMMENT ON COLUMN public.cast_members.confession_avatar_source IS
      'How the confession booth avatar was created';
  END IF;

  -- Timestamp tracking
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'cast_members' AND column_name = 'confession_avatar_set_at'
  ) THEN
    ALTER TABLE public.cast_members
      ADD COLUMN confession_avatar_set_at TIMESTAMPTZ;

    COMMENT ON COLUMN public.cast_members.confession_avatar_set_at IS
      'When the confession booth avatar was last updated';
  END IF;
END $$;

-- Indexes for confession booth avatar queries
CREATE INDEX IF NOT EXISTS idx_cast_members_confession_avatar
  ON public.cast_members(confession_booth_avatar_url)
  WHERE confession_booth_avatar_url IS NOT NULL;

-- ============================================================================
-- PART 2: Confession Booth Videos Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.mm_confession_booth_videos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id UUID NOT NULL REFERENCES public.mm_games(id) ON DELETE CASCADE,
  cast_member_id UUID NOT NULL REFERENCES public.cast_members(id) ON DELETE CASCADE,

  -- Content (dialogue text limited to ~50 words for 20 seconds)
  dialogue_text TEXT NOT NULL,
  dialogue_word_count INTEGER DEFAULT 0,

  -- Media URLs
  audio_url TEXT NOT NULL, -- ElevenLabs generated audio
  audio_duration_seconds INTEGER,
  video_url TEXT, -- HeyGen generated video
  avatar_still_url TEXT NOT NULL, -- Avatar used for generation
  thumbnail_url TEXT, -- Video thumbnail

  -- HeyGen API metadata
  heygen_video_id TEXT UNIQUE,
  heygen_status TEXT DEFAULT 'pending' CHECK (heygen_status IN (
    'pending',
    'processing',
    'completed',
    'failed'
  )),
  heygen_error_message TEXT,
  heygen_callback_received_at TIMESTAMPTZ,

  -- Display options
  is_anonymous BOOLEAN DEFAULT false,
  display_name_override TEXT,
  booth_background_url TEXT, -- Preset confession booth background

  -- Engagement metrics
  views_count INTEGER DEFAULT 0,
  likes_count INTEGER DEFAULT 0,
  comments_count INTEGER DEFAULT 0,
  shares_count INTEGER DEFAULT 0,

  -- Moderation
  is_approved BOOLEAN DEFAULT false,
  moderation_status TEXT DEFAULT 'pending' CHECK (moderation_status IN (
    'pending',
    'approved',
    'rejected',
    'flagged'
  )),
  moderation_notes TEXT,
  moderated_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  moderated_at TIMESTAMPTZ,

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  published_at TIMESTAMPTZ,

  -- Constraints
  CONSTRAINT reasonable_dialogue_length CHECK (
    char_length(dialogue_text) >= 10 AND char_length(dialogue_text) <= 500
  )
);

-- Indexes for confession booth videos
CREATE INDEX IF NOT EXISTS idx_confession_videos_game
  ON public.mm_confession_booth_videos(game_id);

CREATE INDEX IF NOT EXISTS idx_confession_videos_cast_member
  ON public.mm_confession_booth_videos(cast_member_id);

CREATE INDEX IF NOT EXISTS idx_confession_videos_created
  ON public.mm_confession_booth_videos(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_confession_videos_status
  ON public.mm_confession_booth_videos(heygen_status);

CREATE INDEX IF NOT EXISTS idx_confession_videos_moderation
  ON public.mm_confession_booth_videos(moderation_status, is_approved);

CREATE INDEX IF NOT EXISTS idx_confession_videos_published
  ON public.mm_confession_booth_videos(published_at DESC)
  WHERE published_at IS NOT NULL AND is_approved = true;

-- Comments
COMMENT ON TABLE public.mm_confession_booth_videos IS
  'HeyGen-generated confession booth videos with 20-second dialogue limit';

-- ============================================================================
-- PART 3: Confession Booth Comments Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.mm_confession_booth_comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  video_id UUID NOT NULL REFERENCES public.mm_confession_booth_videos(id) ON DELETE CASCADE,
  cast_member_id UUID NOT NULL REFERENCES public.cast_members(id) ON DELETE CASCADE,
  parent_id UUID REFERENCES public.mm_confession_booth_comments(id) ON DELETE CASCADE,

  -- Content
  comment_text TEXT,
  voice_note_url TEXT,
  voice_note_duration_seconds INTEGER,

  -- Engagement
  like_count INTEGER DEFAULT 0,

  -- Moderation
  is_flagged BOOLEAN DEFAULT false,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- At least one content type required
  CONSTRAINT has_content CHECK (
    comment_text IS NOT NULL OR voice_note_url IS NOT NULL
  )
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_confession_comments_video
  ON public.mm_confession_booth_comments(video_id);

CREATE INDEX IF NOT EXISTS idx_confession_comments_parent
  ON public.mm_confession_booth_comments(parent_id);

CREATE INDEX IF NOT EXISTS idx_confession_comments_cast_member
  ON public.mm_confession_booth_comments(cast_member_id);

CREATE INDEX IF NOT EXISTS idx_confession_comments_created
  ON public.mm_confession_booth_comments(created_at DESC);

COMMENT ON TABLE public.mm_confession_booth_comments IS
  'Comments on confession booth videos with threading support';

-- ============================================================================
-- PART 4: Confession Booth Reactions Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.mm_confession_booth_reactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  video_id UUID REFERENCES public.mm_confession_booth_videos(id) ON DELETE CASCADE,
  comment_id UUID REFERENCES public.mm_confession_booth_comments(id) ON DELETE CASCADE,
  cast_member_id UUID NOT NULL REFERENCES public.cast_members(id) ON DELETE CASCADE,
  reaction_type TEXT NOT NULL CHECK (reaction_type IN (
    'like',
    'love',
    'fire',
    'laugh',
    'shocked',
    'sad',
    'angry',
    'tea'
  )),

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- One reaction per cast member per item
  CONSTRAINT unique_confession_video_reaction UNIQUE NULLS NOT DISTINCT (video_id, cast_member_id),
  CONSTRAINT unique_confession_comment_reaction UNIQUE NULLS NOT DISTINCT (comment_id, cast_member_id),

  -- Must react to either video OR comment, not both
  CONSTRAINT video_or_comment CHECK (
    (video_id IS NOT NULL AND comment_id IS NULL) OR
    (video_id IS NULL AND comment_id IS NOT NULL)
  )
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_confession_reactions_video
  ON public.mm_confession_booth_reactions(video_id);

CREATE INDEX IF NOT EXISTS idx_confession_reactions_comment
  ON public.mm_confession_booth_reactions(comment_id);

CREATE INDEX IF NOT EXISTS idx_confession_reactions_cast_member
  ON public.mm_confession_booth_reactions(cast_member_id);

COMMENT ON TABLE public.mm_confession_booth_reactions IS
  'Reactions on confession booth videos and comments';

-- ============================================================================
-- PART 5: Storage Buckets
-- ============================================================================

-- Confession booth avatars bucket (user stills)
DO $$
BEGIN
  INSERT INTO storage.buckets (id, name, public)
  VALUES ('confession-booth-avatars', 'confession-booth-avatars', true);
EXCEPTION
  WHEN unique_violation THEN NULL;
END $$;

-- Confession booth videos bucket (HeyGen outputs)
DO $$
BEGIN
  INSERT INTO storage.buckets (id, name, public)
  VALUES ('confession-booth-videos', 'confession-booth-videos', true);
EXCEPTION
  WHEN unique_violation THEN NULL;
END $$;

-- Confession booth backgrounds bucket (preset environments)
DO $$
BEGIN
  INSERT INTO storage.buckets (id, name, public)
  VALUES ('confession-booth-backgrounds', 'confession-booth-backgrounds', true);
EXCEPTION
  WHEN unique_violation THEN NULL;
END $$;

-- ============================================================================
-- PART 6: RLS Policies - Confession Booth Videos
-- ============================================================================

ALTER TABLE public.mm_confession_booth_videos ENABLE ROW LEVEL SECURITY;

-- Public read for approved videos
DROP POLICY IF EXISTS "public_read_approved_confession_videos" ON public.mm_confession_booth_videos;
CREATE POLICY "public_read_approved_confession_videos" ON public.mm_confession_booth_videos
  FOR SELECT USING (is_approved = true AND moderation_status = 'approved');

-- Authenticated users can see their own videos (any status)
DROP POLICY IF EXISTS "cast_members_read_own_videos" ON public.mm_confession_booth_videos;
CREATE POLICY "cast_members_read_own_videos" ON public.mm_confession_booth_videos
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.cast_members
      WHERE id = cast_member_id AND user_id = auth.uid()
    )
  );

-- Authenticated users can create videos for their cast members
DROP POLICY IF EXISTS "cast_members_insert_videos" ON public.mm_confession_booth_videos;
CREATE POLICY "cast_members_insert_videos" ON public.mm_confession_booth_videos
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.cast_members
      WHERE id = cast_member_id AND user_id = auth.uid()
    )
  );

-- Users can update their own videos (for engagement counts)
DROP POLICY IF EXISTS "cast_members_update_own_videos" ON public.mm_confession_booth_videos;
CREATE POLICY "cast_members_update_own_videos" ON public.mm_confession_booth_videos
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.cast_members
      WHERE id = cast_member_id AND user_id = auth.uid()
    )
  );

-- Admins can read all videos
DROP POLICY IF EXISTS "admins_read_all_videos" ON public.mm_confession_booth_videos;
CREATE POLICY "admins_read_all_videos" ON public.mm_confession_booth_videos
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role IN ('admin', 'super_admin')
    )
  );

-- Admins can update any video (for moderation)
DROP POLICY IF EXISTS "admins_update_videos" ON public.mm_confession_booth_videos;
CREATE POLICY "admins_update_videos" ON public.mm_confession_booth_videos
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role IN ('admin', 'super_admin')
    )
  );

GRANT SELECT, INSERT, UPDATE ON public.mm_confession_booth_videos TO authenticated;
GRANT SELECT ON public.mm_confession_booth_videos TO anon;

-- ============================================================================
-- PART 7: RLS Policies - Confession Booth Comments
-- ============================================================================

ALTER TABLE public.mm_confession_booth_comments ENABLE ROW LEVEL SECURITY;

-- Public read
DROP POLICY IF EXISTS "public_read_confession_comments" ON public.mm_confession_booth_comments;
CREATE POLICY "public_read_confession_comments" ON public.mm_confession_booth_comments
  FOR SELECT USING (true);

-- Authenticated insert
DROP POLICY IF EXISTS "cast_members_insert_confession_comments" ON public.mm_confession_booth_comments;
CREATE POLICY "cast_members_insert_confession_comments" ON public.mm_confession_booth_comments
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.cast_members
      WHERE id = cast_member_id AND user_id = auth.uid()
    )
  );

-- Update own comments
DROP POLICY IF EXISTS "cast_members_update_own_confession_comments" ON public.mm_confession_booth_comments;
CREATE POLICY "cast_members_update_own_confession_comments" ON public.mm_confession_booth_comments
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.cast_members
      WHERE id = cast_member_id AND user_id = auth.uid()
    )
  );

-- Delete own comments
DROP POLICY IF EXISTS "cast_members_delete_own_confession_comments" ON public.mm_confession_booth_comments;
CREATE POLICY "cast_members_delete_own_confession_comments" ON public.mm_confession_booth_comments
  FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.cast_members
      WHERE id = cast_member_id AND user_id = auth.uid()
    )
  );

GRANT SELECT, INSERT, UPDATE, DELETE ON public.mm_confession_booth_comments TO authenticated;
GRANT SELECT ON public.mm_confession_booth_comments TO anon;

-- ============================================================================
-- PART 8: RLS Policies - Confession Booth Reactions
-- ============================================================================

ALTER TABLE public.mm_confession_booth_reactions ENABLE ROW LEVEL SECURITY;

-- Public read
DROP POLICY IF EXISTS "public_read_confession_reactions" ON public.mm_confession_booth_reactions;
CREATE POLICY "public_read_confession_reactions" ON public.mm_confession_booth_reactions
  FOR SELECT USING (true);

-- Authenticated insert
DROP POLICY IF EXISTS "cast_members_insert_confession_reactions" ON public.mm_confession_booth_reactions;
CREATE POLICY "cast_members_insert_confession_reactions" ON public.mm_confession_booth_reactions
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.cast_members
      WHERE id = cast_member_id AND user_id = auth.uid()
    )
  );

-- Update/delete own reactions
DROP POLICY IF EXISTS "cast_members_manage_own_confession_reactions" ON public.mm_confession_booth_reactions;
CREATE POLICY "cast_members_manage_own_confession_reactions" ON public.mm_confession_booth_reactions
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.cast_members
      WHERE id = cast_member_id AND user_id = auth.uid()
    )
  );

GRANT SELECT, INSERT, UPDATE, DELETE ON public.mm_confession_booth_reactions TO authenticated;
GRANT SELECT ON public.mm_confession_booth_reactions TO anon;

-- ============================================================================
-- PART 9: Storage Bucket Policies
-- ============================================================================

-- Confession booth avatars - public read, authenticated upload
DROP POLICY IF EXISTS "public_read_confession_avatars" ON storage.objects;
CREATE POLICY "public_read_confession_avatars" ON storage.objects
  FOR SELECT USING (bucket_id = 'confession-booth-avatars');

DROP POLICY IF EXISTS "authenticated_upload_confession_avatars" ON storage.objects;
CREATE POLICY "authenticated_upload_confession_avatars" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'confession-booth-avatars');

DROP POLICY IF EXISTS "authenticated_update_confession_avatars" ON storage.objects;
CREATE POLICY "authenticated_update_confession_avatars" ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'confession-booth-avatars');

-- Confession booth videos - public read, authenticated upload
DROP POLICY IF EXISTS "public_read_confession_videos" ON storage.objects;
CREATE POLICY "public_read_confession_videos" ON storage.objects
  FOR SELECT USING (bucket_id = 'confession-booth-videos');

DROP POLICY IF EXISTS "authenticated_upload_confession_videos" ON storage.objects;
CREATE POLICY "authenticated_upload_confession_videos" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'confession-booth-videos');

-- Confession booth backgrounds - public read, admin upload
DROP POLICY IF EXISTS "public_read_confession_backgrounds" ON storage.objects;
CREATE POLICY "public_read_confession_backgrounds" ON storage.objects
  FOR SELECT USING (bucket_id = 'confession-booth-backgrounds');

DROP POLICY IF EXISTS "admin_upload_confession_backgrounds" ON storage.objects;
CREATE POLICY "admin_upload_confession_backgrounds" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'confession-booth-backgrounds'
    AND EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role IN ('admin', 'super_admin')
    )
  );

-- ============================================================================
-- PART 10: Helper Functions
-- ============================================================================

-- Function to update video engagement counts
CREATE OR REPLACE FUNCTION update_confession_video_counts()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF TG_TABLE_NAME = 'mm_confession_booth_comments' THEN
      UPDATE public.mm_confession_booth_videos
      SET comments_count = comments_count + 1
      WHERE id = NEW.video_id;
    ELSIF TG_TABLE_NAME = 'mm_confession_booth_reactions' AND NEW.video_id IS NOT NULL THEN
      UPDATE public.mm_confession_booth_videos
      SET likes_count = likes_count + 1
      WHERE id = NEW.video_id;
    END IF;
  ELSIF TG_OP = 'DELETE' THEN
    IF TG_TABLE_NAME = 'mm_confession_booth_comments' THEN
      UPDATE public.mm_confession_booth_videos
      SET comments_count = GREATEST(0, comments_count - 1)
      WHERE id = OLD.video_id;
    ELSIF TG_TABLE_NAME = 'mm_confession_booth_reactions' AND OLD.video_id IS NOT NULL THEN
      UPDATE public.mm_confession_booth_videos
      SET likes_count = GREATEST(0, likes_count - 1)
      WHERE id = OLD.video_id;
    END IF;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Triggers for auto-updating counts
DROP TRIGGER IF EXISTS update_confession_video_comment_count ON public.mm_confession_booth_comments;
CREATE TRIGGER update_confession_video_comment_count
  AFTER INSERT OR DELETE ON public.mm_confession_booth_comments
  FOR EACH ROW EXECUTE FUNCTION update_confession_video_counts();

DROP TRIGGER IF EXISTS update_confession_video_reaction_count ON public.mm_confession_booth_reactions;
CREATE TRIGGER update_confession_video_reaction_count
  AFTER INSERT OR DELETE ON public.mm_confession_booth_reactions
  FOR EACH ROW EXECUTE FUNCTION update_confession_video_counts();

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
DECLARE
  v_new_tables INTEGER;
  v_new_columns INTEGER;
  v_new_buckets INTEGER;
BEGIN
  -- Check new tables
  SELECT COUNT(*) INTO v_new_tables
  FROM information_schema.tables
  WHERE table_schema = 'public'
  AND table_name IN (
    'mm_confession_booth_videos',
    'mm_confession_booth_comments',
    'mm_confession_booth_reactions'
  );

  -- Check new columns on cast_members
  SELECT COUNT(*) INTO v_new_columns
  FROM information_schema.columns
  WHERE table_schema = 'public'
  AND table_name = 'cast_members'
  AND column_name IN (
    'confession_booth_avatar_url',
    'confession_avatar_source',
    'confession_avatar_set_at'
  );

  -- Check new storage buckets
  SELECT COUNT(*) INTO v_new_buckets
  FROM storage.buckets
  WHERE id IN (
    'confession-booth-avatars',
    'confession-booth-videos',
    'confession-booth-backgrounds'
  );

  RAISE NOTICE '✅ Confession Booth Video System Migration Complete!';
  RAISE NOTICE 'New tables created: % / 3', v_new_tables;
  RAISE NOTICE 'New columns added to cast_members: % / 3', v_new_columns;
  RAISE NOTICE 'New storage buckets: % / 3', v_new_buckets;
  RAISE NOTICE 'Ready for HeyGen video generation integration!';
END $$;
