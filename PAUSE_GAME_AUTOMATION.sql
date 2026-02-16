-- ⏸️ PAUSE ALL GAME AUTOMATION
-- This unschedules all cron jobs so AI agents stop creating content
-- Run this in Supabase SQL Editor to pause the game

-- Unschedule ai-agent-processor (scenarios, voice notes, tea posts)
SELECT cron.unschedule('ai-agent-processor-every-5min');

-- Unschedule ai-decision-processor (alliances, chat messages, link-ups)
SELECT cron.unschedule('ai-decision-processor-every-5min');

-- Verify all jobs are unscheduled (should return empty result)
SELECT * FROM cron.job;

-- ✅ Game automation is now PAUSED
-- No new content will be created until you run setup_cron_jobs.sql again
