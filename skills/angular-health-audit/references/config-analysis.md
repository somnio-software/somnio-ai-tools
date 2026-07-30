# Angular Configuration Analysis

> Read and analyze Angular/Node.js configuration files for version info, dependencies, TypeScript setup, Angular ESLint, Prettier, angular.json, and build/budget configuration.

---

Goal: Read and analyze all Angular project configuration files to
understand the technical foundation and tooling setup.

CONFIGURATION FILES TO ANALYZE:

1. **package.json** (REQUIRED):
   - Extract `@angular/core` version (the Angular major version) and
     other `@angular/*` package versions
   - Extract `@angular/cli`, `@angular-devkit/build-angular`, `rxjs`,
     `zone.js`, `typescript` versions
   - Extract devDependencies (ESLint / `@angular-eslint`, testing libs)
   - Check `scripts` for `ng build`, `ng test`, `ng lint`, `ng serve`
   - Check `engines` field for Node.js version requirement
   - Count total dependencies (dependencies + devDependencies)
   - Identify outdated patterns (Angular major well behind current LTS,
     RxJS 6 with old operator style, deprecated `@angular/http`)
   - Note the Angular version's support status (out-of-support majors are
     a forward-looking risk)

2. **angular.json** (REQUIRED for Angular CLI projects):
   - Enumerate `projects` (application vs library types)
   - For the main app, read `architect`/`targets`:
     * `build` builder (`@angular-devkit/build-angular:application` or
       `:browser`, or `@angular/build:application` esbuild)
     * `configurations.production`: `optimization`, `outputHashing`,
       `sourceMap`, `budgets`, `fileReplacements`
     * `test` builder (Karma or a Jest builder)
   - Note whether `budgets` are defined (bundle-size guardrails)

3. **TypeScript Configuration**:
   - Read `tsconfig.json` (and `tsconfig.app.json` / `tsconfig.spec.json`)
   - Check `"strict": true` or individual strict flags
   - Check `"target"`, `"lib"`, `"module"`, `"moduleResolution"`
   - Check `"paths"` for alias configuration
   - Check `angularCompilerOptions`: `strictTemplates`,
     `strictInjectionParameters`, `strictInputAccessModifiers`,
     `fullTemplateTypeCheck` — Angular's template type-checking depth

4. **ESLint Configuration**:
   - Read `.eslintrc.*` or `eslint.config.*` (flat config)
   - Check for `@angular-eslint/eslint-plugin` (TS rules)
   - Check for `@angular-eslint/eslint-plugin-template` (HTML template rules)
   - Check for `@typescript-eslint` plugin
   - Flag legacy `tslint.json` — TSLint is deprecated and unsupported; a
     project still on TSLint should migrate to `angular-eslint`
   - Note any disabled rules important for Angular

5. **Prettier Configuration**:
   - Read `.prettierrc`, `prettier.config.*`, or `"prettier"` in
     package.json
   - Check if Prettier is configured at all
   - Check for Prettier + ESLint integration (`eslint-config-prettier`)

6. **Environment Configuration**:
   - Check `src/environments/environment.ts` and
     `environment.prod.ts` (or named env files)
   - Verify environment swapping is wired via `fileReplacements` in
     `angular.json` production configuration
   - Check that no secrets are committed in environment files (env files
     are bundled into the client — they must not hold real secrets)

OUTPUT FORMAT:

Provide structured analysis:
- Angular version: [Version] (support status: in-support / EOL)
- TypeScript: [Version]
- RxJS version: [Version]
- Node.js requirement: [Version or Not specified]
- Package manager: [npm/yarn/pnpm]
- Build system: [Angular CLI application/browser builder — esbuild/webpack]
- angular.json budgets defined: [Yes/No]
- ESLint (angular-eslint): [Configured/Missing]
  * template plugin: [Yes/No]
  * typescript-eslint: [Yes/No]
  * legacy TSLint present: [Yes (deprecated)/No]
- Prettier: [Configured/Missing]
- TypeScript strict mode: [Yes/Partial/No]
- Angular strictTemplates: [Yes/No]
- Path aliases: [Configured/Missing]
- Environment files + fileReplacements: [Present/Missing]
- Key risks from configuration
- Recommendations
