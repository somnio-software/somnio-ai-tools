# React Repository Inventory

> Detect repository structure, framework type, monorepo setup, and feature-based folder organization for React projects.

---

Goal: Detect repository structure, component organization, and
validate architecture patterns for clean, maintainable code.

EFFICIENCY REQUIREMENTS:
- Target: ≤ 6 total tool calls for this entire analysis
- Use batch find/ls commands to inventory directory structure in one pass
- Read multiple package.json files per tool call using parallel reads
- Do NOT read individual source files to count them — use find + wc

REPOSITORY STRUCTURE DETECTION:

1. **Framework Detection**:
   - CRA: `react-scripts` in dependencies, no `vite` or `next`
   - Vite: `vite` in devDependencies, `vite.config.*` present
   - Next.js: `next` in dependencies, `next.config.*` present
   - Remix: `@remix-run/react` in dependencies
   - Monorepo: `apps/` directory, OR nx.json, turbo.json, lerna.json

2. **Monorepo Handling**:
   - If monorepo detected: NOTE in report "Monorepo structure detected"
   - FOCUS analysis on the main/core application
   - Don't penalize for monorepo structure
   - Suggest analyzing each app separately if needed

3. **Standard Project Structure**:
   - Check for `src/` directory
   - Check for `public/` directory
   - Check for entry point: `src/main.tsx`, `src/index.tsx`,
     `src/App.tsx`

FOLDER ORGANIZATION ANALYSIS:

4. **Feature-Based Organization Check** (PREFERRED):
   - Detect if `src/features/` or `src/modules/` exists
   - Check for self-contained feature folders:
     * `src/features/auth/`
     * `src/features/dashboard/`
     * `src/features/users/`
   - Note flat structure if all components are in `src/components/`

5. **Directory Inventory**:
   - List top-level directories in `src/`
   - Count: components, hooks, pages/routes, services, types, utils
   - Check for `shared/` or `common/` directory
   - Check for `stores/` or `state/` directory

COMPONENT FILE SIZE ANALYSIS:

6. **Component File Size**:
   For all `*.tsx` files in `src/`:
   - Files < 150 lines: Healthy
   - Files 150-300 lines: Acceptable
   - Files > 300 lines: FLAG for review
   - Files > 500 lines: CRITICAL FLAG

NAMING CONVENTIONS:

7. **Naming Check**:
   - PascalCase component files: `UserProfile.tsx` ✓
   - kebab-case utility files: `format-date.ts` ✓
   - Barrel exports: `index.ts` in feature folders ✓
   - Flag: `userProfile.tsx`, `UserProfile.js` (no TypeScript)

OUTPUT FORMAT:

Provide structured analysis:
- Framework detected: [CRA/Vite/Next.js/Remix/Other]
- If monorepo: note detected and recommend separate analysis
- Total components count: [Number]
- Organization pattern: [Feature-based/Component-based/Flat/Mixed]
- Feature-based structure: [Yes/Partial/No]
- Component file size analysis:
  * Files < 150 lines: [Count]
  * Files 150-300 lines: [Count]
  * Files > 300 lines: [Count] (flag for review)
  * Files > 500 lines: [Count] (critical - list files)
- Naming convention compliance: [XX]%
- Shared/common modules: [Present/Missing]
- Risks identified
- Recommendations

SCORING GUIDANCE:

Strong (85-100):
- Feature-based organization present
- Component files reasonably sized (most < 300 lines)
- Consistent naming conventions
- Shared/common modules present

Fair (70-84):
- Mixed organization (some features, some flat)
- Some large component files
- Minor naming inconsistencies

Weak (0-69):
- Completely flat structure
- Multiple oversized files
- Inconsistent or wrong naming conventions
