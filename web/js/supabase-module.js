/**
 * Supabase Client Configuration - ES6 Module
 * Mansion Mayhem - Backend Integration
 */

'use strict';

// Supabase configuration - Mansion Mayhem Database
const SUPABASE_URL = 'https://mllqzeaxqusorytеaxzg.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sbHF6ZWF4cXVzb3J5dGVheHpnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA0ODA1NzAsImV4cCI6MjA4NjA1NjU3MH0.s9CAe91gUG8uZ7Nrjd1pIX9YYvpNKa2lOrt6HDUarec';

// Wait for Supabase CDN to load
async function waitForSupabase() {
  return new Promise((resolve) => {
    if (window.supabase) {
      resolve();
      return;
    }

    const checkInterval = setInterval(() => {
      if (window.supabase) {
        clearInterval(checkInterval);
        resolve();
      }
    }, 50);

    // Timeout after 10 seconds
    setTimeout(() => {
      clearInterval(checkInterval);
      if (!window.supabase) {
        console.error('❌ Supabase CDN failed to load after 10 seconds');
      }
      resolve();
    }, 10000);
  });
}

// Wait for Supabase and create client
await waitForSupabase();

if (!window.supabase) {
  throw new Error('Supabase CDN not loaded. Make sure to include the Supabase script before this module.');
}

const { createClient } = window.supabase;

export const supabaseClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: true
  }
});

/**
 * Get current authenticated user
 * @returns {Promise<User|null>}
 */
export const getCurrentUser = async function() {
  const { data: { user }, error } = await supabaseClient.auth.getUser();
  if (error) {
    console.error('Error getting user:', error);
    return null;
  }
  return user;
};

/**
 * Get user profile from profiles table
 * @returns {Promise<Object|null>}
 */
export const getUserProfile = async function() {
  const user = await getCurrentUser();
  if (!user) return null;

  const { data, error } = await supabaseClient
    .from('profiles')
    .select('*')
    .eq('id', user.id)
    .single();

  if (error) {
    console.error('Error fetching profile:', error);
    return null;
  }

  return data;
};

/**
 * Sign out and redirect to homepage
 */
export const signOut = async function() {
  await supabaseClient.auth.signOut();
  window.location.href = '/index.html';
};

/**
 * Check if user is authenticated, redirect if not
 * @param {string} redirectUrl - URL to redirect to if not authenticated
 * @returns {Promise<User|null>}
 */
export const requireAuth = async function(redirectUrl = '/pages/sign-in.html') {
  const user = await getCurrentUser();
  if (!user) {
    window.location.href = redirectUrl;
    return null;
  }
  return user;
};

/**
 * Setup auth state change listener
 * @param {Function} callback - Function to call when auth state changes
 */
export const onAuthStateChange = function(callback) {
  return supabaseClient.auth.onAuthStateChange((event, session) => {
    callback(event, session);
  });
};

console.log('✅ Supabase client initialized:', supabaseClient);

// Make it globally available for console debugging
window.supabase = window.supabase || {};
window.supabase.client = supabaseClient;
