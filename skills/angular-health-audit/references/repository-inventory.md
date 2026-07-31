# Angular Repository Inventory

> Detect repository structure, Angular workspace layout, NgModules vs standalone organization, and feature-based folder organization for modern Angular projects.

---

Goal: Detect repository structure, module/component organization, and
validate architecture patterns for clean, maintainable code.

EFFICIENCY REQUIREMENTS:
- Target: ≤ 6 total tool calls for this entire analysis
- Use batch find/ls commands to inventory directory structure in one pass
- Read `angular.json` and package.json files per tool call using parallel reads
- Do NOT read individual source files to count them — use find + wc

REPOSITORY STRUCTURE DETECTION:

1. **Framework Detection** (this is modern Angular 2+, NOT AngularJS 1.x):
   - Angular CLI app: `@angular/core` in dependencies AND `angular.json`
     present at root
   - Confirm it is NOT AngularJS 1.x: absence of `angular` (1.x) global,
     no `bower.json`, no `.controller(`/`$scope` patterns (if those
     dominate, stop and recommend `angularjs-health-audit`)
   - Multi-project workspace / monorepo: multiple entries under the
     `projects` key in `angular.json`, OR `apps/`+`libs/` directories,
     OR `nx.json` (Nx workspace)

2. **Workspace / Monorepo Handling**:
   - If a multi-project workspace or Nx monorepo is detected: NOTE in the
     report "Angular multi-project workspace detected"
   - FOCUS analysis on the main/default application (`defaultProject` or
     the first `application`-type project in `angular.json`)
   - Don't penalize for workspace structure
   - Suggest analyzing each project separately if needed

3. **Standard Project Structure**:
   - Check for `src/` directory and `src/app/`
   - Check for `src/assets/` and `src/environments/`
   - Check for entry point: `src/main.ts`, and the root component
     (`src/app/app.component.ts`) plus `app.module.ts` (NgModule) or
     `app.config.ts` + `bootstrapApplication` (standalone)

4. **NgModule vs Standalone Detection**:
   - Count `@NgModule` declarations: `grep -rl "@NgModule" src/ | wc -l`
   - Count standalone components:
     `grep -rl "standalone: true" src/ | wc -l`
   - Note the dominant pattern (classic NgModules, standalone-first, or
     mixed migration in progress). Standalone is the modern default
     (Angular 15+); a fully standalone app is a positive signal.

FOLDER ORGANIZATION ANALYSIS:

5. **Feature-Based Organization Check** (PREFERRED):
   - Detect if `src/app/features/` or feature modules exist
   - Check for self-contained feature folders / feature modules:
     * `src/app/features/auth/`
     * `src/app/features/dashboard/`
     * `src/app/features/users/`
   - Check for `core/` (singleton services, guards, interceptors) and
     `shared/` (reusable components/pipes/directives) modules
   - Note flat structure if all components sit directly in `src/app/`

6. **Directory Inventory**:
   - List top-level directories in `src/app/`
   - Count: components (`*.component.ts`), services (`*.service.ts`),
     modules (`*.module.ts`), directives (`*.directive.ts`),
     pipes (`*.pipe.ts`), guards (`*.guard.ts`), models/interfaces
   - Check for `core/` or `shared/` module
   - Check for a state directory (`store/`, `state/`, `+state/`)

COMPONENT FILE SIZE ANALYSIS:

7. **Component File Size**:
   For all `*.component.ts` files in `src/` (and their `.html` templates):
   - Files < 150 lines: Healthy
   - Files 150-300 lines: Acceptable
   - Files > 300 lines: FLAG for review (god-component risk)
   - Files > 500 lines: CRITICAL FLAG
   - Also flag component templates (`*.component.html`) > 200 lines

NAMING CONVENTIONS (Angular style guide):

8. **Naming Check**:
   - kebab-case file names with type suffix: `user-profile.component.ts` ✓
   - Class names PascalCase with type suffix: `UserProfileComponent` ✓
   - Services: `auth.service.ts` → `AuthService` ✓
   - Selectors kebab-case with a project prefix: `app-user-profile` ✓
   - Barrel exports: `index.ts` / `public-api.ts` in libs ✓
   - Flag: `UserProfile.ts` (no suffix), files with no type suffix at all

OUTPUT FORMAT:

Provide structured analysis:
- Framework detected: Modern Angular (Angular CLI) [confirm NOT AngularJS 1.x]
- If multi-project/Nx workspace: note detected and recommend separate analysis
- Total components count: [Number]
- NgModule count / standalone-component count: [Numbers]
- Dominant module pattern: [NgModules/Standalone/Mixed]
- Organization pattern: [Feature-based/Layered/Flat/Mixed]
- Feature-based structure: [Yes/Partial/No]
- core/ and shared/ modules: [Present/Missing]
- Component file size analysis:
  * Files < 150 lines: [Count]
  * Files 150-300 lines: [Count]
  * Files > 300 lines: [Count] (flag for review)
  * Files > 500 lines: [Count] (critical - list files)
  * Templates > 200 lines: [Count]
- Naming convention compliance: [XX]%
- Risks identified
- Recommendations

SCORING GUIDANCE:

Strong (85-100):
- Feature-based organization with core/ and shared/ modules
- Component files reasonably sized (most < 300 lines)
- Consistent Angular-style-guide naming (kebab-case + type suffixes)
- Coherent module strategy (all NgModule or all standalone, not chaotic mix)

Fair (70-84):
- Mixed organization (some features, some flat)
- Some large components or templates
- Minor naming inconsistencies or partial standalone migration

Weak (0-69):
- Completely flat structure
- Multiple oversized components / god-components
- Inconsistent or wrong naming conventions
