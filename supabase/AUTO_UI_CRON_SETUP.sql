-- ============================================================================
-- AUTO UI GENERATION CRON JOBS
-- Set up automated scenario analysis and UI generation
-- ============================================================================

-- Note: Supabase Edge Functions don't have built-in cron yet
-- Use pg_cron extension or external cron service

-- Option 1: pg_cron (if available)
SELECT cron.schedule(
  'analyze-new-scenarios',
  '*/5 * * * *', -- Every 5 minutes
  $$
  SELECT
    net.http_post(
      url := 'https://fpxbhqibimekjhlumnmc.supabase.co/functions/v1/analyze-scenario',
      headers := '{"Content-Type": "application/json", "Authorization": "Bearer ' || current_setting('app.settings.service_role_key') || '"}'::jsonb,
      body := '{}'::jsonb
    ) AS request_id;
  $$
);

-- Option 2: GitHub Actions cron (recommended)
-- See: .github/workflows/auto-ui-cron.yml

-- Option 3: External cron service (cron-job.org, etc.)
-- HTTP POST to: https://fpxbhqibimekjhlumnmc.supabase.co/functions/v1/analyze-scenario
-- Every 5 minutes

-- Manual trigger for testing
-- Run this to manually trigger analysis:
/*
SELECT
  net.http_post(
    url := 'https://fpxbhqibimekjhlumnmc.supabase.co/functions/v1/analyze-scenario',
    headers := '{"Content-Type": "application/json", "Authorization": "Bearer [SERVICE_ROLE_KEY]"}'::jsonb,
    body := '{}'::jsonb
  );
*/
