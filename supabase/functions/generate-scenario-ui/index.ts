// ============================================================================
// UI GENERATION ENGINE
// Generates custom UI pages for special scenarios
// Called by analyze-scenario when custom UI is needed
// ============================================================================

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import Anthropic from 'npm:@anthropic-ai/sdk@0.24.3'

const ANTHROPIC_API_KEY = Deno.env.get('ANTHROPIC_API_KEY')!
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { scenarioId } = await req.json()

    if (!scenarioId) {
      throw new Error('scenarioId is required')
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
    const anthropic = new Anthropic({ apiKey: ANTHROPIC_API_KEY })

    console.log(`🎨 UI Generation Engine started for scenario: ${scenarioId}`)

    // Load scenario with analysis
    const { data: scenario, error: scenarioError } = await supabase
      .from('scenarios')
      .select(`
        *,
        scenario_targets (
          cast_member:cast_members (
            id,
            display_name,
            full_name,
            archetype
          )
        )
      `)
      .eq('id', scenarioId)
      .single()

    if (scenarioError) {
      console.error('❌ Scenario query error:', scenarioError)
      throw scenarioError
    }
    if (!scenario) throw new Error('Scenario not found')

    console.log(`📊 Scenario: ${scenario.title}`)
    console.log(`📐 Template: ${scenario.ui_template}`)
    console.log(`📊 Scenario targets count: ${scenario.scenario_targets?.length || 0}`)
    console.log(`📊 Roles:`, JSON.stringify(scenario.roles))

    // Check if scenario has been analyzed
    if (!scenario.analyzed_at) {
      throw new Error('Scenario has not been analyzed yet. Run analyze-scenario first.')
    }

    if (!scenario.ui_template || scenario.ui_template === 'standard') {
      throw new Error('Scenario does not need custom UI (template: standard)')
    }

    // Create generation record
    const { data: genRecord, error: genError } = await supabase
      .from('generated_uis')
      .insert({
        scenario_id: scenarioId,
        template_used: scenario.ui_template,
        generation_status: 'pending'
      })
      .select()
      .single()

    if (genError) throw genError

    try {
      // Generate UI based on template type
      const generatedHTML = await generateUIForTemplate(
        scenario,
        anthropic
      )

      // Save generated HTML to database
      const filePath = `/pages/events/scenario-${scenarioId}.html`

      const { error: updateError } = await supabase
        .from('generated_uis')
        .update({
          generated_html: generatedHTML,
          file_path: filePath,
          generation_status: 'completed',
          generated_at: new Date().toISOString()
        })
        .eq('id', genRecord.id)

      if (updateError) throw updateError

      // Update scenario with custom UI path
      await supabase
        .from('scenarios')
        .update({
          custom_ui_path: filePath,
          ui_generated_at: new Date().toISOString()
        })
        .eq('id', scenarioId)

      console.log(`✅ UI generated successfully: ${filePath}`)

      return new Response(JSON.stringify({
        success: true,
        scenarioId,
        filePath,
        htmlLength: generatedHTML.length
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })

    } catch (error) {
      // Mark as failed
      await supabase
        .from('generated_uis')
        .update({
          generation_status: 'failed',
          error_message: error.message
        })
        .eq('id', genRecord.id)

      throw error
    }

  } catch (error) {
    console.error('❌ UI generation error:', error)
    return new Response(JSON.stringify({
      success: false,
      error: error.message
    }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})

async function generateUIForTemplate(
  scenario: any,
  anthropic: Anthropic
): Promise<string> {

  const template = scenario.ui_template || 'standard'

  console.log(`🎯 Generating ${template} template`)

  // Build cast member info for context
  const judges = scenario.roles?.judges || []
  const participants = scenario.roles?.participants || []

  const castInfo = scenario.scenario_targets?.map((t: any) => {
    if (!t.cast_member) {
      console.warn('Warning: scenario_target missing cast_member data')
      return null
    }
    return {
      id: t.cast_member.id,
      name: t.cast_member.display_name || t.cast_member.full_name,
      archetype: t.cast_member.archetype
    }
  }).filter(Boolean) || []

  let templateInstructions = ''

  switch (template) {
    case 'judge-panel':
      templateInstructions = `
CREATE A JUDGE PANEL UI:

PURPOSE: Judges review participants' responses and vote on winner

LAYOUT:
1. Header: Scenario title + "JUDGE MODE" badge
2. Instructions: "Review each submission and vote for the best"
3. Participant Cards (one per participant):
   - Name + Archetype
   - Their response/receipts
   - Star rating (1-5)
   - Vote button
4. Submit Verdict button (disabled until vote cast)

FEATURES:
- Load all participant responses from scenario_responses table
- Allow judge to rate and vote
- Save vote to scenario_votes table
- Show real-time voting if multiple judges
- Highlight winner after all judges vote

JUDGES: ${judges.join(', ')}
PARTICIPANTS: ${participants.join(', ')}
`
      break

    case 'voting-booth':
      templateInstructions = `
CREATE A VOTING BOOTH UI:

PURPOSE: All cast members vote on something

LAYOUT:
1. Header: Scenario title + voting question
2. Voting options (cards)
3. Submit vote button
4. Results (after voting)

FEATURES:
- Show voting options
- Record vote in database
- Show live results
- Prevent double voting
`
      break

    case 'challenge-arena':
      templateInstructions = `
CREATE A CHALLENGE ARENA UI:

PURPOSE: Track competition/challenge performance

LAYOUT:
1. Header: Challenge name
2. Leaderboard
3. Submission area for participants
4. Scoring system

FEATURES:
- Track scores/performance
- Real-time leaderboard
- Declare winner
`
      break

    default:
      throw new Error(`Unknown template: ${template}`)
  }

  const prompt = `Generate a COMPLETE, PRODUCTION-READY HTML page for this Mansion Mayhem scenario.

SCENARIO: ${scenario.title}
DESCRIPTION: ${scenario.description}
CONTEXT NOTES: ${scenario.context_notes || 'None'}
TEMPLATE TYPE: ${template}

${templateInstructions}

DESIGN SYSTEM (MATCH EXACTLY):
- Background: linear-gradient(135deg, #1a0033, #0a0012)
- Cards: background: rgba(255,255,255,0.05), border: 1px solid rgba(255,255,255,0.1)
- Purple accent: #8b5cf6
- Pink accent: #ec4899
- Text: #fafafa
- Secondary text: #a1a1aa
- Font: 'Inter', sans-serif
- Border radius: 12px for cards
- Padding: 20px cards, 40px page

TECHNICAL REQUIREMENTS:
1. Include Supabase CDN: <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
2. Initialize Supabase client with: const supabaseClient = window.supabase.createClient(window.SUPABASE_URL, window.SUPABASE_ANON_KEY)
   (The server will inject window.SUPABASE_URL and window.SUPABASE_ANON_KEY automatically)
3. Load data from database (scenario_responses, cast_members, etc.)
4. Save votes/responses to database
5. Mobile responsive (grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)))
6. Loading states
7. Error handling
8. Back button to dashboard

CAST MEMBERS:
${JSON.stringify(castInfo, null, 2)}

Generate COMPLETE standalone HTML file with:
- Inline CSS (in <style> tag)
- Inline JavaScript (in <script> tag)
- Supabase CDN included
- ALL functionality implemented
- Production-ready code

Return ONLY the HTML code, no explanation.`

  console.log('🤖 Calling Claude to generate UI...')

  const message = await anthropic.messages.create({
    model: 'claude-sonnet-4-5-20250929',
    max_tokens: 8000,
    messages: [{
      role: 'user',
      content: prompt
    }]
  })

  const responseText = message.content[0].type === 'text'
    ? message.content[0].text
    : ''

  // Extract HTML from response (might be in code block)
  let html = responseText

  // Check if wrapped in code block
  const codeBlockMatch = responseText.match(/```html?\n([\s\S]*?)```/)
  if (codeBlockMatch) {
    html = codeBlockMatch[1]
  }

  // Validate HTML
  if (!html.includes('<!DOCTYPE html>') && !html.includes('<html')) {
    throw new Error('Generated content is not valid HTML')
  }

  return html.trim()
}
