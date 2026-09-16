# .NET Health Audit Support Lifecycle Analysis

> Determine whether every TargetFramework in the solution is still within Microsoft's official .NET support policy, and identify the current recommended LTS target — without relying on a hardcoded date table that goes stale.

---

Goal: Assess whether the .NET version(s) this solution targets are still
officially supported by Microsoft, how much runway remains before
end-of-support, and what the current recommended upgrade target is.
Findings from this step feed into the existing **Tech Stack** report
section — this is NOT a standalone report section.

IMPORTANT — WHY THIS USES A RULE, NOT A HARDCODED DATE TABLE:

A literal table like "net6.0 supported until Nov 2024" goes stale the
moment it's written — a new major version ships every November, and
copies of this file installed months or years apart would silently give
wrong answers. Instead, this step applies Microsoft's own **published,
stable support-cadence policy**, combined with a table of *release
years* (a historical fact that never changes once a version has
shipped) to compute end-of-support dates arithmetically. This stays
correct indefinitely without maintenance, for any TargetFramework this
step encounters — past, present, or future.

EFFICIENCY REQUIREMENTS:
- Target: ≤ 4 total tool calls for this entire analysis
- Reuse the TargetFramework list already collected by
  `references/version-alignment.md` (step 2) instead of re-scanning
  `.csproj` files from scratch — only re-derive it if that artifact is
  unavailable

THE .NET SUPPORT POLICY RULE:

1. **Modern .NET (formerly ".NET Core"), versions 5 and above**:
   - Microsoft ships a new major version every **November**.
   - **Even-numbered** major versions (6, 8, 10, 12, ...) are
     **LTS (Long Term Support)**: supported for **3 years** from
     general availability.
   - **Odd-numbered** major versions (5, 7, 9, 11, ...) are
     **STS (Standard Term Support)**: supported for **18 months**
     from general availability.
   - End-of-support date = release month/year (November of the
     release year) + the support duration above. A version is
     "in support" if today's date is before that computed date.
   - Source of this policy: https://dotnet.microsoft.com/platform/support/policy/dotnet-core
     (fetch this page with WebFetch if available, to double-check
     against the rule below and catch any policy change; if WebFetch
     is unavailable, the rule alone is sufficient and does not
     require network access).

2. **Release-year table (historical fact — extend forward as new
   versions ship, never needs correcting backward)**:
   | Major version | GA month/year | Type |
   |---|---|---|
   | .NET Core 1.0 | Jun 2016 | (out of support) |
   | .NET Core 1.1 | Nov 2016 | (out of support) |
   | .NET Core 2.0 | Aug 2017 | (out of support) |
   | .NET Core 2.1 | May 2018 | LTS (out of support) |
   | .NET Core 2.2 | Dec 2018 | (out of support) |
   | .NET Core 3.0 | Sep 2019 | (out of support) |
   | .NET Core 3.1 | Dec 2019 | LTS (out of support) |
   | .NET 5 | Nov 2020 | STS (out of support) |
   | .NET 6 | Nov 2021 | LTS |
   | .NET 7 | Nov 2022 | STS (out of support) |
   | .NET 8 | Nov 2023 | LTS |
   | .NET 9 | Nov 2024 | STS |
   | .NET 10 | Nov 2025 | LTS |
   | .NET 11+ | (not yet released as of this writing) | STS if odd, LTS if even |

   If a `TargetFramework` value is encountered that isn't in this table
   (a future version), its GA date is November of the year that
   continues the established one-major-version-per-year cadence — each
   subsequent major version ships exactly one year after the previous
   one, in November (e.g. .NET 8 → Nov 2023, .NET 9 → Nov 2024, .NET 10
   → Nov 2025, .NET 11 → Nov 2026, and so on). Extrapolate linearly
   from the nearest known anchor row above rather than guessing.

3. **.NET Framework (4.x — the pre-2016 Windows-only runtime, NOT
   modern .NET)**:
   - Follows the **Windows lifecycle**, not the modern .NET cadence:
     each .NET Framework version is supported for as long as the
     Windows/Windows Server OS version it shipped with (or was
     validated on) remains in support, per the ".NET Framework
     lifecycle FAQ" policy — practically, 4.5.2 through 4.8.1 are
     supported for the life of the underlying OS, with no independent
     EOL date of their own.
   - Note it as "supported via the OS lifecycle, but receives no new
     features and is not the actively developed platform" — this is
     a genuinely different kind of finding than a hard EOL date, and
     should be reported as a **modernization opportunity**, not
     phrased identically to "this version is unsupported."

4. **.NET Core 1.x/2.x/3.x and .NET 5/7 found in a solution today are
   ALWAYS past end-of-support** (per the table above) — this is a
   simple, unconditional flag regardless of current date, since even
   the longest-lived of these (.NET Core 3.1 LTS, EOL Dec 2022) is
   long past its window as of any date this skill would plausibly run.

EXECUTION STEPS:

1. Collect the distinct `TargetFramework`/`TargetFrameworks` values
   already detected in `references/version-alignment.md` step 3 (or
   re-run `find . -name "*.csproj" -not -path "*/bin/*" -not -path
   "*/obj/*" | xargs grep -oE "<TargetFrameworks?>[^<]*</TargetFrameworks?>"`
   if that artifact isn't available).
2. For each distinct TFM, classify it:
   - `net48`, `net472`, `net462`, etc. → .NET Framework, apply rule 3.
   - `netcoreapp*`, `net5.0` through current → modern .NET, apply
     rules 1-2 to compute exact support status and days/months
     remaining (or elapsed since EOL).
   - `netstandard2.0`/`netstandard2.1` → a portability target, not a
     runtime — note it separately as "Standard, not a runtime version;
     consuming apps' TFM determines actual support status."
3. Identify the **current latest LTS** version using today's date and
   the table above (e.g. if today falls after a new LTS's GA date, that
   is the new recommended target) — this is the version to recommend
   migrating toward, not necessarily the newest version overall (STS
   releases are not a good long-term target for production systems
   that won't upgrade again within 18 months).
4. If `WebFetch` is available, fetch
   `https://dotnet.microsoft.com/platform/support/policy/dotnet-core`
   once and cross-check the computed dates/current-LTS recommendation
   against it; note any discrepancy explicitly rather than silently
   trusting one source over the other. If `WebFetch` is unavailable or
   fails, proceed with the rule-based computation alone and note that
   no live cross-check was performed.

OUTPUT FORMAT:

Provide structured analysis:
- TargetFramework(s) found: [list, e.g. net8.0, net472]
- Per-TFM support status:
  * [TFM]: [In support / Out of support since [month year] / Supported
    via OS lifecycle (no independent EOL)] — [type: LTS/STS/Framework]
- Months remaining (or months past EOL) for each in-support/out-of-support TFM
- Current recommended LTS target: [e.g. net8.0, or net10.0 if already GA]
- Live cross-check performed: [Yes — consistent/Yes — discrepancy noted/No — rule-based only]
- Risks identified (e.g. "net5.0 has been out of support since May 2022 — running in production on an unsupported runtime receives no security patches")
- Recommendations (e.g. "plan migration from net6.0 to net8.0 before Nov 2024 EOL" — phrase relative to the computed date, not a fixed calendar claim that could itself go stale in the report)

SCORING GUIDANCE (this score is one input into the Tech Stack section score, not standalone):

Strong (85-100):
- All TargetFrameworks are on a currently-supported LTS release
- No .NET Framework or EOL .NET Core/5.x/7.x targets present
- If on an LTS approaching its final year of support, a migration plan is already evident (docs, tracked issue, in-progress branch)

Fair (70-84):
- On a currently-supported STS release (net9.0-style), or an LTS release with roughly a year or less of support life remaining and no visible migration plan
- .NET Framework present alongside a modern tier, with the modern tier actively growing (a deliberate, in-progress migration)

Weak (0-69):
- Any TargetFramework is past its official end-of-support date (e.g. net5.0, net7.0, net6.0 after Nov 2024, .NET Core 3.x or earlier)
- .NET Framework present with no modern tier and no evidence of a modernization plan
- Running production workloads on an unsupported runtime is a genuine security and compliance risk — score this harshly, it is not a cosmetic finding
