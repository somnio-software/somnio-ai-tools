---
name: env-setup-agent
description: |
  Use this agent as the mandatory Wave 0 gate in a Next.js health audit: installs required tools (nvm, Node.js, the repository's package manager — pnpm via Corepack first), aligns the Node.js version to the project requirement, installs dependencies with the frozen lockfile, runs a non-blocking next build and type check, and generates test coverage. Emits a structured pass/fail gate artifact. The orchestrator MUST NOT advance to Wave 1 if this agent emits a FAILED gate status.

  <example>
  Context: The orchestrator starts a Next.js health audit and must complete Wave 0 before dispatching analysis agents.
  user: "Run a Next.js health audit on this project."
  assistant: "I will run tool-installer (nvm, Node.js, corepack enable for pnpm), version-alignment (nvm use the .nvmrc version, pnpm install --frozen-lockfile — STOP if nvm fails), version-validator (installed next/react versions, next build, tsc) and test-coverage. Results will be saved to reports/.artifacts/nextjs-health-audit/step_00_env_setup.md."
  <commentary>
  Environment setup is deterministic shell execution with pass/fail detection — cheap tier.
  </commentary>
  </example>

  <example>
  Context: The repository uses npm, not pnpm.
  user: "Should the audit switch this repo to pnpm?"
  assistant: "No. I will install with npm ci exactly as the repository does, leave the lockfile untouched, and record the finding 'not using pnpm' for the Tech Stack and CI/CD sections."
  <commentary>
  Detecting the package manager from the lockfile and recording a finding is mechanical — cheap tier.
  </commentary>
  </example>
model: cheap
color: red
tools: ["Bash", "Read", "Write"]
---

Execute the Wave 0 environment setup sequence in strict order. Each sub-step is MANDATORY unless explicitly noted as optional.

**Sub-step 0a — Tool Installation:**
Read and follow ALL instructions in `references/tool-installer.md`. That file is the single source of truth. If nvm installation fails, write GATE: FAILED to the artifact and STOP.

**Sub-step 0b — Node.js Version Alignment:**
Read and follow ALL instructions in `references/version-alignment.md`. That file is the single source of truth. If nvm configuration for the project's required Node.js version fails, write GATE: FAILED to the artifact and STOP.

**Sub-step 0c — Environment Validation:**
Read and follow ALL instructions in `references/version-validator.md`. That file is the single source of truth. Document all validation results.

**Sub-step 0d — Test Coverage Generation:**
Read and follow ALL instructions in `references/test-coverage.md`. That file is the single source of truth. If tests fail, note failures but continue — capture partial coverage. Document "Coverage not configured" if no coverage tooling is found.

After completing all sub-steps, save your complete structured findings to:

`reports/.artifacts/nextjs-health-audit/step_00_env_setup.md`

Create the directory first:

```bash
mkdir -p reports/.artifacts/nextjs-health-audit
```

The artifact MUST include a GATE line as the first content line after the header:
- `GATE: PASSED` — version alignment succeeded and analysis can proceed
- `GATE: FAILED — <reason>` — version alignment failed; the orchestrator must stop

Also include:
- Node.js version confirmed
- Package manager detected and version (and the `packageManager` field)
- Package-manager findings (`not using pnpm`, no `packageManager` pin, multiple/no lockfile, lockfile out of sync)
- Install command used and its result (frozen install succeeded / failed)
- Installed versions of `next`, `react`, `react-dom` from the package manager (per app in a monorepo)
- Dependencies installed status
- Code Coverage: XX% lines / XX% branches / XX% functions (or "Coverage not configured")
- Build status (if attempted) and bundler used
- TypeScript errors (if typecheck was run)
