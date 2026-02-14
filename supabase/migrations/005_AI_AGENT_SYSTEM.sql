-- ============================================================================
-- MANSION MAYHEM - AI AGENT SYSTEM
-- ============================================================================
-- Tables and functions to power AI character behavior
-- Hybrid model: Haiku for chat, Sonnet for strategy
-- ============================================================================

-- ============================================================================
-- 1. AI_ACTION_QUEUE - Pending AI Actions
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.ai_action_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id UUID NOT NULL REFERENCES public.mm_games(id) ON DELETE CASCADE,
  cast_member_id UUID NOT NULL REFERENCES public.cast_members(id) ON DELETE CASCADE,

  action_type TEXT NOT NULL CHECK (action_type IN (
    'respond_scenario',
    'send_chat_message',
    'form_alliance',
    'vote',
    'spill_tea',
    'react_to_event'
  )),

  -- Context for the action
  context JSONB NOT NULL, -- Contains scenario_id, room_id, etc.
  priority INTEGER DEFAULT 5, -- 1-10, higher = more urgent

  -- Model to use for this action
  ai_model TEXT NOT NULL DEFAULT 'haiku' CHECK (ai_model IN ('haiku', 'sonnet')),

  -- Processing status
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
  processed_at TIMESTAMPTZ,
  error_message TEXT,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ai_action_queue_status ON public.ai_action_queue(status);
CREATE INDEX IF NOT EXISTS idx_ai_action_queue_cast_member ON public.ai_action_queue(cast_member_id);
CREATE INDEX IF NOT EXISTS idx_ai_action_queue_priority ON public.ai_action_queue(priority DESC);
CREATE INDEX IF NOT EXISTS idx_ai_action_queue_created ON public.ai_action_queue(created_at);

-- ============================================================================
-- 2. AI_ACTIVITY_LOG - Track AI Actions for Cost Monitoring
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.ai_activity_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cast_member_id UUID NOT NULL REFERENCES public.cast_members(id) ON DELETE CASCADE,
  game_id UUID NOT NULL REFERENCES public.mm_games(id) ON DELETE CASCADE,

  action_type TEXT NOT NULL,
  ai_model TEXT NOT NULL, -- 'haiku' or 'sonnet'

  -- Token usage for cost tracking
  input_tokens INTEGER DEFAULT 0,
  output_tokens INTEGER DEFAULT 0,
  cached_tokens INTEGER DEFAULT 0,

  -- Cost calculation (in USD cents)
  estimated_cost_cents NUMERIC(10,4) DEFAULT 0,

  -- Response details
  response_id UUID, -- Links to scenario_response, mm_alliance_message, etc.
  response_preview TEXT, -- First 100 chars of response

  processing_time_ms INTEGER,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ai_activity_log_cast_member ON public.ai_activity_log(cast_member_id);
CREATE INDEX IF NOT EXISTS idx_ai_activity_log_game ON public.ai_activity_log(game_id);
CREATE INDEX IF NOT EXISTS idx_ai_activity_log_created ON public.ai_activity_log(created_at DESC);

-- ============================================================================
-- 3. AI_PERSONALITY_STATE - Track AI Relationship Memory
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.ai_personality_state (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cast_member_id UUID NOT NULL REFERENCES public.cast_members(id) ON DELETE CASCADE,
  game_id UUID NOT NULL REFERENCES public.mm_games(id) ON DELETE CASCADE,

  -- Memory of other players
  relationships JSONB DEFAULT '{}', -- { cast_member_id: { trust: 0-100, notes: "" } }

  -- Strategic state
  current_strategy TEXT, -- "lie low", "cause drama", "build alliances"
  target_player_id UUID REFERENCES public.cast_members(id) ON DELETE SET NULL,

  -- Emotional state
  mood TEXT DEFAULT 'neutral', -- affects chat tone
  drama_level INTEGER DEFAULT 5 CHECK (drama_level >= 0 AND drama_level <= 10),

  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE(game_id, cast_member_id)
);

CREATE INDEX IF NOT EXISTS idx_ai_personality_state_game ON public.ai_personality_state(game_id);

-- ============================================================================
-- 4. FUNCTIONS - Queue AI Actions
-- ============================================================================

-- Queue scenario response for AI
CREATE OR REPLACE FUNCTION public.queue_ai_scenario_response(
  p_scenario_id UUID,
  p_cast_member_id UUID
)
RETURNS UUID AS $$
DECLARE
  v_game_id UUID;
  v_action_id UUID;
BEGIN
  -- Get game_id from scenario
  SELECT game_id INTO v_game_id
  FROM scenarios WHERE id = p_scenario_id;

  -- Queue the action (use Sonnet for scenarios)
  INSERT INTO ai_action_queue (
    game_id,
    cast_member_id,
    action_type,
    context,
    priority,
    ai_model
  ) VALUES (
    v_game_id,
    p_cast_member_id,
    'respond_scenario',
    jsonb_build_object('scenario_id', p_scenario_id),
    8, -- High priority
    'sonnet'
  ) RETURNING id INTO v_action_id;

  RETURN v_action_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Queue chat message for AI
CREATE OR REPLACE FUNCTION public.queue_ai_chat_message(
  p_room_id UUID,
  p_cast_member_id UUID,
  p_context TEXT DEFAULT 'general_chat'
)
RETURNS UUID AS $$
DECLARE
  v_game_id UUID;
  v_action_id UUID;
BEGIN
  -- Get game_id from room
  SELECT game_id INTO v_game_id
  FROM mm_alliance_rooms WHERE id = p_room_id;

  -- Queue the action (use Haiku for chat)
  INSERT INTO ai_action_queue (
    game_id,
    cast_member_id,
    action_type,
    context,
    priority,
    ai_model
  ) VALUES (
    v_game_id,
    p_cast_member_id,
    'send_chat_message',
    jsonb_build_object('room_id', p_room_id, 'context', p_context),
    3, -- Lower priority
    'haiku'
  ) RETURNING id INTO v_action_id;

  RETURN v_action_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Queue alliance formation for AI
CREATE OR REPLACE FUNCTION public.queue_ai_alliance_decision(
  p_game_id UUID,
  p_cast_member_id UUID
)
RETURNS UUID AS $$
DECLARE
  v_action_id UUID;
BEGIN
  -- Queue the action (use Sonnet for strategy)
  INSERT INTO ai_action_queue (
    game_id,
    cast_member_id,
    action_type,
    context,
    priority,
    ai_model
  ) VALUES (
    p_game_id,
    p_cast_member_id,
    'form_alliance',
    jsonb_build_object('phase', 'alliance_lobby'),
    7, -- High priority
    'sonnet'
  ) RETURNING id INTO v_action_id;

  RETURN v_action_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 5. COST TRACKING VIEW
-- ============================================================================
CREATE OR REPLACE VIEW public.ai_cost_summary AS
SELECT
  game_id,
  DATE(created_at) as date,
  ai_model,
  COUNT(*) as action_count,
  SUM(input_tokens) as total_input_tokens,
  SUM(output_tokens) as total_output_tokens,
  SUM(estimated_cost_cents) / 100.0 as total_cost_usd
FROM ai_activity_log
GROUP BY game_id, DATE(created_at), ai_model
ORDER BY date DESC, game_id;

-- ============================================================================
-- 6. TRIGGER - Auto-queue AI scenarios
-- ============================================================================
CREATE OR REPLACE FUNCTION public.auto_queue_ai_scenarios()
RETURNS TRIGGER AS $$
BEGIN
  -- When a scenario is assigned to an AI character, queue response
  IF EXISTS (
    SELECT 1 FROM cast_members
    WHERE id = NEW.cast_member_id
      AND is_ai_player = true
  ) THEN
    PERFORM queue_ai_scenario_response(NEW.scenario_id, NEW.cast_member_id);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS auto_queue_ai_scenarios_trigger ON public.scenario_targets;
CREATE TRIGGER auto_queue_ai_scenarios_trigger
  AFTER INSERT ON public.scenario_targets
  FOR EACH ROW
  EXECUTE FUNCTION public.auto_queue_ai_scenarios();

-- ============================================================================
-- GRANTS
-- ============================================================================
GRANT EXECUTE ON FUNCTION public.queue_ai_scenario_response(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.queue_ai_chat_message(UUID, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.queue_ai_alliance_decision(UUID, UUID) TO authenticated;

-- ============================================================================
-- VERIFICATION
-- ============================================================================
DO $$
BEGIN
  RAISE NOTICE '✅ AI Agent System Created!';
  RAISE NOTICE 'Tables: ai_action_queue, ai_activity_log, ai_personality_state';
  RAISE NOTICE 'Functions: queue_ai_scenario_response, queue_ai_chat_message, queue_ai_alliance_decision';
  RAISE NOTICE 'Next: Deploy Edge Function for AI processing';
END $$;
