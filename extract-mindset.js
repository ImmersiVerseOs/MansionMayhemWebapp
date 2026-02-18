#!/usr/bin/env node

/**
 * MINDSET EXTRACTION ENGINE
 * Analyzes Claude conversation history to extract thought patterns
 */

const fs = require('fs');
const path = require('path');

// Patterns to detect
const PATTERNS = {
  'Burst Ideation': {
    keywords: ['what if', 'we could', 'or we can', 'also', 'and then'],
    indicators: [
      'Multiple ideas in quick succession',
      'Building on previous idea immediately',
      'Generating variations rapidly'
    ],
    detectMultipleIdeas: true
  },
  'ROI-First Filter': {
    keywords: ['$', 'cost', 'revenue', 'profit', 'how much', 'price', 'save', 'make money'],
    indicators: [
      'Calculating costs unprompted',
      'Asking about revenue model',
      'Comparing options by ROI'
    ],
    detectNumbers: true
  },
  '2-Click Philosophy': {
    keywords: ['simple', 'easy', 'just', 'click', '2 step', 'one command'],
    indicators: [
      'Simplifying complex flows',
      'Removing unnecessary steps',
      'Voice command as interface'
    ],
    detectSimplification: true
  },
  'Systems Thinking': {
    keywords: ['ecosystem', 'platform', 'architecture', 'stack', 'integration', 'connect'],
    indicators: [
      'Thinking beyond single feature',
      'Connecting multiple systems',
      'Full-stack considerations'
    ],
    detectConnections: true
  },
  'Pivot Speed': {
    keywords: ['or', 'instead', 'what about', 'switch to', 'lets do', 'change to'],
    indicators: [
      'Changing direction quickly',
      'Suggesting alternatives',
      'Moving past obstacles'
    ],
    detectDirectionChange: true
  },
  'Proof-First': {
    keywords: ['test', 'try', 'demo', 'show me', 'lets see', 'preview'],
    indicators: [
      'Requesting demos',
      'Testing before committing',
      'Visual proof preference'
    ],
    detectTestingMentality: true
  },
  'Market Gap Hunting': {
    keywords: ['competitor', 'better', '100x', 'different', 'unique', 'nobody else'],
    indicators: [
      'Comparing to competitors',
      'Seeking differentiation',
      'Ambitious improvement goals'
    ],
    detectCompetitiveAnalysis: true
  },
  'Full-Stack Vision': {
    keywords: ['database', 'backend', 'frontend', 'deploy', 'marketing', 'revenue'],
    indicators: [
      'Thinking database to UI to money',
      'Cross-layer considerations',
      'End-to-end thinking'
    ],
    detectLayeredThinking: true
  }
};

class MindsetExtractor {
  constructor(sessionFiles) {
    this.sessions = sessionFiles;
    this.patterns = {};
    this.examples = {};
    this.vocabulary = {
      frequentWords: {},
      phrases: [],
      style: {}
    };
    this.decisions = [];
    this.pivots = [];
    this.ideas = [];
  }

  async analyze() {
    console.log('🧬 MINDSET EXTRACTION ENGINE');
    console.log(`📁 Analyzing ${this.sessions.length} session files...\n`);

    for (const sessionFile of this.sessions) {
      await this.processSession(sessionFile);
    }

    this.calculateConfidence();
    return this.generateSOUL();
  }

  async processSession(filePath) {
    try {
      const content = fs.readFileSync(filePath, 'utf-8');
      const lines = content.split('\n').filter(l => l.trim());

      let sessionStats = {
        userMessages: 0,
        ideas: 0,
        decisions: 0,
        pivots: 0
      };

      for (const line of lines) {
        try {
          const entry = JSON.parse(line);
          if (entry.type === 'user' && entry.message && entry.message.content) {
            sessionStats.userMessages++;
            // Extract text from content array
            const textContent = entry.message.content
              .filter(c => c.type === 'text')
              .map(c => c.text)
              .join(' ');
            if (textContent) {
              this.analyzeMessage(textContent);
            }
          }
        } catch (e) {
          // Skip invalid JSON lines
        }
      }

      const fileName = path.basename(filePath);
      if (sessionStats.userMessages > 0) {
        console.log(`✓ ${fileName}: ${sessionStats.userMessages} messages`);
      }
    } catch (error) {
      console.log(`✗ ${path.basename(filePath)}: ${error.message}`);
    }
  }

  analyzeMessage(content) {
    const text = typeof content === 'string' ? content : JSON.stringify(content);
    const lower = text.toLowerCase();

    // Check for each pattern
    for (const [patternName, pattern] of Object.entries(PATTERNS)) {
      const matches = pattern.keywords.filter(kw => lower.includes(kw));
      if (matches.length > 0) {
        if (!this.patterns[patternName]) {
          this.patterns[patternName] = { count: 0, examples: [] };
        }
        this.patterns[patternName].count++;

        // Store example (first 200 chars)
        if (this.patterns[patternName].examples.length < 3) {
          this.patterns[patternName].examples.push(
            text.substring(0, 200).replace(/\n/g, ' ')
          );
        }
      }
    }

    // Extract vocabulary
    const words = text.toLowerCase().match(/\b\w+\b/g) || [];
    words.forEach(word => {
      if (word.length > 3 && !['that', 'this', 'with', 'from', 'have'].includes(word)) {
        this.vocabulary.frequentWords[word] = (this.vocabulary.frequentWords[word] || 0) + 1;
      }
    });

    // Detect ideas (sentences with verbs indicating creation)
    if (lower.match(/create|build|make|add|generate|design/)) {
      this.ideas.push(text.substring(0, 150));
    }

    // Detect pivots (direction changes)
    if (lower.match(/instead|or we|what about|switch to|lets do/)) {
      this.pivots.push(text.substring(0, 150));
    }

    // Detect decisions (commitment phrases)
    if (lower.match(/lets go|do it|yes|lets test|deploy/)) {
      this.decisions.push(text.substring(0, 150));
    }
  }

  calculateConfidence() {
    const totalMessages = Object.values(this.patterns).reduce((sum, p) => sum + p.count, 0);

    for (const [name, data] of Object.entries(this.patterns)) {
      data.confidence = Math.min(0.99, (data.count / totalMessages) * 5);
    }
  }

  generateSOUL() {
    const topWords = Object.entries(this.vocabulary.frequentWords)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 20)
      .map(([word]) => word);

    const sortedPatterns = Object.entries(this.patterns)
      .sort((a, b) => b[1].count - a[1].count);

    return {
      patterns: this.patterns,
      vocabulary: {
        topWords,
        totalWords: Object.keys(this.vocabulary.frequentWords).length
      },
      stats: {
        totalIdeas: this.ideas.length,
        totalPivots: this.pivots.length,
        totalDecisions: this.decisions.length
      },
      topPatterns: sortedPatterns.slice(0, 8).map(([name, data]) => ({
        name,
        count: data.count,
        confidence: data.confidence.toFixed(2),
        examples: data.examples
      }))
    };
  }
}

// Main execution
async function main() {
  const claudeDir = path.join(process.env.USERPROFILE || process.env.HOME, '.claude', 'projects', 'C--Users-15868');

  console.log(`\n🔍 Scanning: ${claudeDir}\n`);

  // Get all .jsonl files
  const files = fs.readdirSync(claudeDir)
    .filter(f => f.endsWith('.jsonl') && !f.includes('subagents'))
    .map(f => path.join(claudeDir, f))
    .sort((a, b) => fs.statSync(b).mtime - fs.statSync(a).mtime) // Most recent first
    .slice(0, 20); // Analyze last 20 sessions

  if (files.length === 0) {
    console.log('❌ No session files found');
    return;
  }

  const extractor = new MindsetExtractor(files);
  const result = await extractor.analyze();

  console.log('\n\n📊 MINDSET ANALYSIS RESULTS\n');
  console.log('═══════════════════════════════════════\n');

  console.log('🧠 TOP THOUGHT PATTERNS:\n');
  result.topPatterns.forEach((p, i) => {
    console.log(`${i + 1}. ${p.name}`);
    console.log(`   Confidence: ${(p.confidence * 100).toFixed(0)}%`);
    console.log(`   Occurrences: ${p.count}`);
    if (p.examples[0]) {
      console.log(`   Example: "${p.examples[0].substring(0, 120)}..."`);
    }
    console.log();
  });

  console.log('\n📈 STATS:\n');
  console.log(`Ideas Generated: ${result.stats.totalIdeas}`);
  console.log(`Direction Pivots: ${result.stats.totalPivots}`);
  console.log(`Decisions Made: ${result.stats.totalDecisions}`);

  console.log('\n💬 VOCABULARY:\n');
  console.log(`Unique Words: ${result.vocabulary.totalWords}`);
  console.log(`Top Words: ${result.vocabulary.topWords.slice(0, 10).join(', ')}`);

  // Save results
  const outputPath = path.join(__dirname, 'mindset-analysis.json');
  fs.writeFileSync(outputPath, JSON.stringify(result, null, 2));
  console.log(`\n\n✅ Full analysis saved to: ${outputPath}`);

  return result;
}

if (require.main === module) {
  main().catch(console.error);
}

module.exports = { MindsetExtractor };
