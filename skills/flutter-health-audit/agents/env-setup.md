---
name: env-setup
description: |
  Use this agent when configuring the Flutter environment for a health audit — installing required tools (Node.js, FVM), aligning the global Flutter version with the project requirement, validating the setup, and running comprehensive dependency installation. This is Wave 0: it MUST complete successfully before any analysis agent runs.

  <example>
  Context: The orchestrator launches the audit and Wave 0 must run before any analysis.
  user: "Run a health audit on this Flutter project."
  assistant: "I will start by configuring the Flutter environment: installing Node.js and FVM if missing, aligning the global Flutter version with the project's FVM config, validating the setup, and installing all dependencies (root, packages, apps)."
  <commentary>
  env-setup is always the first agent in a Flutter health audit. No analysis agent may start until env-setup succeeds. If version alignment fails, execution must stop.
  </commentary>
  </example>

  <example>
  Context: The audit environment is partially set up; FVM is installed but the project requires a different Flutter version.
  user: "Run the Flutter health audit."
  assistant: "I will check the current global Flutter version, detect the project's required version from .fvm/fvm_config.json or pubspec.yaml, and realign via FVM if there is a mismatch before proceeding."
  <commentary>
  Version realignment is idempotent and safe to re-run. The agent skips reinstalls when pub.lock and .dart_tool are already present.
  </commentary>
  </example>

  <example>
  Context: A monorepo has multiple apps each pinning a Flutter version; the orchestrator needs the environment ready before parallel analysis waves.
  user: "Audit this Flutter monorepo."
  assistant: "I will detect the monorepo structure, extract the required Flutter version from each app and package, resolve any cross-app version conflicts, set the FVM global version, and install all dependencies across apps/ and packages/ before signalling the orchestrator to advance."
  <commentary>
  Monorepo dependency installation spans apps/ and packages/ directories. The env-setup agent handles all of them in a single Wave 0 pass.
  </commentary>
  </example>

  <example>
  Context: Coverage generation is part of environment setup so that analysis agents can reference the preflight artifact.
  user: "Start the Flutter health audit."
  assistant: "After aligning the Flutter version and installing dependencies, I will run fvm flutter test --coverage to generate the lcov data and write the coverage summary to reports/.artifacts/flutter_health/step_00_test_coverage.md."
  <commentary>
  Test coverage is captured in Wave 0 so that testing-analyzer (Wave 2) can reference the preflight artifact rather than re-running coverage.
  </commentary>
  </example>
model: cheap
color: cyan
tools: ["Bash", "Read", "Write"]
---

Read and follow ALL instructions in `references/tool-installer.md`, `references/version-alignment.md`, `references/version-validator.md`, and `references/test-coverage.md` — these four references are the single source of truth for this agent's complete execution.

Execute them in this exact order:

1. `references/tool-installer.md` — installs Node.js and FVM. MANDATORY; stop if it fails.
2. `references/version-alignment.md` — aligns the global Flutter version to the project requirement via FVM. MANDATORY; stop if it fails.
3. `references/version-validator.md` — verifies the FVM global setup and installs all dependencies (root, packages, apps).
4. `references/test-coverage.md` — runs `fvm flutter test --coverage` and writes the coverage artifact to `reports/.artifacts/flutter_health/step_00_test_coverage.md`.

Write the artifact for step 4 to: `reports/.artifacts/flutter_health/step_00_test_coverage.md`

Create the directory first: `mkdir -p reports/.artifacts/flutter_health`

On success, output: `WAVE 0 COMPLETED: env-setup passed. Flutter version aligned. Coverage artifact written.`
On failure of any MANDATORY step, output: `WAVE 0 FAILED: [step name] — [reason]. Stopping audit.` and halt.
