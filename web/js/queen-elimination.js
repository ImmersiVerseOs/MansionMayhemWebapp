/**
 * QUEEN + HOT SEAT + ELIMINATION SYSTEM
 * ======================================
 * Sunday: Random Queen selection
 * Week: Queen nominates 2 for Hot Seat
 * Saturday: Cast votes (Queen = 2X), Elimination
 */

class QueenEliminationSystem {
  constructor(supabaseClient, gameId) {
    this.supabase = supabaseClient;
    this.gameId = gameId;
    this.currentCastMemberId = localStorage.getItem('currentCastMemberId');
  }

  // ========================================
  // QUEEN SELECTION (Sunday)
  // ========================================

  async getCurrentQueen() {
    try {
      const { data, error } = await this.supabase
        .from('mm_weekly_queens')
        .select(`
          *,
          cast_members!mm_weekly_queens_queen_cast_id_fkey(
            id, full_name, display_name, archetype, avatar_url
          )
        `)
        .eq('game_id', this.gameId)
        .eq('throne_status', 'active')
        .order('week_number', { ascending: false })
        .limit(1)
        .maybeSingle();

      if (error) throw error;

      // Restructure data
      if (data && data.cast_members) {
        data.queen = data.cast_members;
        delete data.cast_members;
      }

      return data;
    } catch (error) {
      console.error('Error fetching queen:', error);
      return null;
    }
  }

  async selectRandomQueen(weekNumber) {
    try {
      const { data, error } = await this.supabase.rpc('select_random_queen', {
        p_game_id: this.gameId,
        p_week_number: weekNumber
      });

      if (error) throw error;
      return data; // Returns UUID of selected queen
    } catch (error) {
      console.error('Error selecting queen:', error);
      throw error;
    }
  }

  async isCurrentQueen() {
    if (!this.currentCastMemberId) return false;

    try {
      const queen = await this.getCurrentQueen();
      return queen && queen.queen_cast_id === this.currentCastMemberId;
    } catch (error) {
      return false;
    }
  }

  // ========================================
  // VOTING ROUNDS
  // ========================================

  async getActiveVotingRound() {
    try {
      const { data, error } = await this.supabase
        .from('mm_voting_rounds')
        .select(`
          *,
          hot_seat_nominees:mm_hot_seat_nominees(
            id,
            nomination_reason,
            vote_count,
            weighted_vote_count,
            cast_member:cast_members(
              id, full_name, display_name, archetype, avatar_url
            )
          )
        `)
        .eq('game_id', this.gameId)
        .in('status', ['nominations', 'voting', 'closed'])
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle();

      if (error) throw error;
      return data;
    } catch (error) {
      console.error('Error fetching voting round:', error);
      return null;
    }
  }

  async createVotingRound(weekNumber, title, description) {
    try {
      const queen = await this.getCurrentQueen();

      const { data, error } = await this.supabase
        .from('mm_voting_rounds')
        .insert([{
          game_id: this.gameId,
          weekly_queen_id: queen?.id || null,
          week_number: weekNumber,
          title: title,
          description: description,
          status: 'nominations'
        }])
        .select()
        .maybeSingle();

      if (error) throw error;
      return data;
    } catch (error) {
      console.error('Error creating voting round:', error);
      throw error;
    }
  }

  async updateVotingRoundStatus(roundId, status) {
    try {
      const updateData = { status };

      if (status === 'voting') {
        updateData.voting_opens_at = new Date().toISOString();
        // Initialize eligible voters count
        await this.supabase.rpc('initialize_elimination_voting', { round_id: roundId });
      }

      const { data, error } = await this.supabase
        .from('mm_voting_rounds')
        .update(updateData)
        .eq('id', roundId)
        .select()
        .maybeSingle();

      if (error) throw error;
      return data;
    } catch (error) {
      console.error('Error updating voting round:', error);
      throw error;
    }
  }

  // ========================================
  // HOT SEAT NOMINATIONS
  // ========================================

  async nominateForHotSeat(roundId, nominees) {
    if (nominees.length !== 2) {
      throw new Error('Must nominate exactly 2 cast members');
    }

    try {
      const nomineeData = nominees.map(nominee => ({
        voting_round_id: roundId,
        cast_member_id: nominee.castMemberId,
        nomination_reason: nominee.reason || 'Nominated by Queen',
      }));

      const { data, error } = await this.supabase
        .from('mm_hot_seat_nominees')
        .insert(nomineeData)
        .select(`
          *,
          cast_member:cast_members(
            id, full_name, display_name, archetype, avatar_url
          )
        `);

      if (error) throw error;
      return data;
    } catch (error) {
      console.error('Error nominating for hot seat:', error);
      throw error;
    }
  }

  async getHotSeatNominees(roundId) {
    try {
      const { data, error } = await this.supabase
        .from('mm_hot_seat_nominees')
        .select(`
          *,
          cast_member:cast_members(
            id, full_name, display_name, archetype, avatar_url
          )
        `)
        .eq('voting_round_id', roundId)
        .order('nominated_at', { ascending: true });

      if (error) throw error;
      return data || [];
    } catch (error) {
      console.error('Error fetching nominees:', error);
      return [];
    }
  }

  // ========================================
  // ELIMINATION VOTING (Queen = 2X)
  // ========================================

  async castEliminationVote(roundId, nomineeId, weekNumber) {
    if (!this.currentCastMemberId) {
      throw new Error('No cast member ID found');
    }

    try {
      // Get vote weight (Queen = 2X, others = 1X)
      const { data: weightData, error: weightError } = await this.supabase.rpc('get_vote_weight', {
        p_game_id: this.gameId,
        p_cast_member_id: this.currentCastMemberId,
        p_week_number: weekNumber
      });

      if (weightError) throw weightError;

      const voteWeight = weightData || 1.0;

      // Cast vote with weight
      const { data, error } = await this.supabase
        .from('mm_elimination_votes')
        .insert([{
          voting_round_id: roundId,
          voter_cast_id: this.currentCastMemberId,
          nominee_id: nomineeId,
          vote_weight: voteWeight
        }])
        .select()
        .maybeSingle();

      if (error) throw error;
      return { success: true, voteWeight, data };
    } catch (error) {
      console.error('Error casting vote:', error);
      throw error;
    }
  }

  async hasVoted(roundId) {
    if (!this.currentCastMemberId) return false;

    try {
      const { data, error } = await this.supabase
        .from('mm_elimination_votes')
        .select('id')
        .eq('voting_round_id', roundId)
        .eq('voter_cast_id', this.currentCastMemberId)
        .limit(1);

      if (error) throw error;
      return data && data.length > 0;
    } catch (error) {
      console.error('Error checking vote status:', error);
      return false;
    }
  }

  async getVotingStatus(roundId) {
    try {
      // Get all active cast members
      const { data: castMembers, error: castError } = await this.supabase
        .from('cast_members')
        .select('id, full_name, display_name, avatar_url')
        .eq('status', 'active');

      if (castError) throw castError;

      // Get all votes for this round
      const { data: votes, error: votesError } = await this.supabase
        .from('mm_elimination_votes')
        .select('voter_cast_id, vote_weight')
        .eq('voting_round_id', roundId);

      if (votesError) throw votesError;

      const votedMap = new Map(votes.map(v => [v.voter_cast_id, v.vote_weight]));

      return {
        voted: castMembers
          .filter(cm => votedMap.has(cm.id))
          .map(cm => ({ ...cm, voteWeight: votedMap.get(cm.id) })),
        notVoted: castMembers.filter(cm => !votedMap.has(cm.id)),
      };
    } catch (error) {
      console.error('Error fetching voting status:', error);
      throw error;
    }
  }

  // ========================================
  // ELIMINATION
  // ========================================

  async executeElimination(roundId) {
    try {
      // Get voting round details
      const { data: round, error: roundError } = await this.supabase
        .from('mm_voting_rounds')
        .select(`
          *,
          hot_seat_nominees:mm_hot_seat_nominees(
            id,
            weighted_vote_count,
            cast_member:cast_members(id, full_name, display_name)
          )
        `)
        .eq('id', roundId)
        .maybeSingle();

      if (roundError) throw roundError;

      if (!round || !round.hot_seat_nominees || round.hot_seat_nominees.length !== 2) {
        throw new Error('Invalid voting round or nominees');
      }

      // Find nominee with highest weighted vote count
      const nominees = round.hot_seat_nominees;
      const eliminated = nominees.reduce((prev, current) =>
        (current.weighted_vote_count > prev.weighted_vote_count) ? current : prev
      );

      // Create elimination record
      const { data: elimination, error: elimError } = await this.supabase
        .from('mm_eliminations')
        .insert([{
          game_id: round.game_id,
          voting_round_id: roundId,
          eliminated_cast_id: eliminated.cast_member.id,
          vote_count: eliminated.weighted_vote_count,
          total_votes: round.total_cast_votes
        }])
        .select(`
          *,
          eliminated_cast:cast_members(
            id, full_name, display_name, archetype, avatar_url
          )
        `)
        .maybeSingle();

      if (elimError) throw elimError;

      // Update cast member status to 'eliminated'
      const { error: statusError } = await this.supabase
        .from('cast_members')
        .update({ status: 'eliminated' })
        .eq('id', eliminated.cast_member.id);

      if (statusError) throw statusError;

      // Update voting round
      const { error: roundUpdateError } = await this.supabase
        .from('mm_voting_rounds')
        .update({
          eliminated_cast_id: eliminated.cast_member.id,
          status: 'revealed',
          revealed_at: new Date().toISOString()
        })
        .eq('id', roundId);

      if (roundUpdateError) throw roundUpdateError;

      return elimination;
    } catch (error) {
      console.error('Error executing elimination:', error);
      throw error;
    }
  }

  // ========================================
  // REAL-TIME SUBSCRIPTIONS
  // ========================================

  subscribeToQueen(callback) {
    return this.supabase
      .channel(`queen-${this.gameId}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'mm_weekly_queens',
          filter: `game_id=eq.${this.gameId}`
        },
        (payload) => callback(payload)
      )
      .subscribe();
  }

  subscribeToVotingRound(callback) {
    return this.supabase
      .channel(`voting-round-${this.gameId}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'mm_voting_rounds',
          filter: `game_id=eq.${this.gameId}`
        },
        (payload) => callback(payload)
      )
      .subscribe();
  }

  subscribeToHotSeat(roundId, callback) {
    return this.supabase
      .channel(`hot-seat-${roundId}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'mm_hot_seat_nominees',
          filter: `voting_round_id=eq.${roundId}`
        },
        (payload) => callback(payload)
      )
      .subscribe();
  }

  subscribeToVotes(roundId, callback) {
    return this.supabase
      .channel(`elimination-votes-${roundId}`)
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'mm_elimination_votes',
          filter: `voting_round_id=eq.${roundId}`
        },
        (payload) => callback(payload)
      )
      .subscribe();
  }
}

// Export
window.QueenEliminationSystem = QueenEliminationSystem;
console.log('✅ Queen + Hot Seat + Elimination system loaded');
