/**
 * Supabase Configuration
 * UPDATE THIS FILE with your NEW Supabase credentials
 */

// Mansion Mayhem Supabase Database
export const SUPABASE_CONFIG = {
  url: 'https://mllqzeaxqusorytеaxzg.supabase.co',
  anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sbHF6ZWF4cXVzb3J5dGVheHpnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA0ODA1NzAsImV4cCI6MjA4NjA1NjU3MH0.s9CAe91gUG8uZ7Nrjd1pIX9YYvpNKa2lOrt6HDUarec'
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
