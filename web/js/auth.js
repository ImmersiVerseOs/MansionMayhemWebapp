/**
 * Authentication Module
 * Mansion Mayhem - User Authentication & Registration
 */

import { supabaseClient as supabase, getCurrentUser } from './supabase-module.js'

/**
 * Sign up with email and password
 * @param {string} email
 * @param {string} password
 * @param {string} displayName
 * @returns {Promise<Object>}
 */
export async function signUpWithEmail(email, password, displayName) {
  // Create auth user
  const { data: authData, error: authError } = await supabase.auth.signUp({
    email,
    password,
    options: {
      emailRedirectTo: window.location.origin + '/pages/confirm-email.html',
      data: {
        display_name: displayName
      }
    }
  })

  if (authError) throw authError

  // Create profile record
  const { error: profileError } = await supabase
    .from('profiles')
    .insert({
      id: authData.user.id,
      email: authData.user.email,
      display_name: displayName,
      role: 'cast_member',
      status: 'pending'
    })

  if (profileError) {
    console.error('Error creating profile:', profileError)
    throw profileError
  }

  return authData
}

/**
 * Sign in with email and password
 * @param {string} email
 * @param {string} password
 * @returns {Promise<Object>}
 */
export async function signInWithEmail(email, password) {
  const { data, error } = await supabase.auth.signInWithPassword({
    email,
    password
  })

  if (error) throw error
  return data
}

/**
 * Sign in with Google OAuth
 * @param {string} redirectTo - URL to redirect after auth
 * @returns {Promise<Object>}
 */
export async function signInWithGoogle(redirectTo = '/pages/dashboard.html') {
  const { data, error } = await supabase.auth.signInWithOAuth({
    provider: 'google',
    options: {
      redirectTo: window.location.origin + redirectTo
    }
  })

  if (error) throw error
  return data
}

/**
 * Sign in with Facebook OAuth
 * @param {string} redirectTo - URL to redirect after auth
 * @returns {Promise<Object>}
 */
export async function signInWithFacebook(redirectTo = '/pages/dashboard.html') {
  const { data, error } = await supabase.auth.signInWithOAuth({
    provider: 'facebook',
    options: {
      redirectTo: window.location.origin + redirectTo
    }
  })

  if (error) throw error
  return data
}

/**
 * Send password reset email
 * @param {string} email
 * @returns {Promise<Object>}
 */
export async function resetPassword(email) {
  const { data, error } = await supabase.auth.resetPasswordForEmail(email, {
    redirectTo: window.location.origin + '/pages/reset-password.html'
  })

  if (error) throw error
  return data
}

/**
 * Update password (requires current session)
 * @param {string} newPassword
 * @returns {Promise<Object>}
 */
export async function updatePassword(newPassword) {
  const { data, error } = await supabase.auth.updateUser({
    password: newPassword
  })

  if (error) throw error
  return data
}

/**
 * Update user profile
 * @param {Object} updates - Fields to update
 * @returns {Promise<Object>}
 */
export async function updateProfile(updates) {
  const user = await getCurrentUser()
  if (!user) throw new Error('Not authenticated')

  const { data, error } = await supabase
    .from('profiles')
    .update(updates)
    .eq('id', user.id)
    .select()
    .single()

  if (error) throw error
  return data
}

/**
 * Check if user has completed onboarding
 * @returns {Promise<boolean>}
 */
export async function hasCompletedOnboarding() {
  const user = await getCurrentUser()
  if (!user) return false

  const { data, error } = await supabase
    .from('profiles')
    .select('onboarding_completed')
    .eq('id', user.id)
    .single()

  if (error) return false
  return data?.onboarding_completed || false
}

/**
 * Mark onboarding as complete
 * @returns {Promise<Object>}
 */
export async function completeOnboarding() {
  return updateProfile({ onboarding_completed: true })
}

/**
 * Require authentication - redirect to sign-in if not authenticated
 * @param {string} redirectUrl - URL to redirect to if not authenticated
 * @returns {Promise<User|null>}
 */
export async function requireAuth(redirectUrl = '/pages/sign-in.html') {
  const user = await getCurrentUser()
  if (!user) {
    window.location.href = redirectUrl
    return null
  }
  return user
}
