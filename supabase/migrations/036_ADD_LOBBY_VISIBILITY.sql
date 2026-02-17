-- Add lobby visibility feature
-- Allows lobbies to be private (invite-only) or public (appears in browser)

-- Add is_public column to mm_games
ALTER TABLE mm_games
ADD COLUMN IF NOT EXISTS is_public BOOLEAN NOT NULL DEFAULT false;

-- Add index for faster public lobby queries
CREATE INDEX IF NOT EXISTS idx_mm_games_public_status
ON mm_games(is_public, status)
WHERE is_public = true;

-- Add comment
COMMENT ON COLUMN mm_games.is_public IS 'Whether lobby appears in public lobby browser. false = private (invite-only), true = public (anyone can join)';
