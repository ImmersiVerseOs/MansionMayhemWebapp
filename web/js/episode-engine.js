/**
 * ============================================================
 * MANSION OF MAYHEM — EPISODE ENGINE (Web/Mobile)
 * ============================================================
 * Ported from VR live-game-engine.js → Supabase Realtime.
 * Server-authoritative: cron drives phase transitions.
 * Client timer is COSMETIC — server is the truth.
 * ============================================================
 */

import { getSupabase } from '/js/supabase.js';
const supabase = getSupabase();

// ============================================================
// EPISODE ENGINE
// ============================================================

export class EpisodeEngine {
  constructor(gameId, options = {}) {
    this.gameId = gameId;
    this.castMemberId = options.castMemberId || null;
    this.userId = options.userId || null;

    // ---- GAME STATE (synced from server) ----
    this.state = {
      episode: 0,
      phase: 'lobby',
      phaseStartedAt: null,
      phaseDurationSecs: 0,
      phaseTimeRemaining: 0,
      dramaLevel: 0,
      gameMode: 'party',
      gameStatus: 'active',
      // Players
      players: [],        // { cast_member_id, display_name, archetype, status, strike_count, immunity, drama_points, secret_role }
      myRole: null,        // Only MY role
      myMissions: [],      // Only MY missions
      myPowers: [],        // Only MY powers
      // Episode data
      directorMessages: [],
      secrets: [],
      challenge: null,
      votes: new Map(),
      votingOpen: false,
      // Fight state
      activeFight: null,
    };

    // Phase durations (default Party mode — overridden by server)
    this.phaseDurations = {
      arrival: 180, social: 480, challenge: 420,
      whisper: 300, confrontation: 300, deliberation: 240, elimination: 180,
    };
    this.phaseOrder = ['arrival', 'social', 'challenge', 'whisper', 'confrontation', 'deliberation', 'elimination'];

    // Timer
    this.timerInterval = null;

    // Event listeners
    this.listeners = new Map();

    // Supabase subscriptions
    this.subscriptions = [];
  }

  // ============================================================
  // INITIALIZATION
  // ============================================================

  async init() {
    // Load initial game state
    await this._loadGameState();
    await this._loadPlayers();
    await this._loadMyRole();
    await this._loadMyMissions();
    await this._loadMyPowers();
    await this._loadDirectorMessages();
    await this._loadChallenge();

    // Subscribe to real-time updates
    this._subscribeToGame();
    this._subscribeToPlayers();
    this._subscribeToDirector();
    this._subscribeToFights();
    this._subscribeToPowers();
    this._subscribeToMissions();
    this._subscribeToSecrets();

    // Start cosmetic timer
    this._startTimer();

    this.emit('engine-ready', this.getState());
    return this;
  }

  // ============================================================
  // DATA LOADING
  // ============================================================

  async _loadGameState() {
    const { data } = await supabase
      .from('mm_games')
      .select('*, game_mode_templates(*)')
      .eq('id', this.gameId)
      .single();

    if (data) {
      this.state.episode = data.episode_number || 1;
      this.state.phase = data.current_phase || 'lobby';
      this.state.phaseStartedAt = data.phase_started_at;
      this.state.dramaLevel = data.drama_level || 0;
      this.state.gameMode = data.game_mode || 'party';
      this.state.gameStatus = data.status;

      // Load mode-specific phase durations
      if (data.game_mode) {
        const { data: phases } = await supabase
          .from('episode_phase_templates')
          .select('*')
          .eq('mode_name', data.game_mode)
          .order('phase_order');

        if (phases) {
          phases.forEach(p => { this.phaseDurations[p.phase_name] = p.duration_secs; });
        }
      }

      this.state.phaseDurationSecs = this.phaseDurations[this.state.phase] || 300;
    }
  }

  async _loadPlayers() {
    const { data } = await supabase
      .from('mm_game_cast')
      .select('*, cast_members(id, display_name, archetype, avatar_url, is_ai_player)')
      .eq('game_id', this.gameId)
      .order('joined_at');

    if (data) {
      this.state.players = data.map(gc => ({
        cast_member_id: gc.cast_member_id,
        display_name: gc.cast_members?.display_name || 'Unknown',
        archetype: gc.cast_members?.archetype || 'wildcard',
        avatar_url: gc.cast_members?.avatar_url,
        is_ai: gc.cast_members?.is_ai_player || false,
        status: gc.status,
        strike_count: gc.strike_count || 0,
        immunity: gc.immunity || false,
        drama_points: gc.drama_points || 0,
        has_power: gc.has_power,
        missions_completed: gc.missions_completed || 0,
      }));
    }
  }

  async _loadMyRole() {
    if (!this.castMemberId) return;
    const { data } = await supabase
      .from('episode_player_roles')
      .select('*, episode_role_templates(*)')
      .eq('game_id', this.gameId)
      .eq('episode_number', this.state.episode)
      .eq('cast_member_id', this.castMemberId)
      .maybeSingle();

    if (data) {
      this.state.myRole = {
        name: data.role_name,
        template: data.episode_role_templates,
        is_revealed: data.is_revealed,
        ability_uses: data.ability_uses_remaining,
      };
    }
  }

  async _loadMyMissions() {
    if (!this.castMemberId) return;
    const { data } = await supabase
      .from('episode_missions')
      .select('*, episode_mission_templates(*)')
      .eq('game_id', this.gameId)
      .eq('episode_number', this.state.episode)
      .eq('cast_member_id', this.castMemberId)
      .in('status', ['active']);

    this.state.myMissions = data || [];
  }

  async _loadMyPowers() {
    if (!this.castMemberId) return;
    const { data } = await supabase
      .from('episode_powers')
      .select('*')
      .eq('game_id', this.gameId)
      .eq('cast_member_id', this.castMemberId)
      .eq('is_used', false);

    this.state.myPowers = data || [];
  }

  async _loadDirectorMessages() {
    const { data } = await supabase
      .from('episode_director_log')
      .select('*')
      .eq('game_id', this.gameId)
      .eq('episode_number', this.state.episode)
      .order('created_at', { ascending: false })
      .limit(10);

    this.state.directorMessages = (data || []).reverse();
  }

  async _loadChallenge() {
    const { data } = await supabase
      .from('episode_challenges')
      .select('*, episode_challenge_templates(*)')
      .eq('game_id', this.gameId)
      .eq('episode_number', this.state.episode)
      .eq('status', 'active')
      .maybeSingle();

    this.state.challenge = data;
  }

  // ============================================================
  // REAL-TIME SUBSCRIPTIONS
  // ============================================================

  _subscribeToGame() {
    const ch = supabase
      .channel(`game-${this.gameId}`)
      .on('postgres_changes', {
        event: 'UPDATE', schema: 'public', table: 'mm_games',
        filter: `id=eq.${this.gameId}`
      }, (payload) => {
        const old = this.state.phase;
        const game = payload.new;

        this.state.phase = game.current_phase || this.state.phase;
        this.state.phaseStartedAt = game.phase_started_at;
        this.state.dramaLevel = game.drama_level || 0;
        this.state.episode = game.episode_number || this.state.episode;
        this.state.gameStatus = game.status;
        this.state.phaseDurationSecs = this.phaseDurations[this.state.phase] || 300;

        if (game.current_phase !== old) {
          this._onPhaseChange(old, game.current_phase);
        }
        if (game.status === 'completed') {
          this.emit('game-over', { status: 'completed' });
        }

        this.emit('game-update', this.getState());
      })
      .subscribe();
    this.subscriptions.push(ch);
  }

  _subscribeToPlayers() {
    const ch = supabase
      .channel(`players-${this.gameId}`)
      .on('postgres_changes', {
        event: '*', schema: 'public', table: 'mm_game_cast',
        filter: `game_id=eq.${this.gameId}`
      }, async () => {
        await this._loadPlayers();
        this.emit('players-update', this.state.players);
      })
      .subscribe();
    this.subscriptions.push(ch);
  }

  _subscribeToDirector() {
    const ch = supabase
      .channel(`director-${this.gameId}`)
      .on('postgres_changes', {
        event: 'INSERT', schema: 'public', table: 'episode_director_log',
        filter: `game_id=eq.${this.gameId}`
      }, (payload) => {
        const msg = payload.new;
        this.state.directorMessages.push(msg);
        // Keep last 20
        if (this.state.directorMessages.length > 20) this.state.directorMessages.shift();

        this.emit('director-message', msg);

        // Whisper only goes to target
        if (msg.message_type === 'whisper' && msg.target_cast_id !== this.castMemberId) return;
        this.emit('director-announcement', { text: msg.content, type: msg.message_type, phase: msg.phase });
      })
      .subscribe();
    this.subscriptions.push(ch);
  }

  _subscribeToFights() {
    const ch = supabase
      .channel(`fights-${this.gameId}`)
      .on('postgres_changes', {
        event: 'INSERT', schema: 'public', table: 'episode_fights',
        filter: `game_id=eq.${this.gameId}`
      }, (payload) => {
        const fight = payload.new;
        this.state.activeFight = fight;
        this.emit('fight-started', fight);

        // Check if I'm involved
        if (fight.initiator_id === this.castMemberId || fight.target_id === this.castMemberId) {
          this.emit('fight-involved', fight);
        }
      })
      .subscribe();
    this.subscriptions.push(ch);
  }

  _subscribeToPowers() {
    const ch = supabase
      .channel(`powers-${this.gameId}`)
      .on('postgres_changes', {
        event: 'INSERT', schema: 'public', table: 'episode_powers',
        filter: `game_id=eq.${this.gameId}`
      }, async (payload) => {
        if (payload.new.cast_member_id === this.castMemberId) {
          await this._loadMyPowers();
          this.emit('power-gained', payload.new);
        }
      })
      .subscribe();
    this.subscriptions.push(ch);
  }

  _subscribeToMissions() {
    const ch = supabase
      .channel(`missions-${this.gameId}`)
      .on('postgres_changes', {
        event: '*', schema: 'public', table: 'episode_missions',
        filter: `game_id=eq.${this.gameId}`
      }, async (payload) => {
        if (payload.new?.cast_member_id === this.castMemberId) {
          await this._loadMyMissions();
          if (payload.eventType === 'INSERT') {
            this.emit('mission-assigned', payload.new);
          } else {
            this.emit('mission-update', payload.new);
          }
        }
      })
      .subscribe();
    this.subscriptions.push(ch);
  }

  _subscribeToSecrets() {
    const ch = supabase
      .channel(`secrets-${this.gameId}`)
      .on('postgres_changes', {
        event: 'UPDATE', schema: 'public', table: 'episode_secrets',
        filter: `game_id=eq.${this.gameId}`
      }, (payload) => {
        if (payload.new.is_revealed) {
          this.state.secrets.push(payload.new);
          this.emit('secret-revealed', payload.new);
        }
      })
      .subscribe();
    this.subscriptions.push(ch);
  }

  // ============================================================
  // PHASE TRANSITIONS (triggered by server via Realtime)
  // ============================================================

  async _onPhaseChange(oldPhase, newPhase) {
    console.log(`[EpisodeEngine] Phase: ${oldPhase} → ${newPhase}`);

    // Reload relevant data for new phase
    if (newPhase === 'arrival') {
      await this._loadMyRole();
    }
    if (['social', 'whisper'].includes(newPhase)) {
      await this._loadMyMissions();
    }
    if (newPhase === 'challenge') {
      await this._loadChallenge();
    }
    if (newPhase === 'deliberation') {
      this.state.votingOpen = true;
    }
    if (newPhase === 'elimination') {
      this.state.votingOpen = false;
    }

    // Restart cosmetic timer
    this._startTimer();

    this.emit('phase-change', {
      oldPhase, newPhase,
      duration: this.phaseDurations[newPhase] || 300,
      episode: this.state.episode,
    });
  }

  // ============================================================
  // COSMETIC TIMER (server is authoritative)
  // ============================================================

  _startTimer() {
    if (this.timerInterval) clearInterval(this.timerInterval);

    const phaseDuration = this.phaseDurations[this.state.phase] || 300;

    // Calculate remaining from server phase_started_at
    if (this.state.phaseStartedAt) {
      const elapsed = (Date.now() - new Date(this.state.phaseStartedAt).getTime()) / 1000;
      this.state.phaseTimeRemaining = Math.max(0, Math.round(phaseDuration - elapsed));
    } else {
      this.state.phaseTimeRemaining = phaseDuration;
    }

    this.timerInterval = setInterval(() => {
      this.state.phaseTimeRemaining = Math.max(0, this.state.phaseTimeRemaining - 1);

      const total = this.phaseDurations[this.state.phase] || 300;
      const pct = this.state.phaseTimeRemaining / total;

      this.emit('timer-tick', {
        remaining: this.state.phaseTimeRemaining,
        total,
        percentage: pct,
        phase: this.state.phase,
        urgency: pct < 0.15 ? 'critical' : pct < 0.3 ? 'warning' : 'normal',
      });
    }, 1000);
  }

  // ============================================================
  // PLAYER ACTIONS — Write to Supabase, server processes
  // ============================================================

  /** Cast a vote for elimination */
  async castVote(targetCastId) {
    if (!this.state.votingOpen) return { success: false, reason: 'Voting closed' };

    // Check for immunity
    const target = this.state.players.find(p => p.cast_member_id === targetCastId);
    if (target?.immunity) return { success: false, reason: 'Player has immunity' };

    // Check for double_vote power
    const doublePower = this.state.myPowers.find(p => p.power_type === 'double_vote' && !p.is_used);

    // Find active voting round
    const { data: round } = await supabase
      .from('mm_voting_rounds')
      .select('id')
      .eq('game_id', this.gameId)
      .in('status', ['open', 'active'])
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    if (!round) return { success: false, reason: 'No active voting round' };

    // Insert or update vote
    const { error } = await supabase
      .from('mm_elimination_votes')
      .upsert({
        round_id: round.id,
        cast_member_id: this.castMemberId,
        voted_for_id: targetCastId,
      }, { onConflict: 'round_id,cast_member_id' });

    if (error) return { success: false, reason: error.message };

    this.state.votes.set(this.castMemberId, targetCastId);
    this.emit('vote-cast', { voter: this.castMemberId, target: targetCastId });
    return { success: true };
  }

  /** Initiate a fight with another player */
  async initiateFight(targetCastId, fightType = 'shove') {
    const validTypes = ['shove', 'table_flip', 'drink_throw', 'champagne_splash', 'hallway_slam', 'confession_eruption'];
    if (!validTypes.includes(fightType)) fightType = 'shove';

    const { data, error } = await supabase
      .from('episode_fights')
      .insert({
        game_id: this.gameId,
        episode_number: this.state.episode,
        initiator_id: this.castMemberId,
        target_id: targetCastId,
        fight_type: fightType,
        phase: this.state.phase,
        outcome: 'completed', // Default, can be changed to walked_away
        drama_generated: 15,
      })
      .select()
      .single();

    if (error) return { success: false, reason: error.message };

    // Process fight server-side
    await supabase.rpc('process_episode_fight', { p_fight_id: data.id });

    this.emit('fight-initiated', data);
    return { success: true, fight: data };
  }

  /** Use a power */
  async usePower(powerId, targetCastId = null) {
    const { data, error } = await supabase
      .from('episode_powers')
      .update({
        is_used: true,
        used_at: new Date().toISOString(),
        target_cast_id: targetCastId,
      })
      .eq('id', powerId)
      .eq('cast_member_id', this.castMemberId)
      .select()
      .single();

    if (error) return { success: false, reason: error.message };

    await this._loadMyPowers();
    this.emit('power-used', data);
    return { success: true, power: data };
  }

  /** Complete a mission */
  async completeMission(missionId) {
    const { data, error } = await supabase
      .from('episode_missions')
      .update({ status: 'completed', completed_at: new Date().toISOString() })
      .eq('id', missionId)
      .eq('cast_member_id', this.castMemberId)
      .select()
      .single();

    if (error) return { success: false, reason: error.message };

    // Update player stats
    await supabase
      .from('mm_game_cast')
      .update({ missions_completed: this.state.players.find(p => p.cast_member_id === this.castMemberId)?.missions_completed + 1 || 1 })
      .eq('game_id', this.gameId)
      .eq('cast_member_id', this.castMemberId);

    await this._loadMyMissions();
    this.emit('mission-completed', data);
    return { success: true, mission: data };
  }

  /** Form an alliance with other players */
  async formAlliance(name, memberIds) {
    const allMembers = [this.castMemberId, ...memberIds];
    const roomType = allMembers.length === 2 ? 'duo' : allMembers.length === 3 ? 'trio' : 'quad';

    const { data, error } = await supabase
      .from('mm_alliance_rooms')
      .insert({
        game_id: this.gameId,
        room_name: name,
        room_type: roomType,
        member_ids: allMembers,
        status: 'active',
      })
      .select()
      .single();

    if (error) return { success: false, reason: error.message };

    this.emit('alliance-formed', data);
    return { success: true, alliance: data };
  }

  /** Send a chat message */
  async sendChat(content, chatType = 'public', targetId = null) {
    const { error } = await supabase
      .from('mm_tea_room_posts')
      .insert({
        game_id: this.gameId,
        cast_member_id: this.castMemberId,
        content,
        post_type: chatType === 'whisper' ? 'anonymous' : 'tea',
        phase: this.state.phase,
      });

    return { success: !error, error: error?.message };
  }

  // ============================================================
  // HELPER METHODS
  // ============================================================

  getActivePlayers() {
    return this.state.players.filter(p => p.status === 'active');
  }

  getEliminatedPlayers() {
    return this.state.players.filter(p => p.status === 'eliminated');
  }

  getMyPlayer() {
    return this.state.players.find(p => p.cast_member_id === this.castMemberId);
  }

  getPhaseInfo() {
    const total = this.phaseDurations[this.state.phase] || 300;
    const remaining = this.state.phaseTimeRemaining;
    const pct = total > 0 ? remaining / total : 0;
    return {
      name: this.state.phase,
      remaining,
      total,
      percentage: pct,
      label: this._getPhaseLabel(this.state.phase),
      description: this._getPhaseDescription(this.state.phase),
      icon: this._getPhaseIcon(this.state.phase),
      urgency: pct < 0.15 ? 'critical' : pct < 0.3 ? 'warning' : 'normal',
    };
  }

  getDramaColor() {
    const d = this.state.dramaLevel;
    if (d < 25) return '#4CAF50';   // Green — calm
    if (d < 50) return '#FFC107';   // Yellow — tension
    if (d < 75) return '#FF9800';   // Orange — heated
    return '#E94560';               // Red — chaos
  }

  _getPhaseLabel(phase) {
    return { arrival: 'Arrival', social: 'Social Hour', challenge: 'The Challenge', whisper: 'Whisper Hour', confrontation: 'Confrontation', deliberation: 'Deliberation', elimination: 'Elimination' }[phase] || phase;
  }

  _getPhaseDescription(phase) {
    return {
      arrival: 'Your role has been assigned. Explore the Mansion.',
      social: 'Mingle, form alliances, complete missions.',
      challenge: 'Compete for immunity and powers.',
      whisper: 'The lights dim. Whisper your secrets.',
      confrontation: 'The Director reveals a secret. React.',
      deliberation: 'Vote to eliminate someone.',
      elimination: 'The votes are in.',
    }[phase] || '';
  }

  _getPhaseIcon(phase) {
    return { arrival: '🏰', social: '💬', challenge: '⚔️', whisper: '🤫', confrontation: '💥', deliberation: '🗳️', elimination: '🚪' }[phase] || '🎭';
  }

  // ============================================================
  // STATE EXPORT & CLEANUP
  // ============================================================

  getState() {
    return { ...this.state };
  }

  destroy() {
    if (this.timerInterval) clearInterval(this.timerInterval);
    this.subscriptions.forEach(ch => ch.unsubscribe());
    this.subscriptions = [];
    this.listeners.clear();
  }

  // ============================================================
  // EVENT SYSTEM
  // ============================================================

  on(event, cb) {
    if (!this.listeners.has(event)) this.listeners.set(event, []);
    this.listeners.get(event).push(cb);
    return () => {
      const cbs = this.listeners.get(event);
      if (cbs) this.listeners.set(event, cbs.filter(c => c !== cb));
    };
  }

  emit(event, data) {
    (this.listeners.get(event) || []).forEach(cb => {
      try { cb(data); } catch (e) { console.error(`[EpisodeEngine] Error in ${event}:`, e); }
    });
  }
}

export default EpisodeEngine;
