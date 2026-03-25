# Flutter Documentation Analysis

> Review project documentation, build instructions, environment setup, and technical documentation for Flutter projects (single app or multi-app monorepos).

---

Goal: Review project documentation, build instructions, environment
setup, and technical documentation for single app or multi-app
repositories.

EFFICIENCY REQUIREMENTS:
- Target: ≤ 6 total tool calls for this entire analysis
- Read multiple README/doc files per tool call using parallel reads
- Use batch find commands to locate all documentation files at once
- Reference cached artifacts from previous steps when available

IMPORTANT EXCLUSIONS:
- Do NOT recommend operational documentation (runbooks,
  troubleshooting guides, incident response)
- Do NOT recommend deployment procedures or operational workflows
- Do NOT recommend monitoring or performance documentation
- Focus ONLY on technical documentation (build instructions,
  environment setup, API docs, code documentation)

MONOREPO DETECTION:
- First detect repository structure: single app (app/) or multi-app
  monorepo (apps/app1/, apps/app2/, etc.)
- If apps/ directory exists, analyze each app individually
- If packages/ directory exists, analyze each package individually

SINGLE APP ANALYSIS:
- Analyze technical documentation and setup:
  * Read app/README.md completely
  * Check README for build instructions and --dart-define usage for
    environment variables
  * Check for app/sample.env.jsonc or .env.example
  * Search for CHANGELOG.md or CHANGELOG
  * Check for technical onboarding documentation in any README files
  * Look for l10n.yaml (internationalization config)
  * Important: Do NOT recommend adding new languages or translations
  * Do NOT recommend CODEOWNERS or SECURITY.md files - these are
    governance decisions, not technical requirements
  * Do NOT recommend operational documentation (runbooks,
    troubleshooting, deployment procedures)

MULTI-APP MONOREPO ANALYSIS:
- Root-level documentation:
  * Read root README.md completely (main project documentation)
  * Check root README for overall build instructions and --dart-define
    usage
  * Check for root-level sample.env.jsonc or .env.example
  * Search for root-level CHANGELOG.md or CHANGELOG
  * Check for root-level technical onboarding documentation
  * Look for root-level l10n.yaml (shared internationalization config)
  * Important: Do NOT recommend adding new languages or translations
  * Do NOT recommend CODEOWNERS or SECURITY.md files - these are
    governance decisions, not technical requirements
  * Do NOT recommend operational documentation (runbooks,
    troubleshooting, deployment procedures)
- Per-app documentation:
  * For each app in apps/ directory:
    - Read apps/<app_name>/README.md (if exists)
    - Check for app-specific build instructions
    - Check for apps/<app_name>/sample.env.jsonc or .env.example
    - Check for app-specific CHANGELOG.md or CHANGELOG
    - Check for app-specific technical onboarding documentation
    - Look for apps/<app_name>/l10n.yaml (app-specific
      internationalization config)
    - Important: Do NOT recommend adding new languages or translations
    - Do NOT recommend CODEOWNERS or SECURITY.md files - these are
      governance decisions, not technical requirements
    - Do NOT recommend operational documentation (runbooks,
      troubleshooting, deployment procedures)
- Documentation consistency:
  * Compare documentation quality across apps
  * Check for consistent build instruction patterns
  * Verify environment variable documentation consistency
  * Important: Do NOT recommend adding new languages or translations

PACKAGE ANALYSIS (if packages/ exists):
- For each package in packages/ directory:
  * Read packages/<package_name>/README.md (if exists)
  * Check for package-specific documentation
  * Look for package-specific l10n.yaml if applicable

Output format:
- Repository structure type (single app / multi-app monorepo)
- README completeness and quality (per app if multi-app)
- Build instructions availability (per app if multi-app)
- Environment variable documentation (per app if multi-app)
- Changelog presence and format (per app if multi-app)
- Onboarding documentation status (per app if multi-app)
- Internationalization configuration (per app if multi-app)
- Missing documentation files (per app if multi-app)
- Documentation consistency across apps/packages (if multi-app)
- Root vs app-specific documentation patterns (if multi-app)
