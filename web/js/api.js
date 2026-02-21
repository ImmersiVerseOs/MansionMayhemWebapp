/**
 * API Module - Backend Integration
 * Mansion Mayhem - All database operations and RPC function calls
 */

import { supabaseClient as supabase, getCurrentUser } from './supabase-module.js'

// ============================================================================
// CHARACTER SETUP & ONBOARDING
// ============================================================================

/**
 * Complete full character setup in one transaction
 * @param {Object} characterData - All character data
 * @returns {Promise<string>} Character ID
 */
export async function completeCharacterSetup(characterData) {
  const user = await getCurrentUser()
  if (!user) throw new Error('Not authenticated')

  const { data, error } = await supabase.rpc('complete_character_setup', {
    p_user_id: user.id,
    p_character_data: characterData.character,
    p_facecast_data: characterData.facecast,
    p_personality_data: characterData.personality,
    p_consent_data: characterData.consent
  })

  if (error) throw error
  return data
}

// ============================================================================
// DASHBOARD & ANALYTICS
// ============================================================================

/**
 * Get user dashboard statistics
 * @param {string} userId
 * @returns {Promise<Object>} Dashboard stats
 */
export async function getCharacterDashboard(userId) {
  const { data, error } = await supabase.rpc('get_character_dashboard', {
    p_user_id: userId
  })

  if (error) throw error
  return data
}

/**
 * Get admin analytics (admin only)
 * @param {number} days - Number of days to analyze (default 30)
 * @returns {Promise<Object>} Platform analytics
 */
export async function getAdminAnalytics(days = 30) {
  const { data, error } = await supabase.rpc('get_admin_analytics', {
    p_days: days
  })

  if (error) throw error
  return data
}

// ============================================================================
// VOICE NOTES
// ============================================================================

/**
 * Create a new voice note
 * @param {string} userId
 * @param {string} audioUrl - Storage URL
 * @param {number} duration - Duration in seconds
 * @param {string} noteType - confession|response|drama|update
 * @param {string} caption - Optional caption
 * @returns {Promise<string>} Voice note ID
 */
export async function createVoiceNote(userId, audioUrl, duration, noteType, caption = null) {
  const { data, error } = await supabase.rpc('create_voice_note', {
    p_user_id: userId,
    p_note_type: noteType,
    p_audio_url: audioUrl,
    p_duration: duration,
    p_caption: caption
  })

  if (error) throw error
  return data
}

/**
 * Get voice notes feed (approved only)
 * @param {number} limit - Number of notes to fetch
 * @returns {Promise<Array>} Voice notes
 */
export async function getVoiceNotesFeed(limit = 20) {
  const { data, error } = await supabase
    .from('voice_notes')
    .select(`
      *,
      profiles (
        id,
        display_name,
        avatar_url
      )
    `)
    .eq('status', 'approved')
    .order('created_at', { ascending: false })
    .limit(limit)

  if (error) throw error
  return data
}

/**
 * React to a voice note
 * @param {string} voiceNoteId
 * @param {string} reactionType - fire|drama|laugh|shocked
 * @returns {Promise<boolean>}
 */
export async function reactToVoiceNote(voiceNoteId, reactionType) {
  const user = await getCurrentUser()
  if (!user) throw new Error('Not authenticated')

  const { data, error } = await supabase.rpc('react_to_voice_note', {
    p_voice_note_id: voiceNoteId,
    p_user_id: user.id,
    p_reaction_type: reactionType
  })

  if (error) throw error
  return data
}

/**
 * Search voice notes by keyword
 * @param {string} query - Search query
 * @param {number} limit - Max results
 * @returns {Promise<Array>} Matching voice notes
 */
export async function searchVoiceNotes(query, limit = 20) {
  const { data, error } = await supabase.rpc('search_voice_notes', {
    p_query: query,
    p_limit: limit
  })

  if (error) throw error
  return data
}

// ============================================================================
// SCENARIOS
// ============================================================================

/**
 * Get active scenarios for a user
 * @param {string} userId
 * @returns {Promise<Array>} Active scenarios
 */
export async function getActiveScenarios(userId) {
  const { data, error} = await supabase.rpc('get_active_scenarios', {
    p_user_id: userId
  })

  if (error) throw error
  return data
}

/**
 * Submit a response to a scenario
 * @param {string} scenarioId
 * @param {string} userId
 * @param {string} responseText
 * @param {boolean} isAiGenerated
 * @returns {Promise<string>} Response ID
 */
export async function submitScenarioResponse(scenarioId, userId, responseText, isAiGenerated = false) {
  const { data, error } = await supabase.rpc('submit_scenario_response', {
    p_scenario_id: scenarioId,
    p_user_id: userId,
    p_response_text: responseText,
    p_is_ai_generated: isAiGenerated
  })

  if (error) throw error
  return data
}

// ============================================================================
// EPISODES
// ============================================================================

/**
 * Get published episodes
 * @param {number} limit - Number of episodes to fetch
 * @returns {Promise<Array>} Episodes
 */
export async function getPublishedEpisodes(limit = 20) {
  const { data, error } = await supabase
    .from('episodes')
    .select('*')
    .eq('status', 'published')
    .not('published_at', 'is', null)
    .order('episode_number', { ascending: false })
    .limit(limit)

  if (error) throw error
  return data
}

/**
 * Get episode by ID
 * @param {string} episodeId
 * @returns {Promise<Object>} Episode details
 */
export async function getEpisode(episodeId) {
  const { data, error } = await supabase
    .from('episodes')
    .select(`
      *,
      episode_cast (
        user_id,
        screen_time,
        earnings,
        profiles (
          display_name,
          avatar_url
        )
      )
    `)
    .eq('id', episodeId)
    .maybeSingle()

  if (error) throw error
  return data
}

/**
 * Increment episode view count
 * @param {string} episodeId
 */
export async function incrementEpisodeViews(episodeId) {
  const { error } = await supabase.rpc('increment', {
    table_name: 'episodes',
    row_id: episodeId,
    column_name: 'view_count'
  })

  if (error) console.error('Error incrementing views:', error)
}

// ============================================================================
// EARNINGS & PAYOUTS
// ============================================================================

/**
 * Calculate earnings for a user
 * @param {string} userId
 * @param {string} startDate - YYYY-MM-DD
 * @param {string} endDate - YYYY-MM-DD
 * @returns {Promise<Object>} Earnings breakdown
 */
export async function calculateCharacterEarnings(userId, startDate, endDate) {
  const { data, error } = await supabase.rpc('calculate_character_earnings', {
    p_user_id: userId,
    p_start_date: startDate,
    p_end_date: endDate
  })

  if (error) throw error
  return data
}

/**
 * Get user's earnings history
 * @param {number} limit - Number of records to fetch
 * @returns {Promise<Array>} Earnings records
 */
export async function getEarningsHistory(limit = 50) {
  const user = await getCurrentUser()
  if (!user) throw new Error('Not authenticated')

  const { data, error } = await supabase
    .from('earnings')
    .select('*')
    .eq('user_id', user.id)
    .order('created_at', { ascending: false })
    .limit(limit)

  if (error) throw error
  return data
}

/**
 * Get user's payout history
 * @returns {Promise<Array>} Payout records
 */
export async function getPayoutHistory() {
  const user = await getCurrentUser()
  if (!user) throw new Error('Not authenticated')

  const { data, error } = await supabase
    .from('payouts')
    .select('*')
    .eq('user_id', user.id)
    .order('created_at', { ascending: false })

  if (error) throw error
  return data
}

// ============================================================================
// MODERATION
// ============================================================================

/**
 * Flag content for moderation
 * @param {string} contentType - voice_note|comment|profile|response
 * @param {string} contentId
 * @param {string} reason - harassment|hate_speech|spam|inappropriate|threatening|other
 * @param {string} description - Optional details
 * @returns {Promise<string>} Report ID
 */
export async function flagContent(contentType, contentId, reason, description = null) {
  const user = await getCurrentUser()
  if (!user) throw new Error('Not authenticated')

  const { data, error } = await supabase.rpc('flag_content', {
    p_reporter_id: user.id,
    p_content_type: contentType,
    p_content_id: contentId,
    p_reason: reason,
    p_description: description
  })

  if (error) throw error
  return data
}

/**
 * Get pending content reports (admin only)
 * @returns {Promise<Array>} Reports
 */
export async function getPendingReports() {
  const { data, error } = await supabase
    .from('content_reports')
    .select(`
      *,
      reporter:profiles!reporter_id (
        display_name
      )
    `)
    .eq('status', 'pending')
    .order('created_at', { ascending: false })

  if (error) throw error
  return data
}

// ============================================================================
// FILE UPLOADS (STORAGE)
// ============================================================================

/**
 * Upload FaceCast photo
 * @param {File} file - Image file
 * @returns {Promise<string>} Public URL
 */
export async function uploadFaceCastPhoto(file) {
  const user = await getCurrentUser()
  if (!user) throw new Error('Not authenticated')

  const fileName = `${user.id}/${Date.now()}_${file.name}`

  const { data, error } = await supabase.storage
    .from('facecast-photos')
    .upload(fileName, file, {
      cacheControl: '3600',
      upsert: false
    })

  if (error) throw error

  const { data: { publicUrl } } = supabase.storage
    .from('facecast-photos')
    .getPublicUrl(fileName)

  return publicUrl
}

/**
 * Upload voice note audio
 * @param {Blob} audioBlob - Audio file
 * @param {string} userId
 * @returns {Promise<string>} Public URL
 */
export async function uploadVoiceNote(audioBlob, userId) {
  const fileName = `${userId}/${Date.now()}.webm`

  const { data, error } = await supabase.storage
    .from('voice-notes')
    .upload(fileName, audioBlob, {
      contentType: 'audio/webm',
      cacheControl: '3600'
    })

  if (error) throw error

  const { data: { publicUrl } } = supabase.storage
    .from('voice-notes')
    .getPublicUrl(fileName)

  return publicUrl
}

/**
 * Upload user avatar
 * @param {File} file - Image file
 * @returns {Promise<string>} Public URL
 */
export async function uploadAvatar(file) {
  const user = await getCurrentUser()
  if (!user) throw new Error('Not authenticated')

  const fileName = `${user.id}/avatar_${Date.now()}.${file.name.split('.').pop()}`

  const { data, error } = await supabase.storage
    .from('user-avatars')
    .upload(fileName, file, {
      cacheControl: '3600',
      upsert: true
    })

  if (error) throw error

  const { data: { publicUrl } } = supabase.storage
    .from('user-avatars')
    .getPublicUrl(fileName)

  return publicUrl
}

/**
 * Upload episode video (admin only)
 * @param {File} file - Video file
 * @param {string} episodeNumber
 * @returns {Promise<string>} Public URL
 */
export async function uploadEpisodeVideo(file, episodeNumber) {
  const fileName = `episode_${episodeNumber}_${Date.now()}.${file.name.split('.').pop()}`

  const { data, error } = await supabase.storage
    .from('episode-videos')
    .upload(fileName, file, {
      cacheControl: '3600'
    })

  if (error) throw error

  const { data: { publicUrl } } = supabase.storage
    .from('episode-videos')
    .getPublicUrl(fileName)

  return publicUrl
}

/**
 * Upload episode thumbnail
 * @param {File} file - Image file
 * @param {string} episodeNumber
 * @returns {Promise<string>} Public URL
 */
export async function uploadEpisodeThumbnail(file, episodeNumber) {
  const fileName = `episode_${episodeNumber}_thumb_${Date.now()}.${file.name.split('.').pop()}`

  const { data, error } = await supabase.storage
    .from('episode-thumbnails')
    .upload(fileName, file, {
      cacheControl: '3600'
    })

  if (error) throw error

  const { data: { publicUrl } } = supabase.storage
    .from('episode-thumbnails')
    .getPublicUrl(fileName)

  return publicUrl
}

// ============================================================================
// REAL-TIME SUBSCRIPTIONS
// ============================================================================

/**
 * Subscribe to voice notes updates
 * @param {Function} callback - Function to call on new voice note
 * @returns {Object} Subscription object
 */
export function subscribeToVoiceNotes(callback) {
  return supabase
    .channel('voice_notes_channel')
    .on('postgres_changes', {
      event: 'INSERT',
      schema: 'public',
      table: 'voice_notes',
      filter: 'status=eq.approved'
    }, callback)
    .subscribe()
}

/**
 * Subscribe to scenario updates
 * @param {Function} callback - Function to call on scenario change
 * @returns {Object} Subscription object
 */
export function subscribeToScenarios(callback) {
  return supabase
    .channel('scenarios_channel')
    .on('postgres_changes', {
      event: '*',
      schema: 'public',
      table: 'scenarios'
    }, callback)
    .subscribe()
}

/**
 * Unsubscribe from real-time channel
 * @param {Object} subscription - Subscription object from subscribe function
 */
export async function unsubscribe(subscription) {
  await supabase.removeChannel(subscription)
}
