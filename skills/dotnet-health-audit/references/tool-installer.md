# .NET Health Audit Tool Installer

> Centralized installer for the .NET SDK and companion CLI tools (dotnet-ef, dotnet-outdated-tool, dotnet-reportgenerator-globaltool) required by the ASP.NET Core Web API health audit.

---

Goal: Verify required tools are present and properly configured. Only
install tools that are genuinely missing — never reinstall tools that
are already available.

INSTALLATION PHILOSOPHY:
- CHECK FIRST: Always verify if a tool is already installed before attempting installation
- CONFIGURE, DON'T REINSTALL: If the SDK or a global tool exists, use it — do not reinstall
- MINIMAL CHANGES: Only install what is genuinely missing
- VERSION PRESERVATION: Do not change the active SDK version unless required by the version-alignment step (that step owns SDK-pin enforcement; this step only ensures *a* working SDK and toolset exist)
- IDEMPOTENT: Running this installer multiple times must produce the same result without side effects

EFFICIENCY REQUIREMENTS:
- Target: ≤ 8 total tool calls for this entire installer
- Batch the SDK/tool detection commands into as few shell invocations as possible (chain with `&&`/`;` inside one call rather than one call per check)
- Do NOT enumerate or read individual source files here — this step only touches SDK/tool state and top-level project files
- Only run the dotnet-install script or `dotnet tool install` when the preceding check proves the tool is actually missing

TOOLS TO INSTALL:
1. .NET SDK (version-agnostic baseline check — exact pin is enforced by `@dotnet_version_alignment`)
2. `dotnet-ef` (only if the project uses EF Core)
3. `dotnet-outdated-tool` (outdated package detection, used later in the audit)
4. `dotnet-reportgenerator-globaltool` (coverage report merging, used by `@dotnet_test_coverage`)

EXECUTION STEPS:

1. Check for an installed .NET SDK:
   ```bash
   echo "Checking .NET SDK..."
   if command -v dotnet &> /dev/null; then
     echo "dotnet CLI found: $(dotnet --version 2>/dev/null)"
     echo "Installed SDKs:"
     dotnet --list-sdks
   else
     echo "dotnet CLI not found."
   fi
   ```

2. Install the .NET SDK only if missing (via the official dotnet-install script):
   ```bash
   if ! command -v dotnet &> /dev/null; then
     echo "No .NET SDK found. Installing latest LTS SDK..."
     if [[ "$OSTYPE" == "darwin"* ]] || [[ "$OSTYPE" == "linux-gnu"* ]]; then
       curl -sSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh
       chmod +x /tmp/dotnet-install.sh
       /tmp/dotnet-install.sh --channel LTS --install-dir "$HOME/.dotnet"
       export PATH="$HOME/.dotnet:$PATH"
       if ! command -v dotnet &> /dev/null; then
         echo "ERROR: Failed to install .NET SDK via dotnet-install.sh."
         echo "Please install manually: https://dotnet.microsoft.com/download"
         exit 1
       fi
       echo ".NET SDK installed successfully: $(dotnet --version)"
     elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
       echo "Windows detected — run in PowerShell:"
       echo '  Invoke-WebRequest https://dot.net/v1/dotnet-install.ps1 -OutFile dotnet-install.ps1'
       echo '  ./dotnet-install.ps1 -Channel LTS'
       exit 1
     else
       echo "ERROR: Unsupported OS for automatic SDK installation."
       echo "Please install manually: https://dotnet.microsoft.com/download"
       exit 1
     fi
   else
     echo ".NET SDK is already installed and configured."
   fi
   ```
   Note: if `global.json` pins a *specific* SDK version/channel, `@dotnet_version_alignment`
   (run immediately after this installer) is responsible for installing that exact
   version via the same dotnet-install mechanism with `--channel <version>` or
   `--version <version>`. This step only guarantees a baseline SDK exists so that
   `dotnet --list-sdks` and `global.json` parsing are possible in the first place.

3. Detect whether the project uses EF Core (determines whether `dotnet-ef` is needed):
   ```bash
   echo "Checking for EF Core usage..."
   if grep -rl "Microsoft.EntityFrameworkCore.Design" --include="*.csproj" . 2>/dev/null | head -1 > /dev/null; then
     echo "EF Core Design package found — dotnet-ef is required."
     EF_CORE_DETECTED=true
   else
     echo "No Microsoft.EntityFrameworkCore.Design reference found — skipping dotnet-ef."
     EF_CORE_DETECTED=false
   fi
   ```

4. Check/Install `dotnet-ef` (only if EF Core detected):
   ```bash
   if [ "$EF_CORE_DETECTED" = true ]; then
     if dotnet tool list -g 2>/dev/null | grep -q "dotnet-ef"; then
       echo "dotnet-ef is already installed globally."
       dotnet ef --version 2>/dev/null
     else
       echo "Installing dotnet-ef global tool..."
       dotnet tool install -g dotnet-ef > /dev/null 2>&1
       if [ $? -ne 0 ]; then
         echo "WARNING: Failed to install dotnet-ef. EF Core migration checks will be skipped."
       else
         echo "dotnet-ef installed successfully."
         dotnet ef --version 2>/dev/null
       fi
     fi
   else
     echo "Skipping dotnet-ef (no EF Core Design package reference detected)."
   fi
   ```

5. Check/Install `dotnet-outdated-tool` (used for outdated NuGet package detection later in the audit):
   ```bash
   echo "Checking dotnet-outdated-tool..."
   if dotnet tool list -g 2>/dev/null | grep -q "dotnet-outdated-tool"; then
     echo "dotnet-outdated-tool is already installed globally."
   else
     echo "Installing dotnet-outdated-tool..."
     dotnet tool install -g dotnet-outdated-tool > /dev/null 2>&1
     if [ $? -ne 0 ]; then
       echo "WARNING: Failed to install dotnet-outdated-tool. Outdated package detection will fall back to 'dotnet list package --outdated'."
     else
       echo "dotnet-outdated-tool installed successfully."
     fi
   fi
   ```

6. Check/Install `dotnet-reportgenerator-globaltool` (used to merge coverage reports across multiple test projects):
   ```bash
   echo "Checking dotnet-reportgenerator-globaltool..."
   if dotnet tool list -g 2>/dev/null | grep -q "dotnet-reportgenerator-globaltool"; then
     echo "reportgenerator is already installed globally."
   else
     echo "Installing dotnet-reportgenerator-globaltool..."
     dotnet tool install -g dotnet-reportgenerator-globaltool > /dev/null 2>&1
     if [ $? -ne 0 ]; then
       echo "WARNING: Failed to install reportgenerator. Multi-project coverage will be reported per-project instead of merged."
     else
       echo "reportgenerator installed successfully."
     fi
   fi
   ```

7. Verify NuGet restore works at the solution level:
   ```bash
   echo "Verifying NuGet restore..."
   SLN_FILE=$(find . -maxdepth 2 -name "*.sln" | head -1)
   if [ -n "$SLN_FILE" ]; then
     echo "Restoring solution: $SLN_FILE"
     dotnet restore "$SLN_FILE" 2>&1 | tail -30
   else
     echo "No .sln found at repo root — restoring from current directory."
     dotnet restore 2>&1 | tail -30
   fi
   RESTORE_STATUS=$?
   if [ $RESTORE_STATUS -ne 0 ]; then
     echo "WARNING: dotnet restore reported errors. This may indicate missing NuGet feeds, network issues, or version conflicts. See version-validator for a deeper build check."
   else
     echo "NuGet restore succeeded."
   fi
   ```

8. Verify installations:
   ```bash
   echo "=== Tool Verification ==="
   echo ".NET SDK version: $(dotnet --version 2>/dev/null || echo 'Not installed')"
   echo "Installed SDKs: $(dotnet --list-sdks 2>/dev/null | tr '\n' ';' || echo 'Not installed')"
   echo "dotnet-ef: $(dotnet ef --version 2>/dev/null || echo 'Not installed / not applicable')"
   echo "dotnet-outdated-tool: $(dotnet tool list -g 2>/dev/null | grep dotnet-outdated-tool || echo 'Not installed')"
   echo "reportgenerator: $(dotnet tool list -g 2>/dev/null | grep dotnet-reportgenerator-globaltool || echo 'Not installed')"
   echo "=========================="
   ```

OUTPUT FORMAT:

Provide structured output:
- .NET SDK status: [Already present / Installed / Failed]
- SDK version(s) found (full list from `dotnet --list-sdks`)
- `dotnet-ef` status: [Installed / Already present / Failed / Skipped — no EF Core detected]
- `dotnet-outdated-tool` status: [Installed / Already present / Failed]
- `dotnet-reportgenerator-globaltool` status: [Installed / Already present / Failed]
- Solution-level `dotnet restore` result: [Success / Failed — with error summary]
- Any manual intervention required (e.g. Windows PowerShell install steps, missing NuGet feed credentials)
- Recommendations for follow-up (e.g. "run `@dotnet_version_alignment` next to pin the exact SDK version from global.json")
