-- ============================================================================
-- MANSION MAYHEM - CLEAN SCHEMA v1.0
-- ============================================================================
-- Single source of truth schema with 21 essential tables
-- Replaces 122 competing SQL files and eliminates legacy bloat
-- Total: ~800 lines (82% reduction from original ~4,500 lines)
-- ============================================================================

-- ============================================================================
-- 1. CAST MEMBERS - AI Characters & Player Configurations
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.cast_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  full_name TEXT NOT NULL,
  display_name TEXT NOT NULL,
  avatar_url TEXT,
  archetype TEXT NOT NULL CHECK (archetype IN ('queen', 'villain', 'wildcard', 'sweetheart', 'strategist', 'comedian')),
  personality_traits TEXT[] DEFAULT '{}',
  backstory TEXT,
  bio TEXT,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'eliminated', 'pending')),
  screen_time_score TEXT NOT NULL DEFAULT 'medium' CHECK (screen_time_score IN ('high', 'medium', 'low')),
  is_ai_player BOOLEAN NOT NULL DEFAULT false,
  ai_personality_config JSONB,

  -- FaceCast Integration (MUST PRESERVE)
  facecast_id UUID,
  cameo_id TEXT,

  -- Metadata
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_cast_members_archetype ON public.cast_members(archetype);
CREATE INDEX idx_cast_members_is_ai ON public.cast_members(is_ai_player);
CREATE INDEX idx_cast_members_status ON public.cast_members(status);
CREATE INDEX idx_cast_members_facecast_id ON public.cast_members(facecast_id) WHERE facecast_id IS NOT NULL;

-- ============================================================================
-- 2. PROFILES - Minimal User Profiles
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL UNIQUE,
  display_name TEXT,
  avatar_url TEXT,
  role TEXT NOT NULL DEFAULT 'player' CHECK (role IN ('player', 'admin', 'super_admin')),

  -- Game stats
  games_played INTEGER DEFAULT 0,
  games_won INTEGER DEFAULT 0,

  -- Metadata
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_profiles_email ON public.profiles(email);
CREATE INDEX idx_profiles_role ON public.profiles(role);

-- ============================================================================
-- 3. MM_GAMES - Game Instances
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.mm_games (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  status TEXT NOT NULL DEFAULT 'recruiting' CHECK (status IN ('recruiting', 'active', 'completed', 'cancelled')),
  max_players INTEGER NOT NULL DEFAULT 20,
  current_players INTEGER NOT NULL DEFAULT 0,

  -- Game timing
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,

  -- Metadata
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_mm_games_status ON public.mm_games(status);

-- ============================================================================
-- 4. MM_GAME_CAST - Cast Members in Games
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.mm_game_cast (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id UUID NOT NULL REFERENCES public.mm_games(id) ON DELETE CASCADE,
  cast_member_id UUID NOT NULL REFERENCES public.cast_members(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  eliminated_at TIMESTAMPTZ,
  placement INTEGER, -- Final placement (1st, 2nd, etc.)

  UNIQUE(game_id, cast_member_id)
);

CREATE INDEX idx_mm_game_cast_game_id ON public.mm_game_cast(game_id);
CREATE INDEX idx_mm_game_cast_cast_member_id ON public.mm_game_cast(cast_member_id);

-- ============================================================================
-- 5. MM_GAME_STAGES - Game Progression Tracking
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.mm_game_stages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id UUID NOT NULL REFERENCES public.mm_games(id) ON DELETE CASCADE,
  stage_name TEXT NOT NULL,
  stage_number INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'completed')),
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE(game_id, stage_number)
);

CREATE INDEX idx_mm_game_stages_game_id ON public.mm_game_stages(game_id);
CREATE INDEX idx_mm_game_stages_status ON public.mm_game_stages(status);

-- ============================================================================
-- 6. SCENARIOS - Scenario Prompts
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.scenarios (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id UUID NOT NULL REFERENCES public.mm_games(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  context_notes TEXT,
  scenario_type TEXT NOT NULL CHECK (scenario_type IN ('alliance', 'conflict', 'strategy', 'personal', 'wildcard')),
  target_archetype TEXT, -- Optional: target specific archetype

  -- Timing
  deadline_at TIMESTAMPTZ,
  closed_at TIMESTAMPTZ,

  -- Response tracking
  responses_received INTEGER DEFAULT 0,
  voice_notes_received INTEGER DEFAULT 0,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_scenarios_game_id ON public.scenarios(game_id);
CREATE INDEX idx_scenarios_deadline_at ON public.scenarios(deadline_at);
CREATE INDEX idx_scenarios_scenario_type ON public.scenarios(scenario_type);

-- ============================================================================
-- 7. SCENARIO_RESPONSES - Player Responses to Scenarios
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.scenario_responses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  scenario_id UUID NOT NULL REFERENCES public.scenarios(id) ON DELETE CASCADE,
  cast_member_id UUID NOT NULL REFERENCES public.cast_members(id) ON DELETE CASCADE,
  response_text TEXT,
  voice_note_url TEXT,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE(scenario_id, cast_member_id)
);

CREATE INDEX idx_scenario_responses_scenario_id ON public.scenario_responses(scenario_id);
CREATE INDEX idx_scenario_responses_cast_member_id ON public.scenario_responses(cast_member_id);

-- ============================================================================
-- 8. MM_LINK_UP_REQUESTS - Alliance Invitations
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.mm_link_up_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id UUID NOT NULL REFERENCES public.mm_games(id) ON DELETE CASCADE,
  from_cast_member_id UUID NOT NULL REFERENCES public.cast_members(id) ON DELETE CASCADE,
  to_cast_member_id UUID NOT NULL REFERENCES public.cast_members(id) ON DELETE CASCADE,
  link_up_type TEXT NOT NULL CHECK (link_up_type IN ('duo', 'trio')),
  message TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined', 'expired')),

  -- For trio requests
  required_accepts INTEGER DEFAULT 1, -- 1 for duo, 2 for trio
  current_accepts INTEGER DEFAULT 0,

  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_mm_link_up_requests_game_id ON public.mm_link_up_requests(game_id);
CREATE INDEX idx_mm_link_up_requests_from_id ON public.mm_link_up_requests(from_cast_member_id);
CREATE INDEX idx_mm_link_up_requests_to_id ON public.mm_link_up_requests(to_cast_member_id);
CREATE INDEX idx_mm_link_up_requests_status ON public.mm_link_up_requests(status);

-- ============================================================================
-- 9. MM_LINK_UP_RESPONSES - Responses to Alliance Invitations
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.mm_link_up_responses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id UUID NOT NULL REFERENCES public.mm_link_up_requests(id) ON DELETE CASCADE,
  cast_member_id UUID NOT NULL REFERENCES public.cast_members(id) ON DELETE CASCADE,
  response TEXT NOT NULL CHECK (response IN ('accept', 'decline')),
  message TEXT,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE(request_id, cast_member_id)
);

CREATE INDEX idx_mm_link_up_responses_request_id ON public.mm_link_up_responses(request_id);
CREATE INDEX idx_mm_link_up_responses_cast_member_id ON public.mm_link_up_responses(cast_member_id);

-- ============================================================================
-- 10. MM_ALLIANCE_ROOMS - Active Alliance Chat Rooms
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.mm_alliance_rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id UUID NOT NULL REFERENCES public.mm_games(id) ON DELETE CASCADE,
  room_name TEXT NOT NULL,
  room_type TEXT NOT NULL CHECK (room_type IN ('duo', 'trio')),
  member_ids UUID[] NOT NULL,

  -- Room status
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'dissolved', 'betrayed')),
  dissolved_at TIMESTAMPTZ,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_mm_alliance_rooms_game_id ON public.mm_alliance_rooms(game_id);
CREATE INDEX idx_mm_alliance_rooms_status ON public.mm_alliance_rooms(status);
CREATE INDEX idx_mm_alliance_rooms_member_ids ON public.mm_alliance_rooms USING GIN(member_ids);

-- ============================================================================
-- 11. MM_ALLIANCE_MESSAGES - Chat Messages in Alliances
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.mm_alliance_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES public.mm_alliance_rooms(id) ON DELETE CASCADE,
  cast_member_id UUID NOT NULL REFERENCES public.cast_members(id) ON DELETE CASCADE,
  message TEXT NOT NULL,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_mm_alliance_messages_room_id ON public.mm_alliance_messages(room_id);
CREATE INDEX idx_mm_alliance_messages_cast_member_id ON public.mm_alliance_messages(cast_member_id);
CREATE INDEX idx_mm_alliance_messages_created_at ON public.mm_alliance_messages(created_at DESC);

-- ============================================================================
-- 12. MM_RELATIONSHIP_EDGES - Player Relationship Scores
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.mm_relationship_edges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id UUID NOT NULL REFERENCES public.mm_games(id) ON DELETE CASCADE,
  cast_member_a_id UUID NOT NULL REFERENCES public.cast_members(id) ON DELETE CASCADE,
  cast_member_b_id UUID NOT NULL REFERENCES public.cast_members(id) ON DELETE CASCADE,

  -- Relationship metrics
  trust_score INTEGER DEFAULT 50 CHECK (trust_score >= 0 AND trust_score <= 100),
  alliance_strength INTEGER DEFAULT 0 CHECK (alliance_strength >= 0 AND alliance_strength <= 100),
  rivalry_level INTEGER DEFAULT 0 CHECK (rivalry_level >= 0 AND rivalry_level <= 100),

  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- CRITICAL: Enforce ordered pairs to prevent duplicates (A-B vs B-A)
  CONSTRAINT ordered_pair CHECK (cast_member_a_id < cast_member_b_id),
  UNIQUE(game_id, cast_member_a_id, cast_member_b_id)
);

CREATE INDEX idx_mm_relationship_edges_game_id ON public.mm_relationship_edges(game_id);
CREATE INDEX idx_mm_relationship_edges_a_id ON public.mm_relationship_edges(cast_member_a_id);
CREATE INDEX idx_mm_relationship_edges_b_id ON public.mm_relationship_edges(cast_member_b_id);

-- ============================================================================
-- 13. MM_GRAPH_SCORES - Relationship Graph Analytics
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.mm_graph_scores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id UUID NOT NULL REFERENCES public.mm_games(id) ON DELETE CASCADE,
  cast_member_id UUID NOT NULL REFERENCES public.cast_members(id) ON DELETE CASCADE,

  -- Network metrics
  centrality_score NUMERIC(5,2) DEFAULT 0.0,
  betweenness_score NUMERIC(5,2) DEFAULT 0.0,
  clustering_coefficient NUMERIC(5,2) DEFAULT 0.0,

  calculated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE(game_id, cast_member_id)
);

CREATE INDEX idx_mm_graph_scores_game_id ON public.mm_graph_scores(game_id);
CREATE INDEX idx_mm_graph_scores_cast_member_id ON public.mm_graph_scores(cast_member_id);

-- ============================================================================
-- 14. MM_VOTING_ROUNDS - Elimination Voting Rounds
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.mm_voting_rounds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id UUID NOT NULL REFERENCES public.mm_games(id) ON DELETE CASCADE,
  round_number INTEGER NOT NULL,
  queen_id UUID REFERENCES public.cast_members(id) ON DELETE SET NULL,

  -- Nominations
  nominee_a_id UUID REFERENCES public.cast_members(id) ON DELETE SET NULL,
  nominee_b_id UUID REFERENCES public.cast_members(id) ON DELETE SET NULL,

  -- Results
  eliminated_id UUID REFERENCES public.cast_members(id) ON DELETE SET NULL,
  votes_for_a INTEGER DEFAULT 0,
  votes_for_b INTEGER DEFAULT 0,

  -- Timing
  voting_opens_at TIMESTAMPTZ NOT NULL,
  voting_closes_at TIMESTAMPTZ NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'completed')),

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE(game_id, round_number)
);

CREATE INDEX idx_mm_voting_rounds_game_id ON public.mm_voting_rounds(game_id);
CREATE INDEX idx_mm_voting_rounds_status ON public.mm_voting_rounds(status);
CREATE INDEX idx_mm_voting_rounds_queen_id ON public.mm_voting_rounds(queen_id);

-- ============================================================================
-- 15. MM_ELIMINATION_VOTES - Individual Votes
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.mm_elimination_votes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  round_id UUID NOT NULL REFERENCES public.mm_voting_rounds(id) ON DELETE CASCADE,
  cast_member_id UUID NOT NULL REFERENCES public.cast_members(id) ON DELETE CASCADE,
  voted_for_id UUID NOT NULL REFERENCES public.cast_members(id) ON DELETE CASCADE,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- One vote per cast member per round
  UNIQUE(round_id, cast_member_id)
);

CREATE INDEX idx_mm_elimination_votes_round_id ON public.mm_elimination_votes(round_id);
CREATE INDEX idx_mm_elimination_votes_cast_member_id ON public.mm_elimination_votes(cast_member_id);
CREATE INDEX idx_mm_elimination_votes_voted_for_id ON public.mm_elimination_votes(voted_for_id);

-- ============================================================================
-- 16. MM_CONFESSION_CARDS - Confession Card Submissions
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.mm_confession_cards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id UUID NOT NULL REFERENCES public.mm_games(id) ON DELETE CASCADE,
  cast_member_id UUID REFERENCES public.cast_members(id) ON DELETE SET NULL, -- Anonymous possible
  confession_text TEXT NOT NULL,
  is_anonymous BOOLEAN DEFAULT true,

  -- Moderation
  is_approved BOOLEAN DEFAULT false,
  approved_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_mm_confession_cards_game_id ON public.mm_confession_cards(game_id);
CREATE INDEX idx_mm_confession_cards_is_approved ON public.mm_confession_cards(is_approved);

-- ============================================================================
-- 17. MM_CONFESSION_REACTIONS - Reactions to Confessions
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.mm_confession_reactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  confession_id UUID NOT NULL REFERENCES public.mm_confession_cards(id) ON DELETE CASCADE,
  cast_member_id UUID NOT NULL REFERENCES public.cast_members(id) ON DELETE CASCADE,
  reaction_type TEXT NOT NULL CHECK (reaction_type IN ('like', 'shocked', 'laugh', 'angry')),

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE(confession_id, cast_member_id)
);

CREATE INDEX idx_mm_confession_reactions_confession_id ON public.mm_confession_reactions(confession_id);
CREATE INDEX idx_mm_confession_reactions_cast_member_id ON public.mm_confession_reactions(cast_member_id);

-- ============================================================================
-- 18. USER_GAME_STATE - User Progress Tracking
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.user_game_state (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  game_id UUID NOT NULL REFERENCES public.mm_games(id) ON DELETE CASCADE,

  -- Progress tracking
  has_completed_onboarding BOOLEAN DEFAULT false,
  current_page TEXT,
  last_active_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE(user_id, game_id)
);

CREATE INDEX idx_user_game_state_user_id ON public.user_game_state(user_id);
CREATE INDEX idx_user_game_state_game_id ON public.user_game_state(game_id);

-- ============================================================================
-- 19. NOTIFICATIONS - In-App Notifications
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  notification_type TEXT NOT NULL,
  title TEXT NOT NULL,
  message TEXT NOT NULL,

  -- Optional link
  link_url TEXT,

  -- Status
  is_read BOOLEAN DEFAULT false,
  read_at TIMESTAMPTZ,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX idx_notifications_is_read ON public.notifications(is_read);
CREATE INDEX idx_notifications_created_at ON public.notifications(created_at DESC);

-- ============================================================================
-- 20. USER_SETTINGS - User Preferences
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.user_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,

  -- Notification preferences
  email_notifications BOOLEAN DEFAULT true,
  push_notifications BOOLEAN DEFAULT true,

  -- Display preferences
  theme TEXT DEFAULT 'dark' CHECK (theme IN ('light', 'dark')),

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE(user_id)
);

CREATE INDEX idx_user_settings_user_id ON public.user_settings(user_id);

-- ============================================================================
-- 21. PAYMENT_TRANSACTIONS - Payment History (Minimal)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.payment_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  amount NUMERIC(10,2) NOT NULL,
  currency TEXT NOT NULL DEFAULT 'USD',
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed', 'refunded')),

  -- Payment processor info
  processor TEXT NOT NULL, -- 'stripe', 'paypal', etc.
  processor_transaction_id TEXT,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_payment_transactions_user_id ON public.payment_transactions(user_id);
CREATE INDEX idx_payment_transactions_status ON public.payment_transactions(status);

-- ============================================================================
-- TRIGGERS - Auto-update timestamps
-- ============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to tables with updated_at
CREATE TRIGGER update_cast_members_updated_at
  BEFORE UPDATE ON public.cast_members
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_mm_games_updated_at
  BEFORE UPDATE ON public.mm_games
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_mm_link_up_requests_updated_at
  BEFORE UPDATE ON public.mm_link_up_requests
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_mm_alliance_rooms_updated_at
  BEFORE UPDATE ON public.mm_alliance_rooms
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_game_state_updated_at
  BEFORE UPDATE ON public.user_game_state
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_settings_updated_at
  BEFORE UPDATE ON public.user_settings
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- VERIFICATION
-- ============================================================================
DO $$
DECLARE
  table_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO table_count
  FROM information_schema.tables
  WHERE table_schema = 'public'
  AND table_name IN (
    'cast_members', 'profiles', 'mm_games', 'mm_game_cast', 'mm_game_stages',
    'scenarios', 'scenario_responses', 'mm_link_up_requests', 'mm_link_up_responses',
    'mm_alliance_rooms', 'mm_alliance_messages', 'mm_relationship_edges', 'mm_graph_scores',
    'mm_voting_rounds', 'mm_elimination_votes', 'mm_confession_cards', 'mm_confession_reactions',
    'user_game_state', 'notifications', 'user_settings', 'payment_transactions'
  );

  RAISE NOTICE '✅ Clean Schema Created!';
  RAISE NOTICE 'Tables created: %', table_count;
  RAISE NOTICE 'Schema ready for RLS policies and seed data.';
END $$;
