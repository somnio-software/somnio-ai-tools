# Flutter Tool Installer

> Centralized installer for required tools (Node.js, FVM) for the Flutter Project Health Audit.

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

TOOLS TO INSTALL:
1. Node.js & npm (via Homebrew if missing)
2. FVM (Flutter Version Management)

EXECUTION STEPS:

1. Check/Install Node.js & npm:
   ```bash
   echo "Checking Node.js and npm..."
   if ! command -v npm &> /dev/null; then
     echo "npm not found. Attempting to install Node.js (which
       includes npm)..."
     if command -v brew &> /dev/null; then
       echo "Homebrew found. Installing Node.js..."
       brew install node > /dev/null 2>&1
       if [ $? -ne 0 ]; then
         echo "ERROR: Failed to install Node.js via Homebrew."
         echo "Please install Node.js manually: https://nodejs.org/"
         exit 1
       fi
       echo "Node.js installed successfully."
     else
       echo "ERROR: Homebrew not found. Cannot auto-install Node.js."
       echo "Please install Node.js manually: https://nodejs.org/"
       exit 1
     fi
   else
     echo "Node.js and npm are already installed and configured."
     node --version > /dev/null 2>&1
     npm --version > /dev/null 2>&1
   fi
   ```

2. Check/Install FVM:
   ```bash
   echo "Checking FVM..."
   if ! command -v fvm &> /dev/null; then
     echo "FVM not found. Installing via dart pub global activate..."
     dart pub global activate fvm > /dev/null 2>&1
     if [ $? -ne 0 ]; then
       echo "ERROR: Failed to install FVM."
       exit 1
     fi
     # Add to PATH if needed (best effort for current session)
     export PATH="$PATH":"$HOME/.pub-cache/bin"
     echo "FVM installed successfully."
   else
     echo "FVM is already installed and configured."
     fvm --version > /dev/null 2>&1
   fi
   ```

Output format:
- Status of each tool (Installed/Updated/Failed)
- Any manual intervention required
