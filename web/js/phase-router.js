/**
 * Phase-Based Routing System for Mansion Mayhem
 *
 * Automatically routes users to the correct page based on:
 * - Current game phase/stage
 * - User role (player, director, admin)
 * - Game status
 */

import { supabaseClient as supabase } from './supabase-module.js'
import { showPhaseTransition as showTransitionModal } from './phase-transition-modal.js'

/**
 * Route user to appropriate page based on game phase
 * @param {string} gameId - The game ID
 * @param {boolean} redirect - Whether to redirect immediately (default: true)
 * @returns {Promise<string>} The target URL
 */
export async function routeToGamePhase(gameId, redirect = true) {
  try {
    // Get current user
    const { data: { user }, error: userError } = await supabase.auth.getUser()
    if (userError || !user) {
      if (redirect) window.location.href = '/pages/sign-in.html'
      return '/pages/sign-in.html'
    }

    // Get game with stage info
    const { data: game, error: gameError } = await supabase
      .from('mm_games')
      .select('*, mm_game_stages(*)')
      .eq('id', gameId)
      .maybeSingle()

    if (gameError) {
      console.error('Error loading game:', gameError)
      if (redirect) window.location.href = '/pages/player-dashboard.html'
      return '/pages/player-dashboard.html'
    }

    // Get user's role in this game
    const role = await getUserRole(gameId, user.id)

    // Directors and admins always go to director console
    if (role === 'director' || role === 'admin') {
      const url = `/director-console.html?game=${gameId}`
      if (redirect) window.location.href = url
      return url
    }

    // Route cast members based on game stage
    const currentStage = game.mm_game_stages?.current_stage || 'lobby'
    const url = getUrlForStage(currentStage, gameId, game.status)

    if (redirect) window.location.href = url
    return url

  } catch (error) {
    console.error('Error in phase routing:', error)
    const fallback = '/pages/player-dashboard.html'
    if (redirect) window.location.href = fallback
    return fallback
  }
}

/**
 * Get user's role in a specific game
 * @param {string} gameId - The game ID
 * @param {string} userId - The user ID
 * @returns {Promise<string>} Role: 'director', 'admin', 'cast', or 'viewer'
 */
export async function getUserRole(gameId, userId) {
  try {
    // Check if admin
    const { data: adminCheck } = await supabase
      .from('admin_users')
      .select('user_id')
      .eq('user_id', userId)
      .single()

    if (adminCheck) return 'admin'

    // Check if director
    const { data: game } = await supabase
      .from('mm_games')
      .select('director_user_id')
      .eq('id', gameId)
      .single()

    if (game && game.director_user_id === userId) return 'director'

    // Check if cast member
    const { data: castMember } = await supabase
      .from('cast_members')
      .select('id')
      .eq('game_id', gameId)
      .eq('user_id', userId)
      .single()

    if (castMember) return 'cast'

    return 'viewer'

  } catch (error) {
    console.error('Error getting user role:', error)
    return 'viewer'
  }
}

/**
 * Get the appropriate URL for a game stage
 * @param {string} stage - Current game stage
 * @param {string} gameId - The game ID
 * @param {string} gameStatus - Game status
 * @returns {string} Target URL
 */
function getUrlForStage(stage, gameId, gameStatus) {
  // Game completed - show results
  if (gameStatus === 'completed') {
    return `/pages/results.html?game=${gameId}`
  }

  // Route based on stage
  switch (stage) {
    case 'lobby':
    case 'pre_game':
      return `/lobby-dashboard.html?game=${gameId}`

    case 'introductions':
      return `/voice-introduction.html?game=${gameId}`

    case 'scenarios':
    case 'active':
      return `/pages/player-dashboard.html?game=${gameId}`

    case 'voting':
      return `/voting.html?game=${gameId}`

    case 'final_three':
      // Final 3 week - still uses voting but only 1 nominee
      return `/voting.html?game=${gameId}`

    case 'finale':
      // Finale - fan voting page
      return `/pages/finale-fan-vote.html?game=${gameId}`

    case 'episodes':
    case 'episode_viewing':
      return `/pages/gallery.html?game=${gameId}`

    case 'results':
      return `/pages/results.html?game=${gameId}`

    case 'paused':
    case 'maintenance':
      return `/pages/player-dashboard.html?message=game_paused`

    default:
      // Default to cast portal for unknown stages
      return `/pages/player-dashboard.html?game=${gameId}`
  }
}

/**
 * Check if user has access to a specific page in current game context
 * @param {string} pageType - Type of page: 'voting', 'results', 'scenarios', etc.
 * @param {string} gameId - The game ID
 * @returns {Promise<boolean>} Whether user has access
 */
export async function hasAccessToPage(pageType, gameId) {
  try {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return false

    const role = await getUserRole(gameId, user.id)

    // Admins and directors have access to everything
    if (role === 'admin' || role === 'director') return true

    // Cast members need to check game stage
    if (role === 'cast') {
      const { data: game } = await supabase
        .from('mm_games')
        .select('*, mm_game_stages(*)')
        .eq('id', gameId)
        .single()

      if (!game) return false

      const currentStage = game.mm_game_stages?.current_stage

      // Map page types to allowed stages
      const stageAccess = {
        'voting': ['voting', 'final_three'],
        'finale': ['finale'],
        'results': ['results', 'completed'],
        'scenarios': ['scenarios', 'active'],
        'gallery': ['episodes', 'episode_viewing', 'completed'],
        'leaderboard': ['scenarios', 'active', 'episodes', 'voting', 'final_three', 'finale', 'results', 'completed'],
        'cast-portal': ['scenarios', 'active', 'episodes', 'voting', 'final_three', 'finale', 'results']
      }

      const allowedStages = stageAccess[pageType] || []
      return allowedStages.includes(currentStage) || game.status === 'completed'
    }

    return false

  } catch (error) {
    console.error('Error checking page access:', error)
    return false
  }
}

/**
 * Initialize phase-aware routing on page load
 * - Checks if user should be on current page
 * - Redirects if they're in the wrong place
 * @param {string} expectedPage - Expected page type
 * @param {string} gameId - The game ID (optional)
 */
export async function initPhaseAwareRouting(expectedPage, gameId = null) {
  try {
    // Get game ID from URL if not provided
    if (!gameId) {
      const urlParams = new URLSearchParams(window.location.search)
      gameId = urlParams.get('game')
    }

    // If no game context, skip routing
    if (!gameId) return

    // Check if user has access to current page
    const hasAccess = await hasAccessToPage(expectedPage, gameId)

    if (!hasAccess) {
      console.log(`User doesn't have access to ${expectedPage}, routing to correct phase`)
      await routeToGamePhase(gameId, true)
    }

  } catch (error) {
    console.error('Error in phase-aware routing:', error)
  }
}

/**
 * Get current game phase information
 * @param {string} gameId - The game ID
 * @returns {Promise<Object>} Phase info object
 */
export async function getCurrentPhaseInfo(gameId) {
  try {
    const { data: game, error } = await supabase
      .from('mm_games')
      .select('*, mm_game_stages(*)')
      .eq('id', gameId)
      .single()

    if (error) throw error

    const stage = game.mm_game_stages?.current_stage || 'lobby'
    const stageData = game.mm_game_stages

    return {
      stage,
      status: game.status,
      stageStartedAt: stageData?.stage_started_at,
      stageEndsAt: stageData?.stage_ends_at,
      isTimeLimited: !!stageData?.stage_ends_at,
      timeRemaining: stageData?.stage_ends_at ?
        new Date(stageData.stage_ends_at) - new Date() : null,
      phaseLabel: getPhaseLabel(stage),
      phaseDescription: getPhaseDescription(stage)
    }

  } catch (error) {
    console.error('Error getting phase info:', error)
    return null
  }
}

/**
 * Get human-readable label for a phase
 * @param {string} stage - Stage identifier
 * @returns {string} Display label
 */
function getPhaseLabel(stage) {
  const labels = {
    'lobby': 'Pre-Game Lobby',
    'pre_game': 'Preparing to Start',
    'introductions': 'Voice Introductions',
    'scenarios': 'Active Scenarios',
    'active': 'Game in Progress',
    'voting': 'Elimination Voting',
    'final_three': 'Final Three',
    'finale': 'Finale Fan Vote',
    'episodes': 'Episode Viewing',
    'episode_viewing': 'Watching Episodes',
    'results': 'Episode Results',
    'paused': 'Game Paused',
    'completed': 'Game Completed'
  }
  return labels[stage] || stage
}

/**
 * Get description for a phase
 * @param {string} stage - Stage identifier
 * @returns {string} Description
 */
function getPhaseDescription(stage) {
  const descriptions = {
    'lobby': 'Waiting for all players to join',
    'pre_game': 'Getting ready to begin',
    'introductions': 'Record your voice introduction',
    'scenarios': 'Respond to dramatic scenarios',
    'active': 'Drama is unfolding',
    'voting': 'Vote to eliminate a cast member',
    'final_three': 'Queen eliminates 1 cast member',
    'finale': 'Vote for your winner!',
    'episodes': 'Watch the episode compilation',
    'episode_viewing': 'View completed episodes',
    'results': 'See who was eliminated',
    'paused': 'Game temporarily paused',
    'completed': 'Game has concluded'
  }
  return descriptions[stage] || ''
}

/**
 * Subscribe to game phase changes with automatic transition display
 * @param {string} gameId - The game ID
 * @param {Function} callback - Optional callback function (phase, oldPhase) => {}
 * @param {boolean} showTransitions - Whether to show transition modals (default: true)
 * @returns {Object} Subscription object with unsubscribe method
 */
export function subscribeToPhaseChanges(gameId, callback = null, showTransitions = true) {
  let currentPhase = null

  const subscription = supabase
    .channel(`game-${gameId}-phases`)
    .on('postgres_changes', {
      event: 'UPDATE',
      schema: 'public',
      table: 'mm_game_stages',
      filter: `game_id=eq.${gameId}`
    }, async (payload) => {
      const newPhase = payload.new.current_stage
      const oldPhase = currentPhase

      if (newPhase !== oldPhase) {
        currentPhase = newPhase

        // Show transition modal if enabled
        if (showTransitions) {
          await showPhaseTransition(newPhase, oldPhase, gameId)
        }

        // Call custom callback if provided
        if (callback) {
          callback(newPhase, oldPhase)
        }
      }
    })
    .subscribe()

  // Load initial phase
  getCurrentPhaseInfo(gameId).then(info => {
    if (info) {
      currentPhase = info.stage
    }
  })

  return {
    unsubscribe: () => subscription.unsubscribe()
  }
}

/**
 * Show phase transition modal with animation
 * @param {string} newPhase - The new phase
 * @param {string} oldPhase - The previous phase
 * @param {string} gameId - The game ID
 */
export async function showPhaseTransition(newPhase, oldPhase, gameId) {
  // Determine transition key
  let transitionKey = `${oldPhase}-to-${newPhase}`

  // Handle special cases
  if (newPhase === 'completed') {
    transitionKey = 'game-completed'
  } else if (!oldPhase || oldPhase === 'lobby') {
    if (newPhase === 'introductions') {
      transitionKey = 'lobby-to-introductions'
    } else if (newPhase === 'scenarios' || newPhase === 'active') {
      transitionKey = 'lobby-to-scenarios'
    }
  } else if ((oldPhase === 'scenarios' || oldPhase === 'active') && newPhase === 'episodes') {
    transitionKey = 'scenarios-to-episodes'
  } else if (newPhase === 'voting') {
    transitionKey = 'episodes-to-voting'
  } else if (newPhase === 'results') {
    transitionKey = 'voting-to-results'
  }

  // Show transition with routing callback
  await showTransitionModal(transitionKey, {
    customTitle: getPhaseLabel(newPhase),
    customDescription: getPhaseDescription(newPhase),
    customIcon: getPhaseIcon(newPhase),
    onComplete: () => {
      // Route to new phase after transition
      routeToGamePhase(gameId, true)
    }
  })
}

/**
 * Get icon for a phase
 * @param {string} stage - Stage identifier
 * @returns {string} Emoji icon
 */
function getPhaseIcon(stage) {
  const icons = {
    'lobby': '🏰',
    'introductions': '🎙️',
    'scenarios': '📝',
    'voting': '🗳️',
    'final_three': '🔥',
    'finale': '👑',
    'episodes': '🎬',
    'results': '📊',
    'completed': '✨'
  }
  return icons[stage] || '🎭'
}

// Export all functions
export default {
  routeToGamePhase,
  getUserRole,
  hasAccessToPage,
  initPhaseAwareRouting,
  getCurrentPhaseInfo,
  subscribeToPhaseChanges,
  showPhaseTransition
}
