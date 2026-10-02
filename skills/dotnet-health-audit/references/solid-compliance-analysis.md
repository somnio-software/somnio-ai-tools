# .NET Health Audit SOLID Compliance Analysis

> Analyze the solution for SOLID principle adherence (SRP, OCP, LSP, ISP, DIP) and measure real cyclomatic complexity/coupling via a forced analyzer build, at the project-wide level.

---

Goal: Assess how consistently the solution follows the five SOLID principles and
measure real cyclomatic complexity/class coupling to produce a SOLID Compliance
score that feeds into the Architecture section of the final report.

STANDARDS SOURCE (local-first, then live):
- local: `agent-rules/rules/dotnet/solid-principles.md`
  raw:   https://raw.githubusercontent.com/somnio-software/somnio-ai-tools/main/agent-rules/rules/dotnet/solid-principles.md

RESOLUTION ORDER (per rule, never assume the file is on disk):
1. If `agent-rules/` exists in the repo, USE the `Read` tool on the local path above.
2. If `agent-rules/` is absent (standalone install), USE the `WebFetch` tool on the matching raw URL.

EFFICIENCY REQUIREMENTS:
- Target: ≤ 10 total tool calls for this entire analysis
- Batch grep across the whole solution for each heuristic instead of scanning
  file-by-file or project-by-project
- Reuse file-size and layering findings already produced by the
  repository-inventory step rather than re-deriving them
- Run the forced-analyzer build exactly once for the whole solution (step 6),
  not once per project

1. SINGLE RESPONSIBILITY PRINCIPLE (SRP):
   - Grep constructor parameter lists for classes with 6+ constructor-injected
     dependencies (God Object smell) — a rough proxy: count comma-separated
     parameters in `public ClassName(...)` constructors
   - Flag methods over ~50 lines that visibly mix input validation, I/O
     (HTTP/DB/file/queue calls), and business-rule branching in the same method
     body
   - Flag `*Manager`, `*Helper`, or `*Utility` classes that have accumulated 10+
     unrelated public methods — these names are frequently a symptom of a class
     with no single, nameable responsibility
   - Report count of offending classes/methods and the top offenders by name

2. OPEN/CLOSED PRINCIPLE (OCP):
   - Grep for `switch` statements/expressions and `if-else if` chains that
     branch on an `enum` value or a type discriminator (e.g. `order.Status`,
     `payment.Type`) and contain business logic (not just simple mapping/DTO
     projection)
   - For each discriminator found, search the rest of the solution for another
     `switch`/`if-else if` chain branching on the SAME enum/discriminator —
     duplication across two or more locations is the actual OCP violation
     signal (adding a new case requires touching multiple places instead of
     one polymorphic extension point)
   - Report count of duplicated discriminator chains and the files involved

3. LISKOV SUBSTITUTION PRINCIPLE (LSP):
   - Grep overridden interface/base-class members (`override`, explicit
     interface implementations) for bodies that throw `NotImplementedException`
     or `NotSupportedException`
   - This is a strong LSP violation signal: a subtype/implementation that
     cannot be substituted for its base/interface without breaking caller
     expectations
   - Report count and the files/types involved

4. INTERFACE SEGREGATION PRINCIPLE (ISP):
   - Flag interfaces with 8+ members where at least one implementation throws
     `NotImplementedException`/`NotSupportedException` for a subset of those
     members (fat interface forcing partial implementation)
   - Flag interfaces with 8+ members where call-site usage (grep for the
     interface type at injection points) shows most consumers only ever call
     1-2 of the available members — a signal the interface should be split by
     client-specific usage
   - Report count of offending interfaces and their member counts

5. DEPENDENCY INVERSION PRINCIPLE (DIP):
   - Grep for `new ConcreteServiceClass()` / `new ConcreteRepositoryClass()`
     instantiated inside another class's method or field initializer (not in
     `Program.cs`/composition-root/factory code, which legitimately constructs
     concrete types)
   - For each hit, check whether an interface for that same concern already
     exists elsewhere in the solution and IS used via DI in other classes —
     this "abstraction exists but isn't used here" pattern is the concrete,
     detectable DIP violation (as opposed to a general preference for
     interfaces)
   - EXCLUDE false positives: `new` of DTOs, value objects, records, POCOs,
     exceptions, and framework/BCL collections (`List<T>`, `Dictionary<K,V>`,
     `HttpClient` behind a factory, etc.) — these are normal object
     construction, not DIP violations
   - Report count of genuine hits and the files involved

6. CYCLOMATIC COMPLEXITY & COUPLING (forced analyzer build):
   - This requires actually compiling the code — grep cannot detect true
     cyclomatic complexity. Run a build with analyzers forced on for THIS
     audit run only, regardless of what the target repo's own `.csproj` /
     `Directory.Build.props` / `.editorconfig` currently enable:
     ```
     dotnet build <solution-or-project> -p:EnableNETAnalyzers=true -p:AnalysisLevel=latest-all -p:AnalysisMode=All --no-restore 2>&1 | grep -E "CA1502|CA1506"
     ```
     (use `findstr` in place of `grep` if running in a Windows shell without a
     POSIX grep available)
   - This ONLY overrides MSBuild properties on the command line for this one
     build invocation — it does NOT modify any file in the repo (no `.csproj`,
     `Directory.Build.props`, or `.editorconfig` is touched or persisted); it
     purely forces the built-in .NET analyzers to run and report for this
     audit even if the repo normally ships with them off or suppressed
   - Parse **CA1502** (excessive cyclomatic complexity, default threshold 25)
     hits: extract the file:line and method name from each warning
   - Parse **CA1506** (excessive class coupling) hits: extract the file:line
     and class name from each warning
   - Cross-reference both against file-size findings already produced by the
     repository-inventory step — large files are corroborating evidence of
     complexity risk, not a substitute for these real, measured hits
   - Report the total count of each rule's hits and the specific
     methods/classes flagged

7. ARCHITECTURE PATTERN CROSS-CHECK:
   - The repository-inventory step already classifies the solution's
     architecture pattern (Clean/Onion, Layered, Vertical Slice, or Flat) — do
     NOT re-classify it here
   - This step's job is to check whether SOLID principles are actually being
     followed WITHIN whichever pattern is in use, not whether the pattern
     itself is well-chosen
   - A codebase can have clean, well-separated folders/projects at the
     architecture level and still be riddled with SOLID violations inside
     those boundaries — e.g. a Vertical Slice codebase with `new
     ConcreteRepository()` scattered inside feature-folder handlers is still a
     SOLID problem even though the folder-level slicing looks fine
   - Note explicitly in the output whether SOLID violations are concentrated
     in specific layers/slices or spread evenly across the codebase

OUTPUT FORMAT:

Provide structured analysis:
- SRP violations: [count] (top offenders: [class/method names])
- OCP violations: [count] (files: [list of duplicated discriminator chains])
- LSP violations: [count] (files: [list])
- ISP violations: [count] (files: [list of fat interfaces])
- DIP violations: [count] (files: [list])
- CA1502 hits (excessive cyclomatic complexity): [count] (methods: [file:line list])
- CA1506 hits (excessive class coupling): [count] (classes: [file:line list])
- Architecture pattern cross-check: [violations concentrated in specific
  layers/slices, or spread evenly — reference the pattern from
  repository-inventory]
- Overall SOLID compliance assessment
- Risks identified
- Recommendations

SCORING GUIDANCE:

This score feeds into the **Architecture** section of the final report — it is
not reported as a standalone section.

Strong (85-100):
- Zero or near-zero SRP violations (no 6+-dependency constructors, no
  10+-method Manager/Helper/Utility classes)
- No duplicated switch/if-else discriminator chains for the same enum/type
  across the codebase (OCP respected)
- Zero LSP violations (no `NotImplementedException`/`NotSupportedException`
  in overridden members)
- No fat interfaces forcing partial implementation (ISP respected)
- Zero or isolated DIP violations, and an existing abstraction is used
  consistently where one exists
- CA1502/CA1506 hits are zero or a small handful, none in critical paths
- SOLID violations, where any exist, are isolated rather than systemic across
  the architecture pattern in use

Fair (70-84):
- A small number of SRP violations (a few oversized constructors or
  Manager/Helper classes) not yet widespread
- One or two duplicated discriminator chains (OCP), not repeated throughout
- Isolated LSP violations (one or two `NotImplementedException` overrides)
- One or two fat interfaces with partial implementations
- A handful of DIP violations where DI is used elsewhere for the same concern
- A moderate number of CA1502/CA1506 hits, mostly in non-critical code
- Violations are scattered rather than concentrated, but not negligible

Weak (0-69):
- Multiple SRP violations (God Object constructors, bloated Manager/Helper/
  Utility classes) recurring across the codebase
- Duplicated discriminator switch/if-else chains for the same enum/type
  appearing in three or more places (OCP systemically violated)
- Multiple LSP violations (overrides throwing `NotImplementedException`/
  `NotSupportedException`)
- Multiple fat interfaces with partial/throwing implementations (ISP
  systemically violated)
- Multiple DIP violations where an existing abstraction is bypassed in favor
  of direct instantiation
- CA1502/CA1506 hits are numerous, including in controllers/services on
  critical request paths
- SOLID violations are concentrated and systemic within the architecture
  pattern in use, not isolated incidents
