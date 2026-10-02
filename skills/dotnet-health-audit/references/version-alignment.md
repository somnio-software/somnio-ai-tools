# .NET Health Audit Version Alignment

> SDK version alignment requirement for any ASP.NET Core Web API project analysis (single project or multi-project solution). Ensures the installed .NET SDK matches — or is compatible with — the repo's `global.json` pin and each project's `TargetFramework`.

---

Goal: Align the installed .NET SDK with what the repository requires
via `global.json` (the .NET analogue of `.nvmrc`/nvm), and confirm
`TargetFramework` consistency across every project in the solution.

STEP 0 — RUN THIS BEFORE ANY OTHER ANALYSIS STEP.

IMPORTANT — HOW THIS DIFFERS FROM THE NODE.JS/NESTJS AND REACT AUDITS:

In the Node.js-based audits, nvm + `.nvmrc` alignment is a **hard,
blocking, MANDATORY gate** — if the exact Node.js version cannot be
configured, execution STOPS, because Node.js has no cross-version
compatibility guarantee.

.NET SDKs do NOT have this problem: any installed SDK whose major
version is >= the project's `TargetFramework` version can build and run
older-`TargetFramework` projects (the SDK is backward compatible: an
SDK 8.x can build a `net6.0` project just fine). Because of this,
**SDK alignment in this audit is a strong recommendation with graceful
degradation, NOT a hard blocking gate.** If the pinned SDK cannot be
installed, the audit CONTINUES using the closest compatible SDK
already present, and simply documents the deviation. This is a
deliberate, explicit difference from the React/NestJS skills — do not
treat a missing exact-version match as a stop condition here.

The only genuinely execution-stopping condition in this file is a
**failed `dotnet restore`** at the end (see step 5) — a broken restore
means the solution literally cannot build, which is not something
graceful degradation can paper over.

EXECUTION STEPS:

1. **Detect `global.json`**:
   ```bash
   echo "Checking for global.json..."
   if [ -f "global.json" ]; then
     echo "global.json found:"
     cat global.json
     PINNED_SDK=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' global.json | sed 's/.*"\(.*\)"$/\1/')
     ROLL_FORWARD=$(grep -o '"rollForward"[[:space:]]*:[[:space:]]*"[^"]*"' global.json | sed 's/.*"\(.*\)"$/\1/')
     echo "Pinned SDK version: ${PINNED_SDK:-none}"
     echo "rollForward policy: ${ROLL_FORWARD:-not specified (defaults to 'latestPatch' behavior)}"
   else
     echo "No global.json found."
     PINNED_SDK=""
   fi
   ```

2. **Graceful fallback when no `global.json` exists**:
   - If no `global.json` is present, this is NOT a failure. Note in the
     report: "No SDK pin found (no global.json) — using the latest
     installed SDK compatible with the lowest `TargetFramework` found
     across .csproj files."
   - Proceed to step 3 to discover the actual `TargetFramework` floor
     from the .csproj files instead.

3. **Detect all `TargetFramework`/`TargetFrameworks` values across the solution**:
   ```bash
   echo "Scanning for TargetFramework(s) across all .csproj files..."
   find . -name "*.csproj" -not -path "*/bin/*" -not -path "*/obj/*" | while read -r proj; do
     tfm=$(grep -oE "<TargetFrameworks?>[^<]*</TargetFrameworks?>" "$proj" | sed -E 's/<[^>]*>//g')
     echo "$proj -> ${tfm:-NOT FOUND}"
   done
   ```
   - Collect the distinct set of TargetFramework values found (e.g.
     `net6.0`, `net8.0`, `net9.0`).
   - **Flag inconsistency as a real risk**: if more than one distinct
     TFM appears across projects in the same solution (e.g. one project
     on `net6.0`, another on `net8.0`), this is a genuine finding —
     it risks divergent language features, API surface, and subtle
     runtime behavior differences between projects that are supposed
     to interoperate. Report it even though it is not a blocking error.

4. **Check current SDK vs requirement**:
   ```bash
   echo "Current dotnet SDK: $(dotnet --version 2>/dev/null || echo 'none')"
   echo "All installed SDKs:"
   dotnet --list-sdks 2>/dev/null || echo "none"
   ```
   - If `global.json` specifies a version: compare against `dotnet --list-sdks`.
   - If the pinned SDK is present: alignment already satisfied, continue.
   - If the pinned SDK is absent: proceed to step 5 to install it,
     respecting `rollForward`.
   - If no `global.json`: confirm the currently active SDK's major
     version is >= the highest TargetFramework major version detected
     in step 3 (e.g. an active SDK 8.x can serve a `net8.0` project;
     it cannot serve a `net9.0` project). Note any shortfall.

5. **Install the pinned SDK if missing** (same dotnet-install mechanism as `@dotnet_tool_installer`, respecting `rollForward`):
   ```bash
   if [ -n "$PINNED_SDK" ] && ! dotnet --list-sdks 2>/dev/null | grep -q "^$PINNED_SDK "; then
     echo "Pinned SDK $PINNED_SDK not installed. Installing..."
     if [[ "$OSTYPE" == "darwin"* ]] || [[ "$OSTYPE" == "linux-gnu"* ]]; then
       curl -sSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh
       chmod +x /tmp/dotnet-install.sh
       /tmp/dotnet-install.sh --version "$PINNED_SDK" --install-dir "$HOME/.dotnet"
       export PATH="$HOME/.dotnet:$PATH"
       if dotnet --list-sdks 2>/dev/null | grep -q "^$PINNED_SDK "; then
         echo "SDK $PINNED_SDK installed successfully."
       else
         echo "WARNING: Could not install exact pinned SDK $PINNED_SDK."
         echo "Proceeding with graceful degradation using closest compatible installed SDK: $(dotnet --version)"
       fi
     else
       echo "Windows detected — install manually or via PowerShell dotnet-install.ps1:"
       echo "  ./dotnet-install.ps1 -Version $PINNED_SDK"
       echo "Proceeding with graceful degradation using closest compatible installed SDK: $(dotnet --version)"
     fi
   else
     echo "SDK requirement already satisfied (or no pin present)."
   fi
   ```
   - Failure to install the exact pinned SDK is logged as a
     **recommendation, not a stop condition**: document it, fall back
     to the closest compatible installed SDK, and continue.

6. **Restore the full solution — THIS check IS execution-stopping on failure**:
   ```bash
   echo "Restoring solution..."
   SLN_FILE=$(find . -maxdepth 2 -name "*.sln" | head -1)
   if [ -n "$SLN_FILE" ]; then
     echo "Found solution file: $SLN_FILE"
     dotnet restore "$SLN_FILE" 2>&1 | tail -50
   else
     echo "No .sln found — restoring from repo root."
     dotnet restore 2>&1 | tail -50
   fi
   RESTORE_EXIT=$?
   if [ $RESTORE_EXIT -ne 0 ]; then
     echo "RESTORE FAILED — this IS a legitimate execution-stopping issue."
     echo "Resolution steps to document in the report:"
     echo "  1. Check NuGet.config for correct/reachable package feeds."
     echo "  2. Confirm network/proxy access to nuget.org or the private feed."
     echo "  3. Check for version conflicts between PackageReference entries"
     echo "     and any Directory.Packages.props (see @dotnet_version_validator)."
     echo "  4. Re-run: dotnet restore --verbosity detailed"
     echo "  5. Clear NuGet caches if corruption is suspected: dotnet nuget locals all --clear"
   else
     echo "Restore succeeded."
   fi
   ```

WHY THIS IS CRITICAL (even though it is not a hard blocking gate):
- Prevents subtly wrong analysis: an SDK too old for the highest
  TargetFramework in the solution cannot build that project at all.
- Surfaces genuine cross-project TargetFramework drift, which is a
  real maintainability and behavior-consistency risk even though .NET
  itself tolerates it at the SDK level.
- A failed restore is the one condition in this file that must stop
  execution, since no amount of graceful degradation fixes a solution
  that cannot resolve its own dependencies.

OUTPUT FORMAT:

Provide structured output:
- SDK version required: [from global.json, e.g. "8.0.404"] or "not pinned (no global.json)"
- rollForward policy: [value] or "not specified"
- SDK version(s) actually installed/active: [list]
- Alignment result: [Exact match / Compatible (graceful degradation) / Incompatible — document why]
- TargetFramework(s) detected per project: [table of project -> TFM]
- Cross-project TargetFramework consistency verdict: [Consistent / Inconsistent — list mismatched projects]
- Solution restore status: [Success / Failed — with resolution steps]
- Recommendations (e.g. "pin global.json to avoid SDK drift across environments", "align net6.0 project X to net8.0 to match the rest of the solution")
