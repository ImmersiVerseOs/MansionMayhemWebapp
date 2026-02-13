
# Real-Time Features Implementation Guide

## Overview

This guide explains how to implement real-time features in Mansion Mayhem using Supabase Realtime:

1. **Real-time voting updates** - Live vote counts that update automatically
2. **Live game status changes** - See game updates as they happen
3. **Notification system** - Push notifications for new scenarios and events
4. **Live chat** - Real-time chat for cast members within a game

---

## Setup Steps

### 1. Run Database Migration

First, create the necessary database tables by running the SQL migration:

```bash
# In Supabase SQL Editor, run:
backend/CREATE-REALTIME-TABLES.sql
```

This creates:
- `notifications` table with RLS policies
- `chat_messages` table with RLS policies
- `vote_counts` table for tracking votes
- Real-time triggers and functions
- Enables real-time replication on all necessary tables

---

### 2. Include JavaScript Modules

Add these script tags to your HTML pages **after** the Supabase client initialization:

```html
<!-- Supabase Client (must be loaded first) -->
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>

<!-- Initialize Supabase -->
<script>
  var supabase = window.supabase.createClient(
    'YOUR_SUPABASE_URL',
    'YOUR_SUPABASE_ANON_KEY'
  );
  window.supabase = supabase;
</script>

<!-- Real-time Modules -->
<script src="/mansion-mayhem/js/realtime.js"></script>
<script src="/mansion-mayhem/js/notifications-ui.js"></script>
<script src="/mansion-mayhem/js/chat-ui.js"></script>
<script src="/mansion-mayhem/js/voting-realtime.js"></script>
```

---

## Feature Implementation

### 1. Real-Time Voting Updates

**Use Case:** Live vote counts that update as users vote

```javascript
// Initialize real-time manager
const realtimeManager = new RealtimeManager(supabase);

// Initialize voting real-time
const votingRealtime = new VotingRealtime(
  supabase,
  realtimeManager,
  'game-id-here'
);

// When user submits a vote
async function handleVote(castMemberId) {
  // Your vote submission logic here
  const { error } = await supabase
    .from('cast_responses')
    .insert({
      scenario_id: scenarioId,
      cast_member_id: currentUserId,
      target_cast_member_id: castMemberId,
      // ... other fields
    });

  if (!error) {
    // Trigger vote count update (will broadcast to all subscribers)
    await votingRealtime.triggerVoteCountUpdate();
  }
}
```

**HTML Structure Required:**
```html
<div class="vote-card" data-cast-id="CAST_MEMBER_ID">
  <div class="card-name">Cast Member Name</div>
  <div class="card-votes">0 votes</div>
  <div class="card-percentage">0%</div>
  <div class="vote-progress">
    <div class="vote-progress-fill" style="width: 0%"></div>
  </div>
</div>
```

---

### 2. Live Game Status Changes

**Use Case:** See when games start, end, or change status

```javascript
const realtimeManager = new RealtimeManager(supabase);

// Subscribe to specific game updates
realtimeManager.subscribeToGameStatus('game-id', (updatedGame) => {
  console.log('Game updated:', updatedGame);

  // Update UI based on game status
  if (updatedGame.status === 'active') {
    showGameActive();
  } else if (updatedGame.status === 'ended') {
    showGameEnded();
  }
});

// Or subscribe to ALL games (for admin dashboard)
realtimeManager.subscribeToAllGames((payload) => {
  console.log('Game change:', payload);
  refreshGamesList();
});
```

---

### 3. Notification System

**Use Case:** Push notifications for new scenarios, votes, game updates

```javascript
const realtimeManager = new RealtimeManager(supabase);

// Initialize notification UI (creates bell icon + panel automatically)
const notificationUI = new NotificationUI(realtimeManager);

// That's it! The notification system is now active
// Notifications will appear automatically when:
// - New scenarios are assigned to cast members
// - Someone mentions you in chat
// - Game status changes
// - Vote results are in
```

**Manual Notification (Admin Only):**
```javascript
// Send custom notification (requires admin role)
const { data, error } = await supabase.rpc('send_notification', {
  p_user_id: 'user-uuid',
  p_cast_member_id: 'cast-member-uuid',
  p_type: 'system',
  p_title: 'Important Update!',
  p_message: 'The finale is starting soon!',
  p_link: '/mansion-mayhem/game-detail.html?id=game-123',
  p_metadata: { game_id: 'game-123' }
});
```

---

### 4. Live Chat for Cast Members

**Use Case:** Real-time communication between cast members in a game

```javascript
const realtimeManager = new RealtimeManager(supabase);

// Get current cast member info
const { data: castMember } = await supabase
  .from('cast_members')
  .select('id, display_name')
  .eq('user_id', user.id)
  .single();

// Initialize chat UI (creates floating chat widget automatically)
const chatUI = new ChatUI(
  realtimeManager,
  'game-id',
  castMember.id,
  castMember.display_name
);

// That's it! Chat is now live
// Features include:
// - Real-time messages
// - @mentions with notifications
// - Online presence (who's online)
// - Message editing and deletion
// - Unread badge
```

---

## Complete Page Example

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Mansion Mayhem - Live Features Demo</title>
  <link rel="stylesheet" href="styles.css">
</head>
<body>
  <!-- Your page content here -->
  <div class="header">
    <h1>Mansion Mayhem</h1>
    <!-- Notification bell will be added here automatically -->
  </div>

  <div class="voting-section">
    <!-- Vote cards will update in real-time -->
    <div class="vote-card" data-cast-id="cast-123">
      <div class="card-name">Zara</div>
      <div class="card-votes">0 votes</div>
      <div class="card-percentage">0%</div>
    </div>
  </div>

  <!-- Chat widget will appear in bottom-right corner automatically -->

  <!-- Scripts -->
  <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
  <script>
    // Initialize Supabase
    var supabase = window.supabase.createClient(
      'https://your-project.supabase.co',
      'your-anon-key'
    );
    window.supabase = supabase;
  </script>

  <!-- Load real-time modules -->
  <script src="/mansion-mayhem/js/realtime.js"></script>
  <script src="/mansion-mayhem/js/notifications-ui.js"></script>
  <script src="/mansion-mayhem/js/chat-ui.js"></script>
  <script src="/mansion-mayhem/js/voting-realtime.js"></script>

  <script>
    // Initialize everything
    async function initRealtime() {
      try {
        // Get current user
        const { data: { user } } = await supabase.auth.getUser();
        if (!user) {
          console.log('User not authenticated');
          return;
        }

        // Get current game ID (from URL or your logic)
        const gameId = 'your-game-id';

        // Initialize real-time manager
        const realtimeManager = new RealtimeManager(supabase);

        // Initialize notifications
        const notificationUI = new NotificationUI(realtimeManager);

        // Initialize voting real-time
        const votingRealtime = new VotingRealtime(
          supabase,
          realtimeManager,
          gameId
        );

        // Initialize chat (if cast member)
        const { data: castMember } = await supabase
          .from('cast_members')
          .select('id, display_name')
          .eq('user_id', user.id)
          .single();

        if (castMember) {
          const chatUI = new ChatUI(
            realtimeManager,
            gameId,
            castMember.id,
            castMember.display_name
          );
        }

        console.log('✅ All real-time features initialized!');

      } catch (error) {
        console.error('Error initializing real-time features:', error);
      }
    }

    // Initialize when page loads
    document.addEventListener('DOMContentLoaded', initRealtime);
  </script>
</body>
</html>
```

---

## CSS Variables

The real-time components use these CSS variables. Make sure they're defined:

```css
:root {
  --bg: #0a0a0a;
  --bg-card: #111;
  --bg-elevated: #1a1a1a;
  --border: #2a2a2a;
  --text: #fff;
  --text-dim: #888;
  --text-muted: #555;
  --gold: #d4af37;
  --rose: #e91e63;
  --purple: #9c27b0;
  --success: #4caf50;
  --warning: #ff9800;
}
```

---

## Browser Notifications

To enable browser notifications, the user needs to grant permission:

```javascript
// Request permission (automatically done by NotificationUI)
const granted = await realtimeManager.requestNotificationPermission();

if (granted) {
  console.log('✅ Browser notifications enabled');
} else {
  console.log('⚠️ Browser notifications denied');
}
```

---

## Cleanup

When leaving a page, clean up subscriptions:

```javascript
// Unsubscribe from specific channel
await realtimeManager.unsubscribe('votes:game-123');

// Or unsubscribe from everything
await realtimeManager.unsubscribeAll();
```

---

## Testing Real-Time Features

### Test Voting Updates:
1. Open voting page in two browser windows
2. Vote in one window
3. See vote counts update in both windows instantly

### Test Chat:
1. Sign in as two different cast members in separate browsers
2. Send messages
3. See them appear in real-time in both windows
4. Check online presence indicator

### Test Notifications:
1. Create a new scenario (admin)
2. Assigned cast members should see notification instantly
3. Check notification bell badge
4. Click to open notification panel

### Test Game Status:
1. Update a game's status (admin)
2. All users viewing that game should see the update instantly

---

## Troubleshooting

### Real-time not working:
1. Check Supabase project has real-time enabled (should be on by default)
2. Verify tables are added to `supabase_realtime` publication (done in migration SQL)
3. Check RLS policies allow SELECT access
4. Check browser console for connection errors

### Notifications not showing:
1. Verify notifications table exists
2. Check RLS policies on notifications table
3. Ensure user is authenticated
4. Check browser console for errors

### Chat not appearing:
1. Verify chat_messages table exists
2. Check RLS policies allow INSERT and SELECT
3. Ensure game_id and cast_member_id are valid
4. Check if user is part of the game

---

## Performance Considerations

- **Subscriptions**: Each subscription uses a WebSocket connection. Limit to what you need.
- **Presence**: Presence tracking can add overhead. Use only in chat/game pages.
- **Vote Updates**: Debounce rapid updates to avoid UI thrashing.
- **Message History**: Limit chat history to last 100 messages for performance.

---

## Security Notes

- **RLS Policies**: All real-time tables have RLS enabled
- **Admin Functions**: Send notification function requires admin role
- **Chat**: Cast members can only see chats for games they're in
- **Votes**: Vote counts are public, but individual votes are private

---

## Next Steps

1. Run the database migration
2. Add the JavaScript modules to your pages
3. Initialize real-time features in your page scripts
4. Test each feature
5. Customize UI to match your design

---

## Support

If you encounter issues:
1. Check browser console for errors
2. Verify database tables and RLS policies
3. Check Supabase real-time logs
4. Test with Supabase Studio's real-time inspector

---

🎉 **You're all set to add real-time features to Mansion Mayhem!**
