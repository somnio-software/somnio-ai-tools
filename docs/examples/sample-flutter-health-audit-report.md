> ⚠️ **FICTIONAL WORKED EXAMPLE — THIS IS NOT A REAL AUDIT.**
> This entire document is a made-up sample produced only to exercise the
> `flutter-health-audit` report template end-to-end. The audited project,
> **"Wanderlist,"** **does not exist.** Every score, percentage, file path,
> finding, risk, recommendation, and metric below is **invented** for
> illustration purposes and was not produced by running any audit tool
> against any real codebase — including this one (`somnio-ai-tools`).
> **Do not cite any number or finding in this file as a real audit
> result, and do not treat any file path in it as real.**

# Flutter Project Health Audit Report

**Project:** Wanderlist
**Date:** 2026-09-18
**Auditor:** AI-Assisted Analysis
**Framework:** Flutter/Dart — melos monorepo (1 app + 2 shared packages)

> **Exclusions:** Never recommend adding new languages/translations, CODEOWNERS/SECURITY.md files, or platform-specific Android/iOS build workflows.

---

## 1. Executive Summary

**Description:** Comprehensive analysis of Wanderlist, a Flutter travel-planning app built as a melos monorepo (`apps/wanderlist_app`, `packages/design_system`, `packages/api_client`) using `flutter_bloc` for state management and a repository layer for data access, demonstrating solid tooling and CI discipline alongside real gaps in the data layer, test coverage, and AI-harness adoption.

**Overall Score:** 73/100 (Fair)

**Top Strengths:**
- Repo-wide `very_good_analysis` lint set enforced with zero analyzer errors across all three packages.
- Mature two-workflow GitHub Actions CI/CD pipeline that runs `melos exec` fan-out for analyze/format/test on every package.
- Consistent `flutter_bloc` adoption for the majority of feature state (9 Blocs, 4 Cubits).
- `design_system` package is cleanly isolated with its own theme, tokens, and component tests.
- Melos-managed monorepo with clear package boundaries and independent `pubspec.yaml`/versioning per package.

**Top Risks:**
- `BookingRepository` instantiates its own `Dio` client instead of going through `packages/api_client`, breaking the intended data-layer abstraction.
- Overall line coverage sits at 46%, with `apps/wanderlist_app` (the largest package) at only 34%.
- `TripRepository.fetchTrip()` swallows exceptions and returns `null` on failure, hiding backend errors from the UI layer.
- No AI harness beyond a thin root `CLAUDE.md` and a single code-review agent — no rules, hooks, or pre-push checks.
- `design_system` has a transitive dependency on `packages/api_client` for shared DTOs, leaking data-layer types into the presentation layer.

**Priority Recommendations:**
1. Route all HTTP calls in `apps/wanderlist_app/lib/data/repositories/booking_repository.dart` through the shared `WanderlistApiClient` instead of a locally constructed `Dio`.
2. Raise `apps/wanderlist_app` unit/bloc-test coverage above 60% before adding new features, starting with `trip_planner_bloc.dart` and `itinerary_cubit.dart`.
3. Replace the silent `null` return in `TripRepository.fetchTrip()` with a typed `Result`/`Either` so callers can distinguish "not found" from "network error."
4. Extract the shared DTOs `design_system` currently imports from `api_client` into a small `packages/wanderlist_models` package (or move them into `design_system` itself) to remove the layering violation.
5. Add a `.claude/rules/flutter.md` and a `pre-push` git hook running `melos run analyze` + `melos run test` before investing further in feature work.

---

## 2. At-a-Glance Scorecard

| Section | Score | Label |
|---------|-------|-------|
| Tech Stack | 82/100 | Fair |
| Architecture | 78/100 | Fair |
| State Management | 74/100 | Fair |
| Repositories & Data Layer | 66/100 | Weak |
| Testing | 58/100 | Weak |
| Code Quality (Linter & Warnings) | 88/100 | Strong |
| Documentation & Operations | 71/100 | Fair |
| CI/CD (Configs Found in Repo) | 90/100 | Strong |
| AI Harness & Adoption | 45/100 | Weak |
| **Overall** | **73/100** | **Fair** |

> **Test Coverage:** 46% (lines) — full breakdown in the Testing section.
> Fallback when no coverage tool is detected: `Not measured (no coverage tool detected/configured)`

> **Scoring:** Strong (85–100) · Fair (70–84) · Weak (0–69)

Wanderlist is a well-tooled monorepo with strong CI/CD and linting discipline, but a leaky repository layer, under-tested app package, and near-absent AI harness pull the Overall Score down to a middling Fair.

---

## 3. Tech Stack

**Description:** Assessment of the SDKs, package manager, and core third-party dependencies used across the Wanderlist monorepo.

**Score:** 82/100 (Fair)

### Key Findings
- Flutter SDK pinned via `fvm` (`.fvmrc` → `3.24.3`); Dart SDK constraint in every `pubspec.yaml` is `>=3.5.0 <4.0.0`.
- `melos.yaml` declares all 3 packages (`apps/wanderlist_app`, `packages/design_system`, `packages/api_client`) with `melos bootstrap` wiring local path dependencies correctly.
- State management: `flutter_bloc: ^8.1.6` + `equatable: ^2.0.5`.
- Networking: `dio: ^5.7.0` wrapped inside `packages/api_client`; local persistence via `hive: ^2.2.3` and `shared_preferences: ^2.3.2`.
- Navigation: `go_router: ^14.2.7`; models generated with `freezed: ^2.5.7` / `json_serializable: ^6.8.0`.
- `apps/wanderlist_app/pubspec.yaml` still allows `flutter_bloc: ^8.1.6` while `packages/api_client/pubspec.yaml` pins a narrower `^8.1.3`, a minor version-range drift melos bootstrap currently resolves silently.

### Evidence
- `apps/wanderlist_app/pubspec.yaml`
- `packages/design_system/pubspec.yaml`
- `packages/api_client/pubspec.yaml`
- `melos.yaml`
- `.fvmrc`

### Risks
- Version-range drift between packages (`flutter_bloc` `^8.1.6` vs `^8.1.3`) can produce different resolved versions per package if bootstrapped independently outside melos.
- `hive` is used only in `apps/wanderlist_app/lib/data/local/trip_cache_store.dart` with no migration strategy declared for schema changes.

### Recommendations
- Align `flutter_bloc` (and other shared deps) to a single version constraint across all 3 `pubspec.yaml` files via `melos.yaml`'s `command/bootstrap/dependencyOverridePaths`.
- Document a Hive box-migration plan before the next schema change to `TripCacheStore`.

### Counts & Metrics
- Flutter SDK: 3.24.3
- Dart SDK constraint: >=3.5.0 <4.0.0
- Melos version: 6.1.0
- Direct pub dependencies (union across packages): 38
- Packages with mismatched shared-dependency ranges: 1 (`flutter_bloc`)

---

## 4. Architecture

**Description:** Review of the layering between presentation, state management, the repository layer, and the shared `api_client`/`design_system` packages.

**Score:** 78/100 (Fair)

### Key Findings
- Intended layering is presentation → Bloc/Cubit → repository → `WanderlistApiClient`, and most of `apps/wanderlist_app/lib/features/trip_planner` follows it cleanly.
- `apps/wanderlist_app/lib/features/booking/bloc/booking_bloc.dart` calls `BookingRepository` directly, but `BookingRepository` bypasses `packages/api_client` and constructs its own `Dio` instance (see Section 6).
- `packages/design_system` imports `TripDto`/`BookingDto` from `packages/api_client` for its `TripCard`/`BookingSummaryCard` widgets, coupling the presentation-only package to data-layer types.
- Feature folders are consistently structured (`bloc/`, `view/`, `widgets/`) across `trip_planner`, `itinerary`, and `booking`.

### Evidence
- `apps/wanderlist_app/lib/features/trip_planner/bloc/trip_planner_bloc.dart`
- `apps/wanderlist_app/lib/features/booking/bloc/booking_bloc.dart`
- `apps/wanderlist_app/lib/data/repositories/booking_repository.dart`
- `packages/design_system/lib/src/components/trip_card.dart`
- `packages/api_client/lib/src/models/trip_dto.dart`

### Risks
- The `design_system` → `api_client` dependency means any DTO/schema change can force an unrelated UI-kit release.
- The direct `Dio` usage inside `BookingRepository` will drift from `WanderlistApiClient`'s retry/interceptor behavior (auth refresh, logging) over time.

### Recommendations
- Move `TripDto`/`BookingDto` (or thin presentation view-models derived from them) into `design_system` or a new shared models package so `design_system` never imports `api_client`.
- Refactor `BookingRepository` to depend on `WanderlistApiClient` like `TripRepository` and `UserRepository` already do.

### Counts & Metrics
- Feature folders in `apps/wanderlist_app`: 7 (`trip_planner`, `itinerary`, `booking`, `profile`, `search`, `onboarding`, `settings`)
- Packages: 3
- Cross-package layering violations found: 2 (`design_system`→`api_client` DTO import, `BookingRepository`'s direct `Dio` usage)

---

## 5. State Management

**Description:** Evaluation of `flutter_bloc` usage patterns, event/state modeling, and consistency across features.

**Score:** 74/100 (Fair)

### Key Findings
- 9 Blocs and 4 Cubits across the app, all extending `Equatable` states, giving predictable rebuilds in most features.
- No written convention for when to use a Bloc (event-driven) vs. a Cubit (method-driven); `itinerary` uses a Cubit for what is arguably event-shaped logic (drag-to-reorder), inconsistent with `trip_planner`'s Bloc for similar list-mutation logic.
- `apps/wanderlist_app/lib/features/profile/view/profile_page.dart` mixes local `setState` for an avatar-crop preview with `ProfileBloc` for the rest of the screen, creating two sources of truth on one page.
- `BlocProvider`/`RepositoryProvider` wiring is centralized in `apps/wanderlist_app/lib/app.dart`, which is good, but 3 of 13 Bloc/Cubit classes are not `Equatable`-based on their state class, causing avoidable rebuilds.

### Evidence
- `apps/wanderlist_app/lib/features/trip_planner/bloc/trip_planner_bloc.dart`
- `apps/wanderlist_app/lib/features/itinerary/bloc/itinerary_cubit.dart`
- `apps/wanderlist_app/lib/features/profile/view/profile_page.dart`
- `apps/wanderlist_app/lib/app.dart`

### Risks
- Mixed `setState`/Bloc usage in `ProfileBloc`'s screen risks UI desync between the avatar-crop preview and the rest of the saved profile state.
- Missing `Equatable` on 3 state classes causes unnecessary widget rebuilds under `BlocBuilder`, a latent performance cost as the app grows.

### Recommendations
- Write a short internal convention doc: Bloc for multi-step/event-driven flows, Cubit for simple method-driven state, and apply it retroactively to `itinerary_cubit.dart`.
- Migrate the avatar-crop preview in `profile_page.dart` fully into `ProfileBloc` state.
- Add `Equatable` to the remaining 3 state classes.

### Counts & Metrics
- Blocs: 9
- Cubits: 4
- State classes extending `Equatable`: 10/13
- Screens mixing `setState` with Bloc/Cubit: 1 (`profile_page.dart`)

---

## 6. Repositories & Data Layer

**Description:** Assessment of the repository abstractions between the Bloc layer and `packages/api_client`, including caching and error handling.

**Score:** 66/100 (Weak)

### Key Findings
- Three repositories exist: `TripRepository`, `BookingRepository`, `UserRepository`, all under `apps/wanderlist_app/lib/data/repositories/`.
- `TripRepository` and `UserRepository` correctly depend on the injected `WanderlistApiClient`; `BookingRepository` instantiates its own `Dio()` internally instead (see Section 4).
- `TripRepository.fetchTrip()` catches `DioException` and returns `null` on any failure, so the Bloc layer cannot distinguish "trip not found" (404) from "network unreachable" — both render the same generic empty state.
- Local caching via `TripCacheStore` (Hive) has no TTL or explicit invalidation hook; stale trip data can persist indefinitely after a successful remote update if the cache write step is skipped on error.
- No repository-level retry/backoff policy; that logic lives ad hoc inside `WanderlistApiClient`'s interceptor only, not in the repositories that call it.

### Evidence
- `apps/wanderlist_app/lib/data/repositories/trip_repository.dart`
- `apps/wanderlist_app/lib/data/repositories/booking_repository.dart`
- `apps/wanderlist_app/lib/data/repositories/user_repository.dart`
- `apps/wanderlist_app/lib/data/local/trip_cache_store.dart`

### Risks
- Silent `null` returns from `TripRepository.fetchTrip()` can surface as confusing "trip not found" UI states for what are actually transient network failures.
- `BookingRepository`'s bespoke `Dio` client means auth-token refresh (handled by `WanderlistApiClient`'s interceptor) does not apply to booking requests, risking silent 401s.
- Unbounded Hive cache in `TripCacheStore` can serve stale itineraries after a trip is edited elsewhere.

### Recommendations
- Introduce a typed `Result<T, WanderlistError>` (or similar) return type across all repository methods to replace the silent-`null` pattern.
- Route `BookingRepository` through `WanderlistApiClient`.
- Add a TTL or explicit `invalidate(tripId)` API to `TripCacheStore`, called on every successful mutation.

### Counts & Metrics
- Repository classes: 3
- Repositories bypassing `WanderlistApiClient`: 1 (`BookingRepository`)
- Repository methods returning nullable-on-error rather than a typed result: 6

---

## 7. Testing

**Description:** Review of unit, bloc, and widget test coverage and practices across the three packages.

**Score:** 58/100 (Weak)

**Code Coverage:** 46% (lines)

**Coverage Breakdown:**
- `apps/wanderlist_app`: 34% (lines)
- `packages/design_system`: 76% (lines)
- `packages/api_client`: 58% (lines)

### Key Findings
- 187 tests total, run via `flutter_test` + `bloc_test` + `mocktail`, all currently green in CI.
- `apps/wanderlist_app` drags the overall figure down: `booking_bloc_test.dart` covers only the happy path, with no test for the direct-`Dio` failure paths noted in Section 6.
- `packages/design_system` has good coverage (76%) via widget/golden tests, but `TripCard`'s "loading" and "error" visual states have no golden test, only the "loaded" state.
- No integration tests (`integration_test/`) exist anywhere in the monorepo.
- One test, `apps/wanderlist_app/test/features/itinerary/itinerary_cubit_test.dart`, is `skip`-tagged in CI with a `// TODO: flaky, fix debounce timing` comment and has been skipped for over a release cycle.

### Evidence
- `apps/wanderlist_app/test/features/trip_planner/trip_planner_bloc_test.dart`
- `apps/wanderlist_app/test/features/booking/booking_bloc_test.dart`
- `apps/wanderlist_app/test/features/itinerary/itinerary_cubit_test.dart`
- `packages/design_system/test/src/components/trip_card_test.dart`
- `packages/api_client/test/src/wanderlist_api_client_test.dart`

### Risks
- A long-skipped flaky test (`itinerary_cubit_test.dart`) erodes trust in the suite and hides a real debounce bug.
- Zero integration test coverage means the booking checkout flow (spanning 3 Blocs and 2 repositories) has never been exercised end-to-end.
- `TripCard`'s missing error/loading golden tests leave visual regressions in those states undetected.

### Recommendations
- Un-skip and fix `itinerary_cubit_test.dart`'s debounce timing before adding new itinerary features.
- Add at least one `integration_test/` flow covering search → trip detail → booking checkout.
- Add golden tests for `TripCard`'s loading and error states.

### Counts & Metrics
- Test count: 187
- Test framework: flutter_test, bloc_test, mocktail
- Skipped tests in CI: 1

---

## 8. Code Quality (Linter & Warnings)

**Description:** Static-analysis and linting posture across the monorepo.

**Score:** 88/100 (Strong)

### Key Findings
- All 3 packages share a root `analysis_options.yaml` built on `very_good_analysis: ^6.0.0`, with no per-package overrides weakening the rule set.
- `melos run analyze` (wired to `dart analyze --fatal-infos` per package) is green across the monorepo: 0 errors, 0 warnings.
- 12 outstanding info-level lints remain, mostly `public_member_api_docs` gaps inside `packages/api_client`.
- Formatting is enforced via `melos run format-check` (`dart format --set-exit-if-changed`) in CI, but not locally via a pre-commit hook, so drift is only caught after push.

### Evidence
- `analysis_options.yaml`
- `melos.yaml` (`format-check`, `analyze` script definitions)
- `packages/api_client/lib/src/wanderlist_api_client.dart`

### Risks
- Relying solely on CI for format enforcement means contributors can accumulate several unformatted commits before the check fails.
- The 12 `public_member_api_docs` gaps are concentrated in `api_client`, the package most other teams would consume if it were ever extracted.

### Recommendations
- Add a local `dart format` pre-commit (or pre-push) hook so formatting issues are caught before CI.
- Close the remaining `public_member_api_docs` gaps in `packages/api_client`'s public surface.

### Counts & Metrics
- Lint rule set: very_good_analysis 6.0.0
- Analyzer errors: 0
- Analyzer warnings: 0
- Info-level lints outstanding: 12

---

## 9. Documentation & Operations

**Description:** Review of package-level documentation, dartdoc coverage, and day-2 operational docs.

**Score:** 71/100 (Fair)

### Key Findings
- Each of the 3 packages has its own `README.md` covering purpose and local setup; the root `README.md` links to all three.
- No architecture decision records (ADRs) exist for the layering decisions described in Section 4, including the still-unresolved `design_system`→`api_client` dependency.
- `packages/api_client`'s public methods are ~55% dartdoc-covered; `packages/design_system`'s public widgets are ~70% covered.
- No runbook exists for diagnosing the `TripCacheStore` staleness issue flagged in Section 6.

### Evidence
- `README.md`
- `apps/wanderlist_app/README.md`
- `packages/design_system/README.md`
- `packages/api_client/README.md`

### Risks
- Without an ADR trail, the `design_system`→`api_client` coupling is likely to be repeated by future contributors who don't know it was ever flagged.
- Missing dartdoc on over a third of `api_client`'s public surface slows onboarding for anyone consuming it outside `apps/wanderlist_app`.

### Recommendations
- Add a lightweight `docs/adr/` folder and record at least the layering decision from Section 4 as the first ADR.
- Raise `packages/api_client` dartdoc coverage on public methods to at least 80%.

### Counts & Metrics
- READMEs present: 3/3 packages + root
- Dartdoc coverage, public API (`api_client`): ~55%
- Dartdoc coverage, public API (`design_system`): ~70%
- ADRs on file: 0

---

## 10. CI/CD (Configs Found in Repo)

**Description:** Review of the GitHub Actions workflows driving analysis, tests, and builds across the monorepo.

**Score:** 90/100 (Strong)

### Key Findings
- `.github/workflows/ci.yaml` runs on every PR: `melos bootstrap` → `melos run analyze` → `melos run format-check` → `melos run test` (fanned out per package with `--concurrency=4`).
- `.github/workflows/release.yaml` builds signed Android/iOS artifacts on tags, gated on `ci.yaml` passing.
- Both workflows cache the pub cache and Flutter SDK (via `subosito/flutter-action`) keyed on `pubspec.lock` hashes, keeping average CI time around 6m40s.
- Coverage is collected (`flutter test --coverage` per package, merged with `lcov`) but not yet gated on a minimum threshold — the pipeline never fails on low coverage.

### Evidence
- `.github/workflows/ci.yaml`
- `.github/workflows/release.yaml`
- `melos.yaml` (`analyze`, `format-check`, `test` script definitions)

### Risks
- Without a coverage gate, the 34% figure in `apps/wanderlist_app` (Section 7) can keep dropping without ever failing a build.
- `release.yaml` has no automated version-bump/changelog step; `melos version` is run manually before tagging.

### Recommendations
- Add a coverage-threshold check (e.g. fail under 50% for `apps/wanderlist_app`) to `ci.yaml`.
- Automate `melos version`/changelog generation as part of the release workflow.

### Counts & Metrics
- Workflows: 2 (`ci.yaml`, `release.yaml`)
- Average CI run time: 6m40s
- Coverage gate configured: No

---

## 11. AI Harness & Adoption

**Description:** Assessment of the repo's Claude Code / AI-assisted-development harness maturity.

**Score:** 45/100 (Weak)

**Maturity:** harness básico

### Harness Coverage
| Dimension | Status | Points |
|---|---|---|
| CLAUDE.md | Present, thin | 9/13 |
| Rules | Minimal | 4/9 |
| Permissions | Partial | 7/13 |
| Hooks | Minimal | 5/14 |
| Pre-push git hook | Missing | 0/11 |
| Agents | Partial | 5/11 |
| Commands / Skills | Partial | 6/9 |
| Advanced orchestration | Missing | 1/5 |
| Lifecycle | Minimal | 2/3 |
| Harness versioning | Partial | 6/12 |
| **Total** | | **45/100** |

### Key Findings
- Root `CLAUDE.md` (~420 words) documents the melos layout and the "no direct `Dio` in features" rule, but has no per-package guidance and predates the `design_system`→`api_client` coupling flagged in Section 4, so it doesn't warn against it.
- No `.claude/rules/` directory exists; the flutter-specific conventions (Bloc vs. Cubit, repository return types) live only in the CLAUDE.md prose, not as enforceable path-scoped rules.
- `.claude/settings.json` grants a short allowlist (`dart`, `flutter`, `melos`) but has no deny list and no hooks configured.
- One custom agent, `code-reviewer`, exists under `.claude/agents/` for PR review; no test-writer or release agent.
- Two slash commands (`/run-tests`, `/bootstrap`) exist under `.claude/commands/`; no skills are installed via the Somnio CLI.
- No pre-push git hook exists; `melos run analyze`/`test` are only enforced in CI, not locally before push.

### Evidence
- `CLAUDE.md`
- `.claude/settings.json`
- `.claude/agents/code-reviewer.md`
- `.claude/commands/run-tests.md`
- `.claude/commands/bootstrap.md`

### Risks
- Without path-scoped rules, conventions like "repositories must return typed results, not nullable" (Section 6) are easy for an AI agent to miss since they're buried in CLAUDE.md prose rather than an enforced rule file.
- The missing pre-push hook means an AI agent (or a human) can push code that fails `melos run analyze`/`test`, discovering it only after CI runs.

### Actions to Raise the Score
1. **[+5] Add a pre-push git hook.** Create a `pre-push` hook running `melos run analyze` and `melos run test` before allowing a push. → dimension Pre-push git hook, 0/11 → 5/11.
2. **[+4] Add `.claude/rules/flutter.md`.** Encode the Bloc-vs-Cubit convention and the "repositories return typed results" rule as an enforced, path-scoped rule rather than CLAUDE.md prose. → dimension Rules, 4/9 → 8/9.
3. **[+3] Extend `.claude/settings.json` with a deny list and a `PostToolUse` hook** that runs `dart format` on edited files. → dimension Hooks, 5/14 → 8/14.
4. **[+2] Add a test-writer agent** under `.claude/agents/` scoped to the packages with the lowest coverage (`apps/wanderlist_app`). → dimension Agents, 5/11 → 7/11.

### Counts & Metrics
- CLAUDE.md word count: ~420
- Custom agents: 1
- Slash commands: 2
- Rule files under `.claude/rules/`: 0

---

## 12. Additional Metrics

- **Supported platforms:** iOS, Android
- **Number of feature folders:** 7 (`apps/wanderlist_app`)
- **Packages count:** 3
- **State management detected:** flutter_bloc (Bloc + Cubit mix)
- **Force-upgrade/maintenance mode:** Not implemented
- **Spell-check scope:** None configured
- **Public API docs enforcement:** Not enforced (dartdoc gaps noted in Section 9, no CI check)

---

## 13. Risks & Opportunities

- `BookingRepository`'s standalone `Dio` client bypasses the shared auth/retry interceptor, risking silent 401s on booking requests.
- `TripRepository.fetchTrip()`'s silent `null`-on-error pattern hides real backend failures behind a generic "not found" UI state.
- `apps/wanderlist_app`'s 34% coverage is the single biggest drag on the overall 46% figure and on the Testing score.
- A flaky, long-`skip`-tagged test (`itinerary_cubit_test.dart`) is masking a real debounce bug in the itinerary feature.
- `packages/design_system` importing DTOs from `packages/api_client` couples the UI kit to data-layer schema changes.
- No CI coverage gate means the app-package coverage figure can keep declining without ever failing a build.
- The AI harness has no path-scoped rules or pre-push hook, so the conventions this very audit relies on (typed repository results, Bloc/Cubit discipline) are not mechanically enforced.
- Zero integration-test coverage leaves the multi-Bloc booking checkout flow completely unverified end-to-end.

---

## 14. Recommendations

1. **High:** Route `BookingRepository` through `WanderlistApiClient` instead of a locally constructed `Dio`.
2. **High:** Replace `TripRepository.fetchTrip()`'s silent `null`-on-error with a typed `Result`/`Either` return.
3. **High:** Un-skip and fix the flaky `itinerary_cubit_test.dart` debounce test.
4. **Medium:** Raise `apps/wanderlist_app` line coverage above 60%, starting with `booking_bloc_test.dart`'s failure paths.
5. **Medium:** Remove `design_system`'s dependency on `api_client` DTOs by introducing shared/presentation-only models.
6. **Medium:** Add a coverage-threshold gate to `.github/workflows/ci.yaml`.
7. **Medium:** Add a `pre-push` git hook running `melos run analyze` + `melos run test`.
8. **Low:** Document a Bloc-vs-Cubit convention and apply it retroactively to `itinerary_cubit.dart`.
9. **Low:** Close the 12 outstanding `public_member_api_docs` lints in `packages/api_client`.
10. **Low:** Add an `integration_test/` flow covering search → trip detail → booking checkout.

---

## 15. Appendix: Evidence Index

**Tech Stack:**
- `apps/wanderlist_app/pubspec.yaml`
- `packages/design_system/pubspec.yaml`
- `packages/api_client/pubspec.yaml`
- `melos.yaml`
- `.fvmrc`

**Architecture:**
- `apps/wanderlist_app/lib/app.dart`
- `apps/wanderlist_app/lib/features/booking/bloc/booking_bloc.dart`
- `apps/wanderlist_app/lib/data/repositories/booking_repository.dart`
- `packages/design_system/lib/src/components/trip_card.dart`

**State Management:**
- `apps/wanderlist_app/lib/features/trip_planner/bloc/trip_planner_bloc.dart`
- `apps/wanderlist_app/lib/features/itinerary/bloc/itinerary_cubit.dart`
- `apps/wanderlist_app/lib/features/profile/view/profile_page.dart`

**Repositories & Data Layer:**
- `apps/wanderlist_app/lib/data/repositories/trip_repository.dart`
- `apps/wanderlist_app/lib/data/repositories/booking_repository.dart`
- `apps/wanderlist_app/lib/data/repositories/user_repository.dart`
- `apps/wanderlist_app/lib/data/local/trip_cache_store.dart`

**Testing:**
- `apps/wanderlist_app/test/features/trip_planner/trip_planner_bloc_test.dart`
- `apps/wanderlist_app/test/features/itinerary/itinerary_cubit_test.dart`
- `packages/design_system/test/src/components/trip_card_test.dart`
- `packages/api_client/test/src/wanderlist_api_client_test.dart`

**Code Quality:**
- `analysis_options.yaml`
- `melos.yaml`

**Documentation:**
- `README.md`
- `apps/wanderlist_app/README.md`
- `packages/design_system/README.md`
- `packages/api_client/README.md`

**CI/CD:**
- `.github/workflows/ci.yaml`
- `.github/workflows/release.yaml`

**AI Harness & Adoption:**
- `CLAUDE.md`
- `.claude/settings.json`
- `.claude/agents/code-reviewer.md`
- `.claude/commands/run-tests.md`

---

## Appendix: Scoring Methodology

**Weighted formula** (weights sum to 1.00 — the authoritative source is this skill's
`references/report-generator.md`; this table is a read-only summary of what was applied):

| Section | Weight |
|---------|--------|
| Tech Stack | 0.18 |
| Architecture | 0.18 |
| State Management | 0.18 |
| Repositories & Data Layer | 0.10 |
| Testing | 0.10 |
| Code Quality (Linter & Warnings) | 0.10 |
| Documentation & Operations | 0.03 |
| CI/CD (Configs Found in Repo) | 0.03 |
| AI Harness & Adoption | 0.10 |
| **Total** | **1.00** |

**Arithmetic shown:**
`0.18×82 + 0.18×78 + 0.18×74 + 0.10×66 + 0.10×58 + 0.10×88 + 0.03×71 + 0.03×90 + 0.10×45`
`= 14.76 + 14.04 + 13.32 + 6.60 + 5.80 + 8.80 + 2.13 + 2.70 + 4.50`
`= 72.65 → rounds to 73`

**Rounding rule:** Standard mathematical rounding (0.5 rounds up). No subjective adjustment.

**Scoring bands:** Strong (85–100) · Fair (70–84) · Weak (0–69)

---

## Report Metadata

| Field | Value |
|-------|-------|
| Generated by | Somnio CLI v0.0.0-example (fictional worked example, not a real run) |
| Skill | flutter-health-audit |
| Date | 2026-09-18 |
| Somnio AI Tools | https://github.com/somnio-software/somnio-ai-tools |
