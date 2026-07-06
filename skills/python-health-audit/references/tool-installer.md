# Python Tool Installer

> Idempotent installer for all required Python tooling (uv, Ruff, mypy or pyright, pytest + pytest-cov) for the Python Project Health Audit.

---

Goal: Verify required tools are present and properly configured. Only
install tools that are genuinely missing — never reinstall tools that
are already available.

INSTALLATION PHILOSOPHY:
- CHECK FIRST: Always verify if a tool is already installed before
  attempting installation
- CONFIGURE, DON'T REINSTALL: If a tool exists, configure it for the
  project — do not reinstall
- MINIMAL CHANGES: Only install what is genuinely missing
- IDEMPOTENT: Running this installer multiple times must produce the
  same result without side effects
- NO FABRICATED TOOLS: Only use tools that are verifiably available
  (uv, Ruff, mypy, pyright, pytest, pytest-cov)

TOOLS TO VERIFY / INSTALL:
1. uv (Python package and project manager)
2. Ruff (linter + formatter)
3. mypy OR pyright (static type checker — prefer whichever is already
   configured in pyproject.toml / pyrightconfig.json)
4. pytest + pytest-cov (test runner + coverage)

EXECUTION STEPS:

1. Check/Install uv:
   ```bash
   echo "Checking uv..."
   if command -v uv > /dev/null 2>&1; then
     echo "uv is already installed."
     uv --version
   else
     echo "uv not found. Installing uv..."
     # Official uv installer (https://docs.astral.sh/uv/getting-started/installation/)
     curl -LsSf https://astral.sh/uv/install.sh | sh
     # Re-source shell path so uv is available immediately
     export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"
     if command -v uv > /dev/null 2>&1; then
       echo "uv installed successfully."
       uv --version
     else
       echo "ERROR: uv installation failed."
       echo "Please install uv manually: https://docs.astral.sh/uv/"
       exit 1
     fi
   fi
   ```

2. Check/Install Ruff:
   ```bash
   echo "Checking Ruff..."
   if command -v ruff > /dev/null 2>&1; then
     echo "Ruff is already installed."
     ruff --version
   else
     echo "Ruff not found. Installing via uv tool..."
     uv tool install ruff
     if command -v ruff > /dev/null 2>&1; then
       echo "Ruff installed successfully."
       ruff --version
     else
       echo "WARNING: Ruff not available in PATH after install."
       echo "Trying: uv run ruff --version"
       uv run ruff --version 2>/dev/null || \
         echo "Ruff unavailable — lint step will use: uv run ruff"
     fi
   fi
   ```

3. Check/Install type checker (mypy or pyright):
   ```bash
   echo "Checking type checker..."

   # Detect which type checker is configured in the project
   TYPECHECKER=""
   if grep -qE '^\[tool\.mypy\]' pyproject.toml 2>/dev/null || \
      [ -f "mypy.ini" ] || [ -f ".mypy.ini" ] || \
      [ -f "setup.cfg" ] && grep -q "\[mypy\]" setup.cfg 2>/dev/null; then
     TYPECHECKER="mypy"
   elif grep -qE '^\[tool\.pyright\]' pyproject.toml 2>/dev/null || \
        [ -f "pyrightconfig.json" ]; then
     TYPECHECKER="pyright"
   fi

   if [ -z "$TYPECHECKER" ]; then
     # Default to mypy when no config is found
     TYPECHECKER="mypy"
     echo "No type checker config detected — defaulting to mypy"
   fi

   echo "Selected type checker: $TYPECHECKER"

   if command -v "$TYPECHECKER" > /dev/null 2>&1; then
     echo "$TYPECHECKER is already installed."
     $TYPECHECKER --version
   else
     echo "$TYPECHECKER not found. Installing via uv tool..."
     uv tool install "$TYPECHECKER"
     if command -v "$TYPECHECKER" > /dev/null 2>&1; then
       echo "$TYPECHECKER installed successfully."
       $TYPECHECKER --version
     else
       echo "WARNING: $TYPECHECKER not in PATH — will use: uv run $TYPECHECKER"
     fi
   fi
   ```

4. Check/Install pytest and pytest-cov:
   ```bash
   echo "Checking pytest and pytest-cov..."

   # Check inside the active venv / uv-managed environment first
   if uv run pytest --version > /dev/null 2>&1; then
     echo "pytest is available via uv run."
     uv run pytest --version
   elif command -v pytest > /dev/null 2>&1; then
     echo "pytest is available on PATH."
     pytest --version
   else
     echo "pytest not found. Installing via uv add --dev..."
     if [ -f "pyproject.toml" ]; then
       uv add --dev pytest pytest-cov
     else
       echo "No pyproject.toml found — installing pytest globally via uv tool..."
       uv tool install pytest
       uv tool install pytest-cov 2>/dev/null || true
     fi
     uv run pytest --version || pytest --version || \
       echo "ERROR: pytest still unavailable after install."
   fi

   # Verify pytest-cov specifically
   echo "Verifying pytest-cov..."
   uv run python -c "import pytest_cov; print('pytest-cov:', pytest_cov.__version__)" \
     2>/dev/null || \
   python -c "import pytest_cov; print('pytest-cov:', pytest_cov.__version__)" \
     2>/dev/null || \
   echo "WARNING: pytest-cov not importable — coverage step may fail. Run: uv add --dev pytest-cov"
   ```

5. Verify all tool installations:
   ```bash
   echo "=== Tool Verification ==="
   echo "uv:         $(uv --version 2>/dev/null || echo 'NOT FOUND')"
   echo "ruff:       $(ruff --version 2>/dev/null || uv run ruff --version 2>/dev/null || echo 'NOT FOUND')"
   echo "mypy:       $(mypy --version 2>/dev/null || uv run mypy --version 2>/dev/null || echo 'not configured')"
   echo "pyright:    $(pyright --version 2>/dev/null || uv run pyright --version 2>/dev/null || echo 'not configured')"
   echo "pytest:     $(uv run pytest --version 2>/dev/null || pytest --version 2>/dev/null || echo 'NOT FOUND')"
   echo "pytest-cov: $(uv run python -c 'import pytest_cov; print(pytest_cov.__version__)' 2>/dev/null || echo 'NOT FOUND')"
   echo "========================="
   ```

Output format:
- Status of each tool (Already installed / Installed / WARNING / ERROR)
- Version information for all installed tools
- Which type checker is configured and will be used
- Any manual intervention required
- No tool is silently skipped without a logged reason
