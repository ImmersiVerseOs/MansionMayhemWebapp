# Mansion Mayhem - Deployment Guide

## 🎯 Current Status

✅ **Repository Created**: Local git initialized with clean build
✅ **Schema Ready**: 21 tables, RLS policies, AI seed data
✅ **Files Organized**: Web UI, edge functions, configs all in place
⏳ **Next Steps**: Push to GitHub and deploy to Supabase

---

## Step 1: Get Supabase Credentials

1. Go to your new Supabase project: https://supabase.com/dashboard/project/fpxbhqibimekjhlumnmc

2. Navigate to **Settings** → **API**

3. Copy these values:
   - **Project URL**: `https://fpxbhqibimekjhlumnmc.supabase.co`
   - **anon public key**: (long JWT token starting with `eyJ...`)

4. Create `.env.local` in the project root:
```bash
cd MansionMayhemWebapp
cp .env.example .env.local
```

5. Edit `.env.local` and add your credentials:
```env
VITE_SUPABASE_URL=https://fpxbhqibimekjhlumnmc.supabase.co
VITE_SUPABASE_ANON_KEY=<your_anon_key_here>
```

---

## Step 2: Push to GitHub

### Option A: New GitHub Repo (Recommended)

1. Create new repo on GitHub:
   - Go to https://github.com/new
   - Repository name: `MansionMayhemWebapp`
   - Owner: `ImmersiVerseOs`
   - **Keep it PRIVATE** for now
   - Don't initialize with README (we already have one)

2. Connect and push:
```bash
cd MansionMayhemWebapp
git remote add origin https://github.com/ImmersiVerseOs/MansionMayhemWebapp.git
git branch -M main
git push -u origin main
```

### Option B: Existing Repo

If the repo already exists on GitHub:
```bash
cd MansionMayhemWebapp
git remote add origin https://github.com/ImmersiVerseOs/MansionMayhemWebapp.git
git push -u origin main --force  # Force push to replace existing content
```

---

## Step 3: Deploy to Supabase

### 3.1 Install Supabase CLI (if needed)
```bash
npm install -g supabase
```

### 3.2 Login to Supabase
```bash
supabase login
```
This will open a browser for authentication.

### 3.3 Link to Your Project
```bash
cd MansionMayhemWebapp
supabase link --project-ref fpxbhqibimekjhlumnmc
```
When prompted, enter your database password.

### 3.4 Test Locally (Optional but Recommended)
```bash
# Start local Supabase
supabase start

# This will create a local instance and run migrations
# Check if tables are created correctly
supabase db diff

# Stop local instance when done testing
supabase stop
```

### 3.5 Deploy to Production
```bash
# Push database migrations to production
supabase db push

# You should see output like:
# ✓ Applying migration 001_CLEAN_SCHEMA.sql...
# ✓ Applying migration 002_RLS_POLICIES.sql...
# ✓ Applying migration 003_SEED_AI_CHARACTERS.sql...
# ✓ Applying migration 004_SEED_DEMO_GAME.sql...
```

### 3.6 Deploy Edge Functions

You'll need to set environment variables for edge functions:

```bash
# Set OpenAI API key for AI functions
supabase secrets set OPENAI_API_KEY=your_openai_key_here

# Deploy each function
supabase functions deploy ai-decision-processor
supabase functions deploy generate-auto-response
supabase functions deploy generate-scenario
supabase functions deploy send-invite-email
```

---

## Step 4: Verify Deployment

### 4.1 Check Database Tables

Go to Supabase Dashboard → **Table Editor**

You should see 21 tables:
- ✅ cast_members
- ✅ profiles
- ✅ mm_games
- ✅ mm_game_cast
- ✅ mm_game_stages
- ✅ scenarios
- ✅ scenario_responses
- ✅ mm_link_up_requests
- ✅ mm_link_up_responses
- ✅ mm_alliance_rooms
- ✅ mm_alliance_messages
- ✅ mm_relationship_edges
- ✅ mm_graph_scores
- ✅ mm_voting_rounds
- ✅ mm_elimination_votes
- ✅ mm_confession_cards
- ✅ mm_confession_reactions
- ✅ user_game_state
- ✅ notifications
- ✅ user_settings
- ✅ payment_transactions

### 4.2 Check AI Characters

Run this query in **SQL Editor**:
```sql
SELECT
  display_name,
  archetype,
  screen_time_score,
  is_ai_player
FROM cast_members
WHERE is_ai_player = true
ORDER BY archetype, display_name;
```

You should see 20 AI characters:
- 4 Queens (Cassandra, Victoria, Dominique, Serena)
- 4 Villains (Madison, Raven, Scarlett, Natasha)
- 4 Wildcards (Zoe, Phoenix, Luna, Jade)
- 3 Sweethearts (Emma, Sophie, Lily)
- 3 Strategists (Olivia, Isabella, Aria)
- 2 Comedians (Ruby, Mia)

### 4.3 Check Active Game

```sql
SELECT
  g.id,
  g.title,
  g.status,
  COUNT(gc.cast_member_id) as cast_count
FROM mm_games g
LEFT JOIN mm_game_cast gc ON gc.game_id = g.id
WHERE g.status = 'active'
GROUP BY g.id, g.title, g.status;
```

Should show 1 active game with 20 cast members.

### 4.4 Check RLS Policies

```sql
SELECT
  tablename,
  policyname,
  cmd,
  roles
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;
```

Every table should have at least a `service_role_all` policy.

---

## Step 5: Deploy Web UI

### Option A: Netlify (Recommended)

1. Go to https://app.netlify.com/

2. Click **Add new site** → **Import an existing project**

3. Connect to your GitHub repo: `ImmersiVerseOs/MansionMayhemWebapp`

4. Configure build settings:
   - **Base directory**: `web`
   - **Build command**: (leave empty - static HTML)
   - **Publish directory**: `web`

5. Add environment variables:
   - `VITE_SUPABASE_URL`: `https://fpxbhqibimekjhlumnmc.supabase.co`
   - `VITE_SUPABASE_ANON_KEY`: (your anon key)

6. Click **Deploy site**

7. Once deployed, get your Netlify URL (e.g., `mansion-mayhem-app.netlify.app`)

8. Update Supabase Auth settings:
   - Go to **Authentication** → **URL Configuration**
   - Add your Netlify URL to **Redirect URLs**

### Option B: Vercel

Similar process to Netlify:
1. Import GitHub repo
2. Set root directory to `web`
3. Add environment variables
4. Deploy

---

## Step 6: Setup Cron Jobs for AI Activity

### 6.1 Via Supabase Dashboard

Go to **Database** → **Extensions** → Enable **pg_cron**

Run these in SQL Editor:

```sql
-- Schedule AI link-up requests every 15 minutes
SELECT cron.schedule(
  'ai-link-up-requests',
  '*/15 * * * *',  -- Every 15 minutes
  $$
  SELECT net.http_post(
    url := 'https://fpxbhqibimekjhlumnmc.supabase.co/functions/v1/ai-decision-processor',
    headers := '{"Content-Type": "application/json", "Authorization": "Bearer ' || current_setting('app.settings.service_role_key') || '"}'::jsonb,
    body := '{"action": "create_link_up_request"}'::jsonb
  );
  $$
);

-- Schedule AI link-up responses every 10 minutes
SELECT cron.schedule(
  'ai-link-up-responses',
  '*/10 * * * *',  -- Every 10 minutes
  $$
  SELECT net.http_post(
    url := 'https://fpxbhqibimekjhlumnmc.supabase.co/functions/v1/ai-decision-processor',
    headers := '{"Content-Type": "application/json", "Authorization": "Bearer ' || current_setting('app.settings.service_role_key') || '"}'::jsonb,
    body := '{"action": "respond_to_link_up"}'::jsonb
  );
  $$
);

-- Schedule AI chat messages every 15 minutes
SELECT cron.schedule(
  'ai-chat-messages',
  '*/15 * * * *',  -- Every 15 minutes
  $$
  SELECT net.http_post(
    url := 'https://fpxbhqibimekjhlumnmc.supabase.co/functions/v1/ai-decision-processor',
    headers := '{"Content-Type": "application/json", "Authorization": "Bearer ' || current_setting('app.settings.service_role_key') || '"}'::jsonb,
    body := '{"action": "send_chat_message"}'::jsonb
  );
  $$
);
```

---

## Step 7: Final Testing

### Test Checklist

- [ ] **Landing page** (`/web/landing.html`) loads
- [ ] **Sign up** creates user in `profiles` table
- [ ] **Sign in** authenticates successfully
- [ ] **Lobby** (`/web/lobby.html`) displays 20 AI characters
- [ ] **FaceCast pages** load and explain integration
- [ ] **Browse Cast** (`/web/browse-cast.html`) shows AI personalities
- [ ] **Scenarios** can be created and responded to
- [ ] **Link-up requests** can be sent
- [ ] **Alliance chat** works in real-time
- [ ] **Voting page** displays correctly
- [ ] **Confession cards** can be submitted
- [ ] **AI edge functions** create activity (check logs)
- [ ] **Cron jobs** trigger successfully (check cron.job_run_details)

### Check Edge Function Logs

```sql
-- View cron job execution history
SELECT * FROM cron.job_run_details
ORDER BY start_time DESC
LIMIT 20;
```

Go to **Edge Functions** → Select function → **Logs** to see execution logs.

---

## Troubleshooting

### Issue: "relation does not exist"
**Solution**: Migrations didn't run. Re-run `supabase db push`

### Issue: Edge functions can't query database
**Solution**: Check RLS policies have `service_role_all` policy

### Issue: No AI characters in database
**Solution**: Run `003_SEED_AI_CHARACTERS.sql` manually in SQL Editor

### Issue: Web UI can't connect to Supabase
**Solution**: Check environment variables in Netlify/Vercel match your Supabase credentials

### Issue: Auth redirects not working
**Solution**: Add your Netlify URL to Supabase Auth → URL Configuration → Redirect URLs

---

## Next Steps After Deployment

1. **Test all game mechanics** with real user accounts
2. **Monitor edge function logs** for errors
3. **Set up analytics** to track user engagement
4. **Configure email templates** in Supabase Auth
5. **Add custom domain** to Netlify
6. **Set up CI/CD** for automatic deployments

---

## Success Criteria

✅ All 21 tables exist in Supabase
✅ 20 AI characters seeded with personality configs
✅ 1 active game with all AI characters
✅ RLS policies active on all tables
✅ Edge functions deployed and callable
✅ Web UI deployed and accessible
✅ Auth flow working (sign up, sign in, sign out)
✅ Cron jobs creating AI activity
✅ All UI pages load without errors

---

## Support

If you encounter issues:
1. Check Supabase logs: **Logs** → **Database** or **Edge Functions**
2. Review RLS policies: Ensure `service_role_all` exists on each table
3. Verify environment variables: Check Netlify/Vercel settings
4. Test edge functions manually: Use Supabase Dashboard → **Edge Functions** → **Invoke**

---

Built with ❤️ by the ImmersiVerse OS team
