-- ============================================================================
-- MIGRATION 045: EVENT PROCESSOR & SCHEDULER FUNCTIONS
-- ============================================================================
-- Core event processing engine that replaces 19 cron jobs with 1.
-- Includes: process_game_events(), schedule_game_events(),
--           schedule_next_week_events()
-- ============================================================================

-- ============================================================================
-- 1. process_game_events() - Main processor (runs every minute via cron)
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
  -- Grab up to 10 due events, lock them to prevent double-processing
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

    -- Mark as processing
    UPDATE game_events
    SET status = 'processing', started_at = NOW()
    WHERE id = v_event.id;

    BEGIN
      -- Dispatch to appropriate handler
      CASE v_event.event_type
        WHEN 'lobby_check' THEN
          v_result := handle_event_lobby_check(v_event.game_id, v_event.payload);
        WHEN 'lobby_fill' THEN
          v_result := handle_event_lobby_fill(v_event.game_id, v_event.payload);
        WHEN 'game_start' THEN
          v_result := handle_event_game_start(v_event.game_id, v_event.payload);
        WHEN 'scenario_distribute' THEN
          v_result := handle_event_scenario_distribute(v_event.game_id, v_event.payload);
        WHEN 'queen_selection' THEN
          v_result := handle_event_queen_selection(v_event.game_id, v_event.payload);
        WHEN 'hot_seat_start' THEN
          v_result := handle_event_hot_seat(v_event.game_id, v_event.payload);
        WHEN 'voting_open' THEN
          v_result := handle_event_voting_open(v_event.game_id, v_event.payload);
        WHEN 'voting_close' THEN
          v_result := handle_event_voting_close(v_event.game_id, v_event.payload);
        WHEN 'elimination_announce' THEN
          v_result := handle_event_elimination(v_event.game_id, v_event.payload);
        WHEN 'ai_director_run' THEN
          v_result := handle_event_ai_director(v_event.game_id, v_event.payload);
        WHEN 'ai_tea_posts' THEN
          v_result := handle_event_ai_tea(v_event.game_id, v_event.payload);
        WHEN 'ai_link_ups' THEN
          v_result := handle_event_ai_linkups(v_event.game_id, v_event.payload);
        WHEN 'ai_agent_process' THEN
          v_result := handle_event_ai_process(v_event.game_id, v_event.payload);
        WHEN 'cleanup' THEN
          v_result := handle_event_cleanup(v_event.game_id, v_event.payload);
        WHEN 'game_end' THEN
          v_result := handle_event_game_end(v_event.game_id, v_event.payload);
        WHEN 'party_round' THEN
          v_result := handle_event_party_round(v_event.game_id, v_event.payload);
        WHEN 'random_event' THEN
          v_result := handle_event_random_event(v_event.game_id, v_event.payload);
        WHEN 'party_elimination' THEN
          v_result := handle_event_party_elimination(v_event.game_id, v_event.payload);
        ELSE
          v_result := jsonb_build_object('error', 'Unknown event type: ' || v_event.event_type);
      END CASE;

      v_duration_ms := EXTRACT(MILLISECONDS FROM clock_timestamp() - v_start_time)::INTEGER;

      -- Mark completed
      UPDATE game_events
      SET status = 'completed',
          completed_at = NOW(),
          result = v_result
      WHERE id = v_event.id;

      -- Log to audit trail
      INSERT INTO game_event_log (game_id, event_id, event_type, status, payload, result, duration_ms)
      VALUES (v_event.game_id, v_event.id, v_event.event_type, 'completed', v_event.payload, v_result, v_duration_ms);

      -- If recurring, schedule next occurrence
      IF v_event.is_recurring AND v_event.recurring_interval IS NOT NULL THEN
        -- Only schedule next if game is still active
        PERFORM 1 FROM mm_games
        WHERE id = v_event.game_id
          AND status IN ('active', 'active_lobby', 'waiting_lobby', 'final_three', 'finale');

        IF FOUND THEN
          INSERT INTO game_events (
            game_id, event_type, status, scheduled_for, priority,
            payload, is_recurring, recurring_interval, parent_event_id
          ) VALUES (
            v_event.game_id, v_event.event_type, 'scheduled',
            v_event.scheduled_for + v_event.recurring_interval,
            v_event.priority, v_event.payload,
            true, v_event.recurring_interval, v_event.id
          );
        END IF;
      END IF;

      v_processed := v_processed + 1;
      v_results := v_results || jsonb_build_object(
        'event_id', v_event.id,
        'type', v_event.event_type,
        'status', 'completed',
        'duration_ms', v_duration_ms
      );

    EXCEPTION WHEN OTHERS THEN
      v_duration_ms := EXTRACT(MILLISECONDS FROM clock_timestamp() - v_start_time)::INTEGER;

      -- Check retry count
      IF v_event.retry_count < v_event.max_retries THEN
        -- Retry with exponential backoff (1min, 5min, 25min)
        UPDATE game_events
        SET status = 'scheduled',
            started_at = NULL,
            retry_count = retry_count + 1,
            error_message = SQLERRM,
            scheduled_for = NOW() + (POWER(5, v_event.retry_count) * INTERVAL '1 minute')
        WHERE id = v_event.id;
      ELSE
        -- Max retries exceeded, mark as failed
        UPDATE game_events
        SET status = 'failed',
            completed_at = NOW(),
            error_message = SQLERRM
        WHERE id = v_event.id;
      END IF;

      -- Log failure
      INSERT INTO game_event_log (game_id, event_id, event_type, status, payload, error_message, duration_ms)
      VALUES (v_event.game_id, v_event.id, v_event.event_type, 'failed', v_event.payload, SQLERRM, v_duration_ms);

      v_failed := v_failed + 1;
      v_results := v_results || jsonb_build_object(
        'event_id', v_event.id,
        'type', v_event.event_type,
        'status', 'failed',
        'error', SQLERRM
      );
    END;
  END LOOP;

  RETURN jsonb_build_object(
    'processed', v_processed,
    'failed', v_failed,
    'events', v_results,
    'timestamp', NOW()
  );
END;
$$;

-- ============================================================================
-- 2. schedule_game_events() - Bootstrap events for a game + mode
-- ============================================================================
CREATE OR REPLACE FUNCTION public.schedule_game_events(
  p_game_id UUID,
  p_mode TEXT DEFAULT 'weekly'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_template RECORD;
  v_game RECORD;
  v_game_start TIMESTAMPTZ;
  v_scheduled_count INTEGER := 0;
  v_phase JSONB;
  v_phase_offset INTERVAL := INTERVAL '0';
BEGIN
  -- Get the mode template
  SELECT * INTO v_template
  FROM game_mode_templates
  WHERE mode_name = p_mode;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Unknown game mode: ' || p_mode);
  END IF;

  -- Get game details
  SELECT * INTO v_game
  FROM mm_games
  WHERE id = p_game_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Game not found');
  END IF;

  -- Set game mode and template
  UPDATE mm_games
  SET game_mode = p_mode,
      mode_template_id = v_template.id,
      current_phase = 'lobby',
      phase_started_at = NOW()
  WHERE id = p_game_id;

  -- Use game_starts_at or NOW() as base time
  v_game_start := COALESCE(v_game.game_starts_at, v_game.started_at, NOW());

  -- Cancel any existing scheduled events for this game
  UPDATE game_events
  SET status = 'cancelled'
  WHERE game_id = p_game_id
    AND status = 'scheduled';

  -- =============================================
  -- Schedule recurring AI events (all modes)
  -- =============================================

  -- AI Agent Processor (every 3 min for weekly, every 1 min for blitz)
  INSERT INTO game_events (game_id, event_type, scheduled_for, priority, is_recurring, recurring_interval, payload)
  VALUES (
    p_game_id, 'ai_agent_process',
    v_game_start + INTERVAL '5 minutes',
    CASE WHEN p_mode = 'blitz' THEN 8 ELSE 5 END,
    true,
    CASE WHEN p_mode = 'blitz' THEN INTERVAL '1 minute'
         WHEN p_mode = 'sprint' THEN INTERVAL '2 minutes'
         ELSE INTERVAL '3 minutes'
    END,
    jsonb_build_object('mode', p_mode)
  );
  v_scheduled_count := v_scheduled_count + 1;

  -- AI Tea Posts
  INSERT INTO game_events (game_id, event_type, scheduled_for, priority, is_recurring, recurring_interval, payload)
  VALUES (
    p_game_id, 'ai_tea_posts',
    v_game_start + (v_template.ai_tea_frequency_minutes * INTERVAL '1 minute'),
    CASE WHEN p_mode = 'blitz' THEN 7 ELSE 4 END,
    true,
    (v_template.ai_tea_frequency_minutes * INTERVAL '1 minute'),
    jsonb_build_object('mode', p_mode)
  );
  v_scheduled_count := v_scheduled_count + 1;

  -- AI Link-Ups
  INSERT INTO game_events (game_id, event_type, scheduled_for, priority, is_recurring, recurring_interval, payload)
  VALUES (
    p_game_id, 'ai_link_ups',
    v_game_start + (v_template.ai_linkup_frequency_minutes * INTERVAL '1 minute'),
    CASE WHEN p_mode = 'blitz' THEN 7 ELSE 5 END,
    true,
    (v_template.ai_linkup_frequency_minutes * INTERVAL '1 minute'),
    jsonb_build_object('mode', p_mode)
  );
  v_scheduled_count := v_scheduled_count + 1;

  -- AI Director
  INSERT INTO game_events (game_id, event_type, scheduled_for, priority, is_recurring, recurring_interval, payload)
  VALUES (
    p_game_id, 'ai_director_run',
    v_game_start + (v_template.ai_director_frequency_minutes * INTERVAL '1 minute'),
    CASE WHEN p_mode = 'blitz' THEN 8 ELSE 6 END,
    true,
    (v_template.ai_director_frequency_minutes * INTERVAL '1 minute'),
    jsonb_build_object('mode', p_mode)
  );
  v_scheduled_count := v_scheduled_count + 1;

  -- Cleanup (daily for weekly, every 6hr for blitz, every 12hr for sprint)
  INSERT INTO game_events (game_id, event_type, scheduled_for, priority, is_recurring, recurring_interval, payload)
  VALUES (
    p_game_id, 'cleanup',
    v_game_start + INTERVAL '3 hours',
    2,
    true,
    CASE WHEN p_mode = 'blitz' THEN INTERVAL '6 hours'
         WHEN p_mode = 'sprint' THEN INTERVAL '12 hours'
         ELSE INTERVAL '24 hours'
    END,
    jsonb_build_object('mode', p_mode)
  );
  v_scheduled_count := v_scheduled_count + 1;

  -- =============================================
  -- Schedule mode-specific gameplay events
  -- =============================================

  IF p_mode = 'weekly' THEN
    -- Schedule first week events (subsequent weeks chained via schedule_next_week_events)
    -- Lobby fill immediately
    INSERT INTO game_events (game_id, event_type, scheduled_for, priority, payload)
    VALUES (p_game_id, 'lobby_fill', v_game_start, 8,
            jsonb_build_object('mode', 'weekly'));
    v_scheduled_count := v_scheduled_count + 1;

    -- Lobby check (recurring every minute during lobby)
    INSERT INTO game_events (game_id, event_type, scheduled_for, priority, is_recurring, recurring_interval, payload)
    VALUES (p_game_id, 'lobby_check', v_game_start + INTERVAL '1 minute', 7, true, INTERVAL '1 minute',
            jsonb_build_object('mode', 'weekly'));
    v_scheduled_count := v_scheduled_count + 1;

    -- Schedule week 1 events (offset from game start + 48hr lobby)
    v_scheduled_count := v_scheduled_count + schedule_next_week_events(p_game_id, 1, v_game_start + INTERVAL '48 hours');

    -- Game end (10 weeks + 48hr lobby)
    INSERT INTO game_events (game_id, event_type, scheduled_for, priority, payload)
    VALUES (p_game_id, 'game_end',
            v_game_start + INTERVAL '48 hours' + (10 * INTERVAL '7 days'),
            9, jsonb_build_object('mode', 'weekly', 'reason', 'season_complete'));
    v_scheduled_count := v_scheduled_count + 1;

  ELSIF p_mode = 'blitz' THEN
    -- ACT 1: Alliance Hour (0-4hr)
    INSERT INTO game_events (game_id, event_type, scheduled_for, priority, payload)
    VALUES
      (p_game_id, 'lobby_fill', v_game_start, 9,
       jsonb_build_object('mode', 'blitz')),
      (p_game_id, 'game_start', v_game_start + INTERVAL '15 minutes', 9,
       jsonb_build_object('mode', 'blitz', 'act', 1)),
      (p_game_id, 'scenario_distribute', v_game_start + INTERVAL '30 minutes', 8,
       jsonb_build_object('mode', 'blitz', 'act', 1, 'deadline_hours', 1)),
      (p_game_id, 'queen_selection', v_game_start + INTERVAL '1 hour', 8,
       jsonb_build_object('mode', 'blitz', 'act', 1));
    v_scheduled_count := v_scheduled_count + 4;

    -- ACT 2: Betrayal Hour (4-12hr)
    INSERT INTO game_events (game_id, event_type, scheduled_for, priority, payload)
    VALUES
      (p_game_id, 'scenario_distribute', v_game_start + INTERVAL '4 hours', 8,
       jsonb_build_object('mode', 'blitz', 'act', 2, 'deadline_hours', 1)),
      (p_game_id, 'scenario_distribute', v_game_start + INTERVAL '6 hours', 8,
       jsonb_build_object('mode', 'blitz', 'act', 2, 'deadline_hours', 1)),
      (p_game_id, 'hot_seat_start', v_game_start + INTERVAL '5 hours', 8,
       jsonb_build_object('mode', 'blitz', 'nomination_hours', 1, 'vote_hours', 2)),
      (p_game_id, 'voting_open', v_game_start + INTERVAL '8 hours', 9,
       jsonb_build_object('mode', 'blitz', 'voting_hours', 2));
    v_scheduled_count := v_scheduled_count + 4;

    -- ACT 3: Final Hour (12-24hr)
    INSERT INTO game_events (game_id, event_type, scheduled_for, priority, payload)
    VALUES
      (p_game_id, 'voting_close', v_game_start + INTERVAL '12 hours', 9,
       jsonb_build_object('mode', 'blitz', 'act', 3)),
      (p_game_id, 'elimination_announce', v_game_start + INTERVAL '12 hours 30 minutes', 10,
       jsonb_build_object('mode', 'blitz', 'act', 3)),
      (p_game_id, 'scenario_distribute', v_game_start + INTERVAL '14 hours', 8,
       jsonb_build_object('mode', 'blitz', 'act', 3, 'deadline_hours', 1, 'finale_scenario', true)),
      (p_game_id, 'voting_open', v_game_start + INTERVAL '18 hours', 9,
       jsonb_build_object('mode', 'blitz', 'act', 3, 'voting_hours', 2, 'finale_vote', true)),
      (p_game_id, 'voting_close', v_game_start + INTERVAL '22 hours', 9,
       jsonb_build_object('mode', 'blitz', 'act', 3, 'finale_vote', true)),
      (p_game_id, 'game_end', v_game_start + INTERVAL '24 hours', 10,
       jsonb_build_object('mode', 'blitz', 'reason', 'blitz_complete'));
    v_scheduled_count := v_scheduled_count + 6;

  ELSIF p_mode = 'sprint' THEN
    -- DAY 1: Alliance Day (0-24hr)
    INSERT INTO game_events (game_id, event_type, scheduled_for, priority, payload)
    VALUES
      (p_game_id, 'lobby_fill', v_game_start, 9,
       jsonb_build_object('mode', 'sprint')),
      (p_game_id, 'game_start', v_game_start + INTERVAL '30 minutes', 9,
       jsonb_build_object('mode', 'sprint', 'day', 1)),
      (p_game_id, 'scenario_distribute', v_game_start + INTERVAL '2 hours', 8,
       jsonb_build_object('mode', 'sprint', 'day', 1, 'deadline_hours', 4)),
      (p_game_id, 'queen_selection', v_game_start + INTERVAL '6 hours', 8,
       jsonb_build_object('mode', 'sprint', 'day', 1)),
      (p_game_id, 'scenario_distribute', v_game_start + INTERVAL '12 hours', 8,
       jsonb_build_object('mode', 'sprint', 'day', 1, 'deadline_hours', 4)),
      (p_game_id, 'scenario_distribute', v_game_start + INTERVAL '18 hours', 8,
       jsonb_build_object('mode', 'sprint', 'day', 1, 'deadline_hours', 4));
    v_scheduled_count := v_scheduled_count + 6;

    -- DAY 2: Hot Seat Day (24-48hr)
    INSERT INTO game_events (game_id, event_type, scheduled_for, priority, payload)
    VALUES
      (p_game_id, 'scenario_distribute', v_game_start + INTERVAL '26 hours', 8,
       jsonb_build_object('mode', 'sprint', 'day', 2, 'deadline_hours', 4)),
      (p_game_id, 'hot_seat_start', v_game_start + INTERVAL '28 hours', 8,
       jsonb_build_object('mode', 'sprint', 'nomination_hours', 2, 'vote_hours', 4)),
      (p_game_id, 'voting_open', v_game_start + INTERVAL '34 hours', 9,
       jsonb_build_object('mode', 'sprint', 'day', 2, 'voting_hours', 6)),
      (p_game_id, 'voting_close', v_game_start + INTERVAL '42 hours', 9,
       jsonb_build_object('mode', 'sprint', 'day', 2)),
      (p_game_id, 'elimination_announce', v_game_start + INTERVAL '43 hours', 10,
       jsonb_build_object('mode', 'sprint', 'day', 2)),
      (p_game_id, 'queen_selection', v_game_start + INTERVAL '44 hours', 8,
       jsonb_build_object('mode', 'sprint', 'day', 2));
    v_scheduled_count := v_scheduled_count + 6;

    -- DAY 3: Finale Day (48-72hr)
    INSERT INTO game_events (game_id, event_type, scheduled_for, priority, payload)
    VALUES
      (p_game_id, 'scenario_distribute', v_game_start + INTERVAL '50 hours', 8,
       jsonb_build_object('mode', 'sprint', 'day', 3, 'deadline_hours', 4, 'finale_scenario', true)),
      (p_game_id, 'voting_open', v_game_start + INTERVAL '56 hours', 9,
       jsonb_build_object('mode', 'sprint', 'day', 3, 'voting_hours', 8, 'finale_vote', true)),
      (p_game_id, 'voting_close', v_game_start + INTERVAL '66 hours', 9,
       jsonb_build_object('mode', 'sprint', 'day', 3, 'finale_vote', true)),
      (p_game_id, 'elimination_announce', v_game_start + INTERVAL '67 hours', 10,
       jsonb_build_object('mode', 'sprint', 'day', 3)),
      (p_game_id, 'game_end', v_game_start + INTERVAL '72 hours', 10,
       jsonb_build_object('mode', 'sprint', 'reason', 'sprint_complete'));
    v_scheduled_count := v_scheduled_count + 5;

  ELSIF p_mode = 'party' THEN
    -- =============================================
    -- PARTY MODE: 35 minutes, 6 rounds of 5 min each
    -- 20 players → 3 eliminated per round → 2 survive → highest score wins
    -- =============================================

    -- OUTSIDE THE MANSION (0:00 - 5:00)
    -- Fill lobby immediately, start game, first scenario, alliances fly
    INSERT INTO game_events (game_id, event_type, scheduled_for, priority, payload)
    VALUES
      (p_game_id, 'lobby_fill', v_game_start, 10,
       jsonb_build_object('mode', 'party')),
      (p_game_id, 'game_start', v_game_start + INTERVAL '10 seconds', 10,
       jsonb_build_object('mode', 'party', 'phase', 'outside_mansion')),
      (p_game_id, 'scenario_distribute', v_game_start + INTERVAL '30 seconds', 9,
       jsonb_build_object('mode', 'party', 'phase', 'outside_mansion', 'deadline_minutes', 4)),
      (p_game_id, 'ai_link_ups', v_game_start + INTERVAL '15 seconds', 8,
       jsonb_build_object('mode', 'party', 'phase', 'outside_mansion')),
      (p_game_id, 'ai_tea_posts', v_game_start + INTERVAL '1 minute', 8,
       jsonb_build_object('mode', 'party', 'phase', 'outside_mansion'));
    v_scheduled_count := v_scheduled_count + 5;

    -- AI agent processor: every 30 seconds for party mode (override the one above)
    UPDATE game_events
    SET recurring_interval = INTERVAL '30 seconds',
        priority = 9
    WHERE game_id = p_game_id
      AND event_type = 'ai_agent_process'
      AND status = 'scheduled';

    -- ROUND 1 through ROUND 6 (5:00 - 35:00)
    -- Each round: queen → scenario → random event → voting → elimination
    FOR i IN 1..6 LOOP
      DECLARE
        v_round_start INTERVAL := (5 + ((i - 1) * 5)) * INTERVAL '1 minute';
      BEGIN
        -- Round start marker + new Queen
        INSERT INTO game_events (game_id, event_type, scheduled_for, priority, payload)
        VALUES (
          p_game_id, 'party_round',
          v_game_start + v_round_start,
          10,
          jsonb_build_object('mode', 'party', 'round', i, 'total_rounds', 6)
        );
        v_scheduled_count := v_scheduled_count + 1;

        -- Queen selection (0:00 into round)
        INSERT INTO game_events (game_id, event_type, scheduled_for, priority, payload)
        VALUES (
          p_game_id, 'queen_selection',
          v_game_start + v_round_start,
          9,
          jsonb_build_object('mode', 'party', 'round', i)
        );
        v_scheduled_count := v_scheduled_count + 1;

        -- Scenario drops (0:30 into round)
        INSERT INTO game_events (game_id, event_type, scheduled_for, priority, payload)
        VALUES (
          p_game_id, 'scenario_distribute',
          v_game_start + v_round_start + INTERVAL '30 seconds',
          9,
          jsonb_build_object('mode', 'party', 'round', i, 'deadline_minutes', 2)
        );
        v_scheduled_count := v_scheduled_count + 1;

        -- Random event (1:00 into round) - skip round 6 for cleaner finale
        IF i < 6 THEN
          INSERT INTO game_events (game_id, event_type, scheduled_for, priority, payload)
          VALUES (
            p_game_id, 'random_event',
            v_game_start + v_round_start + INTERVAL '1 minute',
            8,
            jsonb_build_object('mode', 'party', 'round', i)
          );
          v_scheduled_count := v_scheduled_count + 1;
        END IF;

        -- AI tea posts (1:30 into round - drama erupts)
        INSERT INTO game_events (game_id, event_type, scheduled_for, priority, payload)
        VALUES (
          p_game_id, 'ai_tea_posts',
          v_game_start + v_round_start + INTERVAL '90 seconds',
          8,
          jsonb_build_object('mode', 'party', 'round', i)
        );
        v_scheduled_count := v_scheduled_count + 1;

        -- Voting opens (3:00 into round)
        INSERT INTO game_events (game_id, event_type, scheduled_for, priority, payload)
        VALUES (
          p_game_id, 'voting_open',
          v_game_start + v_round_start + INTERVAL '3 minutes',
          9,
          jsonb_build_object('mode', 'party', 'round', i, 'voting_minutes', 1.5)
        );
        v_scheduled_count := v_scheduled_count + 1;

        -- Voting closes (4:30 into round)
        INSERT INTO game_events (game_id, event_type, scheduled_for, priority, payload)
        VALUES (
          p_game_id, 'voting_close',
          v_game_start + v_round_start + INTERVAL '4 minutes 30 seconds',
          9,
          jsonb_build_object('mode', 'party', 'round', i)
        );
        v_scheduled_count := v_scheduled_count + 1;

        -- ELIMINATION: 3 cast eliminated (4:45 into round)
        INSERT INTO game_events (game_id, event_type, scheduled_for, priority, payload)
        VALUES (
          p_game_id, 'party_elimination',
          v_game_start + v_round_start + INTERVAL '4 minutes 45 seconds',
          10,
          jsonb_build_object('mode', 'party', 'round', i, 'eliminate_count', 3)
        );
        v_scheduled_count := v_scheduled_count + 1;
      END;
    END LOOP;

    -- GAME END (35:00) - crown the winner
    INSERT INTO game_events (game_id, event_type, scheduled_for, priority, payload)
    VALUES (
      p_game_id, 'game_end',
      v_game_start + INTERVAL '35 minutes',
      10,
      jsonb_build_object('mode', 'party', 'reason', 'party_complete', 'crown_highest_score', true)
    );
    v_scheduled_count := v_scheduled_count + 1;

  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'game_id', p_game_id,
    'mode', p_mode,
    'events_scheduled', v_scheduled_count,
    'game_start', v_game_start
  );
END;
$$;

-- ============================================================================
-- 3. schedule_next_week_events() - Chain weekly events
-- ============================================================================
CREATE OR REPLACE FUNCTION public.schedule_next_week_events(
  p_game_id UUID,
  p_week INTEGER,
  p_week_start TIMESTAMPTZ DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_week_start TIMESTAMPTZ;
  v_count INTEGER := 0;
  v_game RECORD;
BEGIN
  -- Get game details
  SELECT * INTO v_game
  FROM mm_games WHERE id = p_game_id;

  IF NOT FOUND OR v_game.status NOT IN ('active', 'final_three', 'finale') THEN
    RETURN 0;
  END IF;

  -- Check if we've exceeded 10 weeks (season complete)
  IF p_week > 10 THEN
    -- Schedule game end instead
    INSERT INTO game_events (game_id, event_type, scheduled_for, priority, payload)
    VALUES (p_game_id, 'game_end', COALESCE(p_week_start, NOW()), 10,
            jsonb_build_object('mode', 'weekly', 'reason', 'season_complete', 'final_week', p_week - 1));
    RETURN 1;
  END IF;

  -- Calculate week start (use provided or derive from game start + weeks elapsed)
  v_week_start := COALESCE(
    p_week_start,
    v_game.started_at + ((p_week - 1) * INTERVAL '7 days')
  );

  -- Weekly schedule (relative to week start = Sunday midnight):
  -- Sunday (Day 0): Queen selection + scenarios
  INSERT INTO game_events (game_id, event_type, scheduled_for, priority, payload)
  VALUES (
    p_game_id, 'queen_selection',
    v_week_start + INTERVAL '1 hour',  -- Sunday 1:00 AM
    8,
    jsonb_build_object('mode', 'weekly', 'week', p_week)
  );
  v_count := v_count + 1;

  -- Monday: Scenarios distributed
  INSERT INTO game_events (game_id, event_type, scheduled_for, priority, payload)
  VALUES (
    p_game_id, 'scenario_distribute',
    v_week_start + INTERVAL '1 day 14 hours',  -- Monday 2:00 PM
    7,
    jsonb_build_object('mode', 'weekly', 'week', p_week, 'deadline_hours', 120)
  );
  v_count := v_count + 1;

  -- Saturday: Hot seat
  INSERT INTO game_events (game_id, event_type, scheduled_for, priority, payload)
  VALUES (
    p_game_id, 'hot_seat_start',
    v_week_start + INTERVAL '6 days 17 hours',  -- Saturday 5:00 PM
    8,
    jsonb_build_object('mode', 'weekly', 'week', p_week, 'nomination_hours', 4, 'vote_hours', 12)
  );
  v_count := v_count + 1;

  -- Next Sunday: Voting close + elimination + next week chain
  -- Voting opens Friday (implicit via hot seat flow), closes Sunday
  INSERT INTO game_events (game_id, event_type, scheduled_for, priority, payload)
  VALUES (
    p_game_id, 'voting_open',
    v_week_start + INTERVAL '5 days',  -- Friday midnight
    8,
    jsonb_build_object('mode', 'weekly', 'week', p_week, 'voting_hours', 48)
  );
  v_count := v_count + 1;

  INSERT INTO game_events (game_id, event_type, scheduled_for, priority, payload)
  VALUES (
    p_game_id, 'voting_close',
    v_week_start + INTERVAL '7 days',  -- Next Sunday midnight
    9,
    jsonb_build_object('mode', 'weekly', 'week', p_week)
  );
  v_count := v_count + 1;

  -- Elimination announcement (Sunday 12:30 AM = next week start + 30min)
  INSERT INTO game_events (game_id, event_type, scheduled_for, priority, payload)
  VALUES (
    p_game_id, 'elimination_announce',
    v_week_start + INTERVAL '7 days 30 minutes',  -- Next Sunday 12:30 AM
    10,
    jsonb_build_object('mode', 'weekly', 'week', p_week, 'chain_next_week', true)
  );
  v_count := v_count + 1;

  RETURN v_count;
END;
$$;

-- ============================================================================
-- 4. chain_next_week() - Called after elimination to schedule next week
-- ============================================================================
CREATE OR REPLACE FUNCTION public.chain_next_week(p_game_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_game RECORD;
  v_next_week INTEGER;
  v_count INTEGER;
BEGIN
  SELECT * INTO v_game FROM mm_games WHERE id = p_game_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Game not found');
  END IF;

  v_next_week := COALESCE(v_game.current_week, 1) + 1;

  -- Schedule next week's events starting from now
  v_count := schedule_next_week_events(p_game_id, v_next_week, NOW());

  -- Update game week
  UPDATE mm_games
  SET current_week = v_next_week,
      current_phase = 'gameplay_week_' || v_next_week
  WHERE id = p_game_id;

  RETURN jsonb_build_object(
    'success', true,
    'next_week', v_next_week,
    'events_scheduled', v_count
  );
END;
$$;

-- ============================================================================
-- 5. cancel_game_events() - Cancel all pending events for a game
-- ============================================================================
CREATE OR REPLACE FUNCTION public.cancel_game_events(p_game_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_count INTEGER;
BEGIN
  UPDATE game_events
  SET status = 'cancelled'
  WHERE game_id = p_game_id
    AND status IN ('scheduled', 'processing');

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

-- ============================================================================
-- 6. get_game_event_timeline() - View upcoming events for a game
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_game_event_timeline(
  p_game_id UUID,
  p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
  event_id UUID,
  event_type TEXT,
  status TEXT,
  scheduled_for TIMESTAMPTZ,
  priority INTEGER,
  is_recurring BOOLEAN,
  payload JSONB
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
  RETURN QUERY
  SELECT ge.id, ge.event_type, ge.status, ge.scheduled_for,
         ge.priority, ge.is_recurring, ge.payload
  FROM game_events ge
  WHERE ge.game_id = p_game_id
    AND ge.status IN ('scheduled', 'processing')
  ORDER BY ge.scheduled_for ASC
  LIMIT p_limit;
END;
$$;

-- ============================================================================
-- 7. Party Mode: Initialize leaderboard for all cast members
-- ============================================================================
CREATE OR REPLACE FUNCTION public.init_party_leaderboard(p_game_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_count INTEGER;
BEGIN
  INSERT INTO party_leaderboard (game_id, cast_member_id)
  SELECT p_game_id, gc.cast_member_id
  FROM mm_game_cast gc
  WHERE gc.game_id = p_game_id
    AND gc.status = 'active'
  ON CONFLICT (game_id, cast_member_id) DO NOTHING;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

-- ============================================================================
-- 8. Party Mode: Award points to a cast member
-- ============================================================================
CREATE OR REPLACE FUNCTION public.party_award_points(
  p_game_id UUID,
  p_cast_member_id UUID,
  p_action TEXT,
  p_points INTEGER,
  p_round INTEGER DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_new_total INTEGER;
BEGIN
  -- Log the score change
  INSERT INTO party_score_log (game_id, cast_member_id, action, points, round_number)
  VALUES (p_game_id, p_cast_member_id, p_action, p_points, p_round);

  -- Update the appropriate column on leaderboard
  CASE p_action
    WHEN 'alliance_formed' THEN
      UPDATE party_leaderboard SET alliance_points = alliance_points + p_points, updated_at = NOW()
      WHERE game_id = p_game_id AND cast_member_id = p_cast_member_id;
    WHEN 'drama', 'tea_room_post', 'started_beef' THEN
      UPDATE party_leaderboard SET drama_score = drama_score + p_points, updated_at = NOW()
      WHERE game_id = p_game_id AND cast_member_id = p_cast_member_id;
    WHEN 'scenario_response' THEN
      UPDATE party_leaderboard SET scenario_points = scenario_points + p_points, updated_at = NOW()
      WHERE game_id = p_game_id AND cast_member_id = p_cast_member_id;
    WHEN 'event_win' THEN
      UPDATE party_leaderboard SET event_wins = event_wins + 1, updated_at = NOW()
      WHERE game_id = p_game_id AND cast_member_id = p_cast_member_id;
    WHEN 'voice_note' THEN
      UPDATE party_leaderboard SET voice_note_points = voice_note_points + p_points, updated_at = NOW()
      WHERE game_id = p_game_id AND cast_member_id = p_cast_member_id;
    WHEN 'tea_post' THEN
      UPDATE party_leaderboard SET tea_room_points = tea_room_points + p_points, updated_at = NOW()
      WHERE game_id = p_game_id AND cast_member_id = p_cast_member_id;
    WHEN 'survived_round' THEN
      UPDATE party_leaderboard SET survival_points = survival_points + p_points, updated_at = NOW()
      WHERE game_id = p_game_id AND cast_member_id = p_cast_member_id;
    WHEN 'crowned_queen' THEN
      UPDATE party_leaderboard SET queen_points = queen_points + p_points, updated_at = NOW()
      WHERE game_id = p_game_id AND cast_member_id = p_cast_member_id;
    ELSE
      UPDATE party_leaderboard SET drama_score = drama_score + p_points, updated_at = NOW()
      WHERE game_id = p_game_id AND cast_member_id = p_cast_member_id;
  END CASE;

  -- Get new total
  SELECT total_score INTO v_new_total
  FROM party_leaderboard
  WHERE game_id = p_game_id AND cast_member_id = p_cast_member_id;

  RETURN jsonb_build_object(
    'cast_member_id', p_cast_member_id,
    'action', p_action,
    'points', p_points,
    'new_total', v_new_total
  );
END;
$$;

-- ============================================================================
-- 9. Party Mode: Get leaderboard
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_party_leaderboard(p_game_id UUID)
RETURNS TABLE (
  rank BIGINT,
  cast_member_id UUID,
  display_name TEXT,
  archetype TEXT,
  total_score INTEGER,
  alliance_points INTEGER,
  drama_score INTEGER,
  scenario_points INTEGER,
  event_wins INTEGER,
  survival_points INTEGER,
  is_eliminated BOOLEAN
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
  RETURN QUERY
  SELECT
    ROW_NUMBER() OVER (ORDER BY pl.total_score DESC) AS rank,
    pl.cast_member_id,
    cm.display_name,
    cm.archetype,
    pl.total_score,
    pl.alliance_points,
    pl.drama_score,
    pl.scenario_points,
    pl.event_wins,
    pl.survival_points,
    pl.is_eliminated
  FROM party_leaderboard pl
  JOIN cast_members cm ON cm.id = pl.cast_member_id
  WHERE pl.game_id = p_game_id
  ORDER BY pl.total_score DESC;
END;
$$;

-- ============================================================================
-- VERIFICATION
-- ============================================================================
SELECT 'process_game_events' AS func, TRUE AS exists
WHERE EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'process_game_events');

SELECT 'schedule_game_events' AS func, TRUE AS exists
WHERE EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'schedule_game_events');

SELECT 'schedule_next_week_events' AS func, TRUE AS exists
WHERE EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'schedule_next_week_events');
