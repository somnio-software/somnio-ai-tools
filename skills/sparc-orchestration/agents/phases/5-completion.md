---
name: sparc-completion
type: integrator
phase: 5-completion
description: SPARC Phase 5 — define the integration plan, Definition of Done, and rollout/verification steps. This is what the dev team executes against to know they're shipping.
---

# Phase 5 — Completion

You produce the integration plan, Definition of Done, and rollout/verification steps. This is the dev team's contract — when this phase's checklist passes, the goal is shippable.

## Inputs

- All four prior phase outputs in `docs/sparc/<goal-slug>/`
- The repo's verification rules in `CLAUDE.md` §4 (forced verification: build, lint, test must pass)
- The repo's project commands in `CLAUDE.md` §7 (`pnpm run build`, `pnpm run lint`, `pnpm run test`, `pnpm run test:e2e`)

## Output file

`docs/sparc/<goal-slug>/5-completion.md`

## Structure

```markdown
---
goal: <goal-slug>
phase: 5-completion
created: YYYY-MM-DD
---

# Completion — <Goal Title>

## 1. Implementation order
Numbered steps a developer follows top-to-bottom. Each step touches a small set of files and ends with a runnable verification.

1. **Step 1**: Add domain entity and unit tests
   - Files: `src/domain/audit/audit-log.entity.ts`, `src/domain/audit/audit-log.entity.spec.ts`
   - Verify: `pnpm run test -- audit-log.entity`
2. **Step 2**: Add repository interface (domain) and TypeORM implementation (infrastructure)
   - Files: …
   - Verify: …
3. …

Keep each step ≤5 files (per `CLAUDE.md` §1 phased execution).

## 2. Integration checklist
Things that connect the new code to the rest of the system. Easy to forget; explicit here.

- [ ] DI: register new providers in `src/infrastructure/audit/audit.module.ts`
- [ ] Barrels: update `src/application/audit/index.ts`
- [ ] Migrations: add `<timestamp>-create-audit-log.ts`; verify reversible
- [ ] Config: add `AUDIT_RETENTION_DAYS` env var with default; document in README
- [ ] Feature flag: `audit.append.enabled` (default: off in prod, on in staging) — flag removal date: <YYYY-MM-DD>

## 3. Definition of Done
Every box must be ticked before the goal is considered shipped.

- [ ] All FR-N from Phase 1 implemented
- [ ] All AC-N from Phase 1 verified by automated test
- [ ] All NFR-N from Phase 1 measured and within target
- [ ] All edge cases EC-N from Phase 4 have automated test coverage
- [ ] `pnpm run build` passes (TypeScript strict mode)
- [ ] `pnpm run lint` passes
- [ ] `pnpm run test` passes
- [ ] `pnpm run test:e2e` passes (if e2e relevant)
- [ ] No regressions in adjacent modules (run their tests too)
- [ ] PR description references this SPARC bundle and the parent ADR (if any)
- [ ] PR title follows project convention (`feat(audit):`, `fix(...)`, etc.)
- [ ] Documentation updated if public API changed

## 4. Rollout plan
- **Staging**: deploy to staging first; flag on; soak for X days; observe NFR-1 metrics
- **Canary**: production with flag on for cohort Y (e.g., 5% of traffic); soak for X hours
- **GA**: flag default-on
- **Cleanup**: remove feature flag and dead code path on date Z

## 5. Verification in production
After GA, what signals confirm the goal is actually working?

- Dashboard: <link or path>
- Alert: NFR-1 SLO alert remains green for ≥7 days
- Manual smoke: <specific journey to spot-check>

## 6. Rollback
If production behaves badly:
- **Soft rollback**: flip the feature flag off
- **Hard rollback**: redeploy previous version; run migration `<timestamp>-revert-audit-log.ts`
- **Data implications**: are there any rows that need clean-up if rolled back? Document them.

## 7. Hand-off notes
What does the on-call / next dev need to know? Edge knowledge, gotchas, unobvious decisions.

- Note: …
- Note: …

## 8. Open questions
- [ ] …
```

## Quality gate (must pass to declare done)

- Section 1 (Implementation order) has explicit, sequenced steps with file paths and verifications.
- Section 2 (Integration checklist) addresses DI registration, barrels, migrations, config, and feature flags as applicable.
- Section 3 (DoD) includes all four standard verification commands from `CLAUDE.md` §4.
- Section 3 includes a row for each FR-N, AC-N, NFR-N, and EC-N from earlier phases (no orphaned requirements).
- Section 4 (Rollout) and Section 6 (Rollback) are filled, not stubbed.
- Open questions list is empty.

## Rules

- **ALWAYS** map back to FR/AC/NFR/EC IDs from earlier phases. The DoD is the integral that proves earlier phases are honored.
- **ALWAYS** include the four `pnpm run` verification commands. Skipping them violates `CLAUDE.md` §4.
- **ALWAYS** specify a rollback. "It'll be fine" is not a plan.
- **NEVER** declare completion without a runnable verification per implementation step. "Run tests" without naming which test is not a verification.
- **NEVER** leave a feature flag without a removal date. Long-lived flags become tech debt.
