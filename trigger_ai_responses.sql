-- Manually trigger AI decision processor for your game
SELECT net.http_post(
  url := 'https://fpxbhqibimekjhlumnmc.supabase.co/functions/v1/ai-decision-processor',
  headers := json_build_object(
    'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZweGJocWliaW1la2pobHVtbm1jIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTczNjg4MjA1OSwiZXhwIjoyMDUyNDU4MDU5fQ.0H1vTPSElXZJ3nMCNsJ-4qJ8SbJxAcH3G5v6Z_pHixw',
    'Content-Type', 'application/json'
  )::jsonb,
  body := json_build_object('gameId', '52c0b489-dad2-4812-8d7b-a48ab540d081')::jsonb
) as request_id;

-- Wait 30 seconds, then run these checks:

-- 1. Check if AI created responses
SELECT 
  cm.display_name as ai_character,
  lurp.response,
  lurp.message,
  lurp.created_at
FROM mm_link_up_responses lurp
JOIN cast_members cm ON cm.id = lurp.cast_member_id
JOIN mm_link_up_requests req ON req.id = lurp.request_id
WHERE req.game_id = '52c0b489-dad2-4812-8d7b-a48ab540d081'
ORDER BY lurp.created_at DESC;

-- 2. Check if requests moved from pending
SELECT 
  from_member.display_name as from_player,
  to_member.display_name as to_player,
  lur.status,
  lur.updated_at
FROM mm_link_up_requests lur
JOIN cast_members from_member ON from_member.id = lur.from_cast_member_id
JOIN cast_members to_member ON to_member.id = lur.to_cast_member_id
WHERE lur.game_id = '52c0b489-dad2-4812-8d7b-a48ab540d081'
  AND lur.status != 'pending'
ORDER BY lur.updated_at DESC;
