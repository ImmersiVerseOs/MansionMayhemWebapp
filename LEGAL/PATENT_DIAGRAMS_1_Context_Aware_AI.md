# Patent Diagrams - Context-Aware AI Decision System

**Patent Application 1:** Context-Aware Multi-Source AI Decision-Making System

---

## Figure 1: System Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                   AI DECISION-MAKING SYSTEM                      │
│                                                                  │
│  ┌────────────────┐  ┌──────────────────┐  ┌─────────────────┐│
│  │   Context      │  │   Relationship   │  │ Conversational  ││
│  │   Gathering    │→ │   Analysis       │→ │ Context         ││
│  │   Module       │  │   Engine         │  │ Analyzer        ││
│  └────────────────┘  └──────────────────┘  └─────────────────┘│
│          ↓                    ↓                      ↓          │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │           Strategic Decision Engine                      │  │
│  │  • Voting decisions                                      │  │
│  │  • Alliance formation                                    │  │
│  │  • Communication strategy                               │  │
│  └──────────────────────────────────────────────────────────┘  │
│          ↓                                                      │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │       Personality Consistency Manager                    │  │
│  │  Ensures decisions align with AI archetype               │  │
│  └──────────────────────────────────────────────────────────┘  │
│          ↓                                                      │
│     [DECISION OUTPUT]                                           │
└─────────────────────────────────────────────────────────────────┘

DATA SOURCES (External):
┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│  Alliance    │  │   Public     │  │ Relationship │  │  Game State  │
│  Chat        │  │   Drama      │  │  Graph       │  │  Database    │
│  Messages    │  │   Posts      │  │  Database    │  │              │
└──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘
       ↑                 ↑                 ↑                 ↑
       └─────────────────┴─────────────────┴─────────────────┘
                    Feeds into Context Gathering Module
```

**Description:** High-level system architecture showing five main components and their data flow. External data sources feed into the Context Gathering Module, which processes information through analysis engines before the Strategic Decision Engine makes personality-consistent decisions.

---

## Figure 2: Context Gathering Module Flowchart

```
                        [START]
                           ↓
              ┌────────────────────────┐
              │  Receive AI Agent ID   │
              │  + Game ID             │
              └────────────────────────┘
                           ↓
        ┌──────────────────┴──────────────────┐
        ↓                                      ↓
┌──────────────────┐                  ┌──────────────────┐
│ Query Alliance   │                  │  Query Public    │
│ Memberships      │                  │  Drama Posts     │
│ (WHERE agent_id) │                  │  (last N posts)  │
└──────────────────┘                  └──────────────────┘
        ↓                                      ↓
┌──────────────────┐                  ┌──────────────────┐
│ Get Last N       │                  │  Extract Post    │
│ Alliance Chat    │                  │  Content +       │
│ Messages         │                  │  Authors         │
└──────────────────┘                  └──────────────────┘
        ↓                                      ↓
        └──────────────────┬───────────────────┘
                           ↓
                  ┌─────────────────┐
                  │ Query Nominees  │
                  │ (current round) │
                  └─────────────────┘
                           ↓
                  ┌─────────────────┐
                  │ Query Relation- │
                  │ ship Graph      │
                  └─────────────────┘
                           ↓
                ┌──────────────────────┐
                │  Build Context       │
                │  Object:             │
                │  - Alliances         │
                │  - Chat history      │
                │  - Public posts      │
                │  - Nominees          │
                │  - Relationships     │
                └──────────────────────┘
                           ↓
                   [RETURN CONTEXT]
```

**Description:** Flowchart showing how the Context Gathering Module collects data from multiple sources (alliance memberships, chat messages, public posts, nominees, relationships) and assembles them into a unified context object.

---

## Figure 3: Relationship Analysis Engine Process

```
          [RECEIVE: Context + AI Agent ID]
                        ↓
            ┌──────────────────────┐
            │  FOR EACH Nominee    │
            │  in Current Round    │
            └──────────────────────┘
                        ↓
        ┌───────────────┴───────────────┐
        ↓                               ↓
┌──────────────────┐          ┌──────────────────┐
│ Check Alliance   │          │  Analyze Chat    │
│ Status:          │          │  Mentions:       │
│ - Is ally?       │          │  - Sentiment     │
│ - Trust score    │          │  - Frequency     │
└──────────────────┘          └──────────────────┘
        ↓                               ↓
        └───────────────┬───────────────┘
                        ↓
            ┌──────────────────────┐
            │  Calculate Threat    │
            │  Level:              │
            │  - Power position    │
            │  - Alliance count    │
            │  - Negative mentions │
            └──────────────────────┘
                        ↓
            ┌──────────────────────┐
            │  Store in            │
            │  Relationship Map:   │
            │  {                   │
            │   nominee_id: {      │
            │    is_ally: bool,    │
            │    sentiment: num,   │
            │    threat: num       │
            │   }                  │
            │  }                   │
            └──────────────────────┘
                        ↓
            [RETURN RELATIONSHIP MAP]
```

**Description:** Process diagram showing how the Relationship Analysis Engine evaluates each nominee by checking alliance status, analyzing chat mentions, and calculating threat levels to build a comprehensive relationship map.

---

## Figure 4: Conversational Context Analyzer Flowchart

```
        [RECEIVE: Alliance Chat Messages]
                        ↓
            ┌──────────────────────┐
            │  Initialize:         │
            │  - active_topics     │
            │  - strategic_plans   │
            │  - betrayal_signals  │
            │  - sentiment_trend   │
            └──────────────────────┘
                        ↓
            ┌──────────────────────┐
            │  FOR i = 0 to        │
            │  length(messages)    │
            └──────────────────────┘
                        ↓
                ┌──────────────┐
                │ Is Question? │
                └──────────────┘
                   ↓        ↓
                  YES       NO
                   ↓         ↓
        ┌──────────────┐    │
        │ Check Next   │    │
        │ Message:     │    │
        │ Is Answer?   │    │
        └──────────────┘    │
              ↓             │
             YES            │
              ↓             │
    ┌──────────────────┐   │
    │ Store Q&A Pair   │   │
    │ in active_topics │   │
    └──────────────────┘   │
              ↓             ↓
              └─────┬───────┘
                    ↓
        ┌──────────────────────┐
        │ Contains Strategy    │
        │ Keywords?            │
        └──────────────────────┘
                ↓         ↓
               YES        NO
                ↓          ↓
    ┌──────────────────┐  │
    │ Extract Strategy │  │
    │ Add to plans     │  │
    └──────────────────┘  │
                ↓         ↓
                └────┬────┘
                     ↓
        ┌──────────────────────┐
        │ Contains Betrayal    │
        │ Language?            │
        └──────────────────────┘
                ↓         ↓
               YES        NO
                ↓          ↓
    ┌──────────────────┐  │
    │ Extract Target   │  │
    │ Add to betrayal  │  │
    └──────────────────┘  │
                ↓         ↓
                └────┬────┘
                     ↓
          [NEXT MESSAGE: i++]
                     ↓
          [RETURN CONVERSATION ANALYSIS]
```

**Description:** Flowchart demonstrating how the Conversational Context Analyzer processes messages sequentially to identify question-answer pairs, strategic plans, and betrayal indicators.

---

## Figure 5: Strategic Decision Engine - Voting Logic Flow

```
   [INPUT: AI Agent + Context + Relationships + Conversation]
                           ↓
              ┌────────────────────────┐
              │  Get Nominees:         │
              │  - Nominee A           │
              │  - Nominee B           │
              └────────────────────────┘
                           ↓
        ┌──────────────────────────────────────┐
        │  RULE 1: Protect Direct Allies       │
        └──────────────────────────────────────┘
                           ↓
        ┌──────────────────────────────────────┐
        │  IF allied with A AND NOT with B     │───YES──→ [VOTE FOR B]
        │  OR allied with B AND NOT with A     │───YES──→ [VOTE FOR A]
        └──────────────────────────────────────┘
                           ↓ NO
        ┌──────────────────────────────────────┐
        │  RULE 2: Eliminate Threats           │
        └──────────────────────────────────────┘
                           ↓
        ┌──────────────────────────────────────┐
        │  IF threat_level(A) > threat_level(B)│───YES──→ [VOTE FOR A]
        │  OR threat_level(B) > threat_level(A)│───YES──→ [VOTE FOR B]
        └──────────────────────────────────────┘
                           ↓ NO
        ┌──────────────────────────────────────┐
        │  RULE 3: Respond to Betrayal         │
        └──────────────────────────────────────┘
                           ↓
        ┌──────────────────────────────────────┐
        │  FOR EACH betrayal in conversation:  │
        │    IF betrayer == A                  │───YES──→ [VOTE FOR A]
        │    IF betrayer == B                  │───YES──→ [VOTE FOR B]
        └──────────────────────────────────────┘
                           ↓ NO
        ┌──────────────────────────────────────┐
        │  RULE 4: Follow Strategic Plans      │
        └──────────────────────────────────────┐
                           ↓
        ┌──────────────────────────────────────┐
        │  FOR EACH plan in conversation:      │
        │    IF plan targets A                 │───YES──→ [VOTE FOR A]
        │    IF plan targets B                 │───YES──→ [VOTE FOR B]
        └──────────────────────────────────────┘
                           ↓ NO
        ┌──────────────────────────────────────┐
        │  RULE 5: Personality-Driven          │
        └──────────────────────────────────────┘
                           ↓
                ┌─────────────────┐
                │  AI Archetype?  │
                └─────────────────┘
            ↓            ↓            ↓
        VILLAIN      HERO         STRATEGIST
            ↓            ↓            ↓
    ┌──────────┐  ┌──────────┐  ┌──────────┐
    │ Keep     │  │ Vote     │  │ Long-    │
    │ Drama    │  │ Fairly   │  │ term     │
    │ Source   │  │ Based on │  │ Game     │
    │ Alive    │  │ Sentiment│  │ Theory   │
    └──────────┘  └──────────┘  └──────────┘
            ↓            ↓            ↓
            └────────┬───┴────────────┘
                     ↓
        ┌─────────────────────────┐
        │  DEFAULT:               │
        │  Vote based on public   │
        │  sentiment analysis     │
        └─────────────────────────┘
                     ↓
            [RETURN VOTE DECISION]
```

**Description:** Detailed decision tree showing the Strategic Decision Engine's voting logic with five rule layers (protect allies, eliminate threats, respond to betrayal, follow plans, personality-driven) cascading to a default sentiment-based decision.

---

## Figure 6: Example Voting Decision - Real Scenario

```
SCENARIO: AI Agent "Villain" voting between Nominees A and B

┌─────────────────────────────────────────────────────┐
│  INPUT DATA:                                        │
│  • AI Agent: "Victoria" (Archetype: Villain)        │
│  • Nominee A: "Sarah"                               │
│  • Nominee B: "Mike"                                │
│                                                     │
│  CONTEXT:                                           │
│  • Victoria allied with Sarah                       │
│  • Victoria NOT allied with Mike                    │
│  • Alliance chat: "Mike is getting too powerful"    │
│  • Public drama: Mike has 3 negative posts          │
│  • Threat scores: Sarah=2, Mike=8                   │
└─────────────────────────────────────────────────────┘
                        ↓
        ┌───────────────────────────┐
        │  RULE 1: Protect Allies   │
        └───────────────────────────┘
                        ↓
        ┌───────────────────────────────────┐
        │  Victoria allied with Sarah?      │
        │  YES → Protect Sarah              │
        │  Decision: VOTE FOR MIKE          │
        └───────────────────────────────────┘
                        ↓
        ┌───────────────────────────────────┐
        │  Additional Context Check:        │
        │  • Mike threat=8 (high)           │
        │  • Alliance discussed eliminating │
        │    Mike                           │
        │  • Aligns with villain archetype  │
        │    (eliminate strong players)     │
        │                                   │
        │  ✓ Decision confirmed             │
        └───────────────────────────────────┘
                        ↓
        ┌───────────────────────────────────┐
        │  OUTPUT:                          │
        │  Vote: MIKE                       │
        │  Reasoning: "Protect ally Sarah + │
        │             eliminate threat Mike"│
        │  Confidence: HIGH                 │
        └───────────────────────────────────┘
```

**Description:** Concrete example showing how the system processes real game data through the decision logic to reach a strategic voting decision with reasoning.

---

## Creating Professional Diagrams

### Tools You Can Use:
1. **Draw.io (Free)** - https://app.diagrams.net/
   - Open source, web-based
   - Export as PNG/PDF

2. **Lucidchart** - https://www.lucidchart.com/
   - Professional diagramming
   - 7-day free trial

3. **Microsoft PowerPoint**
   - Use SmartArt and shapes
   - Export slides as images

4. **Hand-Drawn (USPTO Accepts)**
   - Draw on paper
   - Scan at 300 DPI
   - Must be clear and legible

### USPTO Requirements:
- **Format:** PDF, JPEG, or PNG
- **Resolution:** Minimum 300 DPI
- **Size:** 8.5" × 11" (letter size)
- **Margins:** 1" top, 1" left/right, 0.5" bottom
- **Line thickness:** Clear and distinct
- **Labels:** All elements must be labeled with reference numerals

### Quick Creation Guide:
1. Open draw.io or PowerPoint
2. Use these ASCII diagrams as templates
3. Recreate using boxes, arrows, and text
4. Keep it simple - USPTO prefers clarity over beauty
5. Export as PDF at 300 DPI

---

**Files Location:**
`C:\Users\15868\MansionMayhemWebapp\LEGAL\PATENT_DIAGRAMS_1_Context_Aware_AI.md`

**Next:** See `PATENT_DIAGRAMS_2_AI_Personality.md` for second patent's diagrams
