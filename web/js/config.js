/**
 * Supabase Configuration
 * UPDATE THIS FILE with your NEW Supabase credentials
 */

// Mansion Mayhem Supabase Database
export const SUPABASE_CONFIG = {
  url: 'https://qnvgmyhnfrhhfsshdhvl.supabase.co',
  anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFudmdteWhuZnJoaGZzc2hkaHZsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzY3OTk5NDUsImV4cCI6MjA1MjM3NTk0NX0.gx_EsjHEDM1v3_kjjhtWBqnNgqVN0wgG7SV9C5bGPkc'
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
