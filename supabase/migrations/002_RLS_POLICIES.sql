-- ============================================================================
-- MANSION MAYHEM - RLS POLICIES
-- ============================================================================
-- Consistent, minimal RLS policies designed to eliminate conflicts
-- Service role bypasses RLS for edge functions
-- ============================================================================

-- ============================================================================
-- 1. CAST_MEMBERS - Public read, admin write
-- ============================================================================
ALTER TABLE public.cast_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "service_role_all" ON public.cast_members;
CREATE POLICY "service_role_all" ON public.cast_members
  FOR ALL USING (auth.role() = 'service_role');

-- PUBLIC read access (for guest viewing of AI characters)
DROP POLICY IF EXISTS "public_read" ON public.cast_members;
CREATE POLICY "public_read" ON public.cast_members
  FOR SELECT USING (true);

-- Admin write access
DROP POLICY IF EXISTS "admin_write" ON public.cast_members;
CREATE POLICY "admin_write" ON public.cast_members
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'super_admin')
    )
  );

-- ============================================================================
-- 2. PROFILES - Users can read/update their own profile
-- ============================================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "service_role_all" ON public.profiles;
CREATE POLICY "service_role_all" ON public.profiles
  FOR ALL USING (auth.role() = 'service_role');

DROP POLICY IF EXISTS "users_read_own" ON public.profiles;
CREATE POLICY "users_read_own" ON public.profiles
  FOR SELECT USING (id = auth.uid());

DROP POLICY IF EXISTS "users_update_own" ON public.profiles;
CREATE POLICY "users_update_own" ON public.profiles
  FOR UPDATE USING (id = auth.uid());

DROP POLICY IF EXISTS "users_insert_own" ON public.profiles;
CREATE POLICY "users_insert_own" ON public.profiles
  FOR INSERT WITH CHECK (id = auth.uid());

-- ============================================================================
-- 3. MM_GAMES - Public read, admin write
-- ============================================================================
ALTER TABLE public.mm_games ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "service_role_all" ON public.mm_games;
CREATE POLICY "service_role_all" ON public.mm_games
  FOR ALL USING (auth.role() = 'service_role');

DROP POLICY IF EXISTS "public_read" ON public.mm_games;
CREATE POLICY "public_read" ON public.mm_games
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "admin_write" ON public.mm_games;
CREATE POLICY "admin_write" ON public.mm_games
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'super_admin')
    )
  );

-- ============================================================================
-- 4. MM_GAME_CAST - Public read, admin write
-- ============================================================================
ALTER TABLE public.mm_game_cast ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "service_role_all" ON public.mm_game_cast;
CREATE POLICY "service_role_all" ON public.mm_game_cast
  FOR ALL USING (auth.role() = 'service_role');

DROP POLICY IF EXISTS "public_read" ON public.mm_game_cast;
CREATE POLICY "public_read" ON public.mm_game_cast
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "admin_write" ON public.mm_game_cast;
CREATE POLICY "admin_write" ON public.mm_game_cast
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'super_admin')
    )
  );

-- ============================================================================
-- 5. MM_GAME_STAGES - Public read, admin write
-- ============================================================================
ALTER TABLE public.mm_game_stages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "service_role_all" ON public.mm_game_stages;
CREATE POLICY "service_role_all" ON public.mm_game_stages
  FOR ALL USING (auth.role() = 'service_role');

DROP POLICY IF EXISTS "public_read" ON public.mm_game_stages;
CREATE POLICY "public_read" ON public.mm_game_stages
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "admin_write" ON public.mm_game_stages;
CREATE POLICY "admin_write" ON public.mm_game_stages
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'super_admin')
    )
  );

-- ============================================================================
-- 6. SCENARIOS - Public read, admin write
-- ============================================================================
ALTER TABLE public.scenarios ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "service_role_all" ON public.scenarios;
CREATE POLICY "service_role_all" ON public.scenarios
  FOR ALL USING (auth.role() = 'service_role');

DROP POLICY IF EXISTS "public_read" ON public.scenarios;
CREATE POLICY "public_read" ON public.scenarios
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "admin_write" ON public.scenarios;
CREATE POLICY "admin_write" ON public.scenarios
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'super_admin')
    )
  );

-- ============================================================================
-- 7. SCENARIO_RESPONSES - Public read, authenticated write
-- ============================================================================
ALTER TABLE public.scenario_responses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "service_role_all" ON public.scenario_responses;
CREATE POLICY "service_role_all" ON public.scenario_responses
  FOR ALL USING (auth.role() = 'service_role');

DROP POLICY IF EXISTS "public_read" ON public.scenario_responses;
CREATE POLICY "public_read" ON public.scenario_responses
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "authenticated_write" ON public.scenario_responses;
CREATE POLICY "authenticated_write" ON public.scenario_responses
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- ============================================================================
-- 8. MM_LINK_UP_REQUESTS - Public read, authenticated write
-- ============================================================================
ALTER TABLE public.mm_link_up_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "service_role_all" ON public.mm_link_up_requests;
CREATE POLICY "service_role_all" ON public.mm_link_up_requests
  FOR ALL USING (auth.role() = 'service_role');

DROP POLICY IF EXISTS "public_read" ON public.mm_link_up_requests;
CREATE POLICY "public_read" ON public.mm_link_up_requests
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "authenticated_write" ON public.mm_link_up_requests;
CREATE POLICY "authenticated_write" ON public.mm_link_up_requests
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "authenticated_update" ON public.mm_link_up_requests;
CREATE POLICY "authenticated_update" ON public.mm_link_up_requests
  FOR UPDATE USING (auth.role() = 'authenticated');

-- ============================================================================
-- 9. MM_LINK_UP_RESPONSES - Public read, authenticated write
-- ============================================================================
ALTER TABLE public.mm_link_up_responses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "service_role_all" ON public.mm_link_up_responses;
CREATE POLICY "service_role_all" ON public.mm_link_up_responses
  FOR ALL USING (auth.role() = 'service_role');

DROP POLICY IF EXISTS "public_read" ON public.mm_link_up_responses;
CREATE POLICY "public_read" ON public.mm_link_up_responses
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "authenticated_write" ON public.mm_link_up_responses;
CREATE POLICY "authenticated_write" ON public.mm_link_up_responses
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- ============================================================================
-- 10. MM_ALLIANCE_ROOMS - Members only (private), quota enforcement
-- ============================================================================
ALTER TABLE public.mm_alliance_rooms ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "service_role_all" ON public.mm_alliance_rooms;
CREATE POLICY "service_role_all" ON public.mm_alliance_rooms
  FOR ALL USING (auth.role() = 'service_role');

-- Members can view own alliance rooms
DROP POLICY IF EXISTS "public_read" ON public.mm_alliance_rooms;
DROP POLICY IF EXISTS "Members can view own alliance rooms" ON public.mm_alliance_rooms;
CREATE POLICY "Members can view own alliance rooms" ON public.mm_alliance_rooms
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM cast_members cm
      WHERE cm.user_id = auth.uid() AND cm.id = ANY(mm_alliance_rooms.member_ids)
    )
  );

-- Alliance room creation with quota check
DROP POLICY IF EXISTS "authenticated_write" ON public.mm_alliance_rooms;
DROP POLICY IF EXISTS "Users can create alliance rooms" ON public.mm_alliance_rooms;
CREATE POLICY "Users can create alliance rooms" ON public.mm_alliance_rooms
  FOR INSERT TO authenticated
  WITH CHECK (
    -- Check user is in member_ids AND hasn't exceeded quota
    EXISTS (
      SELECT 1 FROM cast_members cm
      LEFT JOIN mm_alliance_quotas aq ON aq.cast_member_id = cm.id
      WHERE cm.user_id = auth.uid()
        AND cm.id = ANY(mm_alliance_rooms.member_ids)
        AND COALESCE(aq.active_alliances, 0) < COALESCE(aq.max_alliances, 5)
    )
    -- Verify room has max 5 members
    AND array_length(mm_alliance_rooms.member_ids, 1) <= 5
  );

DROP POLICY IF EXISTS "authenticated_update" ON public.mm_alliance_rooms;
CREATE POLICY "authenticated_update" ON public.mm_alliance_rooms
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM cast_members cm
      WHERE cm.user_id = auth.uid() AND cm.id = ANY(mm_alliance_rooms.member_ids)
    )
  );

-- ============================================================================
-- 11. MM_ALLIANCE_MESSAGES - Members only (private)
-- ============================================================================
ALTER TABLE public.mm_alliance_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "service_role_all" ON public.mm_alliance_messages;
CREATE POLICY "service_role_all" ON public.mm_alliance_messages
  FOR ALL USING (auth.role() = 'service_role');

-- Alliance members can view messages
DROP POLICY IF EXISTS "public_read" ON public.mm_alliance_messages;
DROP POLICY IF EXISTS "Alliance members can view messages" ON public.mm_alliance_messages;
CREATE POLICY "Alliance members can view messages" ON public.mm_alliance_messages
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM mm_alliance_rooms ar
      JOIN cast_members cm ON cm.id = ANY(ar.member_ids)
      WHERE ar.id = mm_alliance_messages.room_id AND cm.user_id = auth.uid()
    )
  );

-- Alliance members can send messages
DROP POLICY IF EXISTS "authenticated_write_if_member" ON public.mm_alliance_messages;
DROP POLICY IF EXISTS "Alliance members can send messages" ON public.mm_alliance_messages;
CREATE POLICY "Alliance members can send messages" ON public.mm_alliance_messages
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM mm_alliance_rooms ar
      JOIN cast_members cm ON cm.id = ANY(ar.member_ids)
      WHERE ar.id = mm_alliance_messages.room_id AND cm.user_id = auth.uid() AND cm.id = mm_alliance_messages.sender_cast_id
    )
  );

-- ============================================================================
-- 12. MM_RELATIONSHIP_EDGES - Public read, admin write
-- ============================================================================
ALTER TABLE public.mm_relationship_edges ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "service_role_all" ON public.mm_relationship_edges;
CREATE POLICY "service_role_all" ON public.mm_relationship_edges
  FOR ALL USING (auth.role() = 'service_role');

DROP POLICY IF EXISTS "public_read" ON public.mm_relationship_edges;
CREATE POLICY "public_read" ON public.mm_relationship_edges
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "admin_write" ON public.mm_relationship_edges;
CREATE POLICY "admin_write" ON public.mm_relationship_edges
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'super_admin')
    )
  );

-- ============================================================================
-- 13. MM_GRAPH_SCORES - Public read, admin write
-- ============================================================================
ALTER TABLE public.mm_graph_scores ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "service_role_all" ON public.mm_graph_scores;
CREATE POLICY "service_role_all" ON public.mm_graph_scores
  FOR ALL USING (auth.role() = 'service_role');

DROP POLICY IF EXISTS "public_read" ON public.mm_graph_scores;
CREATE POLICY "public_read" ON public.mm_graph_scores
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "admin_write" ON public.mm_graph_scores;
CREATE POLICY "admin_write" ON public.mm_graph_scores
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'super_admin')
    )
  );

-- ============================================================================
-- 14. MM_VOTING_ROUNDS - Public read, admin write
-- ============================================================================
ALTER TABLE public.mm_voting_rounds ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "service_role_all" ON public.mm_voting_rounds;
CREATE POLICY "service_role_all" ON public.mm_voting_rounds
  FOR ALL USING (auth.role() = 'service_role');

DROP POLICY IF EXISTS "public_read" ON public.mm_voting_rounds;
CREATE POLICY "public_read" ON public.mm_voting_rounds
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "admin_write" ON public.mm_voting_rounds;
CREATE POLICY "admin_write" ON public.mm_voting_rounds
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'super_admin')
    )
  );

-- ============================================================================
-- 15. MM_ELIMINATION_VOTES - Public read, authenticated write once per round
-- ============================================================================
ALTER TABLE public.mm_elimination_votes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "service_role_all" ON public.mm_elimination_votes;
CREATE POLICY "service_role_all" ON public.mm_elimination_votes
  FOR ALL USING (auth.role() = 'service_role');

DROP POLICY IF EXISTS "public_read" ON public.mm_elimination_votes;
CREATE POLICY "public_read" ON public.mm_elimination_votes
  FOR SELECT USING (true);

-- Write once per round (enforced by UNIQUE constraint)
DROP POLICY IF EXISTS "authenticated_write_once" ON public.mm_elimination_votes;
CREATE POLICY "authenticated_write_once" ON public.mm_elimination_votes
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- ============================================================================
-- 16. MM_CONFESSION_CARDS - Public read, authenticated write
-- ============================================================================
ALTER TABLE public.mm_confession_cards ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "service_role_all" ON public.mm_confession_cards;
CREATE POLICY "service_role_all" ON public.mm_confession_cards
  FOR ALL USING (auth.role() = 'service_role');

DROP POLICY IF EXISTS "public_read" ON public.mm_confession_cards;
CREATE POLICY "public_read" ON public.mm_confession_cards
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "authenticated_write" ON public.mm_confession_cards;
CREATE POLICY "authenticated_write" ON public.mm_confession_cards
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "admin_update" ON public.mm_confession_cards;
CREATE POLICY "admin_update" ON public.mm_confession_cards
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'super_admin')
    )
  );

-- ============================================================================
-- 17. MM_CONFESSION_REACTIONS - Public read, authenticated write
-- ============================================================================
ALTER TABLE public.mm_confession_reactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "service_role_all" ON public.mm_confession_reactions;
CREATE POLICY "service_role_all" ON public.mm_confession_reactions
  FOR ALL USING (auth.role() = 'service_role');

DROP POLICY IF EXISTS "public_read" ON public.mm_confession_reactions;
CREATE POLICY "public_read" ON public.mm_confession_reactions
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "authenticated_write" ON public.mm_confession_reactions;
CREATE POLICY "authenticated_write" ON public.mm_confession_reactions
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- ============================================================================
-- 18. USER_GAME_STATE - Users access their own state
-- ============================================================================
ALTER TABLE public.user_game_state ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "service_role_all" ON public.user_game_state;
CREATE POLICY "service_role_all" ON public.user_game_state
  FOR ALL USING (auth.role() = 'service_role');

DROP POLICY IF EXISTS "users_read_own" ON public.user_game_state;
CREATE POLICY "users_read_own" ON public.user_game_state
  FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS "users_write_own" ON public.user_game_state;
CREATE POLICY "users_write_own" ON public.user_game_state
  FOR ALL USING (user_id = auth.uid());

-- ============================================================================
-- 19. NOTIFICATIONS - Users access their own notifications
-- ============================================================================
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "service_role_all" ON public.notifications;
CREATE POLICY "service_role_all" ON public.notifications
  FOR ALL USING (auth.role() = 'service_role');

DROP POLICY IF EXISTS "users_read_own" ON public.notifications;
CREATE POLICY "users_read_own" ON public.notifications
  FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS "users_update_own" ON public.notifications;
CREATE POLICY "users_update_own" ON public.notifications
  FOR UPDATE USING (user_id = auth.uid());

-- ============================================================================
-- 20. USER_SETTINGS - Users access their own settings
-- ============================================================================
ALTER TABLE public.user_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "service_role_all" ON public.user_settings;
CREATE POLICY "service_role_all" ON public.user_settings
  FOR ALL USING (auth.role() = 'service_role');

DROP POLICY IF EXISTS "users_read_own" ON public.user_settings;
CREATE POLICY "users_read_own" ON public.user_settings
  FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS "users_write_own" ON public.user_settings;
CREATE POLICY "users_write_own" ON public.user_settings
  FOR ALL USING (user_id = auth.uid());

-- ============================================================================
-- 21. PAYMENT_TRANSACTIONS - Users read their own, admin sees all
-- ============================================================================
ALTER TABLE public.payment_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "service_role_all" ON public.payment_transactions;
CREATE POLICY "service_role_all" ON public.payment_transactions
  FOR ALL USING (auth.role() = 'service_role');

DROP POLICY IF EXISTS "users_read_own" ON public.payment_transactions;
CREATE POLICY "users_read_own" ON public.payment_transactions
  FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS "admin_read_all" ON public.payment_transactions;
CREATE POLICY "admin_read_all" ON public.payment_transactions
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'super_admin')
    )
  );

-- ============================================================================
-- 22. SCENARIO_TARGETS - Public read, admin write
-- ============================================================================
ALTER TABLE public.scenario_targets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "service_role_all" ON public.scenario_targets;
CREATE POLICY "service_role_all" ON public.scenario_targets
  FOR ALL USING (auth.role() = 'service_role');

DROP POLICY IF EXISTS "public_read" ON public.scenario_targets;
CREATE POLICY "public_read" ON public.scenario_targets
  FOR SELECT USING (true);

-- ============================================================================
-- 23. MM_SCENARIO_QUOTAS - Public read, admin write
-- ============================================================================
ALTER TABLE public.mm_scenario_quotas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "service_role_all" ON public.mm_scenario_quotas;
CREATE POLICY "service_role_all" ON public.mm_scenario_quotas
  FOR ALL USING (auth.role() = 'service_role');

DROP POLICY IF EXISTS "public_read" ON public.mm_scenario_quotas;
CREATE POLICY "public_read" ON public.mm_scenario_quotas
  FOR SELECT USING (true);

-- ============================================================================
-- 24. MM_ALLIANCE_QUOTAS - Public read, system write
-- ============================================================================
ALTER TABLE public.mm_alliance_quotas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "service_role_all" ON public.mm_alliance_quotas;
CREATE POLICY "service_role_all" ON public.mm_alliance_quotas
  FOR ALL USING (auth.role() = 'service_role');

DROP POLICY IF EXISTS "public_read" ON public.mm_alliance_quotas;
CREATE POLICY "public_read" ON public.mm_alliance_quotas
  FOR SELECT USING (true);

-- ============================================================================
-- 25. MM_QUEEN_SELECTIONS - Public read, admin write
-- ============================================================================
ALTER TABLE public.mm_queen_selections ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "service_role_all" ON public.mm_queen_selections;
CREATE POLICY "service_role_all" ON public.mm_queen_selections
  FOR ALL USING (auth.role() = 'service_role');

DROP POLICY IF EXISTS "public_read" ON public.mm_queen_selections;
CREATE POLICY "public_read" ON public.mm_queen_selections
  FOR SELECT USING (true);

-- ============================================================================
-- TRIGGER: Update Alliance Quotas
-- ============================================================================
-- Trigger to update alliance quotas when rooms are created/dissolved
CREATE OR REPLACE FUNCTION public.update_alliance_quotas()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Increment quota for all members when alliance created
    INSERT INTO mm_alliance_quotas (game_id, cast_member_id, active_alliances, max_alliances)
    SELECT NEW.game_id, unnest(NEW.member_ids), 1, 5
    ON CONFLICT (game_id, cast_member_id)
    DO UPDATE SET
      active_alliances = mm_alliance_quotas.active_alliances + 1,
      updated_at = NOW();

  ELSIF TG_OP = 'UPDATE' AND OLD.status = 'active' AND NEW.status IN ('dissolved', 'betrayed') THEN
    -- Decrement quota when alliance dissolved
    UPDATE mm_alliance_quotas SET
      active_alliances = GREATEST(0, active_alliances - 1),
      updated_at = NOW()
    WHERE game_id = NEW.game_id
      AND cast_member_id = ANY(NEW.member_ids);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS alliance_quota_update ON public.mm_alliance_rooms;
CREATE TRIGGER alliance_quota_update
  AFTER INSERT OR UPDATE ON public.mm_alliance_rooms
  FOR EACH ROW
  EXECUTE FUNCTION public.update_alliance_quotas();

-- ============================================================================
-- VERIFICATION
-- ============================================================================
DO $$
DECLARE
  policy_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO policy_count
  FROM pg_policies
  WHERE schemaname = 'public';

  RAISE NOTICE '✅ RLS Policies Created!';
  RAISE NOTICE 'Total policies: %', policy_count;
  RAISE NOTICE 'All tables secured with service_role bypass for edge functions.';
END $$;
