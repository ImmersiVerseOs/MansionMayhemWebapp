-- ============================================================================
-- AI ACTIVITY MONITORING QUERIES - Mansion Mayhem
-- ============================================================================
-- Run these in your Supabase SQL Editor to track AI automation
-- ============================================================================

-- 1. AI ACTION QUEUE - See what's being processed
-- ============================================================================
-- Shows pending, processing, and recent completed actions
SELECT
  id,
  action_type,
  status,
  cm.display_name as character_name,
  cm.archetype,
  created_at,
  processed_at,
  EXTRACT(EPOCH FROM (NOW() - created_at))/60 as minutes_waiting
FROM ai_action_queue aaq
LEFT JOIN cast_members cm ON cm.id = aaq.cast_member_id
ORDER BY created_at DESC
LIMIT 50;

-- Count actions by status
SELECT
  status,
  action_type,
  COUNT(*) as count
FROM ai_action_queue
GROUP BY status, action_type
ORDER BY status, action_type;

-- ============================================================================
-- 2. ALLIANCE MESSAGES - Chat Activity
-- ============================================================================
-- Recent chat messages in alliance rooms
SELECT
  am.id,
  am.created_at,
  ar.room_name,
  cm.display_name as sender,
  cm.archetype,
  cm.is_ai_player,
  LEFT(am.message, 100) as message_preview,
  am.message_type
FROM mm_alliance_messages am
JOIN mm_alliance_rooms ar ON ar.id = am.room_id
JOIN cast_members cm ON cm.id = am.cast_member_id
WHERE am.created_at > NOW() - INTERVAL '2 hours'
ORDER BY am.created_at DESC
LIMIT 50;

-- Chat activity by character (last 24 hours)
SELECT
  cm.display_name,
  cm.archetype,
  cm.is_ai_player,
  COUNT(*) as messages_sent,
  MAX(am.created_at) as last_message_at
FROM mm_alliance_messages am
JOIN cast_members cm ON cm.id = am.cast_member_id
WHERE am.created_at > NOW() - INTERVAL '24 hours'
GROUP BY cm.id, cm.display_name, cm.archetype, cm.is_ai_player
ORDER BY messages_sent DESC;

-- ============================================================================
-- 3. TEA ROOM POSTS - Public Drama
-- ============================================================================
-- Recent tea room posts
SELECT
  tp.id,
  tp.created_at,
  cm.display_name as author,
  cm.archetype,
  cm.is_ai_player,
  tp.post_type,
  LEFT(tp.content, 150) as content_preview,
  tp.likes_count,
  tp.comments_count
FROM tea_posts tp
JOIN cast_members cm ON cm.id = tp.cast_member_id
WHERE tp.created_at > NOW() - INTERVAL '24 hours'
ORDER BY tp.created_at DESC
LIMIT 30;

-- Most active tea room posters (last 24 hours)
SELECT
  cm.display_name,
  cm.archetype,
  cm.is_ai_player,
  COUNT(*) as posts_count,
  SUM(tp.likes_count) as total_likes,
  MAX(tp.created_at) as last_post_at
FROM tea_posts tp
JOIN cast_members cm ON cm.id = tp.cast_member_id
WHERE tp.created_at > NOW() - INTERVAL '24 hours'
GROUP BY cm.id, cm.display_name, cm.archetype, cm.is_ai_player
ORDER BY posts_count DESC;

-- ============================================================================
-- 4. SCENARIO RESPONSES - Challenge Completions
-- ============================================================================
-- Recent scenario responses
SELECT
  sr.id,
  sr.created_at,
  s.title as scenario_title,
  s.scenario_type,
  cm.display_name as character,
  cm.archetype,
  cm.is_ai_player,
  LEFT(sr.response_text, 150) as response_preview,
  sr.drama_score,
  sr.strategy_score,
  sr.entertainment_score
FROM scenario_responses sr
JOIN scenarios s ON s.id = sr.scenario_id
JOIN cast_members cm ON cm.id = sr.cast_member_id
WHERE sr.created_at > NOW() - INTERVAL '24 hours'
ORDER BY sr.created_at DESC
LIMIT 30;

-- Scenario completion rate by character
SELECT
  cm.display_name,
  cm.archetype,
  cm.is_ai_player,
  COUNT(*) as responses_submitted,
  ROUND(AVG(sr.drama_score), 2) as avg_drama,
  ROUND(AVG(sr.strategy_score), 2) as avg_strategy,
  ROUND(AVG(sr.entertainment_score), 2) as avg_entertainment
FROM scenario_responses sr
JOIN cast_members cm ON cm.id = sr.cast_member_id
WHERE sr.created_at > NOW() - INTERVAL '24 hours'
GROUP BY cm.id, cm.display_name, cm.archetype, cm.is_ai_player
ORDER BY responses_submitted DESC;

-- ============================================================================
-- 5. VOICE INTRODUCTIONS - Character Intros
-- ============================================================================
-- Recent voice introductions created
SELECT
  vi.id,
  vi.created_at,
  cm.display_name as character,
  cm.archetype,
  cm.is_ai_player,
  LEFT(vi.transcript, 150) as transcript_preview,
  vi.audio_url IS NOT NULL as has_audio,
  vi.duration_seconds
FROM voice_introductions vi
JOIN cast_members cm ON cm.id = vi.cast_member_id
WHERE vi.created_at > NOW() - INTERVAL '24 hours'
ORDER BY vi.created_at DESC;

-- ============================================================================
-- 6. ALLIANCE DECISIONS - Strategic Moves
-- ============================================================================
-- Recent alliance requests and responses
SELECT
  alr.id,
  alr.created_at,
  alr.status,
  sender.display_name as from_character,
  sender.archetype as from_archetype,
  sender.is_ai_player as from_is_ai,
  receiver.display_name as to_character,
  receiver.archetype as to_archetype,
  receiver.is_ai_player as to_is_ai,
  LEFT(alr.message, 100) as message_preview
FROM mm_alliance_link_requests alr
JOIN cast_members sender ON sender.id = alr.sender_id
JOIN cast_members receiver ON receiver.id = alr.receiver_id
WHERE alr.created_at > NOW() - INTERVAL '24 hours'
ORDER BY alr.created_at DESC
LIMIT 30;

-- ============================================================================
-- 7. OVERALL AI ACTIVITY DASHBOARD
-- ============================================================================
-- Summary of all AI activity in last hour
SELECT
  'AI Actions Queued' as metric,
  COUNT(*) as count
FROM ai_action_queue
WHERE created_at > NOW() - INTERVAL '1 hour'

UNION ALL

SELECT
  'AI Actions Completed' as metric,
  COUNT(*) as count
FROM ai_action_queue
WHERE status = 'completed' AND processed_at > NOW() - INTERVAL '1 hour'

UNION ALL

SELECT
  'Chat Messages Sent' as metric,
  COUNT(*) as count
FROM mm_alliance_messages
WHERE created_at > NOW() - INTERVAL '1 hour'

UNION ALL

SELECT
  'Tea Posts Created' as metric,
  COUNT(*) as count
FROM tea_posts
WHERE created_at > NOW() - INTERVAL '1 hour'

UNION ALL

SELECT
  'Scenario Responses' as metric,
  COUNT(*) as count
FROM scenario_responses
WHERE created_at > NOW() - INTERVAL '1 hour'

UNION ALL

SELECT
  'Voice Intros Created' as metric,
  COUNT(*) as count
FROM voice_introductions
WHERE created_at > NOW() - INTERVAL '1 hour';

-- ============================================================================
-- 8. CRON JOB STATUS - Verify automation is running
-- ============================================================================
-- Check if cron jobs are active
SELECT
  jobid,
  jobname,
  schedule,
  active,
  command
FROM cron.job
WHERE jobname LIKE 'ai-%'
ORDER BY jobid;

-- Recent cron job executions (if logging is enabled)
SELECT
  jr.jobid,
  j.jobname,
  jr.start_time,
  jr.end_time,
  jr.status,
  EXTRACT(EPOCH FROM (jr.end_time - jr.start_time)) as duration_seconds
FROM cron.job_run_details jr
JOIN cron.job j ON j.jobid = jr.jobid
WHERE j.jobname LIKE 'ai-%'
ORDER BY jr.start_time DESC
LIMIT 20;

-- ============================================================================
-- 9. REAL-TIME ACTIVITY STREAM (last 15 minutes)
-- ============================================================================
-- Combined stream of all AI activity
SELECT
  'AI Action' as activity_type,
  action_type as detail,
  cm.display_name as character,
  status,
  created_at as timestamp
FROM ai_action_queue aaq
LEFT JOIN cast_members cm ON cm.id = aaq.cast_member_id
WHERE created_at > NOW() - INTERVAL '15 minutes'

UNION ALL

SELECT
  'Chat Message' as activity_type,
  'Message in ' || ar.room_name as detail,
  cm.display_name as character,
  'sent' as status,
  am.created_at as timestamp
FROM mm_alliance_messages am
JOIN mm_alliance_rooms ar ON ar.id = am.room_id
JOIN cast_members cm ON cm.id = am.cast_member_id
WHERE am.created_at > NOW() - INTERVAL '15 minutes'

UNION ALL

SELECT
  'Tea Post' as activity_type,
  post_type as detail,
  cm.display_name as character,
  'posted' as status,
  tp.created_at as timestamp
FROM tea_posts tp
JOIN cast_members cm ON cm.id = tp.cast_member_id
WHERE tp.created_at > NOW() - INTERVAL '15 minutes'

UNION ALL

SELECT
  'Scenario Response' as activity_type,
  s.title as detail,
  cm.display_name as character,
  'submitted' as status,
  sr.created_at as timestamp
FROM scenario_responses sr
JOIN scenarios s ON s.id = sr.scenario_id
JOIN cast_members cm ON cm.id = sr.cast_member_id
WHERE sr.created_at > NOW() - INTERVAL '15 minutes'

ORDER BY timestamp DESC;
