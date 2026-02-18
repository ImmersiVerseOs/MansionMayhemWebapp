# Game Reset & Fresh Start Instructions

## Current Issues

1. ✅ **Cron jobs restarted old game** - Game is running but from old state
2. ❌ **You're not receiving scenarios** - Need to diagnose why
3. ❌ **Leaderboard updating** - AI is active in old game
4. ⚠️ **Page errors** - Need to hard refresh browser (cached old JS)

---

## STEP 1: Pause Everything Immediately

Run this SQL in Supabase SQL Editor:

```sql
-- PAUSE ALL CRON JOBS
UPDATE cron_jobs SET enabled = false WHERE enabled = true;

-- STOP ALL ACTIVE GAMES
UPDATE mm_games
SET status = 'completed', ended_at = NOW()
WHERE status = 'active';

-- Verify
SELECT name, enabled FROM cron_jobs ORDER BY name;
SELECT title, status FROM mm_games ORDER BY created_at DESC LIMIT 5;
```

**Result:** All AI activity stopped immediately.

---

## STEP 2: Diagnose Why You're Not Getting Scenarios

Run this SQL to check:

```sql
-- Find your cast member
SELECT
  cm.id as cast_member_id,
  cm.display_name,
  cm.is_ai,
  gc.game_id
FROM cast_members cm
LEFT JOIN mm_game_cast gc ON gc.cast_member_id = cm.id
WHERE cm.full_name ILIKE '%Justin%Lott%'
ORDER BY cm.created_at DESC;

-- Check scenarios in your game
SELECT
  s.id,
  s.title,
  s.status,
  s.deadline_at,
  s.created_at
FROM scenarios s
WHERE s.game_id = '8f8d5946-271b-4664-91e4-5588954b0dab'
ORDER BY s.created_at DESC
LIMIT 10;

-- Check if you responded to any
SELECT
  s.title,
  sr.responded_at,
  sr.response_text IS NOT NULL as has_response
FROM scenario_responses sr
JOIN scenarios s ON s.id = sr.scenario_id
WHERE sr.cast_member_id = (
  SELECT id FROM cast_members
  WHERE full_name ILIKE '%Justin%Lott%'
  LIMIT 1
)
ORDER BY sr.responded_at DESC;
```

**Possible Issues:**
- ❌ You're not added to the game (mm_game_cast)
- ❌ Scenarios aren't being generated
- ❌ Notification system not working
- ❌ Your cast_member record has wrong user_id

---

## STEP 3: Check Scenario Generation Logs

```sql
-- Check scenario generation activity
SELECT
  action_type,
  status,
  created_at,
  error_message
FROM mm_ai_agent_queue
WHERE game_id = '8f8d5946-271b-4664-91e4-5588954b0dab'
  AND action_type IN ('scenario_generation', 'scenario_response')
ORDER BY created_at DESC
LIMIT 20;

-- Check cron job that generates scenarios
SELECT
  name,
  enabled,
  last_run_at,
  last_error
FROM cron_jobs
WHERE name LIKE '%scenario%';
```

---

## STEP 4: Clean Reset for Fresh Start

### Option A: Keep Game Data, Just Reset State

```sql
-- Stop game
UPDATE mm_games
SET
  status = 'pending',
  current_round = 1,
  started_at = NULL,
  ended_at = NULL
WHERE id = '8f8d5946-271b-4664-91e4-5588954b0dab';

-- Clear AI queue
DELETE FROM mm_ai_agent_queue
WHERE game_id = '8f8d5946-271b-4664-91e4-5588954b0dab';

-- Clear old scenarios
UPDATE scenarios
SET status = 'closed'
WHERE game_id = '8f8d5946-271b-4664-91e4-5588954b0dab'
  AND status = 'active';

-- Keep cast members but reset their stats
-- (Optional - uncomment if needed)
/*
UPDATE mm_game_cast
SET
  screen_time_score = 0,
  drama_score = 0,
  votes_received = 0
WHERE game_id = '8f8d5946-271b-4664-91e4-5588954b0dab';
*/
```

### Option B: Complete Fresh Start (Delete Everything)

```sql
-- WARNING: This deletes all game data!

-- Delete scenario responses
DELETE FROM scenario_responses
WHERE scenario_id IN (
  SELECT id FROM scenarios
  WHERE game_id = '8f8d5946-271b-4664-91e4-5588954b0dab'
);

-- Delete scenarios
DELETE FROM scenarios
WHERE game_id = '8f8d5946-271b-4664-91e4-5588954b0dab';

-- Delete voting records
DELETE FROM mm_voting_records
WHERE round_id IN (
  SELECT id FROM mm_voting_rounds
  WHERE game_id = '8f8d5946-271b-4664-91e4-5588954b0dab'
);

-- Delete voting rounds
DELETE FROM mm_voting_rounds
WHERE game_id = '8f8d5946-271b-4664-91e4-5588954b0dab';

-- Delete tea room posts
DELETE FROM mm_tea_room_posts
WHERE game_id = '8f8d5946-271b-4664-91e4-5588954b0dab';

-- Delete alliance messages
DELETE FROM mm_alliance_messages
WHERE room_id IN (
  SELECT id FROM mm_alliance_rooms
  WHERE game_id = '8f8d5946-271b-4664-91e4-5588954b0dab'
);

-- Delete alliance rooms
DELETE FROM mm_alliance_rooms
WHERE game_id = '8f8d5946-271b-4664-91e4-5588954b0dab';

-- Remove cast from game
DELETE FROM mm_game_cast
WHERE game_id = '8f8d5946-271b-4664-91e4-5588954b0dab';

-- Delete AI queue
DELETE FROM mm_ai_agent_queue
WHERE game_id = '8f8d5946-271b-4664-91e4-5588954b0dab';

-- Finally, delete the game
DELETE FROM mm_games
WHERE id = '8f8d5946-271b-4664-91e4-5588954b0dab';
```

---

## STEP 5: Fix Browser Errors (Hard Refresh)

The errors you're seeing are from cached JavaScript. Fix by:

**Windows:**
```
Ctrl + Shift + R
```

**Or:**
1. Open DevTools (F12)
2. Right-click refresh button
3. "Empty Cache and Hard Reload"

---

## STEP 6: Start Fresh Game

After cleaning up, create a new game:

```sql
-- Create new game
INSERT INTO mm_games (
  id,
  title,
  status,
  current_round,
  settings
) VALUES (
  gen_random_uuid(),
  'Mansion Mayhem Season 1 - Fresh Start',
  'pending',
  0,
  '{}'::jsonb
) RETURNING id;

-- Note the returned ID, then add yourself as cast member
-- Replace <game_id> and <your_cast_member_id>
INSERT INTO mm_game_cast (game_id, cast_member_id)
VALUES (
  '<game_id>',
  (SELECT id FROM cast_members WHERE full_name ILIKE '%Justin%Lott%' LIMIT 1)
);

-- Add AI cast members from existing cast_members where is_ai = true
INSERT INTO mm_game_cast (game_id, cast_member_id)
SELECT
  '<game_id>',
  id
FROM cast_members
WHERE is_ai = true
LIMIT 10;  -- Adjust number of AI players

-- Start the game
UPDATE mm_games
SET
  status = 'active',
  started_at = NOW()
WHERE id = '<game_id>';
```

---

## STEP 7: Resume Cron Jobs (When Ready)

Only after everything is set up:

```sql
-- Resume specific cron jobs
UPDATE cron_jobs
SET enabled = true
WHERE name IN (
  'generate-scenario',
  'ai-agent-processor',
  'ai-decision-processor'
);

-- Verify
SELECT name, enabled FROM cron_jobs ORDER BY name;
```

---

## Quick Diagnosis Commands

Run these to see what's happening:

```sql
-- What games exist?
SELECT id, title, status, current_round FROM mm_games ORDER BY created_at DESC;

-- Who's in the active game?
SELECT
  cm.display_name,
  cm.is_ai,
  gc.joined_at
FROM mm_game_cast gc
JOIN cast_members cm ON cm.id = gc.cast_member_id
WHERE gc.game_id = '8f8d5946-271b-4664-91e4-5588954b0dab'
ORDER BY cm.is_ai, cm.display_name;

-- Recent AI activity?
SELECT
  action_type,
  status,
  created_at
FROM mm_ai_agent_queue
WHERE created_at > NOW() - INTERVAL '1 hour'
ORDER BY created_at DESC
LIMIT 20;

-- Active scenarios?
SELECT title, status, deadline_at FROM scenarios
WHERE game_id = '8f8d5946-271b-4664-91e4-5588954b0dab'
  AND status = 'active';

-- Cron job status?
SELECT name, enabled, last_run_at FROM cron_jobs
WHERE enabled = true;
```

---

## Files Created for You

1. **PAUSE_ALL_AND_RESET.sql** - Complete pause and reset script
2. **CHECK_SCENARIO_DELIVERY.sql** - Diagnose why scenarios aren't coming
3. **GAME_RESET_INSTRUCTIONS.md** - This file

---

## Recommended Actions

1. ✅ **Run PAUSE_ALL_AND_RESET.sql** - Stops everything
2. ✅ **Run CHECK_SCENARIO_DELIVERY.sql** - See why no scenarios
3. ✅ **Hard refresh browser** - Fix JavaScript errors
4. ⚠️ **Decide:** Clean game state or full reset?
5. ⏸️ **Only resume crons when ready to start fresh**

---

Let me know what you find from the diagnostic queries and I can help fix the scenario delivery issue!
