# Mansion Mayhem - AI Automation Implementation Complete 🎉

## What Was Implemented

### 1. ✅ Tea Room Posts System
- **Database**: Created `mm_tea_room_posts` table with voice note support
- **AI Generation**: Added personality-driven post generation with drama, shade, and confessionals
- **Voice Integration**: 20% of tea room posts include ElevenLabs voice notes
- **Cooldowns**: Smart posting frequency based on social_activity trait (30-120 min cooldowns)

### 2. ✅ Voice Note System (Enhanced)
- **ElevenLabs Integration**: Already existed, now enhanced for multiple content types
- **Scenario Responses**: 50% of AI scenario responses include voice notes
- **Tea Room Posts**: 20% of tea room posts include voice notes
- **Storage**: Uploads to Supabase Storage `voice-notes` bucket with public access

### 3. ✅ AI Voting System
- **Smart Voting**: AI votes based on personality traits (loyalty, chaos)
- **Alliance Protection**: AI strongly protects allied members in votes
- **Personality Modifiers**: Villains add chaos, strategists vote tactically
- **Vote Counting**: Automatic vote tallying and updating

### 4. ✅ Week Progression System
- **Week Calculation**: Automatic week tracking from game start date
- **Sunday Launches**: New scenarios activate every Sunday
- **Queen Selection**: Random lottery queen selection each week
- **Friday Voting**: Voting rounds start Friday evening

### 5. ✅ Queen Selection System
- **Weekly Selection**: Queen selected every Sunday via random lottery
- **No Repeats**: Tracks selections to avoid duplicates
- **Database Integration**: Stored in `mm_queen_selections` table

### 6. ✅ Double Elimination System
- **Queen's Power**: Queen directly eliminates 1 person (instant)
- **House Vote**: Queen nominates 2 others, house votes to eliminate 1 more
- **Drama Maximization**: 2 eliminations per week = faster pace + more strategy

---

## Files Created/Modified

### New Files:
1. **`supabase/migrations/015_TEA_ROOM_AND_VOTING_UPDATES.sql`**
   - Creates `mm_tea_room_posts` table
   - Adds RLS policies for tea room
   - Updates voting rounds for double elimination
   - Creates voice-notes storage bucket

2. **`supabase/functions/game-manager/index.ts`**
   - Week progression logic
   - Scenario activation on Sundays
   - Queen selection system
   - Voting round creation (double elimination)
   - Game completion detection

3. **`supabase/functions/game-manager/deno.json`**
   - Deno configuration for game-manager function

### Modified Files:
4. **`supabase/functions/ai-agent-processor/index.ts`**
   - Added `processTeaRoomPost()` function (line ~407)
   - Added 'tea_room_post' case to action router
   - Enhanced voice note generation for tea room posts (20% probability)
   - Enhanced scenario response voice notes (50% probability)

5. **`supabase/functions/ai-decision-processor/index.ts`**
   - Added `processAITeaRoomPosts()` function (line ~405)
   - Added `processAIVotes()` function (line ~485)
   - Added tea room posts to main handler
   - Added voting to main handler

---

## Deployment Steps

### Step 1: Run Database Migration

```bash
cd MansionMayhemWebapp

# Apply migration
supabase db push

# Or if using remote:
psql -h [your-db-host] -U postgres -d postgres -f supabase/migrations/015_TEA_ROOM_AND_VOTING_UPDATES.sql
```

### Step 2: Deploy Edge Functions

```bash
# Deploy ai-agent-processor (updated)
supabase functions deploy ai-agent-processor

# Deploy ai-decision-processor (updated)
supabase functions deploy ai-decision-processor

# Deploy game-manager (new)
supabase functions deploy game-manager
```

### Step 3: Set Up Cron Jobs

You have two options for scheduling:

#### Option A: Supabase pg_cron (Recommended)

Run this SQL in your Supabase SQL Editor:

```sql
-- Schedule game-manager to run 3x daily (midnight, noon, 6pm UTC)
SELECT cron.schedule(
  'game-manager-daily',
  '0 0,12,18 * * *',
  $$
  SELECT net.http_post(
    url := 'https://YOUR-PROJECT-REF.supabase.co/functions/v1/game-manager',
    headers := jsonb_build_object(
      'Authorization', 'Bearer YOUR-SERVICE-ROLE-KEY',
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
  $$
);

-- Verify cron job was created
SELECT * FROM cron.job WHERE jobname = 'game-manager-daily';
```

#### Option B: External Cron (Vercel Cron, GitHub Actions, etc.)

Set up an external service to call:
```
POST https://YOUR-PROJECT-REF.supabase.co/functions/v1/game-manager
Authorization: Bearer YOUR-SERVICE-ROLE-KEY
```

Schedule: `0 0,12,18 * * *` (3x daily: midnight, noon, 6pm)

### Step 4: Verify Storage Bucket

Ensure the `voice-notes` bucket exists with public access:

```sql
-- Check if bucket exists
SELECT * FROM storage.buckets WHERE id = 'voice-notes';

-- If not, it was created by the migration, but verify:
SELECT * FROM storage.objects WHERE bucket_id = 'voice-notes' LIMIT 1;
```

### Step 5: Environment Variables

Ensure these are set in Supabase Edge Function secrets:

```bash
supabase secrets list

# Should include:
# - ANTHROPIC_API_KEY
# - ELEVENLABS_API_KEY
# - SUPABASE_URL
# - SUPABASE_SERVICE_ROLE_KEY
```

If missing ELEVENLABS_API_KEY:
```bash
supabase secrets set ELEVENLABS_API_KEY=your-key-here
```

---

## Testing Guide

### Test 1: Tea Room Posts

**Manual Trigger:**
```bash
curl -X POST \
  'https://YOUR-PROJECT-REF.supabase.co/functions/v1/ai-decision-processor' \
  -H 'Authorization: Bearer YOUR-ANON-KEY' \
  -H 'Content-Type: application/json' \
  -d '{"gameId": "YOUR-GAME-ID", "decisionType": "tea_room_posts"}'
```

**Expected:**
- AI posts appear in `mm_tea_room_posts` table
- Posts have personality-driven content (drama, shade, etc.)
- Some posts (~20%) have `voice_note_url` populated

**Verification:**
```sql
-- Check recent tea room posts
SELECT
  cm.display_name,
  trp.post_text,
  trp.post_type,
  trp.voice_note_url IS NOT NULL as has_voice,
  trp.created_at
FROM mm_tea_room_posts trp
JOIN cast_members cm ON cm.id = trp.cast_member_id
ORDER BY trp.created_at DESC
LIMIT 10;
```

### Test 2: AI Voting

**Setup:**
```sql
-- Create a test voting round
INSERT INTO mm_voting_rounds (
  game_id,
  round_number,
  queen_id,
  nominee_a_id,
  nominee_b_id,
  status,
  voting_opens_at,
  voting_closes_at
) VALUES (
  'YOUR-GAME-ID',
  1,
  'QUEEN-CAST-MEMBER-ID',
  'NOMINEE-A-ID',
  'NOMINEE-B-ID',
  'active',
  NOW(),
  NOW() + INTERVAL '2 days'
);
```

**Manual Trigger:**
```bash
curl -X POST \
  'https://YOUR-PROJECT-REF.supabase.co/functions/v1/ai-decision-processor' \
  -H 'Authorization: Bearer YOUR-ANON-KEY' \
  -H 'Content-Type: application/json' \
  -d '{"gameId": "YOUR-GAME-ID", "decisionType": "votes"}'
```

**Expected:**
- AI cast votes in `mm_elimination_votes` table
- Vote counts updated in `mm_voting_rounds`
- AI protects allied members (votes to keep them)

**Verification:**
```sql
-- Check votes
SELECT
  cm.display_name as voter,
  voted_for.display_name as voted_for,
  vr.round_number
FROM mm_elimination_votes ev
JOIN cast_members cm ON cm.id = ev.cast_member_id
JOIN cast_members voted_for ON voted_for.id = ev.voted_for_id
JOIN mm_voting_rounds vr ON vr.id = ev.round_id
ORDER BY ev.created_at DESC;

-- Check vote counts
SELECT
  round_number,
  votes_for_a,
  votes_for_b,
  status
FROM mm_voting_rounds
ORDER BY round_number DESC;
```

### Test 3: Week Progression

**Manual Trigger:**
```bash
curl -X POST \
  'https://YOUR-PROJECT-REF.supabase.co/functions/v1/game-manager' \
  -H 'Authorization: Bearer YOUR-SERVICE-ROLE-KEY' \
  -H 'Content-Type: application/json'
```

**Expected:**
- If Sunday: Scenarios activated, queen selected
- If Friday evening: Voting round created
- Logs show current week calculation

**Verification:**
```sql
-- Check activated scenarios
SELECT
  title,
  status,
  deadline_at,
  distribution_date
FROM scenarios
WHERE game_id = 'YOUR-GAME-ID'
  AND status = 'active'
ORDER BY distribution_date DESC;

-- Check queen selections
SELECT
  week_number,
  cm.display_name as queen,
  selection_method,
  created_at
FROM mm_queen_selections qs
JOIN cast_members cm ON cm.id = qs.selected_queen_id
WHERE game_id = 'YOUR-GAME-ID'
ORDER BY week_number DESC;
```

### Test 4: Voice Notes

**Check ElevenLabs Integration:**
```sql
-- Check scenario responses with voice notes
SELECT
  cm.display_name,
  sr.response_text,
  sr.voice_note_url,
  s.title as scenario
FROM scenario_responses sr
JOIN cast_members cm ON cm.id = sr.cast_member_id
JOIN scenarios s ON s.id = sr.scenario_id
WHERE sr.voice_note_url IS NOT NULL
ORDER BY sr.created_at DESC
LIMIT 5;

-- Check tea room posts with voice notes
SELECT
  cm.display_name,
  trp.post_text,
  trp.voice_note_url,
  trp.voice_note_duration_seconds
FROM mm_tea_room_posts trp
JOIN cast_members cm ON cm.id = trp.cast_member_id
WHERE trp.voice_note_url IS NOT NULL
ORDER BY trp.created_at DESC
LIMIT 5;
```

**Manual Test:**
Visit a voice note URL to verify it plays:
```
https://YOUR-PROJECT-REF.supabase.co/storage/v1/object/public/voice-notes/ai-voice-1234567890.mp3
```

### Test 5: Full Game Flow

**Setup:**
```sql
-- Start a test game
UPDATE mm_games
SET
  status = 'active',
  started_at = NOW() - INTERVAL '1 day' -- 1 day ago
WHERE id = 'YOUR-GAME-ID';

-- Ensure you have 20+ AI cast members
SELECT COUNT(*) FROM mm_game_cast
WHERE game_id = 'YOUR-GAME-ID' AND status = 'active';
```

**Test Flow:**
1. Run game-manager → Should select queen
2. Run ai-decision-processor with tea_room_posts → Should generate drama
3. Run ai-decision-processor with chat_messages → Should send alliance messages
4. Manually create voting round → Run ai-decision-processor with votes → Should vote
5. Run game-manager on Sunday → Should close voting and eliminate

---

## Monitoring & Logs

### Check Function Logs

```bash
# View game-manager logs
supabase functions logs game-manager

# View ai-agent-processor logs
supabase functions logs ai-agent-processor

# View ai-decision-processor logs
supabase functions logs ai-decision-processor
```

### Monitor AI Activity

```sql
-- Check AI activity log
SELECT
  cm.display_name,
  aal.action_type,
  aal.ai_model,
  aal.input_tokens,
  aal.output_tokens,
  aal.estimated_cost_cents / 100.0 as cost_dollars,
  aal.response_preview,
  aal.created_at
FROM ai_activity_log aal
JOIN cast_members cm ON cm.id = aal.cast_member_id
ORDER BY aal.created_at DESC
LIMIT 20;

-- Daily AI cost summary
SELECT
  DATE(created_at) as date,
  COUNT(*) as actions,
  SUM(estimated_cost_cents) / 100.0 as total_cost_dollars,
  SUM(input_tokens) as total_input_tokens,
  SUM(output_tokens) as total_output_tokens
FROM ai_activity_log
GROUP BY DATE(created_at)
ORDER BY date DESC;
```

### Check Game State

```sql
-- Active games and their week
SELECT
  g.id,
  g.status,
  g.started_at,
  FLOOR((EXTRACT(EPOCH FROM (NOW() - g.started_at)) / 86400) / 7) + 1 as current_week,
  (SELECT COUNT(*) FROM mm_game_cast WHERE game_id = g.id AND status = 'active') as active_players
FROM mm_games g
WHERE g.status = 'active';
```

---

## Troubleshooting

### Issue: Tea room posts not generating

**Check:**
1. Are there AI cast members? `SELECT COUNT(*) FROM cast_members WHERE is_ai_player = true`
2. Is cooldown preventing posts? Check `mm_tea_room_posts.created_at` for each AI
3. Is ai-decision-processor running? Check function logs

**Fix:**
```sql
-- Manually queue tea room post action
INSERT INTO ai_action_queue (cast_member_id, action_type, game_id, status, priority)
VALUES ('AI-CAST-MEMBER-ID', 'tea_room_post', 'GAME-ID', 'pending', 50);
```

### Issue: Voice notes not generating

**Check:**
1. Is ELEVENLABS_API_KEY set? `supabase secrets list`
2. Is voice-notes bucket public? Check storage policies
3. Are there ElevenLabs API errors? Check ai-agent-processor logs

**Fix:**
```bash
# Set ElevenLabs API key
supabase secrets set ELEVENLABS_API_KEY=your-key-here

# Restart functions
supabase functions deploy ai-agent-processor
```

### Issue: Votes not being cast

**Check:**
1. Is voting round active? `SELECT * FROM mm_voting_rounds WHERE status = 'active'`
2. Are nominees set? Check `nominee_a_id` and `nominee_b_id`
3. Are AI members eligible to vote? (not nominated, not queen)

**Fix:**
```sql
-- Check eligible voters
SELECT cm.display_name, cm.id
FROM mm_game_cast gc
JOIN cast_members cm ON cm.id = gc.cast_member_id
WHERE gc.game_id = 'GAME-ID'
  AND gc.status = 'active'
  AND cm.is_ai_player = true
  AND cm.id NOT IN (
    SELECT nominee_a_id FROM mm_voting_rounds WHERE game_id = 'GAME-ID' AND status = 'active'
    UNION
    SELECT nominee_b_id FROM mm_voting_rounds WHERE game_id = 'GAME-ID' AND status = 'active'
  );
```

### Issue: Game-manager not progressing game

**Check:**
1. Is cron job running? `SELECT * FROM cron.job WHERE jobname = 'game-manager-daily'`
2. Is game status 'active'? `SELECT status FROM mm_games WHERE id = 'GAME-ID'`
3. Check function logs: `supabase functions logs game-manager`

**Fix:**
```bash
# Manually trigger game-manager
curl -X POST \
  'https://YOUR-PROJECT-REF.supabase.co/functions/v1/game-manager' \
  -H 'Authorization: Bearer YOUR-SERVICE-ROLE-KEY'
```

---

## Performance & Cost Optimization

### Voice Note Costs

- **ElevenLabs Free Tier**: 10,000 characters/month
- **Current Usage**:
  - Scenario responses: 50% with voice (~100 words = 500 chars)
  - Tea room posts: 20% with voice (~30 words = 150 chars)
- **Estimated Monthly**:
  - 100 scenario responses = 25,000 characters (needs paid plan)
  - 500 tea room posts = 15,000 characters
  - **Total: ~40,000 chars/month = $5-10/month**

**Optimization:**
- Reduce voice probability (currently 50% scenarios, 20% tea room)
- Use caching for common phrases
- Implement voice note quotas per AI

### Claude API Costs

- **Haiku**: $0.25/M input, $1.25/M output (chat, tea room)
- **Sonnet**: $3/M input, $15/M output (scenarios, decisions)

**Current Strategy:**
- Chat messages: Haiku (cheap, fast)
- Tea room posts: Haiku (quick social content)
- Scenario responses: Sonnet (quality matters)
- Strategic decisions: Sonnet (important choices)

**Estimated Monthly** (20 AI, active game):
- 10,000 Haiku calls = ~$5-10
- 1,000 Sonnet calls = ~$10-20
- **Total: $15-30/month**

### Optimization Tips

1. **Cooldown Tuning**: Increase cooldown times to reduce API calls
2. **Batch Processing**: Process multiple actions in single function call
3. **Caching**: Cache personality prompts and common responses
4. **Smart Triggers**: Only trigger AI decisions when needed (active games, voting open, etc.)

---

## Next Steps

### Optional Enhancements

1. **Voice Note Variety**:
   - Map more ElevenLabs voices to archetypes
   - Add voice settings per personality (speed, pitch)
   - Implement voice caching for repeated phrases

2. **Advanced Voting**:
   - Strategic AI voting (target threats)
   - Pre-vote alliance coordination
   - Vote manipulation by villains

3. **Tea Room Features**:
   - Reactions/likes on posts
   - Reply threads
   - Trending posts feed

4. **Game Analytics**:
   - Player engagement dashboard
   - AI behavior analytics
   - Cost tracking dashboard

5. **Performance Monitoring**:
   - Alerting for failed functions
   - Cost alerts for API usage
   - Automated testing suite

---

## Success Checklist

After deployment, verify:

- [ ] Migration applied successfully (mm_tea_room_posts table exists)
- [ ] All 3 Edge Functions deployed
- [ ] Cron job scheduled and running
- [ ] ELEVENLABS_API_KEY secret set
- [ ] voice-notes storage bucket exists and is public
- [ ] Tea room posts generating for AI players
- [ ] Voice notes uploading to storage
- [ ] AI voting working in active rounds
- [ ] Week progression advancing games
- [ ] Queen selection happening on Sundays
- [ ] Double elimination working (Queen's choice + House vote)

---

## Support & Feedback

If you encounter issues:
1. Check function logs: `supabase functions logs [function-name]`
2. Check database state with SQL queries above
3. Review MEMORY.md for common patterns
4. Test manually with curl commands

**Remember**: The system is designed to handle:
- 20+ AI players per game
- Real-time drama generation
- Weekly progression with double eliminations
- Voice note generation at scale
- Smart voting with personality traits

The full game is now playable end-to-end! 🎉
