-- =====================================================
-- FORCE UPDATE LOBBY TIMES
-- Manually set correct times for existing game
-- =====================================================

-- Calculate correct Sunday 7pm ET and 8:30pm ET in UTC
-- Feb 16, 2026 at 7:00 PM Eastern = Feb 17, 2026 at 00:00 UTC
-- Feb 16, 2026 at 8:30 PM Eastern = Feb 17, 2026 at 01:30 UTC

UPDATE mm_games
SET
  waiting_lobby_ends_at = '2026-02-17 00:00:00+00'::timestamptz,  -- Sunday 7pm ET
  game_starts_at = '2026-02-17 01:30:00+00'::timestamptz,         -- Sunday 8:30pm ET
  updated_at = NOW()
WHERE id = 'b964f897-2e89-4059-a548-af528acd0fd7';

-- Verify the update
SELECT
  id,
  title,
  waiting_lobby_ends_at,
  waiting_lobby_ends_at AT TIME ZONE 'America/New_York' as lobby_closes_et,
  game_starts_at,
  game_starts_at AT TIME ZONE 'America/New_York' as game_starts_et,
  ROUND(EXTRACT(EPOCH FROM (waiting_lobby_ends_at - NOW())) / 3600, 1) as hours_until_close
FROM mm_games
WHERE id = 'b964f897-2e89-4059-a548-af528acd0fd7';
