// ============================================================================
// UPDATED MAIN HANDLER - Add this to index.ts
// Handles all AI action types
// ============================================================================

serve(async (req) => {
  try {
    console.log('🤖 AI Agent Processor started')

    // Get pending actions (highest priority first, limit 10 per run)
    const { data: actions, error } = await supabase
      .from('ai_action_queue')
      .select('*')
      .eq('status', 'pending')
      .lte('created_at', new Date().toISOString()) // Only process actions whose time has come (for delayed actions)
      .order('priority', { ascending: false })
      .order('created_at', { ascending: true })
      .limit(10)

    if (error) throw error

    if (!actions || actions.length === 0) {
      console.log('✅ No pending actions')
      return new Response(JSON.stringify({ message: 'No pending actions', processed: 0 }), {
        headers: { 'Content-Type': 'application/json' }
      })
    }

    console.log(`📋 Found ${actions.length} pending actions`)

    const results = []

    // Process each action
    for (const action of actions) {
      console.log(`\n🎯 Processing: ${action.action_type} for cast member ${action.cast_member_id}`)

      // Mark as processing
      await supabase
        .from('ai_action_queue')
        .update({ status: 'processing' })
        .eq('id', action.id)

      try {
        let result

        // Route to appropriate handler
        switch (action.action_type) {
          case 'send_link_up_request':
            result = await processSendLinkUpRequest(action)
            break

          case 'respond_to_link_up':
            result = await processRespondToLinkUp(action)
            break

          case 'create_voice_introduction':
            result = await processVoiceIntroduction(action)
            break

          case 'post_tea_room':
            result = await processTeaRoomPost(action)
            break

          case 'respond_to_message':
            result = await processChatMessage(action) // Or processIncomingMessage
            break

          case 'respond_to_scenario':
            result = await processScenarioResponse(action)
            break

          case 'make_alliance_decision':
            result = await processAllianceDecision(action)
            break

          default:
            throw new Error(`Unknown action type: ${action.action_type}`)
        }

        // Mark as completed
        await supabase
          .from('ai_action_queue')
          .update({
            status: 'completed',
            processed_at: new Date().toISOString()
          })
          .eq('id', action.id)

        console.log(`✅ Completed: ${action.action_type}`)
        results.push({ action_id: action.id, status: 'completed', result })

      } catch (error) {
        console.error(`❌ Error processing ${action.action_type}:`, error)

        // Mark as failed
        await supabase
          .from('ai_action_queue')
          .update({
            status: 'failed',
            error_message: error.message,
            processed_at: new Date().toISOString()
          })
          .eq('id', action.id)

        results.push({ action_id: action.id, status: 'failed', error: error.message })
      }
    }

    console.log(`\n✅ Processed ${results.length} actions`)
    console.log(`   Completed: ${results.filter(r => r.status === 'completed').length}`)
    console.log(`   Failed: ${results.filter(r => r.status === 'failed').length}`)

    return new Response(JSON.stringify({
      message: 'Processing complete',
      processed: results.length,
      results
    }), {
      headers: { 'Content-Type': 'application/json' }
    })

  } catch (error) {
    console.error('❌ Fatal error:', error)
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    })
  }
})
