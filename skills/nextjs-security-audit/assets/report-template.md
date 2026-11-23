# Next.js Security Audit Report

---

## 1. Security Scoring Breakdown

| Area | Score |
|------|-------|
| Sensitive File & Env Protection | [Score]/100 ([Label]) |
| Secret Detection | [Score]/100 ([Label]) |
| Framework & Dependency Security | [Score]/100 ([Label]) |
| Supply Chain Integrity | [Score]/100 ([Label]) |
| Next.js App Security | [Score]/100 ([Label]) |
| **Overall Score** | **[Score]/100 ([Label])** |

**Security Posture:** [Secure / Needs Attention / At Risk / Critical]

> **Scoring:** Strong (85–100) · Fair (70–84) · Weak (50–69) · Critical (0–49)

---

## 2. Executive Summary

**Description:** Security analysis of the [Project Name] Next.js project ([App Router / Pages Router / both], [N] app(s)).

**Overall Score:** [Score]/100 ([Label])

**Trend:** Previous [N]/100, change [+/-M] ([improving|declining|unchanged])
> _(First run, with no previous score: write `**Trend:** first run`.)_

**Top Findings:**
- [Framework advisory findings first: `next@[installed]` in `[app]` — [GHSA/CVE IDs] ([severity]), patched in [version quoted from the advisory] — HIGH]
- [End-of-life `next` major, if any — HIGH]
- [Finding with severity]
- [Continue as needed]

**Priority Recommendations:**
1. [Recommendation 1]
2. [Recommendation 2]
3. [Recommendation 3]
4. [Continue as needed]

---

> **Sections 3–7** are dynamically ordered by score ascending (lowest score = Section 3, highest = Section 7).

---

## [N]. [Section Name]

> _(One of: Sensitive File & Env Protection · Secret Detection · Framework & Dependency Security · Supply Chain Integrity · Next.js App Security)_

**Description:** [Brief explanation of what this section evaluates]

**Score:** [Score]/100 ([Label])

**Score Breakdown:**
- Base: 100
- [Deduction reason]: -[value]
- [Bonus reason]: +[value]
- **Final:** [Score]/100 ([Label])

### Key Findings
- **[HIGH/MEDIUM/LOW]** — [Finding 1]
- [Continue as needed]

### Evidence
- `[File path:line, advisory ID + source URL, or config reference]`
- [Continue as needed]

### Risks
- [Risk 1]
- [Continue as needed]

### Recommendations
1. [Recommendation 1]
2. [Continue as needed]

> **Framework & Dependency Security section MUST include, before Key Findings:**
>
> ### Framework Version Status
>
> | App | Package | Installed | Advisories (GHSA / CVE) | Patched in (per advisory) | Latest patch of major | Support status | Verdict |
> |-----|---------|-----------|-------------------------|---------------------------|-----------------------|----------------|---------|
> | [app] | next | [lockfile version] | [IDs or none] | [quoted] | [npm registry] | [Supported / EOL since date / Unknown] | [Vulnerable / No matching advisory at time / Unknown] |
>
> and the dependency tree counts: Critical [N], High [N], Medium [N], Low [N] (direct [N] / transitive [N]).
>
> **Supply Chain Integrity section MUST include**, when the package manager is not pnpm, the pnpm migration recipe under Recommendations.
>
> **Next.js App Security section MUST include** the header checklist: H1 CSP · H2 HSTS · H3 Framing · H4 nosniff · H5 Referrer-Policy · H6 Permissions-Policy · H7 poweredByHeader, each PRESENT / PARTIAL / MISSING / Unknown.

---

## 8. Consolidated Findings by Severity

### 🔴 [HIGH] — Immediate Action Required
1. [Framework advisory / EOL findings first] — Source: [framework/deps/supply chain/secrets/env/sast/headers]
2. [Continue as needed, or "No HIGH severity findings"]

### 🟡 [MEDIUM] — Address Soon
1. [Finding description] — Source: [framework/deps/supply chain/secrets/env/sast/headers]
2. [Continue as needed, or "No MEDIUM severity findings"]

### 🟢 [LOW] — Best Effort
1. [Finding description] — Source: [framework/deps/supply chain/secrets/env/sast/headers]
2. [Continue as needed, or "No LOW severity findings"]

---

## 9. Remediation Priority Matrix

| Priority | Finding | Effort | Impact |
|----------|---------|--------|--------|
| 1 | [Finding] | [Low/Medium/High] | [Low/Medium/High] |
| 2 | [Finding] | [Low/Medium/High] | [Low/Medium/High] |
| [Continue as needed] | | | |

---

## 10. Project Detection Results

- **Next.js apps:** [paths, e.g. `.` or `apps/web`, `apps/admin`]
- **Installed `next` / `react` versions:** [per app, from the lockfile]
- **Router:** [App Router / Pages Router / both, per app]
- **Middleware / proxy:** [file path or none]
- **Package manager:** [Manager and version, lockfile]
- **Node.js runtime targets:** [source: version]
- **Deployment hints:** [vercel.json / Dockerfile / output mode, or none found]
- **Repository structure:** [single app / monorepo]
- **Source files scanned:** [counts from the scope summary]
- **Live sources reached:** [OSV / GitHub Advisory Database / Next.js advisories / endoflife.date / npm registry, with UTC time; failures]

---

## 11. Appendix: Evidence Index

**Framework & Advisories:**
- [Advisory ID — source URL — queried at UTC]
- [Continue as needed]

**Dependencies & Supply Chain:**
- [File path or config reference]
- [Continue as needed]

**Secrets & Environment:**
- [File path:line (values redacted)]
- [Continue as needed]

**Application Code (SAST):**
- [File path:line]
- [Continue as needed]

**Headers & Configuration:**
- [File path:line]
- [Continue as needed]

---

## Appendix: Scoring Methodology

**Area Weights:**
- Sensitive File & Env Protection: 0.15
- Secret Detection: 0.20
- Framework & Dependency Security: 0.30
- Supply Chain Integrity: 0.15
- Next.js App Security: 0.20

**Formula:** overall = round(file_env * 0.15 + secret_detection * 0.20 + framework_dependency * 0.30 + supply_chain * 0.15 + nextjs_app * 0.20)

---

## 12. Report Metadata

| Field | Value |
|-------|-------|
| Scan date | [Date] |
| Project path | [Path] |
| Project type | [Next.js + router type(s)] |
| Tools used | [List of tools] |
| Live sources queried | [Sources reached, with UTC query time] |
| Total findings | [Count] |
| Scan duration | [Duration or N/A] |
| Generated by | Somnio CLI v3.3.3 |
| Skill | nextjs-security-audit |
| Somnio AI Tools | https://github.com/somnio-software/somnio-ai-tools |
