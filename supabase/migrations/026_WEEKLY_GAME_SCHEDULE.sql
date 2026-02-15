-- =====================================================
-- WEEKLY GAME SCHEDULE
-- Saturday: Hot seat nominations
-- Sunday 7:30pm ET: Elimination announcements
-- Sunday 8:00pm ET: New queen selection
-- =====================================================

-- =====================================================
-- 1. SATURDAY HOT SEAT NOMINATIONS
-- =====================================================

CREATE OR REPLACE FUNCTION public.start_saturday_hot_seat(p_game_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_game RECORD;
  v_current_queen UUID;
  v_week_number INTEGER;
  v_nomination_round_id UUID;
BEGIN

  -- Get game info
  SELECT * INTO v_game FROM mm_games WHERE id = p_game_id;

  IF NOT FOUND OR v_game.status != 'active' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Game not found or not active'
    );
  END IF;

  -- Get current queen
  SELECT queen_id, week_number INTO v_current_queen, v_week_number
  FROM mm_weekly_queens
  WHERE game_id = p_game_id
    AND status = 'active'
  ORDER BY week_number DESC
  LIMIT 1;

  IF v_current_queen IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'No active queen found'
    );
  END IF;

  -- Create nomination round
  INSERT INTO mm_hot_seat_nomination_rounds (
    game_id,
    week_number,
    queen_id,
    status,
    queen_nomination_deadline,
    house_vote_deadline,
    created_at
  ) VALUES (
    p_game_id,
    v_week_number,
    v_current_queen,
    'queen_nominating',
    NOW() + INTERVAL '4 hours',  -- Queen has 4 hours to nominate
    NOW() + INTERVAL '12 hours', -- House vote ends 12 hours later
    NOW()
  )
  RETURNING id INTO v_nomination_round_id;

  -- Notify queen to make nomination
  INSERT INTO mm_tea_spot_notifications (
    cast_member_id,
    type,
    title,
    message,
    link_url,
    is_read
  )
  SELECT
    v_current_queen,
    'hot_seat_nomination',
    '👑 Time to Nominate!',
    'As this week''s Queen, you must nominate ONE cast member for the hot seat. Choose wisely...',
    '/pages/hot-seat-nomination.html?game=' || p_game_id,
    false;

  -- Notify all cast members
  INSERT INTO mm_tea_spot_notifications (
    cast_member_id,
    type,
    title,
    message,
    link_url,
    is_read
  )
  SELECT
    cm.id,
    'hot_seat_voting',
    '🔥 Hot Seat Saturday',
    'The Queen is making her nomination. Soon you''ll vote to put someone else on the hot seat.',
    '/pages/hot-seat-vote.html?game=' || p_game_id,
    false
  FROM cast_members cm
  JOIN mm_game_cast gc ON cm.id = gc.cast_member_id
  WHERE gc.game_id = p_game_id
    AND cm.status = 'active'
    AND cm.id != v_current_queen;

  RETURN jsonb_build_object(
    'success', true,
    'game_id', p_game_id,
    'week_number', v_week_number,
    'queen_id', v_current_queen,
    'nomination_round_id', v_nomination_round_id,
    'queen_deadline', NOW() + INTERVAL '4 hours',
    'house_vote_deadline', NOW() + INTERVAL '12 hours'
  );

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 2. SUNDAY 7:30PM ELIMINATION ANNOUNCEMENT
-- =====================================================

CREATE OR REPLACE FUNCTION public.announce_elimination(p_game_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_voting_round RECORD;
  v_eliminated_id UUID;
  v_eliminated_name TEXT;
  v_vote_breakdown JSONB;
BEGIN

  -- Get most recent voting round
  SELECT * INTO v_voting_round
  FROM mm_voting_rounds
  WHERE game_id = p_game_id
    AND status = 'closed'
    AND elimination_executed_at IS NULL
  ORDER BY round_number DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'No closed voting round found'
    );
  END IF;

  -- Determine who was eliminated (queen direct or house vote)
  v_eliminated_id := COALESCE(
    v_voting_round.queen_direct_elimination_id,
    v_voting_round.house_vote_eliminated_id
  );

  IF v_eliminated_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'No eliminated cast member found in voting round'
    );
  END IF;

  -- Get eliminated cast member name
  SELECT display_name INTO v_eliminated_name
  FROM cast_members
  WHERE id = v_eliminated_id;

  -- Mark cast member as eliminated
  UPDATE cast_members
  SET
    status = 'eliminated',
    eliminated_at = NOW(),
    updated_at = NOW()
  WHERE id = v_eliminated_id;

  -- Update voting round
  UPDATE mm_voting_rounds
  SET
    elimination_executed_at = NOW(),
    updated_at = NOW()
  WHERE id = v_voting_round.id;

  -- Get vote breakdown
  SELECT jsonb_build_object(
    'votes_for_a', v_voting_round.votes_for_a,
    'votes_for_b', v_voting_round.votes_for_b,
    'nominee_a_id', v_voting_round.nominee_a_id,
    'nominee_b_id', v_voting_round.nominee_b_id,
    'eliminated_id', v_eliminated_id,
    'eliminated_name', v_eliminated_name
  ) INTO v_vote_breakdown;

  -- Notify all cast members
  INSERT INTO mm_tea_spot_notifications (
    cast_member_id,
    type,
    title,
    message,
    link_url,
    is_read
  )
  SELECT
    cm.id,
    'elimination_announcement',
    '📺 ELIMINATION RESULTS',
    v_eliminated_name || ' has been eliminated from Mansion Mayhem.',
    '/pages/elimination-results.html?game=' || p_game_id,
    false
  FROM cast_members cm
  JOIN mm_game_cast gc ON cm.id = gc.cast_member_id
  WHERE gc.game_id = p_game_id
    AND cm.status IN ('active', 'eliminated');

  -- Update game current week if needed
  UPDATE mm_games
  SET
    current_week = current_week + 1,
    updated_at = NOW()
  WHERE id = p_game_id;

  RETURN jsonb_build_object(
    'success', true,
    'game_id', p_game_id,
    'eliminated_id', v_eliminated_id,
    'eliminated_name', v_eliminated_name,
    'vote_breakdown', v_vote_breakdown,
    'announced_at', NOW()
  );

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 3. SUNDAY 8:00PM NEW QUEEN SELECTION
-- =====================================================

CREATE OR REPLACE FUNCTION public.start_queen_selection(p_game_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_game RECORD;
  v_current_week INTEGER;
  v_previous_queen UUID;
BEGIN

  -- Get game info
  SELECT * INTO v_game FROM mm_games WHERE id = p_game_id;

  IF NOT FOUND OR v_game.status != 'active' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Game not found or not active'
    );
  END IF;

  v_current_week := v_game.current_week;

  -- Mark previous queen as inactive
  UPDATE mm_weekly_queens
  SET
    status = 'completed',
    ended_at = NOW(),
    updated_at = NOW()
  WHERE game_id = p_game_id
    AND status = 'active'
  RETURNING queen_id INTO v_previous_queen;

  -- Notify all cast members that queen selection is open
  INSERT INTO mm_tea_spot_notifications (
    cast_member_id,
    type,
    title,
    message,
    link_url,
    is_read
  )
  SELECT
    cm.id,
    'queen_selection',
    '👑 NEW QUEEN SELECTION',
    'It''s time to select Week ' || v_current_week || '''s Queen. Vote now!',
    '/pages/queen-selection.html?game=' || p_game_id,
    false
  FROM cast_members cm
  JOIN mm_game_cast gc ON cm.id = gc.cast_member_id
  WHERE gc.game_id = p_game_id
    AND cm.status = 'active';

  RETURN jsonb_build_object(
    'success', true,
    'game_id', p_game_id,
    'week_number', v_current_week,
    'previous_queen', v_previous_queen,
    'selection_started_at', NOW()
  );

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 4. CREATE HOT SEAT NOMINATION ROUNDS TABLE
-- =====================================================

CREATE TABLE IF NOT EXISTS public.mm_hot_seat_nomination_rounds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id UUID NOT NULL REFERENCES public.mm_games(id) ON DELETE CASCADE,
  week_number INTEGER NOT NULL,
  queen_id UUID NOT NULL REFERENCES public.cast_members(id),

  -- Queen's direct nomination
  queen_nominee_id UUID REFERENCES public.cast_members(id),
  queen_nominated_at TIMESTAMPTZ,

  -- House vote results
  house_nominee_id UUID REFERENCES public.cast_members(id),
  house_vote_closed_at TIMESTAMPTZ,

  -- Status tracking
  status TEXT NOT NULL DEFAULT 'queen_nominating' CHECK (status IN (
    'queen_nominating',  -- Waiting for queen to nominate
    'house_voting',      -- Queen nominated, house is voting
    'completed'          -- Both nominees selected
  )),

  -- Deadlines
  queen_nomination_deadline TIMESTAMPTZ NOT NULL,
  house_vote_deadline TIMESTAMPTZ NOT NULL,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_hot_seat_rounds_game ON mm_hot_seat_nomination_rounds(game_id);
CREATE INDEX idx_hot_seat_rounds_week ON mm_hot_seat_nomination_rounds(game_id, week_number);
CREATE INDEX idx_hot_seat_rounds_status ON mm_hot_seat_nomination_rounds(status);

-- =====================================================
-- 5. CRON JOBS FOR WEEKLY SCHEDULE
-- =====================================================

-- Saturday 12pm ET (5pm UTC) - Start hot seat nominations
SELECT cron.schedule(
  'hot-seat-saturday',
  '0 17 * * 6',  -- 5pm UTC on Saturdays (12pm ET)
  $$
  SELECT public.start_saturday_hot_seat(id)
  FROM mm_games
  WHERE status = 'active';
  $$
);

-- Sunday 7:30pm ET (12:30am UTC Monday) - Announce eliminations
SELECT cron.schedule(
  'elimination-sunday',
  '30 0 * * 1',  -- 12:30am UTC on Mondays (7:30pm ET Sunday)
  $$
  SELECT public.announce_elimination(id)
  FROM mm_games
  WHERE status = 'active';
  $$
);

-- Sunday 8:00pm ET (1:00am UTC Monday) - Start new queen selection
SELECT cron.schedule(
  'queen-selection-sunday',
  '0 1 * * 1',  -- 1:00am UTC on Mondays (8:00pm ET Sunday)
  $$
  SELECT public.start_queen_selection(id)
  FROM mm_games
  WHERE status = 'active';
  $$
);

-- =====================================================
-- 6. ADD GAME SCHEDULE INFO FUNCTION
-- =====================================================

CREATE OR REPLACE FUNCTION public.get_weekly_schedule(p_game_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_game RECORD;
  v_current_queen UUID;
  v_week_number INTEGER;
  v_next_saturday TIMESTAMPTZ;
  v_next_sunday TIMESTAMPTZ;
BEGIN

  SELECT * INTO v_game FROM mm_games WHERE id = p_game_id;

  -- Get current queen
  SELECT queen_id, week_number INTO v_current_queen, v_week_number
  FROM mm_weekly_queens
  WHERE game_id = p_game_id
    AND status = 'active'
  ORDER BY week_number DESC
  LIMIT 1;

  -- Calculate next Saturday and Sunday
  v_next_saturday := date_trunc('week', NOW() AT TIME ZONE 'America/New_York')
    + INTERVAL '6 days'     -- Next Saturday
    + INTERVAL '12 hours';  -- 12pm ET

  v_next_sunday := date_trunc('week', NOW() AT TIME ZONE 'America/New_York')
    + INTERVAL '7 days'      -- Next Sunday
    + INTERVAL '19.5 hours'; -- 7:30pm ET

  -- If we're past Saturday this week, go to next week
  IF NOW() > v_next_saturday THEN
    v_next_saturday := v_next_saturday + INTERVAL '7 days';
    v_next_sunday := v_next_sunday + INTERVAL '7 days';
  END IF;

  RETURN jsonb_build_object(
    'game_id', p_game_id,
    'current_week', v_week_number,
    'current_queen', v_current_queen,
    'next_hot_seat_saturday', v_next_saturday,
    'next_elimination_sunday', v_next_sunday,
    'schedule', jsonb_build_array(
      jsonb_build_object(
        'day', 'Saturday 12pm ET',
        'event', 'Hot Seat Nominations',
        'description', 'Queen nominates 1, House votes for 1'
      ),
      jsonb_build_object(
        'day', 'Sunday 7:30pm ET',
        'event', 'Elimination Announcement',
        'description', 'One cast member eliminated'
      ),
      jsonb_build_object(
        'day', 'Sunday 8:00pm ET',
        'event', 'New Queen Selection',
        'description', 'Cast votes for next week''s Queen'
      )
    )
  );

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 7. UPDATE CHECK AND LAUNCH GAMES FUNCTION
-- =====================================================

-- Update to set game to active AND trigger first queen selection
CREATE OR REPLACE FUNCTION public.check_and_launch_sunday_games()
RETURNS JSONB AS $$
DECLARE
  v_game RECORD;
  v_launched_games JSONB := '[]'::JSONB;
  v_queen_result JSONB;
BEGIN

  -- Find games ready to launch (lobby closed at 7pm ET, now it's 8:30pm ET)
  FOR v_game IN
    SELECT id, title, waiting_lobby_ends_at, game_starts_at
    FROM mm_games
    WHERE status = 'waiting_lobby'
      AND waiting_lobby_ends_at < NOW()
      AND game_starts_at <= NOW()
  LOOP
    -- Launch the game to active status
    UPDATE mm_games
    SET
      status = 'active',
      started_at = NOW(),
      current_week = 1,
      updated_at = NOW()
    WHERE id = v_game.id;

    -- Immediately start first queen selection
    SELECT start_queen_selection(v_game.id) INTO v_queen_result;

    v_launched_games := v_launched_games || jsonb_build_object(
      'game_id', v_game.id,
      'title', v_game.title,
      'launched_at', NOW(),
      'queen_selection_started', v_queen_result
    );

    RAISE NOTICE '🎬 Game launched: % (ID: %) - Queen selection started', v_game.title, v_game.id;
  END LOOP;

  RETURN jsonb_build_object(
    'launched_count', jsonb_array_length(v_launched_games),
    'games', v_launched_games,
    'checked_at', NOW()
  );

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- GRANT PERMISSIONS
-- =====================================================

GRANT EXECUTE ON FUNCTION public.start_saturday_hot_seat(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.announce_elimination(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.start_queen_selection(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_weekly_schedule(UUID) TO authenticated;

-- =====================================================
-- COMMENTS
-- =====================================================

COMMENT ON FUNCTION public.start_saturday_hot_seat IS
'Starts Saturday hot seat nominations. Queen has 4 hours to nominate, then house votes for 12 hours.';

COMMENT ON FUNCTION public.announce_elimination IS
'Announces elimination results at Sunday 7:30pm ET. Marks cast member as eliminated.';

COMMENT ON FUNCTION public.start_queen_selection IS
'Starts new queen selection at Sunday 8:00pm ET. Marks previous queen as completed.';

COMMENT ON TABLE public.mm_hot_seat_nomination_rounds IS
'Tracks Saturday hot seat nomination rounds. Queen nominates 1, house votes for 1.';
