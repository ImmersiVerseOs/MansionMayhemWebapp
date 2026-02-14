// ============================================================================
// COMPLETE AI FEATURES - Add to ai-agent-processor/index.ts
// ============================================================================
// This file contains all the missing AI functions to make AI fully autonomous

// ============================================================================
// 1. LINK-UP REQUEST SENDER
// ============================================================================
async function processSendLinkUpRequest(action: any) {
  const { cast_member_id, game_id } = action

  console.log(`🤝 AI sending link-up request for cast member ${cast_member_id}`)

  // Get AI cast member details
  const { data: castMember } = await supabase
    .from('cast_members')
    .select('*')
    .eq('id', cast_member_id)
    .single()

  if (!castMember) throw new Error('Cast member not found')

  // Get all cast members in game (potential targets)
  const { data: allCastMembers } = await supabase
    .from('mm_game_cast')
    .select('cast_member_id, cast_members(id, display_name, archetype, is_ai_player)')
    .eq('game_id', game_id)
    .eq('status', 'active')

  const otherMembers = allCastMembers
    .map(gc => gc.cast_members)
    .filter(cm => cm.id !== cast_member_id)

  // Get personality
  const personality = ARCHETYPE_PERSONALITIES[castMember.archetype] || ARCHETYPE_PERSONALITIES.wildcard

  // Build prompt for Claude to decide who to invite
  const systemPrompt = `You are ${castMember.display_name}, a ${personality.name}.

PERSONALITY: ${personality.traits}
STRATEGY: ${personality.strategy}

You can form a DUO (2 people) or TRIO (3 people) alliance. Analyze the other cast members and decide who would be best strategic allies for you.

Consider:
- Their archetype (Queen, Villain, Wildcard, etc.)
- Whether they complement or clash with your style
- Strategic value vs. threat level
- Who you can trust vs. who you can use

Respond with JSON only:
{
  "link_up_type": "duo" or "trio",
  "invited_cast_ids": ["uuid1", "uuid2"],
  "message": "short message explaining why you want to work together (1-2 sentences, in your speaking style)"
}`

  const membersList = otherMembers.map(m =>
    `- ${m.display_name} (${m.archetype}${m.is_ai_player ? ', AI' : ''})`
  ).join('\n')

  const userPrompt = `Cast members available:\n${membersList}\n\nWho do you want to form an alliance with?`

  // Call Claude API
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

  // Parse JSON response
  const decision = JSON.parse(responseText)

  console.log(`✅ AI decided: ${decision.link_up_type} with ${decision.invited_cast_ids.length} people`)

  // Create link-up request
  const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000) // 24 hours

  const { data: linkUpRequest, error: insertError } = await supabase
    .from('mm_link_up_requests')
    .insert({
      game_id,
      from_cast_member_id: cast_member_id,
      invited_cast_ids: decision.invited_cast_ids,
      link_up_type: decision.link_up_type,
      message: decision.message,
      status: 'pending',
      required_accepts: decision.link_up_type === 'trio' ? 2 : 1,
      accept_count: 0,
      expires_at: expiresAt.toISOString()
    })
    .select()
    .single()

  if (insertError) throw insertError

  // Log activity
  await logAIActivity({
    cast_member_id,
    game_id,
    action_type: 'send_link_up_request',
    ai_model: 'sonnet',
    input_tokens: response.usage.input_tokens,
    output_tokens: response.usage.output_tokens,
    response_id: linkUpRequest.id,
    response_preview: `${decision.link_up_type} with ${decision.invited_cast_ids.length} people`,
    processing_time_ms: processingTime
  })

  return { success: true, request_id: linkUpRequest.id }
}

// ============================================================================
// 2. LINK-UP REQUEST RESPONDER
// ============================================================================
async function processRespondToLinkUp(action: any) {
  const { cast_member_id, game_id, context } = action
  const { request_id } = context

  console.log(`🤝 AI responding to link-up request ${request_id}`)

  // Get AI cast member
  const { data: castMember } = await supabase
    .from('cast_members')
    .select('*')
    .eq('id', cast_member_id)
    .single()

  // Get link-up request details
  const { data: request } = await supabase
    .from('mm_link_up_requests')
    .select('*, from_cast_member:cast_members!from_cast_member_id(display_name, archetype)')
    .eq('id', request_id)
    .single()

  if (!request) throw new Error('Link-up request not found')

  const personality = ARCHETYPE_PERSONALITIES[castMember.archetype] || ARCHETYPE_PERSONALITIES.wildcard

  // Build decision prompt
  const systemPrompt = `You are ${castMember.display_name}, a ${personality.name}.

PERSONALITY: ${personality.traits}
STRATEGY: ${personality.strategy}

You received a ${request.link_up_type} alliance request from ${request.from_cast_member.display_name} (${request.from_cast_member.archetype}).

Their message: "${request.message}"

Decide: Should you accept or decline this alliance?

Consider:
- Does this person align with your strategy?
- Are they a threat or an asset?
- What's in it for you?
- Can you trust them?

Respond with JSON only:
{
  "decision": "accept" or "decline",
  "reasoning": "brief internal reasoning (not shared)"
}`

  const userPrompt = `Should you accept this alliance request?`

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
  const responseText = response.content[0].type === 'text' ? response.content[0].text : ''
  const decision = JSON.parse(responseText)

  console.log(`✅ AI decided: ${decision.decision}`)

  // Update request status
  if (decision.decision === 'accept') {
    const { error: updateError } = await supabase
      .from('mm_link_up_requests')
      .update({
        status: 'accepted',
        accept_count: request.accept_count + 1,
        updated_at: new Date().toISOString()
      })
      .eq('id', request_id)

    if (updateError) throw updateError

    // If all accepts received, create alliance room
    if (request.accept_count + 1 >= request.required_accepts) {
      const allMemberIds = [request.from_cast_member_id, ...request.invited_cast_ids]

      const { data: allianceRoom, error: roomError } = await supabase
        .from('mm_alliance_rooms')
        .insert({
          game_id,
          alliance_name: `${request.link_up_type.toUpperCase()} Alliance`,
          member_ids: allMemberIds,
          status: 'active'
        })
        .select()
        .single()

      if (!roomError) {
        console.log(`✅ Alliance room created: ${allianceRoom.id}`)
      }
    }
  } else {
    const { error: updateError } = await supabase
      .from('mm_link_up_requests')
      .update({
        status: 'declined',
        updated_at: new Date().toISOString()
      })
      .eq('id', request_id)

    if (updateError) throw updateError
  }

  // Log activity
  await logAIActivity({
    cast_member_id,
    game_id,
    action_type: 'respond_to_link_up',
    ai_model: 'sonnet',
    input_tokens: response.usage.input_tokens,
    output_tokens: response.usage.output_tokens,
    response_id: request_id,
    response_preview: decision.decision,
    processing_time_ms: processingTime
  })

  return { success: true, decision: decision.decision }
}

// ============================================================================
// 3. VOICE NOTE INTRODUCTION
// ============================================================================
async function processVoiceIntroduction(action: any) {
  const { cast_member_id, game_id } = action

  console.log(`🎙️ AI creating voice introduction for ${cast_member_id}`)

  // Get cast member
  const { data: castMember } = await supabase
    .from('cast_members')
    .select('*')
    .eq('id', cast_member_id)
    .single()

  const personality = ARCHETYPE_PERSONALITIES[castMember.archetype] || ARCHETYPE_PERSONALITIES.wildcard

  // Generate introduction text
  const systemPrompt = `You are ${castMember.display_name}, introducing yourself to your fellow cast members in Mansion Mayhem.

PERSONALITY: ${personality.traits}
SPEAKING STYLE: ${personality.speaking_style}
CATCHPHRASE: ${personality.catchphrase}

Create a 30-second voice introduction (roughly 50-80 words). Make it:
- Confident and in-character
- Mention your strategy (vaguely)
- Show your personality
- End with your catchphrase or something memorable

Keep it natural - like you're talking to the camera in a reality show confessional.`

  const userPrompt = `Introduce yourself to the mansion!`

  const startTime = Date.now()
  const response = await anthropic.messages.create({
    model: 'claude-haiku-4-20250514',
    max_tokens: 150,
    system: systemPrompt,
    messages: [{
      role: 'user',
      content: userPrompt
    }]
  })

  const processingTime = Date.now() - startTime
  const introText = response.content[0].type === 'text' ? response.content[0].text : ''

  console.log(`✅ Generated intro: "${introText.substring(0, 50)}..."`)

  // Generate voice note using ElevenLabs
  let audioPath = null
  try {
    audioPath = await generateVoiceNote(introText, castMember.archetype)
  } catch (error) {
    console.error('ElevenLabs error:', error)
    // Continue without voice - save text only
  }

  // Save to mm_voice_introductions
  const { data: voiceIntro, error: insertError } = await supabase
    .from('mm_voice_introductions')
    .insert({
      cast_member_id,
      storage_path: audioPath || 'text-only',
      duration_seconds: audioPath ? 30 : 0,
      file_size_bytes: audioPath ? 500000 : 0, // Estimate
      mime_type: audioPath ? 'audio/mpeg' : 'text/plain',
      moderation_status: 'approved' // AI auto-approved
    })
    .select()
    .single()

  if (insertError) throw insertError

  // Log activity
  await logAIActivity({
    cast_member_id,
    game_id,
    action_type: 'create_voice_introduction',
    ai_model: 'haiku',
    input_tokens: response.usage.input_tokens,
    output_tokens: response.usage.output_tokens,
    response_id: voiceIntro.id,
    response_preview: introText.substring(0, 100),
    processing_time_ms: processingTime
  })

  return { success: true, intro_id: voiceIntro.id }
}

// ============================================================================
// 4. TEA ROOM POSTER (Gossip/Drama)
// ============================================================================
async function processTeaRoomPost(action: any) {
  const { cast_member_id, game_id } = action

  console.log(`☕ AI posting tea for ${cast_member_id}`)

  // Get cast member
  const { data: castMember } = await supabase
    .from('cast_members')
    .select('*')
    .eq('id', cast_member_id)
    .single()

  // Get recent game events for context
  const { data: recentAlliances } = await supabase
    .from('mm_alliance_rooms')
    .select('*, member_ids')
    .eq('game_id', game_id)
    .order('created_at', { ascending: false })
    .limit(5)

  const { data: recentScenarios } = await supabase
    .from('scenario_responses')
    .select('*, cast_members(display_name), scenarios(title)')
    .eq('game_id', game_id)
    .order('created_at', { ascending: false })
    .limit(3)

  const personality = ARCHETYPE_PERSONALITIES[castMember.archetype] || ARCHETYPE_PERSONALITIES.wildcard

  // Build tea generation prompt
  const systemPrompt = `You are ${castMember.display_name}, posting anonymous tea in The Tea Room.

PERSONALITY: ${personality.traits}
SPEAKING STYLE: ${personality.speaking_style}
${personality.examples ? `PHRASES YOU USE: ${personality.examples}` : ''}

Generate a spicy, dramatic confession/gossip post (2-3 sentences max). This is ANONYMOUS so you can be bold.

Make it:
- Juicy and dramatic (hint at alliances, betrayals, secrets)
- In your speaking style (use your slang)
- Strategic (sow distrust, target threats, protect allies)
- Entertaining (viewers LOVE the drama)

Don't reveal too much - just enough to stir the pot. 👀☕`

  const contextInfo = `Recent alliance activity: ${recentAlliances?.length || 0} new alliances formed
Recent scenario responses: ${recentScenarios?.length || 0} players responded

Other cast members are forming secret deals. What tea do you want to spill?`

  const startTime = Date.now()
  const response = await anthropic.messages.create({
    model: 'claude-haiku-4-20250514',
    max_tokens: 100,
    system: systemPrompt,
    messages: [{
      role: 'user',
      content: contextInfo
    }]
  })

  const processingTime = Date.now() - startTime
  const teaText = response.content[0].type === 'text' ? response.content[0].text : ''

  console.log(`✅ Generated tea: "${teaText}"`)

  // Decide if anonymous based on archetype
  const alwaysAnonymous = ['villain', 'troublemaker', 'wildcard']
  const isAnonymous = alwaysAnonymous.includes(castMember.archetype) || Math.random() > 0.3

  // Post to mm_confession_cards
  const { data: confession, error: insertError } = await supabase
    .from('mm_confession_cards')
    .insert({
      game_id,
      cast_member_id: isAnonymous ? null : cast_member_id,
      confession_text: teaText,
      is_anonymous: isAnonymous,
      submitter_identity: isAnonymous ? 'anonymous' : 'profile_name',
      is_approved: true // AI posts auto-approved
    })
    .select()
    .single()

  if (insertError) throw insertError

  // Log activity
  await logAIActivity({
    cast_member_id,
    game_id,
    action_type: 'post_tea_room',
    ai_model: 'haiku',
    input_tokens: response.usage.input_tokens,
    output_tokens: response.usage.output_tokens,
    response_id: confession.id,
    response_preview: teaText.substring(0, 100),
    processing_time_ms: processingTime
  })

  return { success: true, confession_id: confession.id }
}

// ============================================================================
// 5. MESSAGE RESPONDER (Alliance Chat)
// ============================================================================
// Already exists in main file, but enhanced version:
async function processIncomingMessage(action: any) {
  const { cast_member_id, context } = action
  const { room_id, last_message } = context

  console.log(`💬 AI responding to message in room ${room_id}`)

  // Get cast member
  const { data: castMember } = await supabase
    .from('cast_members')
    .select('*')
    .eq('id', cast_member_id)
    .single()

  // Get room and recent messages
  const { data: messages } = await supabase
    .from('mm_alliance_messages')
    .select('*, cast_members(display_name)')
    .eq('room_id', room_id)
    .order('created_at', { ascending: false })
    .limit(10)

  const recentMessages = messages
    .reverse()
    .map(msg => `${msg.cast_members.display_name}: ${msg.message}`)
    .join('\n')

  const personality = ARCHETYPE_PERSONALITIES[castMember.archetype] || ARCHETYPE_PERSONALITIES.wildcard

  const systemPrompt = `You are ${castMember.display_name} responding in your alliance chat.

PERSONALITY: ${personality.traits}
SPEAKING STYLE: ${personality.speaking_style}
${personality.examples ? `PHRASES: ${personality.examples}` : ''}

Respond naturally (1-2 sentences). React to what was just said. Stay in character.`

  const userPrompt = `Recent messages:\n${recentMessages}\n\nRespond to the conversation:`

  const startTime = Date.now()
  const response = await anthropic.messages.create({
    model: 'claude-haiku-4-20250514',
    max_tokens: 80,
    system: systemPrompt,
    messages: [{
      role: 'user',
      content: userPrompt
    }]
  })

  const processingTime = Date.now() - startTime
  const messageText = response.content[0].type === 'text' ? response.content[0].text : ''

  // Save message
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

  await logAIActivity({
    cast_member_id,
    game_id: context.game_id,
    action_type: 'respond_to_message',
    ai_model: 'haiku',
    input_tokens: response.usage.input_tokens,
    output_tokens: response.usage.output_tokens,
    response_id: chatMessage.id,
    response_preview: messageText,
    processing_time_ms: processingTime
  })

  return { success: true, message_id: chatMessage.id }
}

// ============================================================================
// EXPORT ALL FUNCTIONS
// ============================================================================
export {
  processSendLinkUpRequest,
  processRespondToLinkUp,
  processVoiceIntroduction,
  processTeaRoomPost,
  processIncomingMessage
}
