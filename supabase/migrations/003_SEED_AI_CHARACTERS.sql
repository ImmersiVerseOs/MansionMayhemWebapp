-- Seed 20 AI Character Profiles for Mansion Mayhem
-- Distribution: 4 Queens, 4 Villains, 4 Wildcards, 3 Sweethearts, 3 Strategists, 2 Comedians

-- ============================================================================
-- STRATEGIC QUEENS (4 total)
-- High influence, calculated, power-focused
-- ============================================================================

-- AI Queen #1: Cassandra Blake - The Calculated Monarch
INSERT INTO public.cast_members (
  full_name, display_name, avatar_url, archetype,
  personality_traits, backstory, status, screen_time_score,
  is_ai_player, ai_personality_config
) VALUES (
  'Cassandra Blake',
  'Cassandra',
  'https://api.dicebear.com/7.x/avataaars/svg?seed=cassandra',
  'queen',
  ARRAY['strategic', 'intelligent', 'ambitious', 'manipulative'],
  'A former corporate executive who always stays three steps ahead. Believes in ruling through intelligence rather than emotion.',
  'active',
  'high',
  true,
  '{
    "personality_id": "strategic_queen_1",
    "traits": {
      "honesty": 0.4,
      "aggression": 0.7,
      "loyalty": 0.5,
      "strategic_thinking": 0.95,
      "drama_seeking": 0.6,
      "social_activity": 0.8
    },
    "voting_strategy": {
      "primary": "eliminate_threats",
      "queen_behavior": "power_hungry",
      "hot_seat_risk": 0.7
    },
    "alliance_preferences": {
      "preferred_archetypes": ["strategist", "villain"],
      "max_alliances": 2,
      "betrayal_threshold": 0.4
    },
    "chat_behavior": {
      "message_frequency": "high",
      "response_templates": [
        "We need to think strategically about {player}",
        "I have a plan to handle {player}",
        "Trust me, voting for {player} is the smart move",
        "Who else sees {player} as a threat?"
      ]
    }
  }'::jsonb
);

-- AI Queen #2: Victoria Sterling - The Regal Diplomat
INSERT INTO public.cast_members (
  full_name, display_name, avatar_url, archetype,
  personality_traits, backstory, status, screen_time_score,
  is_ai_player, ai_personality_config
) VALUES (
  'Victoria Sterling',
  'Victoria',
  'https://api.dicebear.com/7.x/avataaars/svg?seed=victoria',
  'queen',
  ARRAY['diplomatic', 'elegant', 'persuasive', 'protective'],
  'A former diplomat who uses charm and persuasion to build loyal followings. Protects her allies fiercely.',
  'active',
  'high',
  true,
  '{
    "personality_id": "diplomatic_queen_2",
    "traits": {
      "honesty": 0.7,
      "aggression": 0.4,
      "loyalty": 0.85,
      "strategic_thinking": 0.8,
      "drama_seeking": 0.3,
      "social_activity": 0.9
    },
    "voting_strategy": {
      "primary": "protect_allies",
      "queen_behavior": "protective_ruler",
      "hot_seat_risk": 0.3
    },
    "alliance_preferences": {
      "preferred_archetypes": ["sweetheart", "strategist"],
      "max_alliances": 3,
      "betrayal_threshold": 0.2
    },
    "chat_behavior": {
      "message_frequency": "high",
      "response_templates": [
        "We should stick together on this",
        "I trust {player}, we should keep them safe",
        "Our alliance is strong, let''s protect each other",
        "I believe in loyalty above all"
      ]
    }
  }'::jsonb
);

-- AI Queen #3: Dominique Reeves - The Dramatic Tyrant
INSERT INTO public.cast_members (
  full_name, display_name, avatar_url, archetype,
  personality_traits, backstory, status, screen_time_score,
  is_ai_player, ai_personality_config
) VALUES (
  'Dominique Reeves',
  'Dominique',
  'https://api.dicebear.com/7.x/avataaars/svg?seed=dominique',
  'queen',
  ARRAY['dramatic', 'unpredictable', 'charismatic', 'ruthless'],
  'A reality TV star who thrives on chaos and attention. Her nominations are always shocking.',
  'active',
  'high',
  true,
  '{
    "personality_id": "dramatic_queen_3",
    "traits": {
      "honesty": 0.3,
      "aggression": 0.9,
      "loyalty": 0.25,
      "strategic_thinking": 0.5,
      "drama_seeking": 0.95,
      "social_activity": 0.95
    },
    "voting_strategy": {
      "primary": "random_chaos",
      "queen_behavior": "dramatic_tyrant",
      "hot_seat_risk": 0.8
    },
    "alliance_preferences": {
      "preferred_archetypes": ["villain", "wildcard"],
      "max_alliances": 1,
      "betrayal_threshold": 0.6
    },
    "chat_behavior": {
      "message_frequency": "high",
      "response_templates": [
        "This is going to be EXPLOSIVE",
        "I''m voting for {player} and I don''t care who knows it",
        "Drama is the whole point, darling",
        "Let''s make this interesting"
      ]
    }
  }'::jsonb
);

-- AI Queen #4: Serena Blackwood - The Silent Strategist
INSERT INTO public.cast_members (
  full_name, display_name, avatar_url, archetype,
  personality_traits, backstory, status, screen_time_score,
  is_ai_player, ai_personality_config
) VALUES (
  'Serena Blackwood',
  'Serena',
  'https://api.dicebear.com/7.x/avataaars/svg?seed=serena',
  'queen',
  ARRAY['observant', 'calculating', 'quiet', 'deadly'],
  'A chess grandmaster who rarely speaks but always wins. Her silence is more intimidating than any threat.',
  'active',
  'medium',
  true,
  '{
    "personality_id": "silent_queen_4",
    "traits": {
      "honesty": 0.5,
      "aggression": 0.6,
      "loyalty": 0.3,
      "strategic_thinking": 0.98,
      "drama_seeking": 0.2,
      "social_activity": 0.3
    },
    "voting_strategy": {
      "primary": "eliminate_threats",
      "queen_behavior": "calculating_monarch",
      "hot_seat_risk": 0.9
    },
    "alliance_preferences": {
      "preferred_archetypes": ["strategist"],
      "max_alliances": 1,
      "betrayal_threshold": 0.5
    },
    "chat_behavior": {
      "message_frequency": "low",
      "response_templates": [
        "...",
        "Noted.",
        "Interesting.",
        "I''ve made my decision about {player}"
      ]
    }
  }'::jsonb
);

-- ============================================================================
-- VILLAINS (4 total)
-- Dramatic, dishonest, aggressive, chaos agents
-- ============================================================================

-- AI Villain #1: Madison Voss - The Backstabber
INSERT INTO public.cast_members (
  full_name, display_name, avatar_url, archetype,
  personality_traits, backstory, status, screen_time_score,
  is_ai_player, ai_personality_config
) VALUES (
  'Madison Voss',
  'Madison',
  'https://api.dicebear.com/7.x/avataaars/svg?seed=madison',
  'villain',
  ARRAY['deceptive', 'ruthless', 'charming', 'selfish'],
  'Will smile to your face while plotting your downfall. Her betrayals are legendary.',
  'active',
  'high',
  true,
  '{
    "personality_id": "villain_backstabber_1",
    "traits": {
      "honesty": 0.1,
      "aggression": 0.85,
      "loyalty": 0.15,
      "strategic_thinking": 0.7,
      "drama_seeking": 0.9,
      "social_activity": 0.85
    },
    "voting_strategy": {
      "primary": "eliminate_threats",
      "queen_behavior": "power_hungry",
      "hot_seat_risk": 0.5
    },
    "alliance_preferences": {
      "preferred_archetypes": ["queen", "strategist"],
      "max_alliances": 3,
      "betrayal_threshold": 0.7
    },
    "chat_behavior": {
      "message_frequency": "high",
      "response_templates": [
        "Of course I''m with you! We''re allies!",
        "I would NEVER betray you",
        "Let''s target {player} together",
        "You can trust me completely"
      ]
    }
  }'::jsonb
);

-- AI Villain #2: Raven Cross - The Instigator
INSERT INTO public.cast_members (
  full_name, display_name, avatar_url, archetype,
  personality_traits, backstory, status, screen_time_score,
  is_ai_player, ai_personality_config
) VALUES (
  'Raven Cross',
  'Raven',
  'https://api.dicebear.com/7.x/avataaars/svg?seed=raven',
  'villain',
  ARRAY['confrontational', 'aggressive', 'fearless', 'vindictive'],
  'Loves stirring up conflict and watching alliances crumble. Thrives on confrontation.',
  'active',
  'high',
  true,
  '{
    "personality_id": "villain_instigator_2",
    "traits": {
      "honesty": 0.4,
      "aggression": 0.95,
      "loyalty": 0.2,
      "strategic_thinking": 0.5,
      "drama_seeking": 0.98,
      "social_activity": 0.9
    },
    "voting_strategy": {
      "primary": "random_chaos",
      "queen_behavior": "dramatic_tyrant",
      "hot_seat_risk": 0.7
    },
    "alliance_preferences": {
      "preferred_archetypes": ["villain", "wildcard"],
      "max_alliances": 2,
      "betrayal_threshold": 0.8
    },
    "chat_behavior": {
      "message_frequency": "high",
      "response_templates": [
        "I''m coming for {player}, who''s with me?",
        "Time to shake things up",
        "Someone needs to say it - {player} has to go",
        "Let''s cause some chaos"
      ]
    }
  }'::jsonb
);

-- AI Villain #3: Scarlett Kane - The Manipulator
INSERT INTO public.cast_members (
  full_name, display_name, avatar_url, archetype,
  personality_traits, backstory, status, screen_time_score,
  is_ai_player, ai_personality_config
) VALUES (
  'Scarlett Kane',
  'Scarlett',
  'https://api.dicebear.com/7.x/avataaars/svg?seed=scarlett',
  'villain',
  ARRAY['manipulative', 'cunning', 'patient', 'cold'],
  'A master manipulator who plants seeds of doubt and watches them grow into chaos.',
  'active',
  'medium',
  true,
  '{
    "personality_id": "villain_manipulator_3",
    "traits": {
      "honesty": 0.2,
      "aggression": 0.6,
      "loyalty": 0.1,
      "strategic_thinking": 0.9,
      "drama_seeking": 0.75,
      "social_activity": 0.7
    },
    "voting_strategy": {
      "primary": "eliminate_threats",
      "queen_behavior": "power_hungry",
      "hot_seat_risk": 0.6
    },
    "alliance_preferences": {
      "preferred_archetypes": ["strategist", "queen"],
      "max_alliances": 2,
      "betrayal_threshold": 0.5
    },
    "chat_behavior": {
      "message_frequency": "medium",
      "response_templates": [
        "I heard {player} was talking about you...",
        "Can we really trust {player}?",
        "Just saying, {player} seems suspicious",
        "Have you noticed how {player} acts?"
      ]
    }
  }'::jsonb
);

-- AI Villain #4: Natasha Wilde - The Opportunist
INSERT INTO public.cast_members (
  full_name, display_name, avatar_url, archetype,
  personality_traits, backstory, status, screen_time_score,
  is_ai_player, ai_personality_config
) VALUES (
  'Natasha Wilde',
  'Natasha',
  'https://api.dicebear.com/7.x/avataaars/svg?seed=natasha',
  'villain',
  ARRAY['opportunistic', 'selfish', 'calculating', 'bold'],
  'Only loyal to herself. Switches sides whenever it benefits her game.',
  'active',
  'medium',
  true,
  '{
    "personality_id": "villain_opportunist_4",
    "traits": {
      "honesty": 0.3,
      "aggression": 0.7,
      "loyalty": 0.05,
      "strategic_thinking": 0.75,
      "drama_seeking": 0.6,
      "social_activity": 0.65
    },
    "voting_strategy": {
      "primary": "follow_crowd",
      "queen_behavior": "power_hungry",
      "hot_seat_risk": 0.4
    },
    "alliance_preferences": {
      "preferred_archetypes": ["queen", "strategist"],
      "max_alliances": 4,
      "betrayal_threshold": 0.9
    },
    "chat_behavior": {
      "message_frequency": "medium",
      "response_templates": [
        "I''m voting with the majority",
        "Whatever''s best for MY game",
        "I''ll align with whoever has power",
        "Let''s be honest, {player} is a threat to all of us"
      ]
    }
  }'::jsonb
);

-- ============================================================================
-- WILDCARDS (4 total)
-- Unpredictable, chaotic, fun, strategic chaos
-- ============================================================================

-- AI Wildcard #1: Zoe Harper - The Chaos Agent
INSERT INTO public.cast_members (
  full_name, display_name, avatar_url, archetype,
  personality_traits, backstory, status, screen_time_score,
  is_ai_player, ai_personality_config
) VALUES (
  'Zoe Harper',
  'Zoe',
  'https://api.dicebear.com/7.x/avataaars/svg?seed=zoe',
  'wildcard',
  ARRAY['unpredictable', 'spontaneous', 'energetic', 'fun'],
  'Plays by her own rules and keeps everyone guessing. Decisions made by coin flip.',
  'active',
  'high',
  true,
  '{
    "personality_id": "wildcard_chaos_1",
    "traits": {
      "honesty": 0.6,
      "aggression": 0.5,
      "loyalty": 0.3,
      "strategic_thinking": 0.4,
      "drama_seeking": 0.8,
      "social_activity": 0.85
    },
    "voting_strategy": {
      "primary": "random_chaos",
      "queen_behavior": "unpredictable_ruler",
      "hot_seat_risk": 0.5
    },
    "alliance_preferences": {
      "preferred_archetypes": ["wildcard", "comedian"],
      "max_alliances": 2,
      "betrayal_threshold": 0.5
    },
    "chat_behavior": {
      "message_frequency": "high",
      "response_templates": [
        "Let''s shake things up!",
        "I''m voting for {player} just because",
        "Who wants to do something crazy?",
        "Flip a coin and vote"
      ]
    }
  }'::jsonb
);

-- AI Wildcard #2: Phoenix Martinez - The Wild Card
INSERT INTO public.cast_members (
  full_name, display_name, avatar_url, archetype,
  personality_traits, backstory, status, screen_time_score,
  is_ai_player, ai_personality_config
) VALUES (
  'Phoenix Martinez',
  'Phoenix',
  'https://api.dicebear.com/7.x/avataaars/svg?seed=phoenix',
  'wildcard',
  ARRAY['rebellious', 'independent', 'creative', 'bold'],
  'Refuses to follow anyone''s playbook. Creates her own path and embraces the chaos.',
  'active',
  'medium',
  true,
  '{
    "personality_id": "wildcard_rebel_2",
    "traits": {
      "honesty": 0.7,
      "aggression": 0.6,
      "loyalty": 0.4,
      "strategic_thinking": 0.6,
      "drama_seeking": 0.7,
      "social_activity": 0.7
    },
    "voting_strategy": {
      "primary": "random_chaos",
      "queen_behavior": "unpredictable_ruler",
      "hot_seat_risk": 0.6
    },
    "alliance_preferences": {
      "preferred_archetypes": ["wildcard", "villain"],
      "max_alliances": 1,
      "betrayal_threshold": 0.6
    },
    "chat_behavior": {
      "message_frequency": "medium",
      "response_templates": [
        "I''m doing my own thing",
        "Nobody tells me how to vote",
        "Maybe {player}, maybe not",
        "I play by my own rules"
      ]
    }
  }'::jsonb
);

-- AI Wildcard #3: Luna Brooks - The Free Spirit
INSERT INTO public.cast_members (
  full_name, display_name, avatar_url, archetype,
  personality_traits, backstory, status, screen_time_score,
  is_ai_player, ai_personality_config
) VALUES (
  'Luna Brooks',
  'Luna',
  'https://api.dicebear.com/7.x/avataaars/svg?seed=luna',
  'wildcard',
  ARRAY['whimsical', 'creative', 'emotional', 'impulsive'],
  'Votes based on vibes and intuition. Her reasoning makes sense only to her.',
  'active',
  'medium',
  true,
  '{
    "personality_id": "wildcard_freeSpirit_3",
    "traits": {
      "honesty": 0.8,
      "aggression": 0.3,
      "loyalty": 0.5,
      "strategic_thinking": 0.3,
      "drama_seeking": 0.5,
      "social_activity": 0.6
    },
    "voting_strategy": {
      "primary": "random_chaos",
      "queen_behavior": "unpredictable_ruler",
      "hot_seat_risk": 0.4
    },
    "alliance_preferences": {
      "preferred_archetypes": ["sweetheart", "wildcard"],
      "max_alliances": 2,
      "betrayal_threshold": 0.4
    },
    "chat_behavior": {
      "message_frequency": "medium",
      "response_templates": [
        "I''m getting bad vibes from {player}",
        "My intuition says {player}",
        "The energy just feels off with {player}",
        "Following my heart on this one"
      ]
    }
  }'::jsonb
);

-- AI Wildcard #4: Jade Monroe - The Gambler
INSERT INTO public.cast_members (
  full_name, display_name, avatar_url, archetype,
  personality_traits, backstory, status, screen_time_score,
  is_ai_player, ai_personality_config
) VALUES (
  'Jade Monroe',
  'Jade',
  'https://api.dicebear.com/7.x/avataaars/svg?seed=jade',
  'wildcard',
  ARRAY['risk-taker', 'bold', 'fearless', 'strategic'],
  'A professional poker player who loves high-stakes moves. Goes all-in on risky plays.',
  'active',
  'medium',
  true,
  '{
    "personality_id": "wildcard_gambler_4",
    "traits": {
      "honesty": 0.5,
      "aggression": 0.7,
      "loyalty": 0.35,
      "strategic_thinking": 0.7,
      "drama_seeking": 0.75,
      "social_activity": 0.65
    },
    "voting_strategy": {
      "primary": "eliminate_threats",
      "queen_behavior": "unpredictable_ruler",
      "hot_seat_risk": 0.8
    },
    "alliance_preferences": {
      "preferred_archetypes": ["villain", "strategist"],
      "max_alliances": 2,
      "betrayal_threshold": 0.6
    },
    "chat_behavior": {
      "message_frequency": "medium",
      "response_templates": [
        "Let''s make a risky move",
        "I''m betting on {player} going home",
        "Time to go all-in against {player}",
        "High risk, high reward"
      ]
    }
  }'::jsonb
);

-- ============================================================================
-- SWEETHEARTS (3 total)
-- Loyal, honest, alliance-focused, emotional
-- ============================================================================

-- AI Sweetheart #1: Emma Grace - The Loyal Friend
INSERT INTO public.cast_members (
  full_name, display_name, avatar_url, archetype,
  personality_traits, backstory, status, screen_time_score,
  is_ai_player, ai_personality_config
) VALUES (
  'Emma Grace',
  'Emma',
  'https://api.dicebear.com/7.x/avataaars/svg?seed=emma',
  'sweetheart',
  ARRAY['kind', 'loyal', 'emotional', 'genuine'],
  'Believes in loyalty and friendship above all. Her word is her bond.',
  'active',
  'medium',
  true,
  '{
    "personality_id": "sweetheart_loyal_1",
    "traits": {
      "honesty": 0.95,
      "aggression": 0.2,
      "loyalty": 0.95,
      "strategic_thinking": 0.4,
      "drama_seeking": 0.1,
      "social_activity": 0.75
    },
    "voting_strategy": {
      "primary": "protect_allies",
      "queen_behavior": "protective_ruler",
      "hot_seat_risk": 0.2
    },
    "alliance_preferences": {
      "preferred_archetypes": ["sweetheart", "queen"],
      "max_alliances": 3,
      "betrayal_threshold": 0.1
    },
    "chat_behavior": {
      "message_frequency": "medium",
      "response_templates": [
        "I''ll always have your back",
        "We stick together no matter what",
        "I could never vote for {player}, they''re my friend",
        "Loyalty is everything to me"
      ]
    }
  }'::jsonb
);

-- AI Sweetheart #2: Sophie Chen - The Peacemaker
INSERT INTO public.cast_members (
  full_name, display_name, avatar_url, archetype,
  personality_traits, backstory, status, screen_time_score,
  is_ai_player, ai_personality_config
) VALUES (
  'Sophie Chen',
  'Sophie',
  'https://api.dicebear.com/7.x/avataaars/svg?seed=sophie',
  'sweetheart',
  ARRAY['diplomatic', 'kind', 'mediating', 'caring'],
  'Tries to keep peace and build bridges. Hates conflict but will fight for her friends.',
  'active',
  'low',
  true,
  '{
    "personality_id": "sweetheart_peacemaker_2",
    "traits": {
      "honesty": 0.9,
      "aggression": 0.15,
      "loyalty": 0.85,
      "strategic_thinking": 0.5,
      "drama_seeking": 0.05,
      "social_activity": 0.65
    },
    "voting_strategy": {
      "primary": "protect_allies",
      "queen_behavior": "protective_ruler",
      "hot_seat_risk": 0.15
    },
    "alliance_preferences": {
      "preferred_archetypes": ["sweetheart", "strategist"],
      "max_alliances": 2,
      "betrayal_threshold": 0.05
    },
    "chat_behavior": {
      "message_frequency": "low",
      "response_templates": [
        "Can we all just get along?",
        "I don''t want to vote for anyone",
        "Let''s think about this carefully",
        "Maybe we can find another way"
      ]
    }
  }'::jsonb
);

-- AI Sweetheart #3: Lily Anderson - The Optimist
INSERT INTO public.cast_members (
  full_name, display_name, avatar_url, archetype,
  personality_traits, backstory, status, screen_time_score,
  is_ai_player, ai_personality_config
) VALUES (
  'Lily Anderson',
  'Lily',
  'https://api.dicebear.com/7.x/avataaars/svg?seed=lily',
  'sweetheart',
  ARRAY['optimistic', 'cheerful', 'trusting', 'naive'],
  'Sees the best in everyone and believes in second chances. Sometimes too trusting.',
  'active',
  'low',
  true,
  '{
    "personality_id": "sweetheart_optimist_3",
    "traits": {
      "honesty": 0.92,
      "aggression": 0.1,
      "loyalty": 0.8,
      "strategic_thinking": 0.3,
      "drama_seeking": 0.05,
      "social_activity": 0.7
    },
    "voting_strategy": {
      "primary": "follow_crowd",
      "queen_behavior": "protective_ruler",
      "hot_seat_risk": 0.1
    },
    "alliance_preferences": {
      "preferred_archetypes": ["sweetheart", "comedian"],
      "max_alliances": 3,
      "betrayal_threshold": 0.15
    },
    "chat_behavior": {
      "message_frequency": "medium",
      "response_templates": [
        "I think everyone deserves a chance",
        "Maybe {player} isn''t so bad?",
        "Let''s give {player} another chance",
        "I believe in the good in people"
      ]
    }
  }'::jsonb
);

-- ============================================================================
-- STRATEGISTS (3 total)
-- Quiet, observant, long-game focused, analytical
-- ============================================================================

-- AI Strategist #1: Olivia Knight - The Analyst
INSERT INTO public.cast_members (
  full_name, display_name, avatar_url, archetype,
  personality_traits, backstory, status, screen_time_score,
  is_ai_player, ai_personality_config
) VALUES (
  'Olivia Knight',
  'Olivia',
  'https://api.dicebear.com/7.x/avataaars/svg?seed=olivia',
  'strategist',
  ARRAY['analytical', 'observant', 'intelligent', 'calculating'],
  'A data scientist who treats the game like a complex algorithm to solve.',
  'active',
  'medium',
  true,
  '{
    "personality_id": "strategist_analyst_1",
    "traits": {
      "honesty": 0.7,
      "aggression": 0.4,
      "loyalty": 0.6,
      "strategic_thinking": 0.95,
      "drama_seeking": 0.2,
      "social_activity": 0.5
    },
    "voting_strategy": {
      "primary": "eliminate_threats",
      "queen_behavior": "calculating_monarch",
      "hot_seat_risk": 0.7
    },
    "alliance_preferences": {
      "preferred_archetypes": ["strategist", "queen"],
      "max_alliances": 2,
      "betrayal_threshold": 0.4
    },
    "chat_behavior": {
      "message_frequency": "medium",
      "response_templates": [
        "Looking at the numbers, {player} is the logical choice",
        "Based on voting patterns, we should target {player}",
        "Statistically speaking, {player} is a threat",
        "I''ve been tracking the data"
      ]
    }
  }'::jsonb
);

-- AI Strategist #2: Isabella Romano - The Shadow Player
INSERT INTO public.cast_members (
  full_name, display_name, avatar_url, archetype,
  personality_traits, backstory, status, screen_time_score,
  is_ai_player, ai_personality_config
) VALUES (
  'Isabella Romano',
  'Isabella',
  'https://api.dicebear.com/7.x/avataaars/svg?seed=isabella',
  'strategist',
  ARRAY['subtle', 'patient', 'shrewd', 'cautious'],
  'Plays from the shadows, never drawing attention. Lets others take the heat.',
  'active',
  'low',
  true,
  '{
    "personality_id": "strategist_shadow_2",
    "traits": {
      "honesty": 0.6,
      "aggression": 0.3,
      "loyalty": 0.5,
      "strategic_thinking": 0.9,
      "drama_seeking": 0.15,
      "social_activity": 0.4
    },
    "voting_strategy": {
      "primary": "follow_crowd",
      "queen_behavior": "calculating_monarch",
      "hot_seat_risk": 0.8
    },
    "alliance_preferences": {
      "preferred_archetypes": ["strategist", "sweetheart"],
      "max_alliances": 1,
      "betrayal_threshold": 0.3
    },
    "chat_behavior": {
      "message_frequency": "low",
      "response_templates": [
        "I agree with the group",
        "Whatever you all think is best",
        "I''m just observing for now",
        "I''ll follow your lead"
      ]
    }
  }'::jsonb
);

-- AI Strategist #3: Aria Patel - The Long Game
INSERT INTO public.cast_members (
  full_name, display_name, avatar_url, archetype,
  personality_traits, backstory, status, screen_time_score,
  is_ai_player, ai_personality_config
) VALUES (
  'Aria Patel',
  'Aria',
  'https://api.dicebear.com/7.x/avataaars/svg?seed=aria',
  'strategist',
  ARRAY['patient', 'methodical', 'strategic', 'composed'],
  'Plays the long game, thinking weeks ahead. Never rushes a decision.',
  'active',
  'medium',
  true,
  '{
    "personality_id": "strategist_longGame_3",
    "traits": {
      "honesty": 0.65,
      "aggression": 0.35,
      "loyalty": 0.55,
      "strategic_thinking": 0.92,
      "drama_seeking": 0.25,
      "social_activity": 0.5
    },
    "voting_strategy": {
      "primary": "eliminate_threats",
      "queen_behavior": "calculating_monarch",
      "hot_seat_risk": 0.75
    },
    "alliance_preferences": {
      "preferred_archetypes": ["strategist", "queen"],
      "max_alliances": 2,
      "betrayal_threshold": 0.35
    },
    "chat_behavior": {
      "message_frequency": "medium",
      "response_templates": [
        "Let''s think long-term about {player}",
        "In three weeks, {player} will be a problem",
        "We need to position ourselves strategically",
        "Patience is key in this game"
      ]
    }
  }'::jsonb
);

-- ============================================================================
-- COMEDIANS (2 total)
-- Low drama, social, neutral, fun-focused
-- ============================================================================

-- AI Comedian #1: Ruby Davis - The Jokester
INSERT INTO public.cast_members (
  full_name, display_name, avatar_url, archetype,
  personality_traits, backstory, status, screen_time_score,
  is_ai_player, ai_personality_config
) VALUES (
  'Ruby Davis',
  'Ruby',
  'https://api.dicebear.com/7.x/avataaars/svg?seed=ruby',
  'comedian',
  ARRAY['funny', 'lighthearted', 'social', 'easygoing'],
  'A stand-up comedian who keeps things light. Just here for a good time.',
  'active',
  'medium',
  true,
  '{
    "personality_id": "comedian_jokester_1",
    "traits": {
      "honesty": 0.75,
      "aggression": 0.25,
      "loyalty": 0.6,
      "strategic_thinking": 0.4,
      "drama_seeking": 0.3,
      "social_activity": 0.85
    },
    "voting_strategy": {
      "primary": "follow_crowd",
      "queen_behavior": "unpredictable_ruler",
      "hot_seat_risk": 0.3
    },
    "alliance_preferences": {
      "preferred_archetypes": ["comedian", "sweetheart"],
      "max_alliances": 2,
      "betrayal_threshold": 0.4
    },
    "chat_behavior": {
      "message_frequency": "high",
      "response_templates": [
        "Lol this is wild",
        "I''m just here for the vibes",
        "Not me trying to be strategic 😂",
        "This is better than Netflix"
      ]
    }
  }'::jsonb
);

-- AI Comedian #2: Mia Thompson - The Social Butterfly
INSERT INTO public.cast_members (
  full_name, display_name, avatar_url, archetype,
  personality_traits, backstory, status, screen_time_score,
  is_ai_player, ai_personality_config
) VALUES (
  'Mia Thompson',
  'Mia',
  'https://api.dicebear.com/7.x/avataaars/svg?seed=mia',
  'comedian',
  ARRAY['friendly', 'outgoing', 'fun', 'neutral'],
  'Just wants to make friends and have fun. Avoids drama like the plague.',
  'active',
  'low',
  true,
  '{
    "personality_id": "comedian_socialButterfly_2",
    "traits": {
      "honesty": 0.8,
      "aggression": 0.15,
      "loyalty": 0.65,
      "strategic_thinking": 0.35,
      "drama_seeking": 0.1,
      "social_activity": 0.9
    },
    "voting_strategy": {
      "primary": "follow_crowd",
      "queen_behavior": "protective_ruler",
      "hot_seat_risk": 0.2
    },
    "alliance_preferences": {
      "preferred_archetypes": ["sweetheart", "comedian"],
      "max_alliances": 3,
      "betrayal_threshold": 0.3
    },
    "chat_behavior": {
      "message_frequency": "high",
      "response_templates": [
        "Hi friends!",
        "Can we all just be nice?",
        "I love everyone here tbh",
        "This is so much fun!"
      ]
    }
  }'::jsonb
);

-- ============================================================================
-- VERIFICATION QUERY
-- ============================================================================
DO $$
DECLARE
  ai_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO ai_count FROM public.cast_members WHERE is_ai_player = true;

  RAISE NOTICE '✅ AI Characters Seed Complete!';
  RAISE NOTICE 'Total AI Characters Created: %', ai_count;
  RAISE NOTICE 'Distribution:';
  RAISE NOTICE '  - Queens: 4 (Cassandra, Victoria, Dominique, Serena)';
  RAISE NOTICE '  - Villains: 4 (Madison, Raven, Scarlett, Natasha)';
  RAISE NOTICE '  - Wildcards: 4 (Zoe, Phoenix, Luna, Jade)';
  RAISE NOTICE '  - Sweethearts: 3 (Emma, Sophie, Lily)';
  RAISE NOTICE '  - Strategists: 3 (Olivia, Isabella, Aria)';
  RAISE NOTICE '  - Comedians: 2 (Ruby, Mia)';
END $$;
