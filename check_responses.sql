-- Check if AI has responded to link-up requests
SELECT 
  cm.display_name as ai_character,
  lurp.response,
  lurp.message,
  lurp.created_at,
  req.from_cast_member_id as requester_id
FROM mm_link_up_responses lurp
JOIN cast_members cm ON cm.id = lurp.cast_member_id
JOIN mm_link_up_requests req ON req.id = lurp.request_id
WHERE req.game_id = '52c0b489-dad2-4812-8d7b-a48ab540d081'
  AND lurp.created_at > NOW() - INTERVAL '30 minutes'
ORDER BY lurp.created_at DESC;

-- Check current status of link-up requests
SELECT 
  from_member.display_name as from_player,
  to_member.display_name as to_player,
  lur.status,
  lur.created_at,
  lur.updated_at
FROM mm_link_up_requests lur
JOIN cast_members from_member ON from_member.id = lur.from_cast_member_id
JOIN cast_members to_member ON to_member.id = lur.to_cast_member_id
WHERE lur.game_id = '52c0b489-dad2-4812-8d7b-a48ab540d081'
ORDER BY lur.created_at DESC
LIMIT 20;
