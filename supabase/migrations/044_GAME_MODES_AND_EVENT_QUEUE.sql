-- ============================================================================
-- MIGRATION 044: GAME MODE TEMPLATES & EVENT QUEUE
-- ============================================================================
-- Replaces 19 fixed-schedule cron jobs with a single event queue + processor.
-- Adds 4 configurable game modes: weekly, blitz, sprint, party.
-- Modeled after ai_action_queue (migration 014).
-- ============================================================================

-- ============================================================================
-- 1. game_mode_templates - Timing configs for each game mode
-- ============================================================================
CREATE TABLE public.game_mode_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mode_name TEXT NOT NULL UNIQUE CHECK (mode_name IN ('weekly', 'blitz', 'sprint', 'party')),
  display_name TEXT NOT NULL,
  description TEXT,
  total_duration_hours INTEGER NOT NULL,
  phases JSONB NOT NULL DEFAULT '[]'::jsonb,
  ai_config JSONB NOT NULL DEFAULT '{}'::jsonb,
  scenario_frequency_minutes INTEGER NOT NULL,
  ai_tea_frequency_minutes INTEGER NOT NULL,
  ai_linkup_frequency_minutes INTEGER NOT NULL,
  ai_director_frequency_minutes INTEGER NOT NULL,
  is_default BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Only one default allowed
CREATE UNIQUE INDEX idx_game_mode_templates_default ON game_mode_templates (is_default) WHERE is_default = true;

-- ============================================================================
-- 2. game_events - Core event queue (replaces all 19 cron jobs)
-- ============================================================================
CREATE TABLE public.game_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id UUID NOT NULL REFERENCES public.mm_games(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL CHECK (event_type IN (
    'scenario_distribute',
    'queen_selection',
    'hot_seat_start',
    'voting_open',
    'voting_close',
    'elimination_announce',
    'ai_director_run',
    'ai_tea_posts',
    'ai_link_ups',
    'ai_agent_process',
    'lobby_check',
    'game_start',
    'game_end',
    'lobby_fill',
    'cleanup',
    'party_round',
    'random_event',
    'party_elimination'
  )),
  status TEXT NOT NULL DEFAULT 'scheduled' CHECK (status IN (
    'scheduled',
    'processing',
    'completed',
    'failed',
    'cancelled'
  )),
  scheduled_for TIMESTAMPTZ NOT NULL,
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  priority INTEGER NOT NULL DEFAULT 5 CHECK (priority BETWEEN 1 AND 10),
  payload JSONB DEFAULT '{}'::jsonb,
  result JSONB,
  error_message TEXT,
  retry_count INTEGER NOT NULL DEFAULT 0,
  max_retries INTEGER NOT NULL DEFAULT 3,
  -- Recurring support
  is_recurring BOOLEAN NOT NULL DEFAULT false,
  recurring_interval INTERVAL,
  -- Event chaining
  parent_event_id UUID REFERENCES public.game_events(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Primary query path: find due events to process
CREATE INDEX idx_game_events_due ON game_events (status, scheduled_for)
  WHERE status = 'scheduled';

-- Per-game event lookup
CREATE INDEX idx_game_events_game ON game_events (game_id, status);

-- Event type filtering
CREATE INDEX idx_game_events_type ON game_events (event_type, status);

-- Scheduled_for for timeline queries
CREATE INDEX idx_game_events_scheduled ON game_events (scheduled_for);

-- ============================================================================
-- 3. game_event_log - Audit trail
-- ============================================================================
CREATE TABLE public.game_event_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id UUID NOT NULL REFERENCES public.mm_games(id) ON DELETE CASCADE,
  event_id UUID REFERENCES public.game_events(id),
  event_type TEXT NOT NULL,
  status TEXT NOT NULL,
  payload JSONB,
  result JSONB,
  error_message TEXT,
  executed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  duration_ms INTEGER
);

CREATE INDEX idx_game_event_log_game ON game_event_log (game_id, executed_at DESC);
CREATE INDEX idx_game_event_log_type ON game_event_log (event_type, executed_at DESC);

-- ============================================================================
-- 4. ALTER mm_games - Add game mode columns
-- ============================================================================
ALTER TABLE public.mm_games
  ADD COLUMN IF NOT EXISTS game_mode TEXT DEFAULT 'weekly'
    CHECK (game_mode IN ('weekly', 'blitz', 'sprint', 'party'));

ALTER TABLE public.mm_games
  ADD COLUMN IF NOT EXISTS mode_template_id UUID REFERENCES public.game_mode_templates(id);

ALTER TABLE public.mm_games
  ADD COLUMN IF NOT EXISTS current_phase TEXT;

ALTER TABLE public.mm_games
  ADD COLUMN IF NOT EXISTS phase_started_at TIMESTAMPTZ;

-- ============================================================================
-- 5. RLS Policies
-- ============================================================================

-- game_mode_templates: public read, admin write
ALTER TABLE public.game_mode_templates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can read game mode templates" ON public.game_mode_templates;
CREATE POLICY "Anyone can read game mode templates"
  ON public.game_mode_templates FOR SELECT
  USING (true);

-- game_events: service role only (processed by backend)
ALTER TABLE public.game_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Service role manages game events" ON public.game_events;
CREATE POLICY "Service role manages game events"
  ON public.game_events FOR ALL
  USING (auth.role() = 'service_role');

DROP POLICY IF EXISTS "Authenticated users can read game events" ON public.game_events;
CREATE POLICY "Authenticated users can read game events"
  ON public.game_events FOR SELECT
  USING (auth.role() = 'authenticated');

-- game_event_log: authenticated read
ALTER TABLE public.game_event_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read event log" ON public.game_event_log;
CREATE POLICY "Authenticated users can read event log"
  ON public.game_event_log FOR SELECT
  USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Service role manages event log" ON public.game_event_log;
CREATE POLICY "Service role manages event log"
  ON public.game_event_log FOR ALL
  USING (auth.role() = 'service_role');

-- ============================================================================
-- 6. Seed 3 Game Mode Templates
-- ============================================================================

-- WEEKLY MODE (current behavior, 10-week season)
INSERT INTO public.game_mode_templates (
  mode_name, display_name, description,
  total_duration_hours, phases, ai_config,
  scenario_frequency_minutes, ai_tea_frequency_minutes,
  ai_linkup_frequency_minutes, ai_director_frequency_minutes,
  is_default
) VALUES (
  'weekly',
  'Weekly Season',
  'The classic 10-week Mansion Mayhem experience. One elimination per week, alliances form and shatter over time. The full drama arc.',
  1680, -- 70 days = 10 weeks
  '[
    {"name": "lobby", "duration_hours": 48, "events": ["lobby_fill", "lobby_check"]},
    {"name": "gameplay_week_1", "duration_hours": 168, "events": ["scenario_distribute", "queen_selection", "hot_seat_start", "voting_open", "voting_close", "elimination_announce"]},
    {"name": "gameplay_week_2", "duration_hours": 168, "events": ["scenario_distribute", "queen_selection", "hot_seat_start", "voting_open", "voting_close", "elimination_announce"]},
    {"name": "gameplay_week_3", "duration_hours": 168, "events": ["scenario_distribute", "queen_selection", "hot_seat_start", "voting_open", "voting_close", "elimination_announce"]},
    {"name": "gameplay_week_4", "duration_hours": 168, "events": ["scenario_distribute", "queen_selection", "hot_seat_start", "voting_open", "voting_close", "elimination_announce"]},
    {"name": "gameplay_week_5", "duration_hours": 168, "events": ["scenario_distribute", "queen_selection", "hot_seat_start", "voting_open", "voting_close", "elimination_announce"]},
    {"name": "gameplay_week_6", "duration_hours": 168, "events": ["scenario_distribute", "queen_selection", "hot_seat_start", "voting_open", "voting_close", "elimination_announce"]},
    {"name": "gameplay_week_7", "duration_hours": 168, "events": ["scenario_distribute", "queen_selection", "hot_seat_start", "voting_open", "voting_close", "elimination_announce"]},
    {"name": "gameplay_week_8", "duration_hours": 168, "events": ["scenario_distribute", "queen_selection", "hot_seat_start", "voting_open", "voting_close", "elimination_announce"]},
    {"name": "gameplay_week_9", "duration_hours": 168, "events": ["scenario_distribute", "queen_selection", "hot_seat_start", "voting_open", "voting_close", "elimination_announce"]},
    {"name": "gameplay_week_10", "duration_hours": 168, "events": ["scenario_distribute", "queen_selection", "hot_seat_start", "voting_open", "voting_close", "elimination_announce"]},
    {"name": "finale", "duration_hours": 0, "events": ["game_end"]}
  ]'::jsonb,
  '{"priority_boost": 0, "batch_size": 10}'::jsonb,
  1440, -- scenarios every 24hr
  120,  -- tea posts every 2hr
  60,   -- link-ups every 1hr
  360,  -- director 4x/day (every 6hr)
  true  -- default mode
);

-- BLITZ MODE (24hr game night, 3-act structure)
INSERT INTO public.game_mode_templates (
  mode_name, display_name, description,
  total_duration_hours, phases, ai_config,
  scenario_frequency_minutes, ai_tea_frequency_minutes,
  ai_linkup_frequency_minutes, ai_director_frequency_minutes,
  is_default
) VALUES (
  'blitz',
  'Blitz Night',
  'A 24-hour game night experience. Three intense acts: Alliance Hour, Betrayal Hour, and Final Hour. Maximum drama in minimum time.',
  24,
  '[
    {"name": "act_1_alliance_hour", "duration_hours": 4, "label": "Act 1: Alliance Hour", "events": ["lobby_fill", "game_start", "scenario_distribute", "queen_selection", "ai_tea_posts", "ai_link_ups"]},
    {"name": "act_2_betrayal_hour", "duration_hours": 8, "label": "Act 2: Betrayal Hour", "events": ["scenario_distribute", "hot_seat_start", "voting_open", "ai_tea_posts", "ai_link_ups", "ai_director_run"]},
    {"name": "act_3_final_hour", "duration_hours": 12, "label": "Act 3: Final Hour", "events": ["voting_close", "elimination_announce", "scenario_distribute", "voting_open", "voting_close", "game_end"]}
  ]'::jsonb,
  '{"priority_boost": 3, "batch_size": 20, "fast_mode": true}'::jsonb,
  60,  -- scenarios every 1hr
  15,  -- tea posts every 15min
  30,  -- link-ups every 30min
  30,  -- director every 30min
  false
);

-- SPRINT MODE (3-day weekend)
INSERT INTO public.game_mode_templates (
  mode_name, display_name, description,
  total_duration_hours, phases, ai_config,
  scenario_frequency_minutes, ai_tea_frequency_minutes,
  ai_linkup_frequency_minutes, ai_director_frequency_minutes,
  is_default
) VALUES (
  'sprint',
  'Weekend Sprint',
  'A 3-day weekend tournament. Day 1: alliances form. Day 2: the hot seat heats up. Day 3: one winner takes all.',
  72,
  '[
    {"name": "day_1_alliances", "duration_hours": 24, "label": "Day 1: Alliance Day", "events": ["lobby_fill", "game_start", "scenario_distribute", "queen_selection", "ai_tea_posts", "ai_link_ups"]},
    {"name": "day_2_hotseat", "duration_hours": 24, "label": "Day 2: Hot Seat Day", "events": ["scenario_distribute", "hot_seat_start", "voting_open", "voting_close", "elimination_announce", "queen_selection"]},
    {"name": "day_3_finale", "duration_hours": 24, "label": "Day 3: Finale Day", "events": ["scenario_distribute", "voting_open", "voting_close", "elimination_announce", "game_end"]}
  ]'::jsonb,
  '{"priority_boost": 1, "batch_size": 15, "fast_mode": false}'::jsonb,
  240, -- scenarios every 4hr
  60,  -- tea posts every 1hr
  60,  -- link-ups every 1hr
  120, -- director every 2hr
  false
);

-- ============================================================================
-- 7. party_leaderboard - Real-time scoring for Party Mode
-- ============================================================================
CREATE TABLE public.party_leaderboard (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id UUID NOT NULL REFERENCES public.mm_games(id) ON DELETE CASCADE,
  cast_member_id UUID NOT NULL REFERENCES public.cast_members(id),
  -- Scoring breakdown
  alliance_points INTEGER NOT NULL DEFAULT 0,
  drama_score INTEGER NOT NULL DEFAULT 0,
  scenario_points INTEGER NOT NULL DEFAULT 0,
  event_wins INTEGER NOT NULL DEFAULT 0,
  voice_note_points INTEGER NOT NULL DEFAULT 0,
  tea_room_points INTEGER NOT NULL DEFAULT 0,
  survival_points INTEGER NOT NULL DEFAULT 0,
  queen_points INTEGER NOT NULL DEFAULT 0,
  -- Computed total
  total_score INTEGER GENERATED ALWAYS AS (
    alliance_points + drama_score + scenario_points +
    (event_wins * 5) + voice_note_points + tea_room_points +
    survival_points + queen_points
  ) STORED,
  -- Status
  is_eliminated BOOLEAN NOT NULL DEFAULT false,
  eliminated_in_round INTEGER,
  is_winner BOOLEAN NOT NULL DEFAULT false,
  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  -- One entry per cast member per game
  UNIQUE(game_id, cast_member_id)
);

CREATE INDEX idx_party_leaderboard_game ON party_leaderboard (game_id, total_score DESC);
CREATE INDEX idx_party_leaderboard_active ON party_leaderboard (game_id, is_eliminated, total_score DESC);

-- ============================================================================
-- 8. party_random_events - Random event definitions + tracking
-- ============================================================================
CREATE TABLE public.party_random_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id UUID NOT NULL REFERENCES public.mm_games(id) ON DELETE CASCADE,
  round_number INTEGER NOT NULL,
  event_name TEXT NOT NULL CHECK (event_name IN (
    'spill_or_be_spilled',
    'alliance_auction',
    'the_receipt',
    'immunity_idol',
    'double_or_nothing'
  )),
  display_name TEXT NOT NULL,
  description TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'completed')),
  winner_cast_id UUID REFERENCES public.cast_members(id),
  payload JSONB DEFAULT '{}'::jsonb,
  result JSONB,
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_party_random_events_game ON party_random_events (game_id, round_number);

-- ============================================================================
-- 9. party_score_log - Track individual score changes
-- ============================================================================
CREATE TABLE public.party_score_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id UUID NOT NULL REFERENCES public.mm_games(id) ON DELETE CASCADE,
  cast_member_id UUID NOT NULL REFERENCES public.cast_members(id),
  action TEXT NOT NULL,
  points INTEGER NOT NULL,
  round_number INTEGER,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_party_score_log_game ON party_score_log (game_id, created_at DESC);

-- ============================================================================
-- RLS for party tables
-- ============================================================================
ALTER TABLE public.party_leaderboard ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.party_random_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.party_score_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can read party leaderboard" ON public.party_leaderboard;
CREATE POLICY "Anyone can read party leaderboard"
  ON public.party_leaderboard FOR SELECT USING (true);

DROP POLICY IF EXISTS "Service role manages party leaderboard" ON public.party_leaderboard;
CREATE POLICY "Service role manages party leaderboard"
  ON public.party_leaderboard FOR ALL USING (auth.role() = 'service_role');

DROP POLICY IF EXISTS "Anyone can read party events" ON public.party_random_events;
CREATE POLICY "Anyone can read party events"
  ON public.party_random_events FOR SELECT USING (true);

DROP POLICY IF EXISTS "Service role manages party events" ON public.party_random_events;
CREATE POLICY "Service role manages party events"
  ON public.party_random_events FOR ALL USING (auth.role() = 'service_role');

DROP POLICY IF EXISTS "Anyone can read party score log" ON public.party_score_log;
CREATE POLICY "Anyone can read party score log"
  ON public.party_score_log FOR SELECT USING (true);

DROP POLICY IF EXISTS "Service role manages party score log" ON public.party_score_log;
CREATE POLICY "Service role manages party score log"
  ON public.party_score_log FOR ALL USING (auth.role() = 'service_role');

-- ============================================================================
-- 10. Seed PARTY MODE template (35 min - Fight for the Throne)
-- ============================================================================
INSERT INTO public.game_mode_templates (
  mode_name, display_name, description,
  total_duration_hours, phases, ai_config,
  scenario_frequency_minutes, ai_tea_frequency_minutes,
  ai_linkup_frequency_minutes, ai_director_frequency_minutes,
  is_default
) VALUES (
  'party',
  'Party Mode',
  '35-minute Fight for the Throne. 20 players, 3 eliminated every 5 minutes. Form alliances, start drama, win events. Highest score on the leaderboard wins the crown.',
  1, -- ~35 minutes, rounded to 1 hour for the column
  '[
    {"name": "outside_mansion", "duration_minutes": 5, "label": "Outside the Mansion", "events": ["lobby_fill", "game_start", "ai_link_ups", "ai_tea_posts", "scenario_distribute"]},
    {"name": "round_1", "duration_minutes": 5, "round": 1, "label": "Round 1: First Blood", "events": ["party_round", "queen_selection", "scenario_distribute", "random_event", "voting_open", "voting_close", "party_elimination"]},
    {"name": "round_2", "duration_minutes": 5, "round": 2, "label": "Round 2: The Plot Thickens", "events": ["party_round", "queen_selection", "scenario_distribute", "random_event", "voting_open", "voting_close", "party_elimination"]},
    {"name": "round_3", "duration_minutes": 5, "round": 3, "label": "Round 3: Betrayal Hour", "events": ["party_round", "queen_selection", "scenario_distribute", "random_event", "voting_open", "voting_close", "party_elimination"]},
    {"name": "round_4", "duration_minutes": 5, "round": 4, "label": "Round 4: The Reckoning", "events": ["party_round", "queen_selection", "scenario_distribute", "random_event", "voting_open", "voting_close", "party_elimination"]},
    {"name": "round_5", "duration_minutes": 5, "round": 5, "label": "Round 5: Final Five", "events": ["party_round", "queen_selection", "scenario_distribute", "random_event", "voting_open", "voting_close", "party_elimination"]},
    {"name": "round_6", "duration_minutes": 5, "round": 6, "label": "Round 6: The Throne", "events": ["party_round", "queen_selection", "scenario_distribute", "voting_open", "voting_close", "party_elimination", "game_end"]}
  ]'::jsonb,
  '{"priority_boost": 5, "batch_size": 20, "fast_mode": true, "haiku_only": true, "response_timeout_seconds": 10}'::jsonb,
  5,  -- scenario every 5 min (each round)
  2,  -- tea posts every 2 min
  2,  -- link-ups every 2 min
  5,  -- director every round
  false
);

-- ============================================================================
-- VERIFICATION
-- ============================================================================
-- Check tables exist
SELECT 'game_mode_templates' AS tbl, count(*) FROM game_mode_templates;
SELECT 'game_events' AS tbl, count(*) FROM game_events;
SELECT 'game_event_log' AS tbl, count(*) FROM game_event_log;
SELECT 'party_leaderboard' AS tbl, count(*) FROM party_leaderboard;
SELECT 'party_random_events' AS tbl, count(*) FROM party_random_events;
SELECT 'party_score_log' AS tbl, count(*) FROM party_score_log;

-- Check mm_games columns added
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'mm_games'
  AND column_name IN ('game_mode', 'mode_template_id', 'current_phase', 'phase_started_at');

-- Check templates seeded
SELECT mode_name, display_name, total_duration_hours, is_default FROM game_mode_templates;

-- Done
-- ============================================================================
