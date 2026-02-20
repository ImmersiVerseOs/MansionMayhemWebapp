// Supabase Edge Function: AI Auto-Response for Inactive Cast
// Rewritten from OpenAI to Anthropic Claude (2026-02-20)
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import Anthropic from 'https://esm.sh/@anthropic-ai/sdk@0.24.0'

const ANTHROPIC_API_KEY = Deno.env.get('ANTHROPIC_API_KEY')!
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

interface AutoResponseRequest {
  scenarioId?: string
  checkAll?: boolean // Check all expiring scenarios
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { scenarioId, checkAll }: AutoResponseRequest = await req.json()

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
    const anthropic = new Anthropic({ apiKey: ANTHROPIC_API_KEY })

    let scenariosToProcess = []

    if (checkAll) {
      // Find scenarios expiring in next 30 minutes with missing responses
      const thirtyMinutesFromNow = new Date(Date.now() + 30 * 60 * 1000).toISOString()

      const { data: expiringScenarios } = await supabase
        .from('scenarios')
        .select('id, title, prompt_text, deadline_at, game_id')
        .eq('status', 'active')
        .lt('deadline_at', thirtyMinutesFromNow)
        .gt('deadline_at', new Date().toISOString())

      scenariosToProcess = expiringScenarios || []
      console.log(`Found ${scenariosToProcess.length} scenarios expiring in next 30 minutes`)

    } else if (scenarioId) {
      const { data: scenario } = await supabase
        .from('scenarios')
        .select('id, title, prompt_text, deadline_at, game_id')
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

      // Get all targets for this scenario
      const { data: targets } = await supabase
        .from('scenario_targets')
        .select(`
          cast_member_id,
          cast_members (
            id,
            user_id,
            full_name,
            display_name,
            archetype,
            personality_traits,
            backstory
          )
        `)
        .eq('scenario_id', scenario.id)

      if (!targets || targets.length === 0) continue

      // Get existing responses
      const { data: existingResponses } = await supabase
        .from('scenario_responses')
        .select('user_id')
        .eq('scenario_id', scenario.id)

      const respondedUserIds = new Set(
        existingResponses?.map(r => r.user_id) || []
      )

      // Get response options
      const { data: options } = await supabase
        .from('response_options')
        .select('option_number, option_text, option_tag')
        .eq('scenario_id', scenario.id)
        .order('option_number')

      // Generate responses for non-responders
      for (const target of targets) {
        const cast = target.cast_members

        if (respondedUserIds.has(cast.user_id)) {
          console.log(`${cast.full_name} already responded, skipping`)
          continue
        }

        console.log(`Generating auto-response for ${cast.full_name}...`)

        try {
          // Generate character-aware response using Claude
          const message = await anthropic.messages.create({
            model: 'claude-sonnet-4-20250514',
            max_tokens: 500,
            system: getCharacterSystemPrompt(cast),
            messages: [{
              role: 'user',
              content: `You're in this situation:\n\n${scenario.prompt_text}\n\nYour options are:\n${options?.map(o => `${o.option_number}. ${o.option_text}`).join('\n')}\n\nRespond in character with which option you choose and why (1-2 paragraphs).`
            }]
          })

          const aiResponse = message.content[0].type === 'text' ? message.content[0].text : ''

          // Extract chosen option number from response
          const chosenOption = extractChosenOption(aiResponse, options?.length || 4)

          // Create response in database
          const { data: response, error: responseError } = await supabase
            .from('scenario_responses')
            .insert({
              scenario_id: scenario.id,
              user_id: cast.user_id,
              response_text: aiResponse,
              chosen_option: chosenOption,
              is_ai_generated: true,
              ai_generation_metadata: {
                model: 'claude-sonnet-4-20250514',
                generated_at: new Date().toISOString(),
                character: cast.full_name,
                archetype: cast.archetype,
                input_tokens: message.usage?.input_tokens,
                output_tokens: message.usage?.output_tokens
              },
              created_at: new Date().toISOString()
            })
            .select()
            .single()

          if (responseError) {
            console.error(`Error creating response for ${cast.full_name}:`, responseError)
            continue
          }

          responsesGenerated++
          results.push({
            cast_member: cast.full_name,
            scenario: scenario.title,
            response_id: response.id,
            success: true
          })

          console.log(`✓ Generated response for ${cast.full_name}`)

          // Small delay to avoid rate limits
          await new Promise(resolve => setTimeout(resolve, 1000))

        } catch (error) {
          console.error(`Error generating response for ${cast.full_name}:`, error)
          results.push({
            cast_member: cast.full_name,
            scenario: scenario.title,
            error: error.message,
            success: false
          })
        }
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

  return `You are ${cast.full_name}, a cast member on a reality TV show.

ARCHETYPE: ${cast.archetype || 'wildcard'}
PERSONALITY: ${traitsList}
BACKSTORY: ${cast.backstory || 'No backstory available'}

You must respond authentically to scenarios as this character would. Consider:
- Your archetype and how it influences your decisions
- Your personality traits and typical behavior patterns
- Your backstory and motivations
- The dramatic potential of your choice

Stay in character and make decisions that are true to who ${cast.full_name} is. Be specific, emotional, and authentic. This is reality TV - don't hold back!

Choose one of the provided options and explain your reasoning in 1-2 paragraphs. Start with "I choose option [number]:" and then explain why in character.`
}

function extractChosenOption(response: string, maxOptions: number): number {
  // Try to extract option number from response
  const match = response.match(/option\s+(\d+)/i)
  if (match) {
    const num = parseInt(match[1])
    if (num >= 1 && num <= maxOptions) {
      return num
    }
  }

  // Default to option 1 if can't determine
  return 1
}
