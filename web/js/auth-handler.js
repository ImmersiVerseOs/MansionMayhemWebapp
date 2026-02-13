/**
 * Auth Handler - UI Integration for Authentication
 * Connects HTML forms to Supabase auth functions
 */

import { supabaseClient as supabase, getCurrentUser, signOut as supabaseSignOut } from './supabase-module.js'
import { signInWithEmail, signUpWithEmail, signInWithGoogle, resetPassword } from './auth.js'

// ============================================================================
// SIGN IN
// ============================================================================

export async function handleSignIn(email, password) {
  try {
    const { user } = await signInWithEmail(email, password)
    return { success: true, user }
  } catch (error) {
    console.error('Sign in error:', error)
    return { success: false, error: error.message }
  }
}

// ============================================================================
// SIGN UP
// ============================================================================

export async function handleSignUp(email, password, displayName) {
  try {
    const data = await signUpWithEmail(email, password, displayName)
    return { success: true, data }
  } catch (error) {
    console.error('Sign up error:', error)
    return { success: false, error: error.message }
  }
}

// ============================================================================
// OAUTH
// ============================================================================

export async function handleGoogleSignIn() {
  try {
    await signInWithGoogle('/pages/dashboard.html')
    return { success: true }
  } catch (error) {
    console.error('Google sign in error:', error)
    return { success: false, error: error.message }
  }
}

// ============================================================================
// SIGN OUT
// ============================================================================

export async function handleSignOut() {
  try {
    await supabaseSignOut()
    return { success: true }
  } catch (error) {
    console.error('Sign out error:', error)
    return { success: false, error: error.message }
  }
}

// ============================================================================
// PASSWORD RESET
// ============================================================================

export async function handlePasswordReset(email) {
  try {
    await resetPassword(email)
    return { success: true }
  } catch (error) {
    console.error('Password reset error:', error)
    return { success: false, error: error.message }
  }
}

// ============================================================================
// AUTH STATE CHECK
// ============================================================================

export async function checkAuthState() {
  const user = await getCurrentUser()
  return user
}

// ============================================================================
// REDIRECT IF NOT AUTHENTICATED
// ============================================================================

export async function requireAuth(redirectUrl = '/pages/sign-in.html') {
  const user = await getCurrentUser()
  if (!user) {
    window.location.href = redirectUrl
    return null
  }
  return user
}

// ============================================================================
// RENDER USER INFO (for nav/dashboard)
// ============================================================================

export async function renderUserInfo(elementId) {
  const user = await getCurrentUser()
  const element = document.getElementById(elementId)

  if (!element) return

  if (user) {
    element.innerHTML = `
      <div style="display: flex; align-items: center; gap: 1rem;">
        <span style="color: rgba(255,255,255,0.7);">${user.email}</span>
        <button onclick="window.handleSignOutClick()" style="
          background: var(--gradient-gold);
          color: #000;
          border: none;
          padding: 0.5rem 1rem;
          border-radius: 8px;
          font-weight: 600;
          cursor: pointer;
          transition: all 0.3s;
        ">Sign Out</button>
      </div>
    `
  } else {
    element.innerHTML = `
      <a href="/pages/sign-in.html" style="
        background: var(--gradient-gold);
        color: #000;
        text-decoration: none;
        padding: 0.5rem 1rem;
        border-radius: 8px;
        font-weight: 600;
        transition: all 0.3s;
      ">Sign In</a>
    `
  }
}

// Global sign out handler
window.handleSignOutClick = async function() {
  if (confirm('Are you sure you want to sign out?')) {
    const result = await handleSignOut()
    if (result.success) {
      window.location.href = '/index.html'
    }
  }
}
