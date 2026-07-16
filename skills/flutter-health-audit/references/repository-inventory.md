# Flutter Repository Inventory

> Detect repository structure, platform folders, monorepo packages, and feature organization for Flutter projects (single app or multi-app monorepos).

---

Goal: Detect repository structure, platform folders, monorepo packages,
and feature organization for single app or multi-app repositories.

EFFICIENCY REQUIREMENTS:
- Target: ≤ 6 total tool calls for this entire analysis
- Use batch find/ls commands to inventory directory structure in one pass
- Read multiple pubspec.yaml files per tool call using parallel reads
- Do NOT read individual source files to count them — use find + wc

IMPORTANT EXCLUSIONS:
- Do NOT analyze, recommend, or consider CODEOWNERS files
- Do NOT analyze, recommend, or consider SECURITY.md files
- These are governance decisions, not technical requirements

MONOREPO DETECTION:
- First detect repository structure: single app (app/) or multi-app
  monorepo (apps/app1/, apps/app2/, etc.)
- If apps/ directory exists, analyze each app individually
- If packages/ directory exists, analyze each package individually

SINGLE APP INVENTORY:
- Platform folders present in app/ (android/, ios/, web/, macos/,
  windows/, linux/)
- All packages in app/packages/ directory (list names)
- All feature folders in app/lib/ (count directories, exclude gen/,
  l10n/, utils/, extensions/, constants/)
- Presence of .fvm/ directory or .fvm/fvm_config.json

MULTI-APP MONOREPO INVENTORY:
- Root-level structure:
  * Overall repository structure type (multi-app monorepo)
  * Root-level packages/ directory (if exists)
  * Root-level .fvm/ directory or .fvm/fvm_config.json
  * Root-level feature folders (if any)
- Per-app inventory:
  * For each app in apps/ directory:
    - Platform folders present in apps/<app_name>/ (android/, ios/,
      web/, macos/, windows/, linux/)
    - All packages in apps/<app_name>/packages/ directory (list names)
    - All feature folders in apps/<app_name>/lib/ (count directories,
      exclude gen/, l10n/, utils/, extensions/, constants/)
    - Presence of apps/<app_name>/.fvm/ directory or
      apps/<app_name>/.fvm/fvm_config.json
- Cross-app analysis:
  * Compare platform support across apps
  * Compare package usage across apps
  * Compare feature organization across apps
  * Identify shared vs app-specific packages
  * Identify shared vs app-specific features

PACKAGE ANALYSIS (if packages/ exists):
- For each package in packages/ directory:
  * Package name and purpose
  * Platform folders present in packages/<package_name>/ (if applicable)
  * Feature folders in packages/<package_name>/lib/ (if applicable)
  * Package-specific .fvm/ configuration (if applicable)

FOLDER ORGANIZATION / ARCHITECTURE ANALYSIS:

Judge architecture quality, not just structure counts:

- **Feature-folder self-containment**: For each feature folder found
  in `lib/` (or `apps/<app_name>/lib/`), check whether it bundles its
  own concerns (e.g. `feature_x/{data,domain,presentation}` or
  `feature_x/{bloc,view,model}`) rather than being a bare
  widget-only folder with logic scattered elsewhere.
- **Layered split detection**: Check for a `data/`, `domain/`, and
  `presentation/` (or `ui/`) split, either at the app root or inside
  each feature folder:
  `find . -type d \( -iname 'data' -o -iname 'domain' -o -iname 'presentation' \) ! -path '*/.dart_tool/*' ! -path '*/build/*'`
- **Dependency-direction violations**: Flag cases where a
  presentation-layer file imports a data-layer file directly, skipping
  the domain layer:
  `grep -rlE "import '.*\/data\/" $(find . -path '*/presentation/*' -name '*.dart' ! -path '*/.dart_tool/*' ! -path '*/build/*') 2>/dev/null`
  Treat any hits as a dependency-direction violation to flag in Risks.
- Note if there is no layered split at all — this is not automatically
  a defect for small apps, but must be stated explicitly so the
  Architecture section is not scored on an assumption.

Output format:
- Repository structure type (single app / multi-app monorepo)
- Provide exact counts for each category (per app if multi-app)
- List specific package names found (per app if multi-app)
- Note any missing expected directories (per app if multi-app)
- Document the overall repository structure type
- Feature-based structure: [Yes/Partial/No]
- Layered architecture (data/domain/presentation) detected:
  [Yes/Partial/No] (per app if multi-app)
- Dependency-direction violations: [Count and list files, or "None found"]
- Cross-app consistency analysis (if multi-app)
- Shared vs app-specific resources breakdown (if multi-app)
- Platform support matrix across apps (if multi-app)
- Package usage patterns across apps (if multi-app)

ARCHITECTURE SCORING GUIDANCE (0-100):

Strong (85-100):
- Clear, consistent layered split (data/domain/presentation) at the
  app or feature level
- Feature folders are self-contained (own data/domain/presentation or
  equivalent)
- No dependency-direction violations found
- Consistent architecture across apps/packages (if multi-app)

Fair (70-84):
- Partial layered split — present in some features but not others
- Minor dependency-direction violations (isolated cases)
- Feature folders mostly self-contained with some exceptions

Weak (0-69):
- No layered split and no self-contained feature folders
- Widespread dependency-direction violations
- Inconsistent structure across apps/packages (if multi-app) with no
  discernible pattern
