-- ============================================================================
-- 049: SEED AI CAST + INSTANT LOBBY PRE-FILL
-- ============================================================================
-- Run this in Supabase SQL Editor to:
-- 1. Seed all 40 AI cast members (skip duplicates)
-- 2. Create instant_fill_game() function for Party/Blitz/Sprint modes
-- ============================================================================

-- ─── STEP 0: Check current AI count ────────────────────────────────────────
DO $$
DECLARE v_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_count FROM cast_members WHERE is_ai_player = true;
  RAISE NOTICE '🔍 Current AI cast members: %', v_count;
END $$;

-- ─── STEP 1: Expand archetype constraint (idempotent) ──────────────────────
ALTER TABLE public.cast_members DROP CONSTRAINT IF EXISTS cast_members_archetype_check;
ALTER TABLE public.cast_members ADD CONSTRAINT cast_members_archetype_check
  CHECK (archetype IN (
    'queen', 'villain', 'wildcard', 'sweetheart', 'strategist',
    'comedian', 'troublemaker', 'diva', 'hothead',
    'mastermind', 'provocateur', 'peacemaker', 'socialite', 'underdog',
    'flirt', 'loyalist', 'backstabber', 'drama_magnet', 'boss',
    'rebel', 'influencer', 'empath', 'schemer', 'firecracker',
    'enigma', 'showstopper'
  ));

-- ─── STEP 2: Seed all AI characters (skip if display_name exists) ──────────

-- Helper: insert only if not exists
CREATE OR REPLACE FUNCTION seed_ai_if_missing(
  p_full_name TEXT, p_display_name TEXT, p_archetype TEXT,
  p_traits TEXT[], p_backstory TEXT, p_screen_time TEXT DEFAULT 'medium'
) RETURNS VOID AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM cast_members WHERE display_name = p_display_name AND is_ai_player = true) THEN
    INSERT INTO cast_members (full_name, display_name, archetype, personality_traits, backstory, status, screen_time_score, is_ai_player,
      avatar_url, ai_personality_config)
    VALUES (
      p_full_name, p_display_name, p_archetype, p_traits, p_backstory, 'active', p_screen_time, true,
      'https://api.dicebear.com/7.x/avataaars/svg?seed=' || lower(p_display_name),
      jsonb_build_object(
        'traits', jsonb_build_object(
          'honesty', 0.5 + random() * 0.4,
          'aggression', 0.3 + random() * 0.6,
          'loyalty', 0.2 + random() * 0.7,
          'strategic_thinking', 0.3 + random() * 0.6,
          'drama_seeking', 0.3 + random() * 0.6,
          'social_activity', 0.4 + random() * 0.5
        )
      )
    );
    RAISE NOTICE '✅ Added: % (%)', p_display_name, p_archetype;
  ELSE
    RAISE NOTICE '⏭️ Skipped (exists): %', p_display_name;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- QUEENS (4)
SELECT seed_ai_if_missing('Cassandra Blake', 'Cassandra', 'queen', ARRAY['strategic','intelligent','ambitious','manipulative'], 'Former corporate exec who stays three steps ahead.', 'high');
SELECT seed_ai_if_missing('Victoria Sterling', 'Victoria', 'queen', ARRAY['diplomatic','elegant','persuasive','protective'], 'Former diplomat who builds loyal followings through charm.', 'high');
SELECT seed_ai_if_missing('Dominique Reeves', 'Dominique', 'queen', ARRAY['dramatic','unpredictable','charismatic','ruthless'], 'Reality TV star who thrives on chaos and attention.', 'high');
SELECT seed_ai_if_missing('Serena Blackwood', 'Serena', 'queen', ARRAY['observant','calculating','quiet','deadly'], 'Chess grandmaster whose silence is more intimidating than any threat.', 'medium');

-- VILLAINS (4)
SELECT seed_ai_if_missing('Madison Voss', 'Madison', 'villain', ARRAY['deceptive','ruthless','charming','selfish'], 'Smiles to your face while plotting your downfall.', 'high');
SELECT seed_ai_if_missing('Raven Cross', 'Raven', 'villain', ARRAY['confrontational','aggressive','fearless','vindictive'], 'Loves stirring up conflict and watching alliances crumble.', 'high');
SELECT seed_ai_if_missing('Scarlett Kane', 'Scarlett', 'villain', ARRAY['manipulative','cunning','patient','cold'], 'Master manipulator who plants seeds of doubt.', 'medium');
SELECT seed_ai_if_missing('Natasha Wilde', 'Natasha', 'villain', ARRAY['opportunistic','selfish','calculating','bold'], 'Only loyal to herself. Switches sides whenever it benefits her.', 'medium');

-- WILDCARDS (4)
SELECT seed_ai_if_missing('Zoe Harper', 'Zoe', 'wildcard', ARRAY['unpredictable','spontaneous','energetic','fun'], 'Plays by her own rules. Decisions made by coin flip.', 'high');
SELECT seed_ai_if_missing('Phoenix Martinez', 'Phoenix', 'wildcard', ARRAY['rebellious','independent','creative','bold'], 'Refuses to follow anyone''s playbook.', 'medium');
SELECT seed_ai_if_missing('Luna Brooks', 'Luna', 'wildcard', ARRAY['whimsical','creative','emotional','impulsive'], 'Votes based on vibes and intuition.', 'medium');
SELECT seed_ai_if_missing('Jade Monroe', 'Jade', 'wildcard', ARRAY['risk-taker','bold','fearless','strategic'], 'Professional poker player who loves high-stakes moves.', 'medium');

-- SWEETHEARTS (3)
SELECT seed_ai_if_missing('Emma Grace', 'Emma', 'sweetheart', ARRAY['kind','loyal','emotional','genuine'], 'Believes in loyalty and friendship above all.', 'medium');
SELECT seed_ai_if_missing('Sophie Chen', 'Sophie', 'sweetheart', ARRAY['diplomatic','kind','mediating','caring'], 'Keeps peace and builds bridges. Hates conflict.', 'low');
SELECT seed_ai_if_missing('Lily Anderson', 'Lily', 'sweetheart', ARRAY['optimistic','cheerful','trusting','naive'], 'Sees the best in everyone. Sometimes too trusting.', 'low');

-- STRATEGISTS (3)
SELECT seed_ai_if_missing('Olivia Knight', 'Olivia', 'strategist', ARRAY['analytical','observant','intelligent','calculating'], 'Data scientist who treats the game like an algorithm.', 'medium');
SELECT seed_ai_if_missing('Isabella Romano', 'Isabella', 'strategist', ARRAY['subtle','patient','shrewd','cautious'], 'Plays from the shadows, never drawing attention.', 'low');
SELECT seed_ai_if_missing('Aria Patel', 'Aria', 'strategist', ARRAY['patient','methodical','strategic','composed'], 'Plays the long game, thinking weeks ahead.', 'medium');

-- COMEDIANS (2)
SELECT seed_ai_if_missing('Ruby Davis', 'Ruby', 'comedian', ARRAY['funny','lighthearted','social','easygoing'], 'Stand-up comedian who keeps things light.', 'medium');
SELECT seed_ai_if_missing('Mia Thompson', 'Mia', 'comedian', ARRAY['friendly','outgoing','fun','neutral'], 'Just wants to make friends and have fun.', 'low');

-- TROUBLEMAKERS (3)
SELECT seed_ai_if_missing('Diamond Johnson', 'Diamond', 'troublemaker', ARRAY['confrontational','messy','honest','loud','real'], 'From Atlanta. Keeps it 100% real. Will clock your lies.', 'high');
SELECT seed_ai_if_missing('Keisha Williams', 'Keisha', 'troublemaker', ARRAY['provocative','fearless','direct','petty'], 'Brooklyn native. Zero tolerance for BS.', 'high');
SELECT seed_ai_if_missing('Tanisha Brooks', 'Tanisha', 'troublemaker', ARRAY['messy','strategic','bold','shady'], 'Reality TV vet from Houston. Starts beef and watches.', 'high');

-- DIVAS (2)
SELECT seed_ai_if_missing('Porsha Mitchell', 'Porsha', 'diva', ARRAY['glamorous','bougie','petty','fashionable'], 'LA influencer with 500K followers. Serves looks and reads.', 'high');
SELECT seed_ai_if_missing('Tiffany Hayes', 'Tiffany', 'diva', ARRAY['shady','sophisticated','witty','elegant'], 'Fashion designer from Miami. Throws shade elegantly.', 'high');

-- HOTHEADS (2)
SELECT seed_ai_if_missing('Jasmine Rivera', 'Jasmine', 'hothead', ARRAY['explosive','protective','loyal','aggressive'], 'From the Bronx. Rides for her people HARD.', 'high');
SELECT seed_ai_if_missing('India Carter', 'India', 'hothead', ARRAY['confrontational','fierce','real','passionate'], 'Chicago MMA fighter. Doesn''t start fights but finishes them.', 'high');

-- NEW ARCHETYPES (16)
SELECT seed_ai_if_missing('Alexis Monroe', 'Alexis', 'mastermind', ARRAY['calculating','patient','manipulative','brilliant'], 'Former chess prodigy. Sees the house as a board game.', 'high');
SELECT seed_ai_if_missing('Valentina Cruz', 'Valentina', 'provocateur', ARRAY['confrontational','fearless','brutally-honest','charismatic'], 'Miami club promoter. Says what everyone is thinking.', 'high');
SELECT seed_ai_if_missing('Harmony Jackson', 'Harmony', 'peacemaker', ARRAY['diplomatic','calm','empathetic','secretly-strategic'], 'Yoga instructor. Wants everyone to get along but will cut you off.', 'medium');
SELECT seed_ai_if_missing('Chanel Beaumont', 'Chanel', 'socialite', ARRAY['glamorous','connected','judgmental','image-obsessed'], 'Old money heiress. Judges everyone by social standing.', 'medium');
SELECT seed_ai_if_missing('Destiny Williams', 'Destiny', 'underdog', ARRAY['resilient','humble','determined','surprising'], 'Grew up in foster care. Everyone underestimates her.', 'medium');
SELECT seed_ai_if_missing('Sasha Valentino', 'Sasha', 'flirt', ARRAY['seductive','playful','manipulative','charming'], 'Model who knows exactly how to use charm to win.', 'high');
SELECT seed_ai_if_missing('Brianna Torres', 'Brianna', 'loyalist', ARRAY['loyal','protective','fierce','emotional'], 'Military brat. Loyalty over everything.', 'medium');
SELECT seed_ai_if_missing('Nadia Sinclair', 'Nadia', 'backstabber', ARRAY['two-faced','charming','ruthless','opportunistic'], 'PR exec. Best friend today, enemy tomorrow.', 'high');
SELECT seed_ai_if_missing('Tamara Washington', 'Tamara', 'drama_magnet', ARRAY['loud','reactive','entertaining','impulsive'], 'Bartender from Atlanta. Drama finds HER.', 'high');
SELECT seed_ai_if_missing('Monique Laurent', 'Monique', 'boss', ARRAY['authoritative','commanding','confident','intimidating'], 'CEO of her own beauty empire. Her word is law.', 'high');
SELECT seed_ai_if_missing('Storm Davis', 'Storm', 'rebel', ARRAY['defiant','independent','unpredictable','anti-authority'], 'Tattoo artist. Hates being told what to do.', 'medium');
SELECT seed_ai_if_missing('Coco Palmer', 'Coco', 'influencer', ARRAY['trendy','image-conscious','savvy','performative'], 'TikTok star with 2M followers. Everything is content.', 'medium');
SELECT seed_ai_if_missing('Sage Moreno', 'Sage', 'empath', ARRAY['intuitive','sensitive','perceptive','emotionally-intelligent'], 'Therapist who reads people like books.', 'medium');
SELECT seed_ai_if_missing('Priya Kapoor', 'Priya', 'schemer', ARRAY['devious','intelligent','patient','meticulous'], 'Lawyer with three backup plans for everything.', 'high');
SELECT seed_ai_if_missing('Blanca Fuentes', 'Blanca', 'firecracker', ARRAY['passionate','explosive','unapologetic','intense'], 'From Washington Heights. Zero to a hundred in two seconds.', 'high');
SELECT seed_ai_if_missing('Mystique Chen', 'Mystique', 'enigma', ARRAY['mysterious','quiet','observant','unpredictable'], 'Former intel analyst. Watches everything, says little.', 'low');
SELECT seed_ai_if_missing('Elektra Valentine', 'Elektra', 'showstopper', ARRAY['dramatic','theatrical','attention-seeking','talented'], 'Broadway actress. Every room is a stage.', 'high');

-- Cleanup helper
DROP FUNCTION seed_ai_if_missing(TEXT, TEXT, TEXT, TEXT[], TEXT, TEXT);

-- ─── STEP 3: Verify ────────────────────────────────────────────────────────
DO $$
DECLARE
  v_total INTEGER;
  v_by_arch RECORD;
BEGIN
  SELECT COUNT(*) INTO v_total FROM cast_members WHERE is_ai_player = true AND status = 'active';
  RAISE NOTICE '';
  RAISE NOTICE '═══════════════════════════════════════';
  RAISE NOTICE '🎭 TOTAL AI CAST MEMBERS: %', v_total;
  RAISE NOTICE '═══════════════════════════════════════';
  FOR v_by_arch IN
    SELECT archetype, COUNT(*) as cnt
    FROM cast_members WHERE is_ai_player = true AND status = 'active'
    GROUP BY archetype ORDER BY cnt DESC
  LOOP
    RAISE NOTICE '  %-15s  %', v_by_arch.archetype, v_by_arch.cnt;
  END LOOP;
  RAISE NOTICE '═══════════════════════════════════════';
END $$;

-- ─── STEP 4: Create instant_fill_game() — fills lobby BEFORE game starts ───
CREATE OR REPLACE FUNCTION public.instant_fill_game(
  p_game_id UUID,
  p_target_count INTEGER DEFAULT 19
)
RETURNS JSONB AS $$
DECLARE
  v_ai RECORD;
  v_added INTEGER := 0;
  v_current INTEGER;
  v_needed INTEGER;
  v_names TEXT[] := '{}';
BEGIN
  -- How many are already in the game?
  SELECT COUNT(*) INTO v_current
  FROM mm_game_cast WHERE game_id = p_game_id;

  v_needed := GREATEST(0, p_target_count - v_current);

  IF v_needed = 0 THEN
    RETURN jsonb_build_object('success', true, 'added', 0, 'message', 'Lobby already full');
  END IF;

  -- Pick random AI not already in this game
  FOR v_ai IN
    SELECT cm.id, cm.display_name, cm.archetype
    FROM cast_members cm
    WHERE cm.is_ai_player = true
      AND cm.status = 'active'
      AND NOT EXISTS (
        SELECT 1 FROM mm_game_cast gc
        WHERE gc.game_id = p_game_id AND gc.cast_member_id = cm.id
      )
    ORDER BY RANDOM()
    LIMIT v_needed
  LOOP
    INSERT INTO mm_game_cast (game_id, cast_member_id, status, joined_at)
    VALUES (p_game_id, v_ai.id, 'active', NOW())
    ON CONFLICT DO NOTHING;

    v_added := v_added + 1;
    v_names := v_names || v_ai.display_name;
  END LOOP;

  -- Update player count
  UPDATE mm_games
  SET current_players = (SELECT COUNT(*) FROM mm_game_cast WHERE game_id = p_game_id)
  WHERE id = p_game_id;

  RETURN jsonb_build_object(
    'success', true,
    'added', v_added,
    'needed', v_needed,
    'cast', v_names,
    'total_in_game', v_current + v_added
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.instant_fill_game(UUID, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.instant_fill_game(UUID, INTEGER) TO service_role;

COMMENT ON FUNCTION public.instant_fill_game IS
  'Instantly fills a game lobby with AI cast members up to target count.
   Used by Party/Blitz/Sprint modes so lobby is full before game starts.
   AI join with status active (not joined) so they count immediately.';
