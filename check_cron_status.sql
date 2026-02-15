-- Check if cron jobs are active and when they last ran
SELECT 
  jobid,
  jobname,
  schedule,
  active,
  nodename,
  nodeport,
  database
FROM cron.job
WHERE jobname LIKE '%ai-%'
ORDER BY jobid DESC;

-- Check recent cron job runs
SELECT 
  runid,
  jobid,
  job_pid,
  database,
  username,
  command,
  status,
  return_message,
  start_time,
  end_time
FROM cron.job_run_details
WHERE jobid IN (
  SELECT jobid FROM cron.job WHERE jobname LIKE '%ai-%'
)
ORDER BY start_time DESC
LIMIT 10;
