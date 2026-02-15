-- =====================================================
-- FIX GAME STATUS CONSTRAINT
-- Add missing statuses that code uses
-- =====================================================

-- Drop old constraint
ALTER TABLE public.mm_games DROP CONSTRAINT IF EXISTS mm_games_status_check;

-- Add comprehensive constraint with all statuses
ALTER TABLE public.mm_games
ADD CONSTRAINT mm_games_status_check
CHECK (status IN (
  'pending',        -- Initial state
  'recruiting',     -- Accepting players (used by frontend)
  'waiting_lobby',  -- Lobby phase 1 (used by lobby system)
  'active_lobby',   -- Lobby phase 2
  'active',         -- Game running
  'paused',         -- Temporarily paused
  'final_three',    -- Final 3 stage
  'finale',         -- Finale voting
  'completed',      -- Finished
  'cancelled'       -- Cancelled
));

-- Update any games with 'pending' to 'recruiting' for consistency
UPDATE public.mm_games
SET status = 'recruiting'
WHERE status = 'pending';

-- Add comment
COMMENT ON COLUMN public.mm_games.status IS
'Game status progression:
1. recruiting → Players join
2. waiting_lobby → Pre-lobby phase
3. active_lobby → Alliance formation phase
4. active → Game in progress
5. final_three → Final 3 stage
6. finale → Fan voting
7. completed → Game finished
8. cancelled → Game cancelled
Also: paused (temporary pause)';
