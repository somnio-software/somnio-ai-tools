# Next.js Server & Client Components Analysis

> Analyze the Server/Client Component boundary: Server Components by default, minimal and pushed-down 'use client', server-only/client-only markers, serializable props, no secrets across the boundary, and hydration pitfalls.

---

Goal: Evaluate whether the codebase keeps work on the server by default and
crosses into the client only where interactivity or browser APIs need it,
without leaking server-only code or data.

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
- Getting Started: Server and Client Components (including "Preventing
  environment poisoning" and "Interleaving Server and Client Components")
- API Reference > Directives: `use client`
- Guides: Environment Variables (the client-exposure prefix), Data Security
  (passing data from server to client)

COMPLEMENTARY STANDARDS (read when present, never required):
- Somnio Next.js rules: every `.md` under `agent-rules/rules/nextjs/` in the
  local repo. Skip when the directory is absent; do not guess remote URLs.
- Somnio React hooks rule (applies inside Client Components):
  local: `agent-rules/rules/react/hooks-patterns.md`
  raw:   https://raw.githubusercontent.com/somnio-software/somnio-ai-tools/main/agent-rules/rules/react/hooks-patterns.md

If the project has no App Router (`app/` or `src/app/`), this dimension has
no surface: write `Score: N/A` with the reason and stop.

ANALYSIS TARGETS:
1.  **Client Surface Size**:
    *   Count files with a top-level `'use client'` directive versus all
        component files under the App Router tree and shared component dirs.
    *   Flag `'use client'` on `layout.*` and `page.*` files, and on files
        that use no state, effects, event handlers, browser APIs or
        client-only hooks (the directive is unnecessary there).
    *   Flag `'use client'` added to every file of a subtree when the docs
        state that imports of a Client Component are already in the client
        module graph.

2.  **Boundary Placement**:
    *   Check interactive pieces are extracted into small leaf Client
        Components while the surrounding layout/page stays a Server Component.
    *   Check Server Components are passed to Client Components as `children`
        or other props (interleaving) instead of being imported from a client
        module, which would pull them into the client graph.
    *   Check context providers wrap `{children}` as deep in the tree as
        practical rather than the whole document.
    *   Check third-party components that rely on client-only features are
        wrapped in a local Client Component.

3.  **Server-Only / Client-Only Markers**:
    *   Modules that read secrets, databases, or `process.env` values without
        the client-exposure prefix should import `server-only` (or the
        installed version's documented equivalent).
    *   Modules touching `window`, `document` or `localStorage` that could be
        imported by a Server Component should import `client-only`.
    *   Flag server-only modules (DB clients, SDKs with secret keys) imported
        from any `'use client'` file or its imports.

4.  **Props & Data Across the Boundary**:
    *   Props from Server to Client Components must be serializable by React
        (flag functions other than Server Actions, class instances, and other
        values the installed docs list as unsupported).
    *   Flag whole database records or user objects passed to Client
        Components when only a few fields are rendered — pass minimal DTOs.
    *   Flag secrets or tokens passed as props, and env vars with the
        client-exposure prefix that hold secret values.

5.  **Hydration Pitfalls**:
    *   Flag render-time use of `Date.now()`, `new Date()` formatting,
        `Math.random()`, `typeof window` branches, or locale-dependent output
        in components rendered on both server and client without a documented
        guard (e.g. effect, `suppressHydrationWarning` on the specific node,
        or a dynamic import with SSR disabled where the docs allow it).
    *   Flag invalid HTML nesting in JSX that commonly breaks hydration
        (e.g. `<div>` inside `<p>`).
    *   Flag `async` Client Components (the docs and `eslint-config-next`
        flag them).

OUTPUT FORMAT:
*   **Installed version / Docs source**: as resolved above.
*   **Overview**: `'use client'` files / total component files, leaf vs
    root placement, server-only marker coverage.
*   **Score**: 0-100 integer with label (Strong 85-100 / Fair 70-84 / Weak 0-69).
    Start at 100 and deduct per violation: Critical -15, High -8, Medium -4,
    Low -1 (floor 0). Secrets reachable from the client bundle are Critical.
*   **Violations**: list specific file paths and lines.
    *   Format: `[Type Issue] path/to/file.tsx:line — description (docs: <page>)`
*   **Compliance**: good examples found in the codebase.
*   **Recommendations**: specific refactoring suggestions per violation. Where
    the client surface is large, point to Vercel's `react-best-practices`
    skill (https://github.com/vercel-labs/agent-skills/tree/main/skills/react-best-practices)
    as a complementary rule set.
