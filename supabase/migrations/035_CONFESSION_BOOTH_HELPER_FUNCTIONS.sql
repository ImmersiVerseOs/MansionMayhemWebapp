-- ============================================================================
-- Migration 035: Confession Booth Helper Functions
-- ============================================================================
-- RPC functions for confession booth video operations
-- ============================================================================

-- ============================================================================
-- Function: Increment Video Views
-- ============================================================================

CREATE OR REPLACE FUNCTION increment_confession_video_views(video_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE public.mm_confession_booth_videos
  SET views_count = views_count + 1
  WHERE id = video_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION increment_confession_video_views IS
  'Increments the view count for a confession booth video';

-- ============================================================================
-- Function: Get Video with Details
-- ============================================================================

CREATE OR REPLACE FUNCTION get_confession_video_details(video_id UUID)
RETURNS TABLE (
  id UUID,
  dialogue_text TEXT,
  video_url TEXT,
  thumbnail_url TEXT,
  is_anonymous BOOLEAN,
  display_name_override TEXT,
  likes_count INTEGER,
  comments_count INTEGER,
  views_count INTEGER,
  published_at TIMESTAMPTZ,
  author_display_name TEXT,
  author_avatar_url TEXT,
  author_archetype TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    v.id,
    v.dialogue_text,
    v.video_url,
    v.thumbnail_url,
    v.is_anonymous,
    v.display_name_override,
    v.likes_count,
    v.comments_count,
    v.views_count,
    v.published_at,
    CASE
      WHEN v.is_anonymous THEN 'Anonymous'
      ELSE c.display_name
    END AS author_display_name,
    CASE
      WHEN v.is_anonymous THEN NULL
      ELSE c.avatar_url
    END AS author_avatar_url,
    c.archetype AS author_archetype
  FROM public.mm_confession_booth_videos v
  LEFT JOIN public.cast_members c ON v.cast_member_id = c.id
  WHERE v.id = video_id
    AND v.is_approved = true
    AND v.moderation_status = 'approved';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION get_confession_video_details IS
  'Gets full details for a confession video, respecting anonymity settings';

-- ============================================================================
-- Function: Get Popular Confession Videos
-- ============================================================================

CREATE OR REPLACE FUNCTION get_popular_confession_videos(
  game_id_param UUID,
  limit_count INTEGER DEFAULT 20,
  offset_count INTEGER DEFAULT 0
)
RETURNS TABLE (
  id UUID,
  dialogue_text TEXT,
  video_url TEXT,
  thumbnail_url TEXT,
  is_anonymous BOOLEAN,
  likes_count INTEGER,
  comments_count INTEGER,
  views_count INTEGER,
  published_at TIMESTAMPTZ,
  author_display_name TEXT,
  author_avatar_url TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    v.id,
    v.dialogue_text,
    v.video_url,
    v.thumbnail_url,
    v.is_anonymous,
    v.likes_count,
    v.comments_count,
    v.views_count,
    v.published_at,
    CASE
      WHEN v.is_anonymous THEN 'Anonymous'
      ELSE c.display_name
    END AS author_display_name,
    CASE
      WHEN v.is_anonymous THEN NULL
      ELSE c.avatar_url
    END AS author_avatar_url
  FROM public.mm_confession_booth_videos v
  LEFT JOIN public.cast_members c ON v.cast_member_id = c.id
  WHERE v.game_id = game_id_param
    AND v.is_approved = true
    AND v.moderation_status = 'approved'
  ORDER BY v.likes_count DESC, v.views_count DESC
  LIMIT limit_count
  OFFSET offset_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION get_popular_confession_videos IS
  'Gets popular confession videos sorted by engagement (likes + views)';

-- ============================================================================
-- Function: Check if User Has Liked Video
-- ============================================================================

CREATE OR REPLACE FUNCTION has_user_liked_confession_video(
  video_id_param UUID,
  cast_member_id_param UUID
)
RETURNS BOOLEAN AS $$
DECLARE
  has_liked BOOLEAN;
BEGIN
  SELECT EXISTS(
    SELECT 1
    FROM public.mm_confession_booth_reactions
    WHERE video_id = video_id_param
      AND cast_member_id = cast_member_id_param
      AND reaction_type = 'like'
  ) INTO has_liked;

  RETURN has_liked;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION has_user_liked_confession_video IS
  'Checks if a user has already liked a confession video';

-- ============================================================================
-- Function: Get Video Comments with Threading
-- ============================================================================

CREATE OR REPLACE FUNCTION get_confession_video_comments(
  video_id_param UUID,
  limit_count INTEGER DEFAULT 50
)
RETURNS TABLE (
  id UUID,
  comment_text TEXT,
  voice_note_url TEXT,
  like_count INTEGER,
  parent_id UUID,
  created_at TIMESTAMPTZ,
  author_display_name TEXT,
  author_avatar_url TEXT,
  author_archetype TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    cc.id,
    cc.comment_text,
    cc.voice_note_url,
    cc.like_count,
    cc.parent_id,
    cc.created_at,
    c.display_name AS author_display_name,
    c.avatar_url AS author_avatar_url,
    c.archetype AS author_archetype
  FROM public.mm_confession_booth_comments cc
  JOIN public.cast_members c ON cc.cast_member_id = c.id
  WHERE cc.video_id = video_id_param
  ORDER BY
    CASE WHEN cc.parent_id IS NULL THEN cc.created_at ELSE NULL END ASC,
    cc.created_at ASC
  LIMIT limit_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION get_confession_video_comments IS
  'Gets comments for a confession video with threading support';

-- ============================================================================
-- Function: Get User's Confession Videos
-- ============================================================================

CREATE OR REPLACE FUNCTION get_user_confession_videos(
  cast_member_id_param UUID,
  include_pending BOOLEAN DEFAULT false
)
RETURNS TABLE (
  id UUID,
  dialogue_text TEXT,
  video_url TEXT,
  thumbnail_url TEXT,
  heygen_status TEXT,
  moderation_status TEXT,
  is_approved BOOLEAN,
  likes_count INTEGER,
  comments_count INTEGER,
  views_count INTEGER,
  created_at TIMESTAMPTZ,
  published_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    v.id,
    v.dialogue_text,
    v.video_url,
    v.thumbnail_url,
    v.heygen_status,
    v.moderation_status,
    v.is_approved,
    v.likes_count,
    v.comments_count,
    v.views_count,
    v.created_at,
    v.published_at
  FROM public.mm_confession_booth_videos v
  WHERE v.cast_member_id = cast_member_id_param
    AND (include_pending OR (v.is_approved = true AND v.moderation_status = 'approved'))
  ORDER BY v.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION get_user_confession_videos IS
  'Gets all confession videos created by a specific user';

-- ============================================================================
-- Grants
-- ============================================================================

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION increment_confession_video_views TO authenticated;
GRANT EXECUTE ON FUNCTION get_confession_video_details TO authenticated;
GRANT EXECUTE ON FUNCTION get_popular_confession_videos TO authenticated;
GRANT EXECUTE ON FUNCTION has_user_liked_confession_video TO authenticated;
GRANT EXECUTE ON FUNCTION get_confession_video_comments TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_confession_videos TO authenticated;

-- Grant execute to anon for read-only functions
GRANT EXECUTE ON FUNCTION get_confession_video_details TO anon;
GRANT EXECUTE ON FUNCTION get_popular_confession_videos TO anon;
GRANT EXECUTE ON FUNCTION get_confession_video_comments TO anon;

-- ============================================================================
-- Verification
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '✅ Confession Booth Helper Functions Created!';
  RAISE NOTICE 'Functions available:';
  RAISE NOTICE '  - increment_confession_video_views';
  RAISE NOTICE '  - get_confession_video_details';
  RAISE NOTICE '  - get_popular_confession_videos';
  RAISE NOTICE '  - has_user_liked_confession_video';
  RAISE NOTICE '  - get_confession_video_comments';
  RAISE NOTICE '  - get_user_confession_videos';
END $$;
