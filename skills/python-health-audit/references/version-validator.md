# Python Version Validator

> Verify venv is active, the correct Python interpreter is in use, and dependencies are fully installed across the root and every package/app — using uv pip list for inventory.

---

Goal: Confirm that the virtual environment created by version-alignment
is active and that all declared dependencies are installed in every
project member (root, packages/, apps/). Use `uv pip list` to produce
an auditable inventory.

MONOREPO DETECTION:
- Detect repository structure before running any checks
- If `packages/` or `apps/` directories exist, validate each member
  individually
- If a uv workspace is declared, also validate the root

----------------------------------------------------------------------
VALIDATION CHECKS
----------------------------------------------------------------------

1. uv Installation Confirmation:
   ```bash
   echo "=== uv Installation ==="
   if command -v uv > /dev/null 2>&1; then
     echo "uv: $(uv --version)"
   else
     echo "ERROR: uv is NOT installed — run @python_tool_installer"
     exit 1
   fi
   ```

2. Python Version Pin File Check:
   ```bash
   echo "=== Python Version Pin ==="
   if [ -f ".python-version" ]; then
     echo ".python-version found: $(cat .python-version | tr -d '[:space:]')"
   else
     echo "WARNING: .python-version not present — version pin is implicit only"
   fi

   # Check requires-python in pyproject.toml
   if [ -f "pyproject.toml" ]; then
     RQ=$(grep -E '^requires-python' pyproject.toml 2>/dev/null | head -1)
     if [ -n "$RQ" ]; then
       echo "pyproject.toml requires-python: $RQ"
     else
       echo "WARNING: requires-python not set in pyproject.toml"
     fi
   fi
   ```

3. Active Python Interpreter Verification:
   ```bash
   echo "=== Active Python Interpreter ==="
   echo "which python:  $(which python 2>/dev/null || echo 'not in PATH')"
   echo "which python3: $(which python3 2>/dev/null || echo 'not in PATH')"
   echo "python version: $(python --version 2>/dev/null || python3 --version 2>/dev/null || echo 'NOT FOUND')"

   # Check if inside a venv
   if [ -n "$VIRTUAL_ENV" ]; then
     echo "VIRTUAL_ENV is set: $VIRTUAL_ENV"
   elif [ -d ".venv" ]; then
     echo ".venv directory exists (uv-managed)"
     echo "Interpreter: $(.venv/bin/python --version 2>/dev/null || echo 'unable to read')"
   else
     echo "WARNING: No active venv detected and no .venv directory found"
   fi
   ```

4. Root Dependency Installation Check:
   ```bash
   echo "=== Root Dependencies ==="
   if [ -f "pyproject.toml" ]; then
     echo "Running uv pip list (root)..."
     uv pip list 2>/dev/null || \
       uv run pip list 2>/dev/null || \
       echo "WARNING: uv pip list failed — venv may not be synced"
   elif [ -f "requirements.txt" ]; then
     echo "requirements.txt found. Checking installed packages..."
     uv pip list 2>/dev/null || pip list 2>/dev/null || \
       echo "WARNING: could not list installed packages"
   else
     echo "WARNING: No pyproject.toml or requirements.txt at root"
   fi
   ```

5. Monorepo Member Validation (if applicable):
   ```bash
   echo "=== Monorepo Member Validation ==="

   # packages/
   if [ -d "packages" ]; then
     echo "packages/ directory found:"
     for dir in packages/*/; do
       pkg=$(basename "$dir")
       echo "--- $pkg ---"
       if [ -f "$dir/pyproject.toml" ]; then
         echo "pyproject.toml: present"
         if [ -d "$dir/.venv" ]; then
           echo ".venv: present"
           echo "Installed packages in $pkg:"
           (cd "$dir" && uv pip list 2>/dev/null || \
             uv run pip list 2>/dev/null || \
             echo "  WARNING: uv pip list failed")
         else
           echo "WARNING: .venv not found in $dir — run uv sync in that directory"
         fi
       elif [ -f "$dir/requirements.txt" ]; then
         echo "requirements.txt: present (no pyproject.toml)"
       else
         echo "WARNING: No pyproject.toml or requirements.txt in $dir"
       fi
     done
   fi

   # apps/
   if [ -d "apps" ]; then
     echo "apps/ directory found:"
     for dir in apps/*/; do
       app=$(basename "$dir")
       echo "--- $app ---"
       if [ -f "$dir/pyproject.toml" ]; then
         echo "pyproject.toml: present"
         if [ -d "$dir/.venv" ]; then
           echo ".venv: present"
           echo "Installed packages in $app:"
           (cd "$dir" && uv pip list 2>/dev/null || \
             uv run pip list 2>/dev/null || \
             echo "  WARNING: uv pip list failed")
         else
           echo "WARNING: .venv not found in $dir — run uv sync in that directory"
         fi
       else
         echo "WARNING: No pyproject.toml in $dir"
       fi
     done
   fi
   ```

6. Key Test / Lint Dependency Verification:
   ```bash
   echo "=== Key Tool Availability ==="
   # Check inside venv for critical packages
   PYTHON_BIN="$(command -v python 2>/dev/null || command -v python3)"
   if [ -d ".venv" ]; then
     PYTHON_BIN=".venv/bin/python"
   fi

   check_pkg() {
     pkg=$1
     $PYTHON_BIN -c "import $pkg; print('$pkg: OK')" 2>/dev/null || \
       echo "WARNING: $pkg not importable in current environment"
   }

   check_pkg pytest
   check_pkg pytest_cov
   check_pkg ruff 2>/dev/null || \
     (command -v ruff > /dev/null 2>&1 && echo "ruff: OK (global)") || \
     echo "WARNING: ruff not available"
   ```

7. Lockfile / Sync State Check:
   ```bash
   echo "=== Lockfile and Sync State ==="
   if [ -f "uv.lock" ]; then
     echo "uv.lock: present"
     # Verify lock is consistent with pyproject.toml
     uv lock --check 2>/dev/null && echo "Lock is up-to-date" || \
       echo "WARNING: uv.lock may be out of sync with pyproject.toml — run uv lock"
   elif [ -f "requirements.txt" ]; then
     echo "requirements.txt: present (no uv.lock)"
   else
     echo "WARNING: No lockfile found (uv.lock or requirements.txt)"
   fi
   ```

Output format:
- Repository structure (single / monorepo)
- uv version
- Python version active vs required
- VIRTUAL_ENV or .venv status
- uv pip list output for root and each member
- Key package availability (pytest, pytest-cov, ruff, mypy/pyright)
- Lockfile consistency status
- Actionable fix for each WARNING or ERROR
