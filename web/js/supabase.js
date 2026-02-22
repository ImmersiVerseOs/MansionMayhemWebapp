/**
 * Mansion Mayhem — Supabase Client + Auth
 * Single source of truth. Every page imports this.
 */

const SUPABASE_URL = 'https://fpxbhqibimekjhlumnmc.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZweGJocWliaW1la2pobHVtbm1jIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEwMjUwODYsImV4cCI6MjA4NjYwMTA4Nn0.0BmbaObOERMZ5r4znb5BQbrGpB5lE5Fq6KnEzxA0YhY';

let _client = null;

export function getSupabase() {
  if (!_client) {
    if (!window.supabase?.createClient) throw new Error('Supabase CDN not loaded');
    _client = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  }
  return _client;
}

export async function waitForSupabase() {
  return new Promise((resolve, reject) => {
    if (window.supabase?.createClient) { resolve(getSupabase()); return; }
    let attempts = 0;
    const iv = setInterval(() => {
      attempts++;
      if (window.supabase?.createClient) { clearInterval(iv); resolve(getSupabase()); }
      else if (attempts > 60) { clearInterval(iv); reject(new Error('Supabase CDN timeout')); }
    }, 100);
  });
}

export async function getUser() {
  const sb = getSupabase();
  const { data: { user } } = await sb.auth.getUser();
  return user;
}

export async function getProfile(userId) {
  const sb = getSupabase();
  const { data } = await sb.from('profiles').select('*').eq('id', userId).maybeSingle();
  return data;
}

export async function requireAuth(redirectTo = '/index.html') {
  const sb = await waitForSupabase();
  const user = await getUser();
  if (!user) { window.location.href = redirectTo; return null; }
  return user;
}

export async function signInWithEmail(email, password) {
  const sb = getSupabase();
  return sb.auth.signInWithPassword({ email, password });
}

export async function signUpWithEmail(email, password, displayName) {
  const sb = getSupabase();
  const result = await sb.auth.signUp({ email, password, options: { data: { display_name: displayName } } });
  if (result.data?.user && !result.error) {
    // Create profile
    await sb.from('profiles').upsert({
      id: result.data.user.id,
      display_name: displayName,
      email: email,
    });
  }
  return result;
}

export async function signOut() {
  const sb = getSupabase();
  await sb.auth.signOut();
  window.location.href = '/index.html';
}

export { SUPABASE_URL, SUPABASE_ANON_KEY };
