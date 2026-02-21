/*
 * TRADE SECRET - CONFIDENTIAL
 * Proprietary AI decision processing system
 * © 2026 ImmersiVerse OS Inc.
 * Unauthorized disclosure prohibited by law.
 */

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
    // Create Supabase client with service role (AI operates on behalf of AI players)
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
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

      // Process tea room posts
      if (!decisionType || decisionType === 'tea_room_posts') {
        const posts = await processAITeaRoomPosts(supabaseClient, gid);
        results[gid].tea_room_posts = posts.length;
      }

      // Process votes
      if (!decisionType || decisionType === 'votes') {
        const votes = await processAIVotes(supabaseClient, gid);
        results[gid].votes = votes.length;
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
      .contains('member_ids', [ai.id])
      .eq('status', 'active');

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
      room.member_ids.forEach((id: string) => {
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
      .eq('from_cast_member_id', ai.id)
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
        from_cast_member_id: ai.id,
        to_cast_member_id: target.id,
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
    // Get pending requests where this AI is the recipient
    const { data: requests } = await supabase
      .from('mm_link_up_requests')
      .select(`
        *,
        from_member:cast_members!from_cast_member_id(*)
      `)
      .eq('game_id', gameId)
      .eq('to_cast_member_id', ai.id)
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
      if (preferredArchetypes.includes(request.from_member.archetype)) {
        acceptChance += 0.3;
      }
      acceptChance += loyalty * 0.2;
      if (request.from_member.archetype === 'queen') acceptChance += 0.2;
      if (request.from_member.archetype === 'strategist') acceptChance += 0.1;
      acceptChance = Math.min(acceptChance, 0.95);

      const shouldAccept = random() < acceptChance;
      const response = shouldAccept ? 'accept' : 'decline';

      // Create response
      const { data: newResponse, error: responseError } = await supabase
        .from('mm_link_up_responses')
        .insert({
          request_id: request.id,
          cast_member_id: ai.id,
          response,
          message: shouldAccept ? "Let's do this!" : 'Sorry, not right now.',
        })
        .select()
        .single();

      if (responseError) {
        console.error(`❌ Error creating response for ${ai.display_name}:`, responseError);
        continue;
      }

      if (newResponse) {
        responses.push(newResponse);
        console.log(
          `✅ ${ai.display_name} ${response}ed link-up from ${request.from_member.display_name}`
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
      .contains('member_ids', [ai.id])
      .eq('status', 'active');

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
      const sendProbability = socialActivity * 0.8;  // Increased from 0.5 to 0.8 for more active chatting
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
        (member: any) => !room.member_ids.includes(member.id)
      );

      const messageText =
        nonAlliedMembers.length > 0
          ? template.replace(/\{player\}/g, randomChoice(nonAlliedMembers).display_name)
          : template.replace(/\{player\}/g, 'someone');

      // Send message
      const { data: message, error: messageError } = await supabase
        .from('mm_alliance_messages')
        .insert({
          room_id: room.id,
          sender_cast_id: ai.id,
          message_type: 'text',
          message: messageText,
        })
        .select()
        .single();

      if (messageError) {
        console.error(`❌ Error sending message for ${ai.display_name}:`, messageError);
        continue;
      }

      if (message) {
        sentMessages.push(message);
        console.log(`✅ ${ai.display_name} sent message: "${messageText}"`);
      }
    }
  }

  return sentMessages;
}

async function processAITeaRoomPosts(supabase: any, gameId: string) {
  console.log(`☕ Processing AI tea room posts for game ${gameId}...`);

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
  const createdPosts = [];

  for (const ai of aiMembers) {
    // Check last post time to avoid spam
    const { data: lastPosts } = await supabase
      .from('mm_tea_room_posts')
      .select('created_at')
      .eq('cast_member_id', ai.id)
      .eq('game_id', gameId)
      .order('created_at', { ascending: false })
      .limit(1);

    if (lastPosts && lastPosts.length > 0) {
      const minutesSinceLastPost = (Date.now() - new Date(lastPosts[0].created_at).getTime()) / (1000 * 60);

      const config = ai.ai_personality_config;
      const socialActivity = config?.traits?.social_activity || 0.5;

      // Direct minute-based cooldowns for real-time drama
      const cooldownMinutes =
        socialActivity > 0.7 ? 30 :   // High activity: 30 minutes
        socialActivity > 0.4 ? 60 :   // Medium activity: 1 hour
        120;                          // Low activity: 2 hours

      if (minutesSinceLastPost < cooldownMinutes) {
        console.log(
          `Skipping tea room post for ${ai.display_name} - cooldown not met ` +
          `(${minutesSinceLastPost.toFixed(1)} min < ${cooldownMinutes} min required)`
        );
        continue;
      }
    }

    // Decide if should post (personality-based probability)
    const config = ai.ai_personality_config;
    const socialActivity = config?.traits?.social_activity || 0.5;
    const postProbability = socialActivity * 0.4; // 40% max chance if highly social

    if (random() >= postProbability) continue;

    // Queue tea room post action for ai-agent-processor
    const { error } = await supabase
      .from('ai_action_queue')
      .insert({
        cast_member_id: ai.id,
        action_type: 'tea_room_post',
        game_id: gameId,
        context: {},
        priority: 50 // Medium priority (higher than chat, lower than scenarios)
      });

    if (!error) {
      createdPosts.push(ai.id);
      console.log(`✅ Queued tea room post for ${ai.display_name}`);
    } else {
      console.error(`❌ Error queuing tea room post for ${ai.display_name}:`, error);
    }
  }

  return createdPosts;
}

async function processAIVotes(supabase: any, gameId: string) {
  console.log(`🗳️ Processing AI votes for game ${gameId}...`);

  // Get active voting rounds
  const { data: activeRounds } = await supabase
    .from('mm_voting_rounds')
    .select('*')
    .eq('game_id', gameId)
    .eq('status', 'active');

  if (!activeRounds || activeRounds.length === 0) {
    console.log('No active voting rounds');
    return [];
  }

  const votesCreated = [];

  for (const round of activeRounds) {
    if (!round.nominee_a_id || !round.nominee_b_id) {
      console.log(`Round ${round.id} has no nominees, skipping...`);
      continue;
    }

    // Get AI members who can vote (not nominated, not queen)
    const { data: aiMembers } = await supabase
      .from('mm_game_cast')
      .select('cast_member:cast_members!inner(*)')
      .eq('game_id', gameId)
      .eq('cast_member.is_ai_player', true)
      .eq('status', 'active')
      .neq('cast_member.id', round.nominee_a_id)
      .neq('cast_member.id', round.nominee_b_id)
      .neq('cast_member.id', round.queen_id);

    if (!aiMembers || aiMembers.length === 0) {
      console.log('No AI members can vote in this round');
      continue;
    }

    for (const member of aiMembers) {
      const ai = member.cast_member;

      // Check if already voted
      const { data: existingVote } = await supabase
        .from('mm_elimination_votes')
        .select('*')
        .eq('round_id', round.id)
        .eq('cast_member_id', ai.id)
        .maybeSingle();

      if (existingVote) continue;

      // CONTEXT-AWARE VOTING: Gather all relevant information

      // 1. Get alliance relationships
      const { data: relationships } = await supabase
        .from('mm_relationship_edges')
        .select('*')
        .eq('game_id', gameId)
        .or(`cast_member_a_id.eq.${ai.id},cast_member_b_id.eq.${ai.id}`);

      const alliedWithA = relationships?.some((r: any) =>
        (r.cast_member_a_id === ai.id && r.cast_member_b_id === round.nominee_a_id) ||
        (r.cast_member_b_id === ai.id && r.cast_member_a_id === round.nominee_a_id)
      );

      const alliedWithB = relationships?.some((r: any) =>
        (r.cast_member_a_id === ai.id && r.cast_member_b_id === round.nominee_b_id) ||
        (r.cast_member_b_id === ai.id && r.cast_member_a_id === round.nominee_b_id)
      );

      // 2. Get recent alliance chat context (if in same alliance)
      const { data: allianceMessages } = await supabase
        .from('mm_alliance_messages')
        .select('*, cast_members(display_name), mm_alliance_rooms(member_ids)')
        .in('mm_alliance_rooms.member_ids', [[ai.id, round.nominee_a_id], [ai.id, round.nominee_b_id]])
        .order('created_at', { ascending: false })
        .limit(10);

      const allianceContext = allianceMessages
        ?.map((m: any) => `${m.cast_members.display_name}: ${m.message}`)
        .join('\n') || 'No alliance chat history';

      // 3. Get recent tea room drama mentioning nominees
      const { data: teaDrama } = await supabase
        .from('mm_tea_room_posts')
        .select('*, cast_members(display_name)')
        .eq('game_id', gameId)
        .order('created_at', { ascending: false })
        .limit(15);

      const dramaContext = teaDrama
        ?.map((t: any) => `${t.cast_members.display_name}: ${t.post_text}`)
        .join('\n') || 'No drama yet';

      // 4. Get nominee names
      const { data: nomineeA } = await supabase
        .from('cast_members')
        .select('display_name, archetype')
        .eq('id', round.nominee_a_id)
        .single();

      const { data: nomineeB } = await supabase
        .from('cast_members')
        .select('display_name, archetype')
        .eq('id', round.nominee_b_id)
        .single();

      // STRATEGIC DECISION: Use all context to decide
      const votingContext = `
VOTING CONTEXT:
- You are ${ai.display_name} (${ai.archetype})
- Allied with ${nomineeA?.display_name}? ${alliedWithA ? 'YES' : 'NO'}
- Allied with ${nomineeB?.display_name}? ${alliedWithB ? 'YES' : 'NO'}

NOMINEES:
A) ${nomineeA?.display_name} (${nomineeA?.archetype})
B) ${nomineeB?.display_name} (${nomineeB?.archetype})

RECENT ALLIANCE CHAT:
${allianceContext}

RECENT TEA ROOM DRAMA:
${dramaContext}

Based on:
- Your alliances and loyalty
- Recent conversations and drama
- Strategic game position
- Your archetype personality (${ai.archetype})

Who should you vote to ELIMINATE (send home)?
Respond: "ELIMINATE A" or "ELIMINATE B" and briefly explain why.`;

      console.log(`🤔 ${ai.display_name} analyzing vote context...`);

      // Use simple logic for now (can upgrade to Claude API later)
      let votedForId: string;

      if (alliedWithA && !alliedWithB) {
        votedForId = round.nominee_b_id; // Eliminate B, protect ally A
        console.log(`  → Protecting ally ${nomineeA?.display_name}, eliminating ${nomineeB?.display_name}`);
      } else if (alliedWithB && !alliedWithA) {
        votedForId = round.nominee_a_id; // Eliminate A, protect ally B
        console.log(`  → Protecting ally ${nomineeB?.display_name}, eliminating ${nomineeA?.display_name}`);
      } else {
        // No clear alliance - use archetype logic
        if (ai.archetype === 'villain' || ai.archetype === 'troublemaker') {
          votedForId = random() < 0.5 ? round.nominee_a_id : round.nominee_b_id; // Chaos vote
          console.log(`  → ${ai.archetype} chaos vote`);
        } else {
          // Default: slight preference based on tea room drama mentions
          const aHasMoreDrama = dramaContext.toLowerCase().includes(nomineeA?.display_name.toLowerCase() || '');
          votedForId = aHasMoreDrama ? round.nominee_a_id : round.nominee_b_id;
          console.log(`  → Strategic vote based on drama context`);
        }
      }

      // Create vote
      const { data: vote, error } = await supabase
        .from('mm_elimination_votes')
        .insert({
          round_id: round.id,
          cast_member_id: ai.id,
          voted_for_id: votedForId
        })
        .select()
        .single();

      if (!error && vote) {
        votesCreated.push({
          ai: ai.display_name,
          voted_for: votedForId,
          round_id: round.id
        });
        console.log(`✅ ${ai.display_name} voted`);
      } else {
        console.error(`❌ Error creating vote for ${ai.display_name}:`, error);
      }
    }

    // After all votes, update vote counts
    const { data: voteCounts } = await supabase
      .from('mm_elimination_votes')
      .select('voted_for_id')
      .eq('round_id', round.id);

    if (voteCounts) {
      const votesForA = voteCounts.filter((v: any) => v.voted_for_id === round.nominee_a_id).length;
      const votesForB = voteCounts.filter((v: any) => v.voted_for_id === round.nominee_b_id).length;

      await supabase
        .from('mm_voting_rounds')
        .update({
          votes_for_a: votesForA,
          votes_for_b: votesForB
        })
        .eq('id', round.id);

      console.log(`📊 Vote counts: A=${votesForA}, B=${votesForB}`);
    }
  }

  return votesCreated;
}
