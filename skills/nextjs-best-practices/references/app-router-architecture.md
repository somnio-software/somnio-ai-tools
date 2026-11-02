# Next.js App Router Architecture Analysis

> Analyze routing structure, layouts, route groups, colocation, loading/error/not-found boundaries, Pages Router legacy and Metadata API usage against the docs for the installed Next.js version.

---

Goal: Evaluate how the application is organized on top of the Next.js router
and whether it uses the file conventions the installed version documents.

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

DOCS TO READ FOR THIS DIMENSION (paths relative to the docs root; use the
equivalent page names if the installed version organizes them differently):
- Getting Started: Project Structure, Layouts and Pages, Error Handling,
  Metadata and OG images
- API Reference > File Conventions: `layout`, `page`, `loading`, `error`,
  `not-found`, route groups, private folders, parallel/intercepting routes
- The App Router migration guide when a `pages/` directory is present

COMPLEMENTARY STANDARDS (read when present, never required):
- Somnio Next.js rules: every `.md` under `agent-rules/rules/nextjs/` in the
  local repo. Skip when the directory is absent; do not guess remote URLs.
- Somnio React component architecture rule:
  local: `agent-rules/rules/react/component-architecture.md`
  raw:   https://raw.githubusercontent.com/somnio-software/somnio-ai-tools/main/agent-rules/rules/react/component-architecture.md

ANALYSIS TARGETS:
1.  **Router Model**:
    *   Locate the router roots: `app/` or `src/app/` (App Router), `pages/`
        or `src/pages/` (Pages Router). Report which exist.
    *   When both exist, check whether routes are duplicated across routers
        and whether the docs for the installed version describe the mix as a
        supported incremental-migration state. Flag new routes added to
        `pages/` after the App Router was adopted.
    *   Pages Router–only projects: assess Pages Router conventions instead
        (`_app`, `_document`, data-fetching functions per the docs) and note
        App Router adoption as a recommendation, not a violation.

2.  **Route Structure & Colocation**:
    *   Enumerate route segments (`page.*`), dynamic segments (`[param]`,
        `[...slug]`, `[[...slug]]`), route groups (`(group)`), private
        folders (`_folder`), parallel routes (`@slot`) and intercepting routes.
    *   Check that non-route code colocated inside `app/` cannot become a
        public route by accident (only `page` / `route` files are routable;
        verify against the docs).
    *   Flag route groups that create conflicting paths, and deeply nested
        segments that only wrap a single child without a layout or boundary.
    *   Check shared UI lives in layouts rather than being repeated in every
        page.

3.  **Layouts**:
    *   Root layout present with `<html>` and `<body>`.
    *   Flag layouts that read per-request data at the top level when it
        could be read deeper in the tree (see data-fetching dimension for
        caching implications).
    *   Flag layouts marked `'use client'` as a whole (cross-check with the
        Server & Client Components dimension).

4.  **Boundaries**:
    *   `loading.*` files or explicit `<Suspense>` for segments that await
        data.
    *   `error.*` files for segments that can throw; `global-error.*` at the
        root. Verify `error.*` files are Client Components when the installed
        docs require it.
    *   `not-found.*` files and `notFound()` calls for dynamic segments that
        look up records.
    *   Report coverage as `[segments with boundary]/[segments that need one]`.

5.  **Metadata**:
    *   Metadata API usage (`export const metadata`, `generateMetadata`,
        file-based metadata such as `icon`, `opengraph-image`, `sitemap`,
        `robots`) as documented for the installed version.
    *   Flag `next/head` or hand-written `<head>` tags inside the App Router.
    *   Flag pages without a title or description where the root layout does
        not provide a default or template.

OUTPUT FORMAT:
*   **Installed version / Docs source**: as resolved above.
*   **Overview**: router(s) in use, route count, segment count, boundary
    coverage, metadata approach.
*   **Score**: 0-100 integer with label (Strong 85-100 / Fair 70-84 / Weak 0-69).
    Start at 100 and deduct per violation: Critical -15, High -8, Medium -4,
    Low -1 (floor 0). If the project has no surface for this dimension at all,
    write `Score: N/A` and explain why.
*   **Violations**: list specific file paths and lines.
    *   Format: `[Type Issue] path/to/file.tsx:line — description (docs: <page>)`
*   **Compliance**: good examples found in the codebase.
*   **Recommendations**: specific refactoring suggestions per violation.
