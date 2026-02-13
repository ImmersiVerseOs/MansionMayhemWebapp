// AI Decision Processor Edge Function
// Processes AI alliance requests, responses, and chat messages
// Triggered by cron job or manual invocation

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Create Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: req.headers.get('Authorization')! },
        },
      }
    );

    // Parse request body
    const { gameId, decisionType } = await req.json();

    console.log(`Processing AI decisions for game: ${gameId}, type: ${decisionType || 'all'}`);

    const results: any = {};

    // Get active games if no gameId provided
    let gameIds: string[] = [];
    if (gameId) {
      gameIds = [gameId];
    } else {
      // Get all active games
      const { data: activeGames } = await supabaseClient
        .from('mm_games')
        .select('id')
        .eq('status', 'active');

      gameIds = activeGames?.map((g) => g.id) || [];
    }

    // Process each game
    for (const gid of gameIds) {
      results[gid] = {};

      // Process alliance requests
      if (!decisionType || decisionType === 'alliance_requests') {
        const requests = await processAIAllianceRequests(supabaseClient, gid);
        results[gid].alliance_requests = requests.length;
      }

      // Process link-up responses
      if (!decisionType || decisionType === 'alliance_responses') {
        const responses = await processAILinkUpResponses(supabaseClient, gid);
        results[gid].alliance_responses = responses.length;
      }

      // Process chat messages
      if (!decisionType || decisionType === 'chat_messages') {
        const messages = await processAIAllianceMessages(supabaseClient, gid);
        results[gid].chat_messages = messages.length;
      }
    }

    return new Response(JSON.stringify({ success: true, results }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });
  } catch (error) {
    console.error('Error processing AI decisions:', error);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    });
  }
});

// ============================================================================
// AI DECISION LOGIC (Ported from aiService.js)
// ============================================================================

const random = () => Math.random();
const randomChoice = (arr: any[]) => arr[Math.floor(random() * arr.length)];

async function processAIAllianceRequests(supabase: any, gameId: string) {
  console.log(`Processing AI alliance requests for game ${gameId}...`);

  // Get all AI in this game
  const { data: gameCast } = await supabase
    .from('mm_game_cast')
    .select(`
      *,
      cast_member:cast_members!inner(*)
    `)
    .eq('game_id', gameId)
    .eq('cast_member.is_ai_player', true);

  const aiMembers = gameCast?.map((gc: any) => gc.cast_member) || [];
  const createdRequests = [];

  for (const ai of aiMembers) {
    // Get current alliance count
    const { data: myRooms } = await supabase
      .from('mm_alliance_rooms')
      .select('*')
      .eq('game_id', gameId)
      .contains('member_cast_ids', [ai.id])
      .eq('is_active', true);

    const currentAllianceCount = myRooms?.length || 0;
    const config = ai.ai_personality_config;
    const maxAlliances = config?.alliance_preferences?.max_alliances || 2;

    // Check if should send request
    if (currentAllianceCount >= maxAlliances) continue;

    const socialActivity = config?.traits?.social_activity || 0.5;
    const sendProbability = socialActivity * 0.6;
    if (random() >= sendProbability) continue;

    // Get available targets
    const { data: allMembers } = await supabase
      .from('mm_game_cast')
      .select('cast_member:cast_members(*)')
      .eq('game_id', gameId);

    const allMembersList = allMembers?.map((gc: any) => gc.cast_member) || [];

    // Filter out self and already-allied members
    const alliedMemberIds = new Set();
    myRooms?.forEach((room: any) => {
      room.member_cast_ids.forEach((id: string) => {
        if (id !== ai.id) alliedMemberIds.add(id);
      });
    });

    const availableTargets = allMembersList.filter(
      (member: any) => member.id !== ai.id && !alliedMemberIds.has(member.id)
    );

    if (availableTargets.length === 0) continue;

    // Check for existing pending requests
    const { data: pendingRequests } = await supabase
      .from('mm_link_up_requests')
      .select('*')
      .eq('game_id', gameId)
      .eq('requester_cast_id', ai.id)
      .eq('status', 'pending');

    if (pendingRequests && pendingRequests.length > 0) continue;

    // Select target
    const preferredArchetypes = config?.alliance_preferences?.preferred_archetypes || [];
    const preferred = availableTargets.filter((t: any) =>
      preferredArchetypes.includes(t.archetype)
    );

    const target =
      preferred.length > 0 && random() < 0.7
        ? randomChoice(preferred)
        : randomChoice(availableTargets);

    // Create link-up request
    const { data: request, error } = await supabase
      .from('mm_link_up_requests')
      .insert({
        game_id: gameId,
        requester_cast_id: ai.id,
        invited_cast_ids: [target.id],
        link_up_type: 'duo',
        message: `Hey ${target.display_name}, want to team up?`,
        status: 'pending',
        expires_at: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(), // 24 hours
        required_accepts: 1,
      })
      .select()
      .single();

    if (error) {
      console.error(`❌ Error creating link-up request for ${ai.display_name}:`, error);
      continue;
    }

    if (request) {
      createdRequests.push(request);
      console.log(`✅ ${ai.display_name} sent link-up request to ${target.display_name}`);
    }
  }

  return createdRequests;
}

async function processAILinkUpResponses(supabase: any, gameId: string) {
  console.log(`Processing AI link-up responses for game ${gameId}...`);

  // Get all AI in this game
  const { data: gameCast } = await supabase
    .from('mm_game_cast')
    .select(`
      *,
      cast_member:cast_members!inner(*)
    `)
    .eq('game_id', gameId)
    .eq('cast_member.is_ai_player', true);

  const aiMembers = gameCast?.map((gc: any) => gc.cast_member) || [];
  const responses = [];

  for (const ai of aiMembers) {
    // Get pending requests where this AI is invited
    const { data: requests } = await supabase
      .from('mm_link_up_requests')
      .select(`
        *,
        requester:cast_members!requester_cast_id(*)
      `)
      .eq('game_id', gameId)
      .contains('invited_cast_ids', [ai.id])
      .eq('status', 'pending');

    if (!requests || requests.length === 0) continue;

    for (const request of requests) {
      // Check for existing response
      const { data: existingResponse } = await supabase
        .from('mm_link_up_responses')
        .select('*')
        .eq('request_id', request.id)
        .eq('cast_member_id', ai.id)
        .single();

      if (existingResponse) continue;

      // Decide accept/decline
      const config = ai.ai_personality_config;
      const preferredArchetypes = config?.alliance_preferences?.preferred_archetypes || [];
      const loyalty = config?.traits?.loyalty || 0.5;

      let acceptChance = 0.5;
      if (preferredArchetypes.includes(request.requester.archetype)) {
        acceptChance += 0.3;
      }
      acceptChance += loyalty * 0.2;
      if (request.requester.archetype === 'queen') acceptChance += 0.2;
      if (request.requester.archetype === 'strategist') acceptChance += 0.1;
      acceptChance = Math.min(acceptChance, 0.95);

      const shouldAccept = random() < acceptChance;
      const response = shouldAccept ? 'accept' : 'decline';

      // Create response
      const { data: newResponse } = await supabase
        .from('mm_link_up_responses')
        .insert({
          request_id: request.id,
          cast_member_id: ai.id,
          response,
          response_message: shouldAccept ? "Let's do this!" : 'Sorry, not right now.',
        })
        .select()
        .single();

      if (newResponse) {
        responses.push(newResponse);
        console.log(
          `✅ ${ai.display_name} ${response}ed link-up from ${request.requester.display_name}`
        );
      }
    }
  }

  return responses;
}

async function processAIAllianceMessages(supabase: any, gameId: string) {
  console.log(`Processing AI alliance messages for game ${gameId}...`);

  // Get all AI in this game
  const { data: gameCast } = await supabase
    .from('mm_game_cast')
    .select(`
      *,
      cast_member:cast_members!inner(*)
    `)
    .eq('game_id', gameId)
    .eq('cast_member.is_ai_player', true);

  const aiMembers = gameCast?.map((gc: any) => gc.cast_member) || [];
  const sentMessages = [];

  for (const ai of aiMembers) {
    // Get alliance rooms for this AI
    const { data: rooms } = await supabase
      .from('mm_alliance_rooms')
      .select('*')
      .eq('game_id', gameId)
      .contains('member_cast_ids', [ai.id])
      .eq('is_active', true);

    if (!rooms || rooms.length === 0) continue;

    for (const room of rooms) {
      // Check last message time
      const { data: lastMessages } = await supabase
        .from('mm_alliance_messages')
        .select('created_at')
        .eq('room_id', room.id)
        .eq('sender_cast_id', ai.id)
        .order('created_at', { ascending: false })
        .limit(1);

      if (lastMessages && lastMessages.length > 0) {
        const lastMessageTime = new Date(lastMessages[0].created_at);
        const minutesSinceLastMessage =
          (Date.now() - lastMessageTime.getTime()) / (1000 * 60);

        const config = ai.ai_personality_config;
        const socialActivity = config?.traits?.social_activity || 0.5;

        // Direct minute-based cooldowns for real-time experience
        const cooldownMinutes =
          socialActivity > 0.7 ? 10 :   // High activity: 10 minutes (was 2 hours)
          socialActivity > 0.4 ? 20 :   // Medium activity: 20 minutes (was 4 hours)
          40;                           // Low activity: 40 minutes (was 8 hours)

        if (minutesSinceLastMessage < cooldownMinutes) {
          console.log(
            `Skipping room ${room.id} - cooldown not met ` +
            `(${minutesSinceLastMessage.toFixed(1)} min < ${cooldownMinutes} min required)`
          );
          continue;
        }
      }

      // Decide if should send message
      const config = ai.ai_personality_config;
      const socialActivity = config?.traits?.social_activity || 0.5;
      const sendProbability = socialActivity * 0.5;
      if (random() >= sendProbability) continue;

      // Generate message
      const templates = config?.chat_behavior?.response_templates || ["What's the plan?"];
      const template = randomChoice(templates);

      // Get non-allied members for context
      const { data: allMembers } = await supabase
        .from('mm_game_cast')
        .select('cast_member:cast_members(*)')
        .eq('game_id', gameId);

      const allMembersList = allMembers?.map((gc: any) => gc.cast_member) || [];
      const nonAlliedMembers = allMembersList.filter(
        (member: any) => !room.member_cast_ids.includes(member.id)
      );

      const messageText =
        nonAlliedMembers.length > 0
          ? template.replace(/\{player\}/g, randomChoice(nonAlliedMembers).display_name)
          : template.replace(/\{player\}/g, 'someone');

      // Send message
      const { data: message } = await supabase
        .from('mm_alliance_messages')
        .insert({
          room_id: room.id,
          sender_cast_id: ai.id,
          message_type: 'text',
          text_content: messageText,
        })
        .select()
        .single();

      if (message) {
        sentMessages.push(message);
        console.log(`✅ ${ai.display_name} sent message: "${messageText}"`);
      }
    }
  }

  return sentMessages;
}
