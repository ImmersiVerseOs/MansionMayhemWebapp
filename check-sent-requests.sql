-- Check YOUR sent link-up requests for THIS game

-- Replace these with actual values from console:
-- gameId: 8f31b3f0-1b4f-4607-bc23-ce3a7799b269
-- castMemberId: 07692a9f-b2f7-4369-9261-2214005c18ad

SELECT 
  id,
  game_id,
  from_cast_member_id,
  link_up_type,
  status,
  invited_cast_ids,
  accept_count,
  decline_count,
  required_accepts,
  created_at,
  expires_at
FROM mm_link_up_requests
WHERE from_cast_member_id = '07692a9f-b2f7-4369-9261-2214005c18ad'
ORDER BY created_at DESC;

-- Check ALL statuses (not just pending)
SELECT status, COUNT(*) 
FROM mm_link_up_requests
WHERE from_cast_member_id = '07692a9f-b2f7-4369-9261-2214005c18ad'
GROUP BY status;
