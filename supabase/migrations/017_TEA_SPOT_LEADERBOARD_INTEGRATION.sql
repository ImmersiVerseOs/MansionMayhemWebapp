-- ============================================================================
-- Migration 017: Tea Spot Leaderboard Integration
-- ============================================================================
-- Automatically updates drama_score and influence_score based on Tea Spot activity
-- ============================================================================

-- ============================================================================
-- PART 1: Update Drama Score When Posts Are Created
-- ============================================================================

CREATE OR REPLACE FUNCTION public.update_drama_on_post()
RETURNS TRIGGER AS $$
BEGIN
  -- Award drama points for posting
  -- Voice notes get more points (more engaging!)
  UPDATE public.cast_members
  SET
    drama_score = drama_score + CASE
      WHEN NEW.voice_note_url IS NOT NULL THEN 15  -- Voice note post
      ELSE 10  -- Text post
    END,
    activity_count = activity_count + 1
  WHERE id = NEW.cast_member_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for new posts
DROP TRIGGER IF EXISTS trigger_drama_on_post ON public.mm_tea_room_posts;
CREATE TRIGGER trigger_drama_on_post
AFTER INSERT ON public.mm_tea_room_posts
FOR EACH ROW
EXECUTE FUNCTION public.update_drama_on_post();

-- ============================================================================
-- PART 2: Update Drama Score When Reactions Are Received
-- ============================================================================

CREATE OR REPLACE FUNCTION public.update_drama_on_reaction()
RETURNS TRIGGER AS $$
DECLARE
  v_content_author UUID;
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Determine who created the content
    IF NEW.post_id IS NOT NULL THEN
      -- Reaction on post
      SELECT cast_member_id INTO v_content_author
      FROM public.mm_tea_room_posts
      WHERE id = NEW.post_id;
    ELSE
      -- Reaction on comment
      SELECT cast_member_id INTO v_content_author
      FROM public.mm_tea_spot_comments
      WHERE id = NEW.comment_id;
    END IF;

    -- Award drama points to content author (don't award for self-likes)
    IF v_content_author != NEW.cast_member_id THEN
      UPDATE public.cast_members
      SET drama_score = drama_score + 5  -- Each like = +5 drama
      WHERE id = v_content_author;
    END IF;

  ELSIF TG_OP = 'DELETE' THEN
    -- Remove drama points when reaction is removed
    IF OLD.post_id IS NOT NULL THEN
      SELECT cast_member_id INTO v_content_author
      FROM public.mm_tea_room_posts
      WHERE id = OLD.post_id;
    ELSE
      SELECT cast_member_id INTO v_content_author
      FROM public.mm_tea_spot_comments
      WHERE id = OLD.comment_id;
    END IF;

    -- Subtract drama points (don't go below 0)
    IF v_content_author != OLD.cast_member_id THEN
      UPDATE public.cast_members
      SET drama_score = GREATEST(0, drama_score - 5)
      WHERE id = v_content_author;
    END IF;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for reactions
DROP TRIGGER IF EXISTS trigger_drama_on_reaction ON public.mm_tea_spot_reactions;
CREATE TRIGGER trigger_drama_on_reaction
AFTER INSERT OR DELETE ON public.mm_tea_spot_reactions
FOR EACH ROW
EXECUTE FUNCTION public.update_drama_on_reaction();

-- ============================================================================
-- PART 3: Update Influence Score When Comments Are Received
-- ============================================================================

CREATE OR REPLACE FUNCTION public.update_influence_on_comment()
RETURNS TRIGGER AS $$
DECLARE
  v_post_author UUID;
  v_parent_author UUID;
  v_points INTEGER;
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Determine points based on comment type
    v_points := CASE
      WHEN NEW.voice_note_url IS NOT NULL THEN 12  -- Voice reply
      ELSE 8  -- Text comment
    END;

    -- If it's a reply to a comment
    IF NEW.parent_id IS NOT NULL THEN
      -- Award influence to the comment author being replied to
      SELECT cast_member_id INTO v_parent_author
      FROM public.mm_tea_spot_comments
      WHERE id = NEW.parent_id;

      IF v_parent_author != NEW.cast_member_id THEN
        UPDATE public.cast_members
        SET influence_score = influence_score + v_points
        WHERE id = v_parent_author;
      END IF;
    ELSE
      -- Award influence to the post author
      SELECT cast_member_id INTO v_post_author
      FROM public.mm_tea_room_posts
      WHERE id = NEW.post_id;

      IF v_post_author != NEW.cast_member_id THEN
        UPDATE public.cast_members
        SET influence_score = influence_score + v_points
        WHERE id = v_post_author;
      END IF;
    END IF;

    -- Commenter also gets activity count
    UPDATE public.cast_members
    SET activity_count = activity_count + 1
    WHERE id = NEW.cast_member_id;

  ELSIF TG_OP = 'DELETE' THEN
    -- Remove influence points when comment is deleted
    v_points := CASE
      WHEN OLD.voice_note_url IS NOT NULL THEN 12
      ELSE 8
    END;

    IF OLD.parent_id IS NOT NULL THEN
      SELECT cast_member_id INTO v_parent_author
      FROM public.mm_tea_spot_comments
      WHERE id = OLD.parent_id;

      IF v_parent_author != OLD.cast_member_id THEN
        UPDATE public.cast_members
        SET influence_score = GREATEST(0, influence_score - v_points)
        WHERE id = v_parent_author;
      END IF;
    ELSE
      SELECT cast_member_id INTO v_post_author
      FROM public.mm_tea_room_posts
      WHERE id = OLD.post_id;

      IF v_post_author != OLD.cast_member_id THEN
        UPDATE public.cast_members
        SET influence_score = GREATEST(0, influence_score - v_points)
        WHERE id = v_post_author;
      END IF;
    END IF;

    -- Remove activity count
    UPDATE public.cast_members
    SET activity_count = GREATEST(0, activity_count - 1)
    WHERE id = OLD.cast_member_id;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for comments
DROP TRIGGER IF EXISTS trigger_influence_on_comment ON public.mm_tea_spot_comments;
CREATE TRIGGER trigger_influence_on_comment
AFTER INSERT OR DELETE ON public.mm_tea_spot_comments
FOR EACH ROW
EXECUTE FUNCTION public.update_influence_on_comment();

-- ============================================================================
-- PART 4: Add Tea Spot Stats Display (Optional Columns)
-- ============================================================================

-- Add columns to track Tea Spot specific metrics (for display purposes)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'cast_members' AND column_name = 'tea_spot_posts_count'
  ) THEN
    ALTER TABLE public.cast_members
    ADD COLUMN tea_spot_posts_count INTEGER DEFAULT 0,
    ADD COLUMN tea_spot_engagement_received INTEGER DEFAULT 0;

    COMMENT ON COLUMN public.cast_members.tea_spot_posts_count IS 'Total posts created in Tea Spot';
    COMMENT ON COLUMN public.cast_members.tea_spot_engagement_received IS 'Total likes + comments received';
  END IF;
END $$;

-- ============================================================================
-- PART 5: Function to Update Tea Spot Stats Counters
-- ============================================================================

CREATE OR REPLACE FUNCTION public.update_tea_spot_counters()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF TG_TABLE_NAME = 'mm_tea_room_posts' THEN
      -- Increment post count
      UPDATE public.cast_members
      SET tea_spot_posts_count = tea_spot_posts_count + 1
      WHERE id = NEW.cast_member_id;
    END IF;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for post count
DROP TRIGGER IF EXISTS trigger_tea_spot_post_counter ON public.mm_tea_room_posts;
CREATE TRIGGER trigger_tea_spot_post_counter
AFTER INSERT ON public.mm_tea_room_posts
FOR EACH ROW
EXECUTE FUNCTION public.update_tea_spot_counters();

-- ============================================================================
-- PART 6: Summary Comment
-- ============================================================================

COMMENT ON FUNCTION public.update_drama_on_post() IS
  'Awards drama points when posts are created. Voice notes get +15, text posts get +10';

COMMENT ON FUNCTION public.update_drama_on_reaction() IS
  'Awards +5 drama points to content author when they receive a like';

COMMENT ON FUNCTION public.update_influence_on_comment() IS
  'Awards influence points when posts/comments receive engagement. Voice replies get +12, text comments get +8';

-- ============================================================================
-- PART 7: Verification & Point System Summary
-- ============================================================================

/*
POINT SYSTEM SUMMARY:

DRAMA SCORE (🔥):
- Create text post: +10 points
- Create voice note post: +15 points
- Receive a like (post or comment): +5 points

INFLUENCE SCORE (👑):
- Receive a text comment: +8 points
- Receive a voice reply: +12 points
- Get a reply to your comment: +8 or +12 points

ACTIVITY COUNT:
- Create a post: +1
- Create a comment: +1

These scores automatically update in real-time via triggers!
Leaderboard will reflect Tea Spot engagement immediately.

VERIFICATION QUERIES:

-- Check triggers exist:
SELECT trigger_name, event_object_table
FROM information_schema.triggers
WHERE trigger_name LIKE '%drama%' OR trigger_name LIKE '%influence%';

-- Test score increases:
SELECT id, display_name, drama_score, influence_score, activity_count, tea_spot_posts_count
FROM cast_members
ORDER BY drama_score DESC
LIMIT 10;

-- Check if posts increase drama:
-- (Create a test post and check cast_member's drama_score)

*/
