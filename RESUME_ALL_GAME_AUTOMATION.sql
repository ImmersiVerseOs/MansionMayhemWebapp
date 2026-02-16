-- ▶️ RESUME ALL GAME AUTOMATION (19 CRON JOBS)
-- This re-enables all cron jobs after fixes are complete
-- Run this in Supabase SQL Editor to unfreeze the game

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- ========================================
-- HIGH FREQUENCY JOBS
-- ========================================

-- AI Agent Processor (every 3 minutes)
SELECT cron.schedule(
  'ai_agent_processor',
  '*/3 * * * *',
  $$
    SELECT net.http_post(
      url := 'https://fpxbhqibimekjhlumnmc.supabase.co/functions/v1/ai-agent-processor',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZweGJocWliaW1la2pobHVtbm1jIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEwMjUwODYsImV4cCI6MjA4NjYwMTA4Nn0.0BmbaObOERMZ5r4znb5BQbrGpB5lE5Fq6KnEzxA0YhY'
      ),
      body := '{}'::jsonb
    );
  $$
);

-- Check Lobby Timers (every minute)
SELECT cron.schedule(
  'check_lobby_timers',
  '* * * * *',
  $$ SELECT public.check_and_launch_sunday_games(); $$
);

-- Cleanup Abandoned Games (every 15 minutes)
SELECT cron.schedule(
  'cleanup_abandoned_games',
  '*/15 * * * *',
  $$ SELECT public.cleanup_abandoned_games(); $$
);

-- ========================================
-- AI CONTENT GENERATION
-- ========================================

-- Queue AI Link-Ups (every hour)
SELECT cron.schedule(
  'queue_ai_link_ups',
  '0 * * * *',
  $$ SELECT queue_ai_link_up_requests(); $$
);

-- Queue AI Tea Posts (every 2 hours)
SELECT cron.schedule(
  'queue_ai_tea_posts',
  '0 */2 * * *',
  $$ SELECT queue_ai_tea_room_posts(); $$
);

-- Spawn AI into Lobbies (every 4 hours)
SELECT cron.schedule(
  'spawn_ai_into_lobbies',
  '0 */4 * * *',
  $$ SELECT public.spawn_ai_into_lobbies(); $$
);

-- ========================================
-- AI DIRECTOR (4x daily)
-- ========================================

-- Midnight
SELECT cron.schedule(
  'ai-director-midnight',
  '0 0 * * *',
  $$
    SELECT extensions.http_post(
      'https://fpxbhqibimekjhlumnmc.supabase.co/functions/v1/ai-director'::text,
      '{}'::jsonb,
      '{"Content-Type": "application/json"}'::jsonb
    );
  $$
);

-- Morning (6 AM)
SELECT cron.schedule(
  'ai-director-morning',
  '0 6 * * *',
  $$
    SELECT extensions.http_post(
      'https://fpxbhqibimekjhlumnmc.supabase.co/functions/v1/ai-director'::text,
      '{}'::jsonb,
      '{"Content-Type": "application/json"}'::jsonb
    );
  $$
);

-- Noon (12 PM)
SELECT cron.schedule(
  'ai-director-noon',
  '0 12 * * *',
  $$
    SELECT extensions.http_post(
      'https://fpxbhqibimekjhlumnmc.supabase.co/functions/v1/ai-director'::text,
      '{}'::jsonb,
      '{"Content-Type": "application/json"}'::jsonb
    );
  $$
);

-- Evening (6 PM)
SELECT cron.schedule(
  'ai-director-evening',
  '0 18 * * *',
  $$
    SELECT extensions.http_post(
      'https://fpxbhqibimekjhlumnmc.supabase.co/functions/v1/ai-director'::text,
      '{}'::jsonb,
      '{"Content-Type": "application/json"}'::jsonb
    );
  $$
);

-- ========================================
-- GAME MANAGER
-- ========================================

-- Game Manager (midnight, noon, 6pm)
SELECT cron.schedule(
  'game-manager-daily',
  '0 0,12,18 * * *',
  $$
    SELECT net.http_post(
      url := 'https://fpxbhqibimekjhlumnmc.supabase.co/functions/v1/game-manager',
      headers := '{"Content-Type": "application/json"}'::jsonb,
      body := '{}'::jsonb
    );
  $$
);

-- ========================================
-- WEEKLY GAME EVENTS (Mondays)
-- ========================================

-- Weekly Elimination (Monday 12:30 AM)
SELECT cron.schedule(
  'weekly_elimination',
  '30 0 * * 1',
  $$ SELECT public.process_weekly_elimination(); $$
);

-- Weekly Queen Selection (Monday 1:00 AM)
SELECT cron.schedule(
  'weekly_queen_selection',
  '0 1 * * 1',
  $$ SELECT public.trigger_queen_selection(); $$
);

-- Distribute Daily Scenarios (Monday 2:00 PM)
SELECT cron.schedule(
  'distribute_daily_scenarios',
  '0 14 * * 1',
  $$ SELECT public.distribute_daily_scenarios(); $$
);

-- Pre-Launch Fill to 20 (Monday 12:30 AM)
SELECT cron.schedule(
  'pre_launch_fill_to_20',
  '30 0 * * 1',
  $$ SELECT public.fill_lobbies_to_20(); $$
);

-- Elimination Sunday (Monday 12:30 AM)
SELECT cron.schedule(
  'elimination-sunday',
  '30 0 * * 1',
  $$
    SELECT public.announce_elimination(id)
    FROM mm_games
    WHERE status = 'active';
  $$
);

-- Queen Selection Sunday (Monday 1:00 AM)
SELECT cron.schedule(
  'queen-selection-sunday',
  '0 1 * * 1',
  $$
    SELECT public.start_queen_selection(id)
    FROM mm_games
    WHERE status = 'active';
  $$
);

-- ========================================
-- WEEKEND EVENTS
-- ========================================

-- Hot Seat Saturday (Saturday 5:00 PM)
SELECT cron.schedule(
  'hot-seat-saturday',
  '0 17 * * 6',
  $$
    SELECT public.start_saturday_hot_seat(id)
    FROM mm_games
    WHERE status = 'active';
  $$
);

-- ========================================
-- CLEANUP JOBS
-- ========================================

-- Cleanup AI Actions (Daily 3:00 AM)
SELECT cron.schedule(
  'cleanup_ai_actions',
  '0 3 * * *',
  $$ SELECT cleanup_ai_action_queue(); $$
);

-- ========================================
-- VERIFICATION
-- ========================================

-- Verify all jobs are scheduled
SELECT jobid, jobname, schedule, active FROM cron.job ORDER BY jobid;

-- ✅ ALL GAME AUTOMATION IS NOW RESUMED
-- Game is back to normal operation
