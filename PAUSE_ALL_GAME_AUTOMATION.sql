-- ⏸️ PAUSE ALL GAME AUTOMATION (19 CRON JOBS)
-- This unschedules ALL cron jobs so nothing automated happens
-- Run this in Supabase SQL Editor to completely freeze the game

-- HIGH FREQUENCY JOBS (Most Critical to Stop)
SELECT cron.unschedule('check_lobby_timers');           -- Runs every minute
SELECT cron.unschedule('ai_agent_processor');           -- Runs every 3 minutes
SELECT cron.unschedule('cleanup_abandoned_games');      -- Runs every 15 minutes

-- AI CONTENT GENERATION
SELECT cron.unschedule('queue_ai_link_ups');            -- Every hour
SELECT cron.unschedule('queue_ai_tea_posts');           -- Every 2 hours
SELECT cron.unschedule('spawn_ai_into_lobbies');        -- Every 4 hours

-- AI DIRECTOR (4 times daily)
SELECT cron.unschedule('ai-director-midnight');         -- Daily at 12:00 AM
SELECT cron.unschedule('ai-director-morning');          -- Daily at 6:00 AM
SELECT cron.unschedule('ai-director-noon');             -- Daily at 12:00 PM
SELECT cron.unschedule('ai-director-evening');          -- Daily at 6:00 PM

-- GAME MANAGER
SELECT cron.unschedule('game-manager-daily');           -- 3x daily (midnight, noon, 6pm)

-- WEEKLY GAME EVENTS (Mondays)
SELECT cron.unschedule('weekly_elimination');           -- Monday 12:30 AM
SELECT cron.unschedule('weekly_queen_selection');       -- Monday 1:00 AM
SELECT cron.unschedule('distribute_daily_scenarios');   -- Monday 2:00 PM
SELECT cron.unschedule('pre_launch_fill_to_20');        -- Monday 12:30 AM
SELECT cron.unschedule('elimination-sunday');           -- Monday 12:30 AM
SELECT cron.unschedule('queen-selection-sunday');       -- Monday 1:00 AM

-- WEEKEND EVENTS
SELECT cron.unschedule('hot-seat-saturday');            -- Saturday 5:00 PM

-- CLEANUP JOBS
SELECT cron.unschedule('cleanup_ai_actions');           -- Daily 3:00 AM

-- ✅ Verify all jobs are unscheduled (should return empty result)
SELECT jobid, jobname, schedule, active FROM cron.job ORDER BY jobid;

-- 🛑 ALL GAME AUTOMATION IS NOW PAUSED
-- No AI agents, no scenarios, no eliminations, no game events
-- Game is completely frozen until you run RESUME script
