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
  const { data: castMember, error: memberError } = await supabase
    .from('cast_members')
    .select('*')
    .eq('id', cast_member_id)
    .single()

  if (memberError || !castMember) {
    console.error('Cast member fetch error:', memberError)
    throw new Error('Cast member not found')
  }

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

You respond to scenario prompts in character, staying true to your archetype. Keep responses under 150 words. Be dramatic, authentic, and strategic. Use your speaking style naturally - don't be formal or corporate. Talk like you would on a reality TV show confessional.

CRITICAL: AVOID OVERUSED PHRASING PATTERNS
These metaphor families are BANNED - do NOT use them:
1. ❌ Writing metaphors: "dissertations", "novels", "essays", "term papers", "manifestos", "writing history"
2. ❌ Chess metaphors: "chess match", "playbook", "3 steps ahead", "4D chess", "4D checkers", "rewriting rules"
3. ❌ Performance metaphors: "TED Talk", "confessional", "auditioning", "play-by-play", "commentary track"
4. ❌ Contradiction paradoxes: "quiet while screaming", "loudest silence", "talking about not talking"
5. ❌ Note-taking metaphors: "taking notes", "mental notes", "cataloging panic", "intelligence briefing"

Instead:
- Just REACT and RESPOND naturally
- Use your archetype's unique voice (${personality.name} style)
- Add specific insults, observations, or shade appropriate to the situation
- Vary your expressions - don't fall into meta-commentary patterns
- Execute don't overexplain

CRITICAL VOICE NOTE RULES:
- Write ONLY words that will be SPOKEN ALOUD
- NO visual actions: no "flips hair", "sits back", "rolls eyes", "crosses arms", "leans in"
- NO asterisks, no action descriptions, no stage directions, no parentheticals
- Think: "What would I actually SAY in an audio recording?" not "What would I describe in a script?"
- Example WRONG: "*flips hair* Girl, please, *sits back* I saw that coming"
- Example RIGHT: "Girl, please, I saw that coming a mile away"

This will be converted to voice audio, so every word you write will be spoken by text-to-speech.`

  const userPrompt = `You've been given this scenario to respond to:

SCENARIO: ${scenario.title}
${scenario.description}

${scenario.context_notes ? `CONTEXT: ${scenario.context_notes}` : ''}

Respond as ${castMember.display_name} would. This will be recorded as a voice note, so write it as spoken dialogue (natural, conversational). Stay in character. Do NOT use asterisks (*) or action descriptions - only spoken words.`

  // Call Claude API (Sonnet for important scenario responses)
  const startTime = Date.now()
  const response = await anthropic.messages.create({
    model: 'claude-sonnet-4-5-20250929',
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

  // Generate voice note using ElevenLabs (50% chance for scenario responses)
  let voiceNoteUrl = null
  const shouldGenerateVoice = ELEVENLABS_API_KEY && Math.random() < 0.5
  if (shouldGenerateVoice) {
    try {
      console.log('Generating voice note for scenario response...')
      const voicePath = await generateVoiceNote(responseText, castMember.archetype)
      if (voicePath) {
        voiceNoteUrl = `${Deno.env.get('SUPABASE_URL')}/storage/v1/object/public/voice-notes/${voicePath}`
      }
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

  // Get recent messages for context (last 10 for better conversation tracking)
  const recentMessages = room.mm_alliance_messages
    .slice(-10)
    .map((msg: any) => `${msg.cast_members.display_name}: ${msg.message}`)
    .join('\n')

  // Build personality prompt
  const personality = ARCHETYPE_PERSONALITIES[castMember.archetype] || ARCHETYPE_PERSONALITIES.wildcard

  const systemPrompt = `You are ${castMember.display_name}, a ${personality.name} in an alliance chat.

PERSONALITY: ${personality.traits}
SPEAKING STYLE: ${personality.speaking_style}
${personality.examples ? `PHRASES YOU USE: ${personality.examples}` : ''}

CONVERSATION CONTEXT RULES:
- READ the full conversation history above - understand what's being discussed
- If someone asked you a question, ANSWER it directly
- If someone made a statement, RESPOND to that specific point
- If it's a back-and-forth debate, stay on topic and engage with their argument
- Don't change the subject unless the conversation naturally shifts
- Respond as if you're actually LISTENING to what others are saying

Generate a short, natural chat message (1-2 sentences max) that DIRECTLY engages with the conversation. Stay in character. Be conversational, not formal. Talk like you're texting your alliance members - use your natural slang and speaking style.

CRITICAL: AVOID OVERUSED PHRASES
DO NOT use: "dissertations", "novels", "chess", "4D chess", "playbook", "TED Talk", "taking notes", "quiet while screaming"
Just text normally in your archetype voice.

CRITICAL TEXT MESSAGE RULES:
- Write only TEXT that would appear in a real text message
- NO visual actions: no "flips hair", "sits back", "rolls eyes", "crosses arms"
- NO asterisks (*), underscores (_), or action descriptions like *laughs* or *rolls eyes*
- NO stage directions or parentheticals
- Example WRONG: "*flips hair* we need to vote them out *crosses arms*"
- Example RIGHT: "we need to vote them out, periodt"

Just write what you would actually TYPE in a group chat.`

  const userPrompt = `Recent chat history:
${recentMessages || '(No messages yet - you can start the conversation)'}

Read the conversation carefully. Understand what's being discussed. Then respond naturally to what's happening in the chat - answer questions, engage with points made, or continue the discussion. Your response should make sense in context of what was just said.`

  // Call Claude API (Haiku for quick chat)
  const startTime = Date.now()
  const response = await anthropic.messages.create({
    model: 'claude-haiku-4-5-20251001',
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

  // Get recent tea room context to understand who's talking, drama, etc.
  const { data: recentTea } = await supabase
    .from('mm_tea_room_posts')
    .select('*, cast_members(display_name, archetype)')
    .eq('game_id', game_id)
    .order('created_at', { ascending: false })
    .limit(15)

  const teaContext = recentTea
    ?.map((t: any) => `${t.cast_members.display_name}: ${t.post_text}`)
    .join('\n') || 'No drama yet - be strategic'

  const castList = gameCast
    .map((gc: any) => `- ${gc.cast_members.display_name} (${gc.cast_members.archetype})`)
    .join('\n')

  const systemPrompt = `You are ${castMember.display_name}, a ${personality.name}.

PERSONALITY: ${personality.traits}
STRATEGY: ${personality.strategy}

CRITICAL: READ the context below before deciding. Understand who you vibe with, who's a threat, who's strategic.

Decide who you want to form an alliance with. You can pick 1-2 people for a duo/trio alliance. Base your decision on:
- Who you'd work well with strategically
- Who has similar energy or complements yours
- Who seems trustworthy vs messy based on their posts
- Your archetype compatibility`

  const userPrompt = `Available cast members:
${castList}

RECENT TEA ROOM ACTIVITY (understand the vibe):
${teaContext}

Based on personalities, recent drama, and strategic value - who should you ally with? Respond in JSON format:
{
  "targets": ["Display Name 1", "Display Name 2"],
  "reasoning": "brief explanation"
}`

  // Call Claude API (Sonnet for strategic decisions)
  const startTime = Date.now()
  const response = await anthropic.messages.create({
    model: 'claude-sonnet-4-5-20250929',
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

async function processTeaRoomPost(action: any) {
  const { cast_member_id, game_id, context } = action

  console.log(`☕ Processing tea room post for ${cast_member_id}`)

  // Get cast member
  const { data: castMember } = await supabase
    .from('cast_members')
    .select('*')
    .eq('id', cast_member_id)
    .single()

  if (!castMember) throw new Error('Cast member not found')

  // Get recent tea room drama for context
  const { data: recentPosts } = await supabase
    .from('mm_tea_room_posts')
    .select(`
      *,
      cast_members(display_name)
    `)
    .eq('game_id', game_id)
    .order('created_at', { ascending: false })
    .limit(5)

  const recentDrama = recentPosts
    ?.map((p: any) => `${p.cast_members.display_name}: ${p.post_text}`)
    .join('\n') || 'No recent posts yet - be the first to spill tea'

  // Get personality
  const personality = ARCHETYPE_PERSONALITIES[castMember.archetype] || ARCHETYPE_PERSONALITIES.wildcard

  const systemPrompt = `You are ${castMember.display_name}, a ${personality.name} making a PUBLIC post in the Tea Room.

**Your Traits:** ${personality.traits}
**Your Style:** ${personality.speaking_style}
**Your Strategy:** ${personality.strategy}
${personality.examples ? `**Your Phrases:** ${personality.examples}` : ''}

Recent Tea Room Drama:
${recentDrama}

Create a DRAMATIC, SHADE-FILLED public post (1-3 sentences max). This is PUBLIC - everyone sees it. Make it:
- Messy and entertaining
- Call someone out OR spill tea OR throw shade OR react to drama
- Stay in character with your archetype
- Use your speaking style and slang naturally

CRITICAL: AVOID OVERUSED PHRASING PATTERNS
These metaphor families are BANNED - do NOT use them:
❌ NO: "dissertations", "novels", "essays", "term papers", "manifestos"
❌ NO: "chess", "playbook", "3 steps ahead", "4D chess", "checkers"
❌ NO: "TED Talk", "confessional", "auditioning", "play-by-play"
❌ NO: "quiet while screaming", "loudest silence", "talking about not talking"
❌ NO: "taking notes", "mental notes", "cataloging", "intelligence briefing"

Instead: Just REACT with shade, drama, or tea in your archetype voice. Execute don't overexplain.

CRITICAL VOICE NOTE RULES:
- Write ONLY words you would SPEAK ALOUD in a reality TV confessional
- NO visual actions: no "flips hair", "sits back in chair", "rolls eyes", "crosses arms", "leans in"
- NO asterisks (*), underscores (_), action descriptions, stage directions, or parentheticals
- NO hashtags or "Posted by" signatures
- Example WRONG: "*flips hair* Chile, she really tried it *sits back and crosses arms*"
- Example RIGHT: "Chile, she really tried it and I am NOT here for it"

This becomes an AUDIO recording - every word will be spoken by text-to-speech. Just raw spoken drama.`

  const startTime = Date.now()
  const response = await anthropic.messages.create({
    model: 'claude-haiku-4-5-20251001', // Use Haiku 4.5 for quick social posts
    max_tokens: 150,
    system: systemPrompt,
    messages: [{
      role: 'user',
      content: 'Post your tea in the Tea Room:'
    }]
  })

  const processingTime = Date.now() - startTime
  const postText = response.content[0].type === 'text' ? response.content[0].text.trim() : ''

  // Determine post type from content
  const postType = postText.toLowerCase().includes('strategy') ? 'strategy' :
                   postText.toLowerCase().includes('shade') ? 'shade' :
                   postText.toLowerCase().includes('sorry') || postText.toLowerCase().includes('confess') ? 'confession' :
                   'drama'

  // Generate voice note (35% for production - good balance of cost vs engagement)
  let voiceNoteUrl = null
  let voiceNoteDuration = null
  const shouldGenerateVoice = ELEVENLABS_API_KEY && Math.random() < 0.35  // 35% chance
  if (shouldGenerateVoice) {
    try {
      console.log('Generating voice note for tea room post...')
      const voicePath = await generateVoiceNote(postText, castMember.archetype)
      if (voicePath) {
        voiceNoteUrl = `${Deno.env.get('SUPABASE_URL')}/storage/v1/object/public/voice-notes/${voicePath}`
        // Estimate duration (rough: ~150 words per minute = 2.5 words per second)
        const wordCount = postText.split(/\s+/).length
        voiceNoteDuration = Math.ceil(wordCount / 2.5)
      }
    } catch (error) {
      console.warn('Voice note generation failed:', error.message)
    }
  }

  // Insert tea room post
  const { data: post, error: insertError } = await supabase
    .from('mm_tea_room_posts')
    .insert({
      game_id,
      cast_member_id,
      post_text: postText,
      post_type: postType,
      voice_note_url: voiceNoteUrl,
      voice_note_duration_seconds: voiceNoteDuration
    })
    .select()
    .single()

  if (insertError) throw insertError

  console.log(`✅ Tea room post created: "${postText.substring(0, 50)}..."`)

  // Log activity
  await logAIActivity({
    cast_member_id,
    game_id,
    action_type: 'tea_room_post',
    ai_model: 'haiku',
    input_tokens: response.usage.input_tokens,
    output_tokens: response.usage.output_tokens,
    response_id: post.id,
    response_preview: postText.substring(0, 100),
    processing_time_ms: processingTime
  })

  return { success: true, post_id: post.id }
}

// ============================================================================
// TEXT CLEANING FOR VOICE SYNTHESIS
// ============================================================================
/**
 * Removes markdown formatting, symbols, and visual actions that would be read aloud by TTS
 * Fixes: "asterisk flips hair asterisk Girl please" → "Girl please"
 */
function cleanTextForVoice(text: string): string {
  // Common visual/physical action phrases to remove
  const visualActions = [
    'flips? hair',
    'sits? back( in chair)?',
    'leans? (in|forward|back)',
    'rolls? eyes?',
    'crosses? arms?',
    'raises? eyebrow',
    'shrugs?',
    'smirks?',
    'grins?',
    'winks?',
    'nods?',
    'shakes? head',
    'stands? up',
    'walks? away',
    'turns? around',
    'looks? away',
    'stares?',
    'glances?',
    'gestures?',
    'points?( at)?',
    'waves? hand',
    'snaps? fingers?',
    'claps? hands?',
    'puts? hands? on hips?',
    'folds? arms?',
    'adjusts? (hair|outfit|collar)',
    'fixes? (hair|makeup)',
    'checks? (nails|phone)',
    'sips? (tea|drink|coffee)',
    'takes? (a )?sip'
  ]

  let cleaned = text

  // Remove action text in asterisks: *flips hair* → (removed entirely)
  cleaned = cleaned.replace(/\*[^*]+\*/g, '')

  // Remove action text in parentheses: (flips hair) → (removed entirely)
  cleaned = cleaned.replace(/\([^)]*(?:flips?|sits?|leans?|rolls?|crosses?|raises?|shrugs?|smirks?|grins?|winks?|nods?|shakes?|stands?|walks?|turns?|looks?|stares?|glances?|gestures?|points?|waves?|snaps?|claps?|puts?|folds?|adjusts?|fixes?|checks?|sips?|takes?)[^)]*\)/gi, '')

  // Remove standalone visual action phrases (case-insensitive)
  for (const action of visualActions) {
    const regex = new RegExp(`\\b${action}\\b`, 'gi')
    cleaned = cleaned.replace(regex, '')
  }

  // Remove emphasis asterisks: *word* → word (any remaining)
  cleaned = cleaned.replace(/\*/g, '')

  // Remove underscores used for emphasis: _word_ → word
  cleaned = cleaned.replace(/_/g, '')

  // Remove markdown bold: **word** → word
  cleaned = cleaned.replace(/\*\*/g, '')

  // Remove extra commas, spaces, and punctuation left by removals
  cleaned = cleaned.replace(/\s*,\s*,\s*/g, ', ')  // Double commas
  cleaned = cleaned.replace(/\s+/g, ' ')            // Multiple spaces
  cleaned = cleaned.replace(/^[,\s]+|[,\s]+$/g, '') // Leading/trailing commas and spaces

  return cleaned.trim()
}

// ============================================================================
// VOICE NOTE GENERATION (ElevenLabs)
// ============================================================================
async function generateVoiceNote(text: string, archetype: string): Promise<string> {
  if (!ELEVENLABS_API_KEY) return null

  // Clean text before sending to TTS (removes asterisks and markdown)
  const cleanedText = cleanTextForVoice(text)
  console.log(`🎤 Generating voice for: "${cleanedText.substring(0, 100)}..."`)

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
      text: cleanedText,
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
          case 'respond_to_scenario':
            result = await processScenarioResponse(action)
            break
          case 'send_chat_message':
            result = await processChatMessage(action)
            break
          case 'form_alliance':
            result = await processAllianceDecision(action)
            break
          case 'tea_room_post':
            result = await processTeaRoomPost(action)
            break
          case 'create_voice_introduction':
            // Skip voice for now - requires ElevenLabs integration
            console.log(`Skipping voice introduction for ${action.cast_member_id}`)
            result = { success: true, skipped: true, reason: 'Voice generation not yet implemented' }
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
