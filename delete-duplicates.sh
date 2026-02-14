#!/bin/bash
# Delete duplicate and legacy pages

echo "🗑️  Deleting duplicate and legacy pages..."

# Duplicate Dashboards (keep pages/player-dashboard.html)
rm -f web/pages/player-dashboard-NEW.html
rm -f web/dashboard.html

# Duplicate Lobbies (keep root lobby.html)
rm -f web/pages/lobby.html

# Duplicate Alliances (keep link-up-requests.html and alliance-rooms.html)
rm -f web/pages/alliance-chat.html
rm -f web/pages/alliances.html

# Duplicate Voting (keep pages/voting-new.html)
rm -f web/voting.html

# Duplicate Results (keep pages/elimination-results.html)
rm -f web/pages/results.html

# Duplicate Voice Pages (keep pages/voice-feed.html and pages/record-voice.html)
rm -f web/voice-introduction.html
rm -f web/voice-library.html
rm -f web/listen-to-intros.html

# Duplicate Queen/Elimination (keep pages/queen-selection.html)
rm -f web/queen-elimination.html

# Duplicate Scenario (keep scenario-detail.html)
rm -f web/scenario-preview.html

# Duplicate Leaderboard (keep pages/leaderboard.html)
rm -f web/leaderboard.html

# Legacy Game Pages (superseded by new pages)
rm -f web/game-detail.html
rm -f web/game-start.html
rm -f web/my-games-list.html
rm -f web/browse-cast.html
rm -f web/cast-portal.html

# Legacy Application Pages
rm -f web/applications-admin.html
rm -f web/application.html
rm -f web/application-complete.html

# Legacy Admin/Director (keep admin-dashboard, admin-analytics, admin-moderation)
rm -f web/director-console.html
rm -f web/episode-editor.html

# Test/Mockup Pages
rm -f web/mockups/color-palette.html
rm -f web/mockups/drama-feed-visual.html
rm -f web/mockups/screen-showcase.html
rm -f web/pages/test-features.html

# Misc Unused
rm -f web/photo-upload.html
rm -f web/graph-visualization.html
rm -f web/lobby-dashboard.html

# Legacy Join (keep intro, landing, how-to-play flow)
rm -f web/join.html
rm -f web/index.html

echo "✅ Deletion complete!"
echo ""
echo "📊 Deleted pages:"
echo "   - Duplicate dashboards (2)"
echo "   - Duplicate lobbies (1)"
echo "   - Duplicate alliances (2)"
echo "   - Duplicate voice pages (3)"
echo "   - Duplicate voting/results (2)"
echo "   - Legacy game pages (5)"
echo "   - Legacy application pages (3)"
echo "   - Legacy admin/director (2)"
echo "   - Test/mockup pages (4)"
echo "   - Misc unused (5)"
echo ""
echo "   Total deleted: ~29 pages"
echo ""
echo "✅ Kept landing flow: intro.html → landing.html → how-to-play.html → sign-in.html"
echo "✅ Kept: the-drama-show.html"
echo "✅ Kept: All admin pages"
