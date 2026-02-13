/**
 * Supabase Configuration
 * UPDATE THIS FILE with your NEW Supabase credentials
 */

// NEW Supabase Instance (fpxbhqibimekjhlumnmc)
export const SUPABASE_CONFIG = {
  url: 'https://fpxbhqibimekjhlumnmc.supabase.co',
  anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZweGJocWliaW1la2pobHVtbm1jIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEwMjUwODYsImV4cCI6MjA4NjYwMTA4Nn0.0BmbaObOERMZ5r4znb5BQbrGpB5lE5Fq6KnEzxA0YhY'
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
