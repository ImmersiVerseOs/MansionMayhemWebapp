-- ============================================================================
-- MANSION MAYHEM - TESTING & VERIFICATION SCRIPTS
-- ============================================================================
-- Quick SQL scripts to test the new AI automation features
-- ============================================================================

-- ============================================================================
-- 1. VERIFY DATABASE SETUP
-- ============================================================================

-- Check if tea room table exists
SELECT EXISTS (
  SELECT FROM information_schema.tables
  WHERE table_name = 'mm_tea_room_posts'
) as tea_room_table_exists;

-- Check if voting columns exist
SELECT
  column_name,
  data_type
FROM information_schema.columns
WHERE table_name = 'mm_voting_rounds'
  AND column_name IN ('queen_direct_elimination_id', 'house_vote_eliminated_id');

-- Check if voice-notes bucket exists
SELECT * FROM storage.buckets WHERE id = 'voice-notes';

-- ============================================================================
-- 2. VIEW RECENT TEA ROOM DRAMA
-- ============================================================================

-- See latest tea room posts with personality
SELECT
  cm.display_name,
  cm.archetype,
  trp.post_text,
  trp.post_type,
  CASE WHEN trp.voice_note_url IS NOT NULL THEN '🎤 Voice' ELSE '📝 Text' END as format,
  trp.likes_count,
  trp.created_at
FROM mm_tea_room_posts trp
JOIN cast_members cm ON cm.id = trp.cast_member_id
ORDER BY trp.created_at DESC
LIMIT 20;

-- Tea room activity by archetype
SELECT
  cm.archetype,
  COUNT(*) as post_count,
  SUM(CASE WHEN trp.voice_note_url IS NOT NULL THEN 1 ELSE 0 END) as voice_notes,
  ROUND(AVG(LENGTH(trp.post_text))) as avg_post_length
FROM mm_tea_room_posts trp
JOIN cast_members cm ON cm.id = trp.cast_member_id
GROUP BY cm.archetype
ORDER BY post_count DESC;

-- ============================================================================
-- 3. VIEW VOTING ACTIVITY
-- ============================================================================

-- Current active voting rounds
SELECT
  vr.round_number,
  vr.status,
  queen.display_name as queen,
  direct_elim.display_name as queen_eliminated,
  nom_a.display_name as nominee_a,
  nom_b.display_name as nominee_b,
  vr.votes_for_a,
  vr.votes_for_b,
  vr.voting_opens_at,
  vr.voting_closes_at
FROM mm_voting_rounds vr
LEFT JOIN cast_members queen ON queen.id = vr.queen_id
LEFT JOIN cast_members direct_elim ON direct_elim.id = vr.queen_direct_elimination_id
LEFT JOIN cast_members nom_a ON nom_a.id = vr.nominee_a_id
LEFT JOIN cast_members nom_b ON nom_b.id = vr.nominee_b_id
ORDER BY vr.round_number DESC
LIMIT 5;

-- Detailed votes for a specific round
-- Replace ROUND_ID with actual round ID
SELECT
  voter.display_name as voter,
  voter.archetype,
  voted_for.display_name as voted_for,
  ev.created_at
FROM mm_elimination_votes ev
JOIN cast_members voter ON voter.id = ev.cast_member_id
JOIN cast_members voted_for ON voted_for.id = ev.voted_for_id
WHERE ev.round_id = 'ROUND_ID'
ORDER BY ev.created_at;

-- Check if AI is protecting allies
SELECT
  voter.display_name as voter,
  voted_for.display_name as voted_for,
  CASE
    WHEN EXISTS (
      SELECT 1 FROM mm_relationship_edges re
      WHERE re.game_id = vr.game_id
        AND (
          (re.cast_member_a_id = voter.id AND re.cast_member_b_id = voted_for.id) OR
          (re.cast_member_b_id = voter.id AND re.cast_member_a_id = voted_for.id)
        )
    ) THEN '🤝 Allied'
    ELSE '❌ Not Allied'
  END as relationship
FROM mm_elimination_votes ev
JOIN cast_members voter ON voter.id = ev.cast_member_id
JOIN cast_members voted_for ON voted_for.id = ev.voted_for_id
JOIN mm_voting_rounds vr ON vr.id = ev.round_id
ORDER BY relationship DESC;

-- ============================================================================
-- 4. VIEW GAME PROGRESSION
-- ============================================================================

-- Active games with week info
SELECT
  g.id,
  g.status,
  g.started_at,
  FLOOR((EXTRACT(EPOCH FROM (NOW() - g.started_at)) / 86400) / 7) + 1 as current_week,
  EXTRACT(DOW FROM NOW()) as day_of_week, -- 0=Sunday, 5=Friday
  (SELECT COUNT(*) FROM mm_game_cast WHERE game_id = g.id AND status = 'active') as active_players,
  (SELECT COUNT(*) FROM mm_game_cast WHERE game_id = g.id AND status = 'eliminated') as eliminated_players
FROM mm_games g
WHERE g.status = 'active';

-- Queen selections by week
SELECT
  qs.week_number,
  cm.display_name as queen,
  cm.archetype,
  qs.selection_method,
  nom_a.display_name as nominee_a,
  nom_b.display_name as nominee_b,
  qs.created_at
FROM mm_queen_selections qs
JOIN cast_members cm ON cm.id = qs.selected_queen_id
LEFT JOIN cast_members nom_a ON nom_a.id = qs.nominee_a_id
LEFT JOIN cast_members nom_b ON nom_b.id = qs.nominee_b_id
ORDER BY qs.week_number DESC;

-- Scenario activation timeline
SELECT
  s.title,
  s.scenario_type,
  s.status,
  s.distribution_date,
  s.deadline_at,
  (SELECT COUNT(*) FROM scenario_responses WHERE scenario_id = s.id) as responses
FROM scenarios s
WHERE s.status IN ('active', 'completed')
ORDER BY s.distribution_date DESC
LIMIT 10;

-- ============================================================================
-- 5. VIEW AI ACTIVITY & COSTS
-- ============================================================================

-- Recent AI actions
SELECT
  cm.display_name,
  aal.action_type,
  aal.ai_model,
  aal.input_tokens,
  aal.output_tokens,
  aal.estimated_cost_cents / 100.0 as cost_dollars,
  LEFT(aal.response_preview, 60) as preview,
  aal.created_at
FROM ai_activity_log aal
JOIN cast_members cm ON cm.id = aal.cast_member_id
ORDER BY aal.created_at DESC
LIMIT 30;

-- AI cost summary by action type (last 7 days)
SELECT
  action_type,
  ai_model,
  COUNT(*) as action_count,
  SUM(input_tokens) as total_input_tokens,
  SUM(output_tokens) as total_output_tokens,
  ROUND(SUM(estimated_cost_cents) / 100.0, 2) as total_cost_dollars
FROM ai_activity_log
WHERE created_at >= NOW() - INTERVAL '7 days'
GROUP BY action_type, ai_model
ORDER BY total_cost_dollars DESC;

-- Daily AI cost trend
SELECT
  DATE(created_at) as date,
  COUNT(*) as actions,
  ROUND(SUM(estimated_cost_cents) / 100.0, 2) as cost_dollars,
  SUM(input_tokens) as input_tokens,
  SUM(output_tokens) as output_tokens
FROM ai_activity_log
GROUP BY DATE(created_at)
ORDER BY date DESC
LIMIT 30;

-- ============================================================================
-- 6. VOICE NOTE VERIFICATION
-- ============================================================================

-- Scenario responses with voice notes
SELECT
  cm.display_name,
  cm.archetype,
  s.title as scenario,
  LEFT(sr.response_text, 80) as response,
  sr.voice_note_url,
  sr.created_at
FROM scenario_responses sr
JOIN cast_members cm ON cm.id = sr.cast_member_id
JOIN scenarios s ON s.id = sr.scenario_id
WHERE sr.voice_note_url IS NOT NULL
ORDER BY sr.created_at DESC
LIMIT 10;

-- Tea room posts with voice notes
SELECT
  cm.display_name,
  cm.archetype,
  LEFT(trp.post_text, 60) as post,
  trp.voice_note_duration_seconds as duration_sec,
  trp.voice_note_url,
  trp.created_at
FROM mm_tea_room_posts trp
JOIN cast_members cm ON cm.id = trp.cast_member_id
WHERE trp.voice_note_url IS NOT NULL
ORDER BY trp.created_at DESC
LIMIT 10;

-- Voice note generation rate
SELECT
  'Scenario Responses' as content_type,
  COUNT(*) as total,
  SUM(CASE WHEN voice_note_url IS NOT NULL THEN 1 ELSE 0 END) as with_voice,
  ROUND(100.0 * SUM(CASE WHEN voice_note_url IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*), 1) as voice_percentage
FROM scenario_responses
UNION ALL
SELECT
  'Tea Room Posts' as content_type,
  COUNT(*) as total,
  SUM(CASE WHEN voice_note_url IS NOT NULL THEN 1 ELSE 0 END) as with_voice,
  ROUND(100.0 * SUM(CASE WHEN voice_note_url IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*), 1) as voice_percentage
FROM mm_tea_room_posts;

-- ============================================================================
-- 7. GAME HEALTH CHECK
-- ============================================================================

-- Full game state summary
WITH game_stats AS (
  SELECT
    g.id as game_id,
    g.status,
    FLOOR((EXTRACT(EPOCH FROM (NOW() - g.started_at)) / 86400) / 7) + 1 as week,
    COUNT(DISTINCT gc.cast_member_id) FILTER (WHERE gc.status = 'active') as active_players,
    COUNT(DISTINCT gc.cast_member_id) FILTER (WHERE gc.status = 'eliminated') as eliminated,
    COUNT(DISTINCT qs.id) as queen_selections,
    COUNT(DISTINCT vr.id) FILTER (WHERE vr.status = 'active') as active_votes,
    COUNT(DISTINCT s.id) FILTER (WHERE s.status = 'active') as active_scenarios,
    COUNT(DISTINCT trp.id) as tea_room_posts
  FROM mm_games g
  LEFT JOIN mm_game_cast gc ON gc.game_id = g.id
  LEFT JOIN mm_queen_selections qs ON qs.game_id = g.id
  LEFT JOIN mm_voting_rounds vr ON vr.game_id = g.id
  LEFT JOIN scenarios s ON s.game_id = g.id
  LEFT JOIN mm_tea_room_posts trp ON trp.game_id = g.id
  WHERE g.status = 'active'
  GROUP BY g.id, g.status, g.started_at
)
SELECT * FROM game_stats;

-- AI action queue status
SELECT
  status,
  action_type,
  COUNT(*) as count,
  MIN(created_at) as oldest,
  MAX(created_at) as newest
FROM ai_action_queue
GROUP BY status, action_type
ORDER BY status, count DESC;

-- Recent errors in action queue
SELECT
  aq.action_type,
  cm.display_name as ai_member,
  aq.error_message,
  aq.created_at,
  aq.processed_at
FROM ai_action_queue aq
JOIN cast_members cm ON cm.id = aq.cast_member_id
WHERE aq.status = 'failed'
ORDER BY aq.created_at DESC
LIMIT 10;

-- ============================================================================
-- 8. MANUAL TESTING HELPERS
-- ============================================================================

-- Create a test voting round (replace IDs with actual values)
-- INSERT INTO mm_voting_rounds (
--   game_id,
--   round_number,
--   queen_id,
--   nominee_a_id,
--   nominee_b_id,
--   status,
--   voting_opens_at,
--   voting_closes_at
-- ) VALUES (
--   'YOUR-GAME-ID',
--   1,
--   'QUEEN-ID',
--   'NOMINEE-A-ID',
--   'NOMINEE-B-ID',
--   'active',
--   NOW(),
--   NOW() + INTERVAL '2 days'
-- );

-- Queue a tea room post action for testing
-- INSERT INTO ai_action_queue (cast_member_id, action_type, game_id, status, priority)
-- VALUES ('AI-CAST-MEMBER-ID', 'tea_room_post', 'GAME-ID', 'pending', 50);

-- Force activate scenarios for testing
-- UPDATE scenarios
-- SET status = 'active', deadline_at = NOW() + INTERVAL '5 days'
-- WHERE game_id = 'YOUR-GAME-ID' AND status = 'queued'
-- LIMIT 3;

-- Manually trigger queen selection
-- INSERT INTO mm_queen_selections (
--   game_id,
--   week_number,
--   round_number,
--   selected_queen_id,
--   selection_method
-- ) VALUES (
--   'YOUR-GAME-ID',
--   1,
--   1,
--   'RANDOM-CAST-MEMBER-ID',
--   'manual_test'
-- );

-- ============================================================================
-- 9. CLEANUP & RESET (USE WITH CAUTION)
-- ============================================================================

-- Clear tea room posts for a game (testing)
-- DELETE FROM mm_tea_room_posts WHERE game_id = 'YOUR-GAME-ID';

-- Clear votes for a round (testing)
-- DELETE FROM mm_elimination_votes WHERE round_id = 'ROUND-ID';

-- Reset voting round (testing)
-- UPDATE mm_voting_rounds
-- SET status = 'active', votes_for_a = 0, votes_for_b = 0
-- WHERE id = 'ROUND-ID';

-- Clear AI action queue (if stuck)
-- DELETE FROM ai_action_queue WHERE status = 'processing' AND created_at < NOW() - INTERVAL '10 minutes';

-- ============================================================================
-- 10. PERFORMANCE MONITORING
-- ============================================================================

-- Slowest AI actions
SELECT
  action_type,
  ai_model,
  MAX(processing_time_ms) as max_ms,
  AVG(processing_time_ms) as avg_ms,
  COUNT(*) as count
FROM ai_activity_log
WHERE created_at >= NOW() - INTERVAL '24 hours'
GROUP BY action_type, ai_model
ORDER BY avg_ms DESC;

-- Token usage by archetype
SELECT
  cm.archetype,
  COUNT(*) as actions,
  SUM(aal.input_tokens) as total_input,
  SUM(aal.output_tokens) as total_output,
  ROUND(AVG(aal.output_tokens), 0) as avg_output_tokens
FROM ai_activity_log aal
JOIN cast_members cm ON cm.id = aal.cast_member_id
WHERE aal.created_at >= NOW() - INTERVAL '7 days'
GROUP BY cm.archetype
ORDER BY total_output DESC;

-- Storage usage (voice notes)
SELECT
  COUNT(*) as file_count,
  ROUND(SUM(metadata->>'size')::bigint / 1024.0 / 1024.0, 2) as total_mb
FROM storage.objects
WHERE bucket_id = 'voice-notes';
