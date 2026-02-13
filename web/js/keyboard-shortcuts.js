/**
 * KEYBOARD SHORTCUTS SYSTEM
 * Global keyboard shortcuts for quick navigation and actions
 */

/**
 * Keyboard shortcut configuration
 */
const SHORTCUTS = {
  // Navigation shortcuts
  'r': {
    description: 'Record voice note',
    action: () => window.location.href = '/pages/record-voice.html',
    contexts: ['*']
  },
  'v': {
    description: 'Voting page',
    action: () => {
      const gameId = new URLSearchParams(window.location.search).get('game')
      window.location.href = `/voting.html${gameId ? '?game=' + gameId : ''}`
    },
    contexts: ['*']
  },
  'a': {
    description: 'Alliances',
    action: () => {
      const gameId = new URLSearchParams(window.location.search).get('game')
      window.location.href = `/alliance-rooms.html${gameId ? '?game=' + gameId : ''}`
    },
    contexts: ['*']
  },
  'g': {
    description: 'Gallery',
    action: () => window.location.href = '/pages/gallery.html',
    contexts: ['*']
  },
  'l': {
    description: 'Leaderboard',
    action: () => {
      const gameId = new URLSearchParams(window.location.search).get('game')
      window.location.href = `/pages/leaderboard.html${gameId ? '?game=' + gameId : ''}`
    },
    contexts: ['*']
  },
  'f': {
    description: 'Voice feed',
    action: () => window.location.href = '/pages/voice-feed.html',
    contexts: ['*']
  },
  'c': {
    description: 'Cast roster',
    action: () => {
      const gameId = new URLSearchParams(window.location.search).get('game')
      window.location.href = `/pages/cast-roster.html${gameId ? '?game=' + gameId : ''}`
    },
    contexts: ['*']
  },
  'd': {
    description: 'Dashboard',
    action: () => window.location.href = '/pages/player-dashboard.html',
    contexts: ['*']
  },
  'h': {
    description: 'Home',
    action: () => window.location.href = '/index.html',
    contexts: ['*']
  },

  // Search
  '/': {
    description: 'Search',
    action: () => {
      const searchInput = document.querySelector('input[type="search"]') ||
                         document.querySelector('input[placeholder*="search" i]')
      if (searchInput) {
        searchInput.focus()
        return false // Prevent default '/' character
      }
    },
    contexts: ['*'],
    preventDefault: true
  },

  // Modal/dialog controls
  'Escape': {
    description: 'Close modal/dialog',
    action: () => {
      // Close any open modals
      const modals = document.querySelectorAll('.modal, .dialog, .dropdown.active, .user-menu-dropdown.active')
      modals.forEach(modal => {
        modal.classList.remove('active')
        modal.style.display = 'none'
      })

      // Close phase transition if present
      const phaseTransition = document.getElementById('phaseTransitionModal')
      if (phaseTransition) {
        phaseTransition.remove()
      }
    },
    contexts: ['*']
  },

  // Help
  '?': {
    description: 'Show keyboard shortcuts',
    action: () => showShortcutsHelp(),
    contexts: ['*'],
    preventDefault: true
  },

  // Playback controls (when audio is focused)
  ' ': {
    description: 'Play/pause audio',
    action: () => {
      const activeAudio = document.querySelector('audio:not([paused])')
      if (activeAudio) {
        if (activeAudio.paused) {
          activeAudio.play()
        } else {
          activeAudio.pause()
        }
        return false
      }
    },
    contexts: ['*'],
    preventDefault: true
  },

  // Quick actions
  'n': {
    description: 'Notifications',
    action: () => window.location.href = '/pages/notifications.html',
    contexts: ['*']
  },

  's': {
    description: 'Settings',
    action: () => window.location.href = '/pages/settings.html',
    contexts: ['*']
  }
}

/**
 * Initialize keyboard shortcuts
 */
export function initKeyboardShortcuts(options = {}) {
  const {
    enabled = true,
    context = '*',
    customShortcuts = {}
  } = options

  if (!enabled) return

  // Merge custom shortcuts
  const allShortcuts = { ...SHORTCUTS, ...customShortcuts }

  // Add event listener
  document.addEventListener('keydown', (event) => {
    handleKeyPress(event, allShortcuts, context)
  })

  // Show toast on first visit
  const hasSeenShortcuts = localStorage.getItem('hasSeenKeyboardShortcuts')
  if (!hasSeenShortcuts) {
    setTimeout(() => {
      showShortcutsToast()
      localStorage.setItem('hasSeenKeyboardShortcuts', 'true')
    }, 3000)
  }
}

/**
 * Handle key press events
 */
function handleKeyPress(event, shortcuts, context) {
  // Don't trigger shortcuts when typing in inputs
  if (isTypingContext(event.target)) {
    // Exception for Escape key
    if (event.key !== 'Escape') {
      return
    }
  }

  const key = event.key
  const shortcut = shortcuts[key]

  if (!shortcut) return

  // Check if shortcut applies to current context
  if (!shortcut.contexts.includes('*') && !shortcut.contexts.includes(context)) {
    return
  }

  // Prevent default if specified
  if (shortcut.preventDefault) {
    event.preventDefault()
  }

  // Execute action
  try {
    const result = shortcut.action(event)
    if (result === false) {
      event.preventDefault()
    }
  } catch (error) {
    console.error('Error executing shortcut:', error)
  }
}

/**
 * Check if user is typing in an input field
 */
function isTypingContext(element) {
  if (!element) return false

  const tagName = element.tagName.toLowerCase()
  const isInput = tagName === 'input' || tagName === 'textarea'
  const isContentEditable = element.isContentEditable

  return isInput || isContentEditable
}

/**
 * Show keyboard shortcuts help modal
 */
function showShortcutsHelp() {
  // Check if modal already exists
  let modal = document.getElementById('keyboardShortcutsModal')

  if (modal) {
    modal.style.display = 'flex'
    return
  }

  // Create modal
  modal = document.createElement('div')
  modal.id = 'keyboardShortcutsModal'
  modal.className = 'keyboard-shortcuts-modal'
  modal.style.cssText = `
    position: fixed;
    inset: 0;
    z-index: 10000;
    background: rgba(0, 0, 0, 0.9);
    display: flex;
    align-items: center;
    justify-content: center;
    backdrop-filter: blur(10px);
  `

  // Build shortcuts list
  const shortcutsList = Object.entries(SHORTCUTS)
    .filter(([key, config]) => config.description) // Only show documented shortcuts
    .map(([key, config]) => {
      const displayKey = key === ' ' ? 'Space' : key === 'Escape' ? 'Esc' : key.toUpperCase()
      return `
        <div class="shortcut-row">
          <kbd class="shortcut-key">${displayKey}</kbd>
          <span class="shortcut-description">${config.description}</span>
        </div>
      `
    })
    .join('')

  modal.innerHTML = `
    <div class="shortcuts-content" style="
      background: #111;
      border: 2px solid rgba(212, 175, 55, 0.3);
      border-radius: 24px;
      padding: 3rem;
      max-width: 600px;
      width: 90%;
      max-height: 80vh;
      overflow-y: auto;
    ">
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 2rem;">
        <h2 style="color: #d4af37; font-size: 28px; margin: 0;">⌨️ Keyboard Shortcuts</h2>
        <button onclick="this.closest('.keyboard-shortcuts-modal').remove()" style="
          background: transparent;
          border: none;
          color: white;
          font-size: 28px;
          cursor: pointer;
          padding: 0;
          width: 40px;
          height: 40px;
          display: flex;
          align-items: center;
          justify-content: center;
        ">×</button>
      </div>

      <div class="shortcuts-list" style="display: flex; flex-direction: column; gap: 1rem;">
        ${shortcutsList}
      </div>

      <p style="color: rgba(255, 255, 255, 0.5); margin-top: 2rem; font-size: 14px; text-align: center;">
        Press <kbd style="background: rgba(255,255,255,0.1); padding: 4px 8px; border-radius: 4px;">?</kbd> anytime to show this help
      </p>
    </div>

    <style>
      .shortcut-row {
        display: flex;
        align-items: center;
        gap: 1rem;
        padding: 0.75rem 1rem;
        background: rgba(255, 255, 255, 0.03);
        border-radius: 12px;
        transition: background 0.2s;
      }

      .shortcut-row:hover {
        background: rgba(212, 175, 55, 0.1);
      }

      .shortcut-key {
        background: rgba(212, 175, 55, 0.2);
        color: #d4af37;
        padding: 6px 12px;
        border-radius: 8px;
        font-weight: 700;
        font-family: 'Courier New', monospace;
        font-size: 16px;
        min-width: 40px;
        text-align: center;
        border: 2px solid rgba(212, 175, 55, 0.3);
      }

      .shortcut-description {
        color: rgba(255, 255, 255, 0.9);
        font-size: 15px;
      }
    </style>
  `

  document.body.appendChild(modal)

  // Close on click outside
  modal.addEventListener('click', (e) => {
    if (e.target === modal) {
      modal.remove()
    }
  })

  // Close on Escape
  const escapeHandler = (e) => {
    if (e.key === 'Escape') {
      modal.remove()
      document.removeEventListener('keydown', escapeHandler)
    }
  }
  document.addEventListener('keydown', escapeHandler)
}

/**
 * Show shortcuts toast notification
 */
function showShortcutsToast() {
  const toast = document.createElement('div')
  toast.className = 'keyboard-shortcuts-toast'
  toast.style.cssText = `
    position: fixed;
    bottom: 20px;
    right: 20px;
    background: linear-gradient(135deg, rgba(212, 175, 55, 0.95), rgba(255, 215, 0, 0.95));
    color: #000;
    padding: 1rem 1.5rem;
    border-radius: 16px;
    box-shadow: 0 8px 32px rgba(212, 175, 55, 0.4);
    z-index: 9999;
    display: flex;
    align-items: center;
    gap: 1rem;
    font-weight: 600;
    animation: slideInUp 0.5s ease, fadeOut 0.5s ease 4.5s;
  `

  toast.innerHTML = `
    <span style="font-size: 24px;">⌨️</span>
    <div>
      <div style="font-weight: 700;">Keyboard shortcuts available!</div>
      <div style="font-size: 13px; opacity: 0.8;">Press <strong>?</strong> to view all shortcuts</div>
    </div>
  `

  // Add animations
  const style = document.createElement('style')
  style.textContent = `
    @keyframes slideInUp {
      from {
        transform: translateY(100px);
        opacity: 0;
      }
      to {
        transform: translateY(0);
        opacity: 1;
      }
    }

    @keyframes fadeOut {
      to {
        opacity: 0;
        transform: translateY(20px);
      }
    }
  `
  document.head.appendChild(style)

  document.body.appendChild(toast)

  // Remove after 5 seconds
  setTimeout(() => {
    toast.remove()
  }, 5000)
}

/**
 * Add custom shortcut at runtime
 */
export function addShortcut(key, config) {
  SHORTCUTS[key] = {
    description: config.description || '',
    action: config.action,
    contexts: config.contexts || ['*'],
    preventDefault: config.preventDefault || false
  }
}

/**
 * Remove shortcut
 */
export function removeShortcut(key) {
  delete SHORTCUTS[key]
}

/**
 * Get all registered shortcuts
 */
export function getShortcuts() {
  return { ...SHORTCUTS }
}

/**
 * Enable/disable shortcuts
 */
let shortcutsEnabled = true

export function enableShortcuts() {
  shortcutsEnabled = true
}

export function disableShortcuts() {
  shortcutsEnabled = false
}

export function toggleShortcuts() {
  shortcutsEnabled = !shortcutsEnabled
  return shortcutsEnabled
}

// Export for global access
window.keyboardShortcuts = {
  init: initKeyboardShortcuts,
  add: addShortcut,
  remove: removeShortcut,
  getAll: getShortcuts,
  enable: enableShortcuts,
  disable: disableShortcuts,
  toggle: toggleShortcuts,
  showHelp: showShortcutsHelp
}

// Auto-initialize on load
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => initKeyboardShortcuts())
} else {
  initKeyboardShortcuts()
}
