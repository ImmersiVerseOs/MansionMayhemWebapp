-- ============================================================================
-- FIX mm_link_up_requests SCHEMA
-- Add missing columns that the UI expects
-- ============================================================================

-- Add decline_count column (tracks how many people declined)
ALTER TABLE mm_link_up_requests
ADD COLUMN IF NOT EXISTS decline_count INTEGER DEFAULT 0;

-- Add accept_count column (tracks how many people accepted)
ALTER TABLE mm_link_up_requests
ADD COLUMN IF NOT EXISTS accept_count INTEGER DEFAULT 0;

-- Add invited_cast_ids array (if it doesn't exist)
ALTER TABLE mm_link_up_requests
ADD COLUMN IF NOT EXISTS invited_cast_ids UUID[];

-- Add custom_name for the alliance (if it doesn't exist)
ALTER TABLE mm_link_up_requests
ADD COLUMN IF NOT EXISTS custom_name TEXT;

-- Add comments
COMMENT ON COLUMN mm_link_up_requests.decline_count IS
  'Number of invited cast members who declined this request';

COMMENT ON COLUMN mm_link_up_requests.accept_count IS
  'Number of invited cast members who accepted this request';

COMMENT ON COLUMN mm_link_up_requests.invited_cast_ids IS
  'Array of cast member IDs invited to this alliance';

COMMENT ON COLUMN mm_link_up_requests.custom_name IS
  'Custom name for the alliance (optional)';

-- Create index for invited_cast_ids lookups
CREATE INDEX IF NOT EXISTS idx_link_up_requests_invited_cast_ids
ON mm_link_up_requests USING GIN (invited_cast_ids);

-- Success message
DO $$
BEGIN
  RAISE NOTICE '✅ Link-up requests schema fixed!';
  RAISE NOTICE '📍 Added: decline_count (integer)';
  RAISE NOTICE '📍 Added: accept_count (integer)';
  RAISE NOTICE '📍 Added: invited_cast_ids (uuid[])';
  RAISE NOTICE '📍 Added: custom_name (text)';
  RAISE NOTICE '';
  RAISE NOTICE '🤝 Alliance link-up requests should now work!';
END $$;
