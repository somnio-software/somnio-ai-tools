# React Configuration Analysis

> Read and analyze React/Node.js configuration files for version info, dependencies, TypeScript setup, ESLint, Prettier, and bundler configuration.

---

Goal: Read and analyze all React project configuration files to
understand the technical foundation and tooling setup.

CONFIGURATION FILES TO ANALYZE:

1. **package.json** (REQUIRED):
   - Extract React version and major dependencies
   - Extract devDependencies (ESLint, TypeScript, testing libraries)
   - Check `scripts` for build, test, lint, typecheck commands
   - Check `engines` field for Node.js version requirement
   - Check `browserslist` configuration
   - Count total dependencies (dependencies + devDependencies)
   - Identify outdated patterns (e.g., react-scripts < 5, old React 16)

2. **TypeScript Configuration**:
   - Read `tsconfig.json` if present
   - Check `"strict": true` or individual strict flags
   - Check `"target"`, `"lib"`, `"module"` settings
   - Check `"paths"` for alias configuration
   - Check `"jsx"` setting (`react-jsx` preferred over `react`)
   - Note if TypeScript is NOT used (JavaScript project)

3. **ESLint Configuration**:
   - Read `.eslintrc.*` or `eslint.config.*` or `"eslintConfig"` in
     package.json
   - Check for `eslint-plugin-react-hooks` plugin
   - Check for `eslint-plugin-react` plugin
   - Check for `@typescript-eslint` plugin if TypeScript project
   - Check for `jsx-a11y` plugin for accessibility
   - Note any disabled rules that are important for React

4. **Prettier Configuration**:
   - Read `.prettierrc`, `prettier.config.*`, or `"prettier"` in
     package.json
   - Check if Prettier is configured at all
   - Check for Prettier + ESLint integration (eslint-config-prettier)

5. **Bundler Configuration**:
   - Vite: Read `vite.config.*`
     * Check plugins (react, typescript, path aliases)
     * Check build optimization settings
   - Next.js: Read `next.config.*`
     * Check experimental features
     * Check image domains, redirects
   - CRA: Note that configuration is in `react-scripts` (abstracted)

6. **Environment Configuration**:
   - Check for `.env.example` or `.env.template`
   - Verify environment variables use `REACT_APP_` prefix (CRA) or
     `VITE_` prefix (Vite) or `NEXT_PUBLIC_` (Next.js)
   - Check for `.env` committed to repo (security risk)

OUTPUT FORMAT:

Provide structured analysis:
- React version: [Version]
- TypeScript: [Yes - version X.X / No]
- Node.js requirement: [Version or Not specified]
- Package manager: [npm/yarn/pnpm]
- Bundler/Framework: [CRA/Vite/Next.js/Remix]
- ESLint: [Configured/Missing]
  * react-hooks plugin: [Yes/No]
  * typescript-eslint: [Yes/No/N/A]
- Prettier: [Configured/Missing]
- TypeScript strict mode: [Yes/Partial/No/N/A]
- Path aliases: [Configured/Missing]
- Environment template: [Present/Missing]
- Key risks from configuration
- Recommendations
