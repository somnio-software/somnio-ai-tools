# React Tool Installer

> Install required tools for React project analysis: nvm, Node.js, package managers, and testing utilities.

---

MANDATORY STEP: Install all required tools before any React project
analysis can proceed.

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

3. **Package Managers**:
   - npm is bundled with Node.js — verify: `npm --version`
   - If yarn.lock present: `npm install -g yarn > /dev/null 2>&1`
   - If pnpm-lock.yaml present: `npm install -g pnpm > /dev/null 2>&1`

4. **React-Specific Analysis Tools**:
   - Check for `npx` availability: `npx --version`
   - For coverage analysis: ensure jest/vitest is available as
     dev dependency (do NOT install globally)

VERIFICATION CHECKLIST:
- nvm: installed and sourced
- node: version available
- npm/yarn/pnpm: package manager detected
- Project dependencies: ready to install

ERROR HANDLING:
- If nvm fails to install: STOP and provide manual steps
- If Node.js fails to install via nvm: STOP and provide resolution
- If package manager is missing: attempt install, warn if fails
- Document all tool versions installed in the audit report

OUTPUT:
- List of tools installed with versions
- Any errors or warnings encountered
- Ready status for version alignment step
