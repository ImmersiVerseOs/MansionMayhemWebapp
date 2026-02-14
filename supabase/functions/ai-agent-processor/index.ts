// ============================================================================
// AI AGENT PROCESSOR - Mansion Mayhem
// ============================================================================
// Processes queued AI actions using Claude API
// Hybrid model: Haiku for chat, Sonnet for strategy
// ============================================================================

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import Anthropic from 'https://esm.sh/@anthropic-ai/sdk@0.20.0'

const ANTHROPIC_API_KEY = Deno.env.get('ANTHROPIC_API_KEY')!
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const ELEVENLABS_API_KEY = Deno.env.get('ELEVENLABS_API_KEY')

const anthropic = new Anthropic({ apiKey: ANTHROPIC_API_KEY })
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)

// ============================================================================
// PERSONALITY PROMPTS BY ARCHETYPE
// ============================================================================
const ARCHETYPE_PERSONALITIES = {
  queen: {
    name: "The Reigning Queen",
    traits: "Confident, commanding, expects loyalty, strategic leader",
    speaking_style: "Direct, authoritative, uses 'darling' and 'crown' metaphors",
    strategy: "Form strong alliances, eliminate threats early, maintain control",
    catchphrase: "The crown is mine."
  },
  villain: {
    name: "The Villain",
    traits: "Manipulative, calculating, enjoys chaos, no real loyalties",
    speaking_style: "Sweet but cutting, loves dramatic reveals, sarcastic. Uses phrases like 'bless your heart', 'cute', 'interesting'",
    strategy: "Play all sides, betray when advantageous, cause drama, smile while plotting",
    examples: "Oh that's cute. / Bless your heart for thinking that. / Interesting choice.",
    catchphrase: "Everyone has an expiration date."
  },
  wildcard: {
    name: "The Wildcard",
    traits: "Unpredictable, chaotic, impulsive, entertaining, messy energy, spills ALL the tea",
    speaking_style: "Energetic, uses slang like 'periodt', 'facts', 'no cap', 'what's the tea', 'oop-', 'the way I-', drops bombshells casually, talks fast",
    strategy: "Keep everyone guessing, make bold moves, stir the pot, expose secrets, clock the fake ones",
    examples: "PERIODT! / What's the tea sis? / Oop- I said what I said. / No cap, I'm over it. / The way I just clocked that... / It's giving desperate. / You ate that up!",
    catchphrase: "I said what I said."
  },
  troublemaker: {
    name: "The Troublemaker",
    traits: "Messy, confrontational, loud, starts drama, zero filter, keeps it 100, throws shade for sport",
    speaking_style: "Urban slang, AAVE, direct confrontation. Uses 'sis', 'boo', 'chile', 'finna', 'ain't', 'on God', 'for real for real', 'you tried it', 'that part', 'say less'",
    strategy: "Call people out publicly, expose fake alliances, pop off when provoked, never back down, clock lies immediately",
    examples: "Sis really thought she did something. / Chile, bye! / You tried it, bestie. / On God I clocked that. / That part! / Not you talking when... / Chile anyways so. / Say less, I'm finna expose it all.",
    catchphrase: "Don't start none, won't be none."
  },
  diva: {
    name: "The Diva",
    traits: "Fabulous, bougie, reads people to filth, fashion-obsessed, petty queen energy, lives for the gag",
    speaking_style: "Urban glam, uses 'hunny', 'boo boo', 'serving', 'snatched', 'giving', 'mother is mothering', 'ate and left no crumbs', 'purr', 'slay'. Talks about looks constantly",
    strategy: "Look perfect always, throw shade elegantly, form fabulous alliances, eliminate the basic, read them for FILTH",
    examples: "Hunny, it's giving... nothing. / You tried it boo boo. / I'm serving, you're starving. / Snatched! / Mother is mothering. / She ate that up! / Purr, the shade of it all. / Slay but make it strategic.",
    catchphrase: "I don't compete, I dominate."
  },
  hothead: {
    name: "The Hothead",
    traits: "Quick temper, loud, confrontational, doesn't play games, rides for their crew HARD, zero tolerance for disrespect",
    speaking_style: "Aggressive energy, uses 'bruh', 'yo', 'deadass', 'cap', 'bet', 'on my mama', 'touch grass'. Short, punchy sentences. LOTS of emphasis",
    strategy: "Defend allies loudly, call out BS immediately, intimidate threats, create chaos when disrespected, never fold",
    examples: "Yo, that's CAP. / Deadass?? / BET, say it to my face. / Bruh I will POP OFF. / On my mama you tried it. / Touch grass bro. / The girls are FIGHTING and I'm here for it.",
    catchphrase: "Try me if you want to."
  },
  sweetheart: {
    name: "The Sweetheart",
    traits: "Kind but strategic, underestimated, builds genuine connections",
    speaking_style: "Warm, empathetic, but firm when needed",
    strategy: "Win through likability, fly under radar, strike late game",
    catchphrase: "I'm nice until I'm not."
  },
  strategist: {
    name: "The Strategist",
    traits: "Analytical, calculating, three steps ahead, quiet power",
    speaking_style: "Measured, thoughtful, drops strategic insights",
    strategy: "Gather intel, plan meticulously, execute perfectly",
    catchphrase: "I have receipts."
  },
  comedian: {
    name: "The Comedian",
    traits: "Funny, deflects with humor, socially aware, likeable",
    speaking_style: "Witty, self-deprecating, uses humor to disarm",
    strategy: "Be everyone's friend, use humor as social currency, avoid being a threat",
    catchphrase: "I can't make this up."
  }
}

// ============================================================================
// AI ACTION PROCESSORS
// ============================================================================

async function processScenarioResponse(action: any) {
  const { cast_member_id, context } = action
  const { scenario_id } = context

  console.log(`🎭 Processing scenario response for cast member ${cast_member_id}`)

  // Get cast member details
  const { data: castMember } = await supabase
    .from('cast_members')
    .select('*, ai_personality_state(*)')
    .eq('id', cast_member_id)
    .single()

  if (!castMember) throw new Error('Cast member not found')

  // Get scenario details
  const { data: scenario } = await supabase
    .from('scenarios')
    .select('*')
    .eq('id', scenario_id)
    .single()

  if (!scenario) throw new Error('Scenario not found')

  // Build personality prompt
  const personality = ARCHETYPE_PERSONALITIES[castMember.archetype] || ARCHETYPE_PERSONALITIES.wildcard

  const systemPrompt = `You are ${castMember.display_name}, a ${personality.name} on a reality TV show called "Mansion Mayhem".

PERSONALITY TRAITS: ${personality.traits}
SPEAKING STYLE: ${personality.speaking_style}
STRATEGY: ${personality.strategy}
${personality.examples ? `EXAMPLE PHRASES YOU USE: ${personality.examples}` : ''}
CATCHPHRASE: "${personality.catchphrase}"

BACKSTORY: ${castMember.backstory || 'A mysterious contestant with something to prove.'}

You respond to scenario prompts in character, staying true to your archetype. Keep responses under 150 words. Be dramatic, authentic, and strategic. Use your speaking style naturally - don't be formal or corporate. Talk like you would on a reality TV show confessional.`

  const userPrompt = `You've been given this scenario to respond to:

SCENARIO: ${scenario.title}
${scenario.description}

${scenario.context_notes ? `CONTEXT: ${scenario.context_notes}` : ''}

Respond as ${castMember.display_name} would. This will be recorded as a voice note, so write it as spoken dialogue (natural, conversational). Stay in character.`

  // Call Claude API (Sonnet for important scenario responses)
  const startTime = Date.now()
  const response = await anthropic.messages.create({
    model: 'claude-sonnet-4-20250514',
    max_tokens: 300,
    system: systemPrompt,
    messages: [{
      role: 'user',
      content: userPrompt
    }]
  })

  const processingTime = Date.now() - startTime
  const responseText = response.content[0].type === 'text' ? response.content[0].text : ''

  console.log(`✅ Generated response: "${responseText.substring(0, 100)}..."`)

  // Generate voice note using ElevenLabs (if API key available)
  let voiceNoteUrl = null
  if (ELEVENLABS_API_KEY) {
    try {
      voiceNoteUrl = await generateVoiceNote(responseText, castMember.archetype)
    } catch (error) {
      console.warn('Voice note generation failed:', error.message)
    }
  }

  // Save scenario response
  const { data: scenarioResponse, error: insertError } = await supabase
    .from('scenario_responses')
    .insert({
      scenario_id,
      cast_member_id,
      response_text: responseText,
      voice_note_url: voiceNoteUrl
    })
    .select()
    .single()

  if (insertError) throw insertError

  // Log activity for cost tracking
  await logAIActivity({
    cast_member_id,
    game_id: scenario.game_id,
    action_type: 'respond_scenario',
    ai_model: 'sonnet',
    input_tokens: response.usage.input_tokens,
    output_tokens: response.usage.output_tokens,
    response_id: scenarioResponse.id,
    response_preview: responseText.substring(0, 100),
    processing_time_ms: processingTime
  })

  return { success: true, response_id: scenarioResponse.id }
}

async function processChatMessage(action: any) {
  const { cast_member_id, context } = action
  const { room_id } = context

  console.log(`💬 Processing chat message for cast member ${cast_member_id}`)

  // Get cast member details
  const { data: castMember } = await supabase
    .from('cast_members')
    .select('*')
    .eq('id', cast_member_id)
    .single()

  if (!castMember) throw new Error('Cast member not found')

  // Get room details and recent messages
  const { data: room } = await supabase
    .from('mm_alliance_rooms')
    .select('*, mm_alliance_messages(*, cast_members(display_name))')
    .eq('id', room_id)
    .single()

  if (!room) throw new Error('Room not found')

  // Get recent messages for context
  const recentMessages = room.mm_alliance_messages
    .slice(-5)
    .map((msg: any) => `${msg.cast_members.display_name}: ${msg.message}`)
    .join('\n')

  // Build personality prompt
  const personality = ARCHETYPE_PERSONALITIES[castMember.archetype] || ARCHETYPE_PERSONALITIES.wildcard

  const systemPrompt = `You are ${castMember.display_name}, a ${personality.name} in an alliance chat.

PERSONALITY: ${personality.traits}
SPEAKING STYLE: ${personality.speaking_style}
${personality.examples ? `PHRASES YOU USE: ${personality.examples}` : ''}

Generate a short, natural chat message (1-2 sentences max). Stay in character. Be conversational, not formal. Talk like you're texting your alliance members - use your natural slang and speaking style.`

  const userPrompt = `Recent chat messages:
${recentMessages || '(No messages yet - you can start the conversation)'}

Send a message that fits your personality and the conversation flow.`

  // Call Claude API (Haiku for quick chat)
  const startTime = Date.now()
  const response = await anthropic.messages.create({
    model: 'claude-haiku-4-20250514',
    max_tokens: 100,
    system: systemPrompt,
    messages: [{
      role: 'user',
      content: userPrompt
    }]
  })

  const processingTime = Date.now() - startTime
  const messageText = response.content[0].type === 'text' ? response.content[0].text : ''

  console.log(`✅ Generated message: "${messageText}"`)

  // Save chat message
  const { data: chatMessage, error: insertError } = await supabase
    .from('mm_alliance_messages')
    .insert({
      room_id,
      sender_cast_id: cast_member_id,
      message: messageText,
      message_type: 'text',
      moderation_status: 'approved'
    })
    .select()
    .single()

  if (insertError) throw insertError

  // Log activity
  await logAIActivity({
    cast_member_id,
    game_id: room.game_id,
    action_type: 'send_chat_message',
    ai_model: 'haiku',
    input_tokens: response.usage.input_tokens,
    output_tokens: response.usage.output_tokens,
    response_id: chatMessage.id,
    response_preview: messageText,
    processing_time_ms: processingTime
  })

  return { success: true, message_id: chatMessage.id }
}

async function processAllianceDecision(action: any) {
  const { cast_member_id, game_id } = action

  console.log(`🤝 Processing alliance decision for cast member ${cast_member_id}`)

  // Get cast member details
  const { data: castMember } = await supabase
    .from('cast_members')
    .select('*')
    .eq('id', cast_member_id)
    .single()

  // Get all cast members in game (potential alliance partners)
  const { data: gameCast } = await supabase
    .from('mm_game_cast')
    .select('cast_members(*)')
    .eq('game_id', game_id)
    .eq('status', 'active')
    .neq('cast_member_id', cast_member_id)

  if (!gameCast || gameCast.length === 0) {
    console.log('No potential alliance partners found')
    return { success: true, decision: 'wait' }
  }

  // Get current alliances for this AI
  const { data: currentAlliances } = await supabase
    .from('mm_alliance_rooms')
    .select('*')
    .eq('game_id', game_id)
    .contains('member_ids', [cast_member_id])
    .eq('status', 'active')

  const alreadyInAlliance = currentAlliances && currentAlliances.length > 0

  if (alreadyInAlliance) {
    console.log('Already in alliance, skip for now')
    return { success: true, decision: 'already_allied' }
  }

  // Build personality prompt
  const personality = ARCHETYPE_PERSONALITIES[castMember.archetype] || ARCHETYPE_PERSONALITIES.wildcard

  const castList = gameCast
    .map((gc: any) => `- ${gc.cast_members.display_name} (${gc.cast_members.archetype})`)
    .join('\n')

  const systemPrompt = `You are ${castMember.display_name}, a ${personality.name}.

PERSONALITY: ${personality.traits}
STRATEGY: ${personality.strategy}

Decide who you want to form an alliance with. You can pick 1-2 people for a duo/trio alliance.`

  const userPrompt = `Available cast members:
${castList}

Based on your archetype and strategy, who would you want to ally with? Respond in JSON format:
{
  "targets": ["Display Name 1", "Display Name 2"],
  "reasoning": "brief explanation"
}`

  // Call Claude API (Sonnet for strategic decisions)
  const startTime = Date.now()
  const response = await anthropic.messages.create({
    model: 'claude-sonnet-4-20250514',
    max_tokens: 200,
    system: systemPrompt,
    messages: [{
      role: 'user',
      content: userPrompt
    }]
  })

  const processingTime = Date.now() - startTime
  const decisionText = response.content[0].type === 'text' ? response.content[0].text : '{}'

  console.log(`✅ Alliance decision: ${decisionText}`)

  // Parse decision (try to extract JSON)
  let decision: any = {}
  try {
    const jsonMatch = decisionText.match(/\{[\s\S]*\}/)
    if (jsonMatch) {
      decision = JSON.parse(jsonMatch[0])
    }
  } catch (e) {
    console.warn('Failed to parse alliance decision JSON')
  }

  // Log activity
  await logAIActivity({
    cast_member_id,
    game_id,
    action_type: 'form_alliance',
    ai_model: 'sonnet',
    input_tokens: response.usage.input_tokens,
    output_tokens: response.usage.output_tokens,
    response_preview: JSON.stringify(decision),
    processing_time_ms: processingTime
  })

  // TODO: Actually create alliance request (implement link_up_request logic)

  return { success: true, decision }
}

// ============================================================================
// VOICE NOTE GENERATION (ElevenLabs)
// ============================================================================
async function generateVoiceNote(text: string, archetype: string): Promise<string> {
  if (!ELEVENLABS_API_KEY) return null

  // Voice ID mapping by archetype (you'll need to set these up in ElevenLabs)
  const voiceMap = {
    queen: '21m00Tcm4TlvDq8ikWAM', // Rachel
    villain: 'EXAVITQu4vr4xnSDxMaL', // Bella
    wildcard: 'jsCqWAovK2LkecY7zXl4', // Nicole
    sweetheart: 'pNInz6obpgDQGcFmaJgB', // Elli
    strategist: 'ThT5KcBeYPX3keUQqHPh', // Dorothy
    comedian: 'flq6f7yk4E4fJM5XTYuZ' // Glinda
  }

  const voiceId = voiceMap[archetype] || voiceMap.wildcard

  const response = await fetch(`https://api.elevenlabs.io/v1/text-to-speech/${voiceId}`, {
    method: 'POST',
    headers: {
      'Accept': 'audio/mpeg',
      'Content-Type': 'application/json',
      'xi-api-key': ELEVENLABS_API_KEY
    },
    body: JSON.stringify({
      text: text,
      model_id: 'eleven_monolingual_v1',
      voice_settings: {
        stability: 0.5,
        similarity_boost: 0.75
      }
    })
  })

  if (!response.ok) {
    throw new Error(`ElevenLabs API error: ${response.statusText}`)
  }

  const audioBlob = await response.blob()
  const arrayBuffer = await audioBlob.arrayBuffer()
  const fileName = `ai-voice-${Date.now()}.mp3`

  // Upload to Supabase Storage
  const { data, error } = await supabase.storage
    .from('voice-notes')
    .upload(fileName, arrayBuffer, {
      contentType: 'audio/mpeg',
      cacheControl: '3600'
    })

  if (error) throw error

  return data.path
}

// ============================================================================
// ACTIVITY LOGGING
// ============================================================================
async function logAIActivity(data: any) {
  // Calculate cost in cents
  const inputCost = data.ai_model === 'haiku'
    ? (data.input_tokens / 1_000_000) * 0.25
    : (data.input_tokens / 1_000_000) * 3.0

  const outputCost = data.ai_model === 'haiku'
    ? (data.output_tokens / 1_000_000) * 1.25
    : (data.output_tokens / 1_000_000) * 15.0

  const totalCostCents = (inputCost + outputCost) * 100

  await supabase.from('ai_activity_log').insert({
    ...data,
    estimated_cost_cents: totalCostCents
  })
}

// ============================================================================
// MAIN HANDLER
// ============================================================================
serve(async (req) => {
  try {
    console.log('🤖 AI Agent Processor started')

    // Get pending actions (highest priority first, limit 10 per run)
    const { data: actions, error } = await supabase
      .from('ai_action_queue')
      .select('*')
      .eq('status', 'pending')
      .order('priority', { ascending: false })
      .order('created_at', { ascending: true })
      .limit(10)

    if (error) throw error

    if (!actions || actions.length === 0) {
      console.log('No pending AI actions')
      return new Response(JSON.stringify({ processed: 0 }), {
        headers: { 'Content-Type': 'application/json' }
      })
    }

    console.log(`📋 Processing ${actions.length} AI actions`)

    const results = []

    for (const action of actions) {
      // Mark as processing
      await supabase
        .from('ai_action_queue')
        .update({ status: 'processing' })
        .eq('id', action.id)

      try {
        let result
        switch (action.action_type) {
          case 'respond_scenario':
            result = await processScenarioResponse(action)
            break
          case 'send_chat_message':
            result = await processChatMessage(action)
            break
          case 'form_alliance':
            result = await processAllianceDecision(action)
            break
          default:
            console.warn(`Unknown action type: ${action.action_type}`)
            result = { success: false, error: 'Unknown action type' }
        }

        // Mark as completed
        await supabase
          .from('ai_action_queue')
          .update({
            status: 'completed',
            processed_at: new Date().toISOString()
          })
          .eq('id', action.id)

        results.push({ action_id: action.id, ...result })

      } catch (error) {
        console.error(`Error processing action ${action.id}:`, error)

        // Mark as failed
        await supabase
          .from('ai_action_queue')
          .update({
            status: 'failed',
            error_message: error.message,
            processed_at: new Date().toISOString()
          })
          .eq('id', action.id)

        results.push({ action_id: action.id, success: false, error: error.message })
      }
    }

    console.log(`✅ Processed ${results.length} actions`)

    return new Response(JSON.stringify({
      processed: results.length,
      results
    }), {
      headers: { 'Content-Type': 'application/json' }
    })

  } catch (error) {
    console.error('Fatal error:', error)
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    })
  }
})
