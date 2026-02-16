-- ============================================================================
-- ADD ANONYMOUS POSTING TO TEA ROOM
-- Confessional booth feature - post anonymously with hidden identity
-- ============================================================================

-- Add is_anonymous column to posts
ALTER TABLE mm_tea_room_posts
ADD COLUMN is_anonymous BOOLEAN DEFAULT false;

-- Add is_anonymous column to comments
ALTER TABLE mm_tea_spot_comments
ADD COLUMN is_anonymous BOOLEAN DEFAULT false;

-- Create index for filtering anonymous posts
CREATE INDEX idx_tea_room_posts_anonymous ON mm_tea_room_posts(is_anonymous);
CREATE INDEX idx_tea_spot_comments_anonymous ON mm_tea_spot_comments(is_anonymous);

-- Add comment
COMMENT ON COLUMN mm_tea_room_posts.is_anonymous IS
  'If true, this post was made anonymously (confessional booth).
   Display as "Anonymous" instead of cast member name.
   Real cast_member_id is still tracked for moderation.';

COMMENT ON COLUMN mm_tea_spot_comments.is_anonymous IS
  'If true, this comment was made anonymously.
   Real cast_member_id is still tracked for moderation.';

-- Update RLS policies to still allow anonymous posts
-- (Users can still insert with their cast_member_id, it just won't be displayed)

-- Verification
DO $$
BEGIN
  RAISE NOTICE '✅ Anonymous posting enabled!';
  RAISE NOTICE '📍 Added is_anonymous column to mm_tea_room_posts';
  RAISE NOTICE '📍 Added is_anonymous column to mm_tea_spot_comments';
  RAISE NOTICE '🎭 Users can now post anonymously in Tea Room';
  RAISE NOTICE '';
  RAISE NOTICE '📝 Next: Update UI to add anonymous toggle';
END $$;
