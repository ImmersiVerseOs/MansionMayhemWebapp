-- ============================================================================
-- MIGRATION 054: EPISODE SCHEDULER & PHASE ENGINE
-- ============================================================================
-- Extends game_events system with episode phase transitions.
-- Adds new event types for 7-phase episode flow.
-- Creates schedule_episode_events() to pre-schedule an entire episode.
-- Creates handle_event_phase_start() for real-time phase transitions.
-- ============================================================================

-- ============================================================================
-- 1. EXPAND game_events event_type for episode phases
-- ============================================================================
ALTER TABLE public.game_events DROP CONSTRAINT IF EXISTS game_events_event_type_check;
ALTER TABLE public.game_events ADD CONSTRAINT game_events_event_type_check
  CHECK (event_type IN (
    -- Existing event types
    'scenario_distribute', 'queen_selection', 'hot_seat_start',
    'voting_open', 'voting_close', 'elimination_announce',
    'ai_director_run', 'ai_tea_posts', 'ai_link_ups', 'ai_agent_process',
    'lobby_check', 'game_start', 'game_end', 'lobby_fill', 'cleanup',
    'party_round', 'random_event', 'party_elimination',
    -- NEW episode event types
    'episode_start',        -- Begin new episode (assign roles, reset state)
    'phase_start',          -- Transition to a new phase
    'phase_end',            -- Phase timer expired, prepare next
    'mission_assign',       -- Assign missions to players
    'challenge_start',      -- Start group challenge
    'challenge_end',        -- End challenge, award prize
    'secret_generate',      -- Generate secrets for Confrontation
    'fight_process',        -- Process a fight event
    'director_announce',    -- Director makes an announcement
    'coronation'            -- Final crowning
  ));

-- ============================================================================
-- 2. EPISODE PHASE TIMING TEMPLATES
-- Configurable per game mode
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.episode_phase_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mode_name TEXT NOT NULL, -- 'party', 'blitz', 'sprint' (maps to game_mode_templates)
  phase_order INTEGER NOT NULL,
  phase_name TEXT NOT NULL CHECK (phase_name IN (
    'arrival', 'social', 'challenge', 'whisper', 'confrontation', 'deliberation', 'elimination'
  )),
  duration_secs INTEGER NOT NULL,
  events_to_schedule TEXT[] DEFAULT '{}', -- events to fire during this phase
  director_prompt TEXT, -- What the Director says at phase start
  ui_config JSONB DEFAULT '{}', -- UI customization (background, music cue, etc.)
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(mode_name, phase_order)
);

-- Seed timing for 3 episode modes
-- PARTY MODE (35 min total per episode)
INSERT INTO episode_phase_templates (mode_name, phase_order, phase_name, duration_secs, events_to_schedule, director_prompt) VALUES
('party', 1, 'arrival',       180, ARRAY['episode_start', 'director_announce'],
 'Welcome to the Mansion. Your role has been assigned. Trust no one.'),
('party', 2, 'social',        480, ARRAY['mission_assign', 'ai_tea_posts', 'ai_link_ups', 'director_announce'],
 'Mingle. Form alliances. Or plant the seeds of betrayal. The clock is ticking.'),
('party', 3, 'challenge',     420, ARRAY['challenge_start', 'director_announce'],
 'Challenge time. One winner. One prize. Everyone else? Vulnerable.'),
('party', 4, 'whisper',       300, ARRAY['mission_assign', 'director_announce'],
 'The lights are dimming. Whisper hour. The most dangerous time in the Mansion.'),
('party', 5, 'confrontation', 300, ARRAY['secret_generate', 'director_announce'],
 'Everyone to the living room. NOW. I have something to share.'),
('party', 6, 'deliberation',  240, ARRAY['voting_open', 'director_announce'],
 'Voting is OPEN. Choose who goes home. They will know it was you.'),
('party', 7, 'elimination',   180, ARRAY['voting_close', 'elimination_announce', 'director_announce'],
 'The votes are in. Let me enjoy this.')
ON CONFLICT (mode_name, phase_order) DO NOTHING;

-- BLITZ MODE (15 min total per episode)
INSERT INTO episode_phase_templates (mode_name, phase_order, phase_name, duration_secs, events_to_schedule, director_prompt) VALUES
('blitz', 1, 'arrival',       60,  ARRAY['episode_start', 'director_announce'],
 'No time for pleasantries. Know your role. Move.'),
('blitz', 2, 'social',        180, ARRAY['mission_assign', 'director_announce'],
 'Three minutes. Make alliances or make enemies. Your call.'),
('blitz', 3, 'challenge',     120, ARRAY['challenge_start', 'director_announce'],
 'Quick challenge. Winner takes all. Go.'),
('blitz', 4, 'whisper',       120, ARRAY['director_announce'],
 'Lights out. Whisper fast.'),
('blitz', 5, 'confrontation', 120, ARRAY['secret_generate', 'director_announce'],
 'Time for truth. Someone here has been lying.'),
('blitz', 6, 'deliberation',  120, ARRAY['voting_open', 'director_announce'],
 'Vote. Now. No second chances.'),
('blitz', 7, 'elimination',   60,  ARRAY['voting_close', 'elimination_announce', 'director_announce'],
 'Done. Get out.')
ON CONFLICT (mode_name, phase_order) DO NOTHING;

-- SPRINT MODE (5 min total per episode)
INSERT INTO episode_phase_templates (mode_name, phase_order, phase_name, duration_secs, events_to_schedule, director_prompt) VALUES
('sprint', 1, 'arrival',       30,  ARRAY['episode_start', 'director_announce'],
 'Go.'),
('sprint', 2, 'social',        60,  ARRAY['mission_assign', 'director_announce'],
 'One minute. Make it count.'),
('sprint', 3, 'challenge',     45,  ARRAY['challenge_start', 'director_announce'],
 'Challenge. 45 seconds. Win or lose.'),
('sprint', 4, 'whisper',       30,  ARRAY['director_announce'],
 'Whisper.'),
('sprint', 5, 'confrontation', 30,  ARRAY['secret_generate', 'director_announce'],
 'Here is what I know.'),
('sprint', 6, 'deliberation',  45,  ARRAY['voting_open', 'director_announce'],
 'Vote.'),
('sprint', 7, 'elimination',   30,  ARRAY['voting_close', 'elimination_announce', 'director_announce'],
 'Goodbye.')
ON CONFLICT (mode_name, phase_order) DO NOTHING;

ALTER TABLE episode_phase_templates ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Phase templates public read" ON episode_phase_templates FOR SELECT USING (true);

-- ============================================================================
-- 3. schedule_episode_events() — Pre-schedule all phase transitions
-- ============================================================================
CREATE OR REPLACE FUNCTION public.schedule_episode_events(
  p_game_id UUID,
  p_episode_number INTEGER,
  p_mode TEXT DEFAULT 'party'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_phase RECORD;
  v_offset INTERVAL := INTERVAL '0';
  v_count INTEGER := 0;
  v_episode_start TIMESTAMPTZ := NOW();
  v_evt TEXT;
BEGIN
  -- Cancel any existing episode events for this game
  UPDATE game_events SET status = 'cancelled'
  WHERE game_id = p_game_id
    AND event_type IN ('episode_start', 'phase_start', 'phase_end', 'mission_assign',
                        'challenge_start', 'challenge_end', 'secret_generate',
                        'director_announce', 'coronation')
    AND status = 'scheduled';

  -- Update game state
  UPDATE mm_games
  SET episode_number = p_episode_number,
      current_phase = 'arrival',
      phase_started_at = v_episode_start,
      drama_level = GREATEST(drama_level - 10, 0) -- slight drama reset between episodes
  WHERE id = p_game_id;

  -- Schedule each phase
  FOR v_phase IN
    SELECT * FROM episode_phase_templates
    WHERE mode_name = p_mode
    ORDER BY phase_order ASC
  LOOP
    -- Phase start event
    INSERT INTO game_events (game_id, event_type, scheduled_for, priority, payload)
    VALUES (
      p_game_id, 'phase_start',
      v_episode_start + v_offset,
      9,
      jsonb_build_object(
        'episode', p_episode_number,
        'phase', v_phase.phase_name,
        'phase_order', v_phase.phase_order,
        'duration_secs', v_phase.duration_secs,
        'mode', p_mode,
        'director_prompt', v_phase.director_prompt
      )
    );
    v_count := v_count + 1;

    -- Schedule sub-events within this phase
    FOREACH v_evt IN ARRAY v_phase.events_to_schedule LOOP
      -- Stagger sub-events within the phase
      INSERT INTO game_events (game_id, event_type, scheduled_for, priority, payload)
      VALUES (
        p_game_id,
        v_evt,
        v_episode_start + v_offset + INTERVAL '5 seconds' * (v_count % 10),
        CASE
          WHEN v_evt IN ('voting_open', 'voting_close', 'elimination_announce') THEN 9
          WHEN v_evt = 'episode_start' THEN 10
          ELSE 7
        END,
        jsonb_build_object(
          'episode', p_episode_number,
          'phase', v_phase.phase_name,
          'mode', p_mode
        )
      );
      v_count := v_count + 1;
    END LOOP;

    -- Phase end event (fires at phase duration)
    INSERT INTO game_events (game_id, event_type, scheduled_for, priority, payload)
    VALUES (
      p_game_id, 'phase_end',
      v_episode_start + v_offset + (v_phase.duration_secs * INTERVAL '1 second'),
      8,
      jsonb_build_object(
        'episode', p_episode_number,
        'phase', v_phase.phase_name,
        'next_phase_order', v_phase.phase_order + 1,
        'mode', p_mode
      )
    );
    v_count := v_count + 1;

    -- Advance offset
    v_offset := v_offset + (v_phase.duration_secs * INTERVAL '1 second');
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'game_id', p_game_id,
    'episode', p_episode_number,
    'mode', p_mode,
    'events_scheduled', v_count,
    'total_duration_secs', EXTRACT(EPOCH FROM v_offset)::INTEGER,
    'episode_ends_at', v_episode_start + v_offset
  );
END;
$$;

-- ============================================================================
-- 4. handle_event_episode_start — Begin a new episode
-- ============================================================================
CREATE OR REPLACE FUNCTION public.handle_event_episode_start(
  p_game_id UUID,
  p_payload JSONB DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_episode INTEGER;
  v_role_result JSONB;
  v_active_count INTEGER;
BEGIN
  v_episode := COALESCE((p_payload->>'episode')::INTEGER, 1);

  -- Count active players
  SELECT count(*) INTO v_active_count
  FROM mm_game_cast WHERE game_id = p_game_id AND status = 'active';

  -- If 2 or fewer, trigger coronation instead
  IF v_active_count <= 2 THEN
    INSERT INTO game_events (game_id, event_type, scheduled_for, priority, payload)
    VALUES (p_game_id, 'coronation', NOW(), 10,
            jsonb_build_object('episode', v_episode));
    RETURN jsonb_build_object('success', true, 'action', 'coronation', 'remaining', v_active_count);
  END IF;

  -- Reset per-episode state
  UPDATE mm_game_cast
  SET immunity = false, has_power = NULL
  WHERE game_id = p_game_id AND status = 'active';

  -- Assign secret roles
  v_role_result := assign_episode_roles(p_game_id, v_episode);

  -- Director announcement
  INSERT INTO episode_director_log (game_id, episode_number, message_type, content, phase, is_ai_generated)
  VALUES (p_game_id, v_episode, 'phase_intro',
          'Episode ' || v_episode || ' begins. ' || v_active_count || ' players remain. Roles have been assigned. Trust no one.',
          'arrival', false);

  RETURN jsonb_build_object(
    'success', true,
    'episode', v_episode,
    'active_players', v_active_count,
    'roles', v_role_result
  );
END;
$$;

-- ============================================================================
-- 5. handle_event_phase_start — Transition to a new phase
-- ============================================================================
CREATE OR REPLACE FUNCTION public.handle_event_phase_start(
  p_game_id UUID,
  p_payload JSONB DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_phase TEXT;
  v_episode INTEGER;
  v_duration INTEGER;
  v_director_prompt TEXT;
BEGIN
  v_phase := p_payload->>'phase';
  v_episode := COALESCE((p_payload->>'episode')::INTEGER, 1);
  v_duration := COALESCE((p_payload->>'duration_secs')::INTEGER, 300);
  v_director_prompt := p_payload->>'director_prompt';

  -- Update game state (this triggers Realtime → all clients update)
  UPDATE mm_games
  SET current_phase = v_phase,
      phase_started_at = NOW(),
      updated_at = NOW()
  WHERE id = p_game_id;

  -- Update game stage tracking
  INSERT INTO mm_game_stages (game_id, stage_name, stage_number, stage_type, status, started_at, stage_ends_at, auto_advance)
  VALUES (
    p_game_id,
    v_phase || '_ep' || v_episode,
    COALESCE((p_payload->>'phase_order')::INTEGER, 1),
    v_phase,
    'active',
    NOW(),
    NOW() + (v_duration * INTERVAL '1 second'),
    true
  )
  ON CONFLICT (game_id, stage_number) DO UPDATE SET
    stage_name = EXCLUDED.stage_name,
    stage_type = EXCLUDED.stage_type,
    status = 'active',
    started_at = NOW(),
    stage_ends_at = EXCLUDED.stage_ends_at;

  -- Director announcement for phase
  IF v_director_prompt IS NOT NULL THEN
    INSERT INTO episode_director_log (game_id, episode_number, message_type, content, phase, is_ai_generated)
    VALUES (p_game_id, v_episode, 'phase_intro', v_director_prompt, v_phase, false);
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'phase', v_phase,
    'episode', v_episode,
    'duration_secs', v_duration,
    'ends_at', NOW() + (v_duration * INTERVAL '1 second')
  );
END;
$$;

-- ============================================================================
-- 6. handle_event_phase_end — Phase timer expired
-- ============================================================================
CREATE OR REPLACE FUNCTION public.handle_event_phase_end(
  p_game_id UUID,
  p_payload JSONB DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_phase TEXT;
  v_next_order INTEGER;
BEGIN
  v_phase := p_payload->>'phase';
  v_next_order := COALESCE((p_payload->>'next_phase_order')::INTEGER, 0);

  -- Mark current stage as completed
  UPDATE mm_game_stages SET status = 'completed', completed_at = NOW()
  WHERE game_id = p_game_id AND stage_type = v_phase AND status = 'active';

  -- If we're past phase 7 (elimination), the episode is done
  IF v_next_order > 7 THEN
    -- Start next episode
    DECLARE
      v_current_ep INTEGER;
      v_mode TEXT;
    BEGIN
      SELECT episode_number, game_mode INTO v_current_ep, v_mode FROM mm_games WHERE id = p_game_id;

      -- Schedule next episode
      INSERT INTO game_events (game_id, event_type, scheduled_for, priority, payload)
      VALUES (p_game_id, 'episode_start', NOW() + INTERVAL '10 seconds', 10,
              jsonb_build_object('episode', v_current_ep + 1, 'mode', COALESCE(v_mode, 'party')));

      -- Also schedule the full episode phase chain
      PERFORM schedule_episode_events(p_game_id, v_current_ep + 1, COALESCE(v_mode, 'party'));
    END;
  END IF;

  RETURN jsonb_build_object('success', true, 'phase_completed', v_phase, 'next_phase_order', v_next_order);
END;
$$;

-- ============================================================================
-- 7. handle_event_mission_assign — Assign missions to active players
-- ============================================================================
CREATE OR REPLACE FUNCTION public.handle_event_mission_assign(
  p_game_id UUID,
  p_payload JSONB DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_episode INTEGER;
  v_phase TEXT;
  v_cast_id UUID;
  v_mission RECORD;
  v_count INTEGER := 0;
BEGIN
  v_episode := COALESCE((p_payload->>'episode')::INTEGER, 1);
  v_phase := COALESCE(p_payload->>'phase', 'social');

  -- Assign one mission to each active player who doesn't have one this episode
  FOR v_cast_id IN
    SELECT gc.cast_member_id
    FROM mm_game_cast gc
    WHERE gc.game_id = p_game_id AND gc.status = 'active'
    AND gc.cast_member_id NOT IN (
      SELECT em.cast_member_id FROM episode_missions em
      WHERE em.game_id = p_game_id AND em.episode_number = v_episode AND em.status = 'active'
    )
  LOOP
    -- Pick a random available mission for this phase
    SELECT * INTO v_mission
    FROM episode_mission_templates
    WHERE v_phase = ANY(phase_available)
    ORDER BY random()
    LIMIT 1;

    IF v_mission IS NOT NULL THEN
      INSERT INTO episode_missions (
        game_id, episode_number, cast_member_id, mission_template_id,
        status, expires_at
      ) VALUES (
        p_game_id, v_episode, v_cast_id, v_mission.id,
        'active', NOW() + (v_mission.duration_secs * INTERVAL '1 second')
      );
      v_count := v_count + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('success', true, 'missions_assigned', v_count, 'phase', v_phase);
END;
$$;

-- ============================================================================
-- 8. handle_event_challenge_start — Start a group challenge
-- ============================================================================
CREATE OR REPLACE FUNCTION public.handle_event_challenge_start(
  p_game_id UUID,
  p_payload JSONB DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_episode INTEGER;
  v_challenge RECORD;
  v_challenge_id UUID;
  v_active_cast UUID[];
BEGIN
  v_episode := COALESCE((p_payload->>'episode')::INTEGER, 1);

  -- Pick a random challenge
  SELECT * INTO v_challenge FROM episode_challenge_templates ORDER BY random() LIMIT 1;

  -- Get active cast
  SELECT array_agg(cast_member_id) INTO v_active_cast
  FROM mm_game_cast WHERE game_id = p_game_id AND status = 'active';

  -- Create challenge instance
  INSERT INTO episode_challenges (
    game_id, episode_number, challenge_template_id, status,
    participants, started_at
  ) VALUES (
    p_game_id, v_episode, v_challenge.id, 'active',
    to_jsonb(v_active_cast), NOW()
  )
  RETURNING id INTO v_challenge_id;

  -- Director announces challenge
  INSERT INTO episode_director_log (game_id, episode_number, message_type, content, phase)
  VALUES (p_game_id, v_episode, 'challenge',
          v_challenge.icon || ' ' || v_challenge.display_name || ': ' || v_challenge.description,
          'challenge');

  RETURN jsonb_build_object(
    'success', true,
    'challenge_id', v_challenge_id,
    'challenge_name', v_challenge.display_name,
    'challenge_type', v_challenge.challenge_type,
    'duration_secs', v_challenge.duration_secs,
    'reward', v_challenge.reward_type
  );
END;
$$;

-- ============================================================================
-- 9. handle_event_secret_generate — Generate secrets for Confrontation
-- ============================================================================
CREATE OR REPLACE FUNCTION public.handle_event_secret_generate(
  p_game_id UUID,
  p_payload JSONB DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_episode INTEGER;
  v_secret_types TEXT[] := ARRAY['alliance_betrayal', 'secret_vote', 'hidden_alliance', 'role_hint', 'director_intel'];
  v_type TEXT;
  v_about UUID;
  v_content TEXT;
  v_count INTEGER := 0;
BEGIN
  v_episode := COALESCE((p_payload->>'episode')::INTEGER, 1);

  -- Generate 1-3 secrets based on actual game state
  -- Secret 1: Random alliance info
  SELECT gc.cast_member_id INTO v_about
  FROM mm_game_cast gc WHERE gc.game_id = p_game_id AND gc.status = 'active'
  ORDER BY random() LIMIT 1;

  IF v_about IS NOT NULL THEN
    SELECT cm.display_name INTO v_content FROM cast_members cm WHERE cm.id = v_about;

    INSERT INTO episode_secrets (game_id, episode_number, secret_type, content, about_cast_id, drama_impact)
    VALUES (p_game_id, v_episode, 'director_intel',
            'I have been watching ' || v_content || ' very closely. They are not who they seem.',
            v_about, 15);
    v_count := v_count + 1;
  END IF;

  -- Secret 2: Strike-related if anyone has strikes
  SELECT gc.cast_member_id INTO v_about
  FROM mm_game_cast gc WHERE gc.game_id = p_game_id AND gc.status = 'active' AND gc.strike_count > 0
  ORDER BY random() LIMIT 1;

  IF v_about IS NOT NULL THEN
    SELECT cm.display_name INTO v_content FROM cast_members cm WHERE cm.id = v_about;

    INSERT INTO episode_secrets (game_id, episode_number, secret_type, content, about_cast_id, drama_impact)
    VALUES (p_game_id, v_episode, 'alliance_betrayal',
            v_content || ' already has ' || (SELECT strike_count FROM mm_game_cast WHERE game_id = p_game_id AND cast_member_id = v_about) || ' strike(s). One more fight and they are OUT.',
            v_about, 20);
    v_count := v_count + 1;
  END IF;

  -- Director reveals first unrevealed secret
  UPDATE episode_secrets
  SET is_revealed = true, revealed_at = NOW()
  WHERE id = (
    SELECT id FROM episode_secrets
    WHERE game_id = p_game_id AND episode_number = v_episode AND is_revealed = false
    ORDER BY drama_impact DESC LIMIT 1
  );

  RETURN jsonb_build_object('success', true, 'secrets_generated', v_count);
END;
$$;

-- ============================================================================
-- 10. handle_event_director_announce — Director announcement
-- ============================================================================
CREATE OR REPLACE FUNCTION public.handle_event_director_announce(
  p_game_id UUID,
  p_payload JSONB DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_episode INTEGER;
  v_phase TEXT;
  v_prompt TEXT;
BEGIN
  v_episode := COALESCE((p_payload->>'episode')::INTEGER, 1);
  v_phase := COALESCE(p_payload->>'phase', 'social');
  v_prompt := p_payload->>'director_prompt';

  -- Use provided prompt or get from phase template
  IF v_prompt IS NULL THEN
    SELECT director_prompt INTO v_prompt
    FROM episode_phase_templates
    WHERE mode_name = COALESCE(p_payload->>'mode', 'party') AND phase_name = v_phase;
  END IF;

  -- Insert Director message (fallback if Claude API call handled elsewhere)
  IF v_prompt IS NOT NULL THEN
    INSERT INTO episode_director_log (game_id, episode_number, message_type, content, phase, is_ai_generated)
    VALUES (p_game_id, v_episode, 'announce', v_prompt, v_phase, false);
  END IF;

  RETURN jsonb_build_object('success', true, 'phase', v_phase, 'announced', v_prompt IS NOT NULL);
END;
$$;

-- ============================================================================
-- 11. handle_event_coronation — Crown the winner
-- ============================================================================
CREATE OR REPLACE FUNCTION public.handle_event_coronation(
  p_game_id UUID,
  p_payload JSONB DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_winner RECORD;
  v_runner_up RECORD;
BEGIN
  -- Get top 2 active players by drama points
  SELECT gc.cast_member_id, cm.display_name, gc.drama_points
  INTO v_winner
  FROM mm_game_cast gc
  JOIN cast_members cm ON cm.id = gc.cast_member_id
  WHERE gc.game_id = p_game_id AND gc.status = 'active'
  ORDER BY gc.drama_points DESC
  LIMIT 1;

  SELECT gc.cast_member_id, cm.display_name, gc.drama_points
  INTO v_runner_up
  FROM mm_game_cast gc
  JOIN cast_members cm ON cm.id = gc.cast_member_id
  WHERE gc.game_id = p_game_id AND gc.status = 'active'
    AND gc.cast_member_id != v_winner.cast_member_id
  ORDER BY gc.drama_points DESC
  LIMIT 1;

  -- Director crowning announcement
  INSERT INTO episode_director_log (
    game_id, episode_number, message_type, content, phase
  ) VALUES (
    p_game_id,
    COALESCE((SELECT episode_number FROM mm_games WHERE id = p_game_id), 1),
    'coronation',
    '👑 The Mansion has spoken. ' || v_winner.display_name || ' is the Queen of Mansion Mayhem! 👑',
    'elimination'
  );

  -- End the game
  UPDATE mm_games
  SET status = 'completed',
      completed_at = NOW(),
      current_phase = 'completed'
  WHERE id = p_game_id;

  -- Cancel remaining events
  PERFORM cancel_game_events(p_game_id);

  -- Update winner stats
  UPDATE profiles
  SET games_won = games_won + 1
  WHERE id = (SELECT user_id FROM cast_members WHERE id = v_winner.cast_member_id);

  RETURN jsonb_build_object(
    'success', true,
    'winner_id', v_winner.cast_member_id,
    'winner_name', v_winner.display_name,
    'runner_up_id', v_runner_up.cast_member_id,
    'runner_up_name', v_runner_up.display_name
  );
END;
$$;

-- ============================================================================
-- 12. UPDATE process_game_events() — Add new event type dispatchers
-- ============================================================================
CREATE OR REPLACE FUNCTION public.process_game_events()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_event RECORD;
  v_result JSONB;
  v_start_time TIMESTAMPTZ;
  v_duration_ms INTEGER;
  v_processed INTEGER := 0;
  v_failed INTEGER := 0;
  v_results JSONB := '[]'::jsonb;
BEGIN
  FOR v_event IN
    SELECT ge.*
    FROM game_events ge
    WHERE ge.status = 'scheduled'
      AND ge.scheduled_for <= NOW()
    ORDER BY ge.priority DESC, ge.scheduled_for ASC
    LIMIT 10
    FOR UPDATE SKIP LOCKED
  LOOP
    v_start_time := clock_timestamp();
    UPDATE game_events SET status = 'processing', started_at = NOW() WHERE id = v_event.id;

    BEGIN
      CASE v_event.event_type
        -- Existing handlers
        WHEN 'lobby_check' THEN v_result := handle_event_lobby_check(v_event.game_id, v_event.payload);
        WHEN 'lobby_fill' THEN v_result := handle_event_lobby_fill(v_event.game_id, v_event.payload);
        WHEN 'game_start' THEN v_result := handle_event_game_start(v_event.game_id, v_event.payload);
        WHEN 'scenario_distribute' THEN v_result := handle_event_scenario_distribute(v_event.game_id, v_event.payload);
        WHEN 'queen_selection' THEN v_result := handle_event_queen_selection(v_event.game_id, v_event.payload);
        WHEN 'hot_seat_start' THEN v_result := handle_event_hot_seat(v_event.game_id, v_event.payload);
        WHEN 'voting_open' THEN v_result := handle_event_voting_open(v_event.game_id, v_event.payload);
        WHEN 'voting_close' THEN v_result := handle_event_voting_close(v_event.game_id, v_event.payload);
        WHEN 'elimination_announce' THEN v_result := handle_event_elimination(v_event.game_id, v_event.payload);
        WHEN 'ai_director_run' THEN v_result := handle_event_ai_director(v_event.game_id, v_event.payload);
        WHEN 'ai_tea_posts' THEN v_result := handle_event_ai_tea(v_event.game_id, v_event.payload);
        WHEN 'ai_link_ups' THEN v_result := handle_event_ai_linkups(v_event.game_id, v_event.payload);
        WHEN 'ai_agent_process' THEN v_result := handle_event_ai_process(v_event.game_id, v_event.payload);
        WHEN 'cleanup' THEN v_result := handle_event_cleanup(v_event.game_id, v_event.payload);
        WHEN 'game_end' THEN v_result := handle_event_game_end(v_event.game_id, v_event.payload);
        WHEN 'party_round' THEN v_result := handle_event_party_round(v_event.game_id, v_event.payload);
        WHEN 'random_event' THEN v_result := handle_event_random_event(v_event.game_id, v_event.payload);
        WHEN 'party_elimination' THEN v_result := handle_event_party_elimination(v_event.game_id, v_event.payload);
        -- NEW episode handlers
        WHEN 'episode_start' THEN v_result := handle_event_episode_start(v_event.game_id, v_event.payload);
        WHEN 'phase_start' THEN v_result := handle_event_phase_start(v_event.game_id, v_event.payload);
        WHEN 'phase_end' THEN v_result := handle_event_phase_end(v_event.game_id, v_event.payload);
        WHEN 'mission_assign' THEN v_result := handle_event_mission_assign(v_event.game_id, v_event.payload);
        WHEN 'challenge_start' THEN v_result := handle_event_challenge_start(v_event.game_id, v_event.payload);
        WHEN 'secret_generate' THEN v_result := handle_event_secret_generate(v_event.game_id, v_event.payload);
        WHEN 'director_announce' THEN v_result := handle_event_director_announce(v_event.game_id, v_event.payload);
        WHEN 'coronation' THEN v_result := handle_event_coronation(v_event.game_id, v_event.payload);
        WHEN 'fight_process' THEN v_result := jsonb_build_object('note', 'Fight processed via process_episode_fight()');
        ELSE v_result := jsonb_build_object('error', 'Unknown event type: ' || v_event.event_type);
      END CASE;

      v_duration_ms := EXTRACT(MILLISECONDS FROM clock_timestamp() - v_start_time)::INTEGER;

      UPDATE game_events SET status = 'completed', completed_at = NOW(), result = v_result WHERE id = v_event.id;

      INSERT INTO game_event_log (game_id, event_id, event_type, status, payload, result, duration_ms)
      VALUES (v_event.game_id, v_event.id, v_event.event_type, 'completed', v_event.payload, v_result, v_duration_ms);

      -- Recurring events
      IF v_event.is_recurring AND v_event.recurring_interval IS NOT NULL THEN
        PERFORM 1 FROM mm_games WHERE id = v_event.game_id AND status IN ('active', 'active_lobby', 'waiting_lobby', 'final_three', 'finale');
        IF FOUND THEN
          INSERT INTO game_events (game_id, event_type, status, scheduled_for, priority, payload, is_recurring, recurring_interval, parent_event_id)
          VALUES (v_event.game_id, v_event.event_type, 'scheduled', v_event.scheduled_for + v_event.recurring_interval, v_event.priority, v_event.payload, true, v_event.recurring_interval, v_event.id);
        END IF;
      END IF;

      v_processed := v_processed + 1;
      v_results := v_results || jsonb_build_object('event_id', v_event.id, 'type', v_event.event_type, 'status', 'completed', 'duration_ms', v_duration_ms);

    EXCEPTION WHEN OTHERS THEN
      v_duration_ms := EXTRACT(MILLISECONDS FROM clock_timestamp() - v_start_time)::INTEGER;

      IF v_event.retry_count < v_event.max_retries THEN
        UPDATE game_events SET status = 'scheduled', started_at = NULL, retry_count = retry_count + 1, error_message = SQLERRM, scheduled_for = NOW() + (POWER(5, v_event.retry_count) * INTERVAL '1 minute') WHERE id = v_event.id;
      ELSE
        UPDATE game_events SET status = 'failed', completed_at = NOW(), error_message = SQLERRM WHERE id = v_event.id;
      END IF;

      INSERT INTO game_event_log (game_id, event_id, event_type, status, payload, error_message, duration_ms)
      VALUES (v_event.game_id, v_event.id, v_event.event_type, 'failed', v_event.payload, SQLERRM, v_duration_ms);

      v_failed := v_failed + 1;
      v_results := v_results || jsonb_build_object('event_id', v_event.id, 'type', v_event.event_type, 'status', 'failed', 'error', SQLERRM);
    END;
  END LOOP;

  RETURN jsonb_build_object('processed', v_processed, 'failed', v_failed, 'events', v_results, 'timestamp', NOW());
END;
$$;

-- ============================================================================
-- VERIFICATION
-- ============================================================================
SELECT 'episode_phase_templates' AS tbl, count(*) FROM episode_phase_templates;
SELECT proname FROM pg_proc
WHERE proname IN (
  'schedule_episode_events', 'handle_event_episode_start', 'handle_event_phase_start',
  'handle_event_phase_end', 'handle_event_mission_assign', 'handle_event_challenge_start',
  'handle_event_secret_generate', 'handle_event_director_announce', 'handle_event_coronation'
)
ORDER BY proname;
