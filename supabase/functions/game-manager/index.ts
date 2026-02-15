// ============================================================================
// GAME MANAGER - Mansion Mayhem
// ============================================================================
// Handles week progression, scenario activation, queen selection, voting
// Runs on schedule via cron job (daily checks)
// ============================================================================

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    console.log('🎮 Game Manager: Checking game progressions...')

    // Get all active games
    const { data: activeGames } = await supabase
      .from('mm_games')
      .select('*')
      .eq('status', 'active')

    if (!activeGames || activeGames.length === 0) {
      console.log('No active games to process')
      return new Response(JSON.stringify({ success: true, games_processed: 0 }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const results = []

    for (const game of activeGames) {
      const gameResult = await processGameProgression(game)
      results.push(gameResult)
    }

    return new Response(JSON.stringify({
      success: true,
      games_processed: results.length,
      results
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  } catch (error) {
    console.error('Game manager error:', error)
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500
    })
  }
})

async function processGameProgression(game: any) {
  const now = new Date()
  const startedAt = new Date(game.started_at)

  // Calculate current week (Sunday to Saturday)
  const daysSinceStart = Math.floor((now.getTime() - startedAt.getTime()) / (1000 * 60 * 60 * 24))
  const currentWeek = Math.floor(daysSinceStart / 7) + 1

  console.log(`Game ${game.id}: Week ${currentWeek}, Day ${daysSinceStart % 7}`)

  const actions = []

  // Check if it's Sunday (day 0) - new week start
  const dayOfWeek = now.getDay()
  const isSunday = dayOfWeek === 0

  if (isSunday) {
    console.log('📅 Sunday detected - starting new week activities')

    // Activate this week's scenarios
    const scenariosActivated = await activateWeeklyScenarios(game.id, currentWeek)
    actions.push({ action: 'activate_scenarios', count: scenariosActivated })

    // Select queen for this week (if not already selected)
    const queenSelected = await selectWeeklyQueen(game.id, currentWeek)
    actions.push({ action: 'select_queen', success: queenSelected })
  }

  // Check if voting should start (e.g., Friday evening, day 5)
  const isFriday = dayOfWeek === 5
  const isEvening = now.getHours() >= 18

  if (isFriday && isEvening) {
    console.log('🗳️ Friday evening - starting weekly voting')
    const votingStarted = await startWeeklyVoting(game.id, currentWeek)
    actions.push({ action: 'start_voting', success: votingStarted })
  }

  // Check if voting should close (e.g., Sunday morning, just before queen selection)
  if (isSunday) {
    const votingClosed = await closeWeeklyVoting(game.id, currentWeek - 1) // Close previous week's voting
    actions.push({ action: 'close_voting', success: votingClosed })
  }

  // Check if game should end (e.g., 10 weeks or only 2 players left)
  if (currentWeek > 10) {
    const gameEnded = await endGame(game.id)
    actions.push({ action: 'end_game', success: gameEnded })
  } else {
    // Check if only 2 players remain
    const { data: activePlayers } = await supabase
      .from('mm_game_cast')
      .select('cast_member_id')
      .eq('game_id', game.id)
      .eq('status', 'active')

    if (activePlayers && activePlayers.length <= 2) {
      const gameEnded = await endGame(game.id)
      actions.push({ action: 'end_game_final_two', success: gameEnded })
    }
  }

  return { game_id: game.id, week: currentWeek, actions }
}

async function activateWeeklyScenarios(gameId: string, weekNumber: number) {
  console.log(`📋 Activating scenarios for week ${weekNumber}`)

  // Get queued scenarios
  const { data: scenarios } = await supabase
    .from('scenarios')
    .select('*')
    .eq('game_id', gameId)
    .eq('status', 'queued')
    .limit(3) // Activate 3 scenarios per week

  if (!scenarios || scenarios.length === 0) {
    console.log('No queued scenarios to activate')
    return 0
  }

  const deadline = new Date()
  deadline.setDate(deadline.getDate() + 5) // 5 days to respond (until Friday)

  let activatedCount = 0

  for (const scenario of scenarios) {
    const { error } = await supabase
      .from('scenarios')
      .update({
        status: 'active',
        deadline_at: deadline.toISOString(),
        distribution_date: new Date().toISOString()
      })
      .eq('id', scenario.id)

    if (!error) {
      activatedCount++
      console.log(`✅ Activated scenario: ${scenario.title}`)
    }
  }

  return activatedCount
}

async function selectWeeklyQueen(gameId: string, weekNumber: number) {
  console.log(`👑 Selecting queen for week ${weekNumber}`)

  // Check if queen already selected this week
  const { data: existing } = await supabase
    .from('mm_queen_selections')
    .select('*')
    .eq('game_id', gameId)
    .eq('week_number', weekNumber)
    .maybeSingle()

  if (existing) {
    console.log('Queen already selected this week')
    return false
  }

  // Get eligible cast members (not eliminated)
  const { data: eligible } = await supabase
    .from('mm_game_cast')
    .select('cast_member_id')
    .eq('game_id', gameId)
    .eq('status', 'active')

  if (!eligible || eligible.length === 0) {
    console.log('No eligible cast members for queen selection')
    return false
  }

  // Random queen selection (lottery style)
  const randomIndex = Math.floor(Math.random() * eligible.length)
  const queenId = eligible[randomIndex].cast_member_id

  const { error } = await supabase
    .from('mm_queen_selections')
    .insert({
      game_id: gameId,
      week_number: weekNumber,
      round_number: weekNumber,
      selected_queen_id: queenId,
      selection_method: 'random_lottery'
    })

  if (error) {
    console.error('Error selecting queen:', error)
    return false
  }

  console.log(`✅ Queen selected for week ${weekNumber}: ${queenId}`)
  return true
}

async function startWeeklyVoting(gameId: string, weekNumber: number) {
  console.log(`🗳️ Starting voting for week ${weekNumber}`)

  // Check if voting round already exists
  const { data: existing } = await supabase
    .from('mm_voting_rounds')
    .select('*')
    .eq('game_id', gameId)
    .eq('round_number', weekNumber)
    .maybeSingle()

  if (existing) {
    console.log('Voting round already exists for this week')
    return false
  }

  // Get queen selection
  const { data: queenSelection } = await supabase
    .from('mm_queen_selections')
    .select('*')
    .eq('game_id', gameId)
    .eq('week_number', weekNumber)
    .maybeSingle()

  if (!queenSelection) {
    console.log('No queen selected yet, cannot start voting')
    return false
  }

  // Get eligible cast members (not queen, not eliminated)
  const { data: eligible } = await supabase
    .from('mm_game_cast')
    .select('cast_member_id')
    .eq('game_id', gameId)
    .eq('status', 'active')
    .neq('cast_member_id', queenSelection.selected_queen_id)

  if (!eligible || eligible.length < 3) {
    console.log('Not enough eligible cast members for double elimination')
    return false
  }

  // DOUBLE ELIMINATION MECHANIC:
  // 1. Queen directly eliminates 1 person (strategic power move)
  // 2. Queen nominates 2 others for house vote (creates drama)

  const shuffled = eligible.sort(() => Math.random() - 0.5)
  const queenDirectElimination = shuffled[0].cast_member_id // Queen's instant elimination
  const nomineeA = shuffled[1].cast_member_id // Up for house vote
  const nomineeB = shuffled[2].cast_member_id // Up for house vote

  // Immediately eliminate queen's choice
  const { error: eliminateError } = await supabase
    .from('mm_game_cast')
    .update({
      status: 'eliminated',
      eliminated_at: new Date().toISOString()
    })
    .eq('cast_member_id', queenDirectElimination)
    .eq('game_id', gameId)

  if (eliminateError) {
    console.error('Error eliminating cast member:', eliminateError)
    return false
  }

  console.log(`👑 Queen directly eliminated: ${queenDirectElimination}`)

  // Create voting round for house vote
  const votingOpens = new Date()
  const votingCloses = new Date()
  votingCloses.setDate(votingCloses.getDate() + 2) // 2 days to vote (Friday to Sunday)

  const { error: roundError } = await supabase
    .from('mm_voting_rounds')
    .insert({
      game_id: gameId,
      round_number: weekNumber,
      queen_id: queenSelection.selected_queen_id,
      queen_direct_elimination_id: queenDirectElimination,
      nominee_a_id: nomineeA,
      nominee_b_id: nomineeB,
      voting_opens_at: votingOpens.toISOString(),
      voting_closes_at: votingCloses.toISOString(),
      status: 'active',
      votes_for_a: 0,
      votes_for_b: 0
    })

  if (roundError) {
    console.error('Error creating voting round:', roundError)
    return false
  }

  // Update queen selection with nominees
  await supabase
    .from('mm_queen_selections')
    .update({
      nominee_a_id: nomineeA,
      nominee_b_id: nomineeB
    })
    .eq('id', queenSelection.id)

  console.log(`✅ Queen directly eliminated 1, nominated 2 for house vote`)
  return true
}

async function closeWeeklyVoting(gameId: string, weekNumber: number) {
  console.log(`🔒 Closing voting for week ${weekNumber}`)

  // Get active voting round
  const { data: round } = await supabase
    .from('mm_voting_rounds')
    .select('*')
    .eq('game_id', gameId)
    .eq('round_number', weekNumber)
    .eq('status', 'active')
    .maybeSingle()

  if (!round) {
    console.log('No active voting round to close')
    return false
  }

  // Count final votes
  const { data: votes } = await supabase
    .from('mm_elimination_votes')
    .select('voted_for_id')
    .eq('round_id', round.id)

  if (!votes) {
    console.log('No votes found for this round')
    return false
  }

  const votesForA = votes.filter(v => v.voted_for_id === round.nominee_a_id).length
  const votesForB = votes.filter(v => v.voted_for_id === round.nominee_b_id).length

  // Determine who gets eliminated (FEWER votes = eliminated)
  const eliminatedId = votesForA < votesForB ? round.nominee_a_id : round.nominee_b_id

  console.log(`📊 Final votes: A=${votesForA}, B=${votesForB}`)
  console.log(`🔻 House vote eliminates: ${eliminatedId}`)

  // Eliminate the cast member with fewer votes
  await supabase
    .from('mm_game_cast')
    .update({
      status: 'eliminated',
      eliminated_at: new Date().toISOString()
    })
    .eq('cast_member_id', eliminatedId)
    .eq('game_id', gameId)

  // Update voting round as completed
  await supabase
    .from('mm_voting_rounds')
    .update({
      status: 'completed',
      votes_for_a: votesForA,
      votes_for_b: votesForB,
      house_vote_eliminated_id: eliminatedId
    })
    .eq('id', round.id)

  console.log(`✅ Voting round closed, ${eliminatedId} eliminated by house vote`)
  return true
}

async function endGame(gameId: string) {
  console.log(`🏆 Ending game ${gameId}`)

  // Get remaining players
  const { data: remaining } = await supabase
    .from('mm_game_cast')
    .select('cast_member_id, cast_members(display_name)')
    .eq('game_id', gameId)
    .eq('status', 'active')

  if (!remaining || remaining.length === 0) {
    console.log('No remaining players')
    return false
  }

  // Winner is last remaining (or highest votes if multiple)
  const winnerId = remaining[0].cast_member_id

  const { error } = await supabase
    .from('mm_games')
    .update({
      status: 'completed',
      completed_at: new Date().toISOString()
    })
    .eq('id', gameId)

  if (error) {
    console.error('Error ending game:', error)
    return false
  }

  console.log(`✅ Game completed, winner: ${winnerId}`)
  return true
}
