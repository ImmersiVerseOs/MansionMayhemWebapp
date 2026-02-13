/**
 * VOTING PAGE - REAL-TIME UPDATES
 * ================================
 * Adds real-time vote count updates to the voting page
 */

class VotingRealtime {
  constructor(supabaseClient, realtimeManager, gameId) {
    this.supabase = supabaseClient;
    this.realtime = realtimeManager;
    this.gameId = gameId;
    this.currentVoteType = 'elimination'; // or 'hot_seat', 'fan_favorite', etc.

    this.init();
  }

  async init() {
    // Load initial vote counts
    await this.loadVoteCounts();

    // Subscribe to real-time updates
    this.realtime.subscribeToVotes(this.gameId, (payload) => {
      this.handleVoteUpdate(payload);
    });

    console.log('📊 Real-time voting initialized');
  }

  async loadVoteCounts() {
    const counts = await this.realtime.getVoteCounts(this.gameId, this.currentVoteType);

    if (counts) {
      this.updateVoteDisplay(counts);
    }
  }

  handleVoteUpdate(payload) {
    console.log('📊 Vote update received:', payload);

    // payload.new contains the updated vote count record
    if (payload.eventType === 'INSERT' || payload.eventType === 'UPDATE') {
      this.updateSingleCastMember(payload.new);
    }
  }

  updateVoteDisplay(counts) {
    // Sort by vote count (descending)
    counts.sort((a, b) => b.vote_count - a.vote_count);

    counts.forEach((count, index) => {
      this.updateSingleCastMember(count, index === 0); // First is leading
    });
  }

  updateSingleCastMember(voteData, isLeading = false) {
    const castMemberId = voteData.target_cast_member_id;
    const voteCount = voteData.vote_count;
    const percentage = voteData.percentage;

    // Find the cast member card
    const card = document.querySelector(`[data-cast-id="${castMemberId}"]`);
    if (!card) return;

    // Update vote count
    const voteCountEl = card.querySelector('.card-votes');
    if (voteCountEl) {
      voteCountEl.textContent = `${voteCount} votes`;
    }

    // Update percentage
    const percentageEl = card.querySelector('.card-percentage');
    if (percentageEl) {
      percentageEl.textContent = `${percentage.toFixed(1)}%`;
    }

    // Update progress bar if exists
    const progressBar = card.querySelector('.vote-progress-fill');
    if (progressBar) {
      progressBar.style.width = `${percentage}%`;
    }

    // Add/remove leading class
    if (isLeading) {
      card.classList.add('leading');
      // Add crown if not exists
      if (!card.classList.contains('has-crown')) {
        card.classList.add('has-crown');
      }
    } else {
      card.classList.remove('leading');
      card.classList.remove('has-crown');
    }

    // Animate the update
    card.classList.add('vote-updated');
    setTimeout(() => card.classList.remove('vote-updated'), 500);
  }

  // Function to call when user submits a vote
  async submitVote(castMemberId) {
    // Submit vote to database (your existing vote submission logic)
    // ...

    // After successful vote, trigger vote count update
    await this.triggerVoteCountUpdate();
  }

  async triggerVoteCountUpdate() {
    try {
      // Call the update_vote_counts function
      const { error } = await this.supabase.rpc('update_vote_counts', {
        p_game_id: this.gameId,
        p_vote_type: this.currentVoteType
      });

      if (error) {
        console.error('Error updating vote counts:', error);
        // Show user-facing error message
        if (window.showToast) {
          window.showToast('Failed to update vote counts. Please refresh the page.', 'error');
        }
      } else {
        console.log('✅ Vote counts updated');
      }
    } catch (e) {
      console.error('Error triggering vote update:', e);
      // Show user-facing error message
      if (window.showToast) {
        window.showToast('An error occurred while updating votes. Please try again.', 'error');
      }
    }
  }
}

// Export
window.VotingRealtime = VotingRealtime;
console.log('✅ Voting real-time module loaded');
