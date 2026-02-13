# 🌐 Mansion Mayhem Web Platform

**Complete web application for casting, FaceCast creation, consent management, and director dashboard.**

---

## 🎯 What This Is

The **web platform** handles everything BEFORE users download the mobile app:

1. **Casting Call** - Users apply to be cast members
2. **Character Setup** - Create FaceCast OR Generic Character  
3. **Consent Management** - Legal consent for video generation
4. **Director Console** - Admin dashboard for game management
5. **Game Lobby** - View active games and status

---

## 📁 Project Structure

```
mansion-mayhem-web/
├── src/
│   ├── main.jsx                  ✅ React entry point
│   ├── App.jsx                   ✅ Router & routes
│   ├── lib/
│   │   └── supabase.js           ✅ Database client
│   ├── styles/
│   │   └── global.css            ✅ Global styles
│   ├── components/               → Shared components
│   └── pages/                    → Page components
│       ├── HomePage.jsx
│       ├── CastingCallPage.jsx
│       ├── FaceCastOnboardingPage.jsx
│       ├── GenericCharacterPage.jsx
│       ├── FaceCastConsentPage.jsx
│       ├── DirectorConsolePage.jsx
│       └── GameLobbyPage.jsx
│
├── netlify/functions/            → Serverless functions
├── WEB_PLATFORM_SPEC.md         ✅ Complete specification
├── index.html                    ✅ Entry HTML
├── package.json                  ✅ Dependencies
└── vite.config.js                ✅ Build config
```

---

## 🚀 Quick Start

### 1. Install Dependencies
```bash
npm install
```

### 2. Set Up Environment Variables
```bash
# Create .env file
cp .env.example .env

# Add your Supabase credentials
VITE_SUPABASE_URL=your_supabase_url
VITE_SUPABASE_ANON_KEY=your_anon_key
```

### 3. Run Development Server
```bash
npm run dev
# Opens on http://localhost:3000
```

### 4. Build for Production
```bash
npm run build
# Output in /dist
```

### 5. Deploy to Netlify
```bash
npm run deploy
```

---

## 📋 What's Included

### ✅ Core Infrastructure (DONE)
- React 18 with Vite
- React Router for navigation
- Supabase client configured
- Styled-components setup
- Global CSS variables
- Responsive design system

### 🚧 Pages to Build (7 total)

#### 1. **Home Page** (`/`)
Landing page with:
- Hero section
- How it works
- Featured shows
- Apply to cast CTA

#### 2. **Casting Call Page** (`/casting`)
Application form with:
- Personal information
- Why you want to join
- Archetype selection
- Photo/video upload
- Submit to database

#### 3. **FaceCast Onboarding** (`/facecast-onboarding`)
6-step wizard:
- Upload 5-10 photos
- Record 30-sec voice sample
- Set character details
- Review & submit
- Processing animation
- Success with FaceCast ID

#### 4. **Generic Character Setup** (`/generic-character`)
Quick 2-minute setup:
- Choose archetype
- Select appearance style
- Pick voice type
- Name character
- Grant consent
- Success

#### 5. **Consent Page** (`/consent`)
Legal consent form:
- Explanation of usage
- Example video
- Detailed permissions
- Usage restrictions
- Electronic signature
- IP tracking for legal compliance

#### 6. **Director Console** (`/director`)
Admin dashboard:
- Cast member management
- Game creation & control
- Scenario launcher
- Response monitoring
- Video generation queue
- Analytics

#### 7. **Game Lobby** (`/game/:gameId`)
Game status view:
- Cast list with setup status
- Current scenario
- Response tracking
- Video generation status

---

## 🎨 Design System

### Colors
```css
--color-gold: #D4AF37
--color-rose: #E91E63
--color-dark: #0A0A0A
--color-surface: #1A1A1A
```

### Typography
```css
--font-heading: 'Playfair Display'
--font-body: 'Montserrat'
--font-mono: 'Roboto Mono'
```

### Component Library
- Button (4 variants, 3 sizes)
- Card (elevated, flat)
- Input (text, email, file, etc.)
- Modal (dialog, drawer)
- Toast (success, error, info)
- Loader (spinner, skeleton)

---

## 🔌 Backend Integration

### Supabase Tables Used

#### `cast_members`
- Stores applicant information
- Tracks FaceCast/Generic character setup
- Consent status
- Onboarding progress

#### `content_permissions`
- Legal consent records
- IP tracking
- Electronic signatures
- Active/revoked status

#### `facecasts`
- FaceCast metadata
- Photo URLs
- Voice sample URLs
- Character details

#### `mm_games`
- Game instances
- Status tracking
- Cast assignments

#### `scenarios`
- Scenario prompts
- Launch times
- Deadlines
- Response tracking

### API Endpoints (Netlify Functions)

#### `send-approval-email.js`
Triggered when cast member approved
- Sends email with setup link
- Includes token for authentication

#### `verify-invite-code.js`
Validates mobile app invite codes
- Checks game status
- Returns cast member details

#### `generate-episode-scenes.js`
Triggered when game ends
- Aggregates gameplay data
- Generates AI scripts
- Queues Sora video generation

#### `process-auto-responses.js`
Runs every hour for Hybrid/Auto-Pilot users
- Checks for missed responses
- Applies personality-based AI decisions
- Submits auto-responses

---

## 🔄 Complete User Flow

```
Web Platform Flow:

1. USER visits /
   ↓
2. USER clicks "Apply to Cast"
   ↓
3. USER fills casting application at /casting
   ↓
4. SYSTEM saves to cast_members table
   ↓
5. ADMIN approves in /director console
   ↓
6. SYSTEM sends approval email with links
   ↓
7. USER clicks link → /facecast-onboarding OR /generic-character
   ↓
8. USER completes character setup
   ↓
9. USER redirected to /consent
   ↓
10. USER grants Sora permissions
    ↓
11. SYSTEM records consent in database
    ↓
12. USER shown success page with app download links
    ↓
13. USER downloads mobile app
    ↓
14. [Continues in mobile app...]
```

---

## 📱 Integration with Mobile App

### Handoff Points

**1. After Consent Granted:**
```
Web → Shows app download buttons
User → Downloads app from App Store/Google Play
App → Verifies consent exists in database
```

**2. Invite Code System:**
```
Director → Creates game, generates invite codes
Director → Sends codes to cast members
Cast → Opens app, enters code
App → Calls verify-invite-code function
App → Links to cast member account
```

**3. Deep Linking (Future):**
```
Email Link: mansionymayhem://setup?cast_id=xxx&token=yyy
```

---

## 🧪 Testing Checklist

### Page Tests
- [ ] Home page loads correctly
- [ ] Casting form validates input
- [ ] Photo upload works (max 10 photos, 5MB each)
- [ ] Voice recorder captures audio
- [ ] Consent form tracks IP address
- [ ] Director console shows cast members
- [ ] Game creation works

### Integration Tests
- [ ] Form submission saves to Supabase
- [ ] File uploads to Supabase Storage
- [ ] Email functions trigger correctly
- [ ] Mobile app can verify consent

### Responsiveness
- [ ] Mobile (375px)
- [ ] Tablet (768px)
- [ ] Desktop (1440px)

---

## 🚀 Deployment

### Netlify Setup

1. **Connect Repository**
```bash
git remote add origin your-repo-url
git push -u origin main
```

2. **Configure Netlify**
```
Build command: npm run build
Publish directory: dist
Functions directory: netlify/functions
```

3. **Environment Variables**
Add in Netlify dashboard:
- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_ANON_KEY`
- `OPENAI_API_KEY` (for functions)
- `ELEVENLABS_API_KEY` (for voice generation)

4. **Custom Domain** (Optional)
```
mansion-mayhem.immersiverseos.com
```

---

## 📊 Analytics

### Track Key Events
- Application submissions
- FaceCast creations
- Consent grants
- Game creations
- Scenario launches

### Metrics Dashboard
- Total applications
- Conversion rate (apply → consent)
- Average setup time
- Games per week
- Videos generated

---

## 🔒 Security

### Authentication
- Cast members: Token-based from email
- Directors: Password-based auth
- API functions: Supabase service role key

### Data Protection
- HTTPS only
- Row Level Security (RLS) on tables
- Signed URLs for file uploads
- IP address logging for consent

### GDPR Compliance
- Clear consent language
- Right to revoke
- Data export option
- Account deletion

---

## 📝 Next Steps

### Phase 1: Core Pages (Week 1)
1. Build HomePage
2. Build CastingCallPage
3. Build FaceCastOnboardingPage
4. Build GenericCharacterPage
5. Build FaceCastConsentPage

### Phase 2: Admin (Week 2)
1. Build DirectorConsolePage
2. Build GameLobbyPage
3. Add real-time updates

### Phase 3: Functions (Week 3)
1. Email functions
2. Auto-response processor
3. Scene generation trigger
4. Analytics collector

### Phase 4: Polish (Week 4)
1. Responsive design
2. Error handling
3. Loading states
4. Toast notifications
5. Testing
6. Deployment

---

## 🤝 Contributing

### Development Workflow
```bash
# Create feature branch
git checkout -b feature/casting-form

# Make changes
# ...

# Test locally
npm run dev

# Build
npm run build

# Commit
git add .
git commit -m "Add casting form"

# Push
git push origin feature/casting-form

# Create PR
```

---

## 📚 Documentation

- **WEB_PLATFORM_SPEC.md** - Complete technical specification
- **Component Library** - Coming soon
- **API Documentation** - Coming soon
- **Database Schema** - See Supabase docs

---

## 🎯 Success Criteria

✅ **User Can:**
- Apply to be cast member
- Create FaceCast character
- Grant video permissions
- Download mobile app

✅ **Director Can:**
- Approve cast members
- Create games
- Launch scenarios
- Monitor responses
- Trigger video generation

✅ **System Can:**
- Store all data in Supabase
- Send transactional emails
- Process auto-responses
- Generate video scenes
- Track analytics

---

## 🎉 You're Ready!

**Current Status:**
- ✅ Project structure set up
- ✅ React + Vite configured
- ✅ Supabase client ready
- ✅ Routing configured
- ✅ Design system defined
- ✅ Complete specification written

**Next Step:**
Build the 7 pages following WEB_PLATFORM_SPEC.md!

**Estimated Timeline:**
- Core pages: 1 week
- Admin dashboard: 1 week  
- Netlify functions: 1 week
- Testing & polish: 1 week

**Total: 4 weeks to production-ready web platform** 🚀

---

**Questions?** Check WEB_PLATFORM_SPEC.md for detailed implementation guides!
