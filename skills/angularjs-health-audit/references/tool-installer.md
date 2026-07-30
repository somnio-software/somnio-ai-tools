# AngularJS Tool Installer

> Install required tools for AngularJS project analysis: nvm, Node.js, npm, and (when the project uses them) Bower and the Grunt/gulp CLIs.

---

Goal: Verify required tools are present and properly configured. Only
install tools that are genuinely missing — never reinstall tools that
are already available. AngularJS runs in the browser, but its toolchain —
Bower, Grunt/gulp, Karma — runs on Node, so Node/npm must be available.

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
   - Note: legacy AngularJS toolchains (old Grunt/gulp/Karma, node-sass) can
     fail on very new Node majors. If the project pins an old Node via
     `.nvmrc`/`engines`, honor it (version-alignment handles this).

3. **Package Managers / npm**:
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

4. **Bower** (install only if the project uses it):
   - Only install bower if `bower.json` exists AND bower is not already installed:
     ```bash
     if [ -f "bower.json" ]; then
       if ! command -v bower &> /dev/null; then
         echo "bower.json found but bower not installed. Installing..."
         npm install -g bower > /dev/null 2>&1
       else
         echo "bower is already installed and configured."
       fi
     else
       echo "No bower.json found — skipping bower installation."
     fi
     ```
   - Note in the report that Bower is deprecated/abandoned (migration risk),
     but it is still required to resolve `bower_components/` for this project.

5. **Build Tool CLIs** (install only if the project uses them):
   - Grunt: if `Gruntfile.js` exists and `grunt` is missing, install
     `grunt-cli` globally (`npm install -g grunt-cli`); otherwise skip.
   - gulp: if `gulpfile.js` exists and `gulp` is missing, install `gulp-cli`
     globally (`npm install -g gulp-cli`); otherwise skip.
   - Do NOT install both if only one is used.

6. **AngularJS-Specific Analysis Tools**:
   - Check for `npx` availability: `npx --version`
   - For coverage analysis: ensure `karma` / `karma-coverage` are available as
     project dev dependencies (do NOT install globally)

VERIFICATION CHECKLIST:
- nvm: installed and sourced
- node: version available
- npm/yarn: package manager detected
- bower: installed if `bower.json` present
- grunt/gulp CLI: installed if the matching build file is present
- Project dependencies: ready to install (npm + bower)

ERROR HANDLING:
- If nvm fails to install: STOP and provide manual steps
- If Node.js fails to install via nvm: STOP and provide resolution
- If bower/grunt/gulp is missing: attempt install, warn if fails
- Document all tool versions installed in the audit report

OUTPUT:
- List of tools installed with versions (node, npm, bower, grunt/gulp)
- Any errors or warnings encountered
- Ready status for version alignment step
