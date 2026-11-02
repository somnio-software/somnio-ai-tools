# Next.js Configuration Analysis

> Read and analyze Next.js configuration files: `package.json`, `next.config.*`, `tsconfig.json`, ESLint (`eslint-config-next` / `@next/eslint-plugin-next`), Prettier and environment-variable conventions.

---

Goal: Read and analyze all Next.js project configuration files to
understand the technical foundation and flag configuration that hides
errors or weakens the build.

Before stating that a `next.config` option exists, is experimental, or
was removed, check it against the official reference for the installed
version: https://nextjs.org/docs/app/api-reference/config/next-config-js
(Next.js 16.2+ also bundles version-matched docs in
`node_modules/next/dist/docs/`). Never invent an option.

CONFIGURATION FILES TO ANALYZE:

1. **package.json** (REQUIRED — root and every Next.js app):
   - Declared ranges for `next`, `react`, `react-dom` (the INSTALLED
     versions come from `version-validator.md`; never report a range as
     the version)
   - `packageManager` field (pinned pnpm/yarn version for Corepack)
   - `scripts`: `dev`, `build`, `start`, `lint`, `typecheck`, `test`,
     `test:e2e`, `analyze`. Flag `"lint": "next lint"` — `next lint` was
     removed in Next.js 16 (migrate to the ESLint CLI)
   - `engines.node`
   - devDependencies: TypeScript, ESLint, Prettier, testing libraries
   - Count total dependencies (dependencies + devDependencies)
   - Outdated patterns: `next-transpile-modules` (superseded by
     `transpilePackages`), `@next/font` (superseded by `next/font`),
     `next-images`, `next-compose-plugins`, a custom server (`server.js`
     calling `next()`)

2. **next.config.* deep review** (`next.config.ts|js|mjs`; `.cjs` is not
   supported):
   Read the whole file, including wrappers (`withBundleAnalyzer`,
   `withSentryConfig`, `withNextIntl`, `withMDX`, ...).

   RED FLAGS — report each as a Code Quality / Tech Stack risk:
   - `typescript.ignoreBuildErrors: true` — production builds succeed
     with type errors
   - `eslint.ignoreDuringBuilds: true` or any `eslint` key — on Next.js
     versions before 16 it skips lint during `next build`; from Next.js
     16 the `eslint` option was removed together with `next lint`, so the
     key is dead config. Either way, lint must run in CI instead
   - `images.unoptimized: true` without a reason (static export needs it
     or a custom loader)
   - `images.remotePatterns` with wildcard hostnames (`**`) or the
     legacy `images.domains`; `images.dangerouslyAllowSVG: true` without
     a `contentSecurityPolicy`
   - `productionBrowserSourceMaps: true` (exposes source in production —
     confirm it is intentional)
   - `reactStrictMode: false`
   - `poweredByHeader` left default (minor: `x-powered-by` header)
   - Many `experimental.*` flags enabled — list each; experimental flags
     change between minors and block upgrades

   REVIEW (record values, judge fit):
   - `output` (`standalone` / `export` / default)
   - `images` (`remotePatterns`, `localPatterns`, `formats`, `loader`)
   - `headers()` — security headers present? (`Content-Security-Policy`,
     `Strict-Transport-Security`, `X-Content-Type-Options`,
     `Referrer-Policy`, `Permissions-Policy`) — depth is for
     `nextjs-security-audit`; here record presence only
   - `redirects()` / `rewrites()` count
   - `cacheComponents`, `partialPrefetching`, `cacheLife`,
     `cacheHandlers` (caching model — feeds the State Management step)
   - `reactCompiler`, `typedRoutes`
   - `turbopack` / `webpack` customisation
   - `serverExternalPackages`, `transpilePackages`,
     `experimental.optimizePackageImports`
   - `serverActions` (`bodySizeLimit`, `allowedOrigins`)
   - `basePath`, `assetPrefix`, `trailingSlash`, `i18n` (Pages Router)
   - `env` key (build-time inlined values — prefer `.env*` files)
   - `agentRules` / `agentFeedback` / `agentUpgrade` (AI agent
     integration — reported by the harness step)

3. **TypeScript Configuration**:
   - Read `tsconfig.json`
   - `"strict": true` or the individual strict flags
   - `"noUncheckedIndexedAccess"` (bonus)
   - The Next.js TypeScript plugin: `"plugins": [{ "name": "next" }]`
   - `"paths"` aliases (`@/*`) and `"baseUrl"`
   - `"moduleResolution"` (`bundler` is the current create-next-app default)
   - `"include"` covers `next-env.d.ts` and `.next/types/**/*.ts`
   - Note if TypeScript is NOT used (JavaScript project)

4. **ESLint Configuration**:
   - Read `eslint.config.*` (flat config) or legacy `.eslintrc.*`
   - Next.js config present: `eslint-config-next` (base),
     `eslint-config-next/core-web-vitals` (recommended — upgrades Core
     Web Vitals rules to errors), `eslint-config-next/typescript`; or the
     plugin directly: `@next/eslint-plugin-next`
   - Legacy `.eslintrc` with `extends: "next/core-web-vitals"` works on
     older majors but is the pre-flat-config shape — note it
   - `eslint-plugin-react-hooks` (bundled by `eslint-config-next`),
     `eslint-plugin-jsx-a11y`, `typescript-eslint`
   - Important `@next/next/*` rules disabled (e.g. `no-img-element`,
     `no-html-link-for-pages`, `no-sync-scripts`) — list them
   - Monorepo: `settings.next.rootDir` set when Next.js is not at the
     repo root
   - Reference: https://nextjs.org/docs/app/api-reference/config/eslint

5. **Prettier Configuration**:
   - Read `.prettierrc`, `prettier.config.*`, or `"prettier"` in
     package.json
   - `eslint-config-prettier` integration
   - Biome (`biome.json`) as an alternative linter/formatter — record it

6. **Environment Configuration**:
   - `.env.example` / `.env.template` committed
   - Next.js load order files: `.env`, `.env.local`, `.env.development`,
     `.env.production`, `.env.test` — which are committed? `.env*.local`
     must be gitignored; a committed `.env` with real secrets is a
     finding (depth: `nextjs-security-audit`)
   - `NEXT_PUBLIC_` prefix: every variable with this prefix is inlined
     into the client bundle at build time. Grep names for secret-looking
     values exposed this way (`NEXT_PUBLIC_*SECRET*`, `*_KEY`, `*TOKEN*`)
   - Env validation: `@t3-oss/env-nextjs`, `zod` schema in `env.ts`, or
     none
   - Server-only modules guarded with `import 'server-only'`

OUTPUT FORMAT:

Provide structured analysis:
- Next.js declared range: [range] (installed version comes from version-validator)
- React declared range: [range]
- TypeScript: [Yes - version X.X / No] (strict: [Yes/Partial/No]; next plugin: [Yes/No])
- Node.js requirement: [Version or Not specified]
- Package manager: [pnpm/npm/yarn/bun] (packageManager pin: [value/none])
- next.config file: [path] (wrappers: [list])
- Output mode: [default/standalone/export]
- Red flags: [list each with file:line]
- Experimental flags enabled: [list]
- Caching config: cacheComponents [true/false/unset], partialPrefetching [true/false/unset]
- Security headers in next.config: [present: list / none]
- ESLint: [Configured/Missing] (config: [core-web-vitals/base/plugin/legacy next lint])
  * react-hooks rules: [Yes/No]
  * typescript-eslint: [Yes/No/N/A]
  * jsx-a11y: [Yes/No]
- Prettier / Biome: [Configured/Missing]
- Path aliases: [Configured/Missing]
- Environment template: [Present/Missing]; env validation: [library/none]
- `NEXT_PUBLIC_` variables that look secret: [list or none]
- Key risks from configuration
- Recommendations
