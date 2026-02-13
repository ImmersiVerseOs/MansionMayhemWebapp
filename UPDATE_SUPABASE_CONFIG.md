# ⚠️ URGENT: Update Supabase Configuration

## The 404 Error is Because...

The JavaScript files have the **OLD Supabase URL** hardcoded:
```
OLD: https://mllqzeaxqusoryteaxzg.supabase.co
NEW: https://fpxbhqibimekjhlumnmc.supabase.co
```

## 🔧 Quick Fix (2 minutes)

### Step 1: Get Your NEW Anon Key

1. Go to: https://supabase.com/dashboard/project/fpxbhqibimekjhlumnmc/settings/api
2. Copy the **anon public** key (long JWT starting with `eyJ...`)

### Step 2: Update Config File

Edit this file: `web/js/supabase-module.js`

**Change lines 9-10 from:**
```javascript
const SUPABASE_URL = 'https://mllqzeaxqusoryteaxzg.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...OLD_KEY...';
```

**To:**
```javascript
const SUPABASE_URL = 'https://fpxbhqibimekjhlumnmc.supabase.co';
const SUPABASE_ANON_KEY = 'YOUR_NEW_ANON_KEY_HERE';
```

### Step 3: Commit and Push

```bash
cd C:\Users\15868\MansionMayhemWebapp
git add web/js/supabase-module.js web/js/config.js web/_redirects web/netlify.toml
git commit -m "Fix: Update to new Supabase instance and add Netlify config"
git push origin main
```

### Step 4: Redeploy on Netlify

Netlify will automatically redeploy when you push to GitHub.

---

## 🚨 Or Use This Quick Command

If you give me your NEW anon key, I can update the file for you right now!

Just paste the anon key from:
https://supabase.com/dashboard/project/fpxbhqibimekjhlumnmc/settings/api

---

## ✅ After This Fix

- Landing page will load
- Database connection will work
- No more 404 errors
- Ready to deploy database with `supabase db push`
