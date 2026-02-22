-- ============================================================================
-- MIGRATION 053: EPISODE TABLES
-- ============================================================================
-- The real-time episode system ported from VR → web.
-- 7 tables for the 7-phase episode engine.
-- All Realtime-enabled for live client updates.
-- ============================================================================

-- ============================================================================
-- 1. ROLE TEMPLATES — 8 secret roles with unique powers
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.episode_role_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  display_name TEXT NOT NULL,
  description TEXT NOT NULL,
  icon TEXT NOT NULL,
  color TEXT NOT NULL,
  ability_name TEXT NOT NULL,
  ability_description TEXT NOT NULL,
  ability_phase TEXT, -- phase when ability activates
  ability_uses INTEGER DEFAULT 1, -- -1 = unlimited
  bonus_condition TEXT,
  bonus_description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 2. PLAYER ROLES — Assigned per player per episode
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.episode_player_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id UUID NOT NULL REFERENCES public.mm_games(id) ON DELETE CASCADE,
  episode_number INTEGER NOT NULL,
  cast_member_id UUID NOT NULL REFERENCES public.cast_members(id) ON DELETE CASCADE,
  role_template_id UUID NOT NULL REFERENCES public.episode_role_templates(id),
  role_name TEXT NOT NULL,
  is_revealed BOOLEAN DEFAULT false,
  revealed_at TIMESTAMPTZ,
  revealed_by TEXT, -- 'self', 'director', 'spy', 'challenge'
  ability_uses_remaining INTEGER DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(game_id, episode_number, cast_member_id)
);

CREATE INDEX IF NOT EXISTS idx_player_roles_game ON episode_player_roles(game_id, episode_number);

-- ============================================================================
-- 3. MISSION TEMPLATES — 8 standard + 3 betrayal
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.episode_mission_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  description TEXT NOT NULL,
  category TEXT NOT NULL CHECK (category IN ('social', 'stealth', 'drama', 'betrayal')),
  difficulty TEXT DEFAULT 'medium' CHECK (difficulty IN ('easy', 'medium', 'hard')),
  phase_available TEXT[], -- which phases this can appear in
  reward_type TEXT, -- drama_points, immunity, power, intel, alliance_shield
  reward_value JSONB,
  drama_on_complete INTEGER DEFAULT 10,
  drama_on_fail INTEGER DEFAULT 5,
  duration_secs INTEGER DEFAULT 180,
  is_betrayal BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 4. PLAYER MISSIONS — Assigned per player per episode
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.episode_missions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id UUID NOT NULL REFERENCES public.mm_games(id) ON DELETE CASCADE,
  episode_number INTEGER NOT NULL,
  cast_member_id UUID NOT NULL REFERENCES public.cast_members(id) ON DELETE CASCADE,
  mission_template_id UUID NOT NULL REFERENCES public.episode_mission_templates(id),
  target_cast_id UUID REFERENCES public.cast_members(id), -- some missions target a player
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'completed', 'failed', 'expired')),
  progress JSONB DEFAULT '{}',
  assigned_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_ep_missions_game ON episode_missions(game_id, episode_number);
CREATE INDEX IF NOT EXISTS idx_ep_missions_player ON episode_missions(cast_member_id, status);

-- ============================================================================
-- 5. CHALLENGE TEMPLATES — 6 group challenges
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.episode_challenge_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  display_name TEXT NOT NULL,
  description TEXT NOT NULL,
  icon TEXT NOT NULL,
  challenge_type TEXT NOT NULL,
  duration_secs INTEGER DEFAULT 300,
  reward_type TEXT NOT NULL,
  reward_description TEXT NOT NULL,
  min_players INTEGER DEFAULT 3,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 6. EPISODE CHALLENGES — Active challenge instances
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.episode_challenges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id UUID NOT NULL REFERENCES public.mm_games(id) ON DELETE CASCADE,
  episode_number INTEGER NOT NULL,
  challenge_template_id UUID NOT NULL REFERENCES public.episode_challenge_templates(id),
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'completed', 'cancelled')),
  winner_cast_id UUID REFERENCES public.cast_members(id),
  reward_granted TEXT,
  participants JSONB DEFAULT '[]', -- array of cast_member_ids
  results JSONB DEFAULT '{}',
  started_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_ep_challenges_game ON episode_challenges(game_id, episode_number);

-- ============================================================================
-- 7. EPISODE SECRETS — Queue for Confrontation reveals
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.episode_secrets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id UUID NOT NULL REFERENCES public.mm_games(id) ON DELETE CASCADE,
  episode_number INTEGER NOT NULL,
  secret_type TEXT NOT NULL CHECK (secret_type IN (
    'alliance_betrayal', 'secret_vote', 'hidden_alliance',
    'mission_failure', 'role_hint', 'director_intel'
  )),
  content TEXT NOT NULL, -- The secret text revealed by Director
  about_cast_id UUID REFERENCES public.cast_members(id), -- Who the secret is about
  is_revealed BOOLEAN DEFAULT false,
  revealed_at TIMESTAMPTZ,
  drama_impact INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ep_secrets_game ON episode_secrets(game_id, episode_number);

-- ============================================================================
-- 8. EPISODE POWERS — Active powers held by players
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.episode_powers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id UUID NOT NULL REFERENCES public.mm_games(id) ON DELETE CASCADE,
  episode_number INTEGER NOT NULL,
  cast_member_id UUID NOT NULL REFERENCES public.cast_members(id) ON DELETE CASCADE,
  power_type TEXT NOT NULL CHECK (power_type IN (
    'double_vote', 'spy', 'veto', 'immunity_grant',
    'secret_reveal', 'alliance_shield', 'steal_power'
  )),
  source TEXT NOT NULL, -- 'role', 'challenge', 'mission', 'random_event'
  is_used BOOLEAN DEFAULT false,
  used_at TIMESTAMPTZ,
  target_cast_id UUID REFERENCES public.cast_members(id), -- who it was used on
  expires_episode INTEGER, -- episode number when power expires
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ep_powers_player ON episode_powers(cast_member_id, is_used);

-- ============================================================================
-- 9. EPISODE FIGHTS — Confrontation log with strike tracking
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.episode_fights (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id UUID NOT NULL REFERENCES public.mm_games(id) ON DELETE CASCADE,
  episode_number INTEGER NOT NULL,
  initiator_id UUID NOT NULL REFERENCES public.cast_members(id),
  target_id UUID NOT NULL REFERENCES public.cast_members(id),
  fight_type TEXT NOT NULL CHECK (fight_type IN (
    'shove', 'table_flip', 'drink_throw',
    'champagne_splash', 'hallway_slam', 'confession_eruption'
  )),
  phase TEXT NOT NULL,
  outcome TEXT NOT NULL CHECK (outcome IN ('completed', 'walked_away', 'one_sided')),
  initiator_score INTEGER DEFAULT 0,
  target_score INTEGER DEFAULT 0,
  duration_secs DECIMAL(4,1) DEFAULT 10.0,
  initiator_strike_after INTEGER,
  target_strike_after INTEGER,
  auto_eliminated_id UUID REFERENCES public.cast_members(id),
  drama_generated INTEGER DEFAULT 0,
  spectator_reactions INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ep_fights_game ON episode_fights(game_id, episode_number);

-- ============================================================================
-- 10. DIRECTOR LOG — Real-time Director broadcasts
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.episode_director_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id UUID NOT NULL REFERENCES public.mm_games(id) ON DELETE CASCADE,
  episode_number INTEGER NOT NULL,
  message_type TEXT NOT NULL CHECK (message_type IN (
    'announce', 'whisper', 'reveal', 'challenge',
    'elimination', 'coronation', 'commentary', 'phase_intro'
  )),
  content TEXT NOT NULL,
  target_cast_id UUID REFERENCES public.cast_members(id), -- for whispers
  phase TEXT,
  is_ai_generated BOOLEAN DEFAULT false,
  drama_impact INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ep_director_game ON episode_director_log(game_id, created_at DESC);

-- ============================================================================
-- 11. ADD EPISODE COLUMNS TO mm_games
-- ============================================================================
ALTER TABLE public.mm_games
  ADD COLUMN IF NOT EXISTS episode_number INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS drama_level INTEGER DEFAULT 0 CHECK (drama_level >= 0 AND drama_level <= 100);

-- ============================================================================
-- 12. ADD EPISODE COLUMNS TO mm_game_cast
-- ============================================================================
ALTER TABLE public.mm_game_cast
  ADD COLUMN IF NOT EXISTS secret_role TEXT,
  ADD COLUMN IF NOT EXISTS role_revealed BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS strike_count INTEGER DEFAULT 0 CHECK (strike_count >= 0 AND strike_count <= 2),
  ADD COLUMN IF NOT EXISTS fights_initiated INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS drama_points INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS immunity BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS has_power TEXT,
  ADD COLUMN IF NOT EXISTS missions_completed INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS eliminated_by TEXT;

-- ============================================================================
-- 13. EXPAND mm_game_stages stage_type for 7 episode phases
-- ============================================================================
ALTER TABLE public.mm_game_stages DROP CONSTRAINT IF EXISTS mm_game_stages_stage_type_check;
ALTER TABLE public.mm_game_stages ADD CONSTRAINT mm_game_stages_stage_type_check
  CHECK (stage_type IN (
    'waiting_lobby', 'active_lobby', 'gameplay', 'voting', 'elimination',
    -- New episode phases:
    'arrival', 'social', 'challenge', 'whisper', 'confrontation', 'deliberation'
  ));

-- ============================================================================
-- 14. RLS POLICIES
-- ============================================================================
ALTER TABLE episode_role_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE episode_player_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE episode_mission_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE episode_missions ENABLE ROW LEVEL SECURITY;
ALTER TABLE episode_challenge_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE episode_challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE episode_secrets ENABLE ROW LEVEL SECURITY;
ALTER TABLE episode_powers ENABLE ROW LEVEL SECURITY;
ALTER TABLE episode_fights ENABLE ROW LEVEL SECURITY;
ALTER TABLE episode_director_log ENABLE ROW LEVEL SECURITY;

-- Templates: public read
CREATE POLICY "Role templates public read" ON episode_role_templates FOR SELECT USING (true);
CREATE POLICY "Mission templates public read" ON episode_mission_templates FOR SELECT USING (true);
CREATE POLICY "Challenge templates public read" ON episode_challenge_templates FOR SELECT USING (true);

-- Game data: authenticated read, service write
CREATE POLICY "Player roles read" ON episode_player_roles FOR SELECT USING (true);
CREATE POLICY "Player roles service write" ON episode_player_roles FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Player roles auth insert" ON episode_player_roles FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Missions read" ON episode_missions FOR SELECT USING (true);
CREATE POLICY "Missions service write" ON episode_missions FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Missions auth insert" ON episode_missions FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Challenges read" ON episode_challenges FOR SELECT USING (true);
CREATE POLICY "Challenges service write" ON episode_challenges FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Secrets read" ON episode_secrets FOR SELECT USING (true);
CREATE POLICY "Secrets service write" ON episode_secrets FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Powers read" ON episode_powers FOR SELECT USING (true);
CREATE POLICY "Powers service write" ON episode_powers FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Powers auth update" ON episode_powers FOR UPDATE USING (auth.role() = 'authenticated');

CREATE POLICY "Fights read" ON episode_fights FOR SELECT USING (true);
CREATE POLICY "Fights service write" ON episode_fights FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Fights auth insert" ON episode_fights FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Director log read" ON episode_director_log FOR SELECT USING (true);
CREATE POLICY "Director log service write" ON episode_director_log FOR ALL USING (auth.role() = 'service_role');

-- ============================================================================
-- 15. REALTIME — Enable for live game tables
-- ============================================================================
DO $$
DECLARE
  tbl TEXT;
BEGIN
  FOREACH tbl IN ARRAY ARRAY[
    'episode_player_roles', 'episode_missions', 'episode_challenges',
    'episode_secrets', 'episode_powers', 'episode_fights', 'episode_director_log'
  ] LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime' AND tablename = tbl
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE %I', tbl);
    END IF;
  END LOOP;
END $$;

-- ============================================================================
-- 16. SEED: Role Templates (8 secret roles)
-- ============================================================================
INSERT INTO episode_role_templates (name, display_name, description, icon, color, ability_name, ability_description, ability_phase, ability_uses, bonus_condition, bonus_description) VALUES
('instigator', 'The Instigator', 'You thrive on chaos. Start drama, watch the fallout.', '🔥', '#E94560',
 'Rumor Bomb', 'Send a fake Director whisper to one player anonymously.', 'social', 2,
 'Start 3+ fights in one game', 'Double drama points if the most dramatic player survives'),
('protector', 'The Protector', 'You keep your people safe. One veto can change everything.', '🛡️', '#4CAF50',
 'Veto Vote', 'Cancel all votes against one player during elimination.', 'elimination', 1,
 'Your vetoed player survives to finale', 'Crown bonus even if eliminated'),
('spy', 'The Spy', 'Information is power. You see what others cannot.', '👁️', '#00BCD4',
 'Intel Sweep', 'See who everyone voted for before votes are revealed.', 'deliberation', 2,
 'Correctly predict eliminated player 3 times', 'Earn immunity for one round'),
('saboteur', 'The Saboteur', 'The one everyone trusts is the most dangerous.', '💣', '#9C27B0',
 'Mission Hijack', 'Cause another player''s mission to fail automatically.', 'social', 2,
 'Most-trusted player gets eliminated', 'Triple drama if top-allied player is eliminated'),
('diplomat', 'The Diplomat', 'Alliances are your weapon. Build the strongest coalition.', '🤝', '#2196F3',
 'Alliance Shield', 'Protect your alliance from losing drama points for one phase.', 'whisper', 2,
 'No alliance member eliminated for 3 episodes', 'All alliance members earn drama bonus'),
('wildcard', 'The Wildcard', 'Your vote hits twice as hard. But miss, and they know.', '🃏', '#FF9800',
 'Double Down', 'Your vote counts as 2. If target survives, they learn you voted for them.', 'deliberation', -1,
 'Eliminate 2 players with double votes', 'Earn Kingmaker title and crown bonus'),
('ghost', 'The Ghost', 'You see the votes. Then you change yours.', '👻', '#607D8B',
 'Last Word', 'After votes revealed, change your vote to any player.', 'elimination', -1,
 'Change the elimination outcome at least once', 'Immunity next round if your change causes a reversal'),
('socialite', 'The Socialite', 'Connections are currency.', '💎', '#E91E63',
 'Social Map', 'See a graph of who has been whispering to whom this episode.', 'whisper', 3,
 'Form or join the most alliances', 'Crown bonus if you have most alliance connections at finale')
ON CONFLICT (name) DO NOTHING;

-- ============================================================================
-- 17. SEED: Mission Templates (8 standard + 3 betrayal)
-- ============================================================================
INSERT INTO episode_mission_templates (name, description, category, difficulty, phase_available, reward_type, reward_value, drama_on_complete, drama_on_fail, duration_secs, is_betrayal) VALUES
('eavesdropper', 'Listen to 3 conversations without participating. Stay silent.', 'stealth', 'easy', ARRAY['social','whisper'], 'drama_points', '{"points":15}', 10, 5, 240, false),
('alliance_builder', 'Convince 2 players to form an alliance with you within 4 minutes.', 'social', 'medium', ARRAY['social'], 'power', '{"type":"alliance_shield"}', 15, 8, 240, false),
('truth_seeker', 'Get a player to reveal their secret role to you.', 'social', 'hard', ARRAY['social','whisper'], 'intel', '{"type":"role_reveal"}', 20, 5, 300, false),
('rumor_mill', 'Tell 3 different players 3 different "secrets" about someone.', 'drama', 'medium', ARRAY['social','whisper'], 'drama_points', '{"points":25}', 20, 10, 300, false),
('trust_fall', 'Reveal your real role to one player. If they keep quiet for 2 minutes, both get shields.', 'social', 'hard', ARRAY['social'], 'immunity', '{"duration":"1_phase"}', 15, 15, 180, false),
('the_loner', 'Don''t send any messages or join alliances for an entire phase.', 'stealth', 'easy', ARRAY['social','whisper'], 'drama_points', '{"points":10}', 5, 3, 300, false),
('double_agent', 'Join two different alliances in the same episode.', 'drama', 'hard', ARRAY['social'], 'power', '{"type":"double_vote_next"}', 25, 15, 480, false),
('charm_offensive', 'Get the most-voted player to say something positive about you in public chat.', 'social', 'hard', ARRAY['deliberation'], 'immunity', '{"duration":"1_episode"}', 20, 5, 240, false),
('backstab', 'Vote for your strongest ally this round.', 'betrayal', 'medium', ARRAY['whisper','deliberation'], 'power', '{"type":"reveal_role"}', 30, 0, 600, true),
('the_leak', 'Reveal an alliance member''s strategy to a rival alliance.', 'betrayal', 'hard', ARRAY['whisper'], 'drama_points', '{"points":35}', 25, 10, 300, true),
('fake_tears', 'Publicly claim you''re about to be eliminated to gain sympathy.', 'betrayal', 'easy', ARRAY['whisper','deliberation'], 'drama_points', '{"points":20}', 15, 5, 180, true)
ON CONFLICT (name) DO NOTHING;

-- ============================================================================
-- 18. SEED: Challenge Templates (6 group challenges)
-- ============================================================================
INSERT INTO episode_challenge_templates (name, display_name, description, icon, challenge_type, duration_secs, reward_type, reward_description, min_players) VALUES
('truth_circle', 'Truth Circle', 'Director asks a question. Everyone answers. Most honest answer wins.', '⭕', 'truth_circle', 180, 'immunity', 'Winner cannot be voted out this episode.', 3),
('alliance_auction', 'Alliance Auction', 'Bid drama points on powers. Highest bid wins, but spend is public.', '💰', 'alliance_auction', 240, 'steal_power', 'Winner steals one power from any player.', 4),
('the_accusation', 'The Accusation', 'Accuse a player of being AI. Correct = immunity. Wrong = lose 20 points.', '☝️', 'accusation', 120, 'secret_reveal', 'Correct accusation reveals the target.', 3),
('confession_roulette', 'Confession Roulette', 'Director asks increasingly personal questions. First to refuse is out.', '🎰', 'confession_roulette', 300, 'double_vote', 'Winner''s vote counts double next elimination.', 3),
('the_pact', 'The Pact', 'Choose one player for a pact. Both survive = both immune. One eliminated = other loses 30 points.', '🤞', 'the_pact', 120, 'immunity', 'Both pact members gain immunity if both survive.', 4),
('room_race', 'Room Race', 'Director hides a crown (riddle). First to solve it wins.', '👑', 'room_race', 180, 'immunity', 'Winner earns immunity and can whisper one secret.', 3)
ON CONFLICT (name) DO NOTHING;

-- ============================================================================
-- 19. HELPER: Assign roles for an episode
-- ============================================================================
CREATE OR REPLACE FUNCTION public.assign_episode_roles(
  p_game_id UUID,
  p_episode_number INTEGER
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_active_cast UUID[];
  v_roles UUID[];
  v_i INTEGER;
  v_role_id UUID;
  v_role_name TEXT;
  v_assignments JSONB := '[]'::jsonb;
BEGIN
  -- Get active cast members
  SELECT array_agg(cast_member_id) INTO v_active_cast
  FROM mm_game_cast
  WHERE game_id = p_game_id AND status = 'active';

  IF v_active_cast IS NULL OR array_length(v_active_cast, 1) = 0 THEN
    RETURN jsonb_build_object('error', 'No active cast members');
  END IF;

  -- Get all role template IDs, shuffled
  SELECT array_agg(id ORDER BY random()) INTO v_roles
  FROM episode_role_templates;

  -- Assign roles (cycle through if more players than roles)
  FOR v_i IN 1..array_length(v_active_cast, 1) LOOP
    v_role_id := v_roles[((v_i - 1) % array_length(v_roles, 1)) + 1];

    SELECT name INTO v_role_name FROM episode_role_templates WHERE id = v_role_id;

    INSERT INTO episode_player_roles (game_id, episode_number, cast_member_id, role_template_id, role_name)
    VALUES (p_game_id, p_episode_number, v_active_cast[v_i], v_role_id, v_role_name)
    ON CONFLICT (game_id, episode_number, cast_member_id) DO NOTHING;

    -- Also update mm_game_cast for quick lookups
    UPDATE mm_game_cast
    SET secret_role = v_role_name, role_revealed = false
    WHERE game_id = p_game_id AND cast_member_id = v_active_cast[v_i];

    v_assignments := v_assignments || jsonb_build_object('cast_id', v_active_cast[v_i], 'role', v_role_name);
  END LOOP;

  RETURN jsonb_build_object('success', true, 'assignments', v_assignments, 'count', array_length(v_active_cast, 1));
END;
$$;

-- ============================================================================
-- 20. HELPER: Process fight and apply strikes
-- ============================================================================
CREATE OR REPLACE FUNCTION public.process_episode_fight(p_fight_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_fight episode_fights%ROWTYPE;
  v_init_strikes INTEGER;
  v_targ_strikes INTEGER;
  v_auto_elim_id UUID;
  v_auto_elim_name TEXT;
BEGIN
  SELECT * INTO v_fight FROM episode_fights WHERE id = p_fight_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Fight not found');
  END IF;

  IF v_fight.outcome = 'completed' THEN
    -- Both fighters get a strike
    UPDATE mm_game_cast SET strike_count = strike_count + 1, fights_initiated = fights_initiated + 1
    WHERE game_id = v_fight.game_id AND cast_member_id = v_fight.initiator_id
    RETURNING strike_count INTO v_init_strikes;

    UPDATE mm_game_cast SET strike_count = strike_count + 1
    WHERE game_id = v_fight.game_id AND cast_member_id = v_fight.target_id
    RETURNING strike_count INTO v_targ_strikes;

    -- Update fight record
    UPDATE episode_fights
    SET initiator_strike_after = v_init_strikes, target_strike_after = v_targ_strikes
    WHERE id = p_fight_id;

    -- Check auto-elimination (2 strikes)
    IF v_init_strikes >= 2 THEN
      v_auto_elim_id := v_fight.initiator_id;
      UPDATE mm_game_cast SET status = 'eliminated', eliminated_by = 'fight'
      WHERE game_id = v_fight.game_id AND cast_member_id = v_fight.initiator_id;
    ELSIF v_targ_strikes >= 2 THEN
      v_auto_elim_id := v_fight.target_id;
      UPDATE mm_game_cast SET status = 'eliminated', eliminated_by = 'fight'
      WHERE game_id = v_fight.game_id AND cast_member_id = v_fight.target_id;
    END IF;

    IF v_auto_elim_id IS NOT NULL THEN
      UPDATE episode_fights SET auto_eliminated_id = v_auto_elim_id WHERE id = p_fight_id;
      SELECT display_name INTO v_auto_elim_name FROM cast_members WHERE id = v_auto_elim_id;
    END IF;

    -- Update game drama
    UPDATE mm_games SET drama_level = LEAST(100, drama_level + 15) WHERE id = v_fight.game_id;
  ELSIF v_fight.outcome = 'walked_away' THEN
    -- Only initiator gets consequences — drama but no strike
    UPDATE mm_games SET drama_level = LEAST(100, drama_level + 5) WHERE id = v_fight.game_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'initiator_strikes', v_init_strikes,
    'target_strikes', v_targ_strikes,
    'auto_eliminated_id', v_auto_elim_id,
    'auto_eliminated_name', v_auto_elim_name
  );
END;
$$;

-- ============================================================================
-- VERIFICATION
-- ============================================================================
SELECT 'episode_role_templates' AS tbl, count(*) FROM episode_role_templates;
SELECT 'episode_mission_templates' AS tbl, count(*) FROM episode_mission_templates;
SELECT 'episode_challenge_templates' AS tbl, count(*) FROM episode_challenge_templates;
SELECT proname FROM pg_proc WHERE proname IN ('assign_episode_roles', 'process_episode_fight');
