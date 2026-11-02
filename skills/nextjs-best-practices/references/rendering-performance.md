# Next.js Rendering Performance Analysis

> Analyze use of next/image, next/font and next/script, dynamic imports, static versus dynamic rendering, client bundle size drivers, and Partial Prerendering where the installed version documents it.

---

Goal: Evaluate whether the application uses the framework's built-in
optimizations and renders as much as possible ahead of time.

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
- Getting Started: Images, Fonts; Caching (the "Prerendering" section, which
  describes Partial Prerendering in versions that ship it)
- Guides: Scripts, Lazy Loading, Package Bundling, Streaming
- API Reference > Components: `Image`, `Font`, `Script`, `Link`

COMPLEMENTARY STANDARDS (read when present, never required):
- Somnio Next.js rules: every `.md` under `agent-rules/rules/nextjs/` in the
  local repo. Skip when the directory is absent; do not guess remote URLs.
- Somnio React performance rule (memoization, list rendering inside Client
  Components):
  local: `agent-rules/rules/react/performance.md`
  raw:   https://raw.githubusercontent.com/somnio-software/somnio-ai-tools/main/agent-rules/rules/react/performance.md

ANALYSIS TARGETS:
1.  **Images**:
    *   Flag raw `<img>` elements for content images (the
        `@next/next/no-img-element` lint rule exists for this) unless the
        file documents a reason (e.g. inline SVG data, email templates).
    *   `next/image` usage: explicit `width`/`height` or `fill` with a sized
        parent, `sizes` for responsive images, priority/preload hint on the
        LCP image using the prop name the installed docs list.
    *   `images.remotePatterns` (or the installed version's equivalent)
        configured narrowly instead of wildcard hosts.

2.  **Fonts**:
    *   Fonts loaded through `next/font` (Google or local) rather than
        `<link>` tags to font CDNs or CSS `@import`.
    *   Font instances created once (module scope, shared) rather than per
        component render.

3.  **Third-Party Scripts**:
    *   Third-party scripts loaded with `next/script` and an appropriate
        loading strategy; flag raw `<script>` tags in layouts and synchronous
        scripts in the head.
    *   Flag analytics/tag scripts loaded eagerly when a deferred strategy is
        documented.

4.  **Code Splitting & Bundle Size**:
    *   Heavy client-only libraries (charts, editors, maps, PDF, animation)
        loaded with `next/dynamic` or `React.lazy` behind interaction or
        below the fold.
    *   Flag large libraries imported into Client Components when only used
        on the server, and barrel imports from icon/UI libraries that the
        installed docs recommend optimizing (e.g. a package-imports
        optimization option, if documented for the version).
    *   Flag `'use client'` at high levels of the tree that drag large
        subtrees into the client bundle (cross-reference the Server & Client
        Components dimension; do not double-count the same file).
    *   Check `next build` output or a bundle analyzer report if one is
        committed; otherwise state "bundle sizes not measured".

5.  **Static vs Dynamic Rendering**:
    *   Identify routes forced dynamic (`dynamic = 'force-dynamic'`,
        `revalidate = 0`, runtime API reads at the top of a layout) that have
        no request-time data.
    *   Dynamic routes with a known param set provide `generateStaticParams`.
    *   Partial Prerendering / static shell: only if the installed docs
        document it, check whether request-time work is pushed below
        `<Suspense>` so the static shell is meaningful. If not documented for
        the version, write "not documented for vX.Y" and skip.

6.  **Navigation**:
    *   Internal navigation uses `next/link` rather than `<a href>` to
        internal routes (the `@next/next/no-html-link-for-pages` rule).
    *   Flag `prefetch` overrides without a stated reason.

OUTPUT FORMAT:
*   **Installed version / Docs source**: as resolved above.
*   **Overview**: `<img>` vs `next/image` counts, font loading method,
    `<script>` vs `next/script` counts, dynamic imports count, routes forced
    dynamic.
*   **Score**: 0-100 integer with label (Strong 85-100 / Fair 70-84 / Weak 0-69).
    Start at 100 and deduct per violation: Critical -15, High -8, Medium -4,
    Low -1 (floor 0).
*   **Violations**: list specific file paths and lines.
    *   Format: `[Type Issue] path/to/file.tsx:line — description (docs: <page>)`
*   **Compliance**: good examples found in the codebase.
*   **Recommendations**: specific optimization suggestions per violation.
*   **Recommended follow-ups** (only when the installed docs document the
    feature and the project meets its prerequisites), installed with
    `npx skills add vercel/next.js --skill <name>` from
    https://github.com/vercel/next.js/tree/canary/skills:
    *   `next-bundle-optimizer` — client bundles are a measured or likely
        driver of slow initial loads.
    *   `next-cache-components-optimizer` — Cache Components adopted and a key
        route's static shell is thin.
    *   `next-partial-prefetching-adoption` / `next-partial-prefetching-optimizer`
        — Cache Components adopted and navigation speed is in scope.
    *   Vercel's `react-best-practices` skill
        (https://github.com/vercel-labs/agent-skills/tree/main/skills/react-best-practices)
        for React-level re-render and bundle rules.
