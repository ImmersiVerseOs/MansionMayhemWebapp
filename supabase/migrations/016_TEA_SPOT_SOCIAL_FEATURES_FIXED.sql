-- ============================================================================
-- Migration 016: The Tea Spot - Social Features (FIXED)
-- ============================================================================
-- Adds comments, reactions, and notifications to the tea room
-- Makes it a full social feed where users can interact with posts
-- ============================================================================

-- ============================================================================
-- PART 1: Comments Table (with threading support)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.mm_tea_spot_comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES public.mm_tea_room_posts(id) ON DELETE CASCADE,
  cast_member_id UUID NOT NULL REFERENCES public.cast_members(id) ON DELETE CASCADE,
  parent_id UUID REFERENCES public.mm_tea_spot_comments(id) ON DELETE CASCADE,

  -- Content (text or voice or both)
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
CREATE INDEX IF NOT EXISTS idx_tea_spot_comments_post ON public.mm_tea_spot_comments(post_id);
CREATE INDEX IF NOT EXISTS idx_tea_spot_comments_parent ON public.mm_tea_spot_comments(parent_id);
CREATE INDEX IF NOT EXISTS idx_tea_spot_comments_cast_member ON public.mm_tea_spot_comments(cast_member_id);
CREATE INDEX IF NOT EXISTS idx_tea_spot_comments_created ON public.mm_tea_spot_comments(created_at DESC);

COMMENT ON TABLE public.mm_tea_spot_comments IS 'Comments on tea room posts with threading support';

-- ============================================================================
-- PART 2: Reactions Table (likes on posts and comments)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.mm_tea_spot_reactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID REFERENCES public.mm_tea_room_posts(id) ON DELETE CASCADE,
  comment_id UUID REFERENCES public.mm_tea_spot_comments(id) ON DELETE CASCADE,
  cast_member_id UUID NOT NULL REFERENCES public.cast_members(id) ON DELETE CASCADE,
  reaction_type TEXT NOT NULL CHECK (reaction_type IN ('like', 'love', 'fire', 'laugh', 'shocked', 'sad', 'angry')),

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- One reaction per cast member per item
  CONSTRAINT unique_post_reaction UNIQUE NULLS NOT DISTINCT (post_id, cast_member_id),
  CONSTRAINT unique_comment_reaction UNIQUE NULLS NOT DISTINCT (comment_id, cast_member_id),

  -- Must react to either post OR comment, not both
  CONSTRAINT post_or_comment CHECK (
    (post_id IS NOT NULL AND comment_id IS NULL) OR
    (post_id IS NULL AND comment_id IS NOT NULL)
  )
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_tea_spot_reactions_post ON public.mm_tea_spot_reactions(post_id);
CREATE INDEX IF NOT EXISTS idx_tea_spot_reactions_comment ON public.mm_tea_spot_reactions(comment_id);
CREATE INDEX IF NOT EXISTS idx_tea_spot_reactions_cast_member ON public.mm_tea_spot_reactions(cast_member_id);

COMMENT ON TABLE public.mm_tea_spot_reactions IS 'Reactions (likes) on posts and comments';

-- ============================================================================
-- PART 3: Notifications Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.mm_tea_spot_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cast_member_id UUID NOT NULL REFERENCES public.cast_members(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('comment', 'reply', 'reaction', 'mention', 'voice_reply')),

  -- Source
  from_cast_member_id UUID NOT NULL REFERENCES public.cast_members(id) ON DELETE CASCADE,
  post_id UUID REFERENCES public.mm_tea_room_posts(id) ON DELETE CASCADE,
  comment_id UUID REFERENCES public.mm_tea_spot_comments(id) ON DELETE CASCADE,

  -- Content
  message TEXT NOT NULL,
  action_url TEXT,

  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_tea_spot_notifications_cast_member ON public.mm_tea_spot_notifications(cast_member_id, is_read);
CREATE INDEX IF NOT EXISTS idx_tea_spot_notifications_created ON public.mm_tea_spot_notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_tea_spot_notifications_unread ON public.mm_tea_spot_notifications(cast_member_id) WHERE is_read = false;

COMMENT ON TABLE public.mm_tea_spot_notifications IS 'Notifications for interactions on tea room posts';

-- ============================================================================
-- PART 4: RLS Policies - Comments
-- ============================================================================

ALTER TABLE public.mm_tea_spot_comments ENABLE ROW LEVEL SECURITY;

-- Public read
DROP POLICY IF EXISTS "public_read_comments" ON public.mm_tea_spot_comments;
CREATE POLICY "public_read_comments" ON public.mm_tea_spot_comments
  FOR SELECT USING (true);

-- Authenticated insert
DROP POLICY IF EXISTS "cast_members_insert_comments" ON public.mm_tea_spot_comments;
CREATE POLICY "cast_members_insert_comments" ON public.mm_tea_spot_comments
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.cast_members
      WHERE id = cast_member_id AND user_id = auth.uid()
    )
  );

-- Update own comments
DROP POLICY IF EXISTS "cast_members_update_own_comments" ON public.mm_tea_spot_comments;
CREATE POLICY "cast_members_update_own_comments" ON public.mm_tea_spot_comments
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.cast_members
      WHERE id = cast_member_id AND user_id = auth.uid()
    )
  );

-- Delete own comments
DROP POLICY IF EXISTS "cast_members_delete_own_comments" ON public.mm_tea_spot_comments;
CREATE POLICY "cast_members_delete_own_comments" ON public.mm_tea_spot_comments
  FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.cast_members
      WHERE id = cast_member_id AND user_id = auth.uid()
    )
  );

GRANT SELECT, INSERT, UPDATE, DELETE ON public.mm_tea_spot_comments TO authenticated;
GRANT SELECT ON public.mm_tea_spot_comments TO anon;

-- ============================================================================
-- PART 5: RLS Policies - Reactions
-- ============================================================================

ALTER TABLE public.mm_tea_spot_reactions ENABLE ROW LEVEL SECURITY;

-- Public read
DROP POLICY IF EXISTS "public_read_reactions" ON public.mm_tea_spot_reactions;
CREATE POLICY "public_read_reactions" ON public.mm_tea_spot_reactions
  FOR SELECT USING (true);

-- Authenticated insert
DROP POLICY IF EXISTS "cast_members_insert_reactions" ON public.mm_tea_spot_reactions;
CREATE POLICY "cast_members_insert_reactions" ON public.mm_tea_spot_reactions
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.cast_members
      WHERE id = cast_member_id AND user_id = auth.uid()
    )
  );

-- Delete own reactions
DROP POLICY IF EXISTS "cast_members_delete_reactions" ON public.mm_tea_spot_reactions;
CREATE POLICY "cast_members_delete_reactions" ON public.mm_tea_spot_reactions
  FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.cast_members
      WHERE id = cast_member_id AND user_id = auth.uid()
    )
  );

GRANT SELECT, INSERT, DELETE ON public.mm_tea_spot_reactions TO authenticated;
GRANT SELECT ON public.mm_tea_spot_reactions TO anon;

-- ============================================================================
-- PART 6: RLS Policies - Notifications
-- ============================================================================

ALTER TABLE public.mm_tea_spot_notifications ENABLE ROW LEVEL SECURITY;

-- Read own notifications
DROP POLICY IF EXISTS "cast_members_read_own_notifications" ON public.mm_tea_spot_notifications;
CREATE POLICY "cast_members_read_own_notifications" ON public.mm_tea_spot_notifications
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.cast_members
      WHERE id = cast_member_id AND user_id = auth.uid()
    )
  );

-- Update own notifications (mark as read)
DROP POLICY IF EXISTS "cast_members_update_own_notifications" ON public.mm_tea_spot_notifications;
CREATE POLICY "cast_members_update_own_notifications" ON public.mm_tea_spot_notifications
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.cast_members
      WHERE id = cast_member_id AND user_id = auth.uid()
    )
  );

GRANT SELECT, UPDATE ON public.mm_tea_spot_notifications TO authenticated;

-- ============================================================================
-- PART 7: Trigger Functions
-- ============================================================================

-- Update comment like count
CREATE OR REPLACE FUNCTION public.update_comment_like_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' AND NEW.comment_id IS NOT NULL THEN
    UPDATE public.mm_tea_spot_comments
    SET like_count = like_count + 1
    WHERE id = NEW.comment_id;
  ELSIF TG_OP = 'DELETE' AND OLD.comment_id IS NOT NULL THEN
    UPDATE public.mm_tea_spot_comments
    SET like_count = GREATEST(0, like_count - 1)
    WHERE id = OLD.comment_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update post like count
CREATE OR REPLACE FUNCTION public.update_post_like_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' AND NEW.post_id IS NOT NULL THEN
    UPDATE public.mm_tea_room_posts
    SET likes_count = likes_count + 1
    WHERE id = NEW.post_id;
  ELSIF TG_OP = 'DELETE' AND OLD.post_id IS NOT NULL THEN
    UPDATE public.mm_tea_room_posts
    SET likes_count = GREATEST(0, likes_count - 1)
    WHERE id = OLD.post_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update post comment count
CREATE OR REPLACE FUNCTION public.update_post_comment_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.mm_tea_room_posts
    SET comments_count = comments_count + 1
    WHERE id = NEW.post_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.mm_tea_room_posts
    SET comments_count = GREATEST(0, comments_count - 1)
    WHERE id = OLD.post_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create notification on comment
CREATE OR REPLACE FUNCTION public.notify_on_comment()
RETURNS TRIGGER AS $$
DECLARE
  v_post_author UUID;
  v_parent_author UUID;
  v_commenter_name TEXT;
BEGIN
  -- Get commenter display name
  SELECT display_name INTO v_commenter_name
  FROM public.cast_members
  WHERE id = NEW.cast_member_id;

  -- If this is a reply
  IF NEW.parent_id IS NOT NULL THEN
    SELECT cast_member_id INTO v_parent_author
    FROM public.mm_tea_spot_comments
    WHERE id = NEW.parent_id;

    -- Don't notify if replying to own comment
    IF v_parent_author != NEW.cast_member_id THEN
      INSERT INTO public.mm_tea_spot_notifications (
        cast_member_id,
        type,
        from_cast_member_id,
        post_id,
        comment_id,
        message,
        action_url
      ) VALUES (
        v_parent_author,
        'reply',
        NEW.cast_member_id,
        NEW.post_id,
        NEW.id,
        v_commenter_name || ' replied to your comment',
        '/pages/ai-tea-room.html?post=' || NEW.post_id
      );
    END IF;
  ELSE
    -- Top-level comment
    SELECT cast_member_id INTO v_post_author
    FROM public.mm_tea_room_posts
    WHERE id = NEW.post_id;

    -- Don't notify if commenting on own post
    IF v_post_author != NEW.cast_member_id THEN
      INSERT INTO public.mm_tea_spot_notifications (
        cast_member_id,
        type,
        from_cast_member_id,
        post_id,
        comment_id,
        message,
        action_url
      ) VALUES (
        v_post_author,
        CASE WHEN NEW.voice_note_url IS NOT NULL THEN 'voice_reply' ELSE 'comment' END,
        NEW.cast_member_id,
        NEW.post_id,
        NEW.id,
        v_commenter_name || CASE
          WHEN NEW.voice_note_url IS NOT NULL THEN ' sent a voice reply to your post'
          ELSE ' commented on your post'
        END,
        '/pages/ai-tea-room.html?post=' || NEW.post_id
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create notification on reaction
CREATE OR REPLACE FUNCTION public.notify_on_reaction()
RETURNS TRIGGER AS $$
DECLARE
  v_target_cast_member UUID;
  v_reactor_name TEXT;
  v_content_type TEXT;
  v_related_post_id UUID;
BEGIN
  -- Get reactor display name
  SELECT display_name INTO v_reactor_name
  FROM public.cast_members
  WHERE id = NEW.cast_member_id;

  -- Determine target and content type
  IF NEW.post_id IS NOT NULL THEN
    SELECT cast_member_id INTO v_target_cast_member
    FROM public.mm_tea_room_posts WHERE id = NEW.post_id;
    v_content_type := 'post';
    v_related_post_id := NEW.post_id;
  ELSE
    SELECT cast_member_id, post_id INTO v_target_cast_member, v_related_post_id
    FROM public.mm_tea_spot_comments WHERE id = NEW.comment_id;
    v_content_type := 'comment';
  END IF;

  -- Don't notify if reacting to own content
  IF v_target_cast_member != NEW.cast_member_id THEN
    INSERT INTO public.mm_tea_spot_notifications (
      cast_member_id,
      type,
      from_cast_member_id,
      post_id,
      comment_id,
      message,
      action_url
    ) VALUES (
      v_target_cast_member,
      'reaction',
      NEW.cast_member_id,
      NEW.post_id,
      NEW.comment_id,
      v_reactor_name || ' reacted to your ' || v_content_type,
      '/pages/ai-tea-room.html?post=' || v_related_post_id
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- PART 8: Triggers (FIXED - removed WHEN clauses that caused issues)
-- ============================================================================

-- Trigger for comment likes
DROP TRIGGER IF EXISTS trigger_update_comment_likes ON public.mm_tea_spot_reactions;
CREATE TRIGGER trigger_update_comment_likes
AFTER INSERT OR DELETE ON public.mm_tea_spot_reactions
FOR EACH ROW
EXECUTE FUNCTION public.update_comment_like_count();

-- Trigger for post likes
DROP TRIGGER IF EXISTS trigger_update_post_likes ON public.mm_tea_spot_reactions;
CREATE TRIGGER trigger_update_post_likes
AFTER INSERT OR DELETE ON public.mm_tea_spot_reactions
FOR EACH ROW
EXECUTE FUNCTION public.update_post_like_count();

-- Trigger for post comment count
DROP TRIGGER IF EXISTS trigger_update_post_comments ON public.mm_tea_spot_comments;
CREATE TRIGGER trigger_update_post_comments
AFTER INSERT OR DELETE ON public.mm_tea_spot_comments
FOR EACH ROW
EXECUTE FUNCTION public.update_post_comment_count();

-- Trigger for comment notifications
DROP TRIGGER IF EXISTS trigger_notify_on_comment ON public.mm_tea_spot_comments;
CREATE TRIGGER trigger_notify_on_comment
AFTER INSERT ON public.mm_tea_spot_comments
FOR EACH ROW
EXECUTE FUNCTION public.notify_on_comment();

-- Trigger for reaction notifications
DROP TRIGGER IF EXISTS trigger_notify_on_reaction ON public.mm_tea_spot_reactions;
CREATE TRIGGER trigger_notify_on_reaction
AFTER INSERT ON public.mm_tea_spot_reactions
FOR EACH ROW
EXECUTE FUNCTION public.notify_on_reaction();

-- ============================================================================
-- PART 9: Verification
-- ============================================================================

-- Run these to verify:
SELECT table_name FROM information_schema.tables WHERE table_name LIKE 'mm_tea_spot%';
-- Should return: mm_tea_spot_comments, mm_tea_spot_reactions, mm_tea_spot_notifications

SELECT tablename, policyname FROM pg_policies WHERE tablename LIKE 'mm_tea_spot%';
-- Should show all RLS policies

SELECT trigger_name, event_object_table FROM information_schema.triggers WHERE event_object_table LIKE 'mm_tea_%';
-- Should show all 5 triggers
