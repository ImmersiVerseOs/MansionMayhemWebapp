# Deploy Edge Functions - Two Methods

## ✨ Method 1: Supabase Dashboard (Easiest - Recommended)

### Step 1: Go to Functions Page
https://supabase.com/dashboard/project/fpxbhqibimekjhlumnmc/functions

### Step 2: Deploy Each Function

**For each function, click "Deploy a new function":**

1. **ai-decision-processor**
   - Name: `ai-decision-processor`
   - Upload files from: `C:\Users\15868\MansionMayhemWebapp\supabase\functions\ai-decision-processor\`
   - Click Deploy

2. **generate-auto-response**
   - Name: `generate-auto-response`
   - Upload files from: `C:\Users\15868\MansionMayhemWebapp\supabase\functions\generate-auto-response\`
   - Click Deploy

3. **generate-scenario**
   - Name: `generate-scenario`
   - Upload files from: `C:\Users\15868\MansionMayhemWebapp\supabase\functions\generate-scenario\`
   - Click Deploy

4. **send-invite-email**
   - Name: `send-invite-email`
   - Upload files from: `C:\Users\15868\MansionMayhemWebapp\supabase\functions\send-invite-email\`
   - Click Deploy

### Step 3: Set Environment Variables (Optional)

If you want to use OpenAI for AI personalities:

Go to: **Settings** → **Edge Functions** → **Environment Variables**
Add: `OPENAI_API_KEY` = `your_openai_key_here`

---

## 🛠️ Method 2: Command Line (Advanced)

### Step 1: Get Access Token
1. Go to: https://supabase.com/dashboard/account/tokens
2. Click **"Generate new token"**
3. Name it: "Mansion Mayhem Deploy"
4. Copy the token

### Step 2: Set Token
```bash
set SUPABASE_ACCESS_TOKEN=your_token_here
```

### Step 3: Run Deploy Script
```bash
cd C:\Users\15868\MansionMayhemWebapp
deploy-functions.bat
```

---

## ✅ Verify Deployment

After deploying, check:
1. Go to: https://supabase.com/dashboard/project/fpxbhqibimekjhlumnmc/functions
2. You should see 4 functions listed
3. Click each one to see logs and test

---

## 🎯 What Each Function Does

**ai-decision-processor**
- Creates AI link-up requests
- Responds to link-up invitations
- Sends AI chat messages
- Makes AI characters feel alive

**generate-auto-response**
- Generates automatic responses for AI characters
- Uses personality configs

**generate-scenario**
- Creates new scenario prompts
- Keeps the game interesting

**send-invite-email**
- Sends email invitations to players
- Optional: configure SendGrid

---

## ⚠️ Note

Edge functions are **optional**. Your game works without them, but they make AI characters more interactive and autonomous.

If you don't deploy them:
- ✅ Players can still play
- ✅ 20 AI characters are in the game
- ✅ All game mechanics work
- ❌ AI won't create automatic activity (link-ups, messages)

You can always deploy them later!
