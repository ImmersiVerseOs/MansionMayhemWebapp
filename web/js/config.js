/**
 * Supabase Configuration
 * UPDATE THIS FILE with your NEW Supabase credentials
 */

// NEW Supabase Instance (fpxbhqibimekjhlumnmc)
export const SUPABASE_CONFIG = {
  url: 'https://fpxbhqibimekjhlumnmc.supabase.co',
  anonKey: 'YOUR_NEW_ANON_KEY_HERE' // Get from: https://supabase.com/dashboard/project/fpxbhqibimekjhlumnmc/settings/api
};

// Fallback to environment variables if available (for Netlify)
if (typeof import.meta !== 'undefined' && import.meta.env) {
  SUPABASE_CONFIG.url = import.meta.env.VITE_SUPABASE_URL || SUPABASE_CONFIG.url;
  SUPABASE_CONFIG.anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY || SUPABASE_CONFIG.anonKey;
}

console.log('🔑 Supabase Config:', {
  url: SUPABASE_CONFIG.url,
  anonKey: SUPABASE_CONFIG.anonKey.substring(0, 20) + '...'
});
