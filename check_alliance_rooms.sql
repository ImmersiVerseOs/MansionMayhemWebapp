-- Check if alliance rooms were created from accepted link-ups
SELECT 
  ar.id,
  ar.room_name,
  ar.room_type,
  ar.is_active,
  ar.created_at,
  array_length(ar.member_cast_ids, 1) as member_count
FROM mm_alliance_rooms ar
WHERE ar.game_id = '52c0b489-dad2-4812-8d7b-a48ab540d081'
  AND ar.created_at > NOW() - INTERVAL '1 hour'
ORDER BY ar.created_at DESC;

-- Check which accepted link-ups still need rooms created
SELECT 
  lur.id as request_id,
  from_member.display_name as player1,
  to_member.display_name as player2,
  lur.status,
  lur.updated_at
FROM mm_link_up_requests lur
JOIN cast_members from_member ON from_member.id = lur.from_cast_member_id
JOIN cast_members to_member ON to_member.id = lur.to_cast_member_id
WHERE lur.game_id = '52c0b489-dad2-4812-8d7b-a48ab540d081'
  AND lur.status = 'accepted'
  AND lur.updated_at > NOW() - INTERVAL '1 hour'
ORDER BY lur.updated_at DESC
LIMIT 20;
