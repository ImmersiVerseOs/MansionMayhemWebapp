# 📋 Mansion Mayhem - Page Audit

## Total Pages: 87

---

## ✅ ESSENTIAL PAGES (Keep)

### Authentication & Onboarding (7 pages)
1. `pages/sign-in.html` - Login page
2. `pages/reset-password.html` - Password reset
3. `pages/confirm-email.html` - Email verification
4. `pages/casting-call.html` - Character creation
5. `pages/facecast-consent.html` - FaceCast consent
6. `pages/facecast-onboarding.html` - FaceCast setup
7. `pages/personality-profile.html` - Character personality

### Core Game Flow (10 pages)
8. `pages/player-dashboard.html` - Main dashboard ⭐
9. `pages/browse-games.html` - Find/join games
10. `lobby.html` - Pre-game lobby ⭐
11. `pages/lobby.html` - (DUPLICATE - lobby in pages folder)
12. `pages/queen-selection.html` - Queen voting
13. `pages/elimination-vote.html` - Vote to eliminate
14. `pages/voting-new.html` - Voting interface
15. `pages/elimination-results.html` - Results page
16. `pages/results.html` - (DUPLICATE?)
17. `pages/ai-reveal.html` - AI player reveal

### Social Features (8 pages)
18. `link-up-requests.html` - Form alliances ⭐
19. `alliance-rooms.html` - Alliance chat rooms
20. `pages/alliance-chat.html` - (DUPLICATE?)
21. `pages/alliances.html` - (DUPLICATE?)
22. `pages/tea-room.html` - Drama/gossip feed ⭐
23. `pages/voice-feed.html` - Voice intro feed
24. `pages/record-voice.html` - Record intro
25. `pages/cast-roster.html` - View all players

### Scenarios (3 pages)
26. `pages/scenario-response.html` - Respond to scenarios
27. `pages/scenario-builder.html` - Admin scenario creation
28. `scenario-detail.html` - View scenario details

### Profile & Settings (3 pages)
29. `pages/player-profile.html` - User profile
30. `pages/settings.html` - User settings
31. `pages/leaderboard.html` - Rankings

---

## ⚠️ DUPLICATES (Delete/Merge)

### Dashboard Duplicates (3 pages - KEEP 1)
- `pages/player-dashboard.html` ✅ KEEP (new design)
- `pages/player-dashboard-NEW.html` ❌ DELETE (old version)
- `dashboard.html` ❌ DELETE (old root version)

### Lobby Duplicates (2 pages - KEEP 1)
- `lobby.html` (root) ✅ KEEP (working version)
- `pages/lobby.html` ❌ DELETE (duplicate)

### Alliance Duplicates (3 pages - KEEP 1)
- `link-up-requests.html` ✅ KEEP (modern version)
- `alliance-rooms.html` ✅ KEEP (chat rooms)
- `pages/alliance-chat.html` ❌ MERGE into alliance-rooms
- `pages/alliances.html` ❌ DELETE or MERGE

### Voting Duplicates (2 pages - KEEP 1)
- `pages/voting-new.html` ✅ KEEP
- `voting.html` ❌ DELETE (old version)

### Results Duplicates (2 pages - KEEP 1)
- `pages/elimination-results.html` ✅ KEEP
- `pages/results.html` ❌ MERGE or DELETE

### Voice Duplicates (4 pages - KEEP 2)
- `pages/voice-feed.html` ✅ KEEP (feed)
- `pages/record-voice.html` ✅ KEEP (recording)
- `voice-introduction.html` ❌ DELETE (duplicate)
- `voice-library.html` ❌ MERGE into voice-feed
- `listen-to-intros.html` ❌ MERGE into voice-feed

---

## 🗑️ UNUSED/LEGACY PAGES (Delete)

### Old Landing/Marketing (5 pages)
- `index.html` - Old landing (if not using)
- `landing.html` - Duplicate landing
- `intro.html` - Old intro page
- `join.html` - Old join page
- `how-to-play.html` - Old instructions

### Legacy Game Pages (8 pages)
- `game-detail.html` - Old game details
- `game-start.html` - Old game start
- `my-games-list.html` - Redundant (in dashboard)
- `browse-cast.html` - Old browse
- `cast-portal.html` - Unused
- `applications-admin.html` - Old admin
- `application.html` - Old application
- `application-complete.html` - Old completion

### Admin Pages (Consider Keeping) (5 pages)
- `pages/admin-dashboard.html` ✅ KEEP
- `pages/admin-analytics.html` ✅ KEEP
- `pages/admin-moderation.html` ✅ KEEP
- `director-console.html` ❌ DELETE (if unused)
- `episode-editor.html` ❌ DELETE (if unused)

### Test/Mockup Pages (6 pages) ❌ DELETE ALL
- `mockups/color-palette.html`
- `mockups/drama-feed-visual.html`
- `mockups/screen-showcase.html`
- `pages/test-features.html`
- `photo-upload.html` (if not used)
- `graph-visualization.html` (if not used)

### Voting Legacy (2 pages)
- `queen-elimination.html` ❌ DELETE (superseded by queen-selection)
- `scenario-preview.html` ❌ DELETE (if unused)

---

## 📄 STATIC/LEGAL PAGES (Keep)

### Marketing/Info (7 pages)
- `pages/about.html` ✅ KEEP
- `pages/how-to-play.html` ✅ KEEP
- `pages/faq.html` ✅ KEEP
- `pages/help-center.html` ✅ KEEP
- `pages/contact.html` ✅ KEEP
- `pages/careers.html` ✅ KEEP
- `pages/press.html` ✅ KEEP

### Legal Pages (6 pages)
- `pages/terms.html` ✅ KEEP
- `pages/privacy.html` ✅ KEEP
- `pages/cookie-policy.html` ✅ KEEP
- `pages/community-guidelines.html` ✅ KEEP
- `pages/consent.html` ✅ KEEP
- `pages/content-rights.html` ✅ KEEP

---

## 🤷 NEED MORE INFO

### Unclear Purpose (8 pages)
- `pages/gallery.html` - Gallery feature?
- `pages/the-drama-show.html` - Special feature?
- `pages/gameplay-mode.html` - Mode selection?
- `pages/generic-character-setup.html` - Alt character creation?
- `pages/facecast-marketplace.html` - FaceCast shop?
- `pages/voice-moderation-simple.html` - Admin tool?
- `help.html` - Root help page (duplicate?)
- `lobby-dashboard.html` - Another lobby variant?

---

## 📊 SUMMARY

**Total Pages:** 87

**Recommended Action:**
- ✅ **Keep:** ~35 pages (essential + legal)
- ❌ **Delete:** ~35 pages (duplicates + legacy)
- ⚠️ **Review:** ~17 pages (need clarification)

**After Cleanup: ~35-40 pages** (much cleaner!)

---

## 🎯 RECOMMENDED DELETIONS (Safe to Remove)

```bash
# Duplicates (12 pages)
pages/player-dashboard-NEW.html
dashboard.html
pages/lobby.html
pages/alliance-chat.html
pages/alliances.html
voting.html
pages/results.html
voice-introduction.html
voice-library.html
listen-to-intros.html
queen-elimination.html
scenario-preview.html

# Legacy/Unused (18 pages)
index.html (if not main landing)
landing.html
intro.html
join.html
how-to-play.html (root)
game-detail.html
game-start.html
my-games-list.html
browse-cast.html
cast-portal.html
applications-admin.html
application.html
application-complete.html
director-console.html
episode-editor.html
photo-upload.html
graph-visualization.html
leaderboard.html (root - duplicate of pages/leaderboard.html)

# Mockups (6 pages)
mockups/color-palette.html
mockups/drama-feed-visual.html
mockups/screen-showcase.html
pages/test-features.html

# TOTAL TO DELETE: ~36 pages
```

---

**Want me to create a deletion script?**
