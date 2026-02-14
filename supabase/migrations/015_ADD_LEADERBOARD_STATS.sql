-- =====================================================
-- ADD LEADERBOARD STATS TRACKING
-- =====================================================
-- Adds score columns and auto-update functions for live leaderboard data
-- Date: 2026-02-14
-- =====================================================

-- Add score columns to cast_members if they don't exist
ALTER TABLE public.cast_members
  ADD COLUMN IF NOT EXISTS drama_score INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS influence_score INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS activity_count INTEGER DEFAULT 0;

-- Create index for faster leaderboard queries
CREATE INDEX IF NOT EXISTS idx_cast_members_drama_score ON public.cast_members(drama_score DESC);
CREATE INDEX IF NOT EXISTS idx_cast_members_influence_score ON public.cast_members(influence_score DESC);

-- =====================================================
-- FUNCTION: Calculate and update cast member scores
-- =====================================================
CREATE OR REPLACE FUNCTION update_cast_member_scores(p_cast_member_id UUID, p_game_id UUID DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  v_relationship_count INTEGER := 0;
  v_voice_plays INTEGER := 0;
  v_scenario_responses INTEGER := 0;
  v_drama_score INTEGER := 0;
  v_influence_score INTEGER := 0;
  v_activity_count INTEGER := 0;
BEGIN
  -- Count relationships (alliances + rivalries)
  SELECT COUNT(*) INTO v_relationship_count
  FROM mm_relationship_edges
  WHERE (cast_member_a_id = p_cast_member_id OR cast_member_b_id = p_cast_member_id)
    AND (p_game_id IS NULL OR game_id = p_game_id);

  -- Count voice introductions (1 if exists, 0 if not)
  SELECT COUNT(*) INTO v_voice_plays
  FROM mm_voice_introductions
  WHERE cast_member_id = p_cast_member_id
    AND moderation_status = 'approved';

  -- Count scenario responses
  SELECT COUNT(*) INTO v_scenario_responses
  FROM scenario_responses
  WHERE cast_member_id = p_cast_member_id;

  -- Calculate drama score: relationships × 10 + voice plays × 5 + scenarios × 15
  v_drama_score := (v_relationship_count * 10) + (v_voice_plays * 5) + (v_scenario_responses * 15);

  -- Calculate influence score: relationships × 8 + scenarios × 12
  v_influence_score := (v_relationship_count * 8) + (v_scenario_responses * 12);

  -- Total activity count
  v_activity_count := v_relationship_count + v_voice_plays + v_scenario_responses;

  -- Update cast member scores
  UPDATE cast_members
  SET
    drama_score = v_drama_score,
    influence_score = v_influence_score,
    activity_count = v_activity_count,
    updated_at = NOW()
  WHERE id = p_cast_member_id;

  -- Return stats
  RETURN jsonb_build_object(
    'cast_member_id', p_cast_member_id,
    'drama_score', v_drama_score,
    'influence_score', v_influence_score,
    'activity_count', v_activity_count,
    'relationships', v_relationship_count,
    'voice_plays', v_voice_plays,
    'scenario_responses', v_scenario_responses
  );
END;
$$;

-- =====================================================
-- TRIGGER: Auto-update scores when voice intro is created/approved
-- =====================================================
CREATE OR REPLACE FUNCTION trigger_update_scores_on_voice_intro()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM update_cast_member_scores(NEW.cast_member_id, NULL);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS voice_intro_update_scores ON mm_voice_introductions;
CREATE TRIGGER voice_intro_update_scores
  AFTER INSERT OR UPDATE OF moderation_status ON mm_voice_introductions
  FOR EACH ROW
  WHEN (NEW.moderation_status = 'approved')
  EXECUTE FUNCTION trigger_update_scores_on_voice_intro();

-- =====================================================
-- TRIGGER: Auto-update scores when relationship is created/updated
-- =====================================================
CREATE OR REPLACE FUNCTION trigger_update_scores_on_relationship()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- Update both cast members in the relationship
  PERFORM update_cast_member_scores(NEW.cast_member_a_id, NEW.game_id);
  PERFORM update_cast_member_scores(NEW.cast_member_b_id, NEW.game_id);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS relationship_update_scores ON mm_relationship_edges;
CREATE TRIGGER relationship_update_scores
  AFTER INSERT OR UPDATE ON mm_relationship_edges
  FOR EACH ROW
  EXECUTE FUNCTION trigger_update_scores_on_relationship();

-- =====================================================
-- TRIGGER: Auto-update scores when scenario is responded to
-- =====================================================
CREATE OR REPLACE FUNCTION trigger_update_scores_on_scenario_response()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM update_cast_member_scores(NEW.cast_member_id);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS scenario_response_update_scores ON scenario_responses;
CREATE TRIGGER scenario_response_update_scores
  AFTER INSERT ON scenario_responses
  FOR EACH ROW
  EXECUTE FUNCTION trigger_update_scores_on_scenario_response();

-- =====================================================
-- FUNCTION: Recalculate all scores for a game
-- =====================================================
CREATE OR REPLACE FUNCTION recalculate_game_scores(p_game_id UUID)
RETURNS TABLE(cast_member_id UUID, drama_score INTEGER, influence_score INTEGER)
LANGUAGE plpgsql
AS $$
BEGIN
  -- Update scores for all cast members in the game
  RETURN QUERY
  SELECT
    cm.id,
    (update_cast_member_scores(cm.id, p_game_id)->>'drama_score')::INTEGER,
    (update_cast_member_scores(cm.id, p_game_id)->>'influence_score')::INTEGER
  FROM cast_members cm
  INNER JOIN mm_game_cast gc ON gc.cast_member_id = cm.id
  WHERE gc.game_id = p_game_id;
END;
$$;

-- =====================================================
-- Grant permissions
-- =====================================================
GRANT EXECUTE ON FUNCTION update_cast_member_scores(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION recalculate_game_scores(UUID) TO authenticated;

-- =====================================================
-- Comments
-- =====================================================
COMMENT ON FUNCTION update_cast_member_scores IS 'Calculates and updates drama and influence scores for a cast member based on their activity';
COMMENT ON FUNCTION recalculate_game_scores IS 'Recalculates scores for all cast members in a specific game';
COMMENT ON COLUMN cast_members.drama_score IS 'Auto-calculated: relationships × 10 + voice plays × 5 + scenarios × 15';
COMMENT ON COLUMN cast_members.influence_score IS 'Auto-calculated: relationships × 8 + scenarios × 12';
COMMENT ON COLUMN cast_members.activity_count IS 'Total activity count across all categories';
