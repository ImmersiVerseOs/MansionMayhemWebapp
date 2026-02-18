// ============================================================================
// SCENARIO ANALYSIS ENGINE
// Analyzes scenarios to detect if custom UI is needed
// Runs as cron job every 5 minutes after AI Director
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

interface ScenarioAnalysis {
  scenarioId: string
  eventType: 'standard' | 'judge' | 'vote' | 'challenge' | 'tribunal' | 'summit'
  roles: {
    judges?: string[]
    participants?: string[]
    spectators?: string[]
  }
  customUINeeded: boolean
  uiTemplate: 'standard' | 'judge-panel' | 'voting-booth' | 'challenge-arena' | 'tribunal-court'
  detectedKeywords: string[]
  confidence: number
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
    const anthropic = new Anthropic({ apiKey: ANTHROPIC_API_KEY })

    console.log('🔍 Scenario Analysis Engine started')

    // Get scenarios created in last 10 minutes that haven't been analyzed
    const tenMinutesAgo = new Date(Date.now() - 10 * 60 * 1000).toISOString()

    const { data: scenarios, error: scenariosError } = await supabase
      .from('scenarios')
      .select(`
        id,
        title,
        context,
        description,
        scenario_type,
        created_at,
        game_id,
        scenario_targets (
          cast_member:cast_members (
            id,
            display_name,
            full_name
          )
        )
      `)
      .gte('created_at', tenMinutesAgo)
      .is('analyzed_at', null) // Not yet analyzed
      .order('created_at', { ascending: false })

    if (scenariosError) throw scenariosError

    if (!scenarios || scenarios.length === 0) {
      console.log('✅ No new scenarios to analyze')
      return new Response(JSON.stringify({
        success: true,
        analyzed: 0,
        message: 'No new scenarios found'
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    console.log(`📊 Found ${scenarios.length} scenarios to analyze`)

    const results = []

    for (const scenario of scenarios) {
      console.log(`🎬 Analyzing: ${scenario.title}`)

      try {
        const analysis = await analyzeScenarioStructure(scenario, anthropic)

        // Save analysis to database
        await saveAnalysis(supabase, scenario.id, analysis)

        results.push({
          scenarioId: scenario.id,
          title: scenario.title,
          analysis
        })

        console.log(`✅ Analysis complete: ${scenario.title}`)
        console.log(`   Event Type: ${analysis.eventType}`)
        console.log(`   Custom UI Needed: ${analysis.customUINeeded}`)
        console.log(`   Template: ${analysis.uiTemplate}`)

        // If custom UI needed, trigger UI generation
        if (analysis.customUINeeded) {
          console.log(`🎨 Triggering UI generation for scenario: ${scenario.id}`)

          // Call generate-scenario-ui function (will create this next)
          await supabase.functions.invoke('generate-scenario-ui', {
            body: { scenarioId: scenario.id }
          })
        }

      } catch (error) {
        console.error(`❌ Error analyzing scenario ${scenario.id}:`, error)
        results.push({
          scenarioId: scenario.id,
          title: scenario.title,
          error: error.message
        })
      }
    }

    return new Response(JSON.stringify({
      success: true,
      analyzed: scenarios.length,
      results
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })

  } catch (error) {
    console.error('❌ Scenario analysis error:', error)
    return new Response(JSON.stringify({
      success: false,
      error: error.message
    }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})

async function analyzeScenarioStructure(
  scenario: any,
  anthropic: Anthropic
): Promise<ScenarioAnalysis> {

  // Build cast member names for context
  const castMembers = scenario.scenario_targets?.map((t: any) =>
    t.cast_member?.display_name || t.cast_member?.full_name
  ).filter(Boolean) || []

  const prompt = `Analyze this reality TV scenario and determine its structure for UI generation.

SCENARIO TITLE: ${scenario.title}

SCENARIO CONTEXT:
${scenario.context || scenario.description || 'No context provided'}

CAST MEMBERS INVOLVED:
${castMembers.join(', ')}

ANALYSIS INSTRUCTIONS:
1. Determine the event type:
   - "standard" = Normal scenario where everyone responds with their thoughts
   - "judge" = Some cast members judge others (keywords: judge, decide, evaluate, vote on, determine winner)
   - "vote" = Cast members vote on something (keywords: vote, eliminate, choose, pick)
   - "challenge" = Competition or task (keywords: compete, challenge, win, compete for)
   - "tribunal" = Someone is accused/defended (keywords: accused, defend, tribunal, trial)
   - "summit" = Special meeting with specific roles (keywords: summit, council, panel)

2. Identify roles by analyzing who does what:
   - JUDGES: People who evaluate/decide/vote on others' actions
   - PARTICIPANTS: People who perform/reveal/compete/submit something to be judged
   - SPECTATORS: Everyone else just watching

3. Determine if custom UI is needed:
   - YES if: judges present, voting system, special challenge mechanics, role-based interaction
   - NO if: everyone just responds normally with their thoughts

4. Choose UI template:
   - "standard" = Normal response page
   - "judge-panel" = Judges review and vote on participants
   - "voting-booth" = Everyone votes on something
   - "challenge-arena" = Competition interface with scoring
   - "tribunal-court" = Accusation/defense interface

5. Extract keywords that helped you decide (judge, vote, reveal, compete, etc.)

6. Rate your confidence 0-100 based on clarity of the scenario structure

Return ONLY valid JSON with this exact structure:
{
  "eventType": "judge" | "vote" | "challenge" | "tribunal" | "summit" | "standard",
  "roles": {
    "judges": ["cast member names who judge"],
    "participants": ["cast member names who are judged/compete"],
    "spectators": ["cast member names who just watch"]
  },
  "customUINeeded": true | false,
  "uiTemplate": "standard" | "judge-panel" | "voting-booth" | "challenge-arena" | "tribunal-court",
  "detectedKeywords": ["keyword1", "keyword2"],
  "confidence": 85
}`

  console.log('🤖 Calling Claude for scenario analysis...')

  const message = await anthropic.messages.create({
    model: 'claude-sonnet-4-5-20250929',
    max_tokens: 2000,
    messages: [{
      role: 'user',
      content: prompt
    }]
  })

  const responseText = message.content[0].type === 'text'
    ? message.content[0].text
    : ''

  // Extract JSON from response
  const jsonMatch = responseText.match(/\{[\s\S]*\}/)
  if (!jsonMatch) {
    throw new Error('Failed to parse Claude response as JSON')
  }

  const analysis = JSON.parse(jsonMatch[0]) as ScenarioAnalysis
  analysis.scenarioId = scenario.id

  return analysis
}

async function saveAnalysis(
  supabase: any,
  scenarioId: string,
  analysis: ScenarioAnalysis
) {
  // Update scenarios table with analysis
  const { error: updateError } = await supabase
    .from('scenarios')
    .update({
      event_type: analysis.eventType,
      roles: analysis.roles,
      ui_template: analysis.uiTemplate,
      custom_ui_needed: analysis.customUINeeded,
      analyzed_at: new Date().toISOString(),
      analysis_confidence: analysis.confidence
    })
    .eq('id', scenarioId)

  if (updateError) {
    console.error('Error saving analysis:', updateError)
    throw updateError
  }

  // Save detailed analysis for debugging
  const { error: insertError } = await supabase
    .from('scenario_analyses')
    .insert({
      scenario_id: scenarioId,
      event_type: analysis.eventType,
      roles: analysis.roles,
      ui_template: analysis.uiTemplate,
      custom_ui_needed: analysis.customUINeeded,
      detected_keywords: analysis.detectedKeywords,
      confidence: analysis.confidence
    })

  if (insertError) {
    console.error('Error inserting analysis record:', insertError)
    // Don't throw - this is just for logging
  }
}
