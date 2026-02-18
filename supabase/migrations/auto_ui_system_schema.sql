-- ============================================================================
-- AUTO UI GENERATION SYSTEM - DATABASE SCHEMA
-- Supports self-generating UI based on scenario analysis
-- ============================================================================

-- Add analysis fields to scenarios table
ALTER TABLE scenarios
ADD COLUMN IF NOT EXISTS event_type TEXT DEFAULT 'standard',
ADD COLUMN IF NOT EXISTS roles JSONB,
ADD COLUMN IF NOT EXISTS ui_template TEXT DEFAULT 'standard',
ADD COLUMN IF NOT EXISTS custom_ui_needed BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS custom_ui_path TEXT,
ADD COLUMN IF NOT EXISTS analyzed_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS analysis_confidence INTEGER,
ADD COLUMN IF NOT EXISTS ui_generated_at TIMESTAMPTZ;

-- Create scenario_analyses table for tracking
CREATE TABLE IF NOT EXISTS scenario_analyses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  scenario_id UUID REFERENCES scenarios(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL,
  roles JSONB,
  ui_template TEXT,
  custom_ui_needed BOOLEAN DEFAULT false,
  detected_keywords TEXT[],
  confidence INTEGER,
  analyzed_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create generated_uis table for tracking UI generation
CREATE TABLE IF NOT EXISTS generated_uis (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  scenario_id UUID REFERENCES scenarios(id) ON DELETE CASCADE,
  file_path TEXT,
  template_used TEXT,
  generation_prompt TEXT,
  generated_html TEXT, -- Store generated HTML
  generated_at TIMESTAMPTZ DEFAULT NOW(),
  deployed_at TIMESTAMPTZ,
  commit_sha TEXT,
  generation_status TEXT DEFAULT 'pending', -- pending, completed, failed
  error_message TEXT
);

-- Create scenario_votes table for judge mode
CREATE TABLE IF NOT EXISTS scenario_votes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  scenario_id UUID REFERENCES scenarios(id) ON DELETE CASCADE,
  judge_cast_member_id UUID REFERENCES cast_members(id),
  participant_cast_member_id UUID REFERENCES cast_members(id),
  vote_score INTEGER CHECK (vote_score >= 1 AND vote_score <= 5),
  vote_comment TEXT,
  voted_at TIMESTAMPTZ DEFAULT NOW(),

  -- Prevent duplicate votes
  UNIQUE(scenario_id, judge_cast_member_id, participant_cast_member_id)
);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_scenarios_event_type ON scenarios(event_type);
CREATE INDEX IF NOT EXISTS idx_scenarios_analyzed_at ON scenarios(analyzed_at);
CREATE INDEX IF NOT EXISTS idx_scenario_analyses_scenario_id ON scenario_analyses(scenario_id);
CREATE INDEX IF NOT EXISTS idx_generated_uis_scenario_id ON generated_uis(scenario_id);
CREATE INDEX IF NOT EXISTS idx_scenario_votes_scenario_id ON scenario_votes(scenario_id);
CREATE INDEX IF NOT EXISTS idx_scenario_votes_judge ON scenario_votes(judge_cast_member_id);

-- Add RLS policies
ALTER TABLE scenario_analyses ENABLE ROW LEVEL SECURITY;
ALTER TABLE generated_uis ENABLE ROW LEVEL SECURITY;
ALTER TABLE scenario_votes ENABLE ROW LEVEL SECURITY;

-- Allow all authenticated users to read analyses
CREATE POLICY "Allow read scenario_analyses" ON scenario_analyses
  FOR SELECT USING (true);

-- Allow all authenticated users to read generated UIs
CREATE POLICY "Allow read generated_uis" ON generated_uis
  FOR SELECT USING (true);

-- Allow judges to insert votes
CREATE POLICY "Allow judges to vote" ON scenario_votes
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM scenarios s
      WHERE s.id = scenario_id
      AND s.roles->'judges' ? judge_cast_member_id::text
    )
  );

-- Allow users to read votes
CREATE POLICY "Allow read scenario_votes" ON scenario_votes
  FOR SELECT USING (true);

-- Add comments
COMMENT ON TABLE scenario_analyses IS 'Tracks AI analysis of scenarios to determine UI needs';
COMMENT ON TABLE generated_uis IS 'Tracks auto-generated UI pages for special scenarios';
COMMENT ON TABLE scenario_votes IS 'Stores judge votes for judge-mode scenarios';
COMMENT ON COLUMN scenarios.event_type IS 'Type of event: standard, judge, vote, challenge, tribunal, summit';
COMMENT ON COLUMN scenarios.roles IS 'JSON object defining judges, participants, spectators';
COMMENT ON COLUMN scenarios.ui_template IS 'UI template to use: standard, judge-panel, voting-booth, challenge-arena, tribunal-court';
