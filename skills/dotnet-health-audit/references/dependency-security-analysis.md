# .NET Health Audit Dependency & Security Analysis

> Analyze NuGet package vulnerabilities, outdated/deprecated dependencies, and package source hygiene for ASP.NET Core Web API projects.

---

Goal: Assess NuGet dependency risk — known vulnerabilities, outdated/unmaintained
packages, and package source configuration hygiene — to produce a dependency
health input for the Tech Stack score.

**Report integration**: This step's findings feed into the existing **Tech
Stack** section of the final report (alongside SDK version and
TargetFramework findings from `version-alignment.md`/`config-analysis.md`)
— it is NOT a new standalone report section. The report structure remains
the current 8 scored dimensions / 15 sections defined in
`references/report-generator.md`. For a deeper security review beyond
dependency scanning (secrets, auth, injection, transport security, etc.),
recommend the user run the standalone Security Audit (`/somnio:security-audit`)
— this step provides a solid first-pass dependency summary, not exhaustive
security coverage.

EFFICIENCY REQUIREMENTS:
- Target: ≤ 6 total tool calls for this entire analysis
- Do NOT re-run `dotnet restore` — reuse the restored state already
  established by `tool-installer.md`/`version-alignment.md`
- Run the vulnerable-package and outdated-package checks as two separate
  `dotnet list package` invocations (they use different flags), not more
- Reuse Central Package Management (`Directory.Packages.props`) detection
  from `config-analysis.md` rather than re-scanning for it

1. VULNERABLE PACKAGE DETECTION:
   - Find the solution file first: `find . -maxdepth 2 -name "*.sln" | head -1`
   - If a `.sln` is found, run:
     ```bash
     dotnet list <path-to-sln> package --vulnerable --include-transitive
     ```
   - If no `.sln` is found, run from the repo root instead:
     ```bash
     dotnet list package --vulnerable --include-transitive
     ```
   - Parse the output table for each project: package name, resolved
     version, severity (`Critical`/`High`/`Moderate`/`Low`), and the GHSA
     advisory ID/URL when NuGet prints one
   - Distinguish direct vs transitive vulnerable packages (the tool prints
     them in separate sub-lists per project) — transitive vulnerabilities
     are still real risk but harder to fix directly; they may require
     bumping the parent package or adding an explicit version override
   - If the command reports "The given project/solution has no
     vulnerable packages", record that explicitly as a clean result —
     do not skip the step or leave it blank

2. OUTDATED PACKAGE DETECTION:
   - Run:
     ```bash
     dotnet list <sln-or-csproj> package --outdated --include-transitive
     ```
     (fall back to `dotnet list package --outdated` for direct packages
     only, from the repo root, if no `.sln` is found)
   - If `dotnet-outdated-tool` was installed successfully by
     `tool-installer.md`, prefer running `dotnet outdated` instead for
     nicer, more actionable output (per-project major/minor/patch
     breakdown); otherwise use the `dotnet list package --outdated` result
   - Parse: package name, current (resolved) version, latest available
     version, and how many major versions behind it is (e.g. "3 major
     versions behind" is a materially bigger red flag than "1 minor
     version behind")
   - Flag packages that are outdated AND have a known deprecation/successor
     signal, e.g.:
     * `Newtonsoft.Json` where `System.Text.Json` is the modern
       framework-provided default
     * Large major-version jumps in `AutoMapper` /
       `AutoMapper.Extensions.Microsoft.DependencyInjection` (breaking
       license/API changes between majors)
     * Old standalone `Microsoft.AspNetCore.Http`-family packages that
       predate ASP.NET Core 3's shared-framework consolidation

3. SEVERITY-WEIGHTED RISK ASSESSMENT:
   - Critical/High severity vulnerabilities in DIRECT dependencies = the
     most urgent finding — surface these first, by name
   - Critical/High severity in TRANSITIVE dependencies = urgent, but
     identify a fix path: can it be resolved by bumping the direct parent
     package to a version that pulls a patched transitive version, or does
     it need an explicit override (`<PackageReference Update="..."
     VersionOverride="..." />` under Central Package Management, or a
     direct `<PackageReference>` pin that out-ranks the transitive
     resolution)?
   - Moderate/Low severity = note in the findings list but do not
     over-weight in the narrative or let it dominate the recommendations
   - A package that is 3+ major versions behind with NO known vulnerability
     is still a real finding — a maintainability/support risk distinct from
     a security finding, since the upgrade path only grows more complex
     the longer it's deferred

4. NUGET SOURCE HYGIENE:
   - Look for `NuGet.Config`/`nuget.config` at the repo root or solution
     directory
   - Check every `<add key="..." value="..." />` entry under
     `<packageSources>` for a non-HTTPS (`http://`) URL — this is a real
     security risk (a MITM position could tamper with package downloads)
     and should be flagged prominently if found
   - Check for a `<packageSourceMapping>` section — its presence is a
     positive signal (it constrains which source each package ID may come
     from, mitigating dependency-confusion attacks); note its absence as a
     nice-to-have gap, not a required control
   - If no `NuGet.Config` is present at all, note that the project relies
     entirely on default/global NuGet sources (typically fine, but source
     mapping cannot be evaluated)

5. CENTRAL PACKAGE MANAGEMENT CROSS-CHECK:
   - If `Directory.Packages.props` was already detected by
     `config-analysis.md`, cross-reference it here: note whether the
     vulnerable/outdated packages found above are managed centrally
     (single version bump in `Directory.Packages.props` fixes every
     project at once) or scattered as per-project `<PackageReference>`
     versions (each project must be bumped and tested individually)
   - If Central Package Management is NOT in use, note this as a factor
     that increases the effort/risk of remediating the findings above,
     not as a separate scoring criterion

OUTPUT FORMAT:

Provide structured analysis (feeds into Tech Stack section):
- Vulnerable packages found: [count] (Critical: N, High: N, Moderate: N, Low: N)
- Direct vs transitive vulnerable: [breakdown, e.g. "2 direct (1 High, 1 Moderate), 3 transitive (1 Critical, 2 Low)"]
- Vulnerable package list: [name@version — severity — advisory ID/URL, for each]
- Outdated packages found: [count] (3+ major versions behind: N)
- Notably deprecated/superseded packages in use: [list, e.g. Newtonsoft.Json where System.Text.Json is expected]
- NuGet source hygiene: [HTTPS-only sources: Yes/No/No NuGet.Config found] (package source mapping: Yes/No)
- Central Package Management remediation impact: [Centralized — single bump fixes all / Scattered per-project / N/A — CPM not in use]
- Risks identified
- Recommendations (prioritized: fix direct Critical/High first, then transitive Critical/High with an identified fix path, then outdated-but-not-vulnerable packages)

SCORING GUIDANCE (this is one input into the Tech Stack section score, not a standalone score):

Strong (85-100):
- Zero Critical/High vulnerabilities, direct or transitive
- Few or no packages outdated by more than 1 major version; no deprecated/unmaintained packages in use
- NuGet sources are HTTPS-only, with package source mapping configured

Fair (70-84):
- No Critical vulnerabilities, but some High/Moderate present with a clear fix path (a patched version is available to bump to)
- A handful of packages 2+ major versions behind, but no unmaintained/abandoned packages
- NuGet sources are HTTPS-only but no package source mapping configured

Weak (0-69):
- One or more Critical/High severity vulnerabilities with no immediate fix path (transitive, no override available), or vulnerabilities left unaddressed across multiple audit cycles
- Multiple packages 3+ major versions behind, including deprecated/unmaintained packages
- Any non-HTTPS NuGet package source configured
