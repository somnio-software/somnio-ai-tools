# NestJS Tool Installer

> Centralized installer for all required tools (Node.js, nvm, npm/yarn/pnpm) for the NestJS Project Health Audit.

---

Goal: Ensure all required tools are installed and configured before
running the audit.

TOOLS TO INSTALL:
1. Node.js & npm
2. nvm (Node Version Manager)
3. yarn (optional but recommended)
4. pnpm (optional but recommended)

EXECUTION STEPS:

1. Check/Install nvm:
   ```bash
   echo "Checking nvm..."
   if ! command -v nvm &> /dev/null; then
     echo "nvm not found. Installing nvm..."
      if [[ "$OSTYPE" == "darwin"* ]] || \
        [[ "$OSTYPE" == "linux-gnu"* ]]; then
        curl -o- \
          https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
       export NVM_DIR="$HOME/.nvm"
       [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
       if [ $? -ne 0 ]; then
         echo "ERROR: Failed to install nvm."
         echo "Please install nvm manually: https://github.com/nvm-sh/nvm"
         exit 1
       fi
       echo "nvm installed successfully."
     else
       echo "ERROR: Unsupported OS for automatic nvm installation."
       echo "Please install nvm manually: https://github.com/nvm-sh/nvm"
       exit 1
     fi
   else
     echo "nvm is installed."
   fi
   ```

2. Check/Install Node.js & npm:
   ```bash
   echo "Checking Node.js and npm..."
   if ! command -v node &> /dev/null; then
     echo "Node.js not found. Installing via nvm..."
     if command -v nvm &> /dev/null; then
       nvm install --lts > /dev/null 2>&1
       nvm use --lts > /dev/null 2>&1
       if [ $? -ne 0 ]; then
         echo "ERROR: Failed to install Node.js via nvm."
         echo "Please install Node.js manually: https://nodejs.org/"
         exit 1
       fi
       echo "Node.js installed successfully."
     else
       echo "ERROR: nvm not found. Cannot auto-install Node.js."
       echo "Please install Node.js manually: https://nodejs.org/"
       exit 1
     fi
   else
     echo "Node.js and npm are installed."
     node --version > /dev/null 2>&1
     npm --version > /dev/null 2>&1
   fi
   ```

3. Check/Install yarn (optional):
   ```bash
   echo "Checking yarn..."
   if ! command -v yarn &> /dev/null; then
     echo "yarn not found. Installing yarn globally..."
     npm install -g yarn > /dev/null 2>&1
     if [ $? -ne 0 ]; then
       echo "WARNING: Failed to install yarn. Continuing with npm."
     else
       echo "yarn installed successfully."
       yarn --version > /dev/null 2>&1
     fi
   else
     echo "yarn is installed."
     yarn --version > /dev/null 2>&1
   fi
   ```

4. Check/Install pnpm (optional):
   ```bash
   echo "Checking pnpm..."
   if ! command -v pnpm &> /dev/null; then
     echo "pnpm not found. Installing pnpm globally..."
     npm install -g pnpm > /dev/null 2>&1
     if [ $? -ne 0 ]; then
       echo "WARNING: Failed to install pnpm. Continuing with npm."
     else
       echo "pnpm installed successfully."
       pnpm --version > /dev/null 2>&1
     fi
   else
     echo "pnpm is installed."
     pnpm --version > /dev/null 2>&1
   fi
   ```

5. Verify installations:
   ```bash
   echo "=== Tool Verification ==="
    echo "Node.js version: $(node --version 2>/dev/null || \
      echo 'Not installed')"
    echo "npm version: $(npm --version 2>/dev/null || \
      echo 'Not installed')"
    echo "nvm version: $(nvm --version 2>/dev/null || \
      echo 'Not installed')"
    echo "yarn version: $(yarn --version 2>/dev/null || \
      echo 'Not installed')"
    echo "pnpm version: $(pnpm --version 2>/dev/null || \
      echo 'Not installed')"
   echo "========================"
   ```

Output format:
- Status of each tool (Installed/Updated/Failed/Skipped)
- Version information for installed tools
- Any manual intervention required
- Recommendations for project-specific package manager
