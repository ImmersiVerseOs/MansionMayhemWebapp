// ============================================================================
// GENERATED UI SERVING ENDPOINT
// Serves auto-generated HTML pages from database
// Accessed via /pages/events/scenario-{id}.html
// ============================================================================

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
// Anon key is public - safe to hardcode
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZweGJocWliaW1la2pobHVtbm1jIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEwMjUwODYsImV4cCI6MjA4NjYwMTA4Nn0.0BmbaObOERMZ5r4znb5BQbrGpB5lE5Fq6KnEzxA0YhY'

serve(async (req) => {
  try {
    // Extract scenario ID from URL
    const url = new URL(req.url)
    const scenarioId = url.searchParams.get('scenario_id')

    if (!scenarioId) {
      return new Response('Missing scenario_id parameter', { status: 400 })
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

    // Load generated UI from database
    const { data, error } = await supabase
      .from('generated_uis')
      .select('generated_html, file_path, generated_at')
      .eq('scenario_id', scenarioId)
      .eq('generation_status', 'completed')
      .order('generated_at', { ascending: false })
      .limit(1)
      .single()

    if (error || !data) {
      // Fallback to standard UI
      return Response.redirect('/pages/scenario-response.html?scenario_id=' + scenarioId, 302)
    }

    // Inject Supabase credentials into HTML
    let html = data.generated_html

    // Inject config script right after <head> tag
    const configScript = `
  <script>
    // Supabase configuration injected by server
    window.SUPABASE_URL = '${SUPABASE_URL}';
    window.SUPABASE_ANON_KEY = '${SUPABASE_ANON_KEY}';
  </script>`

    // Insert after <head> tag
    html = html.replace(/<head>/i, `<head>${configScript}`)

    // Also replace any placeholder strings
    html = html.replace(/['"]SUPABASE_URL['"]/g, `'${SUPABASE_URL}'`)
    html = html.replace(/['"]SUPABASE_ANON_KEY['"]/g, `'${SUPABASE_ANON_KEY}'`)

    // Serve the generated HTML with credentials injected
    return new Response(html, {
      headers: {
        'Content-Type': 'text/html; charset=utf-8',
        'Cache-Control': 'public, max-age=300', // Cache for 5 minutes
      }
    })

  } catch (error) {
    console.error('Error serving generated UI:', error)

    // Fallback to standard UI
    const url = new URL(req.url)
    const scenarioId = url.searchParams.get('scenario_id')
    return Response.redirect('/pages/scenario-response.html?scenario_id=' + scenarioId, 302)
  }
})
