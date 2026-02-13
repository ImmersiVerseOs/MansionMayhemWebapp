# 🚀 MANSION MAYHEM - DEPLOYMENT GUIDE

## Complete Backend & Frontend Setup Instructions

---

## 📋 TABLE OF CONTENTS

1. [Prerequisites](#prerequisites)
2. [Supabase Setup](#supabase-setup)
3. [Database Schema](#database-schema)
4. [Storage Buckets](#storage-buckets)
5. [Authentication](#authentication)
6. [Frontend Integration](#frontend-integration)
7. [Environment Variables](#environment-variables)
8. [Testing](#testing)
9. [Production Deployment](#production-deployment)
10. [Troubleshooting](#troubleshooting)

---

## 1. PREREQUISITES

### Required Accounts
- [ ] Supabase account (https://supabase.com)
- [ ] Stripe account for payments (https://stripe.com)
- [ ] OpenAI API key for AI features (https://platform.openai.com)
- [ ] Domain name (optional, for production)

### Required Tools
- [ ] Node.js 18+ installed
- [ ] Git installed
- [ ] Code editor (VS Code recommended)

---

## 2. SUPABASE SETUP

### Step 1: Create Project
1. Go to https://app.supabase.com
2. Click "New Project"
3. Fill in:
   - Project name: `mansion-mayhem`
   - Database password: **Save this securely!**
   - Region: Choose closest to your users
4. Wait 2-3 minutes for project creation

### Step 2: Get Credentials
1. Go to Project Settings → API
2. Copy these values:
   ```
   Project URL: https://xxxxx.supabase.co
   anon/public key: eyJhbGc...
   service_role key: eyJhbGc... (keep secret!)
   ```

---

## 3. DATABASE SCHEMA

### Step 1: Run Schema SQL
1. In Supabase dashboard, go to **SQL Editor**
2. Click "New Query"
3. Copy entire contents of `supabase-schema.sql`
4. Paste and click "Run"
5. Wait for completion (should see "Success" message)

### Step 2: Run Functions SQL
1. Still in SQL Editor, click "New Query"
2. Copy entire contents of `supabase-functions.sql`
3. Paste and click "Run"
4. Verify no errors

### Step 3: Verify Tables
1. Go to **Table Editor**
2. You should see these tables:
   - profiles
   - characters
   - facecast_consents
   - episodes
   - scenarios
   - scenario_responses
   - voice_notes
   - voice_note_reactions
   - earnings
   - payouts
   - content_reports
   - analytics_events
   - daily_stats

---

## 4. STORAGE BUCKETS

### Create Buckets
Go to **Storage** and create these buckets:

1. **facecast-photos** (Private)
   - For: User FaceCast photo uploads
   - File size limit: 10MB
   - Allowed MIME types: `image/jpeg, image/png, image/webp`

2. **voice-notes** (Private)
   - For: Voice note audio files
   - File size limit: 25MB
   - Allowed MIME types: `audio/webm, audio/mp3, audio/wav`

3. **episode-videos** (Public)
   - For: Published episode videos
   - File size limit: 500MB
   - Allowed MIME types: `video/mp4, video/webm`

4. **episode-thumbnails** (Public)
   - For: Episode thumbnail images
   - File size limit: 5MB
   - Allowed MIME types: `image/jpeg, image/png, image/webp`

5. **user-avatars** (Public)
   - For: User profile avatars
   - File size limit: 2MB
   - Allowed MIME types: `image/jpeg, image/png, image/webp`

### Set Bucket Policies
For each **private** bucket (facecast-photos, voice-notes):
```sql
-- Allow authenticated users to upload their own files
CREATE POLICY "Users can upload own files"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'facecast-photos' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow users to read their own files
CREATE POLICY "Users can read own files"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'facecast-photos' AND
  (storage.foldername(name))[1] = auth.uid()::text
);
```

For **public** buckets (episode-videos, episode-thumbnails, user-avatars):
```sql
-- Allow public read access
CREATE POLICY "Public read access"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'episode-videos');
```

---

## 5. AUTHENTICATION

### Step 1: Email/Password Setup
1. Go to **Authentication** → **Providers**
2. Enable **Email** provider
3. Configure:
   - ✅ Enable email confirmations
   - ✅ Enable email change confirmations
   - Confirmation URL: `https://yourdomain.com/confirm-email`

### Step 2: Social Logins (Optional)
**Google OAuth:**
1. Go to Google Cloud Console
2. Create OAuth 2.0 credentials
3. Add redirect URI: `https://xxxxx.supabase.co/auth/v1/callback`
4. Copy Client ID and Secret to Supabase

**Facebook OAuth:**
1. Go to Facebook Developers
2. Create app and get App ID/Secret
3. Add redirect URI
4. Copy credentials to Supabase

### Step 3: Email Templates
Go to **Authentication** → **Email Templates** and customize:

**Confirm Signup:**
```html
<h2>Welcome to Mansion Mayhem!</h2>
<p>Click the link below to confirm your email:</p>
<p><a href="{{ .ConfirmationURL }}">Confirm Email</a></p>
```

**Reset Password:**
```html
<h2>Reset Your Password</h2>
<p>Click the link below to reset your password:</p>
<p><a href="{{ .ConfirmationURL }}">Reset Password</a></p>
```

---

## 6. FRONTEND INTEGRATION

### Step 1: Install Dependencies
```bash
npm install @supabase/supabase-js
```

### Step 2: Create Supabase Client
Create `/js/supabase-client.js`:
```javascript
import { createClient } from '@supabase/supabase-js'

const SUPABASE_URL = 'YOUR_PROJECT_URL'
const SUPABASE_ANON_KEY = 'YOUR_ANON_KEY'

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY)
```

### Step 3: Add to HTML Pages
In each HTML page's `<head>`:
```html
<script type="module" src="/js/supabase-client.js"></script>
<script type="module" src="/js/auth.js"></script>
```

### Step 4: Implement Authentication
Copy code from `frontend-integration.js` to handle:
- Sign up / Sign in
- Auth state management
- Protected routes

### Step 5: Connect Forms
Update each page's form handlers to use Supabase functions:
- `sign-in-premium.html` → `signInWithEmail()`
- `casting-call-premium.html` → `completeCharacterSetup()`
- `record-voice-premium.html` → `createVoiceNote()`
- `dashboard-premium.html` → `getCharacterDashboard()`

---

## 7. ENVIRONMENT VARIABLES

### Development (.env.local)
```bash
NEXT_PUBLIC_SUPABASE_URL=https://xxxxx.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGc...
SUPABASE_SERVICE_ROLE_KEY=eyJhbGc...

STRIPE_PUBLIC_KEY=pk_test_...
STRIPE_SECRET_KEY=sk_test_...

OPENAI_API_KEY=sk-...
SORA_API_KEY=...

NEXT_PUBLIC_APP_URL=http://localhost:3000
```

### Production (.env.production)
```bash
NEXT_PUBLIC_SUPABASE_URL=https://xxxxx.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGc...
SUPABASE_SERVICE_ROLE_KEY=eyJhbGc...

STRIPE_PUBLIC_KEY=pk_live_...
STRIPE_SECRET_KEY=sk_live_...

OPENAI_API_KEY=sk-...
SORA_API_KEY=...

NEXT_PUBLIC_APP_URL=https://mansionmayhem.com
```

---

## 8. TESTING

### Test Authentication
1. Go to sign-in page
2. Create test account
3. Check Supabase **Authentication** → **Users**
4. Verify profile created in `profiles` table

### Test Character Setup
1. Complete onboarding flow
2. Upload FaceCast photos
3. Set personality traits
4. Check `characters` table for new entry

### Test Voice Notes
1. Record voice note
2. Check `voice_notes` table
3. Verify audio file in storage bucket
4. Check appears in feed

### Test Payments (Stripe Test Mode)
1. Use test card: 4242 4242 4242 4242
2. Create tip or subscription
3. Check `tips` table
4. Verify webhook received

---

## 9. PRODUCTION DEPLOYMENT

### Option A: Netlify (Recommended)
```bash
# Install Netlify CLI
npm install -g netlify-cli

# Deploy
netlify deploy --prod

# Set environment variables in Netlify dashboard
```

### Option B: Vercel
```bash
# Install Vercel CLI
npm install -g vercel

# Deploy
vercel --prod

# Set environment variables in Vercel dashboard
```

### Option C: Custom Server
1. Build static site
2. Upload to web server
3. Configure HTTPS (Let's Encrypt)
4. Set environment variables on server

### Post-Deployment Checklist
- [ ] Test all authentication flows
- [ ] Verify file uploads work
- [ ] Check RLS policies are active
- [ ] Test payment processing
- [ ] Monitor error logs
- [ ] Set up uptime monitoring

---

## 10. TROUBLESHOOTING

### Common Issues

**Authentication not working:**
```
Error: Invalid JWT
Solution: Check SUPABASE_ANON_KEY is correct
```

**RLS policy blocking access:**
```
Error: permission denied for table X
Solution: Verify RLS policies in SQL Editor
Check user is authenticated: await supabase.auth.getUser()
```

**File upload fails:**
```
Error: new row violates row-level security policy
Solution: Check storage bucket policies
Verify bucket name matches code
```

**Database connection issues:**
```
Error: connection timeout
Solution: Check Supabase project is active
Verify SUPABASE_URL is correct
Check network/firewall settings
```

### Debug Mode
Add to console to see Supabase logs:
```javascript
localStorage.setItem('supabase.auth.debug', 'true')
```

### Support Contacts
- Supabase: https://supabase.com/docs
- Discord: https://discord.supabase.com
- GitHub Issues: Create issue in your repo

---

## 📊 SUCCESS CHECKLIST

Backend Setup:
- [ ] Supabase project created
- [ ] Database schema deployed
- [ ] Storage buckets configured
- [ ] RLS policies active
- [ ] Authentication enabled

Frontend Integration:
- [ ] Supabase client installed
- [ ] Environment variables set
- [ ] Forms connected to API
- [ ] File uploads working
- [ ] Real-time subscriptions active

Testing:
- [ ] User signup/signin works
- [ ] Character creation works
- [ ] Voice notes upload
- [ ] Dashboard displays data
- [ ] Admin panel accessible

Production:
- [ ] Site deployed
- [ ] Custom domain configured
- [ ] HTTPS enabled
- [ ] Analytics tracking active
- [ ] Error monitoring setup

---

## 🎉 LAUNCH READY!

Your Mansion Mayhem platform is now fully configured and ready to launch!

**Next Steps:**
1. Create test users and content
2. Invite beta testers
3. Monitor analytics
4. Iterate based on feedback
5. Scale infrastructure as needed

**Good luck with your launch!** 🚀🏰

---

## 📞 NEED HELP?

- Technical issues: Check Supabase docs
- Feature requests: Open GitHub issue
- Security concerns: Email security@immersiverseos.com

---

Built with ❤️ for ImmersiVerse OS
