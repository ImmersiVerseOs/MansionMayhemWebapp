/**
 * GAME CONTEXT UTILITY
 * Manages game state consistently across all pages
 * Ensures user always sees data for THEIR current game only
 */

class GameContext {
  constructor() {
    this.gameId = null
    this.castMemberId = null
    this.initialized = false
  }

  /**
   * Wait for Supabase client to be initialized
   */
  async waitForSupabase() {
    let attempts = 0
    while (!window.supabaseClient && attempts < 50) {
      await new Promise(resolve => setTimeout(resolve, 100))
      attempts++
    }
    if (!window.supabaseClient) {
      throw new Error('Supabase client not initialized after 5 seconds')
    }
  }

  /**
   * Initialize game context from URL or localStorage
   * Call this at the top of every page
   */
  async init() {
    // Wait for Supabase to be ready first
    await this.waitForSupabase()

    // Migrate old localStorage key to new key
    const oldGameId = localStorage.getItem('currentGameId')
    if (oldGameId && !localStorage.getItem('current_game_id')) {
      localStorage.setItem('current_game_id', oldGameId)
      console.log('🔄 Migrated currentGameId to current_game_id')
    }

    // Try URL first (highest priority)
    const urlParams = new URLSearchParams(window.location.search)
    const urlGameId = urlParams.get('game') || urlParams.get('gameId')

    if (urlGameId) {
      this.gameId = urlGameId
      localStorage.setItem('current_game_id', urlGameId)
      console.log('🎮 Game context from URL:', urlGameId)
    } else {
      // Fallback to localStorage
      this.gameId = localStorage.getItem('current_game_id')
      console.log('🎮 Game context from localStorage:', this.gameId)
    }

    // Get current cast member (through mm_game_cast junction table)
    const user = await window.supabaseClient.auth.getUser()
    if (user.data.user && this.gameId) {
      // First get user's cast member ID
      const { data: castMember } = await window.supabaseClient
        .from('cast_members')
        .select('id')
        .eq('user_id', user.data.user.id)
        .maybeSingle()

      if (castMember) {
        // Then check if that cast member is in this game
        const { data: gameCast } = await window.supabaseClient
          .from('mm_game_cast')
          .select(`
            cast_member_id,
            status,
            cast_members (
              id,
              display_name,
              user_id
            )
          `)
          .eq('game_id', this.gameId)
          .eq('cast_member_id', castMember.id)
          .eq('status', 'active')
          .maybeSingle()

        if (gameCast && gameCast.cast_members) {
          this.castMemberId = gameCast.cast_members.id
          localStorage.setItem('current_cast_member_id', gameCast.cast_members.id)
          console.log('👤 Cast member:', gameCast.cast_members.display_name)
        }
      }
    }

    this.initialized = true
    return this.gameId
  }

  /**
   * Check if game context exists, redirect to lobby browser if not
   */
  requireGame() {
    if (!this.gameId) {
      console.warn('⚠️ No game context! Redirecting to lobby browser...')
      window.location.href = '/pages/lobby-browser.html'
      return false
    }
    return true
  }

  /**
   * Get current game ID
   */
  getGameId() {
    return this.gameId
  }

  /**
   * Get current cast member ID
   */
  getCastMemberId() {
    return this.castMemberId
  }

  /**
   * Update navigation links to include game parameter
   */
  updateNavigation() {
    if (!this.gameId) return

    const links = document.querySelectorAll('a[href]:not([href^="http"]):not([href^="#"])')
    links.forEach(link => {
      const href = link.getAttribute('href')

      // Skip if already has game param
      if (href.includes('?game=') || href.includes('&game=')) return

      // Add game param
      const separator = href.includes('?') ? '&' : '?'
      link.setAttribute('href', `${href}${separator}game=${this.gameId}`)
    })

    console.log(`🔗 Updated ${links.length} navigation links with game context`)
  }

  /**
   * Query builder that automatically filters by game_id
   */
  query(table) {
    if (!window.supabaseClient) {
      throw new Error('Supabase client not initialized')
    }

    const query = window.supabaseClient.from(table)

    // Return a wrapped query that auto-filters by game_id
    return {
      select: (columns = '*') => {
        const selectQuery = query.select(columns)

        // Auto-add game_id filter if this table has game_id column
        const tablesWithGameId = [
          'mm_games',
          'mm_game_cast',
          'mm_alliance_rooms',
          'mm_alliance_messages',
          'mm_link_up_requests',
          'mm_link_up_responses',
          'scenarios',
          'scenario_responses',
          'mm_tea_room_posts',
          'mm_voting_rounds',
          'mm_relationship_edges'
        ]

        if (tablesWithGameId.includes(table) && this.gameId) {
          return selectQuery.eq('game_id', this.gameId)
        }

        return selectQuery
      }
    }
  }

  /**
   * Get game info
   */
  async getGame() {
    if (!this.gameId) return null

    const { data, error } = await window.supabaseClient
      .from('mm_games')
      .select('*')
      .eq('id', this.gameId)
      .maybeSingle()

    if (error) {
      console.error('Error loading game:', error)
      return null
    }

    return data
  }

  /**
   * Get cast members in current game only
   */
  async getCastMembers() {
    if (!this.gameId) return []

    const { data, error } = await window.supabaseClient
      .from('mm_game_cast')
      .select(`
        cast_member_id,
        status,
        cast_members (
          id,
          display_name,
          full_name,
          avatar_url,
          archetype,
          is_ai_player
        )
      `)
      .eq('game_id', this.gameId)
      .eq('status', 'active')

    if (error) {
      console.error('Error loading cast members:', error)
      return []
    }

    return data.map(gc => ({
      id: gc.cast_members.id,
      display_name: gc.cast_members.display_name,
      full_name: gc.cast_members.full_name,
      avatar_url: gc.cast_members.avatar_url,
      archetype: gc.cast_members.archetype,
      is_ai_player: gc.cast_members.is_ai_player
    }))
  }

  /**
   * Show warning banner if game context is missing
   */
  showWarningBanner() {
    // Don't auto-redirect — let the page handle no-game state gracefully
    // Dashboard can work without a game (user can create/join from there)
    const isDashboard = window.location.pathname.includes('player-dashboard')
    if (isDashboard) {
      console.log('📋 No active game — dashboard will show create/join options')
      return
    }

    const banner = document.createElement('div')
    banner.style.cssText = `
      position: fixed;
      top: 0;
      left: 0;
      right: 0;
      background: linear-gradient(135deg, #D32F2F, #FF6D00);
      color: white;
      padding: 1rem;
      text-align: center;
      z-index: 10000;
      font-weight: 600;
      box-shadow: 0 4px 12px rgba(0,0,0,0.3);
    `
    banner.innerHTML = `
      ⚠️ No game selected! <a href="/pages/player-dashboard.html" style="color: white; text-decoration: underline; margin-left: 1rem;">Go to Dashboard</a>
    `
    document.body.prepend(banner)

    setTimeout(() => {
      window.location.href = '/pages/player-dashboard.html'
    }, 3000)
  }
}

// Create global instance
window.gameContext = new GameContext()

// Auto-initialize when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', async () => {
    await window.gameContext.init()
    if (!window.gameContext.getGameId()) {
      window.gameContext.showWarningBanner()
    } else {
      window.gameContext.updateNavigation()
    }
  })
} else {
  window.gameContext.init().then(() => {
    if (!window.gameContext.getGameId()) {
      window.gameContext.showWarningBanner()
    } else {
      window.gameContext.updateNavigation()
    }
  })
}

console.log('✅ Game Context utility loaded')
