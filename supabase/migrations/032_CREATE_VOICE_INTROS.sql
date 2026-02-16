-- ============================================================================
-- CREATE mm_voice_intros TABLE and get_lobby_voice_intros RPC
-- Store voice introductions for cast members in games
-- ============================================================================

-- Create table for voice introductions
CREATE TABLE IF NOT EXISTS public.mm_voice_intros (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id UUID NOT NULL REFERENCES public.mm_games(id) ON DELETE CASCADE,
  cast_member_id UUID NOT NULL REFERENCES public.cast_members(id) ON DELETE CASCADE,
  audio_url TEXT NOT NULL,
  duration_seconds INTEGER,
  transcript TEXT,

  submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE(game_id, cast_member_id)
);

CREATE INDEX IF NOT EXISTS idx_mm_voice_intros_game ON public.mm_voice_intros(game_id);
CREATE INDEX IF NOT EXISTS idx_mm_voice_intros_cast ON public.mm_voice_intros(cast_member_id);

-- RLS Policies
ALTER TABLE public.mm_voice_intros ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "voice_intros_select_policy" ON public.mm_voice_intros;
CREATE POLICY "voice_intros_select_policy"
ON public.mm_voice_intros
FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS "voice_intros_insert_policy" ON public.mm_voice_intros;
CREATE POLICY "voice_intros_insert_policy"
ON public.mm_voice_intros
FOR INSERT
TO authenticated
WITH CHECK (
  cast_member_id IN (
    SELECT id FROM cast_members WHERE user_id = auth.uid()
  )
);

-- Create RPC function to get voice intros for a game
CREATE OR REPLACE FUNCTION get_lobby_voice_intros(p_game_id UUID)
RETURNS TABLE (
  id UUID,
  cast_member_id UUID,
  cast_member_name TEXT,
  display_name TEXT,
  avatar_url TEXT,
  archetype TEXT,
  personality_traits TEXT[],
  audio_url TEXT,
  duration_seconds INTEGER,
  transcript TEXT,
  submitted_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    vi.id,
    cm.id as cast_member_id,
    cm.full_name as cast_member_name,
    cm.display_name,
    cm.avatar_url,
    cm.archetype,
    cm.personality_traits,
    vi.audio_url,
    vi.duration_seconds,
    vi.transcript,
    vi.submitted_at
  FROM mm_voice_intros vi
  JOIN cast_members cm ON vi.cast_member_id = cm.id
  WHERE vi.game_id = p_game_id
  ORDER BY vi.submitted_at ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Success message
DO $$
BEGIN
  RAISE NOTICE '✅ mm_voice_intros table created!';
  RAISE NOTICE '✅ get_lobby_voice_intros() RPC function created!';
  RAISE NOTICE '📍 Voice introductions can now be submitted and viewed';
END $$;
