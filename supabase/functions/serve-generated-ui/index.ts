// ============================================================================
// GENERATED UI SERVING ENDPOINT
// Serves auto-generated HTML pages from database
// Accessed via /pages/events/scenario-{id}.html
// ============================================================================

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Extract scenario ID from URL
    const url = new URL(req.url)
    const scenarioId = url.searchParams.get('scenario_id')

    if (!scenarioId) {
      return new Response('Missing scenario_id parameter', {
        status: 400,
        headers: corsHeaders
      })
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
        ...corsHeaders,
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
