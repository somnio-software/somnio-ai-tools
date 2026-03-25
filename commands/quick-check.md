---
description: "Quick project health assessment (2-3 min)"
argument-hint: "[flutter|nestjs]"
allowed-tools: ["Bash", "Glob", "Grep", "Read", "Write"]
---

# Somnio Quick Check

You are a fast project health assessor. Your job is to read key configuration
files and source code indicators, then produce a quick health score without
running any external tools, installing anything, or performing deep analysis.
Complete the entire check in under 3 minutes.

## Phase 1 — Detect Project Type

If `$1` is provided, use it as the project type (`flutter` or `nestjs`).

Otherwise, auto-detect:

1. Check for `pubspec.yaml` in the current directory. If found, this is a
   Flutter project.
2. Check for `package.json` in the current directory. If found, read it and
   check for `@nestjs/core`. If present, this is a NestJS project.
3. If neither is detected, report that quick-check only supports Flutter and
   NestJS projects and stop.

## Phase 2 — Gather Signals

Read the following files and collect data points. Do NOT run any shell commands
for tool installation or analysis tools. Only use Read, Glob, and Grep.

### Flutter Projects

Collect these signals:

1. **Flutter/Dart version**: Read `pubspec.yaml` for SDK constraints. Check
   for `.fvmrc` or `.fvm/fvm_config.json` for FVM usage.
2. **Dependencies**: Read `pubspec.yaml` -- count direct dependencies and
   dev_dependencies. Flag if more than 30 direct dependencies.
3. **Architecture**: Use Grep to check for common patterns -- look for
   directories like `bloc/`, `cubit/`, `provider/`, `riverpod/`,
   `repositories/`, `services/`, `domain/`, `data/`, `presentation/`.
4. **Testing**: Use Glob for `test/**/*_test.dart` -- count test files. Check
   if `flutter_test` or `mocktail`/`mockito` are in dev_dependencies.
5. **CI/CD**: Check for `.github/workflows/*.yml`, `.gitlab-ci.yml`,
   `bitrise.yml`, `codemagic.yaml`, or `Fastfile`.
6. **Code generation**: Check `pubspec.yaml` for `build_runner`,
   `freezed`, `json_serializable`, `auto_route_generator`.
7. **Linting**: Check for `analysis_options.yaml`. Read it and note if
   `flutter_lints`, `very_good_analysis`, or `lint` is used.
8. **Documentation**: Check for `README.md` and its approximate length.
9. **Git hygiene**: Check for `.gitignore` and whether common Flutter
   ignores are present (`*.g.dart`, `build/`, `.dart_tool/`).
10. **Monorepo signals**: Check for `melos.yaml` or a `packages/` directory.

### NestJS Projects

Collect these signals:

1. **Node/NestJS version**: Read `package.json` for NestJS version, engines
   field. Check for `.nvmrc` or `.node-version`.
2. **Dependencies**: Read `package.json` -- count dependencies and
   devDependencies. Flag if more than 40 direct dependencies.
3. **Architecture**: Use Grep to check for modules, controllers, services,
   guards, interceptors, pipes. Look for directory patterns like `modules/`,
   `common/`, `shared/`, `config/`.
4. **Testing**: Use Glob for `**/*.spec.ts` and `**/*.e2e-spec.ts` -- count
   test files. Check for `jest` in devDependencies.
5. **CI/CD**: Check for `.github/workflows/*.yml`, `.gitlab-ci.yml`,
   `Dockerfile`, `docker-compose.yml`.
6. **TypeScript config**: Check for `tsconfig.json` -- note strict mode
   settings.
7. **Linting**: Check for `.eslintrc*` or `eslint.config.*`. Check for
   `prettier` in devDependencies.
8. **Documentation**: Check for `README.md` and its approximate length.
   Check for Swagger/OpenAPI setup (`@nestjs/swagger` in dependencies).
9. **Database/ORM**: Check for `@nestjs/typeorm`, `@prisma/client`,
   `@nestjs/mongoose`, `@nestjs/sequelize` in dependencies.
10. **Environment config**: Check for `.env.example`, `@nestjs/config`
    in dependencies. Flag if `.env` is tracked (not in `.gitignore`).

## Phase 3 — Score Calculation

Rate each area on a simple 3-point scale:

- **Good** (2 points): Signal is present and healthy
- **Fair** (1 point): Signal is present but has issues
- **Missing** (0 points): Signal is absent

**Scoring areas** (10 areas, max 20 points):

| # | Area | Good | Fair | Missing |
|---|------|------|------|---------|
| 1 | SDK/Version management | Pinned + version manager | Pinned, no manager | No constraint |
| 2 | Dependency count | Reasonable count | Slightly high | Excessive or none |
| 3 | Architecture | Clear patterns found | Some structure | No discernible pattern |
| 4 | Testing | Tests exist + mocking lib | Few tests | No tests |
| 5 | CI/CD | Pipeline config found | Partial config | None |
| 6 | Code generation/TypeScript | Properly configured | Partial | Not applicable or broken |
| 7 | Linting | Strict lint rules | Default rules | No linting |
| 8 | Documentation | README > 50 lines | README exists | No README |
| 9 | Git hygiene | Proper .gitignore | Basic .gitignore | Missing or insufficient |
| 10 | Advanced setup | Monorepo/ORM/Swagger | Partial | None |

**Overall score**: Sum points, convert to percentage (points / 20 * 100),
then map to a grade:

- **90-100%**: A - Excellent project health
- **75-89%**: B - Good, minor improvements possible
- **50-74%**: C - Fair, several areas need attention
- **25-49%**: D - Poor, significant improvements needed
- **0-24%**: F - Critical, fundamental setup missing

## Phase 4 — Report Output

Write the report to `./reports/quick-check-report.md` with this format:

```
# Quick Health Check Report

**Project**: [project name from pubspec.yaml or package.json]
**Type**: [Flutter / NestJS]
**Date**: [current date]
**Overall Grade**: [letter grade] ([percentage]%)

## Score Breakdown

| Area | Status | Score | Notes |
|------|--------|-------|-------|
| SDK/Version management | [Good/Fair/Missing] | [0-2] | [brief note] |
| ... | ... | ... | ... |

**Total: [X]/20 ([percentage]%)**

## Key Findings

### Strengths
- [top 3 strengths]

### Areas for Improvement
- [top 3 areas needing work]

### Recommendations
- [3 actionable next steps, prioritized]

---
*Quick check completed in ~[time]. For a comprehensive audit, run
`/somnio:audit`.*
```

Also print the summary (grade, score, top finding) to the conversation so the
user sees it immediately without opening the file.
