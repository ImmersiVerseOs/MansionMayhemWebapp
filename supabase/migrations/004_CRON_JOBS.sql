-- ============================================================================
-- MANSION MAYHEM - CRON JOBS
-- ============================================================================
-- Automated jobs for game state management
-- ============================================================================

-- Enable pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- ============================================================================
-- 1. CHECK LOBBY TIMERS (Every Minute)
-- ============================================================================
-- Checks if waiting lobby or active lobby timers have expired
-- Automatically advances game to next phase
-- ============================================================================
-- Unschedule if exists, then schedule
SELECT cron.unschedule('check_lobby_timers') WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'check_lobby_timers');

SELECT cron.schedule(
  'check_lobby_timers',
  '* * * * *',
  $$ SELECT public.check_and_advance_lobbies(); $$
);

-- ============================================================================
-- 2. DISTRIBUTE DAILY SCENARIOS (9 AM UTC Daily)
-- ============================================================================
-- Distributes 2-3 scenarios per cast member per day
-- Respects quota limits: max 5 total, max 3 per day
-- Each scenario has 24-hour deadline
-- ============================================================================
-- Unschedule if exists, then schedule
SELECT cron.unschedule('distribute_daily_scenarios') WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'distribute_daily_scenarios');

SELECT cron.schedule(
  'distribute_daily_scenarios',
  '0 9 * * *',
  $$ SELECT public.distribute_daily_scenarios(); $$
);

-- ============================================================================
-- 3. WEEKLY QUEEN SELECTION (Sundays at 8 PM UTC)
-- ============================================================================
-- Random lottery selection of weekly queen
-- Triggers on Sundays at 20:00 UTC
-- Queen has 48 hours to nominate two cast members
-- ============================================================================
-- Unschedule if exists, then schedule
SELECT cron.unschedule('weekly_queen_selection') WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'weekly_queen_selection');

SELECT cron.schedule(
  'weekly_queen_selection',
  '0 20 * * 0',
  $$ SELECT public.trigger_queen_selection(); $$
);

-- ============================================================================
-- 4. AI AGENT PROCESSOR (Every 3 minutes)
-- ============================================================================
-- Processes queued AI actions (chat, scenarios, alliances)
-- Runs frequently to make AI feel responsive
-- ============================================================================
SELECT cron.unschedule('ai_agent_processor') WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'ai_agent_processor');

SELECT cron.schedule(
  'ai_agent_processor',
  '*/3 * * * *', -- Every 3 minutes
  $$
  SELECT
    net.http_post(
      url := current_setting('app.supabase_url') || '/functions/v1/ai-agent-processor',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || current_setting('app.supabase_anon_key')
      ),
      body := '{}'::jsonb
    );
  $$
);

-- ============================================================================
-- VERIFICATION
-- ============================================================================
DO $$
DECLARE
  job_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO job_count
  FROM cron.job
  WHERE jobname IN ('check_lobby_timers', 'distribute_daily_scenarios', 'weekly_queen_selection');

  RAISE NOTICE '✅ Cron Jobs Scheduled!';
  RAISE NOTICE 'Active jobs: %', job_count;
  RAISE NOTICE 'Jobs: check_lobby_timers (every minute), distribute_daily_scenarios (daily 9 AM UTC), weekly_queen_selection (Sundays 8 PM UTC)';
END $$;
