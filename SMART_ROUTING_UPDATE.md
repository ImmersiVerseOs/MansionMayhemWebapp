# Smart Routing for Auto-Generated UIs

## Update player-dashboard.html

Add this function to intelligently route to the correct UI:

```javascript
async function openScenario(scenarioId) {
  try {
    // Check if scenario has custom UI
    const { data: scenario, error } = await supabaseClient
      .from('scenarios')
      .select('id, title, custom_ui_path, ui_template, event_type, roles')
      .eq('id', scenarioId)
      .single()

    if (error) throw error

    // Determine user's role in this scenario
    const { data: castMember } = await supabaseClient
      .from('cast_members')
      .select('id')
      .eq('user_id', currentUser.id)
      .single()

    const isJudge = scenario.roles?.judges?.includes(castMember?.id)
    const isParticipant = scenario.roles?.participants?.includes(castMember?.id)

    // Route based on custom UI and role
    if (scenario.custom_ui_path && scenario.ui_generated_at) {
      // Use auto-generated custom UI
      if (isJudge) {
        window.location.href = `/functions/v1/serve-generated-ui?scenario_id=${scenarioId}`
      } else if (isParticipant) {
        window.location.href = `/functions/v1/serve-generated-ui?scenario_id=${scenarioId}`
      } else {
        // Spectator - view only mode
        window.location.href = `/functions/v1/serve-generated-ui?scenario_id=${scenarioId}&mode=spectator`
      }
    } else {
      // Use standard response page
      window.location.href = `/pages/scenario-response.html?scenario_id=${scenarioId}`
    }

  } catch (error) {
    console.error('Error opening scenario:', error)
    // Fallback to standard page
    window.location.href = `/pages/scenario-response.html?scenario_id=${scenarioId}`
  }
}
```

## Example in scenario list

```javascript
scenarioHTML = scenarios.map(s => `
  <div class="scenario-item" onclick="openScenario('${s.scenarios.id}')">
    <div class="scenario-header">
      <div class="scenario-title">${s.scenarios.title}</div>
      ${s.scenarios.custom_ui_needed ? '<span class="badge">SPECIAL EVENT</span>' : ''}
    </div>
    <div class="scenario-desc">${s.scenarios.description}</div>
    <div class="scenario-footer">
      <button class="btn btn-primary btn-sm">
        ${getButtonText(s.scenarios, currentCastMemberId)}
      </button>
    </div>
  </div>
`).join('')

function getButtonText(scenario, castMemberId) {
  if (scenario.roles?.judges?.includes(castMemberId)) {
    return '⚖️ Judge'
  } else if (scenario.roles?.participants?.includes(castMemberId)) {
    return '📝 Participate'
  } else {
    return '👀 Watch'
  }
}
```
