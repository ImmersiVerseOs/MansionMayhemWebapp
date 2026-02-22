-- ============================================================================
-- MIGRATION 051: FIX MISSING TABLES & BROKEN REFERENCES
-- ============================================================================
-- Creates mm_tea_room_posts (referenced by ai-agent-processor but never created)
-- Fixes missing columns referenced across the codebase
-- ============================================================================

-- 1. mm_tea_room_posts — referenced by ai-agent-processor edge function
CREATE TABLE IF NOT EXISTS public.mm_tea_room_posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id UUID NOT NULL REFERENCES public.mm_games(id) ON DELETE CASCADE,
  cast_member_id UUID NOT NULL REFERENCES public.cast_members(id) ON DELETE CASCADE,
  content TEXT NOT NULL CHECK (char_length(content) <= 1000),
  post_type TEXT DEFAULT 'tea' CHECK (post_type IN ('tea', 'shade', 'confession', 'announcement', 'anonymous')),
  is_anonymous BOOLEAN DEFAULT false,
  is_ai_generated BOOLEAN DEFAULT false,
  reactions JSONB DEFAULT '{}',
  reply_to_id UUID REFERENCES public.mm_tea_room_posts(id),
  phase TEXT, -- which game phase this was posted during
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tea_posts_game ON mm_tea_room_posts(game_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_tea_posts_cast ON mm_tea_room_posts(cast_member_id);

ALTER TABLE public.mm_tea_room_posts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can read tea posts" ON mm_tea_room_posts;
CREATE POLICY "Anyone can read tea posts" ON mm_tea_room_posts FOR SELECT USING (true);

DROP POLICY IF EXISTS "Authenticated can create tea posts" ON mm_tea_room_posts;
CREATE POLICY "Authenticated can create tea posts" ON mm_tea_room_posts FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Service role manages tea posts" ON mm_tea_room_posts;
CREATE POLICY "Service role manages tea posts" ON mm_tea_room_posts FOR ALL USING (auth.role() = 'service_role');

-- Enable realtime for tea posts
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'mm_tea_room_posts'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE mm_tea_room_posts;
  END IF;
END $$;

-- 2. Add missing columns on mm_voting_rounds
ALTER TABLE public.mm_voting_rounds
  ADD COLUMN IF NOT EXISTS round_type TEXT DEFAULT 'elimination' CHECK (round_type IN ('elimination', 'finale', 'hot_seat')),
  ADD COLUMN IF NOT EXISTS queen_direct_elimination_id UUID REFERENCES public.cast_members(id),
  ADD COLUMN IF NOT EXISTS house_vote_eliminated_id UUID REFERENCES public.cast_members(id),
  ADD COLUMN IF NOT EXISTS week_number INTEGER;

-- Backfill week_number from round_number if NULL
UPDATE mm_voting_rounds SET week_number = round_number WHERE week_number IS NULL;

-- 3. Add missing columns on mm_games
ALTER TABLE public.mm_games
  ADD COLUMN IF NOT EXISTS current_week INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS game_starts_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS director_user_id UUID;

-- 4. Add missing columns on mm_queen_selections
ALTER TABLE public.mm_queen_selections
  ADD COLUMN IF NOT EXISTS cast_member_id UUID REFERENCES public.cast_members(id);

-- Backfill from selected_queen_id
UPDATE mm_queen_selections SET cast_member_id = selected_queen_id WHERE cast_member_id IS NULL;

-- ============================================================================
-- VERIFICATION
-- ============================================================================
SELECT 'mm_tea_room_posts' AS tbl, count(*) FROM mm_tea_room_posts;
SELECT column_name FROM information_schema.columns
WHERE table_name = 'mm_voting_rounds' AND column_name IN ('round_type', 'queen_direct_elimination_id', 'week_number');
