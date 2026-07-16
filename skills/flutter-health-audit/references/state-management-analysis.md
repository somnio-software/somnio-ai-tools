# Flutter State Management Analysis

> Analyze state management library selection, usage patterns, and architectural quality for Flutter projects (single app or multi-app monorepos).

---

Goal: Analyze the Flutter project's state management approach to
evaluate library selection, usage consistency, and overall state
architecture quality.

EFFICIENCY REQUIREMENTS:
- Target: ≤ 8 total tool calls for this entire analysis
- Use batch grep commands to detect and count usage across the whole
  tree in one pass rather than reading individual source files
- Read pubspec.yaml files (root, apps/*, packages/*) together in
  parallel reads
- Pipe large outputs through `| head -50`

ANALYSIS TARGETS:

1. **State Management Library Detection**:
   - Check `pubspec.yaml` dependencies (root, and per app/package in
     monorepos) for:
     * `flutter_bloc` / `bloc` — BLoC/Cubit
     * `hooks_riverpod` / `flutter_riverpod` / `riverpod` — Riverpod
     * `provider` — Provider
     * `get` — GetX
     * `mobx` / `flutter_mobx` — MobX
     * `redux` / `flutter_redux` — Redux
   - Note if ONLY `setState`/`InheritedWidget` is used (no external
     state library) — this may be entirely appropriate for small apps
     and should not automatically be scored down
   - If no library is detected AND no local-state evidence
     (`setState`/`InheritedWidget`) can be confirmed either, report
     "Unknown" rather than assuming a pattern

2. **BLoC / Cubit Usage** (if `flutter_bloc`/`bloc` present):
   - Count Cubit and Bloc subclasses:
     `grep -rE 'extends Cubit<|extends Bloc<' --include="*.dart" . | wc -l`
   - Note the split between Cubit-only and Bloc-with-events usage
   - Check for `BlocProvider`/`MultiBlocProvider` composition at the
     app root vs. scattered ad hoc instantiation

3. **Riverpod / Provider Usage** (if `riverpod`/`provider` present):
   - Count Provider and Notifier declarations:
     `grep -rE 'Provider\(|NotifierProvider|StateNotifierProvider' --include="*.dart" . | wc -l`
   - Check for code generation (`@riverpod` annotations) vs. manual
     provider declarations
   - Note if `ChangeNotifierProvider` (Provider package) is mixed with
     `riverpod` providers in the same app

4. **GetX Usage** (if `get` present):
   - Count GetxController subclasses:
     `grep -rE 'extends GetxController' --include="*.dart" . | wc -l`
   - Check for reliance on `Get.find`/`Get.put` service-locator calls
     scattered through widgets vs. centralized bindings

5. **Quality Signals** (apply regardless of which library is detected):
   - **Mixed libraries**: multiple state-management libraries
     (e.g. `flutter_bloc` AND `provider` AND `get`) present in the
     same app/package — flag as an anti-pattern unless clearly scoped
     to separate packages
   - **Business logic in widgets**: `build()` methods or widget classes
     containing non-trivial business logic (HTTP calls, data
     transformation) instead of delegating to the state layer
   - **Non-immutable state**: state classes lacking `Equatable`,
     `freezed`, or manual `==`/`hashCode` overrides, which causes
     unnecessary rebuilds and unreliable equality checks
   - **BuildContext leaking into state layer**: Cubit/Bloc/Notifier/
     Controller classes that import `package:flutter/material.dart`
     or accept a `BuildContext` parameter, coupling business logic to
     the widget tree:
     `grep -rlE "import 'package:flutter/material.dart'" $(find . -iname '*_cubit.dart' -o -iname '*_bloc.dart' -o -iname '*_controller.dart' -o -iname '*_notifier.dart')`

6. **Monorepo Comparison** (if apps/ or packages/ exist):
   - Compare the detected library per app/package
   - Flag inconsistent state-management choices across apps in the
     same monorepo as a maintainability risk

Output format:
- State management detected: [flutter_bloc/Riverpod/Provider/
  GetX/MobX/Redux/setState-only/Unknown] (per app if multi-app)
- Cubit/Bloc subclasses: [Count]
- Provider/Notifier declarations: [Count]
- GetxController subclasses: [Count]
- Mixed-library usage detected: [Yes/No — list libraries if Yes]
- Business logic found in widgets: [Yes/No — list examples]
- State classes without Equatable/immutability: [Count or "None found"]
- BuildContext leaking into state layer: [Yes/No — list files]
- Cross-app consistency (monorepo only): [Consistent/Inconsistent]
- Risks identified
- Recommendations

SCORING GUIDANCE (0-100):

Strong (85-100):
- A single, consistent state-management approach used across the
  app/monorepo (or a well-justified, cleanly scoped mix)
- State classes are immutable (Equatable/freezed) where the library
  supports it
- No business logic embedded in widgets
- No BuildContext leakage into Cubit/Bloc/Notifier/Controller classes
- `setState`-only is acceptable and can still score Strong for small,
  genuinely simple apps with no cross-widget shared state

Fair (70-84):
- A state-management library is used but inconsistently (e.g. some
  features still call setState for what should be shared state)
- Minor mixing of libraries, or some state classes missing
  immutability
- Isolated instances of business logic in widgets

Weak (0-69):
- Multiple state-management libraries mixed without clear boundaries
- Widespread business logic in widgets
- Pervasive BuildContext leakage into the state layer
- No discernible state-management pattern despite non-trivial
  cross-widget shared state

Unknown:
- No state-management library detected in `pubspec.yaml` AND no
  `setState`/`InheritedWidget` evidence could be confirmed — report
  "Unknown" and specify what would prove it, rather than assuming a
  pattern
