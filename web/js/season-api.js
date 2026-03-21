/**
 * SEASON API — Mansion Mayhem Live integration for Webapp
 * Queries the persistent season tables (same Supabase project)
 */

const SeasonAPI = (() => {
  function _sb() {
    return window.supabaseClient || (typeof getSupabase === 'function' ? getSupabase() : null);
  }

  // Get active season with week/day info
  async function getStatus() {
    const sb = _sb();
    if (!sb) return { active: false };

    const { data: season } = await sb
      .from('seasons')
      .select('*')
      .eq('status', 'active')
      .single();

    if (!season) return { active: false };

    const { data: week } = await sb
      .from('season_weeks')
      .select('*')
      .eq('season_id', season.id)
      .eq('status', 'active')
      .single();

    const { data: day } = await sb
      .from('season_days')
      .select('*')
      .eq('season_id', season.id)
      .eq('status', 'active')
      .single();

    const { count: playerCount } = await sb
      .from('season_players')
      .select('*', { count: 'exact', head: true })
      .eq('season_id', season.id)
      .eq('status', 'active');

    const { data: upcomingEvents } = await sb
      .from('scheduled_events')
      .select('*')
      .eq('season_id', season.id)
      .in('status', ['scheduled', 'active'])
      .order('starts_at')
      .limit(10);

    return { active: true, season, week, day, playerCount, upcomingEvents: upcomingEvents || [] };
  }

  // Daily check-in
  async function checkIn(seasonId) {
    const sb = _sb();
    const { data: { user } } = await sb.auth.getUser();
    if (!user) throw new Error('Not authenticated');

    const { data: day } = await sb
      .from('season_days')
      .select('id')
      .eq('season_id', seasonId)
      .eq('status', 'active')
      .single();

    if (day) {
      const { data: existing } = await sb
        .from('daily_checkins')
        .select('id')
        .eq('season_id', seasonId)
        .eq('player_id', user.id)
        .eq('day_id', day.id)
        .maybeSingle();
      if (existing) return { already_checked_in: true };
    }

    const { data: player } = await sb
      .from('season_players')
      .select('streak_days, longest_streak, xp, immunity_shards')
      .eq('season_id', seasonId)
      .eq('player_id', user.id)
      .single();

    if (!player) throw new Error('Not in this season');

    // Check yesterday
    const yesterday = new Date(); yesterday.setDate(yesterday.getDate() - 1); yesterday.setHours(0,0,0,0);
    const today = new Date(); today.setHours(0,0,0,0);
    const { data: yCheck } = await sb.from('daily_checkins').select('id')
      .eq('season_id', seasonId).eq('player_id', user.id)
      .gte('checked_in_at', yesterday.toISOString())
      .lt('checked_in_at', today.toISOString())
      .maybeSingle();

    const streak = yCheck ? player.streak_days + 1 : 1;
    const bonus = Math.min(streak * 2, 20);
    const xp = 10 + bonus;
    const shard = streak > 0 && streak % 7 === 0;

    await sb.from('daily_checkins').insert({
      season_id: seasonId, player_id: user.id, day_id: day?.id || null,
      xp_earned: xp, streak_bonus: bonus, platform: 'web'
    });

    const updates = { streak_days: streak, longest_streak: Math.max(streak, player.longest_streak), xp: player.xp + xp };
    if (shard) updates.immunity_shards = player.immunity_shards + 1;
    await sb.from('season_players').update(updates).eq('season_id', seasonId).eq('player_id', user.id);

    return { xp_earned: xp, streak, streak_bonus: bonus, immunity_shard_awarded: shard, total_xp: player.xp + xp };
  }

  // Get all players in season
  async function getPlayers(seasonId) {
    const sb = _sb();
    const { data } = await sb.from('season_players').select('*')
      .eq('season_id', seasonId).order('xp', { ascending: false });
    return data || [];
  }

  // Get bedroom assignments
  async function getRooms(seasonId) {
    const sb = _sb();
    const { data: week } = await sb.from('season_weeks').select('id')
      .eq('season_id', seasonId).eq('status', 'active').single();
    if (!week) return [];

    const { data: bedrooms } = await sb.from('bedrooms').select('*').order('room_number');
    const { data: assignments } = await sb.from('room_assignments').select('*')
      .eq('season_id', seasonId).eq('week_id', week.id).is('moved_out_at', null);

    const playerIds = (assignments || []).map(a => a.player_id);
    const { data: players } = await sb.from('season_players').select('player_id, display_name, archetype, accent_color')
      .eq('season_id', seasonId).in('player_id', playerIds.length ? playerIds : ['none']);

    const pMap = new Map((players || []).map(p => [p.player_id, p]));

    return (bedrooms || []).map(b => ({
      ...b,
      occupants: (assignments || []).filter(a => a.bedroom_id === b.id).map(a => ({
        player_id: a.player_id,
        display_name: pMap.get(a.player_id)?.display_name || '?',
        accent_color: pMap.get(a.player_id)?.accent_color || '#fff',
        assigned_by: a.assigned_by,
      }))
    }));
  }

  // Get today's events
  async function getEvents(seasonId) {
    const sb = _sb();
    const { data: day } = await sb.from('season_days').select('id')
      .eq('season_id', seasonId).eq('status', 'active').single();
    if (!day) return [];
    const { data } = await sb.from('scheduled_events').select('*')
      .eq('day_id', day.id).order('starts_at');
    return data || [];
  }

  // Get AI crew
  async function getCrew() {
    const sb = _sb();
    const { data } = await sb.from('ai_crew').select('*');
    return data || [];
  }

  // Join season
  async function joinSeason(seasonId, displayName, archetype) {
    const sb = _sb();
    const { data: { user } } = await sb.auth.getUser();
    if (!user) throw new Error('Not authenticated');

    const { data, error } = await sb.from('season_players').insert({
      season_id: seasonId, player_id: user.id,
      display_name: displayName, archetype: archetype || null,
    }).select().single();

    if (error) throw error;
    return data;
  }

  // Check if user is in season
  async function isInSeason(seasonId) {
    const sb = _sb();
    const { data: { user } } = await sb.auth.getUser();
    if (!user) return false;
    const { data } = await sb.from('season_players').select('id')
      .eq('season_id', seasonId).eq('player_id', user.id).maybeSingle();
    return !!data;
  }

  return { getStatus, checkIn, getPlayers, getRooms, getEvents, getCrew, joinSeason, isInSeason };
})();
