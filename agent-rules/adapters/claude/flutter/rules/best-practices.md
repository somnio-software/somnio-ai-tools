### Flutter principles, workflow, testing standards, documentation, and project-specific rules.
> Applies to: `mobile/lib/**/*.dart, mobile/packages/*/lib/**/*.dart`
# Flutter Best Practices

## Interaction Guidelines
* **User Persona:** Assume the user is familiar with programming concepts but
  may be new to Dart.
* **Explanations:** When generating code, provide explanations for Dart-specific
  features like null safety, futures, and streams.
* **Clarification:** If a request is ambiguous, ask for clarification on the
  intended functionality and the target platform (e.g., command-line, web,
  server).
* **Dependencies:** When suggesting new dependencies from `pub.dev`, explain
  their benefits.
* **Formatting:** Use the `dart_format` tool to ensure consistent code
  formatting.
* **Fixes:** Use the `dart_fix` tool to automatically fix many common errors,
  and to help code conform to configured analysis options.
* **Linting:** Use the Dart linter with a recommended set of rules to catch
  common issues. Use the `analyze_files` tool to run the linter.

## Flutter Philosophy
* **SOLID Principles:** Apply SOLID principles throughout the codebase.
* **State Management:** Separate ephemeral state and app state. Use a state
  management solution (BLoC) for app state to handle the separation of concerns.
* **Widgets are for UI:** Everything in Flutter's UI is a widget. Compose
  complex UIs from smaller, reusable widgets.
* **Testing mindset:** Write code with testing in mind. Use the `file`,
  `process`, and `platform` packages where appropriate so you can inject
  in-memory and fake versions of objects.

## Package Management
* **Pub Tool:** To manage packages, use the `pub` tool, if available.
* **External Packages:** If a new feature requires an external package, identify
  the most suitable and stable package from pub.dev.
* **Adding Dependencies:** Run `flutter pub add <package_name>`.
* **Adding Dev Dependencies:** Run `flutter pub add dev:<package_name>`.
* **Dependency Overrides:** Run `flutter pub add override:<package_name>:1.0.0`.
* **Removing Dependencies:** Run `dart pub remove <package_name>`.

## Code Quality
* **Code structure:** Adhere to maintainable code structure and separation of
  concerns (e.g., UI logic separate from business logic).
* **Naming conventions:** Avoid abbreviations and use meaningful, consistent,
  descriptive names for variables, functions, and classes. Use `PascalCase`
  for classes, `camelCase` for members/variables/functions/enums, and
  `snake_case` for files.
* **Conciseness:** Write code that is as short as it can be while remaining
  clear.
* **Simplicity:** Write straightforward code. Code that is clever or obscure is
  difficult to maintain.
* **Error Handling:** Anticipate and handle potential errors. Don't let your
  code fail silently.
* **Line length:** Lines should be 80 characters or fewer.
* **Functions:** Short and with a single purpose (strive for less than 20
  lines).
* **Logging:** Use `log()` from `dart:developer`. Never use `print()`.

## API Design Principles
When building reusable APIs, such as a library, follow these principles.

* **Consider the User:** Design APIs from the perspective of the person who will
  be using them. The API should be intuitive and easy to use correctly.
* **Documentation is Essential:** Good documentation is a part of good API
  design. It should be clear, concise, and provide examples.

## Testing
* **Running Tests:** Use `flutter test`.
* **Unit Tests:** Use `package:test` for unit tests.
* **Widget Tests:** Use `package:flutter_test` for widget tests.
* **Integration Tests:** Use `package:integration_test` for integration tests.
* **Assertions:** Prefer using `package:checks` for more expressive and readable
  assertions over the default `matchers`.
* **Convention:** Follow the Arrange-Act-Assert (or Given-When-Then) pattern.
* **Unit Tests:** Write unit tests for domain logic, data layer, and state
  management.
* **Widget Tests:** Write widget tests for UI components.
* **Mocks:** Prefer fakes or stubs over mocks. If mocks are absolutely
  necessary, use `mocktail`.
* **Coverage:** ≥80% line coverage **per file** — not just overall.

## Documentation

* **`dartdoc`:** Write `dartdoc`-style comments for all public APIs.

### Documentation Philosophy

* **Comment wisely:** Use comments to explain why the code is written a certain
  way, not what the code does. The code itself should be self-explanatory.
* **Document for the user:** Write documentation with the reader in mind. If you
  had a question and found the answer, add it to the documentation where you
  first looked.
* **No useless documentation:** If it only restates the obvious from the code's
  name, it's not helpful.
* **Consistency is key:** Use consistent terminology throughout your
  documentation.

### Commenting Style

* **Use `///` for doc comments:** This allows documentation generation tools to
  pick them up.
* **Start with a single-sentence summary** ending with a period.
* **Separate the summary:** Add a blank line after the first sentence to create
  a separate paragraph.
* **Avoid redundancy:** Don't repeat information that's obvious from the code's
  context, like the class name or signature.

### Writing Style

* **Be brief:** Write concisely.
* **Avoid jargon and acronyms** unless they are widely understood.
* **Use backticks for code:** Enclose code blocks in backtick fences, and
  specify the language.

### What to Document

* **Public APIs are a priority:** Always document public APIs.
* **Include code samples** where appropriate.
* **Explain parameters, return values, and exceptions** in prose.
* **Place doc comments before annotations.**

## Accessibility
* **Color Contrast:** Ensure text has a contrast ratio of at least **4.5:1**
  against its background.
* **Dynamic Text Scaling:** Test your UI to ensure it remains usable when users
  increase the system font size.
* **Semantic Labels:** Use the `Semantics` widget to provide clear, descriptive
  labels for UI elements.
* **Screen Reader Testing:** Regularly test your app with TalkBack (Android) and
  VoiceOver (iOS).

---

## Project-Specific Rules

These rules are enforced on every Flutter change in this repo.

### 1. Lint must be clean after every change

Run from `mobile/`:

```bash
dart fix --apply
flutter analyze
```

Zero issues is the exit criterion. Auto-fix first, then fix the rest manually.

### 2. Flutter client never calls third-party APIs directly

The Flutter client talks only to Firebase (Auth, Firestore, Storage, FCM) and to
the Functions REST API via `api_client`. No direct calls to Gemini, RevenueCat,
or any other third-party service.

### 3. i18n is mandatory for every user-visible string

All user-visible strings must live in `mobile/lib/l10n/arb/app_en.arb` and
be accessed via `context.l10n.<key>`. Never inline Spanish (or any other
language) text literals in Dart widgets — not even short button labels or error
messages.

**How to add a new string:**
1. Add the key + `@key` descriptor to `app_en.arb`.
2. Run `flutter gen-l10n` from `mobile/` to regenerate the Dart classes.
3. Reference it as `context.l10n.yourKey`.

**Widgets in `packages/app_ui`** must stay language-agnostic: accept all
user-visible strings as required constructor parameters. Callers in
`mobile/lib/` resolve them from `context.l10n` and pass them in.

### 4. Keyboard must be dismissible by tapping anywhere outside

Every screen or widget that contains a `TextField`, `TextFormField`, or any
focusable input must wrap its body:

```dart
GestureDetector(
  onTap: () => FocusScope.of(context).unfocus(),
  behavior: HitTestBehavior.translucent,
  child: /* screen body */,
)
```

`behavior: HitTestBehavior.translucent` is required so taps pass through to
child widgets. Applies to every screen in `lib/` and to reusable form widgets in
`packages/app_ui` that own their own `Scaffold` or root container.

### 5. UI Design Specs are mandatory

Before implementing or modifying **any** screen or widget under `mobile/lib/`
or `mobile/packages/app_ui/`, always read the corresponding design spec first:

| What you need | Where to look |
|---|---|
| Any app screen | `design/screens-*.jsx` — find the component by feature name |
| Design-system components / tokens | `design/design-system.jsx` |
| Mock data used by specs | `design/mock-data.jsx` |

Each `screens-*.jsx` file exports one React component per screen. Read the JSX to
extract: layout structure, spacing, color roles (`palette.*`), typography slots
(`textStyle('titleMedium', ...)`), variant names (`Card variant="filled"`,
`Button variant="tonal"`), and conditional logic. Translate directly to Flutter
equivalents using `AppSpacing`, `colorScheme`, `AppThemeExtension`, and
`AppCard`/`AppButton` variants.

If no spec exists for the screen being modified, say so explicitly before
proceeding. Never implement UI from a screenshot alone when a JSX spec is
available.
