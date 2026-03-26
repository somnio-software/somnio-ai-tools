#!/usr/bin/env node
/**
 * Generates tool-specific adapter files from the canonical source in rules/.
 *
 * Usage:
 *   node scripts/generate.js                    # regenerate all adapters
 *   node scripts/generate.js --only cursor
 *   node scripts/generate.js --only claude
 *   node scripts/generate.js --only copilot
 *   node scripts/generate.js --only windsurf
 *   node scripts/generate.js --only codex
 *   node scripts/generate.js --only antigravity
 *
 * Source of truth: rules/**\/*.md
 * Generated outputs (all inside adapters/):
 *   adapters/cursor/rules/**\/*.mdc
 *   adapters/claude/CLAUDE.md
 *   adapters/copilot/copilot-instructions.md
 *   adapters/windsurf/.windsurfrules
 *   adapters/codex/system-prompt.md
 *   adapters/antigravity/rules/**\/*.md
 */

const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Parse YAML-like frontmatter and return { meta, body }. */
function parseFrontmatter(content) {
  if (!content.startsWith('---')) return { meta: {}, body: content };

  const end = content.indexOf('\n---', 3);
  if (end === -1) return { meta: {}, body: content };

  const rawMeta = content.slice(4, end);
  const body = content.slice(end + 4).trimStart();

  const meta = {};
  for (const line of rawMeta.split('\n')) {
    const colonIdx = line.indexOf(':');
    if (colonIdx === -1) continue;
    const key = line.slice(0, colonIdx).trim();
    const value = line.slice(colonIdx + 1).trim().replace(/^["']|["']$/g, '');
    meta[key] = value;
  }

  return { meta, body };
}

/** Recursively collect all .md files under a directory, sorted. */
function collectMdFiles(dir) {
  const results = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      results.push(...collectMdFiles(fullPath));
    } else if (entry.name.endsWith('.md')) {
      results.push(fullPath);
    }
  }
  return results.sort();
}

/** Load all rules from rules/, grouped by subfolder name. */
function loadRules() {
  const rulesDir = path.join(ROOT, 'rules');
  const files = collectMdFiles(rulesDir);

  const groups = {};
  for (const filePath of files) {
    const rel = path.relative(rulesDir, filePath);
    const parts = rel.split(path.sep);
    const group = parts.length > 1 ? parts[0] : 'general';
    const filename = path.basename(filePath, '.md');

    const content = fs.readFileSync(filePath, 'utf8');
    const { meta, body } = parseFrontmatter(content);

    if (!groups[group]) groups[group] = [];
    groups[group].push({ filePath, meta, body, filename });
  }

  return groups;
}

const AUTO_GEN_COMMENT =
  `# AUTO-GENERATED — do not edit directly. Edit rules/ and run: npm run generate\n`;

// ---------------------------------------------------------------------------
// Renderers
// ---------------------------------------------------------------------------

/** Full content renderer: all sections with headers and glob notes. */
function renderFull(groups, header) {
  const lines = [AUTO_GEN_COMMENT, header, ''];

  for (const [group, rules] of Object.entries(groups)) {
    const groupTitle = group.charAt(0).toUpperCase() + group.slice(1);
    lines.push(`## ${groupTitle} Rules`, '');

    for (const { meta, body } of rules) {
      if (meta.description) lines.push(`### ${meta.description}`);
      if (meta.globs) lines.push(`> Applies to: \`${meta.globs}\``);
      lines.push('', body.trim(), '', '---', '');
    }
  }

  return lines.join('\n');
}

/** Condensed renderer for Codex: strips code blocks, keeps prose only. */
function renderCondensed(groups, header) {
  const lines = [AUTO_GEN_COMMENT, header, ''];

  for (const [group, rules] of Object.entries(groups)) {
    const groupTitle = group.charAt(0).toUpperCase() + group.slice(1);
    lines.push(`## ${groupTitle} Rules`, '');

    for (const { meta, body } of rules) {
      if (meta.description) lines.push(`### ${meta.description}`, '');

      // Strip fenced code blocks to reduce token usage
      const condensed = body.replace(/```[\s\S]*?```/g, '').replace(/\n{3,}/g, '\n\n').trim();
      lines.push(condensed, '', '---', '');
    }
  }

  return lines.join('\n');
}

// ---------------------------------------------------------------------------
// Writers
// ---------------------------------------------------------------------------

function ensureDir(filePath) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
}

function write(filePath, content) {
  ensureDir(filePath);
  fs.writeFileSync(filePath, content, 'utf8');
  console.log(`  wrote ${path.relative(ROOT, filePath)}`);
}

// ---------------------------------------------------------------------------
// Generators
// ---------------------------------------------------------------------------

function generateCursor(groups) {
  for (const [group, rules] of Object.entries(groups)) {
    for (const { meta, body, filename } of rules) {
      const outName = `${group}-${filename}.mdc`;
      const outPath = path.join(ROOT, 'adapters', 'cursor', 'rules', group, outName);

      const frontmatter = [
        '---',
        meta.description ? `description: "${meta.description}"` : '',
        meta.globs ? `globs: ${meta.globs}` : '',
        `alwaysApply: ${meta.alwaysApply || 'false'}`,
        '---',
      ].filter(Boolean).join('\n');

      write(outPath, `${frontmatter}\n${body}`);
    }
  }
}

function generateClaude(groups) {
  const header = `# Somnio Agent Rules — Claude Code\n\nCopy this file (or relevant sections) into your project's \`CLAUDE.md\`.`;
  write(
    path.join(ROOT, 'adapters', 'claude', 'CLAUDE.md'),
    renderFull(groups, header)
  );
}

function generateCopilot(groups) {
  const header = `# Somnio Coding Standards — GitHub Copilot\n\nFollow these standards in all code suggestions.`;
  write(
    path.join(ROOT, 'adapters', 'copilot', 'copilot-instructions.md'),
    renderFull(groups, header)
  );
}

function generateWindsurf(groups) {
  const header = `# Somnio Coding Standards — Windsurf\n\nFollow these standards when generating or editing code.`;
  write(
    path.join(ROOT, 'adapters', 'windsurf', '.windsurfrules'),
    renderFull(groups, header)
  );
}

function generateCodex(groups) {
  const header = `# System Prompt — Somnio Coding Standards\n\nYou are an expert software engineer. Follow these coding standards precisely when generating code.`;
  write(
    path.join(ROOT, 'adapters', 'codex', 'system-prompt.md'),
    renderCondensed(groups, header)
  );
}

function generateAntigravity(groups) {
  for (const [group, rules] of Object.entries(groups)) {
    for (const { body, filename } of rules) {
      const outPath = path.join(ROOT, 'adapters', 'antigravity', 'rules', group, `${filename}.md`);
      write(outPath, body);
    }
  }
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

const args = process.argv.slice(2);
const onlyIdx = args.indexOf('--only');
const only = onlyIdx !== -1 ? args[onlyIdx + 1] : null;

console.log('Loading rules from rules/...');
const groups = loadRules();
const ruleCount = Object.values(groups).reduce((s, r) => s + r.length, 0);
console.log(`  found ${ruleCount} rules across ${Object.keys(groups).length} groups\n`);

const targets = {
  cursor: generateCursor,
  claude: generateClaude,
  copilot: generateCopilot,
  windsurf: generateWindsurf,
  codex: generateCodex,
  antigravity: generateAntigravity,
};

if (only) {
  if (!targets[only]) {
    console.error(`Unknown target: ${only}. Available: ${Object.keys(targets).join(', ')}`);
    process.exit(1);
  }
  console.log(`Generating ${only}...`);
  targets[only](groups);
} else {
  for (const [name, fn] of Object.entries(targets)) {
    console.log(`Generating ${name}...`);
    fn(groups);
  }
}

console.log('\nDone.');
