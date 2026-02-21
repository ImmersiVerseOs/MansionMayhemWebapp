/**
 * ACHIEVEMENTS SYSTEM
 * Client-side achievement tracking and display
 */

import { supabaseClient as supabase } from './supabase-module.js'

/**
 * Achievement categories with display colors
 */
const CATEGORY_COLORS = {
  'participation': '#4CAF50',
  'drama': '#E91E63',
  'social': '#2196F3',
  'strategic': '#9C27B0',
  'content': '#FF9800',
  'special': '#FFD700'
}

/**
 * Rarity colors
 */
const RARITY_COLORS = {
  'common': '#9E9E9E',
  'uncommon': '#4CAF50',
  'rare': '#2196F3',
  'epic': '#9C27B0',
  'legendary': '#FFD700'
}

/**
 * Check and unlock an achievement
 * @param {string} castMemberId - Cast member UUID
 * @param {string} achievementKey - Achievement key identifier
 * @param {string} gameId - Game UUID
 * @param {Object} progressData - Optional progress data
 * @returns {Promise<boolean>} True if newly unlocked
 */
export async function unlockAchievement(castMemberId, achievementKey, gameId, progressData = {}) {
  try {
    const { data, error } = await supabase.rpc('check_and_unlock_achievement', {
      p_cast_member_id: castMemberId,
      p_achievement_key: achievementKey,
      p_game_id: gameId,
      p_progress_data: progressData
    })

    if (error) throw error

    // If newly unlocked, show notification
    if (data) {
      await showAchievementUnlock(achievementKey)
    }

    return data

  } catch (error) {
    console.error('Error unlocking achievement:', error)
    return false
  }
}

/**
 * Update achievement progress
 * @param {string} castMemberId - Cast member UUID
 * @param {string} achievementKey - Achievement key
 * @param {string} gameId - Game UUID
 * @param {number} increment - Amount to increment progress
 * @returns {Promise<boolean>} True if achievement unlocked
 */
export async function updateProgress(castMemberId, achievementKey, gameId, increment = 1) {
  try {
    const { data, error } = await supabase.rpc('update_achievement_progress', {
      p_cast_member_id: castMemberId,
      p_achievement_key: achievementKey,
      p_game_id: gameId,
      p_increment: increment
    })

    if (error) throw error

    // If unlocked via progress, show notification
    if (data) {
      await showAchievementUnlock(achievementKey)
    }

    return data

  } catch (error) {
    console.error('Error updating achievement progress:', error)
    return false
  }
}

/**
 * Get all achievements for a cast member
 * @param {string} castMemberId - Cast member UUID
 * @param {string} gameId - Optional game UUID filter
 * @returns {Promise<Array>} Array of achievements
 */
export async function getAchievements(castMemberId, gameId = null) {
  try {
    const { data, error } = await supabase.rpc('get_cast_member_achievements', {
      p_cast_member_id: castMemberId,
      p_game_id: gameId
    })

    if (error) throw error
    return data || []

  } catch (error) {
    console.error('Error loading achievements:', error)
    return []
  }
}

/**
 * Get achievement statistics
 * @param {string} castMemberId - Cast member UUID
 * @param {string} gameId - Game UUID
 * @returns {Promise<Object>} Statistics object
 */
export async function getAchievementStats(castMemberId, gameId = null) {
  try {
    const achievements = await getAchievements(castMemberId, gameId)

    const unlocked = achievements.filter(a => a.is_unlocked)
    const totalPoints = unlocked.reduce((sum, a) => sum + a.points, 0)

    const byCategory = {}
    const byRarity = {}

    unlocked.forEach(achievement => {
      // Count by category
      byCategory[achievement.category] = (byCategory[achievement.category] || 0) + 1

      // Count by rarity
      byRarity[achievement.rarity] = (byRarity[achievement.rarity] || 0) + 1
    })

    return {
      total: achievements.length,
      unlocked: unlocked.length,
      locked: achievements.length - unlocked.length,
      percentage: (unlocked.length / achievements.length) * 100,
      totalPoints,
      byCategory,
      byRarity
    }

  } catch (error) {
    console.error('Error getting achievement stats:', error)
    return null
  }
}

/**
 * Show achievement unlock notification
 * @param {string} achievementKey - Achievement key that was unlocked
 */
async function showAchievementUnlock(achievementKey) {
  try {
    // Load achievement details
    const { data: achievement, error } = await supabase
      .from('achievements')
      .select('*')
      .eq('achievement_key', achievementKey)
      .maybeSingle()

    if (error) throw error

    // Create notification element
    const notification = document.createElement('div')
    notification.className = 'achievement-unlock-notification'
    notification.style.cssText = `
      position: fixed;
      top: 100px;
      right: 20px;
      z-index: 10000;
      background: linear-gradient(135deg, rgba(10, 10, 10, 0.98), rgba(26, 26, 46, 0.98));
      border: 2px solid ${RARITY_COLORS[achievement.rarity]};
      border-radius: 16px;
      padding: 1.5rem;
      min-width: 320px;
      max-width: 400px;
      box-shadow: 0 8px 32px rgba(0, 0, 0, 0.5), 0 0 40px ${RARITY_COLORS[achievement.rarity]}80;
      animation: slideInRight 0.5s cubic-bezier(0.68, -0.55, 0.265, 1.55),
                 pulse 2s ease-in-out infinite;
    `

    notification.innerHTML = `
      <div style="text-align: center;">
        <div style="font-size: 48px; margin-bottom: 0.5rem; animation: bounceIn 0.8s ease;">
          ${achievement.icon}
        </div>
        <div style="color: ${RARITY_COLORS[achievement.rarity]}; font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: 2px; margin-bottom: 0.5rem;">
          ${achievement.rarity} Achievement Unlocked!
        </div>
        <div style="font-size: 20px; font-weight: 700; color: #d4af37; margin-bottom: 0.5rem;">
          ${achievement.name}
        </div>
        <div style="color: rgba(255, 255, 255, 0.8); font-size: 14px; margin-bottom: 1rem;">
          ${achievement.description}
        </div>
        <div style="display: flex; align-items: center; justify-content: center; gap: 0.5rem; font-size: 12px; color: rgba(255, 255, 255, 0.6);">
          <span>+${achievement.points} points</span>
          <span>•</span>
          <span style="color: ${CATEGORY_COLORS[achievement.category]}">
            ${achievement.category}
          </span>
        </div>
      </div>
    `

    // Add animations
    const style = document.createElement('style')
    style.textContent = `
      @keyframes slideInRight {
        from {
          transform: translateX(400px);
          opacity: 0;
        }
        to {
          transform: translateX(0);
          opacity: 1;
        }
      }

      @keyframes bounceIn {
        0% {
          transform: scale(0);
          opacity: 0;
        }
        50% {
          transform: scale(1.2);
        }
        100% {
          transform: scale(1);
          opacity: 1;
        }
      }

      @keyframes pulse {
        0%, 100% {
          box-shadow: 0 8px 32px rgba(0, 0, 0, 0.5), 0 0 40px ${RARITY_COLORS[achievement.rarity]}80;
        }
        50% {
          box-shadow: 0 8px 32px rgba(0, 0, 0, 0.5), 0 0 60px ${RARITY_COLORS[achievement.rarity]}FF;
        }
      }
    `
    document.head.appendChild(style)

    document.body.appendChild(notification)

    // Play sound effect if available
    try {
      const audio = new Audio('/sounds/achievement-unlock.mp3')
      audio.volume = 0.5
      audio.play().catch(() => {}) // Ignore autoplay errors
    } catch (err) {}

    // Remove after 5 seconds
    setTimeout(() => {
      notification.style.animation = 'slideInRight 0.5s reverse'
      setTimeout(() => {
        notification.remove()
      }, 500)
    }, 5000)

  } catch (error) {
    console.error('Error showing achievement unlock:', error)
  }
}

/**
 * Create achievement badge HTML
 * @param {Object} achievement - Achievement object
 * @param {boolean} unlocked - Whether achievement is unlocked
 * @returns {string} HTML string
 */
export function createAchievementBadge(achievement, unlocked = false) {
  const rarityColor = RARITY_COLORS[achievement.rarity]
  const categoryColor = CATEGORY_COLORS[achievement.category]

  return `
    <div class="achievement-badge ${unlocked ? 'unlocked' : 'locked'}" data-achievement="${achievement.achievement_key}">
      <div class="badge-icon" style="font-size: 48px; ${unlocked ? '' : 'filter: grayscale(100%); opacity: 0.3;'}">
        ${achievement.icon}
      </div>
      <div class="badge-name" style="font-weight: 700; color: ${unlocked ? rarityColor : 'rgba(255,255,255,0.5)'};">
        ${achievement.name}
      </div>
      <div class="badge-description" style="font-size: 13px; color: rgba(255,255,255,${unlocked ? '0.7' : '0.3'});">
        ${achievement.description}
      </div>
      <div class="badge-footer" style="display: flex; justify-content: space-between; align-items: center; margin-top: 0.5rem; font-size: 11px;">
        <span style="color: ${categoryColor}; text-transform: uppercase; font-weight: 600;">
          ${achievement.category}
        </span>
        <span style="color: ${rarityColor}; text-transform: uppercase; font-weight: 600;">
          ${achievement.rarity}
        </span>
        <span style="color: rgba(255,255,255,0.6);">
          ${achievement.points} pts
        </span>
      </div>
      ${unlocked && achievement.unlocked_at ? `
        <div class="badge-unlocked-date" style="font-size: 10px; color: rgba(255,255,255,0.4); text-align: center; margin-top: 0.5rem;">
          Unlocked ${new Date(achievement.unlocked_at).toLocaleDateString()}
        </div>
      ` : ''}
    </div>
  `
}

/**
 * Render achievements grid
 * @param {string} containerId - Container element ID
 * @param {Array} achievements - Array of achievements
 */
export function renderAchievementsGrid(containerId, achievements) {
  const container = document.getElementById(containerId)
  if (!container) return

  // Group by category
  const byCategory = {}
  achievements.forEach(achievement => {
    if (!byCategory[achievement.category]) {
      byCategory[achievement.category] = []
    }
    byCategory[achievement.category].push(achievement)
  })

  // Render each category
  let html = ''
  Object.entries(byCategory).forEach(([category, items]) => {
    html += `
      <div class="achievement-category">
        <h3 style="color: ${CATEGORY_COLORS[category]}; text-transform: capitalize; margin-bottom: 1rem;">
          ${category}
        </h3>
        <div style="display: grid; grid-template-columns: repeat(auto-fill, minmax(250px, 1fr)); gap: 1rem;">
          ${items.map(achievement => createAchievementBadge(achievement, achievement.is_unlocked)).join('')}
        </div>
      </div>
    `
  })

  container.innerHTML = html

  // Add base styles
  const style = document.createElement('style')
  style.textContent = `
    .achievement-badge {
      background: rgba(255, 255, 255, 0.03);
      border: 2px solid rgba(255, 255, 255, 0.1);
      border-radius: 16px;
      padding: 1.5rem;
      transition: all 0.3s ease;
      cursor: pointer;
    }

    .achievement-badge.unlocked {
      border-color: rgba(212, 175, 55, 0.3);
    }

    .achievement-badge:hover {
      transform: translateY(-4px);
      box-shadow: 0 8px 24px rgba(0, 0, 0, 0.3);
    }

    .achievement-badge.unlocked:hover {
      border-color: rgba(212, 175, 55, 0.6);
      box-shadow: 0 8px 24px rgba(212, 175, 55, 0.2);
    }

    .achievement-category {
      margin-bottom: 3rem;
    }
  `
  document.head.appendChild(style)
}

/**
 * Automatic achievement tracking hooks
 */
export class AchievementTracker {
  constructor(castMemberId, gameId) {
    this.castMemberId = castMemberId
    this.gameId = gameId
  }

  // Track scenario response
  async trackScenarioResponse(responseData) {
    await updateProgress(this.castMemberId, 'first_response', this.gameId)

    // Check drama level
    if (responseData.drama_level >= 80) {
      await unlockAchievement(this.castMemberId, 'drama_king', this.gameId)
    }
  }

  // Track voice note
  async trackVoiceNote(voiceNoteData) {
    await updateProgress(this.castMemberId, 'voice_debut', this.gameId)
    await updateProgress(this.castMemberId, 'prolific_creator', this.gameId)
  }

  // Track alliance creation
  async trackAllianceCreated() {
    await updateProgress(this.castMemberId, 'first_alliance', this.gameId)
    await updateProgress(this.castMemberId, 'social_butterfly', this.gameId)
  }

  // Track vote cast
  async trackVoteCast(votedForCastMemberId) {
    await updateProgress(this.castMemberId, 'first_vote', this.gameId)

    // Check if voted for alliance member
    const { data: isAllyVote } = await supabase
      .from('mm_relationship_edges')
      .select('id')
      .eq('game_id', this.gameId)
      .or(`cast_member_a_id.eq.${this.castMemberId},cast_member_b_id.eq.${this.castMemberId}`)
      .or(`cast_member_a_id.eq.${votedForCastMemberId},cast_member_b_id.eq.${votedForCastMemberId}`)
      .eq('relationship_type', 'alliance')
      .maybeSingle()

    if (isAllyVote) {
      await unlockAchievement(this.castMemberId, 'betrayal', this.gameId)
    }
  }

  // Track reaction received
  async trackReactionReceived(voiceNoteId) {
    const { data: reactions } = await supabase
      .from('voice_note_reactions')
      .select('id')
      .eq('voice_note_id', voiceNoteId)

    if (reactions) {
      await updateProgress(this.castMemberId, 'fan_favorite', this.gameId, 1)

      if (reactions.length >= 20) {
        await unlockAchievement(this.castMemberId, 'viral_moment', this.gameId)
      }
    }
  }

  // Track game win
  async trackGameWin() {
    await unlockAchievement(this.castMemberId, 'game_winner', this.gameId)
  }

  // Track survival to final 3
  async trackFinalThree() {
    await unlockAchievement(this.castMemberId, 'survivor', this.gameId)
  }
}

// Export for global access
window.achievementsModule = {
  unlockAchievement,
  updateProgress,
  getAchievements,
  getAchievementStats,
  createAchievementBadge,
  renderAchievementsGrid,
  AchievementTracker
}

export default {
  unlockAchievement,
  updateProgress,
  getAchievements,
  getAchievementStats,
  createAchievementBadge,
  renderAchievementsGrid,
  AchievementTracker
}
