/**
 * MANSION MAYHEM — END-TO-END GAMEPLAY TEST
 *
 * Tests the full game cycle on the REAL Supabase project (fpxbhqibimekjhlumnmc):
 *   1. Check all required tables exist
 *   2. Verify existing game & cast members
 *   3. Create a new scenario (drama prompt)
 *   4. AI cast members respond to the scenario
 *   5. Cast votes (judge scoring)
 *   6. Post to Tea Room (social)
 *   7. Create relationship edge (alliance)
 *   8. Close scenario & verify results
 *   9. Cleanup all test data
 *
 * Run from InfinityRings dir (has @supabase/supabase-js):
 *   cd C:\Users\15868\InfinityRings && node ../MansionMayhemWebapp/test-e2e-gameplay.js
 */

import { createClient } from '@supabase/supabase-js'

const SUPABASE_URL = 'https://fpxbhqibimekjhlumnmc.supabase.co'
const SUPABASE_SERVICE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZweGJocWliaW1la2pobHVtbm1jIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MTAyNTA4NiwiZXhwIjoyMDg2NjAxMDg2fQ.tNHm7KfHW8nSxmL7gI_7z5ieTXi9XgbqhGsmvGWJ8eQ'

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)

const PASS = '✅'
const FAIL = '❌'
const INFO = '→'
const results = []

function log(status, msg) {
  const icon = status === 'pass' ? PASS : status === 'fail' ? FAIL : INFO
  console.log(`  ${icon} ${msg}`)
  if (status === 'pass' || status === 'fail') {
    results.push({ status, msg })
  }
}

// Track IDs for cleanup
let scenarioId = null
let teaPostId = null
const responseIds = []
const voteIds = []
let edgeId = null

// ─── STEP 1: Check required tables ──────────────────────────────────────────────
async function checkTables() {
  console.log('\n📋 STEP 1: Checking required tables...')

  const tables = [
    'mm_games',
    'cast_members',
    'scenarios',
    'scenario_responses',
    'scenario_votes',
    'mm_tea_room_posts',
    'mm_relationship_edges',
    'generated_uis',
    'voice_notes',
    'profiles',
  ]

  for (const table of tables) {
    const { count, error } = await supabase.from(table).select('*', { count: 'exact', head: true })
    if (error) {
      log('fail', `Table "${table}" — ${error.message}`)
    } else {
      log('pass', `Table "${table}" exists (${count ?? 0} rows)`)
    }
  }
}

// ─── STEP 2: Verify existing game & cast ────────────────────────────────────────
let gameId = null
let castMembers = []

async function verifyGameAndCast() {
  console.log('\n🎮 STEP 2: Verifying existing game & cast members...')

  // Find active game
  const { data: games, error: gErr } = await supabase
    .from('mm_games')
    .select('id, title, status, current_players')
    .eq('status', 'active')
    .limit(1)

  if (gErr || !games?.length) {
    log('fail', `No active game found — ${gErr?.message || 'empty'}`)
    return false
  }

  gameId = games[0].id
  log('pass', `Active game: "${games[0].title}" (${games[0].current_players} players)`)

  // Get active cast members
  const { data: cast, error: cErr } = await supabase
    .from('cast_members')
    .select('id, display_name, archetype, is_ai_player')
    .eq('status', 'active')

  if (cErr || !cast?.length) {
    log('fail', `No cast members found — ${cErr?.message || 'empty'}`)
    return false
  }

  castMembers = cast
  const aiCount = cast.filter(c => c.is_ai_player).length
  const humanCount = cast.filter(c => !c.is_ai_player).length
  log('pass', `${cast.length} active cast members (${humanCount} human, ${aiCount} AI)`)

  return true
}

// ─── STEP 3: Create a scenario ──────────────────────────────────────────────────
async function createScenario() {
  console.log('\n🎭 STEP 3: Creating test scenario...')

  const { data, error } = await supabase.from('scenarios').insert({
    game_id: gameId,
    title: 'E2E Test: The Truth or Dare Showdown',
    description: 'Each cast member must reveal their biggest secret or dare another player to do something outrageous. Alliances will be tested.',
    context_notes: 'This is an automated E2E test scenario. Delete after testing.',
    scenario_type: 'confrontation',
    status: 'active',
    deadline_at: new Date(Date.now() + 3600000).toISOString(),
    responses_received: 0,
    voice_notes_received: 0,
  }).select()

  if (error) {
    log('fail', `Create scenario — ${error.message}`)
    return false
  }

  scenarioId = data[0].id
  log('pass', `Scenario created: ${scenarioId.slice(0, 8)}... "${data[0].title}"`)
  return true
}

// ─── STEP 4: AI cast members respond ────────────────────────────────────────────
async function submitResponses() {
  console.log('\n💬 STEP 4: AI cast members responding to scenario...')

  const aiCast = castMembers.filter(c => c.is_ai_player).slice(0, 5)

  if (aiCast.length < 3) {
    log('fail', `Need at least 3 AI cast members, found ${aiCast.length}`)
    return false
  }

  const responseTexts = [
    "I'm done playing nice. Everyone in this mansion is fake, and I have the receipts to prove it. Try me.",
    "Listen... I came here to win, not to make friends. But some of y'all are making it too easy.",
    "I've been watching everyone. I know who's been talking behind my back. The truth always comes out in the mansion.",
    "You want tea? I'll give you the whole pot. Some people here aren't who they say they are.",
    "I'm not here for the drama, but if it comes to me, I won't run from it. Let's go.",
  ]

  let responded = 0
  for (let i = 0; i < aiCast.length; i++) {
    const { data, error } = await supabase.from('scenario_responses').insert({
      scenario_id: scenarioId,
      cast_member_id: aiCast[i].id,
      response_text: responseTexts[i],
    }).select('id')

    if (error) {
      log('fail', `Response from ${aiCast[i].display_name} — ${error.message}`)
    } else {
      responseIds.push(data[0].id)
      responded++
    }
  }

  // Update response count on scenario
  await supabase.from('scenarios').update({
    responses_received: responded,
  }).eq('id', scenarioId)

  if (responded === aiCast.length) {
    log('pass', `${responded} AI responses submitted`)
  } else {
    log('fail', `Only ${responded}/${aiCast.length} responses succeeded`)
  }

  return responded >= 3
}

// ─── STEP 5: Cast votes (judge scoring) ─────────────────────────────────────────
async function castVotes() {
  console.log('\n🗳️  STEP 5: Casting judge votes...')

  const aiCast = castMembers.filter(c => c.is_ai_player).slice(0, 5)
  if (aiCast.length < 4) {
    log('fail', 'Need at least 4 AI members for voting')
    return false
  }

  // Each judge votes on a participant (scenario_votes schema)
  const votePairs = [
    { judge: aiCast[0], participant: aiCast[1], score: 4, comment: 'Strong delivery, loved the energy' },
    { judge: aiCast[0], participant: aiCast[2], score: 3, comment: 'Decent but could push harder' },
    { judge: aiCast[1], participant: aiCast[0], score: 5, comment: 'Absolutely iconic, 10/10 drama' },
    { judge: aiCast[2], participant: aiCast[0], score: 4, comment: 'The receipts were real' },
    { judge: aiCast[3], participant: aiCast[1], score: 2, comment: 'Not convincing enough' },
  ]

  let voted = 0
  for (const v of votePairs) {
    const { data, error } = await supabase.from('scenario_votes').insert({
      scenario_id: scenarioId,
      judge_cast_member_id: v.judge.id,
      participant_cast_member_id: v.participant.id,
      vote_score: v.score,
      vote_comment: v.comment,
    }).select('id')

    if (error) {
      log('fail', `Vote ${v.judge.display_name} → ${v.participant.display_name} — ${error.message}`)
    } else {
      voteIds.push(data[0].id)
      voted++
    }
  }

  if (voted === votePairs.length) {
    log('pass', `${voted} votes cast across ${new Set(votePairs.map(v => v.judge.id)).size} judges`)
  } else {
    log('fail', `Only ${voted}/${votePairs.length} votes succeeded`)
  }

  return voted >= 3
}

// ─── STEP 6: Tea Room post ──────────────────────────────────────────────────────
async function postToTeaRoom() {
  console.log('\n☕ STEP 6: Posting to Tea Room...')

  const aiCast = castMembers.filter(c => c.is_ai_player)
  if (!aiCast.length) {
    log('fail', 'No AI cast for tea room post')
    return false
  }

  const { data, error } = await supabase.from('mm_tea_room_posts').insert({
    game_id: gameId,
    cast_member_id: aiCast[0].id,
    post_text: "Just finished that scenario and I'm SHOOK. Some people really showed their true colors today... 👀🍵 #MansionMayhem #E2ETest",
    post_type: 'drama',
    likes_count: 0,
    comments_count: 0,
    is_flagged: false,
  }).select('id')

  if (error) {
    log('fail', `Tea Room post — ${error.message}`)
    return false
  }

  teaPostId = data[0].id
  log('pass', `Tea Room post by ${aiCast[0].display_name}: ${teaPostId.slice(0, 8)}...`)
  return true
}

// ─── STEP 7: Create relationship edge (alliance) ───────────────────────────────
async function createAlliance() {
  console.log('\n🤝 STEP 7: Forming alliance (relationship edge)...')

  const aiCast = castMembers.filter(c => c.is_ai_player)
  if (aiCast.length < 2) {
    log('fail', 'Need at least 2 AI cast for alliance')
    return false
  }

  // Use LEAST/GREATEST for ordered_pair constraint
  const a = aiCast[0].id < aiCast[1].id ? aiCast[0] : aiCast[1]
  const b = aiCast[0].id < aiCast[1].id ? aiCast[1] : aiCast[0]

  const { data, error } = await supabase.from('mm_relationship_edges').insert({
    game_id: gameId,
    cast_member_a_id: a.id,
    cast_member_b_id: b.id,
    trust_score: 75,
    alliance_strength: 60,
    rivalry_level: 10,
  }).select('id')

  if (error) {
    log('fail', `Alliance — ${error.message}`)
    return false
  }

  edgeId = data[0].id
  log('pass', `Alliance formed: ${a.display_name || a.id.slice(0,8)} ↔ ${b.display_name || b.id.slice(0,8)}`)
  return true
}

// ─── STEP 8: Close scenario & verify ────────────────────────────────────────────
async function closeAndVerify() {
  console.log('\n📊 STEP 8: Closing scenario & verifying results...')

  // Close the scenario
  const { error: closeErr } = await supabase.from('scenarios').update({
    status: 'completed',
    closed_at: new Date().toISOString(),
  }).eq('id', scenarioId)

  if (closeErr) {
    log('fail', `Close scenario — ${closeErr.message}`)
    return false
  }

  log('pass', 'Scenario closed')

  // Verify responses exist
  const { count: respCount } = await supabase
    .from('scenario_responses')
    .select('*', { count: 'exact', head: true })
    .eq('scenario_id', scenarioId)

  log(respCount > 0 ? 'pass' : 'fail', `${respCount} responses recorded`)

  // Verify votes exist
  const { count: voteCount } = await supabase
    .from('scenario_votes')
    .select('*', { count: 'exact', head: true })
    .eq('scenario_id', scenarioId)

  log(voteCount > 0 ? 'pass' : 'fail', `${voteCount} votes recorded`)

  // Verify tea room post
  const { data: post } = await supabase
    .from('mm_tea_room_posts')
    .select('id')
    .eq('id', teaPostId)

  log(post?.length ? 'pass' : 'fail', 'Tea Room post verified')

  // Verify alliance
  if (edgeId) {
    const { data: edge } = await supabase
      .from('mm_relationship_edges')
      .select('id, trust_score, alliance_strength')
      .eq('id', edgeId)

    log(edge?.length ? 'pass' : 'fail', `Alliance edge verified (trust: ${edge?.[0]?.trust_score}, strength: ${edge?.[0]?.alliance_strength})`)
  }

  return true
}

// ─── STEP 9: Cleanup ───────────────────────────────────────────────────────────
async function cleanup() {
  console.log('\n🧹 STEP 9: Cleaning up test data...')

  let cleaned = 0

  // Delete in FK order
  if (voteIds.length) {
    for (const id of voteIds) {
      await supabase.from('scenario_votes').delete().eq('id', id)
    }
    cleaned++
  }

  if (responseIds.length) {
    for (const id of responseIds) {
      await supabase.from('scenario_responses').delete().eq('id', id)
    }
    cleaned++
  }

  if (edgeId) {
    await supabase.from('mm_relationship_edges').delete().eq('id', edgeId)
    cleaned++
  }

  if (teaPostId) {
    await supabase.from('mm_tea_room_posts').delete().eq('id', teaPostId)
    cleaned++
  }

  if (scenarioId) {
    await supabase.from('scenarios').delete().eq('id', scenarioId)
    cleaned++
  }

  log('pass', `Test data cleaned up (${cleaned} tables)`)
}

// ─── RUN ────────────────────────────────────────────────────────────────────────
async function main() {
  console.log('═══════════════════════════════════════════════════════════')
  console.log('  MANSION MAYHEM — END-TO-END GAMEPLAY TEST')
  console.log('  Supabase: fpxbhqibimekjhlumnmc')
  console.log('═══════════════════════════════════════════════════════════')

  try {
    await checkTables()

    const gameOk = await verifyGameAndCast()
    if (!gameOk) { await cleanup(); return }

    const scenarioOk = await createScenario()
    if (!scenarioOk) { await cleanup(); return }

    const responsesOk = await submitResponses()
    if (!responsesOk) { await cleanup(); return }

    await castVotes()
    await postToTeaRoom()
    await createAlliance()
    await closeAndVerify()
    await cleanup()
  } catch (err) {
    console.error('\n💥 UNEXPECTED ERROR:', err)
    await cleanup().catch(() => {})
  }

  // Summary
  const passed = results.filter(r => r.status === 'pass').length
  const failed = results.filter(r => r.status === 'fail').length

  console.log('\n═══════════════════════════════════════════════════════════')
  console.log(`  RESULTS: ${passed} passed, ${failed} failed`)
  console.log('═══════════════════════════════════════════════════════════')

  if (failed > 0) {
    console.log('\n  Failed tests:')
    results.filter(r => r.status === 'fail').forEach(r => console.log(`    ${FAIL} ${r.msg}`))
  }

  console.log('')
  process.exit(failed > 0 ? 1 : 0)
}

main()
