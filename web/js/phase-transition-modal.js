/**
 * PHASE TRANSITION MODAL
 * Displays dramatic animations when game phases change
 */

import { supabaseClient as supabase } from './supabase-module.js'

/**
 * Phase transition configuration
 */
const PHASE_CONFIG = {
  'lobby-to-introductions': {
    icon: '🚪',
    title: 'Cast Introductions',
    description: 'Time to introduce yourself to the mansion...',
    cssClass: 'phase-transition-lobby-to-scenarios',
    duration: 5000,
    sound: '/sounds/door-open.mp3'
  },
  'introductions-to-scenarios': {
    icon: '🎭',
    title: 'The Mansion Doors Are Opening',
    description: 'Let the drama begin!',
    cssClass: 'phase-transition-lobby-to-scenarios',
    duration: 5000,
    sound: '/sounds/door-creak.mp3'
  },
  'scenarios-to-episodes': {
    icon: '🎬',
    title: 'Episode 1 Begins',
    description: 'Your responses are being compiled into the first episode...',
    cssClass: 'phase-transition-scenarios-to-episodes',
    duration: 6000,
    sound: '/sounds/spotlight.mp3'
  },
  'episodes-to-voting': {
    icon: '🗳️',
    title: 'Time to Vote',
    description: 'Cast your vote to eliminate a housemate',
    cssClass: 'phase-transition-voting',
    duration: 5000,
    sound: '/sounds/dramatic-sting.mp3'
  },
  'voting-to-results': {
    icon: '📊',
    title: 'The Results Are In',
    description: 'Someone is leaving the mansion tonight...',
    cssClass: 'phase-transition-results',
    duration: 6000,
    sound: '/sounds/suspense.mp3'
  },
  'game-completed': {
    icon: '🏆',
    title: 'Game Over',
    description: 'The winner has been crowned!',
    cssClass: 'phase-transition-completed',
    duration: 8000,
    sound: '/sounds/victory.mp3'
  }
}

/**
 * Show phase transition modal
 * @param {string} transitionKey - Key from PHASE_CONFIG
 * @param {Object} options - Additional options
 * @returns {Promise<void>}
 */
export async function showPhaseTransition(transitionKey, options = {}) {
  const config = PHASE_CONFIG[transitionKey]
  if (!config) {
    console.warn(`Unknown transition: ${transitionKey}`)
    return
  }

  const {
    customTitle = config.title,
    customDescription = config.description,
    customIcon = config.icon,
    countdown = null,
    onComplete = null,
    skipSound = false
  } = options

  // Check if user has reduced motion preference
  const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches

  // Create modal HTML
  const modalHtml = `
    <div class="phase-transition-modal ${config.cssClass}" id="phaseTransitionModal">
      <div class="phase-animation"></div>
      <div class="phase-transition-content">
        <div class="phase-icon">${customIcon}</div>
        <h1 class="phase-title">${customTitle}</h1>
        <p class="phase-description">${customDescription}</p>
        ${countdown ? `<div class="phase-countdown" id="phaseCountdown">${countdown}</div>` : ''}
        <div class="phase-progress-bar">
          <div class="phase-progress-fill" style="animation-duration: ${config.duration}ms;"></div>
        </div>
      </div>
    </div>
  `

  // Inject modal into page
  const modalContainer = document.createElement('div')
  modalContainer.innerHTML = modalHtml
  document.body.appendChild(modalContainer)

  // Play sound effect if not skipped and not reduced motion
  if (!skipSound && !prefersReducedMotion) {
    try {
      const audio = new Audio(config.sound)
      audio.volume = 0.5
      audio.play().catch(err => console.log('Audio playback prevented:', err))
    } catch (err) {
      console.log('Audio not available:', err)
    }
  }

  // Handle countdown timer
  let countdownInterval
  if (countdown) {
    const countdownEl = document.getElementById('phaseCountdown')
    let secondsLeft = parseInt(countdown)

    countdownInterval = setInterval(() => {
      secondsLeft--
      if (countdownEl) {
        countdownEl.textContent = secondsLeft
      }
      if (secondsLeft <= 0) {
        clearInterval(countdownInterval)
      }
    }, 1000)
  }

  // Auto-remove modal after duration
  return new Promise((resolve) => {
    setTimeout(() => {
      if (countdownInterval) {
        clearInterval(countdownInterval)
      }

      const modal = document.getElementById('phaseTransitionModal')
      if (modal) {
        modal.style.animation = 'fadeOut 0.5s ease'
        setTimeout(() => {
          modalContainer.remove()
          if (onComplete) {
            onComplete()
          }
          resolve()
        }, 500)
      } else {
        resolve()
      }
    }, config.duration)
  })
}

/**
 * Show custom phase transition with override options
 */
export function showCustomTransition(options) {
  const {
    icon = '✨',
    title = 'Phase Transition',
    description = '',
    duration = 5000,
    cssClass = '',
    countdown = null,
    sound = null,
    onComplete = null
  } = options

  const modalHtml = `
    <div class="phase-transition-modal ${cssClass}" id="phaseTransitionModal">
      <div class="phase-animation"></div>
      <div class="phase-transition-content">
        <div class="phase-icon">${icon}</div>
        <h1 class="phase-title">${title}</h1>
        <p class="phase-description">${description}</p>
        ${countdown ? `<div class="phase-countdown" id="phaseCountdown">${countdown}</div>` : ''}
        <div class="phase-progress-bar">
          <div class="phase-progress-fill" style="animation-duration: ${duration}ms;"></div>
        </div>
      </div>
    </div>
  `

  const modalContainer = document.createElement('div')
  modalContainer.innerHTML = modalHtml
  document.body.appendChild(modalContainer)

  if (sound) {
    try {
      const audio = new Audio(sound)
      audio.volume = 0.5
      audio.play().catch(err => console.log('Audio playback prevented:', err))
    } catch (err) {
      console.log('Audio not available:', err)
    }
  }

  let countdownInterval
  if (countdown) {
    const countdownEl = document.getElementById('phaseCountdown')
    let secondsLeft = parseInt(countdown)

    countdownInterval = setInterval(() => {
      secondsLeft--
      if (countdownEl) {
        countdownEl.textContent = secondsLeft
      }
      if (secondsLeft <= 0) {
        clearInterval(countdownInterval)
      }
    }, 1000)
  }

  return new Promise((resolve) => {
    setTimeout(() => {
      if (countdownInterval) {
        clearInterval(countdownInterval)
      }

      const modal = document.getElementById('phaseTransitionModal')
      if (modal) {
        modal.style.animation = 'fadeOut 0.5s ease'
        setTimeout(() => {
          modalContainer.remove()
          if (onComplete) {
            onComplete()
          }
          resolve()
        }, 500)
      } else {
        resolve()
      }
    }, duration)
  })
}

/**
 * Subscribe to phase changes for a game and show transitions
 * @param {string} gameId - Game UUID
 */
export function subscribeToPhaseTransitions(gameId) {
  const subscription = supabase
    .channel(`game-${gameId}-phase-transitions`)
    .on('postgres_changes', {
      event: 'UPDATE',
      schema: 'public',
      table: 'mm_game_stages',
      filter: `game_id=eq.${gameId}`
    }, async (payload) => {
      const oldStage = payload.old.current_stage
      const newStage = payload.new.current_stage

      // Determine transition key
      let transitionKey = `${oldStage}-to-${newStage}`

      // Handle special cases
      if (newStage === 'completed') {
        transitionKey = 'game-completed'
      }

      // Show transition
      await showPhaseTransition(transitionKey, {
        onComplete: () => {
          // Reload page to new phase
          window.location.reload()
        }
      })
    })
    .subscribe()

  return {
    unsubscribe: () => subscription.unsubscribe()
  }
}

/**
 * Test transition (for debugging)
 */
export function testTransition(transitionKey) {
  showPhaseTransition(transitionKey, {
    countdown: 5,
    onComplete: () => {
      console.log('Transition complete')
    }
  })
}

// Export for global access
window.phaseTransitionModule = {
  showPhaseTransition,
  showCustomTransition,
  subscribeToPhaseTransitions,
  testTransition
}
