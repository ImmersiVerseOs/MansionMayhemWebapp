# 🚀 Mansion Mayhem - Quick Start

## 📍 Your New Repository Location

```
C:\Users\15868\MansionMayhemWebapp
```

Navigate there:
```bash
cd C:\Users\15868\MansionMayhemWebapp
```

---

## ✅ What's Complete

✅ **Clean schema created** - 21 tables, 800 lines (82% reduction)
✅ **RLS policies designed** - Service role bypass for edge functions
✅ **20 AI characters** - Complete personality configs
✅ **Demo game seeded** - Active game with all AI characters
✅ **Web UI copied** - All pages, CSS, JavaScript
✅ **Edge functions ready** - 4 functions ready to deploy
✅ **Git initialized** - Local repository with initial commit
✅ **Documentation complete** - README, deployment guide, build notes

---

## 🎯 Next Steps (In Order)

### 1️⃣ Get Supabase Credentials (5 minutes)

Go to: https://supabase.com/dashboard/project/fpxbhqibimekjhlumnmc

Navigate to: **Settings** → **API**

Copy:
- **Project URL**: `https://fpxbhqibimekjhlumnmc.supabase.co`
- **anon key**: (Long JWT starting with `eyJ...`)

Create `.env.local`:
```bash
cd C:\Users\15868\MansionMayhemWebapp
cp .env.example .env.local
# Edit .env.local and add your credentials
```

---

### 2️⃣ Push to GitHub (5 minutes)

Create repo at: https://github.com/new
- Name: `MansionMayhemWebapp`
- Owner: `ImmersiVerseOs`
- **Private** (for now)
- Don't initialize with README

Then push:
```bash
cd C:\Users\15868\MansionMayhemWebapp
git remote add origin https://github.com/ImmersiVerseOs/MansionMayhemWebapp.git
git branch -M main
git push -u origin main
```

---

### 3️⃣ Deploy to Supabase (10 minutes)

```bash
# Login to Supabase
supabase login

# Link to your project
cd C:\Users\15868\MansionMayhemWebapp
supabase link --project-ref fpxbhqibimekjhlumnmc

# Push database migrations
supabase db push

# Set environment variables for edge functions
supabase secrets set OPENAI_API_KEY=your_openai_key_here

# Deploy edge functions
supabase functions deploy ai-decision-processor
supabase functions deploy generate-auto-response
supabase functions deploy generate-scenario
supabase functions deploy send-invite-email
```

---

### 4️⃣ Deploy Web UI to Netlify (10 minutes)

1. Go to: https://app.netlify.com/
2. **Add new site** → **Import from Git**
3. Select: `ImmersiVerseOs/MansionMayhemWebapp`
4. Configure:
   - **Base directory**: `web`
   - **Build command**: (leave empty)
   - **Publish directory**: `web`
5. Add environment variables:
   - `VITE_SUPABASE_URL`: `https://fpxbhqibimekjhlumnmc.supabase.co`
   - `VITE_SUPABASE_ANON_KEY`: (your anon key)
6. **Deploy**

---

### 5️⃣ Configure Auth URLs (2 minutes)

After Netlify deployment:
1. Copy your Netlify URL (e.g., `mansion-mayhem-app.netlify.app`)
2. Go to Supabase: **Authentication** → **URL Configuration**
3. Add to **Redirect URLs**: `https://your-netlify-url.netlify.app/**`

---

### 6️⃣ Setup Cron Jobs (5 minutes)

In Supabase SQL Editor, run:

```sql
-- Enable pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- AI link-up requests every 15 minutes
SELECT cron.schedule(
  'ai-link-up-requests',
  '*/15 * * * *',
  $$
  SELECT net.http_post(
    url := 'https://fpxbhqibimekjhlumnmc.supabase.co/functions/v1/ai-decision-processor',
    headers := '{"Content-Type": "application/json", "Authorization": "Bearer ' || current_setting('app.settings.service_role_key') || '"}'::jsonb,
    body := '{"action": "create_link_up_request"}'::jsonb
  );
  $$
);
```

---

### 7️⃣ Verify Deployment (10 minutes)

Run in Supabase SQL Editor:

```sql
-- Check tables exist (should show 21)
SELECT COUNT(*) FROM information_schema.tables
WHERE table_schema = 'public';

-- Check AI characters (should show 20)
SELECT COUNT(*) FROM cast_members WHERE is_ai_player = true;

-- Check active game (should show 1 game with 20 cast members)
SELECT g.id, COUNT(gc.cast_member_id) as cast_count
FROM mm_games g
LEFT JOIN mm_game_cast gc ON gc.game_id = g.id
WHERE g.status = 'active'
GROUP BY g.id;
```

Test UI:
- [ ] Visit your Netlify URL
- [ ] Landing page loads
- [ ] Sign up works
- [ ] Lobby displays 20 AI characters

---

## 📖 Documentation

- **README.md** - Project overview and architecture
- **BUILD_COMPLETE.md** - Detailed build summary (THIS IS THE MOST IMPORTANT)
- **DEPLOYMENT_GUIDE.md** - Step-by-step deployment instructions
- **QUICK_START.md** - This file (quick reference)

---

## 🎯 Expected Results

After completing all steps:
- ✅ 21 tables in Supabase
- ✅ 20 AI characters seeded
- ✅ 1 active game with all AI characters
- ✅ RLS policies active
- ✅ Edge functions deployed
- ✅ Web UI live on Netlify
- ✅ Auth working
- ✅ Cron jobs creating AI activity

---

## 🆘 Troubleshooting

**Issue**: Migrations fail
→ Check `001_CLEAN_SCHEMA.sql` for syntax errors

**Issue**: Edge functions can't query database
→ Verify RLS policies include `service_role_all`

**Issue**: No AI characters in database
→ Run `003_SEED_AI_CHARACTERS.sql` manually

**Issue**: Web UI can't connect
→ Check environment variables in Netlify

See **DEPLOYMENT_GUIDE.md** for detailed troubleshooting.

---

## 📊 What You've Gained

| Metric | Before | After |
|--------|--------|-------|
| SQL Files | 122 | 4 |
| Schema Lines | 4,500 | 800 |
| Tables | 37 | 21 |
| RLS Conflicts | Many | 0 |
| Tech Debt | High | Zero |

---

## 🎉 You're Ready!

Total estimated time: **45 minutes** (if everything goes smoothly)

Start with Step 1: Get Supabase credentials

Good luck! 🚀
