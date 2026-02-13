/**
 * Supabase Client Configuration - Window Globals Wrapper
 * Mansion Mayhem - Backend Integration
 *
 * This file imports from supabase-module.js and exposes to window for backward compatibility
 */

import {
  supabaseClient,
  getCurrentUser,
  getUserProfile,
  signOut,
  requireAuth,
  onAuthStateChange
} from './supabase-module.js';

// Expose to window for backward compatibility with lobby pages
window.supabaseClient = supabaseClient;
window.getCurrentUser = getCurrentUser;
window.getUserProfile = getUserProfile;
window.signOut = signOut;
window.requireAuth = requireAuth;
window.onAuthStateChange = onAuthStateChange;

console.log('✅ Supabase client initialized (window globals):', supabaseClient);
