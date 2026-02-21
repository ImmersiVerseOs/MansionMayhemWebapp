-- ============================================================================
-- 048: AGENT TELEMETRY & NORTH STAR AUTONOMY MONITORING
-- ============================================================================
-- Hourly health checks for ALL agents across the ImmersiVerse OS stack.
-- North Star: Full autonomy over Mansion Mayhem, CastLoop, FaceCast,
-- Premier Channel, Theater, AI Artist, Showrunners, Show/Game Creators.
--
-- Every agent reports heartbeats. Every hour we check:
-- 1. Is each agent alive? (heartbeat within expected interval)
-- 2. Is each agent productive? (actions completed vs failed)
-- 3. Is each agent aligned? (north star score: drama, engagement, content)
-- 4. Is the overall system autonomous? (no human intervention needed)
-- ============================================================================

-- ============================================================================
-- 1. AGENT REGISTRY - All agents in the ImmersiVerse ecosystem
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.agent_registry (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_name TEXT NOT NULL UNIQUE,
  agent_type TEXT NOT NULL CHECK (agent_type IN (
    'director',         -- AI Director (scenario generation, game orchestration)
    'processor',        -- AI Agent Processor (action queue execution)
    'decision_maker',   -- AI Decision Processor (votes, alliances)
    'event_engine',     -- Game Event Processor (event queue)
    'content_creator',  -- AI Artist, UI Generator, Scenario Creator
    'showrunner',       -- Showrunner (episode compilation, narrative arc)
    'cast_manager',     -- CastLoop (casting, auditions, profiles)
    'channel_manager',  -- Premier Channel (streaming, scheduling)
    'game_creator',     -- Game Creator (new game type generation)
    'infrastructure'    -- System-level (cleanup, health, monitoring)
  )),

  -- Which layer of ImmersiVerse OS
  platform_layer TEXT NOT NULL DEFAULT 'mansion_mayhem' CHECK (platform_layer IN (
    'mansion_mayhem',   -- Core game
    'castloop',         -- Casting & talent management
    'facecast',         -- Face/avatar generation
    'premier_channel',  -- Content distribution
    'theater',          -- Live experience
    'immersiverse_os'   -- Platform-level
  )),

  description TEXT,

  -- Expected behavior
  expected_heartbeat_interval INTERVAL NOT NULL DEFAULT '15 minutes',
  expected_actions_per_hour INTEGER DEFAULT 1,

  -- Edge function or cron that powers this agent
  implementation_type TEXT CHECK (implementation_type IN ('edge_function', 'cron_job', 'rpc_function', 'realtime_trigger')),
  implementation_ref TEXT, -- e.g., 'ai-director', 'process_game_events'

  -- Status
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- 2. AGENT HEARTBEATS - Real-time "I'm alive" signals
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.agent_heartbeats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_id UUID NOT NULL REFERENCES public.agent_registry(id) ON DELETE CASCADE,
  game_id UUID REFERENCES public.mm_games(id) ON DELETE CASCADE, -- NULL for platform-level agents

  -- What the agent did
  action_summary TEXT,
  items_processed INTEGER DEFAULT 0,
  items_failed INTEGER DEFAULT 0,

  -- Performance
  processing_time_ms INTEGER,

  -- Context
  metadata JSONB DEFAULT '{}',

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_agent_heartbeats_agent ON public.agent_heartbeats(agent_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_agent_heartbeats_game ON public.agent_heartbeats(game_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_agent_heartbeats_recent ON public.agent_heartbeats(created_at DESC);

-- ============================================================================
-- 3. AGENT HEALTH CHECKS - Hourly snapshots of system health
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.agent_health_checks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  check_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Per-agent results stored as JSONB array
  agent_statuses JSONB NOT NULL DEFAULT '[]',
  -- Format: [{ agent_name, status (healthy/degraded/dead/idle), last_heartbeat,
  --            actions_last_hour, failures_last_hour, avg_processing_ms }]

  -- Overall system health
  total_agents INTEGER NOT NULL DEFAULT 0,
  healthy_count INTEGER NOT NULL DEFAULT 0,
  degraded_count INTEGER NOT NULL DEFAULT 0,
  dead_count INTEGER NOT NULL DEFAULT 0,
  idle_count INTEGER NOT NULL DEFAULT 0,

  -- System health score (0-100)
  system_health_score INTEGER NOT NULL DEFAULT 0,

  -- Active games being monitored
  active_games_count INTEGER DEFAULT 0,

  -- Alerts generated
  alerts JSONB DEFAULT '[]',
  -- Format: [{ severity (critical/warning/info), agent_name, message, timestamp }]

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_health_checks_time ON public.agent_health_checks(check_time DESC);

-- ============================================================================
-- 4. NORTH STAR SCORES - Track autonomy alignment per game per hour
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.north_star_scores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id UUID REFERENCES public.mm_games(id) ON DELETE CASCADE,
  check_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Autonomy Pillars (each 0-100)

  -- 1. Drama Engine Autonomy - Is AI creating engaging scenarios without human help?
  drama_autonomy_score INTEGER DEFAULT 0,
  -- Inputs: scenarios created, response rates, drama index, variety

  -- 2. Social Engine Autonomy - Are alliances, tea posts, link-ups happening organically?
  social_autonomy_score INTEGER DEFAULT 0,
  -- Inputs: alliance formation rate, tea post frequency, link-up activity

  -- 3. Content Engine Autonomy - Is content being generated and distributed?
  content_autonomy_score INTEGER DEFAULT 0,
  -- Inputs: voice notes generated, confession videos, UI pages generated

  -- 4. Governance Autonomy - Are votes, eliminations, queen selections running themselves?
  governance_autonomy_score INTEGER DEFAULT 0,
  -- Inputs: voting participation, elimination execution, phase transitions

  -- 5. Cast Management Autonomy - Are AI players behaving like real people?
  cast_autonomy_score INTEGER DEFAULT 0,
  -- Inputs: AI response quality, personality consistency, engagement diversity

  -- Composite North Star Score (weighted average of all pillars)
  north_star_score INTEGER DEFAULT 0,

  -- Breakdown details
  details JSONB DEFAULT '{}',

  -- Trend direction
  trend TEXT CHECK (trend IN ('improving', 'stable', 'declining', 'critical')),

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_north_star_game ON public.north_star_scores(game_id, check_time DESC);
CREATE INDEX IF NOT EXISTS idx_north_star_time ON public.north_star_scores(check_time DESC);

-- ============================================================================
-- 5. SEED AGENT REGISTRY - All current agents
-- ============================================================================
INSERT INTO public.agent_registry (agent_name, agent_type, platform_layer, description, expected_heartbeat_interval, expected_actions_per_hour, implementation_type, implementation_ref) VALUES
  -- Mansion Mayhem Core Agents
  ('ai_director', 'director', 'mansion_mayhem',
   'Generates dramatic scenarios, orchestrates game narrative, manages pacing',
   '6 hours', 1, 'edge_function', 'ai-director'),

  ('ai_agent_processor', 'processor', 'mansion_mayhem',
   'Processes queued AI actions: scenario responses, chat messages, tea posts',
   '5 minutes', 10, 'edge_function', 'ai-agent-processor'),

  ('ai_decision_processor', 'decision_maker', 'mansion_mayhem',
   'Handles alliance decisions, voting logic, link-up responses',
   '30 minutes', 5, 'edge_function', 'ai-decision-processor'),

  ('game_event_processor', 'event_engine', 'mansion_mayhem',
   'Processes scheduled game events: phase transitions, voting, eliminations',
   '2 minutes', 10, 'cron_job', 'process_game_events'),

  ('scenario_generator', 'content_creator', 'mansion_mayhem',
   'Creates scenario content and auto-generates custom UI pages',
   '1 hour', 2, 'edge_function', 'generate-scenario'),

  ('ui_generator', 'content_creator', 'mansion_mayhem',
   'Auto-generates HTML pages for scenarios ($0.027/page)',
   '2 hours', 1, 'edge_function', 'generate-scenario-ui'),

  ('lobby_manager', 'infrastructure', 'mansion_mayhem',
   'Manages lobby lifecycle: AI spawning, player matching, game launch',
   '15 minutes', 2, 'rpc_function', 'spawn_ai_into_lobbies'),

  ('cleanup_agent', 'infrastructure', 'mansion_mayhem',
   'Cleans up abandoned games, old action queue entries, expired data',
   '1 hour', 1, 'cron_job', 'cleanup_ai_action_queue'),

  -- CastLoop Agents
  ('castloop_talent_scout', 'cast_manager', 'castloop',
   'Discovers and profiles new AI cast members, manages auditions',
   '24 hours', 0, 'edge_function', NULL),

  -- FaceCast Agents
  ('facecast_avatar_engine', 'content_creator', 'facecast',
   'Generates and manages AI character avatars and face models',
   '24 hours', 0, 'edge_function', NULL),

  -- Premier Channel Agents
  ('premier_channel_scheduler', 'channel_manager', 'premier_channel',
   'Schedules and distributes content across streaming channels',
   '24 hours', 0, 'edge_function', NULL),

  -- Showrunner Agent
  ('showrunner', 'showrunner', 'mansion_mayhem',
   'Compiles episodes, manages narrative arcs, pacing across weeks',
   '12 hours', 0, 'edge_function', NULL),

  -- Platform Level
  ('system_health_monitor', 'infrastructure', 'immersiverse_os',
   'Hourly telemetry checks across all agents and systems',
   '1 hour', 1, 'cron_job', 'run_agent_health_check')

ON CONFLICT (agent_name) DO NOTHING;

-- ============================================================================
-- 6. RECORD HEARTBEAT FUNCTION - Called by agents to report activity
-- ============================================================================
CREATE OR REPLACE FUNCTION public.record_agent_heartbeat(
  p_agent_name TEXT,
  p_game_id UUID DEFAULT NULL,
  p_action_summary TEXT DEFAULT NULL,
  p_items_processed INTEGER DEFAULT 0,
  p_items_failed INTEGER DEFAULT 0,
  p_processing_time_ms INTEGER DEFAULT NULL,
  p_metadata JSONB DEFAULT '{}'
)
RETURNS UUID AS $$
DECLARE
  v_agent_id UUID;
  v_heartbeat_id UUID;
BEGIN
  -- Look up agent
  SELECT id INTO v_agent_id
  FROM public.agent_registry
  WHERE agent_name = p_agent_name;

  IF v_agent_id IS NULL THEN
    RAISE WARNING 'Unknown agent: %. Registering as infrastructure.', p_agent_name;
    INSERT INTO public.agent_registry (agent_name, agent_type, platform_layer, description)
    VALUES (p_agent_name, 'infrastructure', 'immersiverse_os', 'Auto-registered agent')
    RETURNING id INTO v_agent_id;
  END IF;

  -- Record heartbeat
  INSERT INTO public.agent_heartbeats (
    agent_id, game_id, action_summary,
    items_processed, items_failed, processing_time_ms, metadata
  ) VALUES (
    v_agent_id, p_game_id, p_action_summary,
    p_items_processed, p_items_failed, p_processing_time_ms, p_metadata
  ) RETURNING id INTO v_heartbeat_id;

  -- Update agent last activity
  UPDATE public.agent_registry
  SET updated_at = NOW()
  WHERE id = v_agent_id;

  RETURN v_heartbeat_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.record_agent_heartbeat(TEXT, UUID, TEXT, INTEGER, INTEGER, INTEGER, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_agent_heartbeat(TEXT, UUID, TEXT, INTEGER, INTEGER, INTEGER, JSONB) TO service_role;

-- ============================================================================
-- 7. CALCULATE NORTH STAR SCORE - Per game autonomy measurement
-- ============================================================================
CREATE OR REPLACE FUNCTION public.calculate_north_star_score(p_game_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_drama_score INTEGER := 0;
  v_social_score INTEGER := 0;
  v_content_score INTEGER := 0;
  v_governance_score INTEGER := 0;
  v_cast_score INTEGER := 0;
  v_north_star INTEGER := 0;
  v_details JSONB := '{}';
  v_trend TEXT := 'stable';
  v_prev_score INTEGER;

  -- Counters
  v_scenarios_24h INTEGER;
  v_scenario_response_rate NUMERIC;
  v_drama_index INTEGER;
  v_tea_posts_24h INTEGER;
  v_alliance_count INTEGER;
  v_linkup_count_24h INTEGER;
  v_voice_notes_24h INTEGER;
  v_voting_participation NUMERIC;
  v_ai_actions_completed_24h INTEGER;
  v_ai_actions_failed_24h INTEGER;
  v_active_cast INTEGER;
  v_ai_cast INTEGER;
BEGIN
  -- ============================
  -- PILLAR 1: Drama Engine (25%)
  -- ============================

  -- Scenarios created in last 24h
  SELECT COUNT(*) INTO v_scenarios_24h
  FROM scenarios
  WHERE game_id = p_game_id
    AND created_at > NOW() - INTERVAL '24 hours';

  -- Average response rate for recent scenarios
  SELECT COALESCE(AVG(
    CASE WHEN assigned_count > 0
    THEN (responses_received::NUMERIC / assigned_count) * 100
    ELSE 0 END
  ), 0) INTO v_scenario_response_rate
  FROM scenarios
  WHERE game_id = p_game_id
    AND created_at > NOW() - INTERVAL '72 hours';

  -- Drama index
  BEGIN
    SELECT public.calculate_drama_index(p_game_id) INTO v_drama_index;
  EXCEPTION WHEN OTHERS THEN
    v_drama_index := 50; -- Default if function doesn't exist yet
  END;

  -- Score: scenarios happening (40pts) + high response rate (30pts) + healthy drama (30pts)
  v_drama_score := LEAST(100,
    LEAST(40, v_scenarios_24h * 20) +                    -- 2+ scenarios = full marks
    LEAST(30, (v_scenario_response_rate * 0.3)::INTEGER) + -- 100% response = 30pts
    LEAST(30, CASE
      WHEN v_drama_index BETWEEN 30 AND 80 THEN 30       -- Healthy range = full marks
      WHEN v_drama_index BETWEEN 15 AND 90 THEN 20       -- Acceptable range
      ELSE 10                                              -- Too low or too high
    END)
  );

  -- ============================
  -- PILLAR 2: Social Engine (20%)
  -- ============================

  -- Tea posts in last 24h
  SELECT COUNT(*) INTO v_tea_posts_24h
  FROM mm_tea_room_posts
  WHERE game_id = p_game_id
    AND created_at > NOW() - INTERVAL '24 hours';

  -- Active alliances
  SELECT COUNT(*) INTO v_alliance_count
  FROM mm_alliance_rooms
  WHERE game_id = p_game_id
    AND status = 'active';

  -- Link-ups in last 24h
  SELECT COUNT(*) INTO v_linkup_count_24h
  FROM mm_link_up_requests
  WHERE game_id = p_game_id
    AND created_at > NOW() - INTERVAL '24 hours';

  v_social_score := LEAST(100,
    LEAST(40, v_tea_posts_24h * 4) +     -- 10+ tea posts = full marks
    LEAST(30, v_alliance_count * 10) +    -- 3+ alliances = full marks
    LEAST(30, v_linkup_count_24h * 6)     -- 5+ link-ups = full marks
  );

  -- ============================
  -- PILLAR 3: Content Engine (20%)
  -- ============================

  -- Voice notes generated in last 24h
  SELECT COUNT(*) INTO v_voice_notes_24h
  FROM scenario_responses
  WHERE game_id = p_game_id
    AND voice_note_url IS NOT NULL
    AND created_at > NOW() - INTERVAL '24 hours';

  v_content_score := LEAST(100,
    LEAST(50, v_voice_notes_24h * 10) +   -- 5+ voice notes = 50pts
    LEAST(50, v_scenarios_24h * 25)        -- 2+ scenarios with content = 50pts
  );

  -- ============================
  -- PILLAR 4: Governance (15%)
  -- ============================

  -- Check if voting rounds are completing
  SELECT COALESCE(AVG(
    CASE WHEN status = 'completed' THEN 100 ELSE 0 END
  ), 0) INTO v_voting_participation
  FROM mm_voting_rounds
  WHERE game_id = p_game_id
    AND created_at > NOW() - INTERVAL '7 days';

  v_governance_score := LEAST(100, v_voting_participation::INTEGER);

  -- ============================
  -- PILLAR 5: Cast Autonomy (20%)
  -- ============================

  -- AI actions completed vs failed in last 24h
  SELECT
    COUNT(*) FILTER (WHERE status = 'completed'),
    COUNT(*) FILTER (WHERE status = 'failed')
  INTO v_ai_actions_completed_24h, v_ai_actions_failed_24h
  FROM ai_action_queue
  WHERE game_id = p_game_id
    AND created_at > NOW() - INTERVAL '24 hours';

  -- Active cast count
  SELECT COUNT(*) INTO v_active_cast
  FROM mm_game_cast
  WHERE game_id = p_game_id
    AND status IN ('active', 'joined');

  -- AI cast count
  SELECT COUNT(*) INTO v_ai_cast
  FROM mm_game_cast gc
  JOIN cast_members cm ON cm.id = gc.cast_member_id
  WHERE gc.game_id = p_game_id
    AND gc.status IN ('active', 'joined')
    AND cm.is_ai_player = true;

  v_cast_score := LEAST(100,
    -- AI action success rate (50pts)
    CASE WHEN (v_ai_actions_completed_24h + v_ai_actions_failed_24h) > 0
      THEN LEAST(50, ((v_ai_actions_completed_24h::NUMERIC /
            GREATEST(1, v_ai_actions_completed_24h + v_ai_actions_failed_24h)) * 50)::INTEGER)
      ELSE 25 -- No actions = neutral (might be idle game)
    END +
    -- Cast population (30pts)
    LEAST(30, (v_active_cast * 2)) +
    -- AI presence (20pts)
    LEAST(20, (v_ai_cast * 2))
  );

  -- ============================
  -- COMPOSITE NORTH STAR SCORE
  -- ============================
  -- Weights: Drama 25%, Social 20%, Content 20%, Governance 15%, Cast 20%
  v_north_star := (
    (v_drama_score * 25) +
    (v_social_score * 20) +
    (v_content_score * 20) +
    (v_governance_score * 15) +
    (v_cast_score * 20)
  ) / 100;

  -- Determine trend
  SELECT north_star_score INTO v_prev_score
  FROM public.north_star_scores
  WHERE game_id = p_game_id
  ORDER BY check_time DESC
  LIMIT 1;

  IF v_prev_score IS NOT NULL THEN
    IF v_north_star > v_prev_score + 5 THEN
      v_trend := 'improving';
    ELSIF v_north_star < v_prev_score - 10 THEN
      v_trend := 'critical';
    ELSIF v_north_star < v_prev_score - 5 THEN
      v_trend := 'declining';
    ELSE
      v_trend := 'stable';
    END IF;
  END IF;

  -- Build details
  v_details := jsonb_build_object(
    'drama', jsonb_build_object(
      'score', v_drama_score,
      'scenarios_24h', v_scenarios_24h,
      'response_rate', v_scenario_response_rate,
      'drama_index', v_drama_index
    ),
    'social', jsonb_build_object(
      'score', v_social_score,
      'tea_posts_24h', v_tea_posts_24h,
      'alliances', v_alliance_count,
      'linkups_24h', v_linkup_count_24h
    ),
    'content', jsonb_build_object(
      'score', v_content_score,
      'voice_notes_24h', v_voice_notes_24h
    ),
    'governance', jsonb_build_object(
      'score', v_governance_score,
      'voting_completion_rate', v_voting_participation
    ),
    'cast', jsonb_build_object(
      'score', v_cast_score,
      'active_cast', v_active_cast,
      'ai_cast', v_ai_cast,
      'ai_actions_completed_24h', v_ai_actions_completed_24h,
      'ai_actions_failed_24h', v_ai_actions_failed_24h
    )
  );

  -- Store the score
  INSERT INTO public.north_star_scores (
    game_id, drama_autonomy_score, social_autonomy_score,
    content_autonomy_score, governance_autonomy_score, cast_autonomy_score,
    north_star_score, details, trend
  ) VALUES (
    p_game_id, v_drama_score, v_social_score,
    v_content_score, v_governance_score, v_cast_score,
    v_north_star, v_details, v_trend
  );

  RETURN jsonb_build_object(
    'game_id', p_game_id,
    'north_star_score', v_north_star,
    'trend', v_trend,
    'pillars', v_details,
    'timestamp', NOW()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.calculate_north_star_score(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.calculate_north_star_score(UUID) TO service_role;

-- ============================================================================
-- 8. HOURLY HEALTH CHECK - Main telemetry function
-- ============================================================================
CREATE OR REPLACE FUNCTION public.run_agent_health_check()
RETURNS JSONB AS $$
DECLARE
  v_agent RECORD;
  v_statuses JSONB := '[]';
  v_alerts JSONB := '[]';
  v_healthy INTEGER := 0;
  v_degraded INTEGER := 0;
  v_dead INTEGER := 0;
  v_idle INTEGER := 0;
  v_total INTEGER := 0;
  v_status TEXT;
  v_last_heartbeat TIMESTAMPTZ;
  v_actions_1h INTEGER;
  v_failures_1h INTEGER;
  v_avg_ms INTEGER;
  v_active_games INTEGER;
  v_health_score INTEGER;
  v_game RECORD;
BEGIN

  -- Count active games
  SELECT COUNT(*) INTO v_active_games
  FROM mm_games WHERE status = 'active';

  -- Check each registered agent
  FOR v_agent IN
    SELECT * FROM public.agent_registry WHERE is_active = true
  LOOP
    v_total := v_total + 1;

    -- Get last heartbeat
    SELECT created_at INTO v_last_heartbeat
    FROM public.agent_heartbeats
    WHERE agent_id = v_agent.id
    ORDER BY created_at DESC
    LIMIT 1;

    -- Get actions in last hour
    SELECT
      COALESCE(SUM(items_processed), 0),
      COALESCE(SUM(items_failed), 0),
      COALESCE(AVG(processing_time_ms), 0)::INTEGER
    INTO v_actions_1h, v_failures_1h, v_avg_ms
    FROM public.agent_heartbeats
    WHERE agent_id = v_agent.id
      AND created_at > NOW() - INTERVAL '1 hour';

    -- Determine status
    IF v_last_heartbeat IS NULL THEN
      -- Never reported - might be new or not yet deployed
      IF v_agent.implementation_ref IS NULL THEN
        v_status := 'idle';  -- Not yet implemented
        v_idle := v_idle + 1;
      ELSE
        v_status := 'dead';  -- Should be running but never reported
        v_dead := v_dead + 1;
        v_alerts := v_alerts || jsonb_build_object(
          'severity', 'critical',
          'agent_name', v_agent.agent_name,
          'message', 'Agent has NEVER reported a heartbeat. May not be deployed.',
          'timestamp', NOW()
        );
      END IF;
    ELSIF v_last_heartbeat < NOW() - (v_agent.expected_heartbeat_interval * 3) THEN
      -- Way overdue - agent is dead
      v_status := 'dead';
      v_dead := v_dead + 1;
      v_alerts := v_alerts || jsonb_build_object(
        'severity', 'critical',
        'agent_name', v_agent.agent_name,
        'message', format('Agent last seen %s ago (expected every %s)',
          age(NOW(), v_last_heartbeat)::TEXT,
          v_agent.expected_heartbeat_interval::TEXT),
        'timestamp', NOW()
      );
    ELSIF v_last_heartbeat < NOW() - (v_agent.expected_heartbeat_interval * 1.5) THEN
      -- Overdue - agent is degraded
      v_status := 'degraded';
      v_degraded := v_degraded + 1;
      v_alerts := v_alerts || jsonb_build_object(
        'severity', 'warning',
        'agent_name', v_agent.agent_name,
        'message', format('Agent is late. Last seen %s ago',
          age(NOW(), v_last_heartbeat)::TEXT),
        'timestamp', NOW()
      );
    ELSIF v_failures_1h > v_actions_1h AND v_failures_1h > 0 THEN
      -- More failures than successes
      v_status := 'degraded';
      v_degraded := v_degraded + 1;
      v_alerts := v_alerts || jsonb_build_object(
        'severity', 'warning',
        'agent_name', v_agent.agent_name,
        'message', format('High failure rate: %s failed vs %s completed in last hour',
          v_failures_1h, v_actions_1h),
        'timestamp', NOW()
      );
    ELSE
      v_status := 'healthy';
      v_healthy := v_healthy + 1;
    END IF;

    -- Add to statuses array
    v_statuses := v_statuses || jsonb_build_object(
      'agent_name', v_agent.agent_name,
      'agent_type', v_agent.agent_type,
      'platform_layer', v_agent.platform_layer,
      'status', v_status,
      'last_heartbeat', v_last_heartbeat,
      'actions_last_hour', v_actions_1h,
      'failures_last_hour', v_failures_1h,
      'avg_processing_ms', v_avg_ms,
      'description', v_agent.description
    );
  END LOOP;

  -- Calculate system health score
  IF v_total > 0 THEN
    -- Healthy agents contribute fully, degraded at 50%, dead at 0%, idle neutral
    v_health_score := ((v_healthy * 100 + v_degraded * 50) / GREATEST(1, v_total - v_idle))::INTEGER;
  ELSE
    v_health_score := 0;
  END IF;

  -- Store health check result
  INSERT INTO public.agent_health_checks (
    agent_statuses, total_agents, healthy_count, degraded_count,
    dead_count, idle_count, system_health_score, active_games_count, alerts
  ) VALUES (
    v_statuses, v_total, v_healthy, v_degraded,
    v_dead, v_idle, v_health_score, v_active_games, v_alerts
  );

  -- Calculate North Star scores for all active games
  FOR v_game IN
    SELECT id FROM mm_games WHERE status = 'active'
  LOOP
    PERFORM public.calculate_north_star_score(v_game.id);
  END LOOP;

  -- Record own heartbeat
  PERFORM public.record_agent_heartbeat(
    'system_health_monitor',
    NULL,
    format('Health check: %s healthy, %s degraded, %s dead, %s idle. Score: %s/100',
      v_healthy, v_degraded, v_dead, v_idle, v_health_score),
    v_total,
    v_dead,
    NULL,
    jsonb_build_object('alerts_generated', jsonb_array_length(v_alerts))
  );

  RETURN jsonb_build_object(
    'success', true,
    'system_health_score', v_health_score,
    'agents', jsonb_build_object(
      'total', v_total,
      'healthy', v_healthy,
      'degraded', v_degraded,
      'dead', v_dead,
      'idle', v_idle
    ),
    'active_games', v_active_games,
    'alerts_count', jsonb_array_length(v_alerts),
    'alerts', v_alerts,
    'timestamp', NOW()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.run_agent_health_check() TO authenticated;
GRANT EXECUTE ON FUNCTION public.run_agent_health_check() TO service_role;

-- ============================================================================
-- 9. GET TELEMETRY DASHBOARD DATA - For frontend
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_agent_telemetry_dashboard()
RETURNS JSONB AS $$
DECLARE
  v_latest_check JSONB;
  v_north_star_avg INTEGER;
  v_trend_data JSONB;
  v_alert_history JSONB;
BEGIN
  -- Latest health check
  SELECT jsonb_build_object(
    'check_time', check_time,
    'system_health_score', system_health_score,
    'agents', agent_statuses,
    'healthy', healthy_count,
    'degraded', degraded_count,
    'dead', dead_count,
    'idle', idle_count,
    'active_games', active_games_count,
    'alerts', alerts
  ) INTO v_latest_check
  FROM public.agent_health_checks
  ORDER BY check_time DESC
  LIMIT 1;

  -- Average north star across active games
  SELECT COALESCE(AVG(north_star_score), 0)::INTEGER INTO v_north_star_avg
  FROM public.north_star_scores ns
  WHERE ns.check_time > NOW() - INTERVAL '1 hour';

  -- North star trend (last 24 hours, hourly)
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'hour', date_trunc('hour', check_time),
      'avg_score', avg_score
    ) ORDER BY hour
  ), '[]') INTO v_trend_data
  FROM (
    SELECT date_trunc('hour', check_time) AS hour,
           AVG(north_star_score)::INTEGER AS avg_score
    FROM public.north_star_scores
    WHERE check_time > NOW() - INTERVAL '24 hours'
    GROUP BY date_trunc('hour', check_time)
  ) t;

  -- Recent alerts (last 24h)
  SELECT COALESCE(jsonb_agg(alert ORDER BY alert->>'timestamp' DESC), '[]')
  INTO v_alert_history
  FROM (
    SELECT jsonb_array_elements(alerts) AS alert
    FROM public.agent_health_checks
    WHERE check_time > NOW() - INTERVAL '24 hours'
      AND jsonb_array_length(alerts) > 0
    ORDER BY check_time DESC
    LIMIT 50
  ) t;

  RETURN jsonb_build_object(
    'latest_health_check', COALESCE(v_latest_check, '{}'),
    'north_star_average', v_north_star_avg,
    'north_star_trend_24h', v_trend_data,
    'recent_alerts', v_alert_history,
    'timestamp', NOW()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_agent_telemetry_dashboard() TO authenticated;

-- ============================================================================
-- 10. CRON JOB - Run health check every hour
-- ============================================================================
SELECT cron.schedule(
  'agent_health_check_hourly',
  '0 * * * *',  -- Every hour on the hour
  $$ SELECT public.run_agent_health_check(); $$
);

-- ============================================================================
-- 11. RLS POLICIES
-- ============================================================================

ALTER TABLE public.agent_registry ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agent_heartbeats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agent_health_checks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.north_star_scores ENABLE ROW LEVEL SECURITY;

-- Everyone can read agent status (transparency)
DROP POLICY IF EXISTS "Anyone can view agent registry" ON public.agent_registry;
CREATE POLICY "Anyone can view agent registry" ON public.agent_registry
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Anyone can view heartbeats" ON public.agent_heartbeats;
CREATE POLICY "Anyone can view heartbeats" ON public.agent_heartbeats
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Anyone can view health checks" ON public.agent_health_checks;
CREATE POLICY "Anyone can view health checks" ON public.agent_health_checks
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Anyone can view north star scores" ON public.north_star_scores;
CREATE POLICY "Anyone can view north star scores" ON public.north_star_scores
  FOR SELECT USING (true);

-- Service role can write (agents report via edge functions)
DROP POLICY IF EXISTS "Service role can insert heartbeats" ON public.agent_heartbeats;
CREATE POLICY "Service role can insert heartbeats" ON public.agent_heartbeats
  FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Service role can insert health checks" ON public.agent_health_checks;
CREATE POLICY "Service role can insert health checks" ON public.agent_health_checks
  FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Service role can insert north star" ON public.north_star_scores;
CREATE POLICY "Service role can insert north star" ON public.north_star_scores
  FOR INSERT WITH CHECK (true);

-- ============================================================================
-- 12. HEARTBEAT CLEANUP - Delete heartbeats older than 7 days
-- ============================================================================
CREATE OR REPLACE FUNCTION public.cleanup_old_telemetry()
RETURNS VOID AS $$
BEGIN
  DELETE FROM public.agent_heartbeats WHERE created_at < NOW() - INTERVAL '7 days';
  DELETE FROM public.agent_health_checks WHERE created_at < NOW() - INTERVAL '30 days';
  -- Keep north star scores for 90 days (trend analysis)
  DELETE FROM public.north_star_scores WHERE created_at < NOW() - INTERVAL '90 days';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Daily cleanup at 4 AM UTC
SELECT cron.schedule(
  'cleanup_old_telemetry',
  '0 4 * * *',
  $$ SELECT public.cleanup_old_telemetry(); $$
);

COMMENT ON TABLE public.agent_registry IS 'Registry of all AI agents in the ImmersiVerse OS ecosystem';
COMMENT ON TABLE public.agent_heartbeats IS 'Real-time heartbeat signals from agents';
COMMENT ON TABLE public.agent_health_checks IS 'Hourly system health snapshots';
COMMENT ON TABLE public.north_star_scores IS 'North Star autonomy scores per game per hour';
COMMENT ON FUNCTION public.run_agent_health_check() IS 'Hourly health check across all agents. Generates alerts for dead/degraded agents.';
COMMENT ON FUNCTION public.calculate_north_star_score(UUID) IS 'Calculates the 5-pillar North Star autonomy score for a game.';
