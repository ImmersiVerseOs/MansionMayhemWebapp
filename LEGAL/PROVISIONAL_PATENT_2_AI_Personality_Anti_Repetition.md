# PROVISIONAL PATENT APPLICATION

**United States Patent and Trademark Office (USPTO)**

---

## TITLE OF INVENTION

**PERSONALITY-CONSISTENT AI TEXT GENERATION WITH MULTI-LAYER ANTI-REPETITION ENFORCEMENT**

---

## INVENTOR(S)

[Your Name]
ImmersiVerse OS Inc.
State of Michigan

---

## CROSS-REFERENCE TO RELATED APPLICATIONS

Not Applicable (New Application)

---

## STATEMENT REGARDING FEDERALLY SPONSORED RESEARCH

Not Applicable

---

## BACKGROUND OF THE INVENTION

### Field of the Invention

This invention relates to artificial intelligence text generation systems, specifically to methods and systems for generating personality-consistent AI responses while preventing linguistic repetition patterns across multiple levels of abstraction.

### Description of Related Art

Current AI text generation systems, particularly large language models (LLMs), face significant challenges with repetitive language patterns:

**Existing Approaches:**

1. **Token-level repetition prevention** - Systems like GPT use repetition penalties at the token level (prevent "the the the")
2. **N-gram blocking** - Prevent exact phrase repetition within a window
3. **Temperature/sampling adjustments** - Increase randomness to reduce repetition
4. **Prompt engineering** - Generic instructions like "be creative" or "vary your language"

**Problems with Existing Systems:**

- **Metaphor Family Repetition:** AI agents repeatedly use the same conceptual metaphors (e.g., "chess match," "playbook," "three steps ahead") even when individual words vary
- **Performative Language Patterns:** Over-reliance on abstract performative phrases ("writing dissertations," "giving TED Talks," "performing confessionals")
- **Personality Inconsistency:** Anti-repetition methods that increase randomness often break character personality and archetype consistency
- **Surface-Level Detection:** Existing systems detect exact phrase repetition but miss semantic/conceptual repetition
- **Lack of Domain Awareness:** Generic language models don't understand context-specific overused patterns (e.g., reality TV tropes)

**Need for Improvement:**

There is a need for AI text generation systems that maintain personality consistency while preventing repetition at multiple abstraction levels: exact phrases, metaphor families, and conceptual patterns, particularly in character-driven interactive applications.

---

## SUMMARY OF THE INVENTION

The present invention provides a **multi-layer anti-repetition enforcement system** integrated with **personality-consistent AI text generation** that:

1. **Maintains personality archetypes** - Ensures generated text aligns with predefined character traits, voice, and behavior patterns
2. **Detects repetition at multiple levels** - Identifies exact phrases, metaphor families, and conceptual patterns
3. **Enforces domain-specific bans** - Prevents context-specific overused language patterns (e.g., reality TV tropes, business jargon)
4. **Preserves semantic meaning** - Reduces repetition without sacrificing communication clarity or strategic content
5. **Adapts dynamically** - Learns from generated text to identify emerging repetition patterns

### Key Technical Innovations:

**A. Multi-Layer Repetition Detection:**
- **Layer 1 (Exact Phrases):** "chess match," "three steps ahead," "writing dissertations"
- **Layer 2 (Metaphor Families):** Chess metaphors, writing metaphors, performance metaphors
- **Layer 3 (Conceptual Patterns):** Over-explanation, contradictory phrasing, meta-commentary

**B. Personality-Consistent Constraints:**
- AI personalities maintained during generation (villain vs hero vs strategist)
- Anti-repetition enforcement doesn't introduce out-of-character language
- Strategic content preserved while removing linguistic fluff

**C. Context-Aware Linguistic Analysis:**
- Understanding of domain-specific overused patterns (reality TV, business, gaming)
- Semantic similarity detection across generated responses
- Identification of performative vs substantive language

**D. Adaptive Enforcement:**
- Real-time analysis of generated text against banned pattern database
- Regeneration triggers when repetition detected
- Pattern database updates based on usage analytics

---

## DETAILED DESCRIPTION OF THE INVENTION

### System Architecture

The invention comprises several interconnected components:

1. **Personality Profile Manager**
2. **Multi-Layer Repetition Detector**
3. **Semantic Pattern Analyzer**
4. **Text Generation Controller**
5. **Adaptive Pattern Learning Module**

### 1. Personality Profile Manager

**Purpose:** Define and enforce AI personality archetypes during text generation.

**Personality Dimensions:**
- **Archetype:** Villain, hero, strategist, wildcard, etc.
- **Communication Style:** Direct vs circumspect, emotional vs analytical
- **Strategic Behavior:** Aggressive vs defensive, loyal vs self-interested
- **Linguistic Markers:** Vocabulary, sentence structure, tone

**Implementation:**
```
PERSONALITY_PROFILE {
  archetype: "villain",
  traits: {
    communication_style: "manipulative",
    strategic_behavior: "self-interested",
    emotional_expression: "calculated",
    risk_tolerance: "high"
  },
  linguistic_markers: {
    preferred_vocabulary: ["opportunity", "advantage", "necessary"],
    avoided_vocabulary: ["fair", "right", "team"],
    sentence_complexity: "high",
    tone: "confident"
  }
}
```

### 2. Multi-Layer Repetition Detector

**Purpose:** Identify repetition at exact phrase, metaphor family, and conceptual levels.

**Layer 1: Exact Phrase Detection**
```
BANNED_EXACT_PHRASES = [
  "chess match",
  "three steps ahead",
  "writing dissertations",
  "whole novels",
  "reality show confessional",
  "TED Talk",
  "taking mental notes",
  ...
]

FUNCTION detectExactPhraseRepetition(generated_text):
  FOR EACH phrase IN BANNED_EXACT_PHRASES:
    IF phrase IN generated_text.lowercase():
      RETURN {
        detected: true,
        phrase: phrase,
        layer: "exact_phrase"
      }
    END IF
  END FOR
  RETURN {detected: false}
END FUNCTION
```

**Layer 2: Metaphor Family Detection**
```
METAPHOR_FAMILIES = {
  "chess_metaphors": [
    "chess", "playbook", "checkers", "4D chess",
    "moving pieces", "strategy game", "calculating moves",
    "three steps ahead", "endgame", "opening move"
  ],
  "writing_metaphors": [
    "dissertations", "novels", "essays", "books",
    "chapters", "term papers", "manifestos", "writing",
    "footnotes", "bibliography"
  ],
  "performance_metaphors": [
    "performing", "confessional", "TED Talk", "audition",
    "rehearsing", "scriptwriting", "monologue", "stage",
    "audience", "applause"
  ],
  "note_taking_metaphors": [
    "taking notes", "mental notes", "cataloging",
    "filing away", "recording", "documenting", "journaling"
  ],
  "contradiction_metaphors": [
    "quiet while screaming", "silent but loud",
    "still but moving", "calm chaos", "peaceful storm"
  ]
}

FUNCTION detectMetaphorFamilyRepetition(generated_text):
  text_lowercase = generated_text.lowercase()

  FOR EACH family_name, phrases IN METAPHOR_FAMILIES:
    FOR EACH phrase IN phrases:
      IF phrase IN text_lowercase:
        RETURN {
          detected: true,
          family: family_name,
          phrase: phrase,
          layer: "metaphor_family"
        }
      END IF
    END FOR
  END FOR

  RETURN {detected: false}
END FUNCTION
```

**Layer 3: Conceptual Pattern Detection**
```
CONCEPTUAL_PATTERNS = [
  {
    name: "over_explanation",
    indicators: [
      "let me explain",
      "what I mean is",
      "in other words",
      "to put it differently",
      "basically"
    ],
    threshold: 2  // Flag if 2+ indicators in single response
  },
  {
    name: "meta_commentary",
    indicators: [
      "I'm thinking",
      "I'm analyzing",
      "I'm calculating",
      "I'm strategizing",
      "in my mind"
    ],
    threshold: 2
  },
  {
    name: "performative_action",
    indicators: [
      "*", // Asterisks indicating actions
      "[thinking]",
      "[pauses]",
      "[smirks]"
    ],
    threshold: 1
  }
]

FUNCTION detectConceptualPatternRepetition(generated_text):
  FOR EACH pattern IN CONCEPTUAL_PATTERNS:
    indicator_count = 0

    FOR EACH indicator IN pattern.indicators:
      IF indicator IN generated_text.lowercase():
        indicator_count += 1
      END IF
    END FOR

    IF indicator_count >= pattern.threshold:
      RETURN {
        detected: true,
        pattern: pattern.name,
        count: indicator_count,
        layer: "conceptual_pattern"
      }
    END IF
  END FOR

  RETURN {detected: false}
END FUNCTION
```

### 3. Semantic Pattern Analyzer

**Purpose:** Identify semantic similarity and repetition across multiple generated responses.

**Key Innovation:** Traditional systems analyze individual text generations in isolation. This invention tracks semantic patterns across all responses from an AI agent to detect emerging repetitive concepts.

**Implementation:**
```
FUNCTION analyzeSemanticPatterns(ai_agent_id, new_generated_text):

  // Retrieve recent responses from this AI agent
  recent_responses = DATABASE.query(
    "SELECT response_text FROM responses
     WHERE ai_agent_id = ai_agent_id
     ORDER BY timestamp DESC
     LIMIT 20"
  )

  // Extract key concepts from new text
  new_concepts = extractKeyConcepts(new_generated_text)

  // Compare with concepts in recent responses
  concept_frequency = {}

  FOR EACH response IN recent_responses:
    response_concepts = extractKeyConcepts(response.text)

    FOR EACH concept IN new_concepts:
      FOR EACH prior_concept IN response_concepts:
        similarity = calculateSemanticSimilarity(concept, prior_concept)

        IF similarity > 0.8:  // High semantic similarity
          concept_frequency[concept] = (concept_frequency[concept] OR 0) + 1
        END IF
      END FOR
    END FOR
  END FOR

  // Flag overused concepts
  overused_concepts = []
  FOR EACH concept, frequency IN concept_frequency:
    IF frequency > 3:  // Concept appeared in 3+ recent responses
      overused_concepts.append(concept)
    END IF
  END FOR

  IF length(overused_concepts) > 0:
    RETURN {
      detected: true,
      overused_concepts: overused_concepts,
      layer: "semantic_pattern"
    }
  END IF

  RETURN {detected: false}
END FUNCTION
```

### 4. Text Generation Controller

**Purpose:** Integrate personality profiles and anti-repetition enforcement into AI text generation pipeline.

**Generation Process:**
```
FUNCTION generatePersonalityConsistentResponse(
  ai_agent,
  prompt,
  context
):

  personality = ai_agent.personality_profile
  max_attempts = 3
  attempt = 0

  WHILE attempt < max_attempts:
    attempt += 1

    // Build generation prompt with personality and anti-repetition instructions
    full_prompt = buildPrompt(
      base_prompt = prompt,
      personality_instructions = personality.linguistic_markers,
      context = context,
      anti_repetition_instructions = getAntiRepetitionInstructions()
    )

    // Generate text using LLM
    generated_text = LLM_API.generate(
      prompt = full_prompt,
      temperature = 0.7,  // Balanced creativity
      max_tokens = 500
    )

    // Multi-layer repetition detection
    exact_phrase_check = detectExactPhraseRepetition(generated_text)
    IF exact_phrase_check.detected:
      LOG("Exact phrase detected: " + exact_phrase_check.phrase)
      CONTINUE  // Regenerate
    END IF

    metaphor_check = detectMetaphorFamilyRepetition(generated_text)
    IF metaphor_check.detected:
      LOG("Metaphor family detected: " + metaphor_check.family)
      CONTINUE  // Regenerate
    END IF

    conceptual_check = detectConceptualPatternRepetition(generated_text)
    IF conceptual_check.detected:
      LOG("Conceptual pattern detected: " + conceptual_check.pattern)
      CONTINUE  // Regenerate
    END IF

    semantic_check = analyzeSemanticPatterns(ai_agent.id, generated_text)
    IF semantic_check.detected:
      LOG("Semantic repetition detected: " + semantic_check.overused_concepts)
      CONTINUE  // Regenerate
    END IF

    // All checks passed
    RETURN {
      success: true,
      text: generated_text,
      attempts: attempt
    }

  END WHILE

  // Max attempts reached - return best effort with warning
  RETURN {
    success: false,
    text: generated_text,  // Last attempt
    attempts: attempt,
    warning: "Could not eliminate all repetition patterns"
  }

END FUNCTION
```

**Anti-Repetition Instructions (Embedded in Prompt):**
```
getAntiRepetitionInstructions():
  RETURN """
  CRITICAL ANTI-REPETITION RULES:

  BANNED METAPHOR FAMILIES (DO NOT USE):
  1. ❌ Writing metaphors: "dissertations", "novels", "essays", "chapters"
  2. ❌ Chess metaphors: "chess match", "playbook", "three steps ahead"
  3. ❌ Performance metaphors: "TED Talk", "confessional", "rehearsing"
  4. ❌ Note-taking metaphors: "taking notes", "cataloging", "filing away"
  5. ❌ Contradiction phrases: "quiet while screaming", "silent but loud"

  INSTEAD:
  - React naturally and directly
  - State strategic thoughts clearly without metaphor
  - Avoid over-explanation
  - No meta-commentary about your thinking process
  - No performative action descriptions (no asterisks)

  EXECUTE, don't over-explain.
  """
END FUNCTION
```

### 5. Adaptive Pattern Learning Module

**Purpose:** Automatically identify emerging repetition patterns from usage analytics.

**Implementation:**
```
FUNCTION learnNewRepetitionPatterns():

  // Analyze all AI responses over past 30 days
  all_responses = DATABASE.query(
    "SELECT response_text, ai_agent_id
     FROM responses
     WHERE timestamp > NOW() - INTERVAL '30 days'"
  )

  // Extract n-grams (2-5 word phrases)
  phrase_frequency = {}

  FOR EACH response IN all_responses:
    phrases = extractNGrams(response.text, min=2, max=5)

    FOR EACH phrase IN phrases:
      phrase_frequency[phrase] = (phrase_frequency[phrase] OR 0) + 1
    END FOR
  END FOR

  // Identify overused phrases (appear in >10% of responses)
  threshold = length(all_responses) * 0.10
  new_banned_phrases = []

  FOR EACH phrase, count IN phrase_frequency:
    IF count > threshold:
      // Check if already banned
      IF phrase NOT IN BANNED_EXACT_PHRASES:
        new_banned_phrases.append({
          phrase: phrase,
          frequency: count,
          percentage: count / length(all_responses)
        })
      END IF
    END IF
  END FOR

  // Cluster similar phrases into metaphor families
  new_families = clusterPhrasesIntoFamilies(new_banned_phrases)

  // Update banned lists
  BANNED_EXACT_PHRASES.extend(new_banned_phrases)
  METAPHOR_FAMILIES.update(new_families)

  // Log for review
  LOG("Identified " + length(new_banned_phrases) + " new overused phrases")
  LOG("Created " + length(new_families) + " new metaphor families")

  RETURN {
    new_phrases: new_banned_phrases,
    new_families: new_families
  }

END FUNCTION
```

---

## USE CASE EXAMPLE

**Scenario:** AI villain character responding to an alliance proposal in a social strategy game.

**Without Invention (Repetitive):**
> "Well well, this is quite the chess match we're playing here. You're making interesting moves on the board, but I'm always three steps ahead. Let me write you a dissertation on why this alliance could work—or better yet, a whole novel on the strategy playbook we'd need. *takes mental notes* This is like performing in a confessional, being quiet while screaming my true intentions."

**Problems:**
- 7 banned metaphors (chess, moves, three steps ahead, dissertation, novel, playbook, confessional)
- 2 banned conceptual patterns (meta-commentary with asterisks, contradiction phrase)
- Over-explanation without strategic substance

**With Invention (Personality-Consistent, Non-Repetitive):**
> "Interesting timing. You need protection from the bottom two, and I need someone who won't backstab me next round. But here's the catch—I don't trust easily. Give me one reason why you won't flip on me the second you're safe. And make it convincing, because if I sense weakness, I'm voting you out myself."

**Improvements:**
- ✅ Villain personality maintained (manipulative, self-interested, direct)
- ✅ Zero banned metaphors or patterns
- ✅ Strategic substance (identifies mutual benefit, demands proof of loyalty, threatens if unconvinced)
- ✅ Natural, conversational tone
- ✅ Character-appropriate language

---

## ADVANTAGES OVER PRIOR ART

The present invention provides significant improvements over traditional AI text generation systems:

1. **Multi-Layer Detection:** Identifies repetition at exact phrase, metaphor family, and conceptual levels
2. **Personality Preservation:** Anti-repetition enforcement doesn't break character consistency
3. **Domain Awareness:** Prevents context-specific overused patterns (reality TV tropes, business jargon)
4. **Semantic Analysis:** Detects conceptual repetition across multiple responses, not just within single text
5. **Adaptive Learning:** Automatically identifies emerging repetition patterns from usage data
6. **Substantive Communication:** Reduces linguistic fluff while preserving strategic content
7. **User Engagement:** More natural, varied AI interactions increase user satisfaction

---

## CLAIMS

### Claim 1 (Independent Claim - System)

A personality-consistent AI text generation system with multi-layer anti-repetition enforcement, comprising:

(a) A personality profile manager configured to define and enforce AI personality archetypes including communication style, strategic behavior, and linguistic markers;

(b) A multi-layer repetition detector configured to identify repetition at exact phrase, metaphor family, and conceptual pattern levels;

(c) A semantic pattern analyzer configured to detect semantic similarity and conceptual repetition across multiple generated responses from an AI agent;

(d) A text generation controller configured to generate text that aligns with said personality profile while avoiding patterns detected by said multi-layer repetition detector and semantic pattern analyzer; and

(e) An adaptive pattern learning module configured to automatically identify emerging repetition patterns from usage analytics and update banned pattern databases.

### Claim 2 (Dependent Claim - Metaphor Family Detection)

The system of Claim 1, wherein the multi-layer repetition detector identifies metaphor families comprising semantically related phrases spanning a conceptual domain, including at least one of: chess metaphors, writing metaphors, performance metaphors, note-taking metaphors, or contradiction phrases.

### Claim 3 (Dependent Claim - Regeneration Triggers)

The system of Claim 1, wherein the text generation controller regenerates AI responses when the multi-layer repetition detector identifies banned patterns, with a maximum retry limit to prevent infinite loops.

### Claim 4 (Dependent Claim - Semantic Similarity Threshold)

The system of Claim 1, wherein the semantic pattern analyzer calculates semantic similarity between concepts in new generated text and concepts in prior responses, flagging concepts that exceed a similarity threshold in a specified number of recent responses.

### Claim 5 (Dependent Claim - Personality Dimensions)

The system of Claim 1, wherein the personality profile manager defines personalities across multiple dimensions including archetype classification, communication style, strategic behavior patterns, and linguistic markers comprising preferred vocabulary, avoided vocabulary, and sentence complexity.

### Claim 6 (Independent Claim - Method)

A computer-implemented method for generating personality-consistent AI text with anti-repetition enforcement, comprising:

(a) Receiving a text generation request for an AI agent with a defined personality profile;

(b) Generating candidate text using a language model with personality-specific prompts and anti-repetition instructions;

(c) Analyzing said candidate text for repetition patterns at exact phrase, metaphor family, and conceptual pattern levels;

(d) Analyzing said candidate text for semantic similarity with prior responses from said AI agent;

(e) If repetition or excessive semantic similarity is detected, regenerating candidate text with updated constraints; and

(f) If no repetition is detected, returning said candidate text as final generated response.

### Claim 7 (Dependent Claim - Multi-Layer Analysis Order)

The method of Claim 6, wherein said analyzing steps are performed in order from exact phrase detection to metaphor family detection to conceptual pattern detection to semantic similarity analysis, with early termination and regeneration upon detection at any layer.

### Claim 8 (Dependent Claim - Domain-Specific Ban Lists)

The method of Claim 6, wherein said anti-repetition instructions include domain-specific banned phrase lists tailored to application context, including at least one of: reality TV tropes, business jargon, gaming terminology, or social media language patterns.

### Claim 9 (Dependent Claim - Adaptive Learning)

The method of Claim 6, further comprising periodically analyzing generated text across all AI agents to identify emerging repetition patterns, clustering similar patterns into metaphor families, and updating anti-repetition instructions with newly identified banned patterns.

### Claim 10 (Independent Claim - Computer-Readable Medium)

A non-transitory computer-readable medium storing instructions that, when executed by a processor, cause the processor to:

(a) Define a personality profile for an AI agent including archetype, communication style, and linguistic markers;

(b) Generate text using a language model constrained by said personality profile and multi-layer anti-repetition rules;

(c) Detect repetition in said generated text at exact phrase, metaphor family, and conceptual pattern levels;

(d) Analyze semantic similarity between said generated text and prior responses from said AI agent; and

(e) Regenerate text if repetition or excessive semantic similarity is detected, ensuring personality consistency while preventing linguistic repetition.

---

## ABSTRACT

A personality-consistent AI text generation system with multi-layer anti-repetition enforcement generates AI responses that maintain character personality archetypes while preventing linguistic repetition at exact phrase, metaphor family, and conceptual pattern levels. The system analyzes semantic similarity across multiple responses to detect emerging repetition patterns and adaptively updates banned pattern databases. A text generation controller regenerates responses when repetition is detected, ensuring natural, varied AI interactions that preserve strategic content and character consistency. This approach significantly improves user engagement in character-driven interactive applications by eliminating robotic, repetitive AI language patterns.

---

## DRAWINGS (To Be Provided)

- Figure 1: System architecture diagram
- Figure 2: Multi-layer repetition detection flowchart
- Figure 3: Metaphor family detection process
- Figure 4: Semantic pattern analysis across multiple responses
- Figure 5: Text generation controller with regeneration logic
- Figure 6: Adaptive pattern learning module workflow

---

**Applicant Information:**

**Company:** ImmersiVerse OS Inc.
**State:** Michigan
**Date Filed:** [To be filled by USPTO]
**Application Number:** [To be assigned by USPTO]

---

**NOTES FOR FILING:**
- File as **Provisional Patent Application** (Form PTO/SB/16)
- Filing fee: ~$75-$150 (micro/small entity) or ~$300 (large entity)
- This gives you 12 months to file full utility patent
- Can claim "Patent Pending" status immediately upon filing
- Priority date established on filing date

**Next Steps:**
1. Review and refine claims with patent attorney
2. Create technical diagrams (Figures 1-6)
3. File provisional application via USPTO website or mail
4. Within 12 months, file full utility patent application (non-provisional)

---

**© 2026 ImmersiVerse OS Inc.**
