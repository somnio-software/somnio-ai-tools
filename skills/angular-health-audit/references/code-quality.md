# Angular Code Quality Analysis

> Analyze Angular ESLint configuration, Prettier setup, TypeScript strict mode, Angular strict templates, and code quality enforcement patterns.

---

Goal: Analyze the ESLint and TypeScript configuration, Prettier
setup, and code quality enforcement to evaluate overall code quality
infrastructure.

ANALYSIS TARGETS:

1. **ESLint Configuration**:
   - Read `.eslintrc.*` or `eslint.config.*` (flat config)
   - Check for required Angular plugins:
     * `@angular-eslint/eslint-plugin` — Angular TS rules
     * `@angular-eslint/eslint-plugin-template` — HTML template rules
     * `@typescript-eslint` — TypeScript linting
   - Verify component/template overrides are wired (the `*.html` files
     are linted by the template parser/plugin)
   - Check for meaningful Angular rules, e.g.
     `@angular-eslint/no-output-native`,
     `@angular-eslint/use-lifecycle-interface`,
     `@angular-eslint/template/no-negated-async`
   - Flag legacy `tslint.json` — TSLint is deprecated (removed from the
     Angular toolchain); recommend migrating to `angular-eslint`
   - Flag disabled rules that are important for quality

2. **Prettier Setup**:
   - Check `.prettierrc`, `prettier.config.*`, or `"prettier"` key in
     package.json
   - Verify `eslint-config-prettier` is configured (prevents conflicts)
   - Check for a Prettier ignore file (`.prettierignore`)
   - Note if Prettier is entirely missing

3. **TypeScript Strict Mode + Angular Template Type-Checking**:
   - Read `tsconfig.json`
   - Check `"strict": true` — covers noImplicitAny, strictNullChecks,
     strictFunctionTypes, etc.
   - If `strict` not set, check individual flags
   - Check `angularCompilerOptions.strictTemplates` (full template type
     checking) and `strictInjectionParameters`
   - Count TypeScript errors: `npx tsc --noEmit 2>&1 | grep error | wc -l`
   - Flag any usage of `// @ts-ignore` or `// @ts-expect-error` (count)
   - Check for `skipLibCheck` setting

4. **Code Quality Metrics**:
   - Count `any` type occurrences in source:
     `grep -rn ": any" src/ --include="*.ts" | wc -l`
   - Count `eslint-disable` comments:
     `grep -rn "eslint-disable" src/ | wc -l`
   - Check for `console.log` in source (not specs):
     `grep -rn "console.log" src/ --include="*.ts" --exclude="*.spec.ts"
     | wc -l`
   - Count `any` in templates via untyped bindings is not greppable —
     rely on `strictTemplates` instead

5. **Lint Script**:
   - Check `package.json` scripts for `"lint"` (typically `ng lint`)
   - Verify lint targets the project source and templates
   - Check if lint runs in CI (from cicd-analysis.md results)

6. **Format Check**:
   - Check `package.json` scripts for `"format"` or `"format:check"`
   - Verify Prettier can run on the project

OUTPUT FORMAT:

Provide structured analysis:
- angular-eslint configured: [Yes/No]
- template plugin (@angular-eslint/eslint-plugin-template): [Yes/No]
- @typescript-eslint plugin: [Yes/No]
- Legacy TSLint present: [Yes (deprecated)/No]
- Prettier configured: [Yes/No]
- eslint-config-prettier: [Yes/No]
- TypeScript strict: [Yes/Partial/No]
- Angular strictTemplates: [Yes/No]
- TypeScript errors: [XX]
- any type count: [XX]
- eslint-disable count: [XX]
- console.log in source: [XX]
- Lint script present: [Yes/No]
- Risks identified
- Recommendations

SCORING GUIDANCE:

Strong (85-100):
- angular-eslint with the template plugin and typescript-eslint
- TypeScript strict mode AND strictTemplates enabled
- Prettier configured
- Minimal any usage and disabled rules

Fair (70-84):
- ESLint configured but missing the template plugin
- strict on but strictTemplates off
- Some any usage

Weak (0-69):
- No ESLint / still on deprecated TSLint / minimal configuration
- strict mode off
- High any usage
- No code formatting enforcement
