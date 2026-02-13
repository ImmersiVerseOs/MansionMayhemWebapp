// ============================================================================
// MANSION MAYHEM - SUPABASE FRONTEND INTEGRATION
// ============================================================================
// Complete guide for connecting your frontend pages to Supabase backend
// ============================================================================

// ============================================================================
// 1. INSTALLATION & SETUP
// ============================================================================

/*
Step 1: Install Supabase client
------------------------
npm install @supabase/supabase-js

Step 2: Get your Supabase credentials
------------------------
Go to: https://app.supabase.com/project/YOUR_PROJECT/settings/api
Copy:
- Project URL (SUPABASE_URL)
- anon/public key (SUPABASE_ANON_KEY)
*/

// ============================================================================
// 2. SUPABASE CLIENT INITIALIZATION
// ============================================================================

// Create: /js/supabase-client.js
import { createClient } from '@supabase/supabase-js'

const SUPABASE_URL = 'https://your-project.supabase.co'
const SUPABASE_ANON_KEY = 'your-anon-key-here'

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY)

// ============================================================================
// 3. AUTHENTICATION
// ============================================================================

// Sign Up with Email
async function signUpWithEmail(email, password, displayName) {
  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    options: {
      data: {
        display_name: displayName
      }
    }
  })
  
  if (error) throw error
  
  // Create profile
  const { error: profileError } = await supabase
    .from('profiles')
    .insert({
      id: data.user.id,
      email: data.user.email,
      display_name: displayName
    })
  
  return data
}

// Sign In with Email
async function signInWithEmail(email, password) {
  const { data, error } = await supabase.auth.signInWithPassword({
    email,
    password
  })
  
  if (error) throw error
  return data
}

// Sign In with Google
async function signInWithGoogle() {
  const { data, error } = await supabase.auth.signInWithOAuth({
    provider: 'google',
    options: {
      redirectTo: window.location.origin + '/dashboard.html'
    }
  })
  
  if (error) throw error
  return data
}

// Get Current User
async function getCurrentUser() {
  const { data: { user } } = await supabase.auth.getUser()
  return user
}

// Sign Out
async function signOut() {
  const { error } = await supabase.auth.signOut()
  if (error) throw error
}

// Check Authentication State
supabase.auth.onAuthStateChange((event, session) => {
  console.log('Auth event:', event)
  
  if (event === 'SIGNED_IN') {
    // Redirect to dashboard
    window.location.href = '/dashboard.html'
  }
  
  if (event === 'SIGNED_OUT') {
    // Redirect to landing
    window.location.href = '/index.html'
  }
})

// ============================================================================
// 4. CHARACTER SETUP (ONBOARDING)
// ============================================================================

// Complete Character Setup
async function completeCharacterSetup(characterData) {
  const user = await getCurrentUser()
  
  const { data, error } = await supabase.rpc('complete_character_setup', {
    p_user_id: user.id,
    p_character_data: {
      name: characterData.characterName,
      archetype: characterData.archetype,
      gameplayMode: characterData.gameplayMode,
      autoRespondDelay: characterData.autoRespondDelay
    },
    p_facecast_data: {
      method: characterData.faceCastMethod,
      soraUsername: characterData.soraUsername,
      authorizedCaster: characterData.authorizedCaster,
      photoUrls: characterData.photoUrls,
      genericConfig: characterData.genericConfig
    },
    p_personality_data: characterData.personalityTraits,
    p_consent_data: {
      signatureData: characterData.signatureData,
      ipAddress: characterData.ipAddress,
      timestamp: new Date().toISOString(),
      warranties: characterData.warranties
    }
  })
  
  if (error) throw error
  return data // Returns character_id
}

// Get Character for User
async function getCharacterForUser(userId) {
  const { data, error } = await supabase
    .from('characters')
    .select('*')
    .eq('user_id', userId)
    .single()
  
  if (error) throw error
  return data
}

// ============================================================================
// 5. FILE UPLOADS (FACECAST PHOTOS, VOICE NOTES)
// ============================================================================

// Upload FaceCast Photo
async function uploadFaceCastPhoto(file, userId) {
  const fileName = `${userId}/${Date.now()}_${file.name}`
  
  const { data, error } = await supabase.storage
    .from('facecast-photos')
    .upload(fileName, file, {
      cacheControl: '3600',
      upsert: false
    })
  
  if (error) throw error
  
  // Get public URL
  const { data: { publicUrl } } = supabase.storage
    .from('facecast-photos')
    .getPublicUrl(fileName)
  
  return publicUrl
}

// Upload Voice Note
async function uploadVoiceNote(audioBlob, characterId) {
  const fileName = `${characterId}/${Date.now()}.webm`
  
  const { data, error } = await supabase.storage
    .from('voice-notes')
    .upload(fileName, audioBlob, {
      contentType: 'audio/webm'
    })
  
  if (error) throw error
  
  const { data: { publicUrl } } = supabase.storage
    .from('voice-notes')
    .getPublicUrl(fileName)
  
  return publicUrl
}

// ============================================================================
// 6. VOICE NOTES
// ============================================================================

// Create Voice Note
async function createVoiceNote(characterId, audioUrl, duration, noteType, caption) {
  const { data, error } = await supabase.rpc('create_voice_note', {
    p_character_id: characterId,
    p_note_type: noteType,
    p_audio_url: audioUrl,
    p_duration: duration,
    p_caption: caption
  })
  
  if (error) throw error
  return data // Returns voice_note_id
}

// Get Voice Notes Feed
async function getVoiceNotesFeed(limit = 20) {
  const { data, error } = await supabase
    .from('voice_notes')
    .select(`
      *,
      character:characters(id, name, user_id),
      reactions:voice_note_reactions(count)
    `)
    .eq('status', 'approved')
    .order('created_at', { ascending: false })
    .limit(limit)
  
  if (error) throw error
  return data
}

// React to Voice Note
async function reactToVoiceNote(voiceNoteId, reactionType) {
  const user = await getCurrentUser()
  
  const { data, error } = await supabase.rpc('react_to_voice_note', {
    p_voice_note_id: voiceNoteId,
    p_user_id: user.id,
    p_reaction_type: reactionType
  })
  
  if (error) throw error
  return data
}

// ============================================================================
// 7. SCENARIOS & RESPONSES
// ============================================================================

// Get Active Scenarios for Character
async function getActiveScenarios(characterId) {
  const { data, error } = await supabase.rpc('get_active_scenarios', {
    p_character_id: characterId
  })
  
  if (error) throw error
  return data
}

// Submit Scenario Response
async function submitScenarioResponse(scenarioId, characterId, responseText) {
  const { data, error } = await supabase.rpc('submit_scenario_response', {
    p_scenario_id: scenarioId,
    p_character_id: characterId,
    p_response_text: responseText,
    p_is_ai_generated: false
  })
  
  if (error) throw error
  return data
}

// ============================================================================
// 8. EPISODES
// ============================================================================

// Get Published Episodes
async function getPublishedEpisodes() {
  const { data, error } = await supabase
    .from('episodes')
    .select('*')
    .eq('status', 'approved')
    .not('published_at', 'is', null)
    .order('episode_number', { ascending: false })
  
  if (error) throw error
  return data
}

// Get Episode Details with Cast
async function getEpisodeDetails(episodeId) {
  const { data, error } = await supabase
    .from('episodes')
    .select(`
      *,
      cast:episode_appearances(
        *,
        character:characters(id, name)
      )
    `)
    .eq('id', episodeId)
    .single()
  
  if (error) throw error
  return data
}

// Track Episode View
async function trackEpisodeView(episodeId, userId) {
  // Increment view count
  const { error: updateError } = await supabase.rpc('increment', {
    table_name: 'episodes',
    row_id: episodeId,
    column_name: 'view_count'
  })
  
  // Track analytics event
  const { error: analyticsError } = await supabase
    .from('analytics_events')
    .insert({
      event_type: 'episode_view',
      user_id: userId,
      event_data: { episode_id: episodeId }
    })
}

// ============================================================================
// 9. EARNINGS & DASHBOARD
// ============================================================================

// Get Character Dashboard Stats
async function getCharacterDashboard(characterId) {
  const { data, error } = await supabase.rpc('get_character_dashboard', {
    p_character_id: characterId
  })
  
  if (error) throw error
  return data
}

// Get Earnings History
async function getEarningsHistory(characterId, startDate, endDate) {
  const { data, error } = await supabase.rpc('calculate_character_earnings', {
    p_character_id: characterId,
    p_start_date: startDate,
    p_end_date: endDate
  })
  
  if (error) throw error
  return data
}

// Get Payout History
async function getPayoutHistory(characterId) {
  const { data, error } = await supabase
    .from('payouts')
    .select('*')
    .eq('character_id', characterId)
    .order('created_at', { ascending: false })
  
  if (error) throw error
  return data
}

// ============================================================================
// 10. SETTINGS & PROFILE
// ============================================================================

// Update Character Settings
async function updateCharacterSettings(characterId, settings) {
  const { data, error } = await supabase
    .from('characters')
    .update({
      gameplay_mode: settings.gameplayMode,
      auto_respond_delay: settings.autoRespondDelay
    })
    .eq('id', characterId)
    .select()
    .single()
  
  if (error) throw error
  return data
}

// Update Profile
async function updateProfile(userId, profileData) {
  const { data, error } = await supabase
    .from('profiles')
    .update(profileData)
    .eq('id', userId)
    .select()
    .single()
  
  if (error) throw error
  return data
}

// ============================================================================
// 11. MODERATION & REPORTS
// ============================================================================

// Report Content
async function reportContent(contentType, contentId, reason, description) {
  const user = await getCurrentUser()
  
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

// ============================================================================
// 12. ADMIN FUNCTIONS
// ============================================================================

// Get Admin Analytics
async function getAdminAnalytics(days = 30) {
  const { data, error } = await supabase.rpc('get_admin_analytics', {
    p_days: days
  })
  
  if (error) throw error
  return data
}

// Get Pending Reports
async function getPendingReports() {
  const { data, error } = await supabase
    .from('content_reports')
    .select(`
      *,
      reporter:profiles!reporter_id(display_name),
      voice_note:voice_notes(caption, audio_url)
    `)
    .eq('status', 'pending')
    .order('created_at', { ascending: false })
  
  if (error) throw error
  return data
}

// Moderate Content
async function moderateContent(reportId, action, notes) {
  const user = await getCurrentUser()
  
  const { data, error } = await supabase
    .from('content_reports')
    .update({
      status: 'resolved',
      action_taken: action,
      resolution_notes: notes,
      reviewed_by: user.id,
      reviewed_at: new Date().toISOString()
    })
    .eq('id', reportId)
    .select()
    .single()
  
  if (error) throw error
  return data
}

// ============================================================================
// 13. REAL-TIME SUBSCRIPTIONS
// ============================================================================

// Subscribe to New Voice Notes
function subscribeToVoiceNotes(callback) {
  const subscription = supabase
    .channel('voice_notes_channel')
    .on(
      'postgres_changes',
      {
        event: 'INSERT',
        schema: 'public',
        table: 'voice_notes',
        filter: 'status=eq.approved'
      },
      callback
    )
    .subscribe()
  
  return subscription
}

// Subscribe to Character Notifications
function subscribeToCharacterUpdates(characterId, callback) {
  const subscription = supabase
    .channel(`character_${characterId}`)
    .on(
      'postgres_changes',
      {
        event: '*',
        schema: 'public',
        table: 'scenarios',
        filter: `deadline=gt.${new Date().toISOString()}`
      },
      callback
    )
    .subscribe()
  
  return subscription
}

// Unsubscribe
function unsubscribe(subscription) {
  supabase.removeChannel(subscription)
}

// ============================================================================
// 14. USAGE EXAMPLES
// ============================================================================

// Example: Sign In Page (sign-in-premium.html)
document.getElementById('signInForm').addEventListener('submit', async (e) => {
  e.preventDefault()
  
  const email = document.getElementById('email').value
  const password = document.getElementById('password').value
  
  try {
    await signInWithEmail(email, password)
    // Redirect handled by auth state listener
  } catch (error) {
    console.error('Sign in error:', error)
    alert('Sign in failed: ' + error.message)
  }
})

// Example: Dashboard (dashboard.html)
window.addEventListener('DOMContentLoaded', async () => {
  try {
    const user = await getCurrentUser()
    if (!user) {
      window.location.href = '/sign-in.html'
      return
    }
    
    const character = await getCharacterForUser(user.id)
    const stats = await getCharacterDashboard(character.id)
    
    // Update UI with stats
    document.getElementById('totalEarnings').textContent = `$${stats.total_earnings}`
    document.getElementById('totalEpisodes').textContent = stats.total_episodes
    document.getElementById('pendingScenarios').textContent = stats.pending_scenarios
    
  } catch (error) {
    console.error('Dashboard error:', error)
  }
})

// Example: Voice Recording (record-voice-premium.html)
async function postVoiceNote() {
  try {
    const user = await getCurrentUser()
    const character = await getCharacterForUser(user.id)
    
    // Upload audio
    const audioUrl = await uploadVoiceNote(recordedAudioBlob, character.id)
    
    // Create voice note
    const voiceNoteId = await createVoiceNote(
      character.id,
      audioUrl,
      recordingDuration,
      selectedType,
      captionText
    )
    
    alert('Voice note posted successfully!')
    window.location.href = '/voice-feed.html'
    
  } catch (error) {
    console.error('Post error:', error)
    alert('Failed to post voice note')
  }
}

// ============================================================================
// COMPLETED: FRONTEND INTEGRATION GUIDE
// ============================================================================
// Next steps:
// 1. Add this code to your pages
// 2. Replace SUPABASE_URL and SUPABASE_ANON_KEY with your credentials
// 3. Test authentication flow
// 4. Test character setup
// 5. Test voice notes and scenarios
// ============================================================================
