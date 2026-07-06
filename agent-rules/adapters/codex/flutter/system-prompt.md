# System Prompt — Somnio Coding Standards (Flutter)

You are an expert software engineer. Follow these coding standards precisely when generating code.

### General architecture guidelines when using Flutter.
> Applies to: `mobile/lib/**/*.dart, mobile/packages/*/lib/**/*.dart`

# Flutter Layered Architecture

How to build highly scalable, maintainable, and testable Flutter apps using layered architecture. This architecture consists of four layers with clear boundaries and single responsibilities.

## Architecture Overview

Layered architecture enhances developer experience by allowing independent development of each layer. Each layer can be developed by different teams without impacting others. Testing is simplified since only one layer needs to be mocked.

### Layer Structure

## Layer Responsibilities

### 1. Data Layer (Bottom Layer)

**Purpose**: Retrieve raw data from external sources

**Responsibilities**:
- SQLite database operations
- Local storage (SharedPreferences)
- RESTful API calls
- GPS, battery data, file system access
- No domain or business logic

**Characteristics**:
- Closest to data retrieval
- Free of specific domain logic
- Reusable across unrelated projects
- Platform-specific implementations

**Example**:

### 2. Repository Layer (Composition Layer)

**Purpose**: Compose data clients and apply business rules

**Responsibilities**:
- Fetch data from one or more data sources
- Apply domain-specific logic to raw data
- Provide clean interface to business logic layer
- One repository per domain (UserRepository, WeatherRepository)

**Characteristics**:
- No Flutter dependencies
- No dependencies on other repositories
- Domain-specific business rules
- "Product" layer - business owner determines rules

**Example**:

### 3. Business Logic Layer (Feature Layer)

**Purpose**: Compose repositories and implement feature logic

**Responsibilities**:
- Implement BLoC library
- Retrieve data from repository layer
- Provide state to presentation layer
- Feature-specific use cases

**Characteristics**:
- No Flutter SDK dependencies
- No direct dependencies on other business logic components
- "Feature" layer - design/product determines feature rules

**Example**:

### 4. Presentation Layer (Top Layer)

**Purpose**: UI layer using Flutter widgets

**Responsibilities**:
- Build widgets and manage lifecycle
- Request updates from business logic layer
- Update UI based on state changes
- No business logic

**Characteristics**:
- Flutter UI dependencies
- "Design" layer - designers determine UI
- Only interacts with business logic layer

**Example**:

## Project Organization

### Directory Structure

### Key Principles

1. **Separation of Concerns**: Each layer has a single responsibility
2. **Dependency Direction**: Data flows bottom-up, dependencies flow top-down
3. **Abstraction**: Implementation details don't leak between layers
4. **Testability**: Each layer can be tested in isolation

## Dependency Rules

### ✅ Good: Proper Layer Dependencies

### ❌ Bad: Layer Violations

## Implementation Guidelines

### 1. Layer Boundaries

- **Never skip layers**: Presentation → Business Logic → Repository → Data
- **No cross-layer dependencies**: Repository shouldn't depend on Business Logic
- **Single responsibility**: Each layer has one clear purpose

### 2. Dependency Injection

### 3. Error Handling

### 4. Testing Strategy

## Common Patterns

### Repository Pattern

### BLoC Pattern

### Widget Organization

## Common Anti-Patterns to Avoid

1. **Direct Data Layer Access**: Never access data layer from presentation or business logic
2. **Cross-Layer Dependencies**: Don't create circular dependencies between layers
3. **Business Logic in UI**: Keep all business logic in the business logic layer
4. **Hardcoded Dependencies**: Use dependency injection instead of direct instantiation
5. **Mixed Responsibilities**: Don't mix conce

## Rules

1. **Layer Isolation**: Each layer should be independent and testable
2. **Dependency Direction**: Always flow from top to bottom
3. **Abstraction**: Hide implementation details behind interfaces
4. **Single Responsibility**: Each class has one clear purpose
5. **Error Boundaries**: Handle errors at the appropriate layer
6. **Testing**: Test each layer in isolation with mocks
7. **Documentation**: Document layer boundaries and responsibilities
8. **Consistency**: Follow the same patterns across all features

---

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

---

### Bloc testing standards — bloc, event, and state test patterns.
> Applies to: `mobile/test/**/*bloc_test.dart, mobile/test/**/*event_test.dart, mobile/test/**/*state_test.dart, mobile/packages/*/test/**/*bloc_test.dart`

# Bloc Testing Standards

How to write comprehensive bloc tests following the project's established patterns and conventions.

## Usage

To use this rule when writing bloc tests:

1. Reference this rule when writing BLoC tests.
2. Reference the bloc folder you're testing.
3. Follow the directory structure and naming conventions below

## Directory Structure

Follow this exact structure for bloc files and tests:

## Required Imports

Import only what you need:

## Test File Structure

### 1. Bloc Test File (`feature_name_bloc_test.dart`)

Structure: **Bloc → Event → Test Cases** (focus on state changes)

### 2. Event Test File (`feature_name_event_test.dart`)

### 3. State Test File (`feature_name_state_test.dart`)

## Testing Patterns

### 1. Mock Setup (Only if needed)

### 2. BlocTest Structure

### 3. Test Organization

- **Bloc → Event → Test Cases**: Group by bloc, then by event, then test cases
- **Focus on State Changes**: Test descriptions should explain what state changes occur
- **Descriptive but Concise**: Test names should be clear but not verbose

## Official Documentation Examples

### Login Bloc Test Pattern

### Todos Overview Bloc Test Pattern

### Edit Todo Bloc Test Pattern

## Common Patterns

### Testing Stream-Based Blocs

### Testing Form Validation

### Testing Async Operations

### Testing Error Scenarios

### Testing Conditional Logic

## Rules

1. **Naming**: Use descriptive but concise test names that explain state changes
2. **Grouping**: Group by Bloc → Event → Test Cases
3. **Mocking**: Only mock when bloc has dependencies
4. **Verification**: Always verify repository interactions when testing bloc logic
5. **State Transitions**: Test the complete state transition sequence
6. **Error Handling**: Test both success and failure scenarios
7. **Constants**: Use `const` constructors for events and states when possible
8. **Helper Functions**: Create `buildBloc()` helper for consistent bloc creation
9. **Props Testing**: Always test `props` getter for events and states
10. **Focus**: Focus on state changes that occur in each event

---

### Dart and Flutter implementation patterns — null safety, async/await, const constructors, pattern matching, routing, serialization, logging, code generation.
> Applies to: `mobile/lib/**/*.dart, mobile/packages/*/lib/**/*.dart`

# Dart & Flutter Code Patterns

## Dart Best Practices
* **Effective Dart:** Follow the official Effective Dart guidelines
  (https://dart.dev/effective-dart)
* **Class Organization:** Define related classes within the same library file.
  For large libraries, export smaller, private libraries from a single top-level
  library.
* **Library Organization:** Group related libraries in the same folder.
* **API Documentation:** Add documentation comments to all public APIs,
  including classes, constructors, methods, and top-level functions.
* **Comments:** Write clear comments for complex or non-obvious code. Avoid
  over-commenting.
* **Trailing Comments:** Don't add trailing comments.
* **Async/Await:** Ensure proper use of `async`/`await` for asynchronous
  operations with robust error handling.
    * Use `Future`s, `async`, and `await` for asynchronous operations.
    * Use `Stream`s for sequences of asynchronous events.
* **Null Safety:** Write code that is soundly null-safe. Leverage Dart's null
  safety features. Avoid `!` unless the value is guaranteed to be non-null.
* **Pattern Matching:** Use pattern matching features where they simplify the
  code.
* **Records:** Use records to return multiple types in situations where defining
  an entire class is cumbersome.
* **Switch Statements:** Prefer using exhaustive `switch` statements or
  expressions, which don't require `break` statements.
* **Exception Handling:** Use `try-catch` blocks for handling exceptions, and
  use exceptions appropriate for the type of exception. Use custom exceptions
  for situations specific to your code.
* **Arrow Functions:** Use arrow syntax for simple one-line functions.

## Flutter Best Practices
* **Immutability:** Widgets (especially `StatelessWidget`) are immutable; when
  the UI needs to change, Flutter rebuilds the widget tree.
* **Composition:** Prefer composing smaller widgets over extending existing
  ones. Use this to avoid deep widget nesting.
* **Private Widgets:** Use small, private `Widget` classes instead of private
  helper methods that return a `Widget`.
* **Build Methods:** Break down large `build()` methods into smaller, reusable
  private Widget classes.
* **List Performance:** Use `ListView.builder` or `SliverList` for long lists to
  create lazy-loaded lists for performance.
* **Isolates:** Use `compute()` to run expensive calculations in a separate
  isolate to avoid blocking the UI thread, such as JSON parsing.
* **Const Constructors:** Use `const` constructors for widgets and in `build()`
  methods whenever possible to reduce rebuilds.
* **Build Method Performance:** Avoid performing expensive operations, like
  network calls or complex computations, directly within `build()` methods.

## Data Flow
* **Data Structures:** Define data structures (classes) to represent the data
  used in the application.
* **Data Abstraction:** Abstract data sources (e.g., API calls, database
  operations) using Repositories to promote testability.

## Routing
* **GoRouter:** Use the `go_router` package for declarative navigation, deep
  linking, and web support.
* **GoRouter Setup:** To use `go_router`, first add it to your `pubspec.yaml`
  using the `pub` tool's `add` command.

  
* **Authentication Redirects:** Configure `go_router`'s `redirect` property to
  handle authentication flows, ensuring users are redirected to the login screen
  when unauthorized, and back to their intended destination after successful
  login.

* **Navigator:** Use the built-in `Navigator` for short-lived screens that do
  not need to be deep-linkable, such as dialogs or temporary views.

  

## Data Handling & Serialization
* **JSON Serialization:** Use `json_serializable` and `json_annotation` for
  parsing and encoding JSON data.
* **Field Renaming:** When encoding data, use `fieldRename: FieldRename.snake`
  to convert Dart's camelCase fields to snake_case JSON keys.

  

## Logging
* **Structured Logging:** Use the `log` function from `dart:developer` for
  structured logging that integrates with Dart DevTools. Never use `print()`.

  

## Code Generation
* **Build Runner:** If the project uses code generation, ensure that
  `build_runner` is listed as a dev dependency in `pubspec.yaml`.
* **Code Generation Tasks:** Use `build_runner` for all code generation tasks,
  such as for `json_serializable`.
* **Running Build Runner:** After modifying files that require code generation,
  run the build command:

---

### Flutter layout patterns — Row/Column, Stack, Overlay, scrolling, LayoutBuilder.
> Applies to: `mobile/lib/**/view/**/*.dart, mobile/lib/**/widgets/**/*.dart`

# Flutter Layout Best Practices

## Layout Best Practices

### Building Flexible and Overflow-Safe Layouts

#### For Rows and Columns

* **`Expanded`:** Use to make a child widget fill the remaining available space
  along the main axis.
* **`Flexible`:** Use when you want a widget to shrink to fit, but not
  necessarily grow. Don't combine `Flexible` and `Expanded` in the same `Row` or
  `Column`.
* **`Wrap`:** Use when you have a series of widgets that would overflow a `Row`
  or `Column`, and you want them to move to the next line.

#### For General Content

* **`SingleChildScrollView`:** Use when your content is intrinsically larger
  than the viewport, but is a fixed size.
* **`ListView` / `GridView`:** For long lists or grids of content, always use a
  builder constructor (`.builder`).
* **`FittedBox`:** Use to scale or fit a single child widget within its parent.
* **`LayoutBuilder`:** Use for complex, responsive layouts to make decisions
  based on the available space.

### Layering Widgets with Stack

* **`Positioned`:** Use to precisely place a child within a `Stack` by anchoring it to the edges.
* **`Align`:** Use to position a child within a `Stack` using alignments like `Alignment.center`.

### Advanced Layout with Overlays

* **`OverlayPortal`:** Use this widget to show UI elements (like custom
  dropdowns or tooltips) "on top" of everything else. It manages the
  `OverlayEntry` for you.

---

### Flutter/Dart testing best practices.
> Applies to: `mobile/test/**/*.dart, mobile/packages/*/test/**/*.dart`

# Flutter/Dart Testing Best Practices

This rule provides comprehensive guidelines for writing high-quality tests in Flutter/Dart projects, following testing standards.

## Test File Organization

Test files should mirror your project structure:

## Essential Testing Patterns

### 1. Always Assert Test Results

Every test must have assertions using `expect` or `verify`:

### 2. Use Matchers for Better Messages

Always use matchers instead of direct comparisons:

### 3. String Expressions for Types

Use string interpolation for type references in test descriptions:

### 4. Descriptive Test Names

Be verbose and descriptive in test names:

### 5. Single Purpose Tests

Test one scenario per test:

### 6. Find Widgets by Type, Not Keys

Prefer finding widgets by type over hardcoded keys:

### 7. Private Mocks

Use private mocks to avoid shared state between test files:

### 8. Group Tests by Functionality

Organize tests into logical groups:

### 9. Keep Setup Inside Groups

Always put `setUp` and `tearDown` inside groups:

### 10. Initialize Mutable Objects Per Test

Avoid shared mutable state between tests:

### 11. Use Constants for Test Tags

Avoid magic strings when tagging tests:

### 12. Avoid Shared State Between Tests

Ensure tests are completely independent:

## Running Tests

Use random test ordering to catch flaky tests:

## Coverage Rule

**≥80% line coverage per file** — not just overall. A module that averages 86% overall but has a file at 40% violates this rule.

**Exemptions** (do not count against the threshold):
- Generated files: `*.g.dart`, `app_localizations*.dart`, `*.freezed.dart`
- Single-line config stubs (≤3 lines of executable code)

Every new `lib/` file added in a phase must have a corresponding test file that brings it to ≥80%. Hiding low coverage behind a high-coverage overall score is not acceptable.

## Quick Reference

- ✅ Always use `expect()` or `verify()` assertions
- ✅ Use matchers (`equals`, `isTrue`, `hasLength`, etc.)
- ✅ Use string interpolation for types: `'renders $WidgetName'`
- ✅ Write descriptive test names
- ✅ Test one scenario per test
- ✅ Find widgets by type: `find.byType(WidgetClass)`
- ✅ Use private mocks: `_MockClassName`
- ✅ Group related tests
- ✅ Keep setup inside groups
- ✅ Initialize mutable objects per test
- ✅ Use constants for test tags
- ✅ Avoid shared state between tests

- ❌ Don't skip assertions
- ❌ Don't use direct comparisons without matchers
- ❌ Don't use hardcoded keys for finding widgets
- ❌ Don't use public mocks
- ❌ Don't put setup outside groups
- ❌ Don't share mutable state between tests
- ❌ Don't use magic strings for tags

---

### Flutter UI theming, Material 3, ThemeData, ColorScheme, ThemeExtension, WidgetStateProperty, fonts, and accessibility.
> Applies to: `mobile/lib/**/view/**/*.dart, mobile/lib/**/widgets/**/*.dart, mobile/packages/app_ui/lib/**/*.dart`

# Flutter UI Theming & Styling

## Visual Design & Theming
* **UI Design:** Build beautiful and intuitive user interfaces that follow
  modern design guidelines.
* **Responsiveness:** Ensure the app is mobile responsive and adapts to
  different screen sizes, working perfectly on mobile and web.
* **Navigation:** If there are multiple pages for the user to interact with,
  provide an intuitive and easy navigation bar or controls.
* **Typography:** Stress and emphasize font sizes to ease understanding, e.g.,
  hero text, section headlines, list headlines, keywords in paragraphs.
* **Background:** Apply subtle noise texture to the main background to add a
  premium, tactile feel.
* **Shadows:** Multi-layered drop shadows create a strong sense of depth; cards
  have a soft, deep shadow to look "lifted."
* **Icons:** Incorporate icons to enhance the user's understanding and the
  logical navigation of the app.
* **Interactive Elements:** Buttons, checkboxes, sliders, lists, charts, graphs,
  and other interactive elements have a shadow with elegant use of color to
  create a "glow" effect.

### Theming
* **Centralized Theme:** Define a centralized `ThemeData` object to ensure a
  consistent application-wide style.
* **Light and Dark Themes:** Implement support for both light and dark themes,
  ideal for a user-facing theme toggle (`ThemeMode.light`, `ThemeMode.dark`,
  `ThemeMode.system`).
* **Color Scheme Generation:** Generate harmonious color palettes from a single
  color using `ColorScheme.fromSeed`.

  
* **Color Palette:** Include a wide range of color concentrations and hues in
  the palette to create a vibrant and energetic look and feel.
* **Component Themes:** Use specific theme properties (e.g., `appBarTheme`,
  `elevatedButtonTheme`) to customize the appearance of individual Material
  components.
* **Custom Fonts:** For custom fonts, use the `google_fonts` package. Define a
  `TextTheme` to apply fonts consistently.

  

### Assets and Images
* **Image Guidelines:** If images are needed, make them relevant and meaningful,
  with appropriate size, layout, and licensing (e.g., freely available). Provide
  placeholder images if real ones are not available.
* **Asset Declaration:** Declare all asset paths in your `pubspec.yaml` file.

    

* **Local Images:** Use `Image.asset` for local images from your asset
  bundle.

    
* **Network images:** Use NetworkImage for images loaded from the network.
* **Cached images:** For cached images, use a package like `cached_network_image`.
* **Custom Icons:** Use `ImageIcon` to display an icon from an `ImageProvider`,
  useful for custom icons not in the `Icons` class.
* **Network Images:** Use `Image.network` to display images from a URL, and
  always include `loadingBuilder` and `errorBuilder` for a better user
  experience.

    

## UI Theming and Styling Code

* **Responsiveness:** Use `LayoutBuilder` or `MediaQuery` to create responsive
  UIs.
* **Text:** Use `Theme.of(context).textTheme` for text styles.

## Material Theming Best Practices

### Embrace `ThemeData` and Material 3

* **Use `ColorScheme.fromSeed()`:** Use this to generate a complete, harmonious
  color palette for both light and dark modes from a single seed color.
* **Define Light and Dark Themes:** Provide both `theme` and `darkTheme` to your
  `MaterialApp` to support system brightness settings seamlessly.
* **Centralize Component Styles:** Customize specific component themes (e.g.,
  `elevatedButtonTheme`, `cardTheme`, `appBarTheme`) within `ThemeData` to
  ensure consistency.
* **Dark/Light Mode and Theme Toggle:** Implement support for both light and
  dark themes using `theme` and `darkTheme` properties of `MaterialApp`. The
  `themeMode` property can be dynamically controlled (e.g., via a
  `ChangeNotifierProvider`) to allow for toggling between `ThemeMode.light`,
  `ThemeMode.dark`, or `ThemeMode.system`.

### Implement Design Tokens with `ThemeExtension`

For custom styles that aren't part of the standard `ThemeData`, use
`ThemeExtension` to define reusable design tokens.

* **Create a Custom Theme Extension:** Define a class that extends
  `ThemeExtension<T>` and include your custom properties.
* **Implement `copyWith` and `lerp`:** These methods are required for the
  extension to work correctly with theme transitions.
* **Register in `ThemeData`:** Add your custom extension to the `extensions`
  list in your `ThemeData`.
* **Access Tokens in Widgets:** Use `Theme.of(context).extension<MyColors>()!`
  to access your custom tokens.

### Styling with `WidgetStateProperty`

* **`WidgetStateProperty.resolveWith`:** Provide a function that receives a
  `Set<WidgetState>` and returns the appropriate value for the current state.
* **`WidgetStateProperty.all`:** A shorthand for when the value is the same for
  all states.

## Color Scheme Best Practices

### Contrast Ratios

* **WCAG Guidelines:** Aim to meet the Web Content Accessibility Guidelines
  (WCAG) 2.1 standards.
* **Minimum Contrast:**
    * **Normal Text:** A contrast ratio of at least **4.5:1**.
    * **Large Text:** (18pt or 14pt bold) A contrast ratio of at least **3:1**.

### Palette Selection

* **Primary, Secondary, and Accent:** Define a clear color hierarchy.
* **The 60-30-10 Rule:** A classic design rule for creating a balanced color scheme.
    * **60%** Primary/Neutral Color (Dominant)
    * **30%** Secondary Color
    * **10%** Accent Color

### Complementary Colors

* **Use with Caution:** They can be visually jarring if overused.
* **Best Use Cases:** They are excellent for accent colors to make specific
  elements pop, but generally poor for text and background pairings as they can
  cause eye strain.

### Example Palette

* **Primary:** #0D47A1 (Dark Blue)
* **Secondary:** #1976D2 (Medium Blue)
* **Accent:** #FFC107 (Amber)
* **Neutral/Text:** #212121 (Almost Black)
* **Background:** #FEFEFE (Almost White)

## Font Best Practices

### Font Selection

* **Limit Font Families:** Stick to one or two font families for the entire
  application.
* **Prioritize Legibility:** Choose fonts that are easy to read on screens of
  all sizes. Sans-serif fonts are generally preferred for UI body text.
* **System Fonts:** Consider using platform-native system fonts.
* **Google Fonts:** For a wide selection of open-source fonts, use the
  `google_fonts` package.

### Hierarchy and Scale

* **Establish a Scale:** Define a set of font sizes for different text elements
  (e.g., headlines, titles, body text, captions).
* **Use Font Weight:** Differentiate text effectively using font weights.
* **Color and Opacity:** Use color and opacity to de-emphasize less important
  text.

### Readability

* **Line Height (Leading):** Set an appropriate line height, typically **1.4x to
  1.6x** the font size.
* **Line Length:** For body text, aim for a line length of **45-75 characters**.
* **Avoid All Caps:** Do not use all caps for long-form text.

### Example Typographic Scale

## Accessibility (A11Y)
Implement accessibility features to empower all users, assuming a wide variety
of users with different physical abilities, mental abilities, age groups,
education levels, and learning styles.

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

### No hardcoded spacing, radius, or color values

Every numeric spacing, border radius, and color value must come from
`mobile/packages/app_ui`.

**Spacing / radius:** use `AppSpacing.*` constants (`xs`, `sm`, `md`, `lg`, `xl`,
`xxl`, `s10`, `xxs`, `xxxs`). If no single token matches, compose with addition:

| Target value | Expression |
|---|---|
| 14 | `AppSpacing.md + AppSpacing.xxs` |
| 18 | `AppSpacing.lg + AppSpacing.xxs` |
| 20 | `AppSpacing.lg + AppSpacing.xs` |
| 22 | `AppSpacing.lg + AppSpacing.xs + AppSpacing.xxs` |
| 28 | `AppSpacing.xl + AppSpacing.xs` |
| 30 | `AppSpacing.xl + AppSpacing.xs + AppSpacing.xxs` |

Exception: `9999` / `999` for pill/stadium shapes is acceptable.

**Colors:** always resolve through `Theme.of(context).colorScheme.*` or
`Theme.of(context).extension<AppThemeExtension>()`. No hex literals
(`Color(0xFF…)`) outside `AppColors` / the theme seed declaration.

**Typography:** use `Theme.of(context).textTheme.*` slots. `fontSize` overrides
are only allowed when the design spec explicitly calls out a value not covered by
the type scale (e.g. `fontSize: 10` in `ScopeChip`).

This rule applies equally to `lib/` feature widgets and to widgets inside
`packages/app_ui`.

---
