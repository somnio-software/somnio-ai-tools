# Next.js TypeScript Standards Analysis

> Analyze TypeScript strictness, Next.js type tooling (typed routes, route-aware type helpers), build-time type checking, eslint-config-next, and package-manager tooling.

---

Goal: Evaluate whether type checking and linting are strict and actually
enforced by the build.

VERSION & DOCS RESOLUTION (MANDATORY — run before any analysis):
1. Resolve the INSTALLED `next` version from the lockfile, not from the
   `package.json` range:
   - `pnpm-lock.yaml`, `package-lock.json`, `yarn.lock` or `bun.lock` at the
     project root (or at the workspace root in a monorepo).
   - Fallback: the `"version"` field of `node_modules/next/package.json`.
   - If neither resolves, record the `package.json` range, write
     "Installed version: Unknown", and mark every version-dependent finding
     "unverified against the installed version".
2. Read version-matched documentation; the first source that exists wins:
   a. `node_modules/next/dist/docs/` — bundled with the installed package in
      newer releases; mirrors the nextjs.org/docs tree (`01-app/`, `02-pages/`).
   b. `.next-docs/` — downloaded by `npx @next/codemod@canary agents-md` for
      releases that do not bundle docs (usually indexed from `AGENTS.md`).
   c. Otherwise fetch https://nextjs.org/docs for the installed major. Older
      majors live under a versioned prefix (e.g. `https://nextjs.org/docs/15`);
      the unprefixed path documents the latest release. Every page has a
      Markdown variant at `<url>.md`, and `<prefix>/llms.txt` indexes all pages
      for that version.
   Record in the output: "Installed version: X.Y.Z" and "Docs source: <a|b|c + path>".
3. Never assert that an API, option, file convention or default exists in the
   installed version without evidence from those docs. If the matching docs do
   not mention it, write "not documented for vX.Y" instead of recommending it.
4. Never cite vulnerability version numbers from memory. Security findings go
   to the `nextjs-security-audit` skill; mention them only as a referral.

DOCS TO READ FOR THIS DIMENSION (use the equivalent page names if the
installed version organizes them differently):
- API Reference > Configuration: TypeScript (typed links/routes, route-aware
  type helpers, `ignoreBuildErrors`), ESLint (`eslint-config-next`, and
  whether `next lint` still exists in the installed version)
- API Reference > `next.config.js`: `typedRoutes` (or the experimental flag
  name the installed version uses)

COMPLEMENTARY STANDARDS (read when present, never required):
- Somnio Next.js rules: every `.md` under `agent-rules/rules/nextjs/` in the
  local repo. Skip when the directory is absent; do not guess remote URLs.
- Somnio React TypeScript rule:
  local: `agent-rules/rules/react/typescript.md`
  raw:   https://raw.githubusercontent.com/somnio-software/somnio-ai-tools/main/agent-rules/rules/react/typescript.md
- Somnio TypeScript rule:
  local: `agent-rules/rules/typescript/best-practices.md`
  raw:   https://raw.githubusercontent.com/somnio-software/somnio-ai-tools/main/agent-rules/rules/typescript/best-practices.md

ANALYSIS TARGETS:
1.  **TypeScript Configuration**:
    *   `tsconfig.json` has `"strict": true`; record `noUncheckedIndexedAccess`
        and other stricter flags as bonuses, not requirements.
    *   The Next.js TypeScript plugin entry and `next-env.d.ts` / generated
        `.next/types` includes are present as the installed docs describe.
    *   Path aliases (`paths`) configured and used consistently.
    *   JavaScript-only project: write "TypeScript not adopted" as a High
        finding and score the remaining targets that still apply (lint,
        tooling).

2.  **Build Enforcement**:
    *   **CRITICAL**: flag `typescript.ignoreBuildErrors: true` in
        `next.config.*` unless a separate CI step runs `tsc --noEmit` (cite
        the CI file). Same for any lint-skipping build option the installed
        version still documents.
    *   A `typecheck` (or equivalent) script exists and runs in CI.

3.  **Type Safety in Next.js Code**:
    *   Count explicit `any`, `as any`, `@ts-ignore` and `@ts-expect-error`
        without a comment.
    *   Page, layout and route handler props are typed — with the generated
        route-aware helpers (e.g. `PageProps`, `LayoutProps`,
        `RouteContext`) when the installed docs document them, otherwise with
        explicit types that match the installed version's `params` /
        `searchParams` shape (sync or Promise, per the docs).
    *   Server Action inputs are typed via schema inference (e.g.
        `z.infer`) rather than casts.
    *   Typed routes: if the installed docs document typed links/routes,
        report whether they are enabled; recommend enabling them as Medium.

4.  **Linting**:
    *   `eslint-config-next` (ideally its Core Web Vitals preset, plus its
        TypeScript preset when documented) is configured, in the config
        format the installed version documents.
    *   Flag a `lint` script that calls `next lint` when the installed docs
        say it was removed, and disabled `@next/next/*` or `react-hooks/*`
        rules without justification.

5.  **Tooling (package manager)**:
    *   Record the package manager from the lockfile. If it is not pnpm,
        recommend pnpm as a Low-priority item for supply-chain safety (for
        example release-age delays and an allowlist for dependency build
        scripts; see https://pnpm.io/supply-chain-security). Do not deduct
        score for the package manager choice.
    *   Flag a missing or uncommitted lockfile, or multiple lockfiles, as
        Medium.

OUTPUT FORMAT:
*   **TypeScript Score**: 0-100 integer with label (Strong 85-100 / Fair 70-84
    / Weak 0-69). Start at 100 and deduct per violation: Critical -15,
    High -8, Medium -4, Low -1 (floor 0).
*   **Installed version / Docs source**: as resolved above.
*   **Violations**:
    *   `[Config Issue]` [tsconfig.json / next.config.*]: description.
    *   `[Any Usage]` [file:line]: explicit `any` found.
    *   `[Props Issue]` [file:line]: untyped page/layout/handler props.
    *   `[Lint Issue]` [eslint config]: description.
*   **Recommendations**: specific typing and tooling improvements per
    violation.
