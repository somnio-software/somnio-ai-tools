# .NET Health Audit Code Quality Analysis

> Analyze Roslyn analyzer configuration, warning enforcement, .editorconfig rules, nullable reference type hygiene, and async anti-patterns for ASP.NET Core Web API projects.

---

Goal: Assess static analysis tooling, compiler-enforced quality gates, nullable reference type
discipline, and dangerous async-over-sync patterns to produce a Code Quality health score.

EFFICIENCY REQUIREMENTS:
- Target: ≤ 8 total tool calls for this entire analysis
- Read all `.csproj` files and `Directory.Build.props` in one parallel batch
- Use batch grep across the whole solution for `.Result`, `.Wait()`, and null-forgiving `!` usage
  instead of scanning file-by-file
- Reuse file-size and nullable-config findings already produced by repository-inventory and
  config-analysis steps rather than re-deriving them

1. ROSLYN ANALYZERS:
   - Check for `<EnableNETAnalyzers>true</EnableNETAnalyzers>` in `.csproj` or
     `Directory.Build.props` (built into the .NET SDK since .NET 5; on by default for SDK-style
     projects targeting net5.0+, so also check it hasn't been explicitly disabled)
   - Check `<AnalysisLevel>` value (e.g. `latest`, `8.0`, `latest-recommended`,
     `latest-all`) — `latest-recommended` or higher is a positive signal
   - Check for `<AnalysisMode>` (`All`, `Recommended`, `Minimum`) — `All` or `Recommended` is
     stronger than `Minimum`
   - Check for a `StyleCop.Analyzers` `PackageReference` (style/formatting rule enforcement at
     compile time)
   - Check for other custom Roslyn analyzer packages (e.g. `Roslynator.Analyzers`,
     `Meziantou.Analyzer`, `SonarAnalyzer.CSharp`)

2. TREATWARNINGSASERRORS:
   - Check for `<TreatWarningsAsErrors>true</TreatWarningsAsErrors>` in `.csproj` or
     `Directory.Build.props` — a strong positive signal that analyzer/compiler warnings can't
     silently accumulate
   - If not solution-wide, check for `<WarningsAsErrors>` scoped to specific rule IDs (partial
     enforcement — weaker than blanket `TreatWarningsAsErrors` but still a positive signal)
   - Check for `<NoWarn>` entries suppressing specific warnings — note any suspiciously broad
     suppression lists (e.g. suppressing CS8600-series nullable warnings wholesale)

3. .EDITORCONFIG SEVERITY RULES:
   - Check for a root `.editorconfig` (`root = true`)
   - Check for `dotnet_analyzer_diagnostic.severity` and rule-specific
     `dotnet_diagnostic.<RuleID>.severity` entries (e.g. `dotnet_diagnostic.CA1062.severity = error`)
   - Check for C# formatting conventions: `csharp_new_line_before_open_brace`,
     `csharp_prefer_braces`, `csharp_style_var_for_built_in_types`,
     `indent_style`/`indent_size`
   - Check for naming convention rules (`dotnet_naming_rule.*`) enforcing PascalCase for public
     members, `_camelCase` for private fields, etc.

4. NULLABLE REFERENCE TYPES COMPLIANCE:
   - Cross-reference whether `<Nullable>enable</Nullable>` is set (from config-analysis step); if
     not enabled, skip forgiving-operator analysis and flag nullable as entirely unadopted
   - If enabled, grep for the null-forgiving operator (`!`) usage across `.cs` files (excluding
     `!=` and `!` as logical negation — look specifically for `identifier!` / `)!` / `]!` patterns
     immediately before `.`, `;`, `,`, or `)`)
   - A high count of `!` suppressions relative to file count signals nullable is being "fought"
     (silencing warnings) rather than embraced (fixing the underlying null-flow) — report the
     rough count and flag as a risk if it's pervasive
   - Note any `#nullable disable` pragma blocks reintroducing oblivious context inside an
     otherwise nullable-enabled project

5. DOTNET FORMAT:
   - Cross-reference the cicd-analysis step: is `dotnet format --verify-no-changes` (or
     `dotnet format whitespace --verify-no-changes` / `dotnet format style --verify-no-changes`)
     run in CI?
   - If not found in CI, check for a documented local workflow (README, CONTRIBUTING.md, or a
     `dotnet format` pre-commit hook) as a partial substitute
   - If neither CI enforcement nor a documented local workflow exists, flag formatting as
     unenforced

6. CYCLOMATIC COMPLEXITY / FILE SIZE:
   - Real cyclomatic complexity measurement (CA1502/CA1506, forced on for this audit run
     regardless of the target repo's own analyzer settings) is now owned by
     `references/solid-compliance-analysis.md` — pull its complexity findings into this section's
     Key Findings/Counts & Metrics rather than re-measuring here. This section only checks whether
     the repo's OWN `.csproj`/`.editorconfig` has these rules enabled/enforced day-to-day (a
     tooling-maturity signal), which is a different question from "how complex is the code right
     now" answered by the dedicated step.
   - Reuse file-size findings from the repository-inventory step if available (large `.cs` files,
     especially controllers/services) as corroborating evidence alongside the complexity numbers

7. ASYNC-OVER-SYNC ANTI-PATTERNS:
   - Grep the entire solution (excluding `Main`/`Program.cs` top-level statements, which
     legitimately block via `.GetAwaiter().GetResult()` or synchronous `Main`) for:
     * `.Result` accessed on a `Task<T>` or `ValueTask<T>`
     * `.Wait()` or `.WaitAll()`/`.WaitAny()` called on a `Task`
     * `.GetAwaiter().GetResult()` outside of entry-point/bootstrap code
   - This is a genuine deadlock risk in ASP.NET Core (blocking a request thread waiting on a task
     that needs the same synchronization context/thread-pool slot to complete) — FLAG PROMINENTLY
     as a risk, not just a style note, whenever found in controllers, services, middleware, or
     filters
   - Report the count and the specific file list so each occurrence can be reviewed

OUTPUT FORMAT:

Provide structured analysis:
- Analyzers enabled: [list — EnableNETAnalyzers/AnalysisLevel/StyleCop.Analyzers/other]
- TreatWarningsAsErrors: [Yes/No/Partial (specific rule IDs)]
- .editorconfig severity rules present: [Yes/No] (naming rules: [Yes/No])
- Nullable Reference Types compliance: [Enabled solution-wide/Enabled partially/Not enabled]
- Null-forgiving operator (`!`) count: [approximate number] ([Low/Moderate/High] relative to file count)
- `dotnet format` enforcement: [CI-enforced/Documented locally/Unenforced]
- Sync-over-async anti-pattern hits: [count] (files: [list])
- Risks identified
- Recommendations

SCORING GUIDANCE:

Strong (85-100):
- Roslyn analyzers enabled with `AnalysisLevel` at `latest`/`latest-recommended` or higher, plus
  `TreatWarningsAsErrors` set solution-wide
- `.editorconfig` present with rule-specific severities and naming conventions enforced
- Nullable Reference Types enabled solution-wide with low null-forgiving operator usage
- `dotnet format --verify-no-changes` enforced in CI
- Zero sync-over-async anti-pattern hits (`.Result`/`.Wait()`/`.GetAwaiter().GetResult()`) outside
  bootstrap code

Fair (70-84):
- Analyzers enabled but at a lower `AnalysisLevel`/`AnalysisMode`, or `TreatWarningsAsErrors` only
  partially applied via `WarningsAsErrors` for specific rules
- `.editorconfig` present but with few or no severity overrides (relying on defaults)
- Nullable Reference Types enabled but with a moderate number of null-forgiving operators, or
  enabled only in some projects
- `dotnet format` documented locally but not enforced in CI
- A small number of isolated sync-over-async hits, not in hot request paths

Weak (0-69):
- Roslyn analyzers not enabled, or explicitly disabled; no `TreatWarningsAsErrors`
- No `.editorconfig`, or one present with no meaningful severity/naming rules
- Nullable Reference Types not enabled, or enabled with pervasive null-forgiving operator usage
  indicating the feature is being suppressed rather than used
- No formatting enforcement anywhere (CI or documented)
- Multiple sync-over-async anti-pattern hits in controllers/services — a genuine deadlock risk
