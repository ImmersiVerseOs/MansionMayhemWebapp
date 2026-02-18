-- ============================================================================
-- CHECK WHY USER ISN'T RECEIVING SCENARIOS
-- Diagnose scenario delivery issues
-- ============================================================================

-- STEP 1: FIND USER'S CAST MEMBER ID
-- ============================================================================

SELECT
  cm.id as cast_member_id,
  cm.display_name,
  cm.full_name,
  cm.email,
  cm.user_id,
  cm.is_ai,
  cm.archetype
FROM cast_members cm
WHERE cm.full_name ILIKE '%Justin%Lott%'
  OR cm.display_name ILIKE '%Justin%'
  OR cm.email ILIKE '%justin%'
ORDER BY cm.created_at DESC;

-- STEP 2: CHECK IF USER IS IN THE GAME
-- ============================================================================

SELECT
  gc.game_id,
  gc.cast_member_id,
  gc.joined_at,
  g.title as game_title,
  g.status as game_status,
  cm.display_name,
  cm.is_ai
FROM mm_game_cast gc
JOIN mm_games g ON g.id = gc.game_id
JOIN cast_members cm ON cm.id = gc.cast_member_id
WHERE gc.game_id = '8f8d5946-271b-4664-91e4-5588954b0dab'
ORDER BY gc.joined_at;

-- STEP 3: CHECK SCENARIOS SENT TO THIS GAME
-- ============================================================================

SELECT
  s.id,
  s.title,
  s.status,
  s.deadline_at,
  s.context_notes,
  s.created_at,
  (SELECT COUNT(*) FROM scenario_responses sr WHERE sr.scenario_id = s.id) as response_count,
  (s.deadline_at < NOW()) as is_expired
FROM scenarios s
WHERE s.game_id = '8f8d5946-271b-4664-91e4-5588954b0dab'
ORDER BY s.created_at DESC;

-- STEP 4: CHECK IF USER RECEIVED ANY SCENARIOS
-- ============================================================================

-- Find user's cast member ID first (adjust if needed)
DO $$
DECLARE
  user_cast_id UUID;
BEGIN
  SELECT id INTO user_cast_id
  FROM cast_members
  WHERE full_name ILIKE '%Justin%Lott%'
  ORDER BY created_at DESC
  LIMIT 1;

  RAISE NOTICE 'User cast member ID: %', user_cast_id;

  -- Check scenario responses from this user
  RAISE NOTICE '--- Scenarios user responded to: ---';
  PERFORM s.title, sr.responded_at
  FROM scenario_responses sr
  JOIN scenarios s ON s.id = sr.scenario_id
  WHERE sr.cast_member_id = user_cast_id
  ORDER BY sr.responded_at DESC;

  -- Check scenarios user should have received but didn't respond
  RAISE NOTICE '--- Scenarios user did NOT respond to: ---';
  PERFORM s.title, s.deadline_at, s.status
  FROM scenarios s
  WHERE s.game_id = '8f8d5946-271b-4664-91e4-5588954b0dab'
    AND s.status = 'active'
    AND NOT EXISTS (
      SELECT 1 FROM scenario_responses sr
      WHERE sr.scenario_id = s.id
        AND sr.cast_member_id = user_cast_id
    )
  ORDER BY s.created_at DESC;
END $$;

-- STEP 5: CHECK EMAIL/NOTIFICATION LOGS (if exists)
-- ============================================================================

-- Check if there's a notifications table
SELECT EXISTS (
  SELECT FROM information_schema.tables
  WHERE table_name = 'notifications'
) as has_notifications_table;

-- If notifications table exists, check recent notifications
-- Uncomment if table exists:
/*
SELECT
  notification_type,
  recipient_id,
  sent_at,
  delivered,
  error_message
FROM notifications
WHERE recipient_id IN (
  SELECT id FROM cast_members
  WHERE full_name ILIKE '%Justin%Lott%'
)
ORDER BY created_at DESC
LIMIT 20;
*/

-- STEP 6: CHECK AI AGENT QUEUE FOR SCENARIO GENERATION
-- ============================================================================

SELECT
  action_type,
  status,
  payload->>'scenario_id' as scenario_id,
  payload->>'cast_member_id' as cast_member_id,
  created_at,
  updated_at,
  error_message
FROM mm_ai_agent_queue
WHERE game_id = '8f8d5946-271b-4664-91e4-5588954b0dab'
  AND action_type = 'scenario_response'
ORDER BY created_at DESC
LIMIT 30;

-- STEP 7: CHECK CRON JOB THAT GENERATES SCENARIOS
-- ============================================================================

SELECT
  name,
  schedule,
  enabled,
  last_run_at,
  last_error
FROM cron_jobs
WHERE name LIKE '%scenario%'
  OR name LIKE '%notification%';

-- STEP 8: CHECK GAME SETTINGS
-- ============================================================================

SELECT
  id,
  title,
  status,
  current_round,
  started_at,
  settings
FROM mm_games
WHERE id = '8f8d5946-271b-4664-91e4-5588954b0dab';

-- STEP 9: SUMMARY OF ISSUES
-- ============================================================================

SELECT
  CASE
    WHEN (SELECT COUNT(*) FROM mm_game_cast
          WHERE game_id = '8f8d5946-271b-4664-91e4-5588954b0dab'
            AND cast_member_id IN (
              SELECT id FROM cast_members
              WHERE full_name ILIKE '%Justin%Lott%'
            )) = 0
    THEN '❌ User NOT in game'
    ELSE '✅ User is in game'
  END as user_in_game_status,

  CASE
    WHEN (SELECT COUNT(*) FROM scenarios
          WHERE game_id = '8f8d5946-271b-4664-91e4-5588954b0dab'
            AND status = 'active') = 0
    THEN '❌ No active scenarios'
    ELSE '✅ Active scenarios exist'
  END as scenarios_status,

  CASE
    WHEN (SELECT enabled FROM cron_jobs
          WHERE name LIKE '%scenario%' LIMIT 1) = false
    THEN '❌ Scenario cron job disabled'
    ELSE '✅ Scenario cron job enabled'
  END as cron_status;
