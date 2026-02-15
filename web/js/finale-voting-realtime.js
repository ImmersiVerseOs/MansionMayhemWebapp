/**
 * Finale Voting Real-Time Updates
 * Mansion Mayhem - Live Fan Vote Tracking
 */

import { supabaseClient as supabase } from './supabase-module.js'

/**
 * Subscribe to finale round updates
 * @param {string} finaleRoundId - The finale round ID
 * @param {Function} onUpdate - Callback (finaleRound) => {}
 * @returns {Object} Subscription with unsubscribe method
 */
export function subscribeToFinaleUpdates(finaleRoundId, onUpdate) {
  const channel = supabase
    .channel(`finale-round-${finaleRoundId}`)
    .on('postgres_changes', {
      event: 'UPDATE',
      schema: 'public',
      table: 'mm_finale_rounds',
      filter: `id=eq.${finaleRoundId}`
    }, (payload) => {
      console.log('Finale round updated:', payload.new)
      if (onUpdate) {
        onUpdate(payload.new)
      }
    })
    .subscribe()

  return {
    unsubscribe: () => channel.unsubscribe()
  }
}

/**
 * Subscribe to new fan votes
 * @param {string} finaleRoundId - The finale round ID
 * @param {Function} onVote - Callback (vote) => {}
 * @returns {Object} Subscription with unsubscribe method
 */
export function subscribeToFinaleVotes(finaleRoundId, onVote) {
  const channel = supabase
    .channel(`finale-votes-${finaleRoundId}`)
    .on('postgres_changes', {
      event: 'INSERT',
      schema: 'public',
      table: 'mm_finale_fan_votes',
      filter: `finale_round_id=eq.${finaleRoundId}`
    }, (payload) => {
      console.log('New fan vote:', payload.new)
      if (onVote) {
        onVote(payload.new)
      }
    })
    .subscribe()

  return {
    unsubscribe: () => channel.unsubscribe()
  }
}

/**
 * Get current finale round for a game
 * @param {string} gameId - The game ID
 * @returns {Promise<Object|null>} Finale round data
 */
export async function getCurrentFinaleRound(gameId) {
  try {
    const { data, error } = await supabase
      .from('mm_finale_rounds')
      .select('*')
      .eq('game_id', gameId)
      .eq('status', 'voting_open')
      .single()

    if (error) {
      console.error('Error fetching finale round:', error)
      return null
    }

    return data
  } catch (err) {
    console.error('Error in getCurrentFinaleRound:', err)
    return null
  }
}

/**
 * Get finalist data with full stats
 * @param {string} castMemberId - Cast member ID
 * @param {string} gameId - Game ID
 * @returns {Promise<Object|null>} Finalist data with stats
 */
export async function getFinalistData(castMemberId, gameId) {
  try {
    // Get cast member base data
    const { data: castMember, error: cmError } = await supabase
      .from('cast_members')
      .select('*')
      .eq('id', castMemberId)
      .single()

    if (cmError) throw cmError

    // Get alliance count
    const { count: allianceCount } = await supabase
      .from('mm_alliance_rooms')
      .select('*', { count: 'exact', head: true })
      .contains('member_ids', [castMemberId])
      .eq('game_id', gameId)

    // Get post count
    const { count: postCount } = await supabase
      .from('mm_tea_room_posts')
      .select('*', { count: 'exact', head: true })
      .eq('cast_member_id', castMemberId)
      .eq('game_id', gameId)

    // Get scenario response count
    const { count: scenarioCount } = await supabase
      .from('scenario_responses')
      .select('*', { count: 'exact', head: true })
      .eq('cast_member_id', castMemberId)

    return {
      ...castMember,
      alliances: allianceCount || 0,
      tea_posts: postCount || 0,
      scenario_responses: scenarioCount || 0
    }
  } catch (err) {
    console.error('Error getting finalist data:', err)
    return null
  }
}

/**
 * Cast a fan vote
 * @param {string} finaleRoundId - Finale round ID
 * @param {string} castMemberId - Cast member to vote for
 * @returns {Promise<Object>} Result object { success, message, error }
 */
export async function castFanVote(finaleRoundId, castMemberId) {
  try {
    const { data: { user } } = await supabase.auth.getUser()

    const { data, error } = await supabase.rpc('cast_finale_fan_vote', {
      p_finale_round_id: finaleRoundId,
      p_voted_for_cast_member_id: castMemberId,
      p_voter_user_id: user?.id || null,
      p_voter_ip_address: null
    })

    if (error) throw error

    return data
  } catch (err) {
    console.error('Error casting vote:', err)
    return {
      success: false,
      error: err.message
    }
  }
}

/**
 * Check if user has already voted
 * @param {string} finaleRoundId - Finale round ID
 * @returns {Promise<boolean>} True if already voted
 */
export async function hasUserVoted(finaleRoundId) {
  try {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return false

    const { data, error } = await supabase
      .from('mm_finale_fan_votes')
      .select('id')
      .eq('finale_round_id', finaleRoundId)
      .eq('voter_user_id', user.id)
      .single()

    return !!data
  } catch (err) {
    return false
  }
}

/**
 * Get vote percentages for finalists
 * @param {Object} finaleRound - Finale round data
 * @returns {Object} { finalistA_pct, finalistB_pct, total }
 */
export function getVotePercentages(finaleRound) {
  const totalVotes = finaleRound.finalist_a_fan_votes + finaleRound.finalist_b_fan_votes

  if (totalVotes === 0) {
    return {
      finalistA_pct: 50,
      finalistB_pct: 50,
      total: 0
    }
  }

  return {
    finalistA_pct: Math.round((finaleRound.finalist_a_fan_votes / totalVotes) * 100),
    finalistB_pct: Math.round((finaleRound.finalist_b_fan_votes / totalVotes) * 100),
    total: totalVotes
  }
}

/**
 * Calculate final scores (used for display before official crowning)
 * @param {Object} finaleRound - Finale round data
 * @returns {Object} { finalistA_final, finalistB_final }
 */
export function calculateFinalScores(finaleRound) {
  const totalVotes = finaleRound.finalist_a_fan_votes + finaleRound.finalist_b_fan_votes

  if (totalVotes === 0) {
    return {
      finalistA_final: finaleRound.finalist_a_leaderboard_score * 0.5,
      finalistB_final: finaleRound.finalist_b_leaderboard_score * 0.5
    }
  }

  const finalistA_fanPct = (finaleRound.finalist_a_fan_votes / totalVotes) * 100
  const finalistB_fanPct = (finaleRound.finalist_b_fan_votes / totalVotes) * 100

  return {
    finalistA_final: (finaleRound.finalist_a_leaderboard_score * 0.5) + (finalistA_fanPct * 0.5),
    finalistB_final: (finaleRound.finalist_b_leaderboard_score * 0.5) + (finalistB_fanPct * 0.5)
  }
}

/**
 * Crown the winner (admin only)
 * @param {string} finaleRoundId - Finale round ID
 * @returns {Promise<Object>} Result with winner info
 */
export async function crownWinner(finaleRoundId) {
  try {
    const { data, error } = await supabase.rpc('crown_finale_winner', {
      p_finale_round_id: finaleRoundId
    })

    if (error) throw error

    return data
  } catch (err) {
    console.error('Error crowning winner:', err)
    return {
      success: false,
      error: err.message
    }
  }
}

/**
 * Get countdown time remaining
 * @param {string} closesAt - ISO timestamp when voting closes
 * @returns {Object} { days, hours, minutes, seconds, isExpired }
 */
export function getTimeRemaining(closesAt) {
  const closes = new Date(closesAt)
  const now = new Date()
  const diff = closes - now

  if (diff <= 0) {
    return {
      days: 0,
      hours: 0,
      minutes: 0,
      seconds: 0,
      isExpired: true
    }
  }

  return {
    days: Math.floor(diff / (1000 * 60 * 60 * 24)),
    hours: Math.floor((diff % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60)),
    minutes: Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60)),
    seconds: Math.floor((diff % (1000 * 60)) / 1000),
    isExpired: false
  }
}

// Export all functions
export default {
  subscribeToFinaleUpdates,
  subscribeToFinaleVotes,
  getCurrentFinaleRound,
  getFinalistData,
  castFanVote,
  hasUserVoted,
  getVotePercentages,
  calculateFinalScores,
  crownWinner,
  getTimeRemaining
}
