-- =====================================================
-- ADD MORE SCENARIO TYPES
-- Expand scenario variety for AI Director
-- =====================================================

-- Drop old check constraint
ALTER TABLE public.scenarios DROP CONSTRAINT IF EXISTS scenarios_scenario_type_check;

-- Add new check constraint with expanded types
ALTER TABLE public.scenarios
ADD CONSTRAINT scenarios_scenario_type_check
CHECK (scenario_type IN (
  -- Original types
  'alliance',      -- Test or form alliances
  'conflict',      -- Direct confrontations
  'strategy',      -- Strategic decisions
  'personal',      -- Personal moments/growth
  'wildcard',      -- Unexpected twists

  -- New drama types
  'betrayal',      -- Betrayal opportunities
  'revelation',    -- Secrets revealed
  'confession',    -- Force confessions
  'confrontation', -- Direct face-offs
  'challenge',     -- Competitive challenges

  -- Social dynamics
  'loyalty_test',  -- Test alliance loyalty
  'power_shift',   -- Change power dynamics
  'reputation',    -- Affect social standing
  'gossip',        -- Spread or address rumors

  -- Game mechanics
  'immunity',      -- Immunity-related
  'nomination',    -- Nomination scenarios
  'vote',          -- Voting decisions
  'elimination',   -- Elimination-related

  -- Emotional arcs
  'redemption',    -- Redemption opportunities
  'downfall',      -- Villain downfalls
  'underdog',      -- Underdog moments
  'friendship',    -- Friendship tests

  -- Production twists
  'twist',         -- Game twists
  'reward',        -- Luxury rewards
  'punishment',    -- Consequences
  'sacrifice'      -- Sacrifice for others
));

-- Update AI Director prompt in function (documentation)
COMMENT ON COLUMN public.scenarios.scenario_type IS
'Scenario type categories:
DRAMA: betrayal, revelation, confession, confrontation, challenge
SOCIAL: alliance, loyalty_test, power_shift, reputation, gossip
GAME: immunity, nomination, vote, elimination, conflict
EMOTIONAL: redemption, downfall, underdog, romance, friendship, personal
PRODUCTION: twist, reward, punishment, sacrifice, strategy, wildcard';
