-- ============================================================================
-- AI ACTION QUEUE & TRIGGERS
-- Automatically queue AI actions when events happen
-- ============================================================================

-- Create ai_action_queue table if not exists
CREATE TABLE IF NOT EXISTS public.ai_action_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cast_member_id UUID NOT NULL REFERENCES public.cast_members(id) ON DELETE CASCADE,
  game_id UUID NOT NULL REFERENCES public.mm_games(id) ON DELETE CASCADE,
  action_type TEXT NOT NULL CHECK (action_type IN (
    'send_link_up_request',
    'respond_to_link_up',
    'create_voice_introduction',
    'post_tea_room',
    'respond_to_message',
    'respond_to_scenario',
    'make_alliance_decision'
  )),
  priority INTEGER NOT NULL DEFAULT 5, -- 1 (low) to 10 (high)
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
  context JSONB, -- Additional data needed for action
  error_message TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  processed_at TIMESTAMPTZ
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_ai_action_queue_status ON public.ai_action_queue(status);
CREATE INDEX IF NOT EXISTS idx_ai_action_queue_priority ON public.ai_action_queue(priority DESC);
CREATE INDEX IF NOT EXISTS idx_ai_action_queue_cast_member ON public.ai_action_queue(cast_member_id);
CREATE INDEX IF NOT EXISTS idx_ai_action_queue_created_at ON public.ai_action_queue(created_at);

-- Enable RLS
ALTER TABLE public.ai_action_queue ENABLE ROW LEVEL SECURITY;

-- Service role can do everything
DROP POLICY IF EXISTS "service_role_all" ON public.ai_action_queue;
CREATE POLICY "service_role_all" ON public.ai_action_queue
  FOR ALL TO service_role
  USING (true)
  WITH CHECK (true);

-- ============================================================================
-- TRIGGER 1: Queue voice introductions for new AI players
-- ============================================================================
CREATE OR REPLACE FUNCTION queue_ai_voice_introduction()
RETURNS TRIGGER AS $$
BEGIN
  -- Only for AI players joining a game
  IF EXISTS (
    SELECT 1 FROM cast_members cm
    WHERE cm.id = NEW.cast_member_id
      AND cm.is_ai_player = true
  ) THEN
    INSERT INTO ai_action_queue (cast_member_id, game_id, action_type, priority, context)
    VALUES (
      NEW.cast_member_id,
      NEW.game_id,
      'create_voice_introduction',
      8, -- High priority
      jsonb_build_object('trigger', 'game_join')
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_queue_ai_voice_intro ON mm_game_cast;
CREATE TRIGGER trigger_queue_ai_voice_intro
  AFTER INSERT ON mm_game_cast
  FOR EACH ROW
  EXECUTE FUNCTION queue_ai_voice_introduction();

-- ============================================================================
-- TRIGGER 2: Queue AI to send link-up requests (48 hours after game starts)
-- ============================================================================
CREATE OR REPLACE FUNCTION queue_ai_link_up_requests()
RETURNS void AS $$
DECLARE
  v_cast RECORD;
BEGIN
  -- Find AI players in games that are 48 hours into waiting_lobby
  FOR v_cast IN
    SELECT gc.cast_member_id, gc.game_id
    FROM mm_game_cast gc
    JOIN mm_games g ON g.id = gc.game_id
    JOIN cast_members cm ON cm.id = gc.cast_member_id
    WHERE cm.is_ai_player = true
      AND g.status = 'waiting_lobby'
      AND g.waiting_lobby_starts_at < NOW() - INTERVAL '48 hours'
      AND NOT EXISTS (
        -- Haven't sent a link-up request yet
        SELECT 1 FROM mm_link_up_requests lr
        WHERE lr.from_cast_member_id = gc.cast_member_id
          AND lr.game_id = gc.game_id
      )
      AND NOT EXISTS (
        -- Not already queued
        SELECT 1 FROM ai_action_queue aq
        WHERE aq.cast_member_id = gc.cast_member_id
          AND aq.action_type = 'send_link_up_request'
          AND aq.status IN ('pending', 'processing')
      )
  LOOP
    INSERT INTO ai_action_queue (cast_member_id, game_id, action_type, priority)
    VALUES (v_cast.cast_member_id, v_cast.game_id, 'send_link_up_request', 7);
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Schedule this to run every hour via cron (add to existing cron jobs)
SELECT cron.schedule(
  'queue_ai_link_ups',
  '0 * * * *', -- Every hour
  $$SELECT queue_ai_link_up_requests()$$
);

-- ============================================================================
-- TRIGGER 3: Queue AI to respond to link-up requests they receive
-- ============================================================================
CREATE OR REPLACE FUNCTION queue_ai_link_up_response()
RETURNS TRIGGER AS $$
DECLARE
  v_invited_id UUID;
BEGIN
  -- Queue response action for each invited AI player
  FOREACH v_invited_id IN ARRAY NEW.invited_cast_ids
  LOOP
    IF EXISTS (
      SELECT 1 FROM cast_members cm
      WHERE cm.id = v_invited_id
        AND cm.is_ai_player = true
    ) THEN
      INSERT INTO ai_action_queue (cast_member_id, game_id, action_type, priority, context)
      VALUES (
        v_invited_id,
        NEW.game_id,
        'respond_to_link_up',
        9, -- Very high priority - respond quickly
        jsonb_build_object('request_id', NEW.id)
      );
    END IF;
  END LOOP;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_queue_ai_link_up_response ON mm_link_up_requests;
CREATE TRIGGER trigger_queue_ai_link_up_response
  AFTER INSERT ON mm_link_up_requests
  FOR EACH ROW
  EXECUTE FUNCTION queue_ai_link_up_response();

-- ============================================================================
-- TRIGGER 4: Queue AI to respond to alliance chat messages
-- ============================================================================
CREATE OR REPLACE FUNCTION queue_ai_message_response()
RETURNS TRIGGER AS $$
DECLARE
  v_room RECORD;
  v_member_id UUID;
BEGIN
  -- Get alliance room details
  SELECT * INTO v_room
  FROM mm_alliance_rooms
  WHERE id = NEW.room_id;

  -- Queue response for each AI member in the room (except sender)
  FOREACH v_member_id IN ARRAY v_room.member_ids
  LOOP
    IF v_member_id != NEW.sender_cast_id
       AND EXISTS (
         SELECT 1 FROM cast_members cm
         WHERE cm.id = v_member_id
           AND cm.is_ai_player = true
       ) THEN
      -- Random delay 0-5 minutes to seem natural
      INSERT INTO ai_action_queue (cast_member_id, game_id, action_type, priority, context, created_at)
      VALUES (
        v_member_id,
        v_room.game_id,
        'respond_to_message',
        6, -- Medium priority
        jsonb_build_object('room_id', NEW.room_id, 'last_message', NEW.message),
        NOW() + (random() * interval '5 minutes') -- Natural delay
      );
    END IF;
  END LOOP;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_queue_ai_message_response ON mm_alliance_messages;
CREATE TRIGGER trigger_queue_ai_message_response
  AFTER INSERT ON mm_alliance_messages
  FOR EACH ROW
  EXECUTE FUNCTION queue_ai_message_response();

-- ============================================================================
-- TRIGGER 5: Queue AI to post tea room drama (randomly)
-- ============================================================================
CREATE OR REPLACE FUNCTION queue_ai_tea_room_posts()
RETURNS void AS $$
DECLARE
  v_cast RECORD;
BEGIN
  -- Find AI players in active games who might want to post tea
  FOR v_cast IN
    SELECT DISTINCT gc.cast_member_id, gc.game_id, cm.archetype
    FROM mm_game_cast gc
    JOIN mm_games g ON g.id = gc.game_id
    JOIN cast_members cm ON cm.id = gc.cast_member_id
    WHERE cm.is_ai_player = true
      AND g.status IN ('waiting_lobby', 'active_lobby', 'active')
      AND gc.status = 'active'
      -- Only post tea 20% of the time (keep it special)
      AND random() < 0.2
      -- Haven't posted tea in the last 6 hours
      AND NOT EXISTS (
        SELECT 1 FROM mm_confession_cards cc
        WHERE cc.cast_member_id = gc.cast_member_id
          AND cc.created_at > NOW() - INTERVAL '6 hours'
      )
      -- Not already queued
      AND NOT EXISTS (
        SELECT 1 FROM ai_action_queue aq
        WHERE aq.cast_member_id = gc.cast_member_id
          AND aq.action_type = 'post_tea_room'
          AND aq.status IN ('pending', 'processing')
      )
  LOOP
    -- Villains and wildcards post more drama
    IF v_cast.archetype IN ('villain', 'wildcard', 'troublemaker') THEN
      INSERT INTO ai_action_queue (cast_member_id, game_id, action_type, priority)
      VALUES (v_cast.cast_member_id, v_cast.game_id, 'post_tea_room', 4);
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Schedule tea room posts every 2 hours
SELECT cron.schedule(
  'queue_ai_tea_posts',
  '0 */2 * * *', -- Every 2 hours
  $$SELECT queue_ai_tea_room_posts()$$
);

-- ============================================================================
-- TRIGGER 6: Queue AI scenario responses (when scenarios are assigned)
-- ============================================================================
CREATE OR REPLACE FUNCTION queue_ai_scenario_response()
RETURNS TRIGGER AS $$
BEGIN
  -- If AI player assigned a scenario, queue response
  IF EXISTS (
    SELECT 1 FROM cast_members cm
    WHERE cm.id = NEW.cast_member_id
      AND cm.is_ai_player = true
  ) THEN
    INSERT INTO ai_action_queue (cast_member_id, game_id, action_type, priority, context)
    VALUES (
      NEW.cast_member_id,
      (SELECT game_id FROM scenarios WHERE id = NEW.scenario_id),
      'respond_to_scenario',
      10, -- Highest priority - scenarios are critical
      jsonb_build_object('scenario_id', NEW.scenario_id)
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_queue_ai_scenario_response ON scenario_targets;
CREATE TRIGGER trigger_queue_ai_scenario_response
  AFTER INSERT ON scenario_targets
  FOR EACH ROW
  EXECUTE FUNCTION queue_ai_scenario_response();

-- ============================================================================
-- CLEANUP FUNCTION: Remove old completed/failed actions
-- ============================================================================
CREATE OR REPLACE FUNCTION cleanup_ai_action_queue()
RETURNS void AS $$
BEGIN
  DELETE FROM ai_action_queue
  WHERE status IN ('completed', 'failed')
    AND processed_at < NOW() - INTERVAL '7 days';
END;
$$ LANGUAGE plpgsql;

-- Schedule cleanup daily at 3 AM
SELECT cron.schedule(
  'cleanup_ai_actions',
  '0 3 * * *',
  $$SELECT cleanup_ai_action_queue()$$
);

-- ============================================================================
-- VERIFICATION
-- ============================================================================
-- Check triggers created
SELECT
  trigger_name,
  event_object_table,
  action_statement
FROM information_schema.triggers
WHERE trigger_name LIKE 'trigger_queue_ai%'
ORDER BY trigger_name;

-- Check cron jobs
SELECT jobname, schedule, active
FROM cron.job
WHERE jobname LIKE '%ai%'
ORDER BY jobname;

-- Check action queue table
SELECT COUNT(*) as total_actions,
       status,
       action_type
FROM ai_action_queue
GROUP BY status, action_type
ORDER BY status, action_type;
