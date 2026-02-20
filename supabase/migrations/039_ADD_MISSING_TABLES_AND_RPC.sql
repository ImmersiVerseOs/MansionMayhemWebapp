-- ============================================================================
-- 039: ADD MISSING TABLES, PROFILE COLUMNS, AND VOTE COUNT RPC
-- Fixes critical gaps found in beta audit (2026-02-20)
-- ============================================================================

-- ─── 1. Create voice_notes table ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.voice_notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  game_id UUID REFERENCES public.mm_games(id) ON DELETE CASCADE,
  cast_member_id UUID REFERENCES public.cast_members(id) ON DELETE SET NULL,
  note_type TEXT NOT NULL DEFAULT 'general' CHECK (note_type IN ('general', 'confession', 'drama', 'alliance', 'tea')),
  audio_url TEXT NOT NULL,
  duration_seconds INTEGER DEFAULT 0,
  caption TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_voice_notes_user_id ON public.voice_notes(user_id);
CREATE INDEX idx_voice_notes_game_id ON public.voice_notes(game_id);
CREATE INDEX idx_voice_notes_status ON public.voice_notes(status);

ALTER TABLE public.voice_notes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view approved voice notes" ON public.voice_notes;
CREATE POLICY "Users can view approved voice notes" ON public.voice_notes
  FOR SELECT TO authenticated
  USING (status = 'approved' OR user_id = auth.uid());

DROP POLICY IF EXISTS "Users can create voice notes" ON public.voice_notes;
CREATE POLICY "Users can create voice notes" ON public.voice_notes
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "service_role_all" ON public.voice_notes;
CREATE POLICY "service_role_all" ON public.voice_notes
  FOR ALL USING (auth.role() = 'service_role');

-- ─── 2. Create voice_note_reactions table ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.voice_note_reactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  voice_note_id UUID NOT NULL REFERENCES public.voice_notes(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reaction_type TEXT NOT NULL CHECK (reaction_type IN ('fire', 'drama', 'laugh', 'shocked', 'love', 'shade')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(voice_note_id, user_id)
);

CREATE INDEX idx_voice_note_reactions_note ON public.voice_note_reactions(voice_note_id);

ALTER TABLE public.voice_note_reactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view reactions" ON public.voice_note_reactions;
CREATE POLICY "Users can view reactions" ON public.voice_note_reactions
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Users can react" ON public.voice_note_reactions;
CREATE POLICY "Users can react" ON public.voice_note_reactions
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can remove own reaction" ON public.voice_note_reactions;
CREATE POLICY "Users can remove own reaction" ON public.voice_note_reactions
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "service_role_all" ON public.voice_note_reactions;
CREATE POLICY "service_role_all" ON public.voice_note_reactions
  FOR ALL USING (auth.role() = 'service_role');

-- ─── 3. Create content_reports table ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.content_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content_type TEXT NOT NULL CHECK (content_type IN ('voice_note', 'tea_post', 'alliance_message', 'confession', 'scenario_response')),
  content_id UUID NOT NULL,
  reason TEXT NOT NULL CHECK (reason IN ('inappropriate', 'harassment', 'spam', 'hate_speech', 'other')),
  description TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'action_taken', 'dismissed')),
  reviewed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_content_reports_status ON public.content_reports(status);
CREATE INDEX idx_content_reports_reporter ON public.content_reports(reporter_id);

ALTER TABLE public.content_reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can create reports" ON public.content_reports;
CREATE POLICY "Users can create reports" ON public.content_reports
  FOR INSERT TO authenticated
  WITH CHECK (reporter_id = auth.uid());

DROP POLICY IF EXISTS "Users can view own reports" ON public.content_reports;
CREATE POLICY "Users can view own reports" ON public.content_reports
  FOR SELECT TO authenticated
  USING (reporter_id = auth.uid());

DROP POLICY IF EXISTS "service_role_all" ON public.content_reports;
CREATE POLICY "service_role_all" ON public.content_reports
  FOR ALL USING (auth.role() = 'service_role');

-- ─── 4. Add missing profile columns ───────────────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'alliances_formed') THEN
    ALTER TABLE public.profiles ADD COLUMN alliances_formed INTEGER DEFAULT 0;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'scenarios_completed') THEN
    ALTER TABLE public.profiles ADD COLUMN scenarios_completed INTEGER DEFAULT 0;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'votes_cast') THEN
    ALTER TABLE public.profiles ADD COLUMN votes_cast INTEGER DEFAULT 0;
  END IF;
END $$;

-- ─── 5. Create update_vote_counts() RPC ────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.update_vote_counts(
  p_game_id UUID,
  p_vote_type TEXT DEFAULT 'elimination'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result JSONB;
BEGIN
  -- Get active voting round for this game
  SELECT jsonb_agg(
    jsonb_build_object(
      'target_cast_member_id', ev.voted_for_cast_member_id,
      'display_name', cm.display_name,
      'vote_count', ev.cnt,
      'percentage', ROUND((ev.cnt::NUMERIC / NULLIF(ev.total, 0)) * 100, 1)
    )
  )
  INTO result
  FROM (
    SELECT
      voted_for_cast_member_id,
      COUNT(*) AS cnt,
      SUM(COUNT(*)) OVER () AS total
    FROM mm_elimination_votes
    WHERE round_id IN (
      SELECT id FROM mm_voting_rounds
      WHERE game_id = p_game_id
        AND status = 'active'
    )
    GROUP BY voted_for_cast_member_id
  ) ev
  JOIN cast_members cm ON cm.id = ev.voted_for_cast_member_id;

  RETURN COALESCE(result, '[]'::JSONB);
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_vote_counts TO authenticated;

-- ─── 5b. Add catchphrase column to cast_members (used by queen-selection) ──────
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'cast_members' AND column_name = 'catchphrase') THEN
    ALTER TABLE public.cast_members ADD COLUMN catchphrase TEXT;
  END IF;
END $$;

-- ─── 6. Add missing indexes for cron job performance ───────────────────────────
CREATE INDEX IF NOT EXISTS idx_mm_games_waiting_lobby_ends
  ON public.mm_games(waiting_lobby_ends_at)
  WHERE status = 'waiting_lobby';

CREATE INDEX IF NOT EXISTS idx_mm_games_active_lobby_ends
  ON public.mm_games(active_lobby_ends_at)
  WHERE status = 'active_lobby';

CREATE INDEX IF NOT EXISTS idx_scenarios_status
  ON public.scenarios(status);

-- ─── 7. Auto-update triggers for new tables ────────────────────────────────────
CREATE TRIGGER update_voice_notes_updated_at
  BEFORE UPDATE ON public.voice_notes
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();
