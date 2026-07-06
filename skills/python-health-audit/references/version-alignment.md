# Python Version Alignment

> Mandatory Python version alignment using uv for any Python project analysis (single package or monorepo). Pins the interpreter to .python-version or requires-python; hard stops on failure.

---

MANDATORY STEP: Execute Python Version Alignment before any project
analysis. This step is non-negotiable and MUST succeed before continuing.

CRITICAL REQUIREMENT: The correct Python interpreter version must be
active for all subsequent analysis steps. If this step fails, STOP
execution immediately and report the failure reason.

----------------------------------------------------------------------
MONOREPO DETECTION
----------------------------------------------------------------------

First detect repository structure:
- Single package: one `pyproject.toml` (or `setup.cfg` / `setup.py`)
  at the root; `src/` layout or flat layout
- Monorepo: multiple packages under `packages/` or `apps/`; or a
  workspace declared in the root `pyproject.toml`
  (`[tool.uv.workspace]` or `[tool.hatch.envs]`)

```bash
echo "=== Repository Structure Detection ==="
if [ -f "pyproject.toml" ] && grep -qE '^\[tool\.uv\.workspace\]' pyproject.toml 2>/dev/null; then
  echo "Monorepo detected: uv workspace"
  REPO_TYPE="monorepo"
elif [ -d "packages" ] || [ -d "apps" ]; then
  echo "Monorepo detected: packages/ or apps/ directory"
  REPO_TYPE="monorepo"
else
  echo "Single-package repository detected"
  REPO_TYPE="single"
fi
echo "REPO_TYPE=$REPO_TYPE"
```

----------------------------------------------------------------------
SINGLE PACKAGE VERSION ALIGNMENT
----------------------------------------------------------------------

1. **Extract Required Python Version**:
   - Check `.python-version` file (uv-managed pin) — highest priority
   - Check `requires-python` in `pyproject.toml`
   - Check `python_requires` in `setup.cfg` / `setup.py`
   - If none found: use the system Python version and document the gap

   ```bash
   echo "=== Extracting Required Python Version ==="
   REQUIRED_PY=""

   if [ -f ".python-version" ]; then
     REQUIRED_PY=$(cat .python-version | tr -d '[:space:]')
     echo "Found .python-version: $REQUIRED_PY"
   fi

   if [ -z "$REQUIRED_PY" ] && [ -f "pyproject.toml" ]; then
     REQUIRED_PY=$(grep -E '^requires-python' pyproject.toml 2>/dev/null | \
       grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
     [ -n "$REQUIRED_PY" ] && echo "Found requires-python in pyproject.toml: $REQUIRED_PY"
   fi

   if [ -z "$REQUIRED_PY" ]; then
     echo "WARNING: No Python version pin found (.python-version / requires-python)."
     echo "Recommend adding 'requires-python' to pyproject.toml and a .python-version file."
     REQUIRED_PY=$(python3 --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
     echo "Falling back to system Python: $REQUIRED_PY"
   fi

   echo "Target Python version: $REQUIRED_PY"
   ```

2. **Check Current Python Version**:
   ```bash
   echo "=== Current Python Version ==="
   CURRENT_PY=$(python3 --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
   echo "Current Python: ${CURRENT_PY:-NOT FOUND}"
   ```

3. **Version Mismatch Detection and Alignment**:
   ```bash
   echo "=== Version Alignment ==="
   if [ -z "$REQUIRED_PY" ]; then
     echo "ERROR: Could not determine required Python version. STOPPING."
     exit 1
   fi

   # Extract major.minor for comparison
   REQ_MINOR=$(echo "$REQUIRED_PY" | grep -oE '^[0-9]+\.[0-9]+')
   CUR_MINOR=$(echo "$CURRENT_PY" | grep -oE '^[0-9]+\.[0-9]+')

   if [ "$REQ_MINOR" = "$CUR_MINOR" ]; then
     echo "Python version already aligned: $CURRENT_PY matches $REQUIRED_PY"
   else
     echo "Version mismatch: current=$CURRENT_PY required=$REQUIRED_PY"
     echo "Installing required Python via uv..."
     uv python install "$REQUIRED_PY"
     if [ $? -ne 0 ]; then
       echo "ERROR: uv python install $REQUIRED_PY failed."
       echo "Resolve: ensure uv is up-to-date (uv self update) and the"
       echo "version string is valid (e.g. 3.12, 3.11.9)."
       exit 1
     fi
     echo "Python $REQUIRED_PY installed via uv."
   fi
   ```

4. **Pin .python-version (if missing)**:
   ```bash
   if [ ! -f ".python-version" ] && [ -n "$REQUIRED_PY" ]; then
     echo "Creating .python-version with $REQUIRED_PY"
     uv python pin "$REQUIRED_PY"
   fi
   ```

5. **Sync Virtual Environment**:
   ```bash
   echo "=== Virtual Environment Sync ==="
   if [ -f "pyproject.toml" ]; then
     echo "Running uv sync to create/update .venv..."
     uv sync
     if [ $? -ne 0 ]; then
       echo "ERROR: uv sync failed. STOPPING."
       echo "Check pyproject.toml dependencies and network access."
       exit 1
     fi
     echo "uv sync completed successfully."
   elif [ -f "requirements.txt" ]; then
     echo "No pyproject.toml — creating venv and installing requirements.txt..."
     uv venv
     uv pip install -r requirements.txt
     if [ $? -ne 0 ]; then
       echo "ERROR: dependency install failed. STOPPING."
       exit 1
     fi
   else
     echo "WARNING: No pyproject.toml or requirements.txt found."
     echo "Creating bare venv only."
     uv venv
   fi
   ```

----------------------------------------------------------------------
MONOREPO VERSION ALIGNMENT
----------------------------------------------------------------------

1. **Extract Version from Each Member**:
   ```bash
   echo "=== Monorepo Python Version Inventory ==="
   # Root
   ROOT_PY=""
   [ -f ".python-version" ] && ROOT_PY=$(cat .python-version | tr -d '[:space:]')
   [ -z "$ROOT_PY" ] && ROOT_PY=$(grep -E '^requires-python' pyproject.toml 2>/dev/null | \
     grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
   echo "root: ${ROOT_PY:-not specified}"

   # packages/
   for dir in packages/*/; do
     [ -f "$dir/.python-version" ] && PY=$(cat "$dir/.python-version" | tr -d '[:space:]') || \
       PY=$(grep -E '^requires-python' "$dir/pyproject.toml" 2>/dev/null | \
         grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
     echo "  $dir: ${PY:-not specified}"
   done

   # apps/
   for dir in apps/*/; do
     [ -f "$dir/.python-version" ] && PY=$(cat "$dir/.python-version" | tr -d '[:space:]') || \
       PY=$(grep -E '^requires-python' "$dir/pyproject.toml" 2>/dev/null | \
         grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
     echo "  $dir: ${PY:-not specified}"
   done
   ```

2. **Detect Conflicts**:
   - Document any major.minor discrepancies between members
   - Choose the highest pinned version as the target (or the root pin
     if a uv workspace is declared)

3. **Align and Sync Each Member**:
   ```bash
   # For each member with a pyproject.toml, run uv sync
   for dir in packages/*/ apps/*/; do
     if [ -f "$dir/pyproject.toml" ]; then
       echo "Syncing $dir..."
       (cd "$dir" && uv sync)
       if [ $? -ne 0 ]; then
         echo "ERROR: uv sync failed in $dir. STOPPING."
         exit 1
       fi
     fi
   done

   # Root workspace sync (if pyproject.toml exists at root)
   if [ -f "pyproject.toml" ]; then
     echo "Syncing root workspace..."
     uv sync
     if [ $? -ne 0 ]; then
       echo "ERROR: root uv sync failed. STOPPING."
       exit 1
     fi
   fi
   ```

----------------------------------------------------------------------
HARD STOP CONDITIONS
----------------------------------------------------------------------

STOP execution and report if any of the following occur:
- `uv python install <version>` exits non-zero
- `uv sync` exits non-zero in any member
- Required version cannot be determined AND no fallback Python exists
- `.venv` was not created after sync

These failures mean subsequent analysis steps would run against a
mis-configured interpreter and produce unreliable results.

----------------------------------------------------------------------
DOCUMENTATION
----------------------------------------------------------------------

After successful alignment, log:
- Python version now active
- Whether .python-version was already present or was created
- uv sync exit code for root and each monorepo member
- Any version conflicts found across monorepo members
- Recommendations: add .python-version, pin requires-python in
  pyproject.toml, commit the pin file to version control
