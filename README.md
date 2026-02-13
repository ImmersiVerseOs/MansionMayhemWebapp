# Mansion Mayhem - Clean Build

**A fresh, clean database implementation of Mansion Mayhem with 21 essential tables.**

## 🎯 What's Different?

This is a **brand new, clean build** of Mansion Mayhem with:
- ✅ **21 essential tables** (~800 lines, 82% reduction from original)
- ✅ **Zero legacy bloat** - No competing SQL files
- ✅ **Consistent RLS policies** - Designed for edge functions from day 1
- ✅ **Single source of truth** - All schema in one place
- ✅ **NEW Supabase instance** - `fpxbhqibimekjhlumnmc.supabase.co`
- ✅ **Separate deployment** - Independent from ImmersiVerse OS

## 🏗️ Architecture

### Database Schema (21 Tables)
1. **cast_members** - AI characters & FaceCast integration
2. **profiles** - User profiles (minimal)
3. **mm_games** - Game instances
4. **mm_game_cast** - Cast members in games
5. **mm_game_stages** - Game progression
6. **scenarios** - Scenario prompts
7. **scenario_responses** - Player responses
8. **mm_link_up_requests** - Alliance invitations
9. **mm_link_up_responses** - Invitation responses
10. **mm_alliance_rooms** - Alliance chat rooms
11. **mm_alliance_messages** - Alliance messages
12. **mm_relationship_edges** - Relationship scores
13. **mm_graph_scores** - Graph analytics
14. **mm_voting_rounds** - Voting rounds
15. **mm_elimination_votes** - Individual votes
16. **mm_confession_cards** - Confessions
17. **mm_confession_reactions** - Reactions
18. **user_game_state** - Progress tracking
19. **notifications** - In-app notifications
20. **user_settings** - User preferences
21. **payment_transactions** - Payment history

### Edge Functions
- **ai-decision-processor** - Creates AI activity
- **generate-auto-response** - Auto-response generation
- **generate-scenario** - Scenario generation
- **send-invite-email** - Email invitations

## 🚀 Quick Start

### Prerequisites
- Node.js 18+
- Supabase CLI
- Git

### Setup

1. **Clone the repository**
```bash
git clone https://github.com/ImmersiVerseOs/MansionMayhemWebapp.git
cd MansionMayhemWebapp
```

2. **Install Supabase CLI** (if not already installed)
```bash
npm install -g supabase
```

3. **Link to Supabase project**
```bash
supabase link --project-ref fpxbhqibimekjhlumnmc
```

4. **Create .env.local**
```bash
cp .env.example .env.local
# Edit .env.local with your Supabase credentials
```

5. **Test locally (optional)**
```bash
# Start local Supabase
supabase start

# Apply migrations locally
supabase db reset

# Verify
supabase db diff
```

6. **Deploy to production**
```bash
# Push schema to Supabase
supabase db push

# Deploy edge functions
supabase functions deploy ai-decision-processor
supabase functions deploy generate-auto-response
supabase functions deploy generate-scenario
supabase functions deploy send-invite-email
```

## 📋 Migration Files

The database is built from these migrations (in order):
1. `001_CLEAN_SCHEMA.sql` - Core schema with 21 tables
2. `002_RLS_POLICIES.sql` - Row-level security policies
3. `003_SEED_AI_CHARACTERS.sql` - 20 AI character personalities
4. `004_SEED_DEMO_GAME.sql` - Initial active game

## 🎮 Game Mechanics

All game mechanics are preserved:
- ✅ Alliance system (duo/trio link-ups)
- ✅ Scenario system (prompts & responses)
- ✅ Voting system (elimination rounds)
- ✅ Relationship tracking (graph analytics)
- ✅ Confession cards
- ✅ AI personality system

## 🎭 FaceCast Integration

FaceCast integration is **fully preserved**:
- `cast_members.facecast_id` - Links to user submissions
- `cast_members.cameo_id` - Cameo integration
- All FaceCast UI pages maintained

## 🔐 Security

RLS policies designed with these principles:
- ✅ **Service role bypass** - Edge functions use service_role
- ✅ **Public read** - Guest viewing of cast members & games
- ✅ **Authenticated write** - Users can interact with game
- ✅ **Admin controls** - Admin-only for sensitive operations
- ✅ **No conflicts** - Consistent pattern across all tables

## 📁 Project Structure

```
MansionMayhemWebapp/
├── supabase/
│   ├── migrations/
│   │   ├── 001_CLEAN_SCHEMA.sql
│   │   ├── 002_RLS_POLICIES.sql
│   │   ├── 003_SEED_AI_CHARACTERS.sql
│   │   └── 004_SEED_DEMO_GAME.sql
│   ├── functions/
│   │   ├── ai-decision-processor/
│   │   ├── generate-auto-response/
│   │   ├── generate-scenario/
│   │   └── send-invite-email/
│   └── config.toml
├── web/
│   ├── alliance-chat.html
│   ├── alliance-rooms.html
│   ├── browse-cast.html
│   ├── dashboard.html
│   ├── voting.html
│   └── ... (all UI pages)
├── .env.example
├── .gitignore
└── README.md
```

## 🧪 Verification Checklist

After deployment, verify:
- [ ] All 21 tables exist
- [ ] RLS policies active on all tables
- [ ] 20 AI characters seeded
- [ ] Active game created with all AI characters
- [ ] Edge functions deployed and callable
- [ ] Landing page loads
- [ ] Auth flow works
- [ ] Lobby displays AI characters
- [ ] Scenarios load
- [ ] Alliance system works
- [ ] Voting system works

## 🆘 Troubleshooting

### Edge Functions Can't Query Database
- **Issue**: RLS policies blocking service_role
- **Fix**: All tables have `service_role_all` policy that bypasses RLS

### Missing AI Characters
- **Issue**: Seed script didn't run
- **Fix**: Run `003_SEED_AI_CHARACTERS.sql` manually in Supabase SQL Editor

### No Active Game
- **Issue**: Demo game seed didn't run
- **Fix**: Run `004_SEED_DEMO_GAME.sql` manually

## 🔗 Connection Info

- **New Supabase**: `fpxbhqibimekjhlumnmc.supabase.co`
- **GitHub Repo**: `github.com/ImmersiVerseOs/MansionMayhemWebapp`
- **Status**: Clean build, no legacy baggage

## 📝 Notes

This repository represents a **clean rebuild** of Mansion Mayhem:
- Started from scratch with new Supabase instance
- No migration from old database (old instance remains intact)
- Copied only essential components: schema, AI configs, UI, edge functions
- Dropped 16 legacy ImmersiVerse OS tables
- Eliminated 122 competing SQL files

## 🎯 What Was Left Behind

**Old Instance** (`mllqzeaxqusoryteaxzg.supabase.co`):
- 16 legacy ImmersiVerse tables
- 122 competing SQL files
- Conflicting RLS policies
- Test data and old alliances

**Kept & Improved**:
- 20 AI character configs
- All game mechanics
- All UI pages
- Edge function patterns (with fixes)
- FaceCast integration

---

Built with ❤️ by the ImmersiVerse OS team
