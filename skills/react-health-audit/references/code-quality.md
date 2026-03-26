# React Code Quality Analysis

> Analyze ESLint configuration, Prettier setup, TypeScript strict mode, and code quality enforcement patterns.

---

Goal: Analyze the ESLint and TypeScript configuration, Prettier
setup, and code quality enforcement to evaluate overall code quality
infrastructure.

ANALYSIS TARGETS:

1. **ESLint Configuration**:
   - Read `.eslintrc.*` or `eslint.config.*`
   - Check for required React plugins:
     * `eslint-plugin-react` — React-specific rules
     * `eslint-plugin-react-hooks` — hooks rules enforcement
     * `eslint-plugin-jsx-a11y` — accessibility rules
     * `@typescript-eslint` — TypeScript linting
   - Verify `react-hooks/rules-of-hooks: error` is set
   - Verify `react-hooks/exhaustive-deps: warn` is set
   - Check for `no-unused-vars` or `@typescript-eslint/no-unused-vars`
   - Flag disabled rules that are important for quality

2. **Prettier Setup**:
   - Check `.prettierrc`, `prettier.config.*`, or `"prettier"` key in
     package.json
   - Verify `eslint-config-prettier` is configured (prevents conflicts)
   - Check for Prettier ignore file (`.prettierignore`)
   - Note if Prettier is entirely missing

3. **TypeScript Strict Mode**:
   - Read `tsconfig.json`
   - Check `"strict": true` — covers: noImplicitAny, strictNullChecks,
     strictFunctionTypes, etc.
   - If `strict` not set, check individual flags
   - Count TypeScript errors: `npx tsc --noEmit 2>&1 | grep error | wc -l`
   - Flag any usage of `// @ts-ignore` or `// @ts-expect-error` (count)
   - Check for `skipLibCheck` setting

4. **Code Quality Metrics**:
   - Count `any` type occurrences in source:
     `grep -r ": any" src/ --include="*.ts" --include="*.tsx" | wc -l`
   - Count `eslint-disable` comments:
     `grep -r "eslint-disable" src/ | wc -l`
   - Check for console.log in source (not tests):
     `grep -r "console.log" src/ --include="*.tsx" --include="*.ts"
     --exclude="*.test.*" --exclude="*.spec.*" | wc -l`

5. **Lint Script**:
   - Check `package.json` scripts for `"lint"` or `"lint:check"`
   - Verify lint script targets `src/` directory
   - Check if lint runs in CI (from cicd-analysis.md results)

6. **Format Check**:
   - Check `package.json` scripts for `"format"` or `"format:check"`
   - Verify Prettier can run on the project

OUTPUT FORMAT:

Provide structured analysis:
- ESLint configured: [Yes/No]
- react-hooks plugin: [Yes/No]
- jsx-a11y plugin: [Yes/No]
- @typescript-eslint plugin: [Yes/No/N/A]
- Prettier configured: [Yes/No]
- eslint-config-prettier: [Yes/No]
- TypeScript strict: [Yes/Partial/No/N/A]
- TypeScript errors: [XX]
- any type count: [XX]
- eslint-disable count: [XX]
- console.log in source: [XX]
- Lint script present: [Yes/No]
- Risks identified
- Recommendations

SCORING GUIDANCE:

Strong (85-100):
- ESLint with react-hooks, accessibility, TypeScript plugins
- TypeScript strict mode enabled
- Prettier configured
- Minimal any usage and disabled rules

Fair (70-84):
- ESLint configured but missing some plugins
- TypeScript present but strict mode off
- Some any usage

Weak (0-69):
- No ESLint or minimal configuration
- No TypeScript
- High any usage
- No code formatting enforcement
