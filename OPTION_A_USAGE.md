# 🎮 Option A: Synchronized Launch - Usage Guide

## ✅ System Installed

Your Mansion Mayhem system now runs on **synchronized Sunday launches**:
- 📅 All games launch **Sundays at 8 PM ET**
- 🕐 Week-long lobbies (close Sunday 7 PM ET)
- 👑 Queen selection (Sunday 8 PM ET)
- 📝 First scenarios (Monday 9 AM ET)
- ⚡ Eliminations (Sunday 7:30 PM ET)

---

## 🚀 How to Create a New Game

### Option 1: Auto-Initialize (Recommended)

After creating a game in your admin panel, run this in Supabase SQL Editor:

```sql
SELECT initialize_week_long_lobby('your-game-id-here');
```

**Returns:**
```json
{
  "game_id": "...",
  "lobby_opens": "2026-02-14 10:00:00",
  "lobby_closes": "2026-02-16 19:00:00",  // Sunday 7 PM ET
  "queen_selection": "2026-02-16 20:00:00", // Sunday 8 PM ET
  "first_scenarios": "2026-02-17 09:00:00", // Monday 9 AM ET
  "days_until_launch": 2.375
}
```

### Option 2: Manual Game Creation

```sql
INSERT INTO mm_games (title, description, status, max_players)
VALUES ('Spring Drama Session', 'Week of Feb 16', 'waiting_lobby', 20)
RETURNING id;

-- Use the returned ID:
SELECT initialize_week_long_lobby('<returned-id>');
```

---

## 📅 Weekly Timeline Example

```
Monday Feb 10, 10 AM - Game created
├─ Lobby opens immediately
├─ Players join all week
└─ Alliance building, voice notes, chat

Sunday Feb 16, 7 PM ET - Lobby closes
├─ Roster locked (15 players joined)
└─ Can still chat but no new joins

Sunday Feb 16, 8 PM ET - GAME LAUNCHES! 👑
├─ Queen selected (random lottery)
└─ Notifications sent to all players

Monday Feb 17, 9 AM ET - First scenarios
├─ All 15 players get 2-3 scenarios
└─ 24-hour deadline

Week 1 (Feb 17-23)
├─ Daily scenarios
├─ Alliance drama
└─ NO eliminations (everyone safe Week 1)

Sunday Feb 23, 7:30 PM ET - First elimination ⚡
└─ Player with most votes eliminated

Sunday Feb 23, 8 PM ET - Second queen 👑
└─ Week 2 begins
```

---

## 🔧 Verify System is Running

Run this to check all cron jobs:

```sql
SELECT
  jobid,
  jobname,
  schedule,
  active,
  CASE jobname
    WHEN 'weekly_elimination' THEN 'Sunday 7:30 PM ET'
    WHEN 'weekly_queen_selection' THEN 'Sunday 8 PM ET (LAUNCH)'
    WHEN 'distribute_daily_scenarios' THEN 'Monday 9 AM ET'
    WHEN 'ai_agent_processor' THEN 'Every 3 minutes'
    WHEN 'check_lobby_timers' THEN 'Every minute'
  END as eastern_time
FROM cron.job
ORDER BY jobname;
```

**Expected:** 5 active jobs ✅

---

## 🎯 What Happens Automatically

### Every Minute
- `check_lobby_timers` checks if any lobbies should close
- Transitions games from `waiting_lobby` → `active_lobby`
- Sends notifications to players

### Every 3 Minutes
- `ai_agent_processor` generates AI character responses
- Processes voice notes, tea room posts, scenarios

### Monday 9 AM ET (2 PM UTC)
- `distribute_daily_scenarios` assigns 2-3 scenarios per player
- 24-hour deadline for each

### Sunday 7:30 PM ET (Monday 12:30 AM UTC)
- `weekly_elimination` tallies votes and eliminates player
- Week number increments

### Sunday 8 PM ET (Monday 1 AM UTC)
- `weekly_queen_selection` picks new queen (random lottery)
- 48-hour nomination window begins

---

## 💡 Pro Tips

1. **Create games early in the week** - Gives players more time to join
2. **Saturday games** - Only 1 day lobby, good for quick sessions
3. **Mid-week games** - Get full 6-day lobby for maximum hype
4. **AI characters** - Will join lobby automatically like real players
5. **Week 1 safe** - No eliminations in first week (builds alliances)

---

## 🐛 Troubleshooting

### Lobby not closing?
```sql
-- Check cron job
SELECT * FROM cron.job WHERE jobname = 'check_lobby_timers';
-- Should run every minute

-- Manually trigger
SELECT check_and_launch_sunday_games();
```

### Queen not selected?
```sql
-- Check cron job
SELECT * FROM cron.job WHERE jobname = 'weekly_queen_selection';
-- Should run Mondays 1 AM UTC (Sunday 8 PM ET)

-- Manually trigger
SELECT trigger_queen_selection();
```

### Scenarios not distributing?
```sql
-- Check cron job
SELECT * FROM cron.job WHERE jobname = 'distribute_daily_scenarios';
-- Should run Mondays 2 PM UTC (Monday 9 AM ET)

-- Manually trigger
SELECT distribute_daily_scenarios();
```

### Check game status
```sql
SELECT
  id,
  title,
  status,
  waiting_lobby_starts_at,
  waiting_lobby_ends_at,
  game_starts_at
FROM mm_games
WHERE status LIKE '%lobby%'
ORDER BY created_at DESC;
```

---

## 📊 Your Complete System

✅ 27 AI characters (ratchet personalities)
✅ Week-long lobbies (close Sundays)
✅ Synchronized launches (all games start Sundays 8 PM ET)
✅ First scenarios Monday 9 AM ET
✅ Weekly eliminations (Sunday 7:30 PM ET)
✅ Weekly queen selection (Sunday 8 PM ET)
✅ AI responses every 3 minutes
✅ Cost tracking (~$1.51/game)

**Your Mansion Mayhem system is ELITE!** 🔥💎👑
