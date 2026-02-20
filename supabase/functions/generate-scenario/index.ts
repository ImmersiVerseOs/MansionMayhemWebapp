// Supabase Edge Function: AI Scenario Generation
// Rewritten from OpenAI to Anthropic Claude (2026-02-20)
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import Anthropic from 'https://esm.sh/@anthropic-ai/sdk@0.24.0'

const ANTHROPIC_API_KEY = Deno.env.get('ANTHROPIC_API_KEY')!
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

interface ScenarioRequest {
  gameId: string
  queueId?: string
  scenarioType?: string
  targetCastCount?: number
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { gameId, queueId, scenarioType, targetCastCount }: ScenarioRequest = await req.json()

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
    const anthropic = new Anthropic({ apiKey: ANTHROPIC_API_KEY })

    // Update queue status to processing
    if (queueId) {
      await supabase
        .from('ai_scenario_queue')
        .update({ status: 'processing', processing_started_at: new Date().toISOString() })
        .eq('id', queueId)
    }

    // Get game details
    const { data: game, error: gameError } = await supabase
      .from('mm_games')
      .select('*, profiles:creator_id(full_name)')
      .eq('id', gameId)
      .single()

    if (gameError || !game) {
      throw new Error('Game not found')
    }

    // Get active cast members
    const { data: castMembers } = await supabase
      .from('mm_game_cast')
      .select(`
        id,
        cast_member_id,
        cast_members (
          id,
          full_name,
          display_name,
          archetype,
          personality_traits,
          backstory
        )
      `)
      .eq('game_id', gameId)
      .in('status', ['joined', 'active'])
      .limit(50)

    if (!castMembers || castMembers.length === 0) {
      throw new Error('No active cast members in game')
    }

    // Get recent scenarios for context
    const { data: recentScenarios } = await supabase
      .from('scenarios')
      .select('id, title, scenario_type, created_at')
      .eq('game_id', gameId)
      .order('created_at', { ascending: false })
      .limit(5)

    // Get recent responses for drama context
    const { data: recentResponses } = await supabase
      .from('scenario_responses')
      .select(`
        response_text,
        cast_members!inner(full_name, archetype)
      `)
      .in('scenario_id', (recentScenarios || []).map(s => s.id))
      .limit(10)

    // Build context for AI
    const context = buildScenarioContext({
      game,
      castMembers,
      recentScenarios,
      recentResponses,
      scenarioType
    })

    console.log('Generating scenario with Claude...')

    // Generate scenario with Claude
    const message = await anthropic.messages.create({
      model: 'claude-sonnet-4-20250514',
      max_tokens: 1000,
      system: getSystemPrompt(game.theme),
      messages: [{
        role: 'user',
        content: context
      }]
    })

    const responseText = message.content[0].type === 'text' ? message.content[0].text : ''

    // Extract JSON from response (handle markdown code blocks)
    const jsonMatch = responseText.match(/\{[\s\S]*\}/)
    if (!jsonMatch) {
      throw new Error('AI did not return valid JSON')
    }

    const aiResponse = JSON.parse(jsonMatch[0])

    console.log('AI generated scenario:', aiResponse)

    // Validate AI response
    if (!aiResponse.title || !aiResponse.prompt || !aiResponse.options) {
      throw new Error('Invalid AI response format')
    }

    // Calculate deadline
    const deadlineHours = aiResponse.deadline_hours || 24
    const deadlineAt = new Date(Date.now() + deadlineHours * 60 * 60 * 1000)

    // Create scenario in database
    const { data: scenario, error: scenarioError } = await supabase
      .from('scenarios')
      .insert({
        game_id: gameId,
        title: aiResponse.title,
        scenario_type: aiResponse.scenario_type || scenarioType || 'drama',
        prompt_text: aiResponse.prompt,
        deadline_hours: deadlineHours,
        deadline_at: deadlineAt.toISOString(),
        voice_note_setting: 'encouraged',
        status: 'active',
        launched_at: new Date().toISOString(),
        is_ai_generated: true,
        ai_generation_metadata: {
          model: 'claude-sonnet-4-20250514',
          generated_at: new Date().toISOString(),
          input_tokens: message.usage?.input_tokens,
          output_tokens: message.usage?.output_tokens
        }
      })
      .select()
      .single()

    if (scenarioError) {
      throw scenarioError
    }

    // Create response options
    const options = aiResponse.options.slice(0, 4).map((opt: any, index: number) => ({
      scenario_id: scenario.id,
      option_number: index + 1,
      option_text: opt.text,
      option_tag: opt.tag || 'custom'
    }))

    const { error: optionsError } = await supabase
      .from('response_options')
      .insert(options)

    if (optionsError) {
      throw optionsError
    }

    // Target cast members
    const targetCount = targetCastCount || Math.min(castMembers.length, 5)
    const selectedCast = selectCastForScenario(castMembers, aiResponse, targetCount)

    const targets = selectedCast.map(cm => ({
      scenario_id: scenario.id,
      cast_member_id: cm.cast_members.id,
      notified_at: new Date().toISOString()
    }))

    const { error: targetsError } = await supabase
      .from('scenario_targets')
      .insert(targets)

    if (targetsError) {
      throw targetsError
    }

    // Update total targets count
    await supabase
      .from('scenarios')
      .update({ total_targets: targets.length })
      .eq('id', scenario.id)

    // Update queue status
    if (queueId) {
      await supabase
        .from('ai_scenario_queue')
        .update({
          status: 'generated',
          generated_scenario_id: scenario.id,
          generated_title: scenario.title,
          generated_prompt: scenario.prompt_text,
          processed_at: new Date().toISOString(),
          generation_metadata: {
            model: 'claude-sonnet-4-20250514',
            tokens_used: (message.usage?.input_tokens || 0) + (message.usage?.output_tokens || 0)
          }
        })
        .eq('id', queueId)
    }

    console.log('Scenario created successfully:', scenario.id)

    return new Response(
      JSON.stringify({
        success: true,
        scenario: {
          id: scenario.id,
          title: scenario.title,
          scenario_type: scenario.scenario_type,
          targets_count: targets.length,
          deadline_at: scenario.deadline_at
        }
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      }
    )

  } catch (error) {
    console.error('Error generating scenario:', error)

    // Update queue with error if applicable
    try {
      const body = await req.clone().json()
      if (body.queueId) {
        const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
        await supabase
          .from('ai_scenario_queue')
          .update({
            status: 'failed',
            error_message: error.message,
            processed_at: new Date().toISOString()
          })
          .eq('id', body.queueId)
      }
    } catch (_) {
      // Ignore errors in error handler
    }

    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500
      }
    )
  }
})

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

function getSystemPrompt(theme: string): string {
  const themePrompts = {
    bachelor: 'You are a creative director for a Bachelor/Bachelorette reality show.',
    'love-island': 'You are a creative director for Love Island.',
    'big-brother': 'You are a creative director for Big Brother.',
    survivor: 'You are a creative director for Survivor.',
    default: 'You are a creative director for a dramatic reality TV show.'
  }

  const basePrompt = themePrompts[theme as keyof typeof themePrompts] || themePrompts.default

  return `${basePrompt}

Your job is to create dramatic, engaging scenarios that will generate authentic reactions from cast members.

Create scenarios that:
- Are realistic and believable within the show's context
- Create tension, drama, or emotional moments
- Give cast members meaningful choices
- Lead to interesting character development
- Can be responded to in 1-2 paragraphs

Return a JSON object with this exact structure:
{
  "title": "Short catchy title (max 60 chars)",
  "scenario_type": "confrontation|alliance|revelation|betrayal|challenge|elimination",
  "prompt": "The scenario text that cast will see (2-3 sentences describing the situation)",
  "options": [
    {"text": "Option 1 description", "tag": "aggressive|diplomatic|strategic|passive"},
    {"text": "Option 2 description", "tag": "aggressive|diplomatic|strategic|passive"},
    {"text": "Option 3 description", "tag": "aggressive|diplomatic|strategic|passive"},
    {"text": "Option 4 description", "tag": "aggressive|diplomatic|strategic|passive"}
  ],
  "deadline_hours": 24,
  "reasoning": "Brief explanation of why this scenario works"
}`
}

function buildScenarioContext(data: any): string {
  const { game, castMembers, recentScenarios, recentResponses, scenarioType } = data

  const castList = castMembers
    .map((cm: any) => {
      const c = cm.cast_members
      return `- ${c.full_name} (${c.archetype}): ${c.backstory || 'No backstory'}`
    })
    .join('\n')

  const recentScenariosList = recentScenarios && recentScenarios.length > 0
    ? recentScenarios.map((s: any) => `- "${s.title}" (${s.scenario_type})`).join('\n')
    : 'No recent scenarios'

  const recentDrama = recentResponses && recentResponses.length > 0
    ? recentResponses.slice(0, 5).map((r: any) =>
        `- ${r.cast_members?.full_name}: "${r.response_text?.substring(0, 100)}..."`
      ).join('\n')
    : 'No recent drama'

  return `Generate a dramatic scenario for "${game.title}".

CAST MEMBERS:
${castList}

RECENT SCENARIOS:
${recentScenariosList}

RECENT DRAMA/RESPONSES:
${recentDrama}

${scenarioType ? `REQUESTED TYPE: ${scenarioType}` : ''}

Create a scenario that builds on existing tensions, introduces new drama, or deepens character relationships. Make it compelling and authentic to the show's tone.`
}

function selectCastForScenario(castMembers: any[], aiResponse: any, targetCount: number): any[] {
  // Simple selection: take first N cast members
  return castMembers.slice(0, targetCount)
}
