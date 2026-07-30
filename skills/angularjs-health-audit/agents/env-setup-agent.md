---
name: env-setup-agent
description: |
  Use this agent as the mandatory Wave 0 gate in an AngularJS (Angular 1.x) health audit: installs required tools (nvm, Node.js, npm, and — when the project uses them — Bower and the Grunt/gulp CLIs), aligns the Node.js version to the project requirement, validates dependency installation (npm + Bower), and generates Karma test coverage. Emits a structured pass/fail gate artifact. The orchestrator MUST NOT advance to Wave 1 if this agent emits a FAILED gate status.

  <example>
  Context: The orchestrator starts an AngularJS health audit and must complete Wave 0 before dispatching analysis agents.
  user: "Run an AngularJS health audit on this project."
  assistant: "I will execute the Wave 0 setup sequence: install missing tools via tool-installer (nvm, Node, Bower, Grunt/gulp CLI as needed), align the Node.js version via version-alignment (STOP if fails), validate the nvm setup and dependency install via version-validator, and generate Karma coverage via test-coverage. Results will be saved to reports/.artifacts/angularjs-health-audit/step_00_env_setup.md."
  <commentary>
  Environment setup is deterministic shell execution — no judgment, just command execution and pass/fail detection. Cheap tier is appropriate.
  </commentary>
  </example>

  <example>
  Context: The project pins an older Node.js version in .nvmrc because its legacy Grunt/Karma toolchain breaks on newer Node.
  user: "The project's .nvmrc says Node 12 but my system has Node 20."
  assistant: "I will use nvm to install the pinned Node version, switch to it, verify the version matches the project requirement, then install npm dev-tooling and (if bower.json is present) Bower components, and run Karma with coverage."
  <commentary>
  nvm version switching and dependency installation are shell commands — deterministic, mechanical, cheap tier. Legacy AngularJS toolchains often need an older Node.
  </commentary>
  </example>

  <example>
  Context: nvm is not installed on the system.
  user: "Run the AngularJS health audit setup."
  assistant: "nvm is not found. I will install it via the official install script, source it, then proceed with Node.js version alignment. If nvm installation fails, I will emit GATE: FAILED in the artifact and stop."
  <commentary>
  Tool installation with pass/fail gating is a sequential shell script — mechanical, cheap tier.
  </commentary>
  </example>

  <example>
  Context: The orchestrator needs to verify the Wave 0 gate before proceeding.
  user: "Did the environment setup succeed?"
  assistant: "I will read reports/.artifacts/angularjs-health-audit/step_00_env_setup.md and confirm the GATE status. If GATE: PASSED, Wave 1 can proceed. If GATE: FAILED, I will report the failure reason and stop."
  <commentary>
  Gate status verification is reading a file and checking a keyword — mechanical, cheap tier.
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
Read and follow ALL instructions in `references/version-validator.md`. That file is the single source of truth. Document all validation results (npm + Bower dependency installation).

**Sub-step 0d — Test Coverage Generation:**
Read and follow ALL instructions in `references/test-coverage.md`. That file is the single source of truth. If tests fail, note failures but continue — capture partial coverage. Document "Coverage not configured" if no Karma/coverage tooling is found, or "Coverage not collected — no runnable browser" if the launcher (e.g. PhantomJS) is unavailable.

After completing all sub-steps, save your complete structured findings to:

`reports/.artifacts/angularjs-health-audit/step_00_env_setup.md`

Create the directory first:

```bash
mkdir -p reports/.artifacts/angularjs-health-audit
```

The artifact MUST include a GATE line as the first content line after the header:
- `GATE: PASSED` — version alignment succeeded and analysis can proceed
- `GATE: FAILED — <reason>` — version alignment failed; the orchestrator must stop

Also include:
- Node.js version confirmed
- Package manager detected and version (npm/yarn); Bower used yes/no and components installed
- Dependencies installed status
- Code Coverage: XX% lines / XX% branches / XX% functions (or "Coverage not configured")
- Build status (if attempted — e.g. grunt/gulp build)
- Lint errors (if a lint task was run)
