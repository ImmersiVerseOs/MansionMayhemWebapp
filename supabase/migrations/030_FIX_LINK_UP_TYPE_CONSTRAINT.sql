-- ============================================================================
-- FIX link_up_type CHECK CONSTRAINT
-- Allow 'duo', 'trio', 'group' values that the UI sends
-- ============================================================================

-- Drop the old constraint
ALTER TABLE mm_link_up_requests
DROP CONSTRAINT IF EXISTS mm_link_up_requests_link_up_type_check;

-- Create new constraint allowing the values the UI sends
ALTER TABLE mm_link_up_requests
ADD CONSTRAINT mm_link_up_requests_link_up_type_check
CHECK (link_up_type IN ('duo', 'trio', 'group'));

-- Success message
DO $$
BEGIN
  RAISE NOTICE '✅ link_up_type constraint fixed!';
  RAISE NOTICE '📍 Allowed values: duo, trio, group';
  RAISE NOTICE '';
  RAISE NOTICE '🤝 Link-up requests should now work!';
END $$;
