-- ============================================================================
-- PAUSE ALL CRON JOBS AND RESET GAMES
-- Run this to stop everything and prepare for fresh start
-- ============================================================================

-- STEP 1: PAUSE ALL CRON JOBS IMMEDIATELY
-- ============================================================================

UPDATE cron_jobs SET enabled = false WHERE enabled = true;

-- Verify all cron jobs are paused
SELECT
  name,
  schedule,
  enabled,
  last_run_at
FROM cron_jobs
ORDER BY name;

-- STEP 2: STOP ALL ACTIVE GAMES
-- ============================================================================

UPDATE mm_games
SET
  status = 'completed',
  ended_at = NOW()
WHERE status = 'active';

-- Verify all games are stopped
SELECT
  id,
  title,
  status,
  started_at,
  ended_at,
  current_round
FROM mm_games
ORDER BY created_at DESC
LIMIT 5;

-- STEP 3: CHECK WHAT WAS RUNNING
-- ============================================================================

-- Show recent AI agent activity
SELECT
  action_type,
  status,
  created_at,
  updated_at,
  error_message
FROM mm_ai_agent_queue
WHERE created_at > NOW() - INTERVAL '1 hour'
ORDER BY created_at DESC
LIMIT 20;

-- Show pending scenarios
SELECT
  id,
  title,
  status,
  deadline_at,
  created_at
FROM scenarios
WHERE game_id = '8f8d5946-271b-4664-91e4-5588954b0dab'
  AND status = 'active'
ORDER BY created_at DESC;

-- Show scenario responses received
SELECT
  s.title as scenario_title,
  cm.display_name as responder,
  sr.responded_at,
  sr.response_text IS NOT NULL as has_text,
  sr.voice_note_url IS NOT NULL as has_voice
FROM scenario_responses sr
JOIN scenarios s ON s.id = sr.scenario_id
JOIN cast_members cm ON cm.id = sr.cast_member_id
WHERE s.game_id = '8f8d5946-271b-4664-91e4-5588954b0dab'
ORDER BY sr.responded_at DESC
LIMIT 20;

-- STEP 4: CHECK USER'S CAST MEMBER STATUS
-- ============================================================================

-- Find user's cast member
SELECT
  cm.id,
  cm.display_name,
  cm.full_name,
  cm.archetype,
  cm.is_ai,
  gc.joined_at
FROM cast_members cm
LEFT JOIN mm_game_cast gc ON gc.cast_member_id = cm.id
WHERE cm.full_name ILIKE '%Justin%Lott%'
  OR cm.display_name ILIKE '%Justin%'
ORDER BY cm.created_at DESC;

-- Check if user is in the active game
SELECT
  cm.display_name,
  cm.is_ai,
  gc.joined_at,
  g.title as game_title,
  g.status as game_status
FROM mm_game_cast gc
JOIN cast_members cm ON cm.id = gc.cast_member_id
JOIN mm_games g ON g.id = gc.game_id
WHERE cm.full_name ILIKE '%Justin%Lott%'
  AND g.id = '8f8d5946-271b-4664-91e4-5588954b0dab';

-- STEP 5: CLEAN UP OLD GAME STATE (OPTIONAL)
-- ============================================================================
-- Uncomment these if you want to completely reset the game data

/*
-- Delete AI queue entries for this game
DELETE FROM mm_ai_agent_queue
WHERE game_id = '8f8d5946-271b-4664-91e4-5588954b0dab';

-- Delete scenario responses
DELETE FROM scenario_responses
WHERE scenario_id IN (
  SELECT id FROM scenarios
  WHERE game_id = '8f8d5946-271b-4664-91e4-5588954b0dab'
);

-- Delete scenarios
DELETE FROM scenarios
WHERE game_id = '8f8d5946-271b-4664-91e4-5588954b0dab';

-- Close all voting rounds
UPDATE mm_voting_rounds
SET status = 'closed'
WHERE game_id = '8f8d5946-271b-4664-91e4-5588954b0dab'
  AND status = 'active';

-- Remove cast from game (but keep cast members)
DELETE FROM mm_game_cast
WHERE game_id = '8f8d5946-271b-4664-91e4-5588954b0dab';
*/

-- ============================================================================
-- RESULT SUMMARY
-- ============================================================================

SELECT
  '✅ All cron jobs paused' as status,
  COUNT(*) as total_cron_jobs
FROM cron_jobs;

SELECT
  '✅ All games stopped' as status,
  COUNT(*) as total_games
FROM mm_games
WHERE status = 'completed';

SELECT
  '🎮 Ready for fresh start' as message;
