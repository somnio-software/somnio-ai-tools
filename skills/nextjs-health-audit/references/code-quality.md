# Next.js Code Quality Analysis

> Analyze ESLint (`eslint-config-next` / `@next/eslint-plugin-next`), TypeScript strictness, formatting, code quality metrics, and the Next.js-specific usage signals (Server Components by default, `'use client'` surface, `next/image`, `next/font`, `next/script`, dynamic imports) that also feed the Performance section.

---

Goal: Evaluate the code quality infrastructure and collect the
Next.js usage evidence the report generator needs for both the Code
Quality and the Performance sections.

Run every command from the Next.js app directory (per app in a
monorepo). `SRC` below means the app's source roots that exist among
`app src components lib pages`. Exclude `node_modules`, `.next`,
`coverage` and test files from source counts.

ANALYSIS TARGETS:

1. **ESLint Configuration**:
   - Read `eslint.config.*` (flat) or `.eslintrc.*` (legacy)
   - Next.js rules present: `eslint-config-next/core-web-vitals`
     (recommended), `eslint-config-next`, `eslint-config-next/typescript`,
     or `@next/eslint-plugin-next` used directly
   - `react-hooks/rules-of-hooks` (error) and `react-hooks/exhaustive-deps`
     (warn or error) active (bundled by `eslint-config-next`)
   - `jsx-a11y` rules, `@typescript-eslint/no-unused-vars`,
     `@typescript-eslint/no-explicit-any`
   - Disabled `@next/next/*` rules — list each (e.g.
     `@next/next/no-img-element` off hides raw `<img>` usage)
   - Lint execution: a `lint` script running `eslint` (the `next lint`
     command was removed in Next.js 16)
   - Run the linter non-blocking and count problems:
     `pnpm exec eslint . --format json -o "${TMPDIR:-/tmp}/eslint.json" || true`
     then count errors/warnings from the JSON (or parse stdout)

2. **Formatting**:
   - Prettier (`.prettierrc`, `prettier.config.*`) with
     `eslint-config-prettier`, or Biome (`biome.json`)
   - `format` / `format:check` scripts
   - Note if formatting is entirely missing

3. **TypeScript Strictness**:
   - `tsconfig.json` `"strict": true` (or individual flags)
   - TypeScript errors: reuse the count from `version-validator.md`; if
     missing, `pnpm exec tsc --noEmit 2>&1 | grep -c 'error TS'`
   - `// @ts-ignore` / `// @ts-expect-error` counts
   - `next.config` `typescript.ignoreBuildErrors: true` (from
     `config-analysis.md`) — a strict tsconfig is meaningless if the
     build ignores errors
   - `typedRoutes` enabled (statically typed links — bonus)

4. **Code Quality Metrics**:
   ```bash
   grep -rnE ':\s*any\b|as any\b' $SRC --include='*.ts' --include='*.tsx' | grep -vE '\.(test|spec)\.' | wc -l
   grep -rn 'eslint-disable' $SRC | wc -l
   grep -rn 'console\.log' $SRC --include='*.ts' --include='*.tsx' | grep -vE '\.(test|spec)\.' | wc -l
   grep -rnE 'key=\{(index|i|idx)\}' $SRC --include='*.tsx' --include='*.jsx' | wc -l
   ```

NEXT.JS USAGE SIGNALS (feed Code Quality AND Performance):
Verify every API name against https://nextjs.org/docs before citing it
for the installed version.

5. **Server Components by default / `'use client'` surface**:
   - In the App Router, components are Server Components unless a file
     starts with `'use client'`. Count `'use client'` files vs total
     component files under `app/` + `components/`:
     ```bash
     grep -rlE "^['\"]use client['\"]" $SRC --include='*.tsx' --include='*.jsx' --include='*.ts' | wc -l
     ```
   - Flag `'use client'` at the top of `layout.*` or `page.*` files —
     it turns the whole subtree client-side (sometimes intentional for
     fully interactive pages; list them)
   - Flag `'use client'` files that import heavy server-friendly
     libraries (markdown parsers, syntax highlighters, date libraries,
     chart libraries rendered statically)
   - Flag client files that import server-only modules (database
     clients, `fs`, secrets) — and whether `server-only` is used to
     guard them
   - Flag async Client Components (lint rule
     `@next/next/no-async-client-component`)

6. **`next/image`**:
   - Count `next/image` imports vs raw `<img` tags in TSX/JSX:
     ```bash
     grep -rln "from 'next/image'\|from \"next/image\"" $SRC | wc -l
     grep -rn '<img[ >]' $SRC --include='*.tsx' --include='*.jsx' | wc -l
     ```
   - Above-the-fold images marked with `priority` (or `preload` on
     newer versions — check the installed version's `next/image` docs),
     `sizes` set on responsive (`fill`) images, `remotePatterns`
     configured instead of `unoptimized`

7. **`next/font`**:
   - `next/font/google` or `next/font/local` used vs `<link>` to
     fonts.googleapis.com or CSS `@import` of web fonts (layout shift
     and extra requests)
   - Fonts declared once (root layout or a shared `fonts.ts`), not per page

8. **`next/script`**:
   - Third-party scripts loaded through `next/script` with an explicit
     `strategy` (`afterInteractive` default, `lazyOnload` for
     non-critical, `beforeInteractive` only where required,
     `worker` experimental) vs raw `<script>` tags
   - `@next/third-parties` for Google Analytics / Tag Manager / YouTube /
     Maps embeds
   - Inline scripts carry an `id`

9. **Dynamic imports / code splitting**:
   - `next/dynamic` and `React.lazy` usage for heavy client-only widgets
     (editors, maps, charts), `ssr: false` only inside Client Components
   - `<Suspense>` boundaries around slow server data (count) and
     `loading.*` files (from `repository-inventory.md`)

10. **`next/link` and navigation**:
    - Internal navigation via `next/link` vs raw `<a href="/...">`
      (`@next/next/no-html-link-for-pages`)
    - `<Link prefetch={...}>` overrides — list where prefetch is disabled
      or forced

11. **Bundle analysis readiness**:
    - Turbopack: `next analyze` (Next.js 16.1+) available; script or docs
      mention it
    - webpack: `@next/bundle-analyzer` installed and wired with
      `ANALYZE=true`
    - `experimental.optimizePackageImports` for icon/utility libraries
    - Reference: https://nextjs.org/docs/app/guides/package-bundling

12. **Other**:
    - React Compiler enabled (`reactCompiler` in `next.config`) — note it;
      it reduces the need for manual `useMemo`/`useCallback`/`React.memo`
    - Manual memoization counts (`React.memo`, `useMemo`, `useCallback`)
    - List virtualization libraries (`@tanstack/react-virtual`,
      `react-window`) where long lists exist

OUTPUT FORMAT:

Provide structured analysis:
- ESLint configured: [Yes/No] (Next.js config: [core-web-vitals/base/plugin/legacy/none])
- react-hooks rules: [Yes/No]
- jsx-a11y: [Yes/No]
- typescript-eslint: [Yes/No/N/A]
- Disabled @next/next rules: [list or none]
- ESLint problems: [errors] errors / [warnings] warnings (or Not run)
- Formatter: [Prettier/Biome/None] (eslint-config-prettier: [Yes/No/N/A])
- TypeScript strict: [Yes/Partial/No/N/A]; ignoreBuildErrors: [Yes/No]
- TypeScript errors: [XX]
- any count: [XX]; ts-ignore/ts-expect-error: [XX]; eslint-disable: [XX]; console.log in source: [XX]; index-as-key: [XX]
- 'use client' files: [N] of [M] component files ([XX]%); client layouts/pages: [list]
- next/image imports: [N]; raw <img>: [N]
- next/font used: [Yes/No]; external font links: [N]
- next/script used: [Yes/No] (strategies: [list]); raw <script>: [N]
- next/dynamic / React.lazy: [N]; Suspense boundaries: [N]
- Raw internal <a href>: [N]
- Bundle analyzer: [next analyze/@next/bundle-analyzer/none]
- React Compiler: [Enabled/Not enabled]
- Risks identified
- Recommendations

SCORING GUIDANCE (Code Quality section):

Strong (85-100):
- `eslint-config-next/core-web-vitals` (or plugin) + TypeScript rules, lint clean or near clean
- TypeScript strict, no `ignoreBuildErrors`
- Formatter enforced
- Minimal `any`, ts-ignore and disabled rules

Fair (70-84):
- ESLint configured but Next.js or hooks rules missing/disabled
- TypeScript present but strict mode off
- Some `any` usage, a backlog of lint warnings

Weak (0-69):
- No ESLint or a CI/lint script still on the removed `next lint`
- No TypeScript, or `ignoreBuildErrors: true`
- High `any` usage
- No formatting enforcement
