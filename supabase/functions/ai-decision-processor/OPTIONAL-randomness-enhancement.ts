// ============================================================================
// OPTIONAL ENHANCEMENT: Add Response Time Variance
// ============================================================================
// This file contains code to make AI responses feel more human-like by adding
// random variance to cooldown timing. This prevents AI from responding at
// exactly predictable intervals.
//
// TO USE: Copy the relevant sections into index.ts
// ============================================================================

/**
 * Add random variance to cooldown timing (±30%)
 * Makes AI responses feel less robotic and more human-like
 *
 * Examples:
 * - 10 min cooldown → 7-13 min range
 * - 20 min cooldown → 14-26 min range
 * - 40 min cooldown → 28-52 min range
 *
 * @param baseMinutes - The base cooldown in minutes
 * @returns Adjusted cooldown with random variance
 */
function addRandomVariance(baseMinutes: number): number {
  const variance = baseMinutes * 0.3; // ±30% variance
  const randomOffset = (Math.random() * 2 - 1) * variance; // -variance to +variance
  return Math.max(1, Math.round(baseMinutes + randomOffset)); // Minimum 1 minute
}

// ============================================================================
// INTEGRATION INSTRUCTIONS
// ============================================================================

/*
Step 1: Add the helper function near the top of index.ts (after imports, around line 10)

Step 2: Update the cooldown calculation in processAIAllianceMessages() function
        (around line 322-327)

BEFORE:
--------
const config = ai.ai_personality_config;
const socialActivity = config?.traits?.social_activity || 0.5;

const cooldownMinutes =
  socialActivity > 0.7 ? 10 :
  socialActivity > 0.4 ? 20 :
  40;

if (minutesSinceLastMessage < cooldownMinutes) {
  console.log(
    `Skipping room ${room.id} - cooldown not met ` +
    `(${minutesSinceLastMessage.toFixed(1)} min < ${cooldownMinutes} min required)`
  );
  continue;
}

AFTER:
------
const config = ai.ai_personality_config;
const socialActivity = config?.traits?.social_activity || 0.5;

// Base cooldown without variance
const baseCooldownMinutes =
  socialActivity > 0.7 ? 10 :
  socialActivity > 0.4 ? 20 :
  40;

// Add ±30% randomness for human-like variability
const cooldownMinutes = addRandomVariance(baseCooldownMinutes);

console.log(
  `${ai.display_name} cooldown: ${cooldownMinutes} min ` +
  `(base: ${baseCooldownMinutes} min, social_activity: ${socialActivity})`
);

if (minutesSinceLastMessage < cooldownMinutes) {
  console.log(
    `Skipping room ${room.id} - cooldown not met ` +
    `(${minutesSinceLastMessage.toFixed(1)} min < ${cooldownMinutes} min required)`
  );
  continue;
}

Step 3: Redeploy the function
------
cd supabase/functions
supabase functions deploy ai-decision-processor

*/

// ============================================================================
// ALTERNATIVE VARIANCE STRATEGIES
// ============================================================================

/**
 * Personality-based variance: Different archetypes get different variance levels
 * Queens and villains: More erratic timing (±40%)
 * Strategists: Very consistent timing (±15%)
 * Others: Standard variance (±30%)
 */
function addPersonalityBasedVariance(
  baseMinutes: number,
  archetype: string
): number {
  let variancePercent = 0.3; // Default 30%

  switch (archetype) {
    case 'queen':
    case 'villain':
      variancePercent = 0.4; // More unpredictable (±40%)
      break;
    case 'strategist':
      variancePercent = 0.15; // Very consistent (±15%)
      break;
    case 'wildcard':
      variancePercent = 0.5; // Extremely unpredictable (±50%)
      break;
    default:
      variancePercent = 0.3; // Standard (±30%)
  }

  const variance = baseMinutes * variancePercent;
  const randomOffset = (Math.random() * 2 - 1) * variance;
  return Math.max(1, Math.round(baseMinutes + randomOffset));
}

/**
 * Time-of-day variance: AI is more active during "prime time" hours
 * Reduces cooldowns during peak hours (12pm-2pm, 6pm-11pm UTC)
 * Increases cooldowns during off-peak hours (2am-8am UTC)
 */
function addTimeOfDayVariance(baseMinutes: number): number {
  const hour = new Date().getUTCHours();

  let timeMultiplier = 1.0;

  // Prime time: Lunch (12pm-2pm UTC)
  if (hour >= 12 && hour < 14) {
    timeMultiplier = 0.7; // 30% faster responses
  }
  // Prime time: Evening (6pm-11pm UTC)
  else if (hour >= 18 && hour < 23) {
    timeMultiplier = 0.8; // 20% faster responses
  }
  // Off-peak: Late night/early morning (2am-8am UTC)
  else if (hour >= 2 && hour < 8) {
    timeMultiplier = 1.5; // 50% slower responses
  }

  const adjustedMinutes = baseMinutes * timeMultiplier;

  // Still add some randomness
  const variance = adjustedMinutes * 0.2;
  const randomOffset = (Math.random() * 2 - 1) * variance;

  return Math.max(1, Math.round(adjustedMinutes + randomOffset));
}

/**
 * Combined variance: Uses both personality and time-of-day factors
 */
function addCombinedVariance(
  baseMinutes: number,
  archetype: string
): number {
  // Step 1: Apply personality variance
  const personalityAdjusted = addPersonalityBasedVariance(baseMinutes, archetype);

  // Step 2: Apply time-of-day variance
  const finalMinutes = addTimeOfDayVariance(personalityAdjusted);

  return finalMinutes;
}

// ============================================================================
// USAGE EXAMPLES
// ============================================================================

/*
// Example 1: Simple random variance
const cooldownMinutes = addRandomVariance(baseCooldownMinutes);

// Example 2: Personality-based variance
const cooldownMinutes = addPersonalityBasedVariance(
  baseCooldownMinutes,
  ai.archetype
);

// Example 3: Time-of-day variance
const cooldownMinutes = addTimeOfDayVariance(baseCooldownMinutes);

// Example 4: Combined variance (most realistic)
const cooldownMinutes = addCombinedVariance(
  baseCooldownMinutes,
  ai.archetype
);
*/

// ============================================================================
// TESTING VARIANCE
// ============================================================================

/*
To test variance logic:

console.log('Testing variance for 10-minute base cooldown:');
for (let i = 0; i < 10; i++) {
  console.log(`  Run ${i + 1}: ${addRandomVariance(10)} minutes`);
}

Expected output:
  Run 1: 8 minutes
  Run 2: 12 minutes
  Run 3: 7 minutes
  Run 4: 13 minutes
  Run 5: 10 minutes
  Run 6: 11 minutes
  Run 7: 9 minutes
  Run 8: 10 minutes
  Run 9: 12 minutes
  Run 10: 8 minutes

Range should be 7-13 minutes (±30% of 10)
*/

// ============================================================================
// BENEFITS OF VARIANCE
// ============================================================================

/*
1. Human-like behavior:
   - Real people don't respond at exactly 10:00, 10:10, 10:20
   - Variance makes AI feel more authentic

2. Prevents pattern recognition:
   - Users can't easily identify AI by timing alone
   - Makes game feel more organic and less scripted

3. Distributes load:
   - Not all AI characters respond at exact same intervals
   - Smooths out database and API request patterns

4. Adds drama:
   - Unpredictable timing creates suspense
   - "Will they respond now or in 5 minutes?"

5. Personality expression:
   - High-energy characters can be erratic
   - Strategic characters can be more predictable
   - Reflects character traits in timing behavior
*/

// ============================================================================
// CONSIDERATIONS
// ============================================================================

/*
1. Don't add TOO much variance:
   - ±50% might feel too random
   - ±20-30% is a good sweet spot

2. Keep minimum bounds:
   - Never go below 1 minute cooldown
   - Prevents spam-like behavior

3. Log variance for debugging:
   - Include base and adjusted times in logs
   - Helps troubleshoot if timing feels off

4. Test with real users:
   - Some users prefer predictable timing
   - Others prefer realistic unpredictability
   - Find the right balance for your audience

5. Consider game phase:
   - Maybe less variance during critical moments (finals)
   - More variance during casual phases (lobby)
*/

// ============================================================================
// DEPLOYMENT NOTE
// ============================================================================

/*
This is an OPTIONAL enhancement. The system works great without it.

Recommend deploying basic real-time AI first, then adding variance later
if you want to make AI feel even more human-like.

To deploy with variance:
1. Copy desired variance function(s) to index.ts
2. Update cooldown calculation to use variance
3. Test locally with `supabase functions serve`
4. Deploy: `supabase functions deploy ai-decision-processor`
5. Monitor logs to verify variance is working
6. Gather player feedback on timing feel
*/

export {
  addRandomVariance,
  addPersonalityBasedVariance,
  addTimeOfDayVariance,
  addCombinedVariance
};
