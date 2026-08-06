# .NET Health Audit Test Coverage Runner

> Execute the .NET test suite with Coverlet-based coverage collection, merge multi-project results, and extract line/branch coverage percentages for the final audit report.

---

Goal: Run `dotnet test` with code coverage collection, locate and
parse the resulting Cobertura XML, and emit a single machine-parsable
coverage line for `report-generator.md` to extract downstream.

EFFICIENCY REQUIREMENTS:
- Target: ≤ 6 total tool calls for this entire step
- Pipe all `dotnet test` output through `tail -100` — full test-runner
  output floods the context window; the authoritative coverage data
  lives in the generated `coverage.cobertura.xml` files on disk, not
  in stdout
- Locate coverage files with a single `find` pass, not one `find` per
  test project
- Do NOT open individual test source files to "count" tests — parse
  the `dotnet test` summary line and the Cobertura XML instead

EXECUTION STEPS:

1. **Detect test projects**:
   ```bash
   echo "Detecting test projects..."
   TEST_PROJECTS=$(find . -name "*.csproj" -not -path "*/bin/*" -not -path "*/obj/*" | xargs grep -lE "Microsoft.NET.Test.Sdk|xunit|nunit|MSTest.TestFramework" 2>/dev/null)
   if [ -z "$TEST_PROJECTS" ]; then
     echo "No test projects detected (no .csproj references a test SDK/framework)."
   else
     echo "Test projects found:"
     echo "$TEST_PROJECTS"
   fi
   ```

2. **Run tests with coverage collection** (Coverlet.Collector — the default in modern `dotnet new xunit`/`nunit`/`mstest` templates):
   ```bash
   if [ -n "$TEST_PROJECTS" ]; then
     SLN_FILE=$(find . -maxdepth 2 -name "*.sln" | head -1)
     echo "Running tests with coverage..."
     if [ -n "$SLN_FILE" ]; then
       dotnet test "$SLN_FILE" --no-restore --collect:"XPlat Code Coverage" \
         --results-directory ./TestResults 2>&1 | tail -100
     else
       dotnet test --no-restore --collect:"XPlat Code Coverage" \
         --results-directory ./TestResults 2>&1 | tail -100
     fi
   else
     echo "Skipping test execution — no test projects found."
   fi
   ```
   - If a test project lacks the `coverlet.collector` PackageReference,
     `--collect:"XPlat Code Coverage"` will silently produce no
     coverage file for that project — note this per-project in the
     report rather than failing the whole run.
   - If tests fail: note pass/fail/skip counts from the summary line
     but continue on to coverage parsing — partial coverage from
     passing tests is still useful signal.

3. **Locate generated Cobertura coverage files**:
   ```bash
   echo "Locating coverage files..."
   COVERAGE_FILES=$(find . -path "*/TestResults/*" -name "coverage.cobertura.xml" 2>/dev/null)
   if [ -z "$COVERAGE_FILES" ]; then
     echo "No coverage.cobertura.xml files found."
   else
     echo "Coverage files found:"
     echo "$COVERAGE_FILES"
   fi
   ```

4. **Merge multi-project coverage with `reportgenerator`** (only if more than one coverage file exists and `dotnet-reportgenerator-globaltool` was installed by `@dotnet_tool_installer`):
   ```bash
   NUM_COVERAGE_FILES=$(echo "$COVERAGE_FILES" | grep -c . || echo 0)
   if [ "$NUM_COVERAGE_FILES" -gt 1 ] && command -v reportgenerator &> /dev/null; then
     echo "Merging $NUM_COVERAGE_FILES coverage reports..."
     REPORTS_ARG=$(echo "$COVERAGE_FILES" | tr '\n' ';')
     reportgenerator \
       "-reports:${REPORTS_ARG}" \
       "-targetdir:./TestResults/CoverageReport" \
       "-reporttypes:Cobertura;TextSummary" 2>&1 | tail -30
     if [ -f "./TestResults/CoverageReport/Cobertura.xml" ]; then
       COVERAGE_FILES="./TestResults/CoverageReport/Cobertura.xml"
       echo "Merged report: ./TestResults/CoverageReport/Cobertura.xml"
     fi
   elif [ "$NUM_COVERAGE_FILES" -gt 1 ]; then
     echo "Multiple coverage files found but reportgenerator unavailable — will aggregate manually by summing line-rate weighted by lines-valid."
   fi
   ```

5. **Parse `line-rate` / `branch-rate` from the Cobertura XML** (multiply by 100 for a percentage):
   ```bash
   if [ -n "$COVERAGE_FILES" ]; then
     PRIMARY_COVERAGE_FILE=$(echo "$COVERAGE_FILES" | head -1)
     echo "Parsing: $PRIMARY_COVERAGE_FILE"
     LINE_RATE=$(grep -oE 'line-rate="[0-9.]+"' "$PRIMARY_COVERAGE_FILE" | head -1 | grep -oE '[0-9.]+')
     BRANCH_RATE=$(grep -oE 'branch-rate="[0-9.]+"' "$PRIMARY_COVERAGE_FILE" | head -1 | grep -oE '[0-9.]+')
     if [ -n "$LINE_RATE" ]; then
       LINE_PCT=$(awk "BEGIN { printf \"%.1f\", $LINE_RATE * 100 }")
     fi
     if [ -n "$BRANCH_RATE" ]; then
       BRANCH_PCT=$(awk "BEGIN { printf \"%.1f\", $BRANCH_RATE * 100 }")
     fi
     echo "Line coverage: ${LINE_PCT:-Unknown}%"
     echo "Branch coverage: ${BRANCH_PCT:-Unknown}%"
   else
     echo "No coverage data available to parse."
   fi
   ```

6. **Handle the no-test-projects case explicitly — do not fabricate a number**:
   ```bash
   if [ -z "$TEST_PROJECTS" ] || [ -z "$COVERAGE_FILES" ]; then
     echo "Code Coverage: Unknown — no test projects detected"
   fi
   ```

MANDATORY OUTPUT LINE:

Your final output MUST include, verbatim, exactly one line in this
format — this exact line is parsed by `report-generator.md`
downstream and must match precisely (mirroring how the React/NestJS
`test-coverage.md` produce a `Code Coverage:` line):

```
Code Coverage: XX% lines / XX% branches
```

- If no test projects were found, or no coverage file could be
  produced/parsed, emit instead:
  ```
  Code Coverage: Unknown — no test projects detected
  ```
  Never invent a percentage when no coverage data exists.

OUTPUT FORMAT:

Provide the following structured output:

1. EXECUTION SUMMARY
   - Test projects detected: [count and list, or "none"]
   - Test execution status: [Passed / Failed / Partial — with pass/fail/skip counts]
   - .NET SDK version used for execution

2. COVERAGE OVERVIEW
   - The mandatory `Code Coverage: XX% lines / XX% branches` line (or the Unknown variant)
   - Per-project line/branch coverage (if multiple test projects and no merge was possible)
   - Coverage report location(s) on disk (`TestResults/**/coverage.cobertura.xml`, merged `CoverageReport/Cobertura.xml` if generated)

3. GAPS AND RISKS
   - Test projects present but missing the `coverlet.collector` package (coverage silently unavailable)
   - Any project where `dotnet test` failed outright (coverage not obtainable)

4. RECOMMENDATIONS
   - Coverage threshold suggestions (align with the audit's general scoring bands: ≥80% strong, 60–79% fair, <60% weak)
   - Whether to add `dotnet-reportgenerator-globaltool` merging to CI if multiple test projects exist and are currently reported separately
