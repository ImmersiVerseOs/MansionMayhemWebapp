#!/usr/bin/env node
/**
 * Inject modern-theme.css into all HTML pages
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Get all HTML files
const htmlFiles = execSync('find web -name "*.html" -type f | grep -v node_modules', { encoding: 'utf-8' })
  .trim()
  .split('\n')
  .filter(f => !f.includes('includes/')); // Skip includes

console.log(`📄 Found ${htmlFiles.length} HTML files\n`);

let updated = 0;
let skipped = 0;

htmlFiles.forEach(file => {
  const content = fs.readFileSync(file, 'utf-8');

  // Skip if already has modern-theme.css
  if (content.includes('modern-theme.css')) {
    console.log(`⏭️  ${file} - Already has theme`);
    skipped++;
    return;
  }

  // Determine correct path to CSS based on file location
  const depth = file.split('/').length - 2; // web/ is root
  const cssPath = depth === 1
    ? 'css/modern-theme.css'  // web/file.html
    : '../css/modern-theme.css'; // web/pages/file.html

  // Find </head> and inject before it
  if (!content.includes('</head>')) {
    console.log(`⚠️  ${file} - No </head> tag found`);
    return;
  }

  const themeLink = `  <link rel="stylesheet" href="${cssPath}">\n`;
  const newContent = content.replace('</head>', `${themeLink}</head>`);

  // Write updated file
  fs.writeFileSync(file, newContent, 'utf-8');
  console.log(`✅ ${file} - Theme injected`);
  updated++;
});

console.log(`\n📊 Summary:`);
console.log(`   ✅ Updated: ${updated}`);
console.log(`   ⏭️  Skipped: ${skipped}`);
console.log(`   📁 Total: ${htmlFiles.length}`);
