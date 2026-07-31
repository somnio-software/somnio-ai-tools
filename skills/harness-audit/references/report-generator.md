# Harness Audit Report Generator

> Synthesize the inventory and scoring artifacts into a comprehensive AI Harness
> Audit report with a per-piece score table, the total /100, the maturity band
> reading, and the top-3 highest-impact next steps. MUST follow the exact section
> structure from `assets/report-template.md`. Every section is MANDATORY - do not
> merge, skip, or rename sections.

---

Goal: Generate the final AI Harness Audit report by integrating the inventory
and scoring results using the standardized format in `assets/report-template.md`.

READ-ONLY DISCIPLINE:
- Do NOT re-scan or modify the audited repository. Operate on artifact files.
  Your only writes are `reports/harness_audit.md`, `reports/harness_audit.json`,
  and `reports/.history/last_scores.json`.

STEP ARTIFACT INTEGRATION:
Read both artifacts for this run under `reports/.artifacts/`:
- `step_01_harness_inventory.md` - per-piece evidence, paths, line counts,
  frontmatter, CLAUDE.md size, monorepo notes.
- `step_02_harness_scoring.md` - per-piece status and points, total, band,
  top-3 next steps.

If `step_02_harness_scoring.md` is absent, you cannot produce a valid report:
re-run the scoring step first. If `step_01_harness_inventory.md` is absent, note
it and score every piece as Missing (0) with the band "No harness".

MANDATORY REPORT STRUCTURE (7 sections):
1. Harness Scoring Breakdown (per-piece table + Total + Maturity Band)
2. Executive Summary (Total Score + band reading + the 3 top next steps in brief)
3. Harness Piece Detail (one entry per piece, ordered by points recoverable
   descending - biggest gaps first)
4. Top 3 Highest-Impact Next Steps
5. Maturity Band Reading
6. Harness Detection Results (what was located and where)
7. Scan Metadata

## SCORING SYSTEM (reproduce exactly from references/harness-scoring.md)

7 pieces, 100 points total (Piece 2 is a conditional +10 on Piece 1):

- CLAUDE.md exists - 10
- CLAUDE.md is real (<200 lines + real commands + conventions) - +10
- Rules (>=1 rule with a stack-relevant `paths:`) - 10
- Permissions (project settings.json with a `deny` of secrets) - 15
- Commands / Skills (>=1 invocable team procedure) - 15
- Hooks (lint/format/test wired in PostToolUse or Stop) - 20
- Agents (>=1 custom role, e.g. reviewer/qa) - 10
- Autotest -> PR (agent reaches a green PR on its own, full lifecycle) - 10

Total = round of the raw sum (already 0-100; no re-weighting).

Maturity Band mapping:
- 0-30 = No harness (the model improvises)
- 31-60 = Basic harness (context yes, enforcement no)
- 61-85 = Solid harness (context + enforcement, with gaps)
- 86-100 = Paved path (the quality path is the easy path)

## SECTION FORMAT REQUIREMENTS

### Section 1 - Harness Scoring Breakdown

Render the per-piece score table exactly, one row per piece:
- Columns: Harness Piece | Status | Score
- Status is one of: Present / Weak / Missing (from step_02).
- One row per piece using its awarded/max (e.g. `Hooks | Missing | 0/20`).
- Followed by a **Total Score: [total]/100** line.
- Followed by a **Maturity Band: [band name]** line.
- Include the band legend: No harness (0-30) - Basic (31-60) - Solid (61-85) -
  Paved path (86-100).
- This is THE FIRST THING a reader sees - it must be complete and self-contained.

### Section 2 - Executive Summary

- Must include `Total Score: [total]/100 ([band name])`.
- One-paragraph reading of what the score means for this project.
- A brief list of the 3 top next steps (full detail goes in Section 4).
- If `reports/.history/last_scores.json` exists, read it and add
  `Previous: [N]/100, Change: [+/-M] ([improving|declining|unchanged])`.

### Section 3 - Harness Piece Detail

One entry per piece (all 8 rubric entries; combine Piece 1+2 CLAUDE.md into a
single "CLAUDE.md" entry that shows both the existence and quality sub-scores).
Order the entries by **points recoverable descending** (Missing/Weak pieces with
the most points first) so the biggest gaps lead. Each entry includes:
- **Piece**: name and max points
- **Status**: Present / Weak / Missing
- **Score**: `[awarded]/[max]`
- **Evidence**: exact file paths, line counts, frontmatter values, or command
  excerpts from the inventory artifact (or "Not found - [what would prove it]")
- **Why it matters**: one line on the enforcement/context value of this piece
- **Recommendation**: the concrete change if Weak/Missing (name the file), or
  "No action - criterion met" if Present

### Section 4 - Top 3 Highest-Impact Next Steps

Reproduce the ranked top-3 from step_02. For each:
1. The action (name the exact file to create or edit and the concrete change).
2. Points recovered.
3. Why it is high impact (prefer steps that convert context-only into enforced:
   Permissions, Hooks, Autotest->PR).

### Section 5 - Maturity Band Reading

- State the band and give a 2-4 sentence reading: what this level of harness
  means in practice, and what crossing into the next band would require.

### Section 6 - Harness Detection Results

- Repository structure (single app / monorepo / multi-package).
- Which of the 7 pieces were located and their paths.
- Primary CLAUDE.md path and line count.
- Any sibling-tool harness noted (e.g. `.cursor/`).

### Section 7 - Scan Metadata

- Scan date, project path, total pieces present, total score, band, generated-by
  line, skill name, and the Somnio AI Tools URL.

## FORMATTING RULES

- Follow `assets/report-template.md` structure exactly.
- Use Markdown: `#` headers, tables for the scoring breakdown and metadata,
  `- ` bullets, `1.` numbered lists, and `backtick` file paths.
- Every awarded/withheld point must reference actual repository evidence from the
  inventory artifact.
- Report starts with the `# AI Harness Audit Report` title and nothing before it.

## VALIDATION CHECKLIST

Before finalizing, verify:
- All 7 sections are present and in order.
- Section 1 has one table row per harness piece + Total + Maturity Band + legend.
- The Total in Section 1 matches the Total in Section 2 and the JSON export.
- The Maturity Band matches the Total Score range.
- Section 3 orders pieces by points recoverable descending.
- Section 4 lists exactly the top-3 next steps, each naming an exact file.
- Every Present piece cites evidence; every Missing/Weak piece names the fix.
- The metadata block from SKILL.md is appended at the very end.

## JSON EXPORT (mandatory)

After writing the report, write `reports/harness_audit.json`:

    {
      "totalScore": [integer 0-100],
      "band": "[No harness|Basic harness|Solid harness|Paved path]",
      "pieces": {
        "claudeMdExists": [0-10],
        "claudeMdReal": [0-10],
        "rules": [0-10],
        "permissions": [0-15],
        "commandsSkills": [0-15],
        "hooks": [0-20],
        "agents": [0-10],
        "autotestToPr": [0-10]
      },
      "topNextSteps": ["[step 1]", "[step 2]", "[step 3]"],
      "timestamp": "[ISO8601 datetime]",
      "projectPath": "[audited path]"
    }

Run before saving: `mkdir -p reports`

## SCORE HISTORY (mandatory, after report + JSON)

Write `reports/.history/last_scores.json`:

    { "overall": [total], "timestamp": "[ISO8601]",
      "pieces": { "claudeMdExists": N, "claudeMdReal": N, "rules": N,
        "permissions": N, "commandsSkills": N, "hooks": N, "agents": N,
        "autotestToPr": N },
      "band": "[band name]" }

Run: `mkdir -p reports/.history`
