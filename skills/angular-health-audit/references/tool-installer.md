# Angular Tool Installer

> Verify and install required tools for Angular project analysis: nvm, Node.js, package managers, and the Angular CLI (used locally via npx).

---

Goal: Verify required tools are present and properly configured. Only
install tools that are genuinely missing — never reinstall tools that
are already available.

INSTALLATION PHILOSOPHY:
- CHECK FIRST: Always verify if a tool is already installed before attempting installation
- CONFIGURE, DON'T REINSTALL: If a tool exists, configure it for the project — do not reinstall
- MINIMAL CHANGES: Only install what is genuinely missing
- VERSION PRESERVATION: Do not change globally installed tool versions unless required by version-alignment step
- IDEMPOTENT: Running this installer multiple times must produce the same result without side effects

TOOLS TO INSTALL AND VERIFY:

1. **nvm (Node Version Manager)**:
   - Check if nvm is installed: `command -v nvm > /dev/null 2>&1`
   - If missing, install via official script:
     `curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash`
   - Source nvm: `. ~/.nvm/nvm.sh`
   - Verify: `nvm --version`
   - **CRITICAL**: If nvm install fails, STOP execution and provide
     manual installation instructions.

2. **Node.js (via nvm)**:
   - Install LTS version as fallback: `nvm install --lts`
   - Verify: `node --version`
   - Angular CLI is strict about supported Node.js ranges — the exact
     version is aligned in `version-alignment.md`.

3. **Package Managers** (install only if project uses them):
   - npm is bundled with Node.js — verify: `npm --version`
   - Only install yarn if `yarn.lock` exists AND yarn is not already installed:
     ```bash
     if [ -f "yarn.lock" ]; then
       if ! command -v yarn &> /dev/null; then
         echo "yarn.lock found but yarn not installed. Installing..."
         npm install -g yarn > /dev/null 2>&1
       else
         echo "yarn is already installed and configured."
       fi
     else
       echo "No yarn.lock found — skipping yarn installation."
     fi
     ```
   - Only install pnpm if `pnpm-lock.yaml` exists AND pnpm is not already installed:
     ```bash
     if [ -f "pnpm-lock.yaml" ]; then
       if ! command -v pnpm &> /dev/null; then
         echo "pnpm-lock.yaml found but pnpm not installed. Installing..."
         npm install -g pnpm > /dev/null 2>&1
       else
         echo "pnpm is already installed and configured."
       fi
     else
       echo "No pnpm-lock.yaml found — skipping pnpm installation."
     fi
     ```

4. **Angular-Specific Analysis Tools**:
   - Check for `npx` availability: `npx --version`
   - Prefer the project-local Angular CLI: `npx ng version` (reads the
     workspace's `@angular/cli`). Do NOT install `@angular/cli` globally —
     a global CLI can mismatch the project's version.
   - For Karma-based coverage, a headless Chrome/Chromium must be
     available; note `CHROME_BIN` if the runner cannot find a browser
     (do NOT install browsers globally as part of this step).

VERIFICATION CHECKLIST:
- nvm: installed and sourced
- node: version available
- npm/yarn/pnpm: package manager detected
- Angular CLI: resolvable via `npx ng version`
- Project dependencies: ready to install

ERROR HANDLING:
- If nvm fails to install: STOP and provide manual steps
- If Node.js fails to install via nvm: STOP and provide resolution
- If package manager is missing: attempt install, warn if fails
- Document all tool versions installed in the audit report

OUTPUT:
- List of tools installed with versions
- Angular CLI version (from `npx ng version`) or "not resolvable"
- Any errors or warnings encountered
- Ready status for version alignment step
