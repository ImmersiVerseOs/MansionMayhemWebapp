-- ============================================================================
-- QUICK AI MONITORING QUERIES - Copy/paste these into Supabase SQL Editor
-- ============================================================================

-- 1. AI ACTION QUEUE STATUS (What's being processed right now)
-- ============================================================================
SELECT
  status,
  action_type,
  COUNT(*) as count
FROM ai_action_queue
GROUP BY status, action_type
ORDER BY status, action_type;


-- 2. RECENT AI ACTIONS (Last 50 actions with details)
-- ============================================================================
SELECT
  aaq.id,
  aaq.action_type,
  aaq.status,
  cm.display_name as character_name,
  cm.archetype,
  cm.is_ai_player,
  aaq.created_at,
  aaq.processed_at
FROM ai_action_queue aaq
LEFT JOIN cast_members cm ON cm.id = aaq.cast_member_id
ORDER BY aaq.created_at DESC
LIMIT 50;


-- 3. CHAT ACTIVITY (Last 2 hours)
-- ============================================================================
SELECT
  cm.display_name,
  cm.archetype,
  cm.is_ai_player,
  COUNT(*) as messages_sent,
  MAX(am.created_at) as last_message
FROM mm_alliance_messages am
JOIN cast_members cm ON cm.id = am.cast_member_id
WHERE am.created_at > NOW() - INTERVAL '2 hours'
GROUP BY cm.id, cm.display_name, cm.archetype, cm.is_ai_player
ORDER BY messages_sent DESC;


-- 4. RECENT CHAT MESSAGES (Last 30 messages)
-- ============================================================================
SELECT
  am.created_at,
  cm.display_name as sender,
  cm.archetype,
  ar.room_name,
  am.message
FROM mm_alliance_messages am
JOIN cast_members cm ON cm.id = am.cast_member_id
JOIN mm_alliance_rooms ar ON ar.id = am.room_id
ORDER BY am.created_at DESC
LIMIT 30;


-- 5. TEA ROOM POSTS (Last 24 hours)
-- ============================================================================
SELECT
  tp.created_at,
  cm.display_name as author,
  cm.archetype,
  cm.is_ai_player,
  tp.post_type,
  tp.content,
  tp.likes_count
FROM tea_posts tp
JOIN cast_members cm ON cm.id = tp.cast_member_id
WHERE tp.created_at > NOW() - INTERVAL '24 hours'
ORDER BY tp.created_at DESC
LIMIT 20;


-- 6. SCENARIO RESPONSES (Last 24 hours)
-- ============================================================================
SELECT
  sr.created_at,
  cm.display_name as character,
  cm.archetype,
  s.title as scenario,
  sr.drama_score,
  sr.strategy_score,
  sr.entertainment_score,
  LEFT(sr.response_text, 100) as response_preview
FROM scenario_responses sr
JOIN scenarios s ON s.id = sr.scenario_id
JOIN cast_members cm ON cm.id = sr.cast_member_id
WHERE sr.created_at > NOW() - INTERVAL '24 hours'
ORDER BY sr.created_at DESC;


-- 7. OVERALL ACTIVITY DASHBOARD (Last Hour)
-- ============================================================================
SELECT 'AI Actions Queued' as metric, COUNT(*) as count
FROM ai_action_queue
WHERE created_at > NOW() - INTERVAL '1 hour'

UNION ALL

SELECT 'AI Actions Completed', COUNT(*)
FROM ai_action_queue
WHERE status = 'completed' AND processed_at > NOW() - INTERVAL '1 hour'

UNION ALL

SELECT 'Chat Messages Sent', COUNT(*)
FROM mm_alliance_messages
WHERE created_at > NOW() - INTERVAL '1 hour'

UNION ALL

SELECT 'Tea Posts Created', COUNT(*)
FROM tea_posts
WHERE created_at > NOW() - INTERVAL '1 hour'

UNION ALL

SELECT 'Scenario Responses', COUNT(*)
FROM scenario_responses
WHERE created_at > NOW() - INTERVAL '1 hour';


-- 8. REAL-TIME ACTIVITY STREAM (Last 15 minutes)
-- ============================================================================
SELECT
  'AI Action' as type,
  aaq.action_type as detail,
  cm.display_name as character,
  aaq.status,
  aaq.created_at as timestamp
FROM ai_action_queue aaq
LEFT JOIN cast_members cm ON cm.id = aaq.cast_member_id
WHERE aaq.created_at > NOW() - INTERVAL '15 minutes'

UNION ALL

SELECT
  'Chat Message',
  ar.room_name,
  cm.display_name,
  'sent',
  am.created_at
FROM mm_alliance_messages am
JOIN mm_alliance_rooms ar ON ar.id = am.room_id
JOIN cast_members cm ON cm.id = am.cast_member_id
WHERE am.created_at > NOW() - INTERVAL '15 minutes'

UNION ALL

SELECT
  'Tea Post',
  tp.post_type,
  cm.display_name,
  'posted',
  tp.created_at
FROM tea_posts tp
JOIN cast_members cm ON cm.id = tp.cast_member_id
WHERE tp.created_at > NOW() - INTERVAL '15 minutes'

UNION ALL

SELECT
  'Scenario Response',
  s.title,
  cm.display_name,
  'submitted',
  sr.created_at
FROM scenario_responses sr
JOIN scenarios s ON s.id = sr.scenario_id
JOIN cast_members cm ON cm.id = sr.cast_member_id
WHERE sr.created_at > NOW() - INTERVAL '15 minutes'

ORDER BY timestamp DESC;


-- 9. CHECK CRON JOBS STATUS
-- ============================================================================
SELECT
  jobid,
  jobname,
  schedule,
  active,
  command
FROM cron.job
WHERE jobname LIKE 'ai-%'
ORDER BY jobid;


-- 10. PENDING AI ACTIONS (What's waiting to be processed)
-- ============================================================================
SELECT
  action_type,
  COUNT(*) as pending_count,
  MIN(created_at) as oldest_pending,
  MAX(created_at) as newest_pending
FROM ai_action_queue
WHERE status = 'pending'
GROUP BY action_type;
