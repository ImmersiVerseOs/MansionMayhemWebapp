-- Enable pg_cron extension if not already enabled
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Enable pg_net extension for HTTP requests
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Create cron job for ai-agent-processor (every 5 minutes)
-- This processes ai_action_queue items: scenarios, voice notes, tea posts
SELECT cron.schedule(
  'ai-agent-processor-every-5min',
  '*/5 * * * *',
  $$
    SELECT net.http_post(
      url := 'https://fpxbhqibimekjhlumnmc.supabase.co/functions/v1/ai-agent-processor',
      headers := '{"Content-Type": "application/json"}'::jsonb,
      body := '{}'::jsonb
    ) as request_id;
  $$
);

-- Create cron job for ai-decision-processor (every 5 minutes)
-- This handles alliances, chat messages, link-up responses
SELECT cron.schedule(
  'ai-decision-processor-every-5min',
  '*/5 * * * *',
  $$
    SELECT net.http_post(
      url := 'https://fpxbhqibimekjhlumnmc.supabase.co/functions/v1/ai-decision-processor',
      headers := '{"Content-Type": "application/json"}'::jsonb,
      body := '{}'::jsonb
    ) as request_id;
  $$
);

-- Verify cron jobs were created
SELECT * FROM cron.job;
