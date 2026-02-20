// Supabase Edge Function: AI Auto-Response for Inactive Cast
// Rewritten from OpenAI to Anthropic Claude (2026-02-20)
// Fixed to match actual DB schema (scenario_responses has: scenario_id, cast_member_id, response_text, voice_note_url)
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import Anthropic from 'https://esm.sh/@anthropic-ai/sdk@0.24.0'

const ANTHROPIC_API_KEY = Deno.env.get('ANTHROPIC_API_KEY')!
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

interface AutoResponseRequest {
  scenarioId?: string
  scenario_id?: string  // Support both naming conventions
  cast_member_id?: string
  checkAll?: boolean
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const body: AutoResponseRequest = await req.json()
    const scenarioId = body.scenarioId || body.scenario_id
    const specificCastMemberId = body.cast_member_id
    const checkAll = body.checkAll

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
    const anthropic = new Anthropic({ apiKey: ANTHROPIC_API_KEY })

    let scenariosToProcess = []

    if (checkAll) {
      // Find scenarios expiring in next 30 minutes with missing responses
      const thirtyMinutesFromNow = new Date(Date.now() + 30 * 60 * 1000).toISOString()

      const { data: expiringScenarios } = await supabase
        .from('scenarios')
        .select('id, title, description, context_notes, deadline_at, game_id')
        .eq('status', 'active')
        .lt('deadline_at', thirtyMinutesFromNow)
        .gt('deadline_at', new Date().toISOString())

      scenariosToProcess = expiringScenarios || []
      console.log(`Found ${scenariosToProcess.length} scenarios expiring in next 30 minutes`)

    } else if (scenarioId) {
      const { data: scenario } = await supabase
        .from('scenarios')
        .select('id, title, description, context_notes, deadline_at, game_id')
        .eq('id', scenarioId)
        .single()

      if (scenario) {
        scenariosToProcess = [scenario]
      }
    }

    let responsesGenerated = 0
    const results = []

    for (const scenario of scenariosToProcess) {
      console.log(`Processing scenario: ${scenario.title}`)

      // Get targets for this scenario
      const { data: targets } = await supabase
        .from('scenario_targets')
        .select(`
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
        .eq('scenario_id', scenario.id)

      if (!targets || targets.length === 0) continue

      // If a specific cast member was requested, filter to just them
      const filteredTargets = specificCastMemberId
        ? targets.filter(t => t.cast_member_id === specificCastMemberId)
        : targets

      // Get existing responses (scenario_responses uses cast_member_id, not user_id)
      const { data: existingResponses } = await supabase
        .from('scenario_responses')
        .select('cast_member_id')
        .eq('scenario_id', scenario.id)

      const respondedCastIds = new Set(
        existingResponses?.map(r => r.cast_member_id) || []
      )

      // Generate responses for non-responders
      for (const target of filteredTargets) {
        const cast = target.cast_members

        if (respondedCastIds.has(target.cast_member_id)) {
          console.log(`${cast.display_name} already responded, skipping`)
          continue
        }

        console.log(`Generating auto-response for ${cast.display_name}...`)

        try {
          // Generate character-aware response using Claude
          const message = await anthropic.messages.create({
            model: 'claude-sonnet-4-20250514',
            max_tokens: 500,
            system: getCharacterSystemPrompt(cast),
            messages: [{
              role: 'user',
              content: `You're in this situation:\n\n**${scenario.title}**\n\n${scenario.description}\n\n${scenario.context_notes ? 'Context: ' + scenario.context_notes + '\n\n' : ''}Respond in character (1-2 paragraphs). Be dramatic, authentic, and true to your archetype.`
            }]
          })

          const aiResponse = message.content[0].type === 'text' ? message.content[0].text : ''

          // Create response in database (matches actual scenario_responses schema)
          const { data: response, error: responseError } = await supabase
            .from('scenario_responses')
            .insert({
              scenario_id: scenario.id,
              cast_member_id: target.cast_member_id,
              response_text: aiResponse
            })
            .select()
            .single()

          if (responseError) {
            console.error(`Error creating response for ${cast.display_name}:`, responseError)
            continue
          }

          responsesGenerated++
          results.push({
            cast_member: cast.display_name,
            scenario: scenario.title,
            response_id: response.id,
            success: true
          })

          console.log(`Generated response for ${cast.display_name}`)

          // Small delay to avoid rate limits
          await new Promise(resolve => setTimeout(resolve, 1000))

        } catch (error) {
          console.error(`Error generating response for ${cast.display_name}:`, error)
          results.push({
            cast_member: cast.display_name,
            scenario: scenario.title,
            error: error.message,
            success: false
          })
        }
      }

      // Update responses_received count on the scenario
      if (responsesGenerated > 0) {
        const { data: totalResponses } = await supabase
          .from('scenario_responses')
          .select('id', { count: 'exact', head: true })
          .eq('scenario_id', scenario.id)

        await supabase
          .from('scenarios')
          .update({ responses_received: totalResponses?.length || responsesGenerated })
          .eq('id', scenario.id)
      }
    }

    console.log(`Generated ${responsesGenerated} auto-responses`)

    return new Response(
      JSON.stringify({
        success: true,
        responses_generated: responsesGenerated,
        scenarios_processed: scenariosToProcess.length,
        results
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      }
    )

  } catch (error) {
    console.error('Error in auto-response generation:', error)

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

function getCharacterSystemPrompt(cast: any): string {
  const traitsList = cast.personality_traits?.join(', ') || 'no specific traits'

  return `You are ${cast.display_name}, a cast member on a reality TV show called Mansion Mayhem.

ARCHETYPE: ${cast.archetype || 'wildcard'}
PERSONALITY: ${traitsList}
BACKSTORY: ${cast.backstory || 'No backstory available'}

You must respond authentically to scenarios as this character would. Consider:
- Your archetype and how it influences your decisions
- Your personality traits and typical behavior patterns
- Your backstory and motivations
- The dramatic potential of your choice

Stay in character and make decisions that are true to who ${cast.display_name} is. Be specific, emotional, and authentic. This is reality TV - don't hold back!`
}
