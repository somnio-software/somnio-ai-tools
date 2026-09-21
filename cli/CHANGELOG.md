# Changelog

All notable changes to the Somnio CLI will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Removed

- **`dora-metrics` no longer saves a `.json` alongside its `.md`.** `--out-dir` now writes one Markdown file per repo. The JSON is still printed to stdout — that is the documented interface to the `report-writer` subagent and how `tests/e2e/run_e2e.py` parses a run, so it was deliberately kept. `tests/test_dora_metrics.py` gained an assertion that no `.json` is ever written to `--out-dir`, so a future reintroduction fails the build instead of passing silently.
- **`security-audit` no longer writes the dated `<YYYY-MM-DD>-<project>-security-audit.json` export.** The `JSON EXPORT (mandatory)` blocks were removed from `references/report-generator.md` and `references/report-format-enforcer.md`, along with the matching instructions in `agents/report-writer.md` and `SKILL.md`. `reports/.history/last_scores.json` is **not** a report — it is trend state read back on the next run to render a score delta — and it was preserved, with every read and write of it intact. Its schema is now spelled out inline at both write sites, because the previous wording ("the same score and findings data") leaned on the export schema block this change deletes.
- **Deleted the six orphaned `assets/report-template.txt` files** from `angular-health-audit`, `angularjs-health-audit`, `flutter-health-audit`, `nestjs-health-audit`, `python-health-audit`, and `react-health-audit`. Nothing referenced them — each skill's registered template is `report-template.md`. The files were remnants of an earlier report generation pipeline.
- **Deleted the nine remaining orphaned `assets/report-template.txt` files** from the five `*-best-practices` skills, `harness-audit`, `iso27001-audit` and `soc2-audit`. Same orphan pattern: every `templatePath` in `skill_registry.dart` points at the `.md`, nothing in the repo referenced the `.txt`, and several had gone visibly stale against their `.md` counterpart. No skill ships a `report-template.txt` any more.

### Fixed

- **Claude rule adapters are now lazy-loaded instead of always-loaded.** `generate_claude` used to render a rule's `description`/`globs` as prose (a `### heading` plus a `> Applies to:` note). Claude Code cannot act on that, so every installed rule sat in context from session start — for the `dart` stack alone that was ~56 KB per session. The Claude adapter now emits real YAML frontmatter with a `paths:` array, which Claude Code loads only when a matching file is read. The single-file adapters (windsurf, copilot, codex) still use the prose form via `_rule_header`, because per-rule frontmatter is meaningless once rules are concatenated into one document.
- **The generated frontmatter is quoted, matching the documented format.** 34 of the 58 source rules have frontmatter that is not valid YAML: a glob like `**/*.py` starts with `*`, which YAML reads as an *alias*, and several descriptions contain `: `, which reads as a nested mapping. `parse_frontmatter` is a naive line splitter and never noticed, but the emitted `paths:` is parsed for real — unquoted, those rules would silently never load. Every entry is now a quoted string, which is the form the Claude Code docs use throughout (https://code.claude.com/docs/en/memory, "Path-specific rules"). YAML-list support for `paths:` landed in Claude Code v2.1.84; the older single-line quoted form that anthropics/claude-code#17204 reported as broken is a different shape and predates it.
- **The Claude `CLAUDE.md` fragment is a rule map, not a list of `@import`s.** An `@path` line inlines the whole rule body into every session, which would have cancelled out the `paths:` frontmatter above. The fragment now lists each rule with a one-line summary and says where it loads from.

### Added

- **New `dart` agent-rules stack — pure-Dart coding standards derived from Effective Dart.** `agent-rules/rules/dart/` ships five rules that mirror the four official Effective Dart guides one-to-one — `style.md`, `documentation.md`, `usage.md`, `design.md` — plus a `testing.md` for `package:test`. Every section keeps Effective Dart's own directive vocabulary (DO / DON'T / PREFER / AVOID / CONSIDER) and rule headings verbatim, so a rule can be traced back to https://dart.dev/effective-dart without guesswork. Scope is pure Dart — CLIs, servers, shared packages — with no Flutter dependency: widgets, Material and BLoC stay in the `flutter` stack, and `dart/testing.md` targets `package:test` rather than `flutter_test`. `'dart'` was added to `AgentRuleRegistry.stacks`, so `somnio rules install` offers it for all six adapters (Claude, Cursor, Windsurf, Copilot, Codex, Antigravity).

- **`dora-metrics` now renders a mandatory "How to improve these metrics" section.** A new `references/practice-guidance.md` holds a catalog of engineering practices — 8 anchored entries across two dimensions, lead time and deployment frequency — parsed by a new `scripts/practice_guidance.py`, mirroring the existing `troubleshooting.md` / `troubleshooting.py` pattern so editing the markdown changes every future report. The catalog is deliberately **invariant**: the same entries render on every run, unfiltered and unreordered, regardless of what was measured — that is what keeps it a reference appendix rather than a verdict on a team's numbers. The guardrail in `agents/report-writer.md` was rewritten in the same change to permit exactly that while still forbidding interpretation, ranking and comparison (Goodhart's Law), and it hands the model one mechanical test: does the inclusion or the wording of this text depend on what this run measured? New tests assert that the markdown anchors and `PRACTICE_GUIDANCE_CODES` cannot drift apart, and that the catalog does not vary with the measured values.
- **`soc2-audit` gained a closing `Appendix: Scoring Methodology`.** The weighted formula, the rounding rule and the readiness bands now live in an unnumbered closing block, matching what the six health audits do. No weight value changed — only where the reader finds them.
- **`harness-audit` gained an `Appendix: Evidence Index`**, now section 7, with Report Metadata moving to section 8. It was the only one of the four audits without one, and it is the audit whose findings are hardest to check without it — every point it awards or withholds is a claim about a file. One group per harness piece (CLAUDE.md, rules, permissions, commands/skills, hooks, agents, the autotest-to-PR lifecycle), each carrying evidence or an explicit "Not found", never blank.
- **`Appendix: Scoring Methodology` in every health-audit report.** A closing, unnumbered block that renders the weighted formula used to compute the overall score, its rounding rule and the scoring bands. The weights were previously invisible to report readers, who could not reconcile the section scores against the single overall number. Weights appear only here — never as a column in the At-a-Glance Scorecard — and each skill renders its own family (the six split into two formulas depending on whether the stack has a Performance section). `references/report-generator.md` remains the single source of truth for the numbers.
- **`docs/report-template-canonical.md`**: New canonical report template skeleton documenting the unified 15-section structure for all six health audits, with metadata, scoring notes, and section layout.
- **Template drift check (`cli/test/src/content/report_template_drift_test.dart`)**: the six health-audit templates are hand-maintained and near-identical, so they drift. This test reads all six and fails on divergence — section numbering and order, the trailing unnumbered blocks, the coverage fields, the `Harness Coverage` rename, the byte-identical scoring legend, no `Weight` column in the scorecard, and per-skill weights that match their family and sum to 1.00. Failures name the offending skill and what diverged.
- **`docs/examples/`**: two fully filled-in example reports, one per weight family, audited against the format enforcer. Both cover fictional projects that do not exist and say so in an opening admonition; every score and path in them is invented.
- **`flutter-best-practices` now computes a documented overall score.** `references/best-practices-generator.md` previously carried no scoring instruction at all — the overall score was whatever the model produced, not reproducible between two runs on the same codebase. It now specifies a weighted average: Testing Quality 30% / Architecture Compliance 40% / Code Standards 30%.
- **The Scoring Methodology appendix is now specified everywhere a produced report is shaped from — though it is still not guaranteed to appear.** Adding the block to the six `assets/report-template.md` files was not enough: `references/best-practices-generator.md` is the operative instruction for the `somnio run` path, and its `REPORT SECTIONS` list enumerated the numbered sections and stopped at Evidence Index — so a real run produced no appendix at all. Caught by running `somnio run pp` end to end against this repository, which is the only check that exercises a produced report (nothing in Dart parses one). All six generators now also specify the unnumbered `Appendix: Scoring Methodology` and `Report Metadata` blocks, require the numbered sections in template order (the observed run had reordered them by severity), and every `agents/report-writer.md` and `SKILL.md` now describes Report Metadata as the `| Field | Value |` table the templates render rather than the plain-text `---` list they had been instructing. **This is an improvement in the instructions, not a guarantee.** Two full end-to-end runs against this repository, with identical files, produced different results: one closed with the appendix and the metadata table, the other omitted both and put the weights in an extra table under the scorecard. Per C7 nothing in Dart parses a produced report, so the generator and the format-enforcer pass are prose instructions to a model and the output varies between runs. Treat a missing appendix in a real report as a known limitation, not as proof the skill is misconfigured.

- **`somnio add` now scaffolds a conforming best-practices report template.** `_bestPracticesReportTemplate` in `cli/lib/src/utils/scaffold_generator.dart` still emitted the pre-unification shape — plain-text headings, no scores, no scoring legend, no Score Breakdown, no Evidence Index, no appendix, and a `Prioritized Action Plan` heading — so a freshly scaffolded skill was born violating the format the other six now share. The health-audit scaffold was synced in `6ae1616`; this is the same fix for the other family. `scaffold_generator_test.dart` now asserts the scaffolded template's skeleton, `/100` scale, byte-exact legend and appendix weights summing to 100, because `best_practices_template_drift_test.dart` lists the six known skills by name and would never see a seventh.
- **Scaffolded plan TODOs now name reference files with hyphens.** Both `_bestPracticesPlanTemplate` and `_healthAuditPlanTemplate` told the author to create `best_practices_generator.md` / `${tech}_report_generator.md`. The runner takes the rule name verbatim from `references/<rule-name>.md` (`plan_parser.dart`), and `rule_names.dart` string-matches `best-practices-generator` / `report-generator` exactly — so following those TODOs produced a skill whose report generation never dispatched, with no error. The TODOs now use the real hyphenated names (and drop the `${tech}_` prefix no shipped skill uses) and say why the filename is load-bearing.

- **`docs/best-practices-template-canonical.md`**: new canonical skeleton for the six `*-best-practices` templates — the counterpart of `report-template-canonical.md` for the other family. Documents the shared shape (Executive Summary → Score Breakdown → one numbered section per analysis step → Prioritized Recommendations → Evidence Index → the two unnumbered trailing blocks), each skill's own weights, and the constraints that make the two families non-interchangeable. Nothing reads it at runtime; it is the written reference a skill author copies from. `docs/contributing.md` now points at it.
- **Best-practices template drift check (`cli/test/src/content/best_practices_template_drift_test.dart`)**: the six best-practices templates are hand-maintained and near-identical, and one of them had already drifted badly. This test reads all six and fails on divergence — per-skill section numbering with no gaps, the shared leading and trailing section names, the `| Section | Score | Label |` scorecard with no Weight column, the byte-identical scoring legend, the `/100` scale, the two unnumbered trailing blocks, and each skill's appendix weights matched **per label** against that skill's own declared weights. Failures name the offending skill and what diverged. The per-label comparison is deliberate: a sorted-multiset check cannot see two weights transposed between two sections of the same skill, which for Flutter would silently invert the decision to weight Architecture Compliance above Testing Quality. Three further invariants hold each `references/best-practices-generator.md` to its own template — the generator's `REPORT SECTIONS` list must match the template's numbered sections in count, name and order, it must specify both unnumbered closing blocks, and its `COMPUTE OVERALL SCORE` weights must equal the appendix's per label. Those exist because the template alone does not decide what a produced report contains, and guarding only the template is what let the missing appendix ship.
- **`Appendix: Scoring Methodology` in every `*-best-practices` report.** All six templates (`flutter`, `react`, `angular`, `angularjs`, `python`, `nestjs`) gained a closing, unnumbered block rendering that skill's own weighted formula, rounding rule and scoring bands — each skill keeps its own weights, none were cross-applied. Weights appear only in that appendix and in each skill's `references/best-practices-generator.md`, never as a column in the `## 2. Score Breakdown` table; each format enforcer now rejects a scorecard that shows one.

### Changed

- **The shared report prompt no longer hardcodes one skill's report format for all sixteen.** `cli/lib/src/runner/step_executor.dart` builds the prompts for the report-generator step and the format-enforcer pass, and those prompts are shared by every skill that has a `report-generator.md` or `best-practices-generator.md` — the six `*-best-practices`, the six `*-health-audit`, plus `harness-audit`, `iso27001-audit`, `security-audit` and `soc2-audit`. It asserted four format facts that belong to individual skills and contradicted the others' templates: `security-audit`'s four-band scale (`85-100=Strong … 0-49=Critical`) was applied to all sixteen, though twelve use three bands and `harness-audit` uses named maturity bands; a fixed per-section field list described the health-audit shape and was wrong for the six best-practices skills, whose sections carry `Violations` rather than `Evidence`/`Risks`; a plain-text `---` metadata footer the report "MUST end with" contradicted every template's `| Field | Value |` table and left no place for the unnumbered `Appendix: Scoring Methodology` that thirteen of the sixteen render between the Evidence Index and Report Metadata; and an instruction to sort the scored sections by score ascending scrambled the twelve whose template fixes the section order. Section ordering now defers to each skill's own template and rule file and asserts neither policy, because `security-audit`, `iso27001-audit` and `soc2-audit` genuinely do require their scored sections sorted by score ascending while the other thirteen require a fixed order. The prompts now carry the process — read the rule file and template, read the artifacts, compute the scores, write the file — and leave every format decision to the files they already instruct the model to read. Only prompt text changed; control flow, retries, timeouts and success conditions are untouched. New tests in `step_executor_test.dart` assert the prompts state no band scale, no section ordering policy, no per-section field list and no metadata shape, matched as case-insensitive patterns so a reworded reintroduction fails too.

- **Breaking: `flutter-best-practices` reports moved from a `/10` overall score to `/100`.** `assets/report-template.md`'s `**Overall Score:** [Score]/10` and its `Strong (9–10) · Fair (7–8) · Weak (0–6)` legend are gone; every section and the weighted overall now render on the family's shared `/100` scale with `Strong (85–100) · Fair (70–84) · Weak (0–69)`. **This breaks comparability with every previously generated Flutter best-practices report** — the numbers are on a different scale, so an old report and a new one cannot be read side by side. That is the intended outcome, not a regression: it brings `flutter-best-practices` onto the same scale as the other five `*-best-practices` skills and gives the score more usable resolution than 11 discrete values.
- **`flutter-best-practices` reports moved onto the shared `*-best-practices` skeleton.** `assets/report-template.md`'s `## Section N.` headings became numbered sections, a new `## 2. Score Breakdown` table lists each section score alongside the weighted overall, a new `## 7. Evidence Index` lists the test, architecture and model files the analysis actually covered, and `Prioritized Action Plan` was renamed `Prioritized Recommendations` — matching what `react`, `angular`, `angularjs`, `python` and `nestjs` already had. `flutter-best-practices` still ships exactly three analysis references (`testing-quality.md`, `architecture-compliance.md`, `code-standards.md`); no scored section was added without an analyzer behind it, and no `references/` file was added, removed or renamed in any of the six skills.
- **The `Weight` column was removed from `soc2-audit`'s readiness scorecard.** Weights now appear only in the closing methodology appendix, never in the reader's scorecard, and the format enforcer rejects a scorecard that shows them. `soc2-audit` was the last skill still carrying that column — the same anti-pattern the health-audit unification removed. `references/scoring.md` remains the single source of truth for the numbers.
- **All four audits renamed their trailing `Scan Metadata` section to `Report Metadata`** (`harness-audit`, `iso27001-audit`, `security-audit`, `soc2-audit`), aligning with the six health audits. "Scan" was also inaccurate for `iso27001-audit` and `soc2-audit`, which are readiness assessments rather than scans.
- **Two stale docs were corrected.** `docs/cli.md` listed a `security-audit.json` among its example report outputs, one line below a heading stating that every audit writes one report. `docs/skills.md` promised "one pair of files per repo" for `dora-metrics`, and `skills/dora-metrics/README.md` framed the stdout JSON as conditional on `--out-dir`.
- **`*-health-audit` skills unified report format.** The six health audit skills (`angular-health-audit`, `angularjs-health-audit`, `flutter-health-audit`, `nestjs-health-audit`, `python-health-audit`, `react-health-audit`) now produce reports with identical structure and styling. Test coverage is now reported in every audit — a summary line under the At-a-Glance Scorecard and full `Code Coverage` / `Coverage Breakdown` fields in the Testing section, which previously only Flutter implemented. The duplicated "Quality Index" section was removed; reports are now 15 sections instead of 16. Report headers are now unified across all six, displaying project metadata and exclusions consistently. The AI Harness section's `Coverage` subheading was renamed to `Harness Coverage` for clarity. The common skeleton is documented in a new `docs/report-template-canonical.md`. Nothing consumes it at runtime — the six templates stay hand-maintained; it is the written reference a skill author copies from.

### Fixed

- **`somnio add <framework>` scaffolded a stale report template.** `ScaffoldGenerator._reportTemplate` still emitted a structure that matched no shipped skill — a `Security` scorecard row that exists in none of them, no coverage fields, no appendix — so every newly scaffolded skill started out diverged. It now emits the canonical 15-section skeleton, and its test asserts the structure instead of only checking that the words "At-a-Glance Scorecard" appear somewhere.
- **The report-generation prompt hardcoded a section count that was wrong for almost every skill.** `StepExecutor`'s prompt said "Compute each of the 5 section scores" and "Sort the 5 scored sections", but it is built for every runnable bundle — the health audits have 9 scored sections, `soc2-audit` 10 control families, `iso27001-audit` 11 categories. No single literal is right, so the count is gone and the prompt defers to the rule file and template, which is what actually governs.
- **Two `references/report-generator.md` files contradicted the unified format.** `react` still specified a bare `Coverage:` heading for AI Harness & Adoption where the other five already said `Harness Coverage:`, and `flutter`'s multi-app rule still sent per-app coverage to Additional Metrics, contradicting the rule that coverage appears in exactly two places. Both found by filling the template in end-to-end.
- **`report-generator.md` told the report writer to emit plain text while every other file demanded Markdown.** Its `FORMATTING RULES` block listed `USE MARKDOWN SYNTAX: Use # headers, **bold**` and then, on the next three lines, `NO BOLD MARKERS`, `NO CODE FENCES` and `NO TABLES: Use bullet points instead` — and closed with `Format: Markdown-formatted report (use proper Markdown syntax, syntax, no # headings, no bold markers, no fenced code blocks)`, contradicting itself inside one sentence, typo included. The shipped templates, `report-format-enforcer.md` (`USE BOLD` / `USE TABLES` / `USE CODE BLOCKS`) and each `SKILL.md` ("Google Docs-ready **Markdown** report") all mean Markdown, so the plain-text rules were vestigial: an agent following them literally would produce a report the enforcer then rejects. Fixed in all seven affected skills — the six health audits and `security-audit`.

## [2.13.0] - 2026-09-10

### Removed

- **The Gemini AI Security Analysis step is gone from `security-audit`.** Step 9 invoked `gemini prompt "/security:analyze"` through the Gemini CLI `gemini-cli-security` extension, and left three files behind in the audited project's root (`security_analysis_prompt.txt`, `gemini_security_findings.txt`, `gemini_security_report.txt`) that the skill then tried to `rm -f`. In practice the step produced no findings: of four leftover reports recovered from real audits, three ended in `[API Error: You have exhausted your daily quota on this model.]` and the fourth had stalled on an unanswered interactive prompt. Because the step redirected `2>&1` into its artifact, that quota error was fed straight into the report section it was supposed to fill. `security-audit` therefore now runs **9 steps instead of 10** and produces a **12-section report instead of 13** (the unscored "Gemini AI Analysis" section is dropped; sections 11-13 shift to 10-12). Scoring is unaffected — the five scored sections were always 3-7. The subagent path drops from five waves to four, step 1 no longer probes for the Gemini CLI or installs its security extension, and `reports/.artifacts/security-audit/step_09_security_gemini_analysis.md` is no longer written. Removes `references/gemini-analysis.md` and `agents/gemini-analyzer.md`.

  This does **not** affect Gemini as an *agent*: `somnio run <audit> --agent gemini` still works exactly as before. That is a separate feature — an AI CLI you run audits *with*, rather than a step *inside* an audit.
- **Deleted the orphaned `skills/security-audit/assets/report-template.txt`.** Nothing referenced it (the registered template is `report-template.md`) and it still described the old 13-section structure.
- **Dropped the three dead `.gitignore` entries** for the Gemini side-effect files, now that nothing generates them.

### Fixed

- **`mkdir -p` no longer creates the wrong artifacts directory in four skills.** 2.12.0 moved artifacts to `reports/.artifacts/<skill-name>/` but left 47 bare `mkdir -p reports/.artifacts` commands in `harness-audit`, `iso27001-audit`, `security-audit` and `soc2-audit` — the four skills that previously wrote to the `.artifacts/` root. Writing an artifact into the uncreated sub-directory would fail on the in-session subagent path (`somnio run` was unaffected, since the runner creates the directory itself).

## [2.12.0] - 2026-09-10

### Changed

- **Every audit report is now named `<YYYY-MM-DD>-<project>-<audit>.md`.** Reports had no date and no project name (`reports/flutter_audit.md`, `reports/security_audit.md`), which meant two things: re-running an audit silently overwrote the previous report, and reports from different projects collected into one shared folder were indistinguishable and collided. The name now carries the run date first (so a directory listing sorts chronologically) and the project name second — e.g. `reports/2026-09-14-hoopis-backend-nestjs-health-audit.md`. Applies to all `*-health-audit`, `*-best-practices`, `harness-audit`, `security-audit`, `soc2-audit` and `iso27001-audit` skills, plus the `/quick-check` command. `harness-audit`, `security-audit`, `soc2-audit` and `iso27001-audit` also write a `.json` export with the same base name; `reports/.history/last_scores.json` is trend state rather than a report, so it keeps its fixed, undated name.
- **`somnio run` accepts `--project-name`.** The project segment defaults to the current directory name, slugified to kebab-case. Pass `--project-name` when the checkout directory is not named after the project (`backend/`, `tmp/`, a second clone).
- **`dora-metrics` saves one pair of files per repo.** It previously wrote a single aggregated `YYYY-MM-DD_dora.{json,md}` per run. A repo is the unit this skill measures — deliberately never combined with its siblings — so it is now also the unit it saves: `<YYYY-MM-DD>-<repo>-dora-metrics.{json,md}`, each file holding only that repo's numbers plus the run-level context. The repo name alone is the slug (`example-org/example-frontend` → `example-frontend`), falling back to the org-qualified form only when two repos in one run share a name. `--project` is unchanged and still selects *what* to measure; the file name comes from the repo.

### Fixed

- **The artifacts directory now matches what the skills document.** `somnio run` keyed it off `bundle.id` (`reports/.artifacts/react_health/`) while nine of the sixteen audit skills documented the kebab-case `reports/.artifacts/react-health-audit/`, and `harness-audit`/`iso27001-audit` documented no sub-directory at all. Every skill and the runner now agree on `reports/.artifacts/<skill-name>/`. Artifact *file* names (`step_NN_<rule>.md`) are unchanged — those come from each SKILL.md's "Rule Execution Order".
- **`*-best-practices` skills reported a report path the runner never wrote.** The CLI produced `reports/flutter_best_practices.md` while the skill docs and their report-writer agents said `reports/flutter_best_practices_report.md` (and the Angular/AngularJS/React/NestJS ones said `reports/<tech>-best-practices-report.md`). Deriving the name from the skill name removes the divergence.
- **`docs/contributing.md` pointed new skills at `assets/report-template.txt`.** Every shipped skill uses `assets/report-template.md`; the contributing guide and its `templatePath` example now match.

## [2.11.2] - 2026-09-03

### Fixed

- **`security-audit` no longer penalizes internal monorepo `path:` dependencies in the supply-chain score.** Workspace packages that resolve inside the repo were treated like unpinned external path/git deps, so multi-package Flutter/Dart monorepos took an undeserved supply-chain hit. Path deps are now classified as internal (inside the repo root) or external; only external path deps and `git:` deps count toward that penalty.
- **`flutter-health-audit` writes coverage reports to absolute repo-root paths.** Relative `--coverage-path` values were resolved from the package directory after `cd`, so monorepo package runs wrote `lcov.info` under nested paths (`packages/<name>/coverage/packages/<name>/lcov.info`) and aggregation missed them. Every `--coverage-path` is now built from an absolute repo root captured before any `cd`.

## [2.11.1] - 2026-08-11

### Fixed

- **`flutter-health-audit` no longer counts generated `.g.dart` files toward the coverage percentage.** Coverage was calculated from raw `lcov.info` `DA:` line counts across the app and every package, which included `build_runner`-generated files (`json_serializable`, `freezed`, `injectable`, etc.). Those files are boilerplate, not hand-written logic, and their trivial coverage status skewed the percentage away from actual test effort — feeding an invalid number into the overall project health score. Every `lcov.info` is now filtered to strip `.g.dart` records immediately after generation, before any line counts are taken for analysis or aggregation.
- **`somnio run` Flutter pre-flight now excludes `.g.dart` files from coverage.** The health-audit *skill* already stripped generated files, but `somnio run` never executes that step — it substitutes a deterministic CLI pre-flight that parsed raw `lcov.info`. Packages with large generated models (Hive / json_serializable) were therefore reported well below CI (e.g. 68% vs 94%). `_parseLcovInfo` now skips `SF:` records whose path ends in `.g.dart`, matching `lcov --remove '**/*.g.dart'` in Bitbucket Pipelines.

## [2.11.0] - 2026-08-05

### Added

- **`dora-metrics` diagnoses the setup it measures, and puts the fix steps in the report.** The skill could always say a repo deployed 0 times; it could not say whether that meant "no deploys" or "this repo is not instrumented the way `config/projects.json` claims". It now checks, per repo: whether the credential can see the repo at all, whether the configured `prod_branch` exists, whether the repo has any deploy markers, whether their names match `tag_pattern` (listing the real names it found as evidence), whether `deploy_source` points at the kind of marker the repo actually uses, and whether matching Releases were all left as drafts. Each finding carries the concrete remediation — which field of `config/projects.json` to change, which command to run — in the chat reply **and** in the saved `.md`, which previously listed the symptom with no way to act on it. Costs 2 extra REST calls per repo (`/repos`, `/branches/{branch}`), plus 2 more only when a repo produced no marker and the script needs evidence to explain why; these are REST, not the rate-limited Search API.
- **Structured `issues` in the JSON output.** Every problem is now `{code, impact, message, evidence, guidance}`. `impact` describes whether the *measurement* succeeded — `blocked` (nothing measurable at that level), `partial` (measured, with a declared gap), `none` (a factual note, nothing to fix) — never whether a number is good or bad. Repos that could not be measured come back with `measured: false` and no metric fields instead of a bare `{"repo", "error"}` string; the run continues with the project's other repos. Root-level `issues` carry problems not tied to a repo. `warnings` survives as a derived list of the same message strings, so existing consumers keep working.
- **`scripts/troubleshooting.py`**: parses `references/troubleshooting.md` by `<!-- code: X -->` anchor into `{code: {what, how_to_check, where_to_fix}}`. That markdown file stays the single source of truth for the prose — the script reads it and embeds the steps in its output, so editing it changes every future report. A unit test fails if `ISSUE_CODES` and the file's anchors drift apart, and a code with no entry renders an explicit "no guidance" line rather than inventing steps.

### Changed

- **`dora-metrics` no longer aborts when there is no GitHub credential.** It used to exit before producing anything, leaving the two fix options on stderr. It now generates the report carrying that problem and its steps, saves the `.json`/`.md` when `--out-dir` is passed, and exits 1. Exit code is 1 whenever any issue is `blocked` and 0 otherwise — a partially measured repo does not fail the run. Usage errors (an unknown `--project`, `--branch` without `--project`, an invalid `deploy_source`) keep their old behaviour: message on stderr, no report.
- **The `report-writer` subagent no longer looks guidance up.** It used to match a warning's text against `references/troubleshooting.md` at render time, which left it free to improvise remediation and meant the chat reply and the saved file could disagree. The script now does the lookup before serializing, and the agent renders `issues[].guidance` verbatim from the JSON — the two outputs are the same by construction.
- **`references/troubleshooting.md` restructured** into one anchored entry per problem code with `### What` / `### How to check` / `### Where to fix` subsections, so it is machine-readable. Entries for the new access and configuration problems were added; the existing warning entries kept their prose.

## [2.10.0] - 2026-07-31

### Added

- **`somnio skills` command group**: skills now have their own lifecycle, independent of the CLI binary.
  - `somnio skills install` — pick which skills to install and WHERE: globally (the agent's config dir, e.g. `~/.claude/skills`) or per project (`<project>/.claude/skills`). Flags: `--agent`, `--all-agents`, `--skills`, `--all-skills`, `--global`, `--project`.
  - `somnio skills update` — refreshes only the skills that are actually installed, overwriting them with the latest version. Checks BOTH global and project locations for every agent and updates whichever exist.
  - `somnio skills remove` (alias `uninstall`) — clears a whole scope: asks global, project or both, then removes every skill the CLI installed there. There is no per-skill selection, and skills the CLI did not install are never touched. Flags: `--agent`, `--global`, `--project`, `--force`.
- **Install manifest** (`.somnio-skills.json`): each agent install directory now records the exact paths somnio wrote, per skill. This is what lets `skills update` and `skills remove` act only on CLI-installed content instead of guessing by name — hand-authored skills sharing a name are never touched.
- **Per-project skill installs**: `AgentConfig` gained `supportsProjectScope`, `resolvedScopedInstallPath` and `resolvedScopedExecutionRulesPath`, re-anchoring the `{home}` placeholder at the project root.

### Changed

- **`somnio update` now updates only the CLI.** It no longer wipes and reinstalls every skill on every agent. Use `somnio skills update` for that. The `--legacy`, `--all-skills` and `--post-update` flags are gone.
- **`somnio uninstall` now removes the CLI itself** (`dart pub global deactivate somnio`), asking first whether to also delete the installed skills and rules. The question comes first because once the binary is gone there is no `somnio skills remove` left to run; answering no keeps the skills in place. New `--skills` / `--no-skills` flags answer it up front. When skills are removed it now also clears project-scoped installs and the `.somnio-skills.json` manifests, which the old home-only sweep left behind.

## [2.9.0] - 2026-07-31

### Added

- **AngularJS Health Audit** (`ajh` / `somnio-ajh`): new CLI audit bundle for legacy AngularJS 1.x (controllers/directives/services, `$http`/interceptors/`$rootScope`, digest-cycle hygiene, minification-safe DI, Karma/Jasmine/angular-mocks, Grunt/gulp), including an AI Harness & Adoption analysis step and framework/Bower EOL migration-risk analysis. Mirrors the `react-health-audit` structure. Registered in `skill_registry.dart`.
- **Angular (2+) Health Audit** (`ah` / `somnio-ah`): 13-step health audit for modern Angular (Angular CLI, TypeScript) — module/component architecture, state & data flow (services/RxJS/signals/NgRx), change detection, build & bundle pipeline with Angular CLI budgets, Karma/Jasmine or Jest testing, TS-strict + angular-eslint code quality, CI/CD, documentation — including the AI Harness & Adoption step. Mirrors `react-health-audit`; runnable via `somnio run ah`.
- **AngularJS Best Practices Check** (`ajp` / `somnio-ajp`): micro-level code-quality audit for AngularJS 1.x — module/controller/directive architecture, `$scope` and binding patterns, services/`$http` data flow, digest-cycle performance, minification-safe DI, Karma/Jasmine testing. Mirrors `react-best-practices`; the best-practices companion to the AngularJS health audit. Runnable via `somnio run ajp`.
- **Angular (2+) Best Practices Check** (`ap` / `somnio-ap`): micro-level code-quality audit for modern Angular — component/module architecture, RxJS and state management, change-detection performance, TypeScript strictness and template type-checking, testing. Mirrors `react-best-practices`; the best-practices companion to the Angular health audit. Runnable via `somnio run ap`.
- **Harness Audit** (`ha` / `somnio-ha`): framework-agnostic AI Harness Audit that scores how complete a project's AI coding harness is (CLAUDE.md, `.claude/rules`, `settings.json` permissions/hooks, commands/skills, agents, autotest→PR lifecycle) against a weighted rubric, returning a score /100, a band reading (no harness / basic / solid / paved path) and top next steps. 3-step Rule Execution Order mirroring `security-audit`; runnable via `somnio run ha`.
- **SOC 2 Readiness Audit** (`s2` / `somnio-s2`): framework-agnostic, whole-project SOC 2 readiness audit. Inspects the repo/app for evidence of the AICPA Trust Services Criteria (Common Criteria security plus Availability, Confidentiality, Processing Integrity, Privacy) across an 11-category control taxonomy (A–K) with an ownership-lane model — platform-auditable (scored heavily) vs organizational-policy (artifact presence) vs client CUEC (listed, not penalized). Each control gets a status (met/partial/gap/organizational) with an evidence path and TSC ref; output is a per-criterion scorecard, a gap register with remediation and priority, and an overall readiness score + band. Read-only; secrets redacted. Runnable via `somnio run s2`.
- **ISO 27001:2022 Readiness Audit** (`iso` / `somnio-iso`): framework-agnostic, whole-project ISO/IEC 27001:2022 readiness audit. Inspects the repo/app for evidence of an ISMS and Annex A controls (organizational, people, physical, technological) across the same 11-category taxonomy, and checks ISMS clauses 4–10. Each control gets a status, ownership lane and Annex A ref; output is a per-theme scorecard, a gap register, a Statement-of-Applicability starter, and an overall readiness score + band. Read-only; secrets redacted. Runnable via `somnio run iso`.

### Fixed

- **Interactive skill picker duplicated its first entries once the list outgrew the terminal**: `somnio install` / `somnio update` printed the top of the skill list again on every keypress — `◉ Flutter Project Health Audit / ◉ Angular Project Health Audit / ◉ Flutter Best Practices Check / ◉ SOC 2 Readiness Audit` repeated dozens of times before the rest of the menu. `interact_cli`'s `Select` / `MultiSelect` paint every option on each redraw and erase the previous frame with relative cursor moves (`cursorUp` + `eraseLine`), and a terminal cannot move the cursor above the top of its window: with 23 skills in a 20-row window the first four lines scrolled out of reach of the wipe, so each redraw left another copy behind (reproduced in a PTY at 20 rows — four copies after three arrow presses, one per frame). Both pickers now render through a new `ScrollingPicker` that scrolls a viewport sized from `stdout.terminalLines`, so a frame is always shorter than the window and therefore always fully erasable; the frame keeps a constant height and shows `↑ N more` / `↓ N more` plus a `selected/total` counter, and `a` toggles every option. The viewport math lives in `scroll_window.dart` and is unit-tested (window sizing at every terminal height, minimal scrolling, cursor always visible). Confirmed styles, keys and the confirmed-value line are unchanged; verified at 14, 20 and 60 rows with each label now painted exactly once. Adds a direct `dart_console` dependency (already present transitively via `interact_cli`).
- **`ClaudeTransformer` mangled Angular control-flow syntax into a dangling reference path**: the `` `@word` `` → "Read and follow the instructions in `references/word.md`" rewrite (legacy rule-reference support) fired unconditionally, without checking that the bundle ships such a reference. Angular's built-in control-flow blocks collide with that form, so `angular-best-practices`' line ``- `trackBy` on `*ngFor` (or `@for` track) for list rendering`` installed into `~/.claude/skills/` as ``(or Read and follow the instructions in `references/for.md` track)`` — an instruction pointing at a file that does not exist, inside a sentence that no longer parses. The rewrite is now gated on the bundle actually containing `references/<name>.md`, so `@for`, `@if`, `@defer` and framework decorators survive verbatim while real `@rule_name` references keep resolving. Claude-format installs only; the other transformers never applied the rewrite.
- **`iso27001-audit` and `harness-audit` shipped without a format enforcer**: the runner always queues a format-enforcement step after the report generator (`formatEnforcerRuleFor`), but neither bundle had `references/report-format-enforcer.md`, so `StepExecutor.executeFormatEnforcer` skipped it — their reports were exported with no structural validation while every other audit got one. Both now ship an enforcer grounded in their own report contract (ISO: 20 sections, 11 category scores, Status + Owner/lane per control, SoA starter and ISMS clause coverage as first-class, band ranges, secret redaction; Harness: 7 sections, per-piece table summing to the total, band-vs-total consistency, exactly three evidence-bound next steps), wired into both execution paths — the SKILL.md post-generation step, the Antigravity workflow, and the in-session `report-writer` agent.

## [2.8.2] - 2026-07-22

### Added

- **`somnio commands install`**: New CLI subcommand to list and install root-level commands at folder scope (current working directory) into `.claude/commands/` and `.cursor/commands/` for Claude Code and Cursor. Mirrors the existing `somnio rules install` workflow. Backed by a new `CommandBundle` model, `CommandRegistry`, and `CommandInstaller`.

### Changed

- **`ship` command moved to installable command**: The `ship` skill is now an installable command (via `somnio commands install`) instead of an auto-triggering skill. No longer auto-activates on skill trigger detection.

## [2.8.1] - 2026-07-17

### Changed

- **AI Harness & Adoption rubric — versioning is now its own dimension, not an existence gate**: In all four health-audit skills (`flutter`, `react`, `nestjs`, `python`), a harness that was present on disk but excluded by `.gitignore` scored ~14/100 — indistinguishable from a repo with no harness at all — because `git ls-files` returned empty and zeroed the *existence* half of seven dimensions before any quality could be scored. The rubric now judges existence **on disk**: dimensions 1-9 are scored on what the files actually contain, whether or not they are committed. Whether the harness is versioned is scored once, in the new **dimension 10 — Harness versioning (12 pts)**, graduated 12 (fully tracked) / 8 (tracked but a `.gitignore` pattern will silently swallow every new harness file — the grandfathered trap) / 5 (partial) / 0 (nothing tracked). When dimension 10 scores 0, Section 6 caps the section at 60 ("harness básico"), so an uncommitted harness can never read as "sólido" but is no longer collapsed to the same score as no harness — and the one-line fix (`git add` / remove the `.gitignore` line) surfaces as the highest-leverage action. The remaining dimensions were rebalanced to keep the total at 100. Evidence gathering adds one `git check-ignore -v --no-index` call (the `--no-index` flag is load-bearing — without it git stays silent on already-tracked paths, hiding the grandfathered case), staying within the ≤8-call budget. Applied identically across the shared rubric, the `harness-analyzer` subagents, the `SKILL.md` step descriptions, and the report generators/enforcers/templates.

### Fixed

- **`nestjs-health-audit` rubric drift**: `references/harness-analysis.md` had diverged from the other three stacks outside its designated stack-specific section (the in-session dispatch instruction), violating the file's own byte-identical invariant. Realigned with flutter/react/python.

## [2.8.0] - 2026-07-17

### Added

- **DORA Metrics Skill**: New `dora-metrics` skill that fetches Deployment Frequency and Lead Time for Changes per project and per repo from the GitHub API (never local git), so lead time stays accurate across merge strategies including squash merges. Reads a project-to-repos mapping from `config/projects.json`, asks for missing projects instead of guessing, and reports both metrics with process-gap warnings. Read-only: never ranks, scores, or compares projects or people. Ships with a lightweight Report Writer subagent (`model: sonnet`, parametrizable to `haiku`/`opus` on explicit request) that formats the script's JSON output via a template without interpreting it, and a `references/troubleshooting.md` guide mapping each data/measurement warning to a WHAT/HOW/WHERE-TO-FIX diagnosis, scoped strictly to setup problems, never team performance. Registered in the CLI skill registry.
- **`WorkflowSkill.assetDirectories`**: Workflow skills can now declare extra directories (e.g. `scripts/`, `config/`, `agents/`, `assets/`) copied verbatim alongside their `SKILL.md` for Claude Code `skillDir` installs, so skills backed by real executable code — not just markdown instructions — install correctly via `somnio add`/`somnio install`. Used by the new `dora-metrics` skill.

## [2.7.1] - 2026-07-16

### Added

- **`somnio run --step-timeout` flag**: New CLI flag to configure the per-step timeout in minutes (e.g., `somnio run fh --step-timeout 45`). Accepts positive whole numbers; default is 30 minutes. Non-numeric, zero, negative, or decimal values are rejected with a usage error.
- **`somnio workflow run --step-timeout` flag**: Same timeout configuration for custom workflows (e.g., `somnio workflow run my-workflow --step-timeout 60`).
- **Workflow token/cost summary**: `somnio workflow run` now prints a token consumption and cost summary box at the end of the run, matching the summary shown in `somnio run` audits.
- **Markdown agent rule installs**: Eight markdown-format agents (Codex, Augment Code, Amp, Aider, Cline, OpenCode, CodeBuddy, Qwen) now have their execution rules installed automatically via the default `somnio setup` and `somnio update` paths, not just through interactive `somnio install`.
- **Rules uninstall fallback**: When uninstalling rules from a stack whose install manifest is missing (from installs predating this version), Somnio now falls back to deleting only the known adapter files derived from the upstream repo. If the repo cannot be located, the files are left in place and a warning is logged instead of being removed silently.
- **`flutter-health-audit` state management analysis step**: The audit scored a mandatory `State Management` section and an `Architecture` section with no step producing evidence for either. A new `references/state-management-analysis.md` rubric and `state-management-analyzer` subagent (`model: mid`) now detect the state management library and pattern, and `references/repository-inventory.md` gained folder-organization and architecture analysis. Wired into both execution paths — the CLI `Rule Execution Order` (now 13 rules) and the in-session orchestrator wave dispatch.
- **`allowed-tools` block sequences are honoured**: `ContentLoader.loadPlanFrontmatter` kept only string-valued frontmatter keys, so a skill authoring `allowed-tools` as a YAML block sequence (`skills/ship/SKILL.md`) had it dropped and silently fell back to the installer's generic default — costing `ship` the `AskUserQuestion` tool its own plan calls four times. List values are now normalised to the comma-separated form.

### Fixed

- **Exit codes on install failures**: `somnio setup` and `somnio update` now exit with code 1 (ExitCode.software) when any bundle or workflow-skill install fails, instead of always exiting with code 0 on success. Fixes CI/automation detection of silent failures.
- **`somnio run <tech>-best-practices` never wrote its report**: the runner dispatched the terminal step to `executeReportGenerator` only when the rule name matched `report-generator` exactly, but all four `_plan` bundles name it `best-practices-generator`. The step fell through to the generic branch, which never reads the template or writes `reportPath`, while `_cleanPreviousRun` had already deleted the previous report — so the run destroyed a good report, wrote no replacement and exited 0 reporting success. This is the same defect 2.7.0 fixed for the health audits, shipped a second time through a different rule name; dispatch now goes through `isReportGeneratorRule` / `formatEnforcerRuleFor` in `rule_names.dart`, with an integration test asserting the real parser output for every runnable bundle.
- **Audit step counters and time attribution**: the format-enforcer result was appended to the same list the counters read, printing impossible totals like `11/10 steps`, and failed or timed-out AI steps were billed as pre-flight time in the usage summary. Counters now read a dedicated step list, and every result is classified into exactly one bucket.
- **`somnio add` generated invalid or corrupted Dart**: the registry escaper handled apostrophes only, so a description containing `$` was emitted raw into a single-quoted Dart literal and interpolated. The `dart format` gate is syntax-only and passes such a file, so a compile-broken `skill_registry.dart` was written and reported as success. Backslashes, `$` and apostrophes are now escaped (backslash first) across every generated field, and `hasConflicts` escapes before comparing so detection cannot drift from generation.
- **`somnio add` wrote Windows path separators into the registry**: auto-detected paths were emitted with the host's separator, so a Windows run injected backslash paths into checked-in source consumed on every platform. Paths are now normalised to POSIX at detection.
- **`somnio add` registered duplicate ids**: two skill directories classifying to the same bundle type produced identical ids and names, and the second install silently overwrote the first. Ambiguous detections are now rejected with a usage error, and duplicates are detected within a batch as well as against the existing registry.
- **Workflow resume was skipped when the failed step was the first one**: the resume prompt was gated on the index of the first pending step, but under wave parallelism "step 1 failed while steps 2..N succeeded" is the normal failure shape and yields index 0 — read as "no previous run". Saved progress was discarded and every completed step re-executed, overwriting good outputs. Resume is now an explicit flag gated on completed work, and the runner reconciles progress by file name rather than by index.
- **A stale output file marked a workflow step that produced nothing as successful**: the executor proves a step ran by checking its output file exists, but never cleared it first, so a file left by an earlier run satisfied the check and fed stale content to every downstream `{step_N_output}` consumer. The output is now removed before the AI is spawned.
- **An unrecognized `needs` value was silently dropped**: anything outside the recognised forms collapsed to no dependency, so a step meant to run after others joined wave 1 and ran concurrently with them. Invalid values now fail the workflow with the offending step and value named.
- **A bad dependency graph exited 64 with CLI usage text**: `WavePlanner`'s `FormatException` escaped to the arg parser's handler, so a cyclic or out-of-range graph printed usage as if the command had been typed wrong. It is now caught and reported as a workflow error (exit 70), before progress is saved.
- **A workflow with zero steps reported success**: `somnio workflow plan` and `run` now fail fast instead of printing "Workflow completed!" and exiting 0.
- **An unparseable workflow config was reported as "No config file"**: a malformed config was indistinguishable from a missing one, misattributing the cause of a defaulted model mapping. The two cases are now distinct and a parse failure is an error.
- **AntigravityTransformer never installed a bundle's `agents/` directory**: six workflows' first instruction is to read `<skill>/agents/orchestrator.md`, but the transformer emitted only `references/`, the template and the plan — so every orchestrator entry point dangled. Agent files are now emitted and their paths rewritten to the installed location, in both the prefixed and bare (`agents/x.md`) forms the shipped workflows use.
- **AntigravityTransformer left the report template path unrewritten**: `assets/report-template.md` stayed relative in workflow content while `references/` paths were rewritten, so the generator step pointed at a path that does not exist under the install root.
- **Installers discarded the authored `SKILL.md` frontmatter**: both `ClaudeTransformer` and `AgentInstaller` rebuilt `description` from the registry's short display string, dropping the `Use when …` / `Triggers on: …` clauses that drive skill auto-activation. All 16 skills diverged. The authored description now wins, with the registry as fallback.
- **Emitted frontmatter broke on unusual authored values**: a description containing `: ` was parsed as a nested mapping key, and a literal (`|`) block's newlines truncated the value at its first line — the form `skills/optimize-claude-config/SKILL.md` authors. A new `yaml_frontmatter.dart` folds descriptions into a `>-` block and quotes single-line values such as `allowed-tools` only when the plain form would be misparsed, so existing output is unchanged.
- **`workflow-builder`'s `references/` was never installed**: its plan links to `references/plan.md` and `references/run.md`, which `WorkflowSkill` had no concept of. Workflow skills can now declare a references directory; `skillDir` installs them as siblings and the flat formats append them inline.
- **Work-log hook dropped entries from concurrent projects**: the Stop hook's 5-second debounce was keyed on a single global per-day log file, so a second project logging within 5 seconds of the first was silently discarded — while two turns of the *same* session 1 second apart both wrote, which is the case the debounce existed to prevent. It is now keyed per session, so it suppresses the case it must and permits the case it must not.
- **`optimize-claude-config`'s `allowed-tools` was a space-separated blob**: `Bash Read Edit Write` instead of the comma-separated form all ten sibling skills use. Under a comma-splitting parser this grants none of the four declared tools. The file ships verbatim through the marketplace plugin symlink, and — since installers now re-emit the authored value — through `somnio install` as well.

- **`somnio uninstall` left Cursor execution rules behind**: `~/.cursor/somnio_rules/` was never removed, because Cursor was excluded from the only cleanup path that deletes execution rules. It is now removed like every other agent's.
- **`somnio uninstall` left Claude skills behind**: cleanup iterated a hardcoded skill list that had drifted from `SkillRegistry`, so `python-health-audit`, `python-best-practices`, `dart-model-from-json`, `optimize-claude-config` and the legacy `somnio-rh` / `somnio-rp` were never removed from `~/.claude/skills/`. The list is now derived from the registry, so new skills are covered automatically.
- **`somnio uninstall` skipped `~/.agents/skills/`**: skills.sh's canonical location was only cleaned when `~/.claude/skills/` also existed, so it leaked whenever the symlinks were already gone. Both locations are now cleaned independently.

### Removed

- **`somnio install --force` flag**: Removed the `--force` flag from the `somnio install` command. The flag was documented but never implemented — `somnio install` always overwrote files regardless of the flag. Removing it removes a misleading flag but changes no actual behavior.

### Security

- **Shell command injection via `.nvmrc` in the NestJS pre-flight**: `_readNodeVersion` returned the file's contents with only `.trim()` applied and interpolated them straight into a `bash -c` script, so auditing an untrusted repo whose `.nvmrc` contained shell metacharacters executed them with the invoking user's privileges — before any AI step and before the user approved anything, while the pre-flight reported PASSED. Node version specifiers are now validated at read time against a strict allowlist (`18`, `v18.17.0`, `lts/*`, `lts/iron`, `node`, `stable`), rejecting anything else with a warning. Validating at the source covers every consumer of the value.

## [2.7.0] - 2026-07-14

### Added

- **AI Harness & Adoption audit section**: All four health audits (`flutter-health-audit`, `nestjs-health-audit`, `python-health-audit`, `react-health-audit`) now score a 9th dimension — `CLAUDE.md`, `.claude/rules/`, `settings.json` permissions and hooks, custom agents, commands/skills, the pre-push git hook, advanced orchestration, and lifecycle/versioning — via a new `harness-analyzer` subagent (`model: mid`) and shared `references/harness-analysis.md` rubric (100 points across 9 dimensions, existence + quality split). Weighted at 0.10, with the existing 8 sections rescaled to sum to 0.90.

### Fixed

- **Runner report-generator dispatch (Phase 0)**: `somnio run` compared `step.ruleName.endsWith('_report_generator')` against rule names that are always hyphenated (`report-generator`), so the comparison never matched — `executeReportGenerator()` and the follow-on format-enforcer pass were unreachable, and every audit silently skipped enforcement. Fixed to compare against the exact rule name via a new `kReportGeneratorRuleName` / `kReportFormatEnforcerRuleName` constant.
- **Runner pre-flight artifact lookup (Phase 0)**: pre-flight artifacts were written with an underscore-joined `<techPrefix>_<rule_name>` key but looked up by bare rule name, so `flutter`/`nestjs`/`security` pre-flight steps (tool install, version checks, etc.) never matched their cached artifact and were always re-executed through the AI instead of reusing the deterministic pre-flight result. Fixed via a new pure, tested `preflightKey()` helper in `cli/lib/src/runner/rule_names.dart`, used at all three lookup sites in `run_command.dart`.
- **Rubrics no longer hardcode invoker-specific artifact paths**: the shared `references/` rubrics of the four health audits hardcoded the in-session artifact path (e.g. `reports/.artifacts/flutter_health/step_07_harness_analysis.md`), contradicting the CLI runner's own path convention (`step_{plan-index}_{rule-with-hyphens}.md` per `_artifactPath()`) when run via `somnio run`. Rubrics now defer to the path the invoker names; report generators locate the coverage/harness artifacts by glob (`step_*_test?coverage.md`) instead of an exact filename.
- **`SOMNIO_ARTIFACT_FILE` exported to step processes**: `StepExecutor` now exports the step's artifact path as the `SOMNIO_ARTIFACT_FILE` environment variable when spawning the AI CLI, so bash scripts embedded in rule files (e.g. the Python coverage runner) resolve the CLI's artifact path deterministically instead of relying on the model substituting it. In-session dispatch leaves the variable unset and falls back to the Dispatch Table path.

## [2.6.0] - 2026-06-04

### Added

- **Python Health Audit Skill**: New `python-health-audit` skill (`somnio-ph` / `ph`) that performs a comprehensive Python Project Health Audit. Analyzes tech stack, architecture, API/interface design, data layer, testing, code quality, CI/CD, and documentation. Produces a Google Docs-ready report with section scores and weighted overall score.
- **Python Best Practices Skill**: New `python-best-practices` skill (`somnio-pp` / `pp`) that runs a micro-level Python code quality audit. Validates code against live GitHub standards for typing, code style, function design, data validation, error handling, module structure, and testing. Produces a detailed violations report with prioritized action plan.
- **Python agent rules stacks**: Added `django`, `fastapi`, `flask`, and `python` to the `AgentRuleRegistry.stacks` list, enabling `somnio rules install` to target Python and its major frameworks alongside the existing Flutter/NestJS/React stacks.
- **Multi-model subagent orchestration**: All nine audit skills now fan out into a per-skill orchestrator + tiered analysis subagents (`cheap`/`mid`) + a dedicated frontier-tier report-writer, concentrating premium inference on the single user-facing report.
- **Portable model-tier convention**: Added the provider-neutral `cheap`/`mid`/`frontier` model-tier convention for audit `agents/*.md`, backed by a `modelTiers` map and a `resolveTier(...)` helper on `AgentConfig` that resolves tiers to per-agent model IDs (populated for Claude, Cursor, Gemini, Codex, Augment, and Qwen).
- **Subagent bundling/install**: Each in-scope skill's `agents/` directory is now bundled (via `SkillBundle.agentsDirectory` + `ContentLoader.loadAgentFiles`) and, for the Claude skill-dir install format, written under `<skill>/agents/` with each subagent's `model: <tier>` frontmatter resolved to the target agent's concrete model ID at install time; non-skill-dir formats skip `agents/` (no native subagent-dispatch surface).

### Changed

- **Retiered audit subagents**: Audit skills are retiered so mechanical scanners run on the cheap tier while synthesis runs on the frontier tier, concentrating premium inference on the single user-facing report.
- **`somnio run` per-step tiers**: `somnio run` now captures an optional per-step model tier (`{model: cheap|mid|frontier}` on a Rule Execution Order step) and resolves it via each agent's `modelTiers` before executing that step, with graceful fallback to `defaultModel` for agents lacking distinct tiers; the existing `fallbackModel` quota-retry behavior is preserved.

## [2.5.0] - 2026-05-30

### Added

- **Interactive install wizard**: `somnio install` now lets you pick which agents and skills to install via an arrow-key + spacebar menu instead of installing everything. New `--all-skills` flag installs every skill without prompting, and `--skills <ids>` installs a specific comma-separated subset (skips the wizard). When there is no interactive terminal (CI, pipes) it falls back to installing all skills so automation never hangs.
- **`somnio update` skill selection**: After updating the CLI, `update` now opens the same agent/skill wizard instead of silently reinstalling everything. Non-interactive runs (CI, pipes) still reinstall all skills, and `--all-skills` forces that behavior in a terminal.
- **Dart Model from JSON Skill**: New standalone `dart-model-from-json` skill that generates Dart model classes from a JSON structure using `json_annotation` and `equatable` (`copyWith`, `fromJson`, `toJson`, Equatable props; handles nested objects and arrays). Registered in the CLI skill registry.
- **Optimize Claude Config Skill**: New standalone `optimize-claude-config` skill that audits and optimizes a repo's Claude Code configuration so path-scoped rules load lazily and `CLAUDE.md` stays a lightweight index. Maps the real project tree (`git ls-files`) to validate every glob, migrates rule frontmatter to the native lazy-load `paths:` form, flags stale/over-broad globs, slims redundant `CLAUDE.md` content, and installs the read-not-create `PreToolUse(Write)` hook. Idempotent and conservative; supports `--audit-only` and an optional path argument. Stack-agnostic (requires `git` + `python3`). Registered in the CLI skill registry.
- **Flutter Rules**: Added `code-patterns`, `layout`, and `ui-theming` rules under `agent-rules/rules/flutter/`.
- **Test coverage**: Added a comprehensive unit-test suite (~21 new/extended test files, 379 tests) covering transformers, agents, content loaders, installers, runner, workflow, and utils. Every non-excluded source file under `cli/lib/` now has **100% line coverage**.

### Changed

- **Coverage gate (`pre-push`)**: The hook now enforces the threshold **per file** instead of as an aggregate average, and runs `format_coverage --check-ignore` so files marked `// coverage:ignore-file` (entrypoints, command shells, interactive prompts, and process-spawning orchestrators) are excluded from the calculation. It lists every offending file when the gate fails.
- **Interactive menus**: Migrated all selection prompts (`install`, `add`, `workflow`) from `mason_logger` to `interact_cli` with a Somnio-branded theme. The new menus redraw with relative cursor movement, fixing the jumping / duplicated-line rendering glitches the previous prompts showed when the list reached the bottom of the terminal.
- **Agent Rules**: Refactored flutter, nestjs, and react rule content across stacks and regenerated all tool adapters (Claude, Cursor, Windsurf, Copilot, Codex, Antigravity).
- **Docs**: Updated `docs/agent-rules.md` and the Cursor/Antigravity adapter READMEs to reflect the current flutter rule set.
- **flutter-best-practices Skill**: Updated standards references to point at `code-patterns` instead of the removed `dart-model-from-json` rule.

### Removed

- **Flutter Rule**: Removed `agent-rules/rules/flutter/dart-model-from-json.md`; its functionality now lives in the `dart-model-from-json` skill.

## [2.4.0] - 2026-05-26

### Added

- **Work-Log Hook**: New `hooks/work-log-stop.sh` script (portable, version-controlled) that appends a Haiku-generated 2-3 sentence summary of each Claude Code session turn to `~/.work-log/YYYY-MM-DD.md`. Logs root repo + worktree name (`mini-meta-repo/refactor-flutter_http`) so entries map cleanly to Clockify projects.
- **CLI `somnio hooks`**: New command to opt-in install the work-log Stop hook — copies the script to `~/.claude/hooks/`, makes it executable, and merges the Stop hook entry into `~/.claude/settings.json`. Idempotent; supports `--force` and `--verbose`.
- **Clockify log-based mode**: `clockify-tracker` skill now supports a second mode triggered by "use logs" / "usa los logs". Reads `~/.work-log/` daily files, maps repos to Clockify projects via `~/.clockify-prefs.json` (persisted), handles multi-project days with user-defined hour splits, generates 2-sentence executive summaries per entry, and shows a full preview before posting.
- **Docs**: Added `docs/work-log-stop-hook.md` explaining the hook design, setup, and relation to Clockify.

### Changed

- **Work-Log Hook**: Hook now logs the root git repo name instead of the worktree directory name, and appends the worktree name as a suffix (`root/worktree`) for traceability. Uses `which claude` instead of a hardcoded binary path for portability.
- **`clockify-tracker` command**: Updated description to document both manual mode (unchanged) and the new log-based mode.

## [2.3.0] - 2026-05-12

### Added

- **Agent Rules**: Multi-tool adapter system with rule files for Claude, Codex, Copilot, and Windsurf across functions and TypeScript stacks
- **Agent Rules**: Canonical rule sources under `agent-rules/rules/` for functions architecture, functions testing, and TypeScript best practices
- **Ship Skill**: New `ship` skill for automated PR workflow
- **Skills**: Report templates (`report-template.md`) added to all audit and best-practices skills (Flutter, NestJS, React, Security)

### Changed

- **CLI**: Updated `add`, `rules`, and `run` commands, registries, transformer, and scaffold generator to support the new agent-rules adapter system
- **Skills**: Updated SKILL.md files and references for flutter-best-practices, flutter-health-audit, nestjs-best-practices, nestjs-health-audit, react-best-practices, react-health-audit, and security-audit

### Removed

- **Plugins**: Removed legacy plugins — `engineering-management`, `marketing`, and `operations`

## [2.2.0] - 2026-04-16

### Added

- **Agent Rules**: Per-stack rule installs — Claude modular layout support with separate files per stack (Flutter, NestJS, React) instead of a single merged `CLAUDE.md`
- **Agent Rules**: `somnio rules uninstall` now cleans up all installed rule files
- **Engineering Management**: 10 new external service connectors for the engineering management plugin

### Changed

- **Health Audits**: Improved installation logic with stricter execution discipline and parallelization for faster audit runs
- **Agent Rules**: Migrated code generation script from shell to Python; generated outputs are now gitignored

### Fixed

- **CLI**: Fixed Antigravity skill installation and registered missing skills
- **Flutter Health Audit**: Enforced per-section coverage breakdown in the Testing section of the report

## [2.1.1] - 2026-03-25

### Fixed

- **Rules Install**: Fixed agent detection not finding Cursor (via `/Applications/Cursor.app`) or Antigravity (via `agy`/`antigravity` binaries) — detection now checks all methods: binary, detectionBinaries, detectionPaths, and installPath fallback
- **Rules Install**: Fixed screen reprinting/flickering when navigating the agent selection with arrow keys — detection table no longer renders above the interactive picker
- **Rules Install**: Fixed Claude adapter (`CLAUDE.md`) not found on git-based installs — file was not tracked in git
- **CLI**: Fixed `version.dart` version constant out of sync with `pubspec.yaml` (was stuck at `2.0.0`)

## [2.1.0] - 2026-03-25

### Added

- **Agent Rules**: New `somnio rules` CLI command with `install` and `status` subcommands for multi-agent coding rules management
- **Agent Rules**: Coding standards for NestJS, Flutter, and React with adapters for Claude, Cursor, Windsurf, Copilot, Codex, and Antigravity
- **Clockify Tracker**: New `clockify-tracker` skill with Clockify REST API integration for time tracking
- **Clockify Tracker**: New `clockify-tracker` command to expose the skill via CLI

### Changed

- **Plugins**: Renamed `plugins/developer` to `plugins/development` across all references and documentation

### Fixed

- **CLI**: Fixed `plan_parser` command handling and improved argument resolution
- **CLI**: Added `plan_parser` unit and integration tests for better reliability

## [2.0.0] - 2026-03-25

### Added

- **Plugin Architecture**: Native Claude Code plugin support with `.claude-plugin/` structure and `plugin.json` manifests
- **Workflow System**: Custom workflow system for multi-step, multi-model AI task orchestration
- **Git Skills**: New git-related skills including `git-commit-format` and `git-branch-format`
- **Marketing Plugin**: New `somnio-marketing` plugin with content strategy, ASO audits, and campaign analysis skills
- **Operations Plugin**: New `somnio-operations` plugin for user stories, backlog management, and project workflows
- **Engineering Management Plugin**: New `somnio-engineering-management` plugin with performance reviews and HandShake acknowledgement generation
- **Report Metadata**: Metadata fields (model, timestamp, agent version) injected into health audit reports

### Changed

- **Architecture**: Complete refactor to Agent Skills plugin architecture — skills are now distributed as Claude Code plugins (breaking change)
- **CLI**: Migrated from `skills.sh` shell scripts to structured Dart-based plugin installer
- **Multi-Agent Registry**: Data-driven multi-agent registry supporting 17 agents across all audit types

## [1.0.9] - 2026-02-27

### Added

- **Health Audit Reports**: Code Coverage field in Testing section (below Score)
- **Flutter**: Overall coverage (lib + packages) for single app; per-app overall for monorepo (apps/)
- **NestJS**: Total project coverage aggregated from lcov.info and coverage-summary.json
- **CLI preflight**: Automatic Code Coverage computation and injection into test_coverage artifacts

### Changed

- **Flutter test coverage**: Mandatory Code Coverage output in COVERAGE OVERVIEW
- **NestJS test coverage**: Mandatory Code Coverage output with lcov/coverage-summary parsing
- **Report templates**: Testing section includes Code Coverage placeholder
- **Report generators**: Extract Code Coverage from test_coverage artifact for Testing section

## [1.0.8] - 2025-02-26

### Added

- **Security Audit**: New `security_dependency_age.yaml` rule to detect outdated and deprecated packages per ecosystem
- **Security Audit**: New `security_gitleaks.yaml` rule for git history secret scanning with install recommendation
- **Security Audit**: New `security_sast.yaml` rule for static application security testing
- **Security Audit**: New `security_trivy.yaml` rule for container and filesystem vulnerability scanning

### Changed

- **CLI `somnio run`**: Added Gemini model support (`gemini-3-flash-preview`, `gemini-3-pro-preview`, `gemini-3.1-pro-preview`)
- **Security Audit**: Enhanced `security_dependency_audit.yaml` with improved vulnerability detection
- **Security Audit**: Updated `security_file_analysis.yaml` with expanded sensitive file checks
- **Security Audit**: Refined `security_gemini_analysis.yaml` for Gemini CLI integration
- **Security Audit**: Improved `security_report_format_enforcer.yaml` and `security_report_generator.yaml`
- **Security Audit**: Expanded `security_secret_patterns.yaml` with additional secret detection patterns
- **Security Audit**: Updated `security_tool_installer.yaml` with new tool support (Trivy, Gitleaks)
- **Security Audit**: Updated `security.plan.md` and workflow with new modular execution steps
- **Flutter/NestJS**: Updated `best_practices.plan.md` in both plans

### Fixed

- **Health audit follow-up**: When user responds YES/Y after a health audit, Best Practices and Security Audit are now actually executed instead of only showing the command
- **Health audit follow-up**: Extended prompt to suggest both Best Practices Check and Security Audit (previously only suggested Security Audit)
- **Health audit follow-up**: Per-bundle artifacts and report paths to avoid overwriting when running sequential audits
- `.gitignore` updates for security audit artifacts

## [1.0.7] - Previous

- Add security audit plan and Gemini model updates (#30)
- Interactive CLI selection and model validation for somnio run (#29)
- Improved banner using company colors (#28)
- NestJS Antigravity Workflows (#27)
- Setup command for AI CLI install (#26)
- Cursor CLI Support (#25)
