-- Check recent AI alliance chat messages
SELECT 
  cm.display_name as sender,
  ar.room_name,
  am.text_content,
  am.created_at
FROM mm_alliance_messages am
JOIN cast_members cm ON cm.id = am.sender_cast_id
JOIN mm_alliance_rooms ar ON ar.id = am.room_id
WHERE ar.game_id = '52c0b489-dad2-4812-8d7b-a48ab540d081'
  AND cm.is_ai_player = true
  AND am.created_at > NOW() - INTERVAL '30 minutes'
ORDER BY am.created_at DESC
LIMIT 30;

-- Count total AI messages by character
SELECT 
  cm.display_name,
  COUNT(*) as message_count,
  MAX(am.created_at) as last_message
FROM mm_alliance_messages am
JOIN cast_members cm ON cm.id = am.sender_cast_id
JOIN mm_alliance_rooms ar ON ar.id = am.room_id
WHERE ar.game_id = '52c0b489-dad2-4812-8d7b-a48ab540d081'
  AND cm.is_ai_player = true
GROUP BY cm.display_name
ORDER BY message_count DESC;
