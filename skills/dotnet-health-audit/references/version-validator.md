# .NET Health Audit Version Validator

> Verify the outcome of tool-installer and version-alignment with a clean solution-level build sanity check, including Central Package Management consistency.

---

Goal: Confirm the SDK/tooling from `@dotnet_tool_installer` and
`@dotnet_version_alignment` actually produce a working build — not
just a successful restore — before deeper code analysis steps run on
top of it.

EFFICIENCY REQUIREMENTS:
- Target: ≤ 6 total tool calls for this validation
- Reuse the restore already performed by `@dotnet_version_alignment` — do NOT restore twice; pass `--no-restore` to `dotnet build`
- Pipe build output through `tail` — full MSBuild output floods the context window; only the summary (Build succeeded/failed, warning/error counts) is needed
- Do NOT open individual source files to investigate build errors here — capture the error list and hand it off in the report; deeper analysis belongs to later audit steps

VALIDATION CHECKS:

1. **Confirm SDK version matches (or is compatible with) the `global.json` pin**:
   ```bash
   echo "Active SDK: $(dotnet --version 2>/dev/null || echo 'none')"
   if [ -f "global.json" ]; then
     PINNED_SDK=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' global.json | sed 's/.*"\(.*\)"$/\1/')
     echo "Pinned SDK (global.json): $PINNED_SDK"
     if [ "$(dotnet --version)" = "$PINNED_SDK" ]; then
       echo "✓ Exact match"
     else
       echo "! Active SDK differs from pin — verify this is acceptable per @dotnet_version_alignment graceful degradation rules"
     fi
   else
     echo "! No global.json — no exact pin to compare against"
   fi
   ```

2. **Solution-level build (no restore — reuse the one from version-alignment)**:
   ```bash
   SLN_FILE=$(find . -maxdepth 2 -name "*.sln" | head -1)
   echo "Building..."
   if [ -n "$SLN_FILE" ]; then
     dotnet build "$SLN_FILE" --no-restore --nologo 2>&1 | tail -100
   else
     dotnet build --no-restore --nologo 2>&1 | tail -100
   fi
   BUILD_EXIT=$?
   ```
   - Capture the final summary line(s) MSBuild prints
     (`Build succeeded.` / `Build FAILED.` and the
     `X Warning(s)` / `Y Error(s)` counts).
   - If `$BUILD_EXIT` is non-zero: treat as Failed, capture the list
     of `error CS####`/`error MSB####` lines for the report (grep for
     `: error ` in the captured output).

3. **Extract and count warnings**:
   ```bash
   echo "Warning summary:"
   if [ -n "$SLN_FILE" ]; then
     dotnet build "$SLN_FILE" --no-restore --nologo 2>&1 | grep -c ": warning "
   else
     dotnet build --no-restore --nologo 2>&1 | grep -c ": warning "
   fi
   ```
   (In practice, capture this from the same build invocation as step 2
   rather than rebuilding — rebuilding is only shown here separately
   for clarity of what to grep for.)

4. **Verify all project references resolve (no missing project reference errors)**:
   ```bash
   echo "Checking for project reference errors..."
   BUILD_LOG=$(dotnet build "$SLN_FILE" --no-restore --nologo 2>&1)
   echo "$BUILD_LOG" | grep -iE "MSB3073|MSB3202|MSB4057|unable to find project|project file .* was not found" || \
     echo "No project reference resolution errors found."
   ```

5. **Central Package Management (CPM) consistency check**:
   ```bash
   echo "Checking for Directory.Packages.props (Central Package Management)..."
   if [ -f "Directory.Packages.props" ] && grep -q "ManagePackageVersionsCentrally" Directory.Packages.props && grep -qi "<ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>" Directory.Packages.props; then
     echo "CPM is enabled."
     echo "Checking individual .csproj files for conflicting Version= attributes on PackageReference..."
     CONFLICTS=$(find . -name "*.csproj" -not -path "*/bin/*" -not -path "*/obj/*" | xargs grep -lE '<PackageReference[^>]*\sVersion=' 2>/dev/null)
     if [ -n "$CONFLICTS" ]; then
       echo "! CONFLICT: the following .csproj files specify Version= on PackageReference while CPM is enabled:"
       echo "$CONFLICTS"
       echo "  This is invalid — under CPM, versions must live ONLY in Directory.Packages.props."
     else
       echo "✓ No conflicting per-project Version= attributes found — CPM usage is clean."
     fi
   else
     echo "CPM not detected (no Directory.Packages.props with ManagePackageVersionsCentrally=true) — per-project PackageReference versions are expected and normal."
   fi
   ```

OUTPUT FORMAT:

Provide structured output:
- Active SDK vs `global.json` pin: [Exact match / Compatible (graceful degradation) / No pin present]
- Build status: [Success / Success with Warnings / Failed]
- Warning count: [N]
- Error count: [N] (with the first several `error CS####`/`error MSB####` lines if failed)
- Project reference errors: [None found / List of unresolved references]
- Central Package Management detected: [Yes / No]
- CPM conflict check: [Clean / Conflicts found — list files] / [N/A — CPM not in use]
- Overall verdict: [Ready for analysis / Blocked — build must be fixed first, with resolution steps]
