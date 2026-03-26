# AUTO-GENERATED — do not edit directly. Edit rules/ and run: npm run generate

# Somnio Agent Rules — Claude Code

Copy this file (or relevant sections) into your project's `CLAUDE.md`.

## Flutter Rules

### General architecture guidelines when using Flutter.

# Flutter Layered Architecture

How to build highly scalable, maintainable, and testable Flutter apps using layered architecture. This architecture consists of four layers with clear boundaries and single responsibilities.

## Architecture Overview

Layered architecture enhances developer experience by allowing independent development of each layer. Each layer can be developed by different teams without impacting others. Testing is simplified since only one layer needs to be mocked.

### Layer Structure

```
Presentation Layer (UI/Widgets)
    ↓
Business Logic Layer (BLoC/State Management)
    ↓
Repository Layer (Domain Logic)
    ↓
Data Layer (External Sources)
```

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
```dart
// api_client.dart
class ApiClient {
  final http.Client _client;
  
  Future<Map<String, dynamic>> makeRequest({
    required String url,
    Map<String, dynamic>? data,
  }) async {
    // Raw HTTP implementation
  }
}
```

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
```dart
// user_repository.dart
class UserRepository {
  const UserRepository(this.apiClient);
  
  final ApiClient apiClient;
  final String loginUrl = '/login';
  
  Future<void> logIn(String email, String password) async {
    await apiClient.makeRequest(
      url: loginUrl,
      data: {
        'email': email,
        'password': password,
      },
    );
  }
}
```

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
```dart
// login_bloc.dart
class LoginBloc extends Bloc<LoginEvent, LoginState> {
  LoginBloc({required UserRepository userRepository})
      : _userRepository = userRepository,
        super(const LoginState()) {
    on<LoginSubmitted>(_onLoginSubmitted);
  }

  final UserRepository _userRepository;

  Future<void> _onLoginSubmitted(
    LoginSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    try {
      await _userRepository.logIn(state.email, state.password);
      emit(const LoginSuccess());
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(const LoginFailure());
    }
  }
}
```

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
```dart
// login_page.dart
class LoginPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LoginBloc(
        userRepository: context.read<UserRepository>(),
      ),
      child: BlocListener<LoginBloc, LoginState>(
        listener: (context, state) {
          if (state.status == LoginStatus.success) {
            Navigator.of(context).pushReplacementNamed('/home');
          }
        },
        child: LoginForm(),
      ),
    );
  }
}
```

## Project Organization

### Directory Structure

```
my_app/
├── lib/                    # Presentation + Business Logic
│   ├── login/
│   │   ├── bloc/
│   │   │   ├── login_bloc.dart
│   │   │   ├── login_event.dart
│   │   │   └── login_state.dart
│   │   ├── view/
│   │   │   ├── login_page.dart
│   │   │   └── view.dart
│   │   └── login.dart
│   └── main.dart
├── packages/               # Data + Repository Layers
│   ├── user_repository/
│   │   ├── lib/
│   │   │   ├── src/
│   │   │   │   ├── models/
│   │   │   │   │   ├── models.dart
│   │   │   │   │   └── user.dart
│   │   │   │   └── user_repository.dart
│   │   │   └── user_repository.dart
│   │   └── test/
│   │       ├── models/
│   │       │   └── user_test.dart
│   │       └── user_repository_test.dart
│   └── api_client/
│       ├── lib/
│       │   ├── src/
│       │   │   └── api_client.dart
│       │   └── api_client.dart
│       └── test/
│           └── api_client_test.dart
└── test/                   # Presentation + Business Logic Tests
    └── login/
        ├── bloc/
        │   ├── login_bloc_test.dart
        │   ├── login_event_test.dart
        │   └── login_state_test.dart
        └── view/
            └── login_page_test.dart
```

### Key Principles

1. **Separation of Concerns**: Each layer has a single responsibility
2. **Dependency Direction**: Data flows bottom-up, dependencies flow top-down
3. **Abstraction**: Implementation details don't leak between layers
4. **Testability**: Each layer can be tested in isolation

## Dependency Rules

### ✅ Good: Proper Layer Dependencies

```dart
// Presentation Layer
class LoginPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LoginButton(
      onPressed: () => context.read<LoginBloc>().add(const LoginSubmitted()),
    );
  }
}

// Business Logic Layer
class LoginBloc extends Bloc<LoginEvent, LoginState> {
  Future<void> _onLoginSubmitted(
    LoginSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    try {
      await _userRepository.logIn(state.email, state.password);
      emit(const LoginSuccess());
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(const LoginFailure());
    }
  }
}

// Repository Layer
class UserRepository {
  const UserRepository(this.apiClient);
  final ApiClient apiClient;
  final String loginUrl = '/login';

  Future<void> logIn(String email, String password) async {
    await apiClient.makeRequest(
      url: loginUrl,
      data: {
        'email': email,
        'password': password,
      },
    );
  }
}
```

### ❌ Bad: Layer Violations

```dart
// ❌ Business Logic Layer accessing Data Layer directly
class LoginBloc extends Bloc<LoginEvent, LoginState> {
  final String loginUrl = '/login'; // ❌ API details leaked

  Future<void> _onLoginSubmitted(
    LoginSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    try {
      // ❌ Direct API access from BLoC
      await apiClient.makeRequest(
        url: loginUrl,
        data: {
          'email': state.email,
          'password': state.password,
        },
      );
      emit(const LoginSuccess());
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(const LoginFailure());
    }
  }
}
```

## Implementation Guidelines

### 1. Layer Boundaries

- **Never skip layers**: Presentation → Business Logic → Repository → Data
- **No cross-layer dependencies**: Repository shouldn't depend on Business Logic
- **Single responsibility**: Each layer has one clear purpose

### 2. Dependency Injection

```dart
// Use dependency injection to provide dependencies
class LoginBloc extends Bloc<LoginEvent, LoginState> {
  LoginBloc({required UserRepository userRepository})
      : _userRepository = userRepository,
        super(const LoginState());
}
```

### 3. Error Handling

```dart
// Handle errors at the appropriate layer
class LoginBloc extends Bloc<LoginEvent, LoginState> {
  Future<void> _onLoginSubmitted(
    LoginSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    try {
      await _userRepository.logIn(state.email, state.password);
      emit(const LoginSuccess());
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(const LoginFailure());
    }
  }
}
```

### 4. Testing Strategy

```dart
// Test each layer in isolation
class LoginBlocTest {
  late MockUserRepository mockUserRepository;
  late LoginBloc loginBloc;

  setUp(() {
    mockUserRepository = MockUserRepository();
    loginBloc = LoginBloc(userRepository: mockUserRepository);
  });

  blocTest<LoginBloc, LoginState>(
    'emits [loading, success] when login succeeds',
    build: () => loginBloc,
    act: (bloc) => bloc.add(const LoginSubmitted()),
    expect: () => [
      const LoginState(status: LoginStatus.loading),
      const LoginState(status: LoginStatus.success),
    ],
  );
}
```

## Common Patterns

### Repository Pattern

```dart
abstract class UserRepository {
  Future<void> logIn(String email, String password);
  Future<User> getUser(String id);
  Future<void> updateUser(User user);
}

class UserRepositoryImpl implements UserRepository {
  const UserRepositoryImpl(this.apiClient);
  final ApiClient apiClient;
  
  @override
  Future<void> logIn(String email, String password) async {
    // Implementation
  }
}
```

### BLoC Pattern

```dart
// Events
abstract class LoginEvent extends Equatable {
  const LoginEvent();
}

class LoginSubmitted extends LoginEvent {
  const LoginSubmitted();
  
  @override
  List<Object?> get props => [];
}

// States
class LoginState extends Equatable {
  const LoginState({
    this.status = LoginStatus.initial,
    this.email = '',
    this.password = '',
  });
  
  final LoginStatus status;
  final String email;
  final String password;
  
  @override
  List<Object?> get props => [status, email, password];
}
```

### Widget Organization

```dart
// Feature-level barrel file
export 'bloc/bloc.dart';
export 'view/view.dart';

// View barrel file
export 'login_page.dart';
export 'login_form.dart';

// BLoC barrel file
export 'login_bloc.dart';
export 'login_event.dart';
export 'login_state.dart';
```

## Best Practices

1. **Layer Isolation**: Each layer should be independent and testable
2. **Dependency Direction**: Always flow from top to bottom
3. **Abstraction**: Hide implementation details behind interfaces
4. **Single Responsibility**: Each class has one clear purpose
5. **Error Boundaries**: Handle errors at the appropriate layer
6. **Testing**: Test each layer in isolation with mocks
7. **Documentation**: Document layer boundaries and responsibilities
8. **Consistency**: Follow the same patterns across all features

## Common Anti-Patterns to Avoid

1. **Direct Data Layer Access**: Never access data layer from presentation or business logic
2. **Cross-Layer Dependencies**: Don't create circular dependencies between layers
3. **Business Logic in UI**: Keep all business logic in the business logic layer
4. **Hardcoded Dependencies**: Use dependency injection instead of direct instantiation
5. **Mixed Responsibilities**: Don't mix conce

---

### General guidelines when using Flutter

# AI rules for Flutter

You are an expert in Flutter and Dart development. Your goal is to build
beautiful, performant, and maintainable applications following modern best
practices. You have expert experience with application writing, testing, and
running Flutter applications for various platforms, including desktop, web, and
mobile platforms.

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


## Flutter style guide
* **SOLID Principles:** Apply SOLID principles throughout the codebase.
* **Concise and Declarative:** Write concise, modern, technical Dart code.
  Prefer functional and declarative patterns.
* **Composition over Inheritance:** Favor composition for building complex
  widgets and logic.
* **Immutability:** Prefer immutable data structures. Widgets (especially
  `StatelessWidget`) should be immutable.
* **State Management:** Separate ephemeral state and app state. Use a state
  management solution for app state to handle the separation of concerns.
* **Widgets are for UI:** Everything in Flutter's UI is a widget. Compose
  complex UIs from smaller, reusable widgets.
* **Navigation:** Use a modern routing package like `auto_route` or `go_router`.
  See the [navigation guide](./navigation.md) for a detailed example using
  `go_router`.

## Package Management
* **Pub Tool:** To manage packages, use the `pub` tool, if available.
* **External Packages:** If a new feature requires an external package, use the
  `pub_dev_search` tool, if it is available. Otherwise, identify the most
  suitable and stable package from pub.dev.
* **Adding Dependencies:** To add a regular dependency, use the `pub` tool, if
  it is available. Otherwise, run `flutter pub add <package_name>`.
* **Adding Dev Dependencies:** To add a development dependency, use the `pub`
  tool, if it is available, with `dev:<package name>`. Otherwise, run `flutter
  pub add dev:<package_name>`.
* **Dependency Overrides:** To add a dependency override, use the `pub` tool, if
  it is available, with `override:<package name>:1.0.0`. Otherwise, run `flutter
  pub add override:<package_name>:1.0.0`.
* **Removing Dependencies:** To remove a dependency, use the `pub` tool, if it
  is available. Otherwise, run `dart pub remove <package_name>`.

## Code Quality
* **Code structure:** Adhere to maintainable code structure and separation of
  concerns (e.g., UI logic separate from business logic).
* **Naming conventions:** Avoid abbreviations and use meaningful, consistent,
  descriptive names for variables, functions, and classes.
* **Conciseness:** Write code that is as short as it can be while remaining
  clear.
* **Simplicity:** Write straightforward code. Code that is clever or
  obscure is difficult to maintain.
* **Error Handling:** Anticipate and handle potential errors. Don't let your
  code fail silently.
* **Styling:**
    * Line length: Lines should be 80 characters or fewer.
    * Use `PascalCase` for classes, `camelCase` for
      members/variables/functions/enums, and `snake_case` for files.
* **Functions:**
    * Functions short and with a single purpose (strive for less than 20 lines).
* **Testing:** Write code with testing in mind. Use the `file`, `process`, and
  `platform` packages, if appropriate, so you can inject in-memory and fake
  versions of the objects.
* **Logging:** Use the `logging` package instead of `print`.

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

## API Design Principles
When building reusable APIs, such as a library, follow these principles.

* **Consider the User:** Design APIs from the perspective of the person who will
  be using them. The API should be intuitive and easy to use correctly.
* **Documentation is Essential:** Good documentation is a part of good API
  design. It should be clear, concise, and provide examples.


### Data Flow
* **Data Structures:** Define data structures (classes) to represent the data
  used in the application.
* **Data Abstraction:** Abstract data sources (e.g., API calls, database
  operations) using Repositories to promote testability.

### Routing
* **GoRouter:** Use the `go_router` package for declarative navigation, deep
  linking, and web support.
* **GoRouter Setup:** To use `go_router`, first add it to your `pubspec.yaml`
  using the `pub` tool's `add` command.

  ```dart
  // 1. Add the dependency
  // flutter pub add go_router

  // 2. Configure the router
  final GoRouter _router = GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: 'details/:id', // Route with a path parameter
            builder: (context, state) {
              final String id = state.pathParameters['id']!;
              return DetailScreen(id: id);
            },
          ),
        ],
      ),
    ],
  );

  // 3. Use it in your MaterialApp
  MaterialApp.router(
    routerConfig: _router,
  );
  ```
* **Authentication Redirects:** Configure `go_router`'s `redirect` property to
  handle authentication flows, ensuring users are redirected to the login screen
  when unauthorized, and back to their intended destination after successful
  login.

* **Navigator:** Use the built-in `Navigator` for short-lived screens that do
  not need to be deep-linkable, such as dialogs or temporary views.

  ```dart
  // Push a new screen onto the stack
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const DetailsScreen()),
  );

  // Pop the current screen to go back
  Navigator.pop(context);
  ```

### Data Handling & Serialization
* **JSON Serialization:** Use `json_serializable` and `json_annotation` for
  parsing and encoding JSON data.
* **Field Renaming:** When encoding data, use `fieldRename: FieldRename.snake`
  to convert Dart's camelCase fields to snake_case JSON keys.

  ```dart
  // In your model file
  import 'package:json_annotation/json_annotation.dart';

  part 'user.g.dart';

  @JsonSerializable(fieldRename: FieldRename.snake)
  class User {
    final String firstName;
    final String lastName;

    User({required this.firstName, required this.lastName});

    factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
    Map<String, dynamic> toJson() => _$UserToJson(this);
  }
  ```


### Logging
* **Structured Logging:** Use the `log` function from `dart:developer` for
  structured logging that integrates with Dart DevTools.

  ```dart
  import 'dart:developer' as developer;

  // For simple messages
  developer.log('User logged in successfully.');

  // For structured error logging
  try {
    // ... code that might fail
  } catch (e, s) {
    developer.log(
      'Failed to fetch data',
      name: 'myapp.network',
      level: 1000, // SEVERE
      error: e,
      stackTrace: s,
    );
  }
  ```

## Code Generation
* **Build Runner:** If the project uses code generation, ensure that
  `build_runner` is listed as a dev dependency in `pubspec.yaml`.
* **Code Generation Tasks:** Use `build_runner` for all code generation tasks,
  such as for `json_serializable`.
* **Running Build Runner:** After modifying files that require code generation,
  run the build command:

  ```shell
  dart run build_runner build --delete-conflicting-outputs
  ```

## Testing
* **Running Tests:** To run tests, use the `run_tests` tool if it is available,
  otherwise use `flutter test`.
* **Unit Tests:** Use `package:test` for unit tests.
* **Widget Tests:** Use `package:flutter_test` for widget tests.
* **Integration Tests:** Use `package:integration_test` for integration tests.
* **Assertions:** Prefer using `package:checks` for more expressive and readable
  assertions over the default `matchers`.

### Testing Best practices
* **Convention:** Follow the Arrange-Act-Assert (or Given-When-Then) pattern.
* **Unit Tests:** Write unit tests for domain logic, data layer, and state
  management.
* **Widget Tests:** Write widget tests for UI components.
* **Integration Tests:** For broader application validation, use integration
  tests to verify end-to-end user flows.
* **integration_test package:** Use the `integration_test` package from the
  Flutter SDK for integration tests. Add it as a `dev_dependency` in
  `pubspec.yaml` by specifying `sdk: flutter`.
* **Mocks:** Prefer fakes or stubs over mocks. If mocks are absolutely
  necessary, use `mockito` or `mocktail` to create mocks for dependencies. While
  code generation is common for state management (e.g., with `freezed`), try to
  avoid it for mocks.
* **Coverage:** Aim for high test coverage.

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
* **Icons:** Incorporate icons to enhance the user’s understanding and the
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

  ```dart
  final ThemeData lightTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: Brightness.light,
    ),
    // ... other theme properties
  );
  ```
* **Color Palette:** Include a wide range of color concentrations and hues in
  the palette to create a vibrant and energetic look and feel.
* **Component Themes:** Use specific theme properties (e.g., `appBarTheme`,
  `elevatedButtonTheme`) to customize the appearance of individual Material
  components.
* **Custom Fonts:** For custom fonts, use the `google_fonts` package. Define a
  `TextTheme` to apply fonts consistently.

  ```dart
  // 1. Add the dependency
  // flutter pub add google_fonts

  // 2. Define a TextTheme with a custom font
  final TextTheme appTextTheme = TextTheme(
    displayLarge: GoogleFonts.oswald(fontSize: 57, fontWeight: FontWeight.bold),
    titleLarge: GoogleFonts.roboto(fontSize: 22, fontWeight: FontWeight.w500),
    bodyMedium: GoogleFonts.openSans(fontSize: 14),
  );
  ```

### Assets and Images
* **Image Guidelines:** If images are needed, make them relevant and meaningful,
  with appropriate size, layout, and licensing (e.g., freely available). Provide
  placeholder images if real ones are not available.
* **Asset Declaration:** Declare all asset paths in your `pubspec.yaml` file.

    ```yaml
    flutter:
      uses-material-design: true
      assets:
        - assets/images/
    ```

* **Local Images:** Use `Image.asset` for local images from your asset
  bundle.

    ```dart
    Image.asset('assets/images/placeholder.png')
    ```
* **Network images:** Use NetworkImage for images loaded from the network.
* **Cached images:** For cached images, use NetworkImage a package like
  `cached_network_image`.
* **Custom Icons:** Use `ImageIcon` to display an icon from an `ImageProvider`,
  useful for custom icons not in the `Icons` class.
* **Network Images:** Use `Image.network` to display images from a URL, and
  always include `loadingBuilder` and `errorBuilder` for a better user
  experience.

    ```dart
    Image.network(
      'https://picsum.photos/200/300',
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const Center(child: CircularProgressIndicator());
      },
      errorBuilder: (context, error, stackTrace) {
        return const Icon(Icons.error);
      },
    )
    ```
## UI Theming and Styling Code

* **Responsiveness:** Use `LayoutBuilder` or `MediaQuery` to create responsive
  UIs.
* **Text:** Use `Theme.of(context).textTheme` for text styles.
* **Text Fields:** Configure `textCapitalization`, `keyboardType`, and
* **Responsiveness:** Use `LayoutBuilder` or `MediaQuery` to create responsive
  UIs.
* **Text:** Use `Theme.of(context).textTheme` for text styles.
  remote images.

```dart
// When using network images, always provide an errorBuilder.
Image.network(
  'https://example.com/image.png',
  errorBuilder: (context, error, stackTrace) {
    return const Icon(Icons.error); // Show an error icon
  },
);
```

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

```dart
// main.dart
MaterialApp(
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: Brightness.light,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 57.0, fontWeight: FontWeight.bold),
      bodyMedium: TextStyle(fontSize: 14.0, height: 1.4),
    ),
  ),
  darkTheme: ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: Brightness.dark,
    ),
  ),
  home: const MyHomePage(),
);
```

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

```dart
// 1. Define the extension
@immutable
class MyColors extends ThemeExtension<MyColors> {
  const MyColors({required this.success, required this.danger});

  final Color? success;
  final Color? danger;

  @override
  ThemeExtension<MyColors> copyWith({Color? success, Color? danger}) {
    return MyColors(success: success ?? this.success, danger: danger ?? this.danger);
  }

  @override
  ThemeExtension<MyColors> lerp(ThemeExtension<MyColors>? other, double t) {
    if (other is! MyColors) return this;
    return MyColors(
      success: Color.lerp(success, other.success, t),
      danger: Color.lerp(danger, other.danger, t),
    );
  }
}

// 2. Register it in ThemeData
theme: ThemeData(
  extensions: const <ThemeExtension<dynamic>>[
    MyColors(success: Colors.green, danger: Colors.red),
  ],
),

// 3. Use it in a widget
Container(
  color: Theme.of(context).extension<MyColors>()!.success,
)
```

### Styling with `WidgetStateProperty`

* **`WidgetStateProperty.resolveWith`:** Provide a function that receives a
  `Set<WidgetState>` and returns the appropriate value for the current state.
* **`WidgetStateProperty.all`:** A shorthand for when the value is the same for
  all states.

```dart
// Example: Creating a button style that changes color when pressed.
final ButtonStyle myButtonStyle = ButtonStyle(
  backgroundColor: WidgetStateProperty.resolveWith<Color>(
    (Set<WidgetState> states) {
      if (states.contains(WidgetState.pressed)) {
        return Colors.green; // Color when pressed
      }
      return Colors.red; // Default color
    },
  ),
);
```

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

  ```dart
  class MyDropdown extends StatefulWidget {
    const MyDropdown({super.key});

    @override
    State<MyDropdown> createState() => _MyDropdownState();
  }

  class _MyDropdownState extends State<MyDropdown> {
    final _controller = OverlayPortalController();

    @override
    Widget build(BuildContext context) {
      return OverlayPortal(
        controller: _controller,
        overlayChildBuilder: (BuildContext context) {
          return const Positioned(
            top: 50,
            left: 10,
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('I am an overlay!'),
              ),
            ),
          );
        },
        child: ElevatedButton(
          onPressed: _controller.toggle,
          child: const Text('Toggle Overlay'),
        ),
      );
    }
  }
  ```

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

```dart
// In your ThemeData
textTheme: const TextTheme(
  displayLarge: TextStyle(fontSize: 57.0, fontWeight: FontWeight.bold),
  titleLarge: TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold),
  bodyLarge: TextStyle(fontSize: 16.0, height: 1.5),
  bodyMedium: TextStyle(fontSize: 14.0, height: 1.4),
  labelSmall: TextStyle(fontSize: 11.0, color: Colors.grey),
),
```

## Documentation

* **`dartdoc`:** Write `dartdoc`-style comments for all public APIs.


### Documentation Philosophy

* **Comment wisely:** Use comments to explain why the code is written a certain
  way, not what the code does. The code itself should be self-explanatory.
* **Document for the user:** Write documentation with the reader in mind. If you
  had a question and found the answer, add it to the documentation where you
  first looked. This ensures the documentation answers real-world questions.
* **No useless documentation:** If the documentation only restates the obvious
  from the code's name, it's not helpful. Good documentation provides context
  and explains what isn't immediately apparent.
* **Consistency is key:** Use consistent terminology throughout your
  documentation.

### Commenting Style

* **Use `///` for doc comments:** This allows documentation generation tools to
  pick them up.
* **Start with a single-sentence summary:** The first sentence should be a
  concise, user-centric summary ending with a period.
* **Separate the summary:** Add a blank line after the first sentence to create
  a separate paragraph. This helps tools create better summaries.
* **Avoid redundancy:** Don't repeat information that's obvious from the code's
  context, like the class name or signature.
* **Don't document both getter and setter:** For properties with both, only
  document one. The documentation tool will treat them as a single field.

### Writing Style

* **Be brief:** Write concisely.
* **Avoid jargon and acronyms:** Don't use abbreviations unless they are widely
  understood.
* **Use Markdown sparingly:** Avoid excessive markdown and never use HTML for
  formatting.
* **Use backticks for code:** Enclose code blocks in backtick fences, and
  specify the language.

### What to Document

* **Public APIs are a priority:** Always document public APIs.
* **Consider private APIs:** It's a good idea to document private APIs as well.
* **Library-level comments are helpful:** Consider adding a doc comment at the
  library level to provide a general overview.
* **Include code samples:** Where appropriate, add code samples to illustrate usage.
* **Explain parameters, return values, and exceptions:** Use prose to describe
  what a function expects, what it returns, and what errors it might throw.
* **Place doc comments before annotations:** Documentation should come before
  any metadata annotations.

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

> Applies to: `**/*bloc_test.dart`

# Bloc Testing Standards

How to write comprehensive bloc tests following the project's established patterns and conventions.

## Usage

To use this rule when writing bloc tests:

1. Reference this rule when writing BLoC tests.
2. Reference the bloc folder you're testing.
3. Follow the directory structure and naming conventions below

## Directory Structure

Follow this exact structure for bloc files and tests:

```
lib/feature_name/bloc/
├── feature_name_bloc.dart
├── feature_name_event.dart
└── feature_name_state.dart

test/feature_name/bloc/
├── feature_name_bloc_test.dart
├── feature_name_event_test.dart
└── feature_name_state_test.dart
```

## Required Imports

Import only what you need:

```dart
// Always required for bloc tests
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

// Only if mocking dependencies
import 'package:mocktail/mocktail.dart';

// Import your feature's bloc files
import 'package:your_app/feature_name/feature_name.dart';

// Only if bloc has repository/dependency
import 'package:your_repository/your_repository.dart';
```

## Test File Structure

### 1. Bloc Test File (`feature_name_bloc_test.dart`)

Structure: **Bloc → Event → Test Cases** (focus on state changes)

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:your_app/feature_name/feature_name.dart';

// Only add if bloc has dependencies
import 'package:mocktail/mocktail.dart';
import 'package:your_repository/your_repository.dart';

// Only if mocking repositories
class MockYourRepository extends Mock implements YourRepository {}

void main() {
  group('FeatureNameBloc', () {
    // Only if bloc has dependencies
    late YourRepository yourRepository;

    setUp(() {
      // Only if mocking
      yourRepository = MockYourRepository();
      when(() => yourRepository.someMethod()).thenAnswer((_) async {});
    });

    FeatureNameBloc buildBloc() {
      return FeatureNameBloc(repository: yourRepository);
    }

    group('constructor', () {
      test('works properly', () => expect(buildBloc, returnsNormally));

      test('has correct initial state', () {
        expect(
          buildBloc().state,
          equals(const FeatureNameState()),
        );
      });
    });

    group('EventName', () {
      blocTest<FeatureNameBloc, FeatureNameState>(
        'emits [loading, success] when event succeeds',
        setUp: () {
          when(() => yourRepository.someMethod())
              .thenAnswer((_) async => result);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const EventName()),
        expect: () => const <FeatureNameState>[
          FeatureNameState(status: Status.loading),
          FeatureNameState(status: Status.success),
        ],
        verify: (_) {
          verify(() => yourRepository.someMethod()).called(1);
        },
      );

      blocTest<FeatureNameBloc, FeatureNameState>(
        'emits [loading, failure] when event fails',
        setUp: () {
          when(() => yourRepository.someMethod())
              .thenThrow(Exception('error'));
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const EventName()),
        expect: () => const <FeatureNameState>[
          FeatureNameState(status: Status.loading),
          FeatureNameState(status: Status.failure),
        ],
      );
    });
  });
}
```

### 2. Event Test File (`feature_name_event_test.dart`)

```dart
// ignore_for_file: prefer_const_constructors
import 'package:flutter_test/flutter_test.dart';
import 'package:your_app/feature_name/feature_name.dart';

void main() {
  group('FeatureNameEvent', () {
    group('EventName', () {
      test('supports value equality', () {
        expect(
          EventName(),
          equals(EventName()),
        );
      });

      test('props are correct', () {
        expect(
          EventName().props,
          equals(<Object?>[]),
        );
      });
    });

    group('EventWithData', () {
      const data = 'test-data';
      
      test('supports value equality', () {
        expect(
          EventWithData(data),
          equals(EventWithData(data)),
        );
      });

      test('props are correct', () {
        expect(
          EventWithData(data).props,
          equals(<Object?>[data]),
        );
      });
    });
  });
}
```

### 3. State Test File (`feature_name_state_test.dart`)

```dart
// ignore_for_file: prefer_const_constructors, avoid_redundant_argument_values
import 'package:flutter_test/flutter_test.dart';
import 'package:your_app/feature_name/feature_name.dart';

void main() {
  group('FeatureNameState', () {
    FeatureNameState createSubject({
      Status status = Status.initial,
      String? data,
    }) {
      return FeatureNameState(
        status: status,
        data: data,
      );
    }

    test('supports value equality', () {
      expect(
        createSubject(),
        equals(createSubject()),
      );
    });

    test('props are correct', () {
      expect(
        createSubject(
          status: Status.initial,
          data: 'test',
        ).props,
        equals(<Object?>[
          Status.initial, // status
          'test', // data
        ]),
      );
    });

    group('copyWith', () {
      test('returns the same object if no arguments are provided', () {
        expect(
          createSubject().copyWith(),
          equals(createSubject()),
        );
      });

      test('retains the old value for every parameter if null is provided', () {
        expect(
          createSubject().copyWith(
            status: null,
            data: null,
          ),
          equals(createSubject()),
        );
      });

      test('replaces every non-null parameter', () {
        expect(
          createSubject().copyWith(
            status: () => Status.success,
            data: () => 'new-data',
          ),
          equals(
            createSubject(
              status: Status.success,
              data: 'new-data',
            ),
          ),
        );
      });
    });
  });
}
```

## Testing Patterns

### 1. Mock Setup (Only if needed)

```dart
// Only use if bloc has dependencies
class MockRepository extends Mock implements Repository {}

setUp(() {
  repository = MockRepository();
  when(() => repository.method()).thenAnswer((_) async {});
});
```

### 2. BlocTest Structure

```dart
blocTest<BlocType, StateType>(
  'emits [state1, state2] when event succeeds', // Descriptive but concise
  setUp: () {
    // Setup specific mock behaviors for this test
    when(() => repository.method()).thenAnswer((_) async => result);
  },
  build: () => buildBloc(),
  seed: () => initialState, // Optional: set initial state
  act: (bloc) => bloc.add(event),
  expect: () => [expectedState1, expectedState2],
  verify: (_) {
    // Verify mock interactions
    verify(() => repository.method()).called(1);
  },
);
```

### 3. Test Organization

- **Bloc → Event → Test Cases**: Group by bloc, then by event, then test cases
- **Focus on State Changes**: Test descriptions should explain what state changes occur
- **Descriptive but Concise**: Test names should be clear but not verbose

## Official Documentation Examples

### Login Bloc Test Pattern

```dart
// Simple form-based bloc with validation
blocTest<LoginBloc, LoginState>(
  'emits [submissionInProgress, submissionSuccess] when login succeeds',
  setUp: () {
    when(() => authenticationRepository.logIn(
      username: 'username',
      password: 'password',
    )).thenAnswer((_) => Future<String>.value('user'));
  },
  build: () => LoginBloc(authenticationRepository: authenticationRepository),
  act: (bloc) {
    bloc
      ..add(const LoginUsernameChanged('username'))
      ..add(const LoginPasswordChanged('password'))
      ..add(const LoginSubmitted());
  },
  expect: () => const <LoginState>[
    LoginState(username: Username.dirty('username')),
    LoginState(
      username: Username.dirty('username'),
      password: Password.dirty('password'),
      isValid: true,
    ),
    LoginState(
      username: Username.dirty('username'),
      password: Password.dirty('password'),
      isValid: true,
      status: FormzSubmissionStatus.inProgress,
    ),
    LoginState(
      username: Username.dirty('username'),
      password: Password.dirty('password'),
      isValid: true,
      status: FormzSubmissionStatus.success,
    ),
  ],
);
```

### Todos Overview Bloc Test Pattern

```dart
// Complex bloc with multiple events and stream handling
blocTest<TodosOverviewBloc, TodosOverviewState>(
  'emits state with updated status and todos when repository stream emits',
  build: buildBloc,
  act: (bloc) => bloc.add(const TodosOverviewSubscriptionRequested()),
  expect: () => [
    const TodosOverviewState(status: TodosOverviewStatus.loading),
    TodosOverviewState(
      status: TodosOverviewStatus.success,
      todos: mockTodos,
    ),
  ],
);
```

### Edit Todo Bloc Test Pattern

```dart
// Bloc with conditional logic based on initial state
blocTest<EditTodoBloc, EditTodoState>(
  'emits [loading, success] when saving new todo',
  setUp: () {
    when(() => todosRepository.saveTodo(any())).thenAnswer((_) async {});
  },
  build: buildBloc,
  seed: () => const EditTodoState(title: 'title', description: 'description'),
  act: (bloc) => bloc.add(const EditTodoSubmitted()),
  expect: () => const [
    EditTodoState(
      status: EditTodoStatus.loading,
      title: 'title',
      description: 'description',
    ),
    EditTodoState(
      status: EditTodoStatus.success,
      title: 'title',
      description: 'description',
    ),
  ],
  verify: (bloc) {
    verify(() => todosRepository.saveTodo(any())).called(1);
  },
);
```

## Best Practices

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

## Common Patterns

### Testing Stream-Based Blocs

```dart
blocTest<BlocType, StateType>(
  'emits [loading, success] when stream emits data',
  build: buildBloc,
  act: (bloc) => bloc.add(const StreamSubscriptionRequested()),
  expect: () => [
    const State(status: Status.loading),
    State(status: Status.success, data: streamData),
  ],
);
```

### Testing Form Validation

```dart
blocTest<BlocType, StateType>(
  'emits state with updated field and validation',
  build: buildBloc,
  act: (bloc) => bloc.add(const FieldChanged('value')),
  expect: () => [
    State(field: Field.dirty('value'), isValid: true),
  ],
);
```

### Testing Async Operations

```dart
blocTest<BlocType, StateType>(
  'emits [loading, success] when async operation succeeds',
  setUp: () {
    when(() => repository.asyncMethod()).thenAnswer((_) async => result);
  },
  build: buildBloc,
  act: (bloc) => bloc.add(const AsyncEvent()),
  expect: () => [
    const State(status: Status.loading),
    State(status: Status.success, data: result),
  ],
);
```

### Testing Error Scenarios

```dart
blocTest<BlocType, StateType>(
  'emits [loading, failure] when repository throws exception',
  setUp: () {
    when(() => repository.method()).thenThrow(Exception('error'));
  },
  build: buildBloc,
  act: (bloc) => bloc.add(const EventName()),
  expect: () => [
    const State(status: Status.loading),
    State(status: Status.failure, errorMessage: 'error'),
  ],
);
```

### Testing Conditional Logic

```dart
blocTest<BlocType, StateType>(
  'emits different states based on condition',
  build: buildBloc,
  seed: () => State(condition: true),
  act: (bloc) => bloc.add(const ConditionalEvent()),
  expect: () => [
    State(condition: true, result: 'success'),
  ],
);
```

---


# Dart Model from JSON Generator

Generate Dart models from JSON with proper serialization using `json_annotation` and `equatable`.

## Requirements

- Use `json_annotation` for JSON serialization
- Use `equatable` for value equality
- Include `copyWith` method
- Include `fromJson` and `toJson` methods
- Include `props` getter for equatable
- No `@immutable` decorator needed
- No documentation unless specified
- No `@JsonKey` annotations unless specified

## Model Structure

```dart
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'model_name.g.dart';

@JsonSerializable()
class ModelName extends Equatable {
  ModelName({
    required this.field1,
    this.field2,
    this.field3 = defaultValue,
  });

  final String field1;
  final int? field2;
  final bool field3;

  ModelName copyWith({
    String? field1,
    int? field2,
    bool? field3,
  }) {
    return ModelName(
      field1: field1 ?? this.field1,
      field2: field2 ?? this.field2,
      field3: field3 ?? this.field3,
    );
  }

  static ModelName fromJson(Map<String, dynamic> json) => _$ModelNameFromJson(json);
  Map<String, dynamic> toJson() => _$ModelNameToJson(this);

  @override
  List<Object?> get props => [field1, field2, field3];
}
```

## Field Type Mapping

- `String` → `String`
- `int` → `int`
- `double` → `double`
- `bool` → `bool`
- `null` → nullable type (e.g., `String?`)
- `array` → `List<Type>`
- `object` → custom class or `Map<String, dynamic>`

## Complex JSON Example with Nested Objects

Input JSON:
```json
{
  "id": "123",
  "name": "John Doe",
  "age": 30,
  "isActive": true,
  "tags": ["tag1", "tag2"],
  "address": {
    "street": "123 Main St",
    "city": "New York",
    "zipCode": "10001",
    "country": "USA"
  },
  "profile": {
    "avatar": "https://example.com/avatar.jpg",
    "bio": "Software developer",
    "preferences": {
      "theme": "dark",
      "notifications": true,
      "language": "en"
    }
  },
  "orders": [
    {
      "orderId": "ORD-001",
      "items": [
        {
          "productId": "PROD-001",
          "name": "Laptop",
          "price": 999.99,
          "quantity": 1
        }
      ],
      "total": 999.99,
      "status": "completed"
    }
  ]
}
```

Generated Models:

**Main Model (User):**
```dart
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

@JsonSerializable()
class User extends Equatable {
  User({
    required this.id,
    required this.name,
    required this.age,
    required this.isActive,
    required this.tags,
    required this.address,
    required this.profile,
    required this.orders,
  });

  final String id;
  final String name;
  final int age;
  final bool isActive;
  final List<String> tags;
  final Address address;
  final Profile profile;
  final List<Order> orders;

  User copyWith({
    String? id,
    String? name,
    int? age,
    bool? isActive,
    List<String>? tags,
    Address? address,
    Profile? profile,
    List<Order>? orders,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      age: age ?? this.age,
      isActive: isActive ?? this.isActive,
      tags: tags ?? this.tags,
      address: address ?? this.address,
      profile: profile ?? this.profile,
      orders: orders ?? this.orders,
    );
  }

  static User fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);

  @override
  List<Object?> get props => [id, name, age, isActive, tags, address, profile, orders];
}
```

**Address Model:**
```dart
@JsonSerializable()
class Address extends Equatable {
  Address({
    required this.street,
    required this.city,
    required this.zipCode,
    required this.country,
  });

  final String street;
  final String city;
  final String zipCode;
  final String country;

  Address copyWith({
    String? street,
    String? city,
    String? zipCode,
    String? country,
  }) {
    return Address(
      street: street ?? this.street,
      city: city ?? this.city,
      zipCode: zipCode ?? this.zipCode,
      country: country ?? this.country,
    );
  }

  static Address fromJson(Map<String, dynamic> json) => _$AddressFromJson(json);
  Map<String, dynamic> toJson() => _$AddressToJson(this);

  @override
  List<Object?> get props => [street, city, zipCode, country];
}
```

**Profile Model:**
```dart
@JsonSerializable()
class Profile extends Equatable {
  Profile({
    required this.avatar,
    required this.bio,
    required this.preferences,
  });

  final String avatar;
  final String bio;
  final Preferences preferences;

  Profile copyWith({
    String? avatar,
    String? bio,
    Preferences? preferences,
  }) {
    return Profile(
      avatar: avatar ?? this.avatar,
      bio: bio ?? this.bio,
      preferences: preferences ?? this.preferences,
    );
  }

  static Profile fromJson(Map<String, dynamic> json) => _$ProfileFromJson(json);
  Map<String, dynamic> toJson() => _$ProfileToJson(this);

  @override
  List<Object?> get props => [avatar, bio, preferences];
}
```

**Preferences Model:**
```dart
@JsonSerializable()
class Preferences extends Equatable {
  Preferences({
    required this.theme,
    required this.notifications,
    required this.language,
  });

  final String theme;
  final bool notifications;
  final String language;

  Preferences copyWith({
    String? theme,
    bool? notifications,
    String? language,
  }) {
    return Preferences(
      theme: theme ?? this.theme,
      notifications: notifications ?? this.notifications,
      language: language ?? this.language,
    );
  }

  static Preferences fromJson(Map<String, dynamic> json) => _$PreferencesFromJson(json);
  Map<String, dynamic> toJson() => _$PreferencesToJson(this);

  @override
  List<Object?> get props => [theme, notifications, language];
}
```

**Order Model:**
```dart
@JsonSerializable()
class Order extends Equatable {
  Order({
    required this.orderId,
    required this.items,
    required this.total,
    required this.status,
  });

  final String orderId;
  final List<OrderItem> items;
  final double total;
  final String status;

  Order copyWith({
    String? orderId,
    List<OrderItem>? items,
    double? total,
    String? status,
  }) {
    return Order(
      orderId: orderId ?? this.orderId,
      items: items ?? this.items,
      total: total ?? this.total,
      status: status ?? this.status,
    );
  }

  static Order fromJson(Map<String, dynamic> json) => _$OrderFromJson(json);
  Map<String, dynamic> toJson() => _$OrderToJson(this);

  @override
  List<Object?> get props => [orderId, items, total, status];
}
```

**OrderItem Model:**
```dart
@JsonSerializable()
class OrderItem extends Equatable {
  OrderItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
  });

  final String productId;
  final String name;
  final double price;
  final int quantity;

  OrderItem copyWith({
    String? productId,
    String? name,
    double? price,
    int? quantity,
  }) {
    return OrderItem(
      productId: productId ?? this.productId,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
    );
  }

  static OrderItem fromJson(Map<String, dynamic> json) => _$OrderItemFromJson(json);
  Map<String, dynamic> toJson() => _$OrderItemToJson(this);

  @override
  List<Object?> get props => [productId, name, price, quantity];
}
```

## Guidelines

1. **Naming**: Use PascalCase for class names, camelCase for fields
2. **Required fields**: Use `required` keyword for non-nullable fields
3. **Nullable fields**: Add `?` to type for nullable fields
4. **Default values**: Provide default values in constructor when appropriate
5. **Lists**: Use `List<Type>` for arrays
6. **Nested Objects**: Create separate classes for nested objects instead of using `Map<String, dynamic>`
7. **Props**: Include all fields in the `props` list for equatable comparison (use `List<Object?>` type)
8. **CopyWith**: Include all fields as optional parameters
9. **JsonKey**: Do not add `@JsonKey(name: 'snake_case_name')` annotations unless explicitly specified

## Nested Object Handling

### Class Name Inference Rules:
- **Direct object**: Use the field name in PascalCase (e.g., `address` → `Address`)
- **Nested object**: Use the field name in PascalCase (e.g., `profile.preferences` → `Preferences`)
- **Array items**: Use singular form of the array name in PascalCase (e.g., `orders` → `Order`, `items` → `OrderItem`)
- **Context-based**: If context is unclear, ask for clarification

### When to Create Separate Classes:
- ✅ **Always create classes** for objects with multiple properties
- ✅ **Create classes** for array items that are objects
- ❌ **Don't create classes** for primitive arrays (use `List<String>`, `List<int>`, etc.)

### Context Inference Examples:
- `user.address` → `Address` class
- `user.profile.preferences` → `Preferences` class  
- `user.orders[].items[]` → `Order` and `OrderItem` classes
- `product.categories[]` → `Category` class (if objects) or `List<String>` (if strings)

### When Context is Unclear:
If the JSON structure doesn't provide enough context to infer meaningful class names, ask the user for clarification:
- "What should I name the class for the nested object at `path.to.object`?"
- "Should I create a separate class for the array items in `arrayName`?"

---

> Applies to: `**/*_test.dart, **/test/**/*.dart`

# Flutter/Dart Testing Best Practices

This rule provides comprehensive guidelines for writing high-quality tests in Flutter/Dart projects, following testing standards.

## Test File Organization

Test files should mirror your project structure:

```dart
// Good: test/models/user_test.dart for lib/models/user.dart
// Good: test/widgets/home_page_test.dart for lib/widgets/home_page.dart
// Bad: test/user_test.dart (flat structure)
```

## Essential Testing Patterns

### 1. Always Assert Test Results

Every test must have assertions using `expect` or `verify`:

```dart
// Good ✅
testWidgets('calls [onTap] on tapping widget', (tester) async {
  var isTapped = false;
  await tester.pumpWidget(SomeTappableWidget(onTap: () => isTapped = true));
  await tester.tap(find.byType(SomeTappableWidget));
  expect(isTapped, isTrue); // Always assert!
});

// Bad ❌
testWidgets('can tap widget', (tester) async {
  await tester.pumpWidget(SomeTappableWidget());
  await tester.tap(find.byType(SomeTappableWidget));
  // No assertion - test passes even if nothing works!
});
```

### 2. Use Matchers for Better Messages

Always use matchers instead of direct comparisons:

```dart
// Good ✅
expect(name, equals('Hank'));
expect(people, hasLength(3));
expect(valid, isTrue);
expect(list, contains('item'));

// Bad ❌
expect(name, 'Hank');
expect(people.length, 3);
expect(valid, true);
```

### 3. String Expressions for Types

Use string interpolation for type references in test descriptions:

```dart
// Good ✅
testWidgets('renders $YourView', (tester) async {});
test('$UserRepository returns user data', () async {});

// Bad ❌
testWidgets('renders YourView', (tester) async {});
```

### 4. Descriptive Test Names

Be verbose and descriptive in test names:

```dart
// Good ✅
testWidgets('renders $YourView when user is authenticated', (tester) async {});
test('given valid email returns success response', () async {});
blocTest<YourBloc, State>('emits $LoadingState when fetching data', () {});

// Bad ❌
testWidgets('renders', (tester) async {});
test('works', () async {});
blocTest<YourBloc, State>('emits', () {});
```

### 5. Single Purpose Tests

Test one scenario per test:

```dart
// Good ✅
testWidgets('renders $WidgetA', (tester) async {});
testWidgets('renders $WidgetB', (tester) async {});

// Bad ❌
testWidgets('renders $WidgetA and $WidgetB', (tester) async {});
```

### 6. Find Widgets by Type, Not Keys

Prefer finding widgets by type over hardcoded keys:

```dart
// Good ✅
expect(find.byType(HomePage), findsOneWidget);
expect(find.byType(ElevatedButton), findsNWidgets(2));

// Bad ❌
expect(find.byKey(Key('homePageKey')), findsOneWidget);
```

### 7. Private Mocks

Use private mocks to avoid shared state between test files:

```dart
// Good ✅
class _MockApiClient extends Mock implements ApiClient {}
class _MockUserRepository extends Mock implements UserRepository {}

// Bad ❌
class MockApiClient extends Mock implements ApiClient {}
```

### 8. Group Tests by Functionality

Organize tests into logical groups:

```dart
void main() {
  group(UserRepository, () {
    late ApiClient apiClient;
    late UserRepository repository;

    setUp(() {
      apiClient = _MockApiClient();
      repository = UserRepository(apiClient);
    });

    group('getUser', () {
      test('returns user when API call succeeds', () async {
        // Test implementation
      });

      test('throws exception when API call fails', () async {
        // Test implementation
      });
    });

    group('updateUser', () {
      test('updates user successfully', () async {
        // Test implementation
      });
    });
  });
}
```

### 9. Keep Setup Inside Groups

Always put `setUp` and `tearDown` inside groups:

```dart
// Good ✅
void main() {
  group(UserRepository, () {
    late ApiClient apiClient;

    setUp(() {
      apiClient = _MockApiClient();
    });

    // Tests...
  });
}

// Bad ❌
void main() {
  late ApiClient apiClient;

  setUp(() {
    apiClient = _MockApiClient();
  });

  group(UserRepository, () {
    // Tests...
  });
}
```

### 10. Initialize Mutable Objects Per Test

Avoid shared mutable state between tests:

```dart
// Good ✅
void main() {
  group(_MySubject, () {
    late _MySubjectDependency myDependency;

    setUp(() {
      myDependency = _MySubjectDependency(); // Fresh instance per test
    });

    test('value starts at 0', () {
      final subject = _MySubject(myDependency);
      expect(subject.value, equals(0));
    });

    test('value can be increased', () {
      final subject = _MySubject(myDependency);
      subject.increase();
      expect(subject.value, equals(1));
    });
  });
}
```

### 11. Use Constants for Test Tags

Avoid magic strings when tagging tests:

```dart
// Good ✅
abstract class TestTag {
  static const golden = 'golden';
  static const integration = 'integration';
  static const unit = 'unit';
}

testWidgets(
  'render matches golden file',
  tags: TestTag.golden,
  (WidgetTester tester) async {
    // Test implementation
  },
);

// Bad ❌
testWidgets(
  'render matches golden file',
  tags: 'golden',
  (WidgetTester tester) async {
    // Test implementation
  },
);
```

### 12. Avoid Shared State Between Tests

Ensure tests are completely independent:

```dart
// Good ✅
void main() {
  group(_Counter, () {
    late _Counter counter;

    setUp(() => counter = _Counter()); // Fresh instance per test

    test('increment', () {
      counter.increment();
      expect(counter.value, 1);
    });

    test('decrement', () {
      counter.decrement();
      expect(counter.value, -1);
    });
  });
}

// Bad ❌
void main() {
  group(_Counter, () {
    final _Counter counter = _Counter(); // Shared instance

    test('increment', () {
      counter.increment();
      expect(counter.value, 1);
    });

    test('decrement', () {
      counter.decrement();
      // This test depends on the previous test's state!
      expect(counter.value, 0);
    });
  });
}
```

## Running Tests

Use random test ordering to catch flaky tests:

```bash
# Randomize test ordering
flutter test --test-randomize-ordering-seed random
dart test --test-randomize-ordering-seed random
```

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

## Nestjs Rules

### Controller patterns for NestJS including decorators, meaningful documentation, and guards.
> Applies to: `**/*.controller.ts`

# NestJS Controller Patterns

How to implement clean, well-documented controllers with proper decorators, guards, and meaningful Swagger documentation.

## Purpose

Controllers handle incoming HTTP requests and return responses. They should:
- Define routes and HTTP methods
- Apply guards and interceptors
- Validate input via DTOs
- Document API with meaningful Swagger decorators (not just restating the endpoint)
- Delegate business logic to services

## Controller Structure

```
feature/
├── feature.controller.ts      # Main controller
├── feature.service.ts         # Business logic
├── dto/
│   ├── create-feature-request.dto.ts
│   ├── update-feature-request.dto.ts
│   ├── feature-query.dto.ts
│   └── feature-response.dto.ts
└── entities/
    └── feature.entity.ts
```

## Patterns

### Meaningful Swagger Documentation

The purpose of Swagger documentation is to generate useful API docs. Documentation should **add value**, not just restate the obvious.

#### Good

```typescript
@ApiTags('users')
@Controller('users')
export class UserController {
  @Post()
  @ApiOperation({
    summary: 'Register a new user account',
    description: 'Creates a new user with email verification. Returns the created user without sensitive data. Sends a verification email to the provided address.',
  })
  @ApiResponse({
    status: 201,
    description: 'User account created successfully. Verification email sent.',
    type: UserResponseDto,
  })
  @ApiResponse({
    status: 409,
    description: 'Email already registered in the system',
  })
  async create(@Body() dto: CreateUserRequestDto): Promise<UserResponseDto> {
    return this.userService.create(dto);
  }

  @Get()
  @ApiOperation({
    summary: 'Search and filter users with pagination',
    description: 'Retrieves users matching the provided filters. Supports pagination, sorting, and full-text search on name and email fields.',
  })
  @ApiResponse({
    status: 200,
    description: 'Paginated list of users matching the filters',
  })
  async findAll(@Query() query: UserQueryDto) {
    return this.userService.findAll(query);
  }

  @Get(':id')
  @ApiOperation({
    summary: 'Get user profile with related data',
    description: 'Retrieves complete user profile including department assignments, roles, and contact information.',
  })
  @ApiParam({
    name: 'id',
    description: 'Unique user identifier (UUID v4)',
    format: 'uuid',
  })
  async findOne(@Param('id') id: string): Promise<UserResponseDto> {
    return this.userService.findOne(id);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({
    summary: 'Deactivate user account',
    description: 'Soft-deletes the user account. User data is retained but account becomes inaccessible. Can be restored by admin within 30 days.',
  })
  async remove(@Param('id') id: string): Promise<void> {
    await this.userService.remove(id);
  }
}
```

#### Bad

```typescript
// Documentation that adds no value - just restates the endpoint
@Get()
@ApiOperation({ summary: 'Get all users' })  // Obvious from GET /users
@ApiResponse({ status: 200, description: 'Success' })  // Not helpful
async findAll() { ... }

@Post()
@ApiOperation({ summary: 'Create user' })  // Obvious from POST /users
async create(@Body() dto: any) { ... }  // Using 'any' instead of typed DTO

@Get(':id')
@ApiOperation({ summary: 'Get user by ID' })  // Obvious, no value added
async findOne(@Param() params) { ... }  // Untyped params
```

### Guards and Authorization

#### Good

```typescript
import { Controller, Get, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiUnauthorizedResponse, ApiForbiddenResponse } from '@nestjs/swagger';

@ApiTags('users')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('users')
export class UserController {
  @Get('profile')
  @ApiOperation({
    summary: 'Get authenticated user profile',
    description: 'Returns the complete profile of the currently authenticated user based on the JWT token.',
  })
  @ApiUnauthorizedResponse({ description: 'Invalid or expired authentication token' })
  async getProfile(@CurrentUser() user: User): Promise<UserResponseDto> {
    return this.userService.findOne(user.id);
  }

  @Get('admin/dashboard')
  @Roles(Role.ADMIN)
  @ApiOperation({
    summary: 'Get admin dashboard data',
    description: 'Retrieves aggregated statistics and recent activity. Requires ADMIN role.',
  })
  @ApiForbiddenResponse({ description: 'User does not have ADMIN role' })
  async getAdminDashboard() {
    return this.userService.getDashboardStats();
  }
}
```

#### Bad

```typescript
// Checking authorization in controller instead of guards
@Get('admin/all')
async findAllAdmin(@CurrentUser() user: User) {
  if (user.role !== 'admin') {
    throw new ForbiddenException();  // Use guards instead
  }
  return this.userService.findAll();
}

// Missing auth documentation
@UseGuards(JwtAuthGuard)
@Get('profile')
async getProfile() {  // Missing @ApiBearerAuth
  // ...
}
```

### Response Formatting with Response DTOs

#### Good

```typescript
@Controller('users')
export class UserController {
  @Get()
  @ApiOkResponse({
    description: 'Paginated list with metadata',
    schema: {
      properties: {
        data: { type: 'array', items: { $ref: '#/components/schemas/UserResponseDto' } },
        meta: {
          type: 'object',
          properties: {
            total: { type: 'number', description: 'Total matching records' },
            page: { type: 'number', description: 'Current page number' },
            limit: { type: 'number', description: 'Records per page' },
            totalPages: { type: 'number', description: 'Total available pages' },
          },
        },
      },
    },
  })
  async findAll(@Query() query: UserQueryDto): Promise<PaginatedResponse<UserResponseDto>> {
    const { data, count } = await this.userService.findAll({
      skip: (query.page - 1) * query.limit,
      take: query.limit,
    });

    return {
      data,
      meta: {
        total: count,
        page: query.page,
        limit: query.limit,
        totalPages: Math.ceil(count / query.limit),
      },
    };
  }
}
```

### File Upload Handling

#### Good

```typescript
@Controller('users')
export class UserController {
  @Post(':id/avatar')
  @UseInterceptors(FileInterceptor('file'))
  @ApiConsumes('multipart/form-data')
  @ApiOperation({
    summary: 'Upload user avatar image',
    description: 'Replaces the current avatar with the uploaded image. Supports JPG, PNG, and GIF formats up to 5MB.',
  })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        file: {
          type: 'string',
          format: 'binary',
          description: 'Image file (JPG, PNG, or GIF)',
        },
      },
    },
  })
  async uploadAvatar(
    @Param('id') id: string,
    @UploadedFile(
      new ParseFilePipe({
        validators: [
          new MaxFileSizeValidator({ maxSize: 5 * 1024 * 1024 }),
          new FileTypeValidator({ fileType: /(jpg|jpeg|png|gif)$/ }),
        ],
      }),
    )
    file: Express.Multer.File,
  ) {
    return this.userService.updateAvatar({ id, file });
  }
}
```

### StreamableFile Response

#### Good

```typescript
@Controller('reports')
export class ReportsController {
  @Get(':id/export')
  @ApiOperation({
    summary: 'Export report as PDF',
    description: 'Generates and downloads a PDF version of the report. Report must be in completed status.',
  })
  @ApiProduces('application/pdf')
  @ApiResponse({
    status: 200,
    description: 'PDF file download',
    content: { 'application/pdf': {} },
  })
  async exportPdf(
    @Param('id') id: string,
    @Res({ passthrough: true }) res: Response,
  ): Promise<StreamableFile> {
    const pdfStream = await this.reportsService.generatePdf(id);

    res.set({
      'Content-Type': 'application/pdf',
      'Content-Disposition': `attachment; filename="report-${id}.pdf"`,
    });

    return new StreamableFile(pdfStream);
  }
}
```

### Nested Routes

#### Good

```typescript
@ApiTags('user-orders')
@Controller('users/:userId')
export class UserOrdersController {
  @Get('orders')
  @ApiOperation({
    summary: 'Get order history for a specific user',
    description: 'Retrieves all orders placed by the user, including order items and payment status.',
  })
  @ApiParam({
    name: 'userId',
    description: 'User identifier',
    format: 'uuid',
  })
  async findUserOrders(
    @Param('userId') userId: string,
    @Query() query: OrderQueryDto,
  ) {
    return this.orderService.findByUser({ userId, ...query });
  }
}
```

## Best Practices

- Use `@ApiTags` to group related endpoints logically
- Write `@ApiOperation` summaries that explain **what** and **why**, not just restate the endpoint
- Add `description` for complex operations explaining behavior, side effects, and requirements
- Document all possible response codes with meaningful descriptions
- Use `@ApiBearerAuth` when endpoints require authentication
- Apply guards at controller or method level as appropriate
- Use typed Request DTOs and Response DTOs (never `any`)
- Return consistent response formats (especially for pagination)
- Use `@HttpCode` to set non-default status codes
- Document `@ApiParam` with format and description
- Keep controllers thin - delegate logic to services

## Common Mistakes

- Writing documentation that just restates the endpoint name
- Missing meaningful descriptions for complex operations
- Business logic in controllers instead of services
- Using `any` type for request bodies or parameters
- Missing `@Param` type annotations
- Not setting proper HTTP status codes
- Authorization logic in controllers instead of guards
- Missing authentication documentation (`@ApiBearerAuth`)
- Inconsistent response formats across endpoints

---

### DTO structure with clear request/response naming, validation, transformation, and meaningful Swagger documentation.
> Applies to: `**/*.dto.ts`

# NestJS DTO Validation Standards

How to create robust, well-documented DTOs with clear naming conventions, proper validation, and meaningful documentation.

## Purpose

DTOs (Data Transfer Objects) define the shape of data exchanged between client and server. Proper DTOs ensure:
- Type safety at runtime through validation
- Automatic API documentation via Swagger
- Clean data transformation between layers
- Clear separation between request and response data

## DTO Naming Conventions

**Critical**: DTOs must clearly indicate whether they are for requests or responses.

| Type | Naming Pattern | File Pattern |
|------|----------------|--------------|
| Create Request | `CreateUserRequestDto` | `create-user-request.dto.ts` |
| Update Request | `UpdateUserRequestDto` | `update-user-request.dto.ts` |
| Query Parameters | `UserQueryDto` | `user-query.dto.ts` |
| Response | `UserResponseDto` | `user-response.dto.ts` |
| Detail Response | `UserDetailResponseDto` | `user-response.dto.ts` |
| List Response | `UserListResponseDto` | `user-response.dto.ts` |

## DTO Directory Structure

```
feature/
├── dto/
│   ├── user-request.dto.ts         # Create/Update request DTOs
│   ├── user-response.dto.ts        # Response DTOs (can have multiple)
│   ├── user-query.dto.ts           # Query parameters
│   └── index.ts                    # Barrel export
│
│   # For complex modules with many DTOs:
│   ├── request/
│   │   ├── create-user-request.dto.ts
│   │   ├── update-user-request.dto.ts
│   │   └── index.ts
│   ├── response/
│   │   ├── user-response.dto.ts
│   │   ├── user-detail-response.dto.ts
│   │   └── index.ts
│   └── index.ts
```

## Patterns

### Request DTO with Validation

#### Good

```typescript
// create-user-request.dto.ts
import { IsNotEmpty, IsString, IsEmail, MinLength, IsOptional, IsEnum } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateUserRequestDto {
  @ApiProperty({
    description: 'User email address for authentication and notifications',
    example: 'john.doe@company.com',
    format: 'email',
  })
  @IsNotEmpty()
  @IsEmail()
  readonly email: string;

  @ApiProperty({
    description: 'Secure password meeting complexity requirements',
    minLength: 8,
  })
  @IsNotEmpty()
  @IsString()
  @MinLength(8)
  readonly password: string;

  @ApiProperty({
    description: 'User display name shown in the interface',
    example: 'John Doe',
  })
  @IsNotEmpty()
  @IsString()
  readonly name: string;

  @ApiPropertyOptional({
    description: 'User role determining access permissions',
    enum: UserRole,
    default: UserRole.USER,
  })
  @IsOptional()
  @IsEnum(UserRole)
  readonly role?: UserRole = UserRole.USER;
}
```

#### Bad

```typescript
// No clear naming - is this request or response?
export class CreateUserDto {
  email: string;  // Missing validation
  password: string;  // Missing validation
  name: string;  // Missing validation
}

// Documentation that adds no value
export class CreateUserRequestDto {
  @ApiProperty({ description: 'Email' })  // Just restates the field name
  @IsEmail()
  email: string;

  @ApiProperty({ description: 'Password' })  // No useful information
  password: string;
}
```

### Response DTO with Transformation

Response DTOs control what data is exposed to clients.

#### Good

```typescript
// user-response.dto.ts
import { Expose, Exclude, Type } from 'class-transformer';
import { ApiProperty, ApiPropertyOptional, ApiHideProperty } from '@nestjs/swagger';

// Base response - essential fields only
@Exclude()  // Exclude all by default, explicitly expose fields
export class UserResponseDto {
  @Expose()
  @ApiProperty({ format: 'uuid' })
  readonly id: string;

  @Expose()
  @ApiProperty({ example: 'john.doe@company.com' })
  readonly email: string;

  @Expose()
  @ApiProperty({ example: 'John Doe' })
  readonly name: string;

  @Expose()
  @ApiProperty()
  @Type(() => Date)
  readonly createdAt: Date;

  // These fields are automatically excluded due to @Exclude() on class
  @ApiHideProperty()
  readonly password: string;

  @ApiHideProperty()
  readonly tenantId: string;
}

// Extended response with additional relations
export class UserDetailResponseDto extends UserResponseDto {
  @Expose()
  @ApiPropertyOptional()
  readonly dateOfBirth?: Date;

  @Expose()
  @ApiPropertyOptional({ type: [DepartmentResponseDto] })
  @Type(() => DepartmentResponseDto)
  readonly departments?: DepartmentResponseDto[];

  @Expose()
  @ApiPropertyOptional({ type: AddressResponseDto })
  @Type(() => AddressResponseDto)
  readonly address?: AddressResponseDto;
}

// Minimal response for lists and references
export class UserMinimalResponseDto {
  @Expose()
  @ApiProperty({ format: 'uuid' })
  readonly id: string;

  @Expose()
  @ApiProperty()
  readonly name: string;
}
```

#### Bad

```typescript
// Exposing sensitive data
export class UserResponseDto {
  id: string;
  email: string;
  password: string;  // Never expose passwords!
  hash: string;  // Never expose hashes!
  tenantId: string;  // Internal system field
}

// No transformation control
export class UserResponse {
  // Returns everything from database without filtering
}
```

### When to Use @ApiProperty vs @ApiPropertyOptional

| Decorator | Use When | Validation |
|-----------|----------|------------|
| `@ApiProperty()` | Field is required in the request/response | Pair with `@IsNotEmpty()` |
| `@ApiPropertyOptional()` | Field is optional | Pair with `@IsOptional()` |

#### Good

```typescript
export class CreateUserRequestDto {
  // Required field - must be provided
  @ApiProperty({ description: 'User email for authentication' })
  @IsNotEmpty()
  @IsEmail()
  readonly email: string;

  // Optional field - can be omitted
  @ApiPropertyOptional({
    description: 'Department assignment on creation',
    format: 'uuid',
  })
  @IsOptional()
  @IsUUID(4)
  readonly departmentId?: string;

  // Optional with default value
  @ApiPropertyOptional({
    description: 'User active status',
    default: true,
  })
  @IsOptional()
  @IsBoolean()
  readonly isActive?: boolean = true;
}
```

### Extending DTOs Instead of Duplicating

Use inheritance and utility types to avoid code duplication.

#### Good

```typescript
// Base create DTO
export class CreateAddressRequestDto {
  @ApiProperty()
  @IsString()
  readonly address: string;

  @ApiProperty()
  @IsString()
  readonly city: string;

  @ApiProperty()
  @IsString()
  readonly state: string;

  @ApiProperty()
  @IsString()
  readonly postalCode: string;
}

// Update DTO - all fields optional, inherits validation
export class UpdateAddressRequestDto extends PartialType(CreateAddressRequestDto) {
  @ApiPropertyOptional({ description: 'Address ID for updates' })
  @IsOptional()
  @IsString()
  readonly id?: string;
}

// Omit specific fields
export class UpdateProfileRequestDto extends PartialType(
  OmitType(CreateUserRequestDto, ['email', 'password'] as const),
) {}

// Pick specific fields
export class ChangeEmailRequestDto extends PickType(
  CreateUserRequestDto,
  ['email'] as const,
) {}
```

```typescript
// Response DTO inheritance
export class UserResponseDto {
  @Expose()
  @ApiProperty({ format: 'uuid' })
  readonly id: string;

  @Expose()
  @ApiProperty()
  readonly name: string;
}

// Extend for more details
export class UserDetailResponseDto extends UserResponseDto {
  @Expose()
  @ApiPropertyOptional({ type: [RoleResponseDto] })
  @Type(() => RoleResponseDto)
  readonly roles?: RoleResponseDto[];
}

// Extend for list views
export class UserListResponseDto extends UserResponseDto {
  @Expose()
  @ApiProperty()
  readonly departmentName: string;
}
```

#### Bad

```typescript
// Duplicating validation logic across DTOs
export class CreateUserRequestDto {
  @IsEmail() email: string;
  @IsString() @MinLength(8) password: string;
  @IsString() name: string;
}

export class UpdateUserRequestDto {
  // Duplicating everything with @IsOptional added
  @IsOptional() @IsEmail() email?: string;
  @IsOptional() @IsString() @MinLength(8) password?: string;
  @IsOptional() @IsString() name?: string;
}
```

### Nested Objects with Validation

#### Good

```typescript
export class AddressRequestDto {
  @ApiProperty()
  @IsNotEmpty()
  @IsString()
  readonly street: string;

  @ApiProperty()
  @IsNotEmpty()
  @IsString()
  readonly city: string;
}

export class CreateCompanyRequestDto {
  @ApiProperty()
  @IsNotEmpty()
  @IsString()
  readonly name: string;

  // Single nested object
  @ApiProperty({ type: AddressRequestDto })
  @ValidateNested()  // No { each: true } needed for single objects
  @Type(() => AddressRequestDto)
  readonly address: AddressRequestDto;

  // Array of nested objects
  @ApiProperty({ type: [AddressRequestDto] })
  @IsArray()
  @ValidateNested({ each: true })  // Note: { each: true } for arrays
  @Type(() => AddressRequestDto)
  readonly branches: AddressRequestDto[];
}
```

### Enum Documentation

#### Good

```typescript
export enum UserRole {
  ADMIN = 'admin',
  USER = 'user',
  GUEST = 'guest',
}

export class CreateUserRequestDto {
  @ApiProperty({
    enum: UserRole,
    enumName: 'UserRole',  // Generates named enum in Swagger
    description: 'User role determining access level',
    example: UserRole.USER,
  })
  @IsEnum(UserRole)
  readonly role: UserRole;
}
```

### Custom Validation with Meaningful Messages

#### Good

```typescript
export class CreateUserRequestDto {
  @ApiProperty({ description: 'User email for authentication' })
  @IsEmail({}, { message: 'Please provide a valid email address' })
  readonly email: string;

  @ApiProperty({ description: 'Password meeting security requirements' })
  @IsString({ message: 'Password must be a string' })
  @MinLength(8, { message: 'Password must be at least 8 characters' })
  @Matches(/^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)/, {
    message: 'Password must contain uppercase, lowercase, and number',
  })
  readonly password: string;
}
```

## Best Practices

- **Clear Naming**: Always suffix with `RequestDto` or `ResponseDto`
- **File Organization**: Group related DTOs, separate request/response for complex modules
- **Validation First**: Every request DTO field should have validation decorators
- **Meaningful Documentation**: `@ApiProperty` descriptions should add value, not restate field names
- **Use `readonly`**: All DTO properties should be immutable
- **Extend, Don't Duplicate**: Use `PartialType`, `OmitType`, `PickType` and class inheritance
- **Response Security**: Use `@Exclude()` on class and `@Expose()` on safe fields
- **Hide Internal Fields**: Use `@ApiHideProperty()` for fields not in Swagger
- **Nested Validation**: Always pair `@ValidateNested()` with `@Type()`
- **Array Validation**: Use `{ each: true }` option for array validation
- **Default Values**: Document defaults in `@ApiPropertyOptional`

## Common Mistakes

- Unclear naming (using `UserDto` instead of `UserRequestDto` or `UserResponseDto`)
- Documentation that just restates the field name
- Missing `@Type()` decorator on nested objects
- Missing `{ each: true }` for array validation
- Missing `@IsOptional()` on optional fields
- Exposing sensitive data in response DTOs
- Duplicating validation logic instead of using `PartialType`
- Using `any` type in DTOs
- Not using `readonly` (allows mutation of DTO properties)

---

### Consistent error handling patterns for NestJS - avoid magic strings, use structured approaches.

# NestJS Error Handling Standards

How to implement consistent, maintainable error handling across your NestJS application.

## Purpose

Proper error handling ensures:
- Consistent error response format across the entire API
- Clear, actionable error messages for clients
- No magic strings scattered throughout the codebase
- Easy debugging and error tracking
- Security by not exposing internal details

## Core Principle: Consistency Over Specific Approach

The most important aspect of error handling is **consistency**. Choose an approach and apply it uniformly across the entire codebase. Whether you use error enums, error codes, or error constants - the key is that all developers follow the same pattern.

**Never use magic strings** - errors should always be defined in a centralized location.

## Error Handling Approaches

Choose one approach and stick with it across the entire codebase.

### Approach 1: Error Enums (Recommended for Type Safety)

```typescript
// errors/user.errors.ts
export enum UserError {
  NOT_FOUND = 'USER_NOT_FOUND',
  EMAIL_EXISTS = 'USER_EMAIL_EXISTS',
  INVALID_CREDENTIALS = 'USER_INVALID_CREDENTIALS',
  ACCOUNT_DISABLED = 'USER_ACCOUNT_DISABLED',
  CANNOT_DELETE_ACTIVE = 'USER_CANNOT_DELETE_ACTIVE',
}

// Optional: Message map for user-friendly messages
export const UserErrorMessage: Record<UserError, string> = {
  [UserError.NOT_FOUND]: 'User not found',
  [UserError.EMAIL_EXISTS]: 'A user with this email already exists',
  [UserError.INVALID_CREDENTIALS]: 'Invalid email or password',
  [UserError.ACCOUNT_DISABLED]: 'This account has been disabled',
  [UserError.CANNOT_DELETE_ACTIVE]: 'Cannot delete user with active orders',
};
```

### Approach 2: Error Constants

```typescript
// errors/user.errors.ts
export const USER_ERRORS = {
  NOT_FOUND: {
    code: 'USER_NOT_FOUND',
    message: 'User not found',
  },
  EMAIL_EXISTS: {
    code: 'USER_EMAIL_EXISTS',
    message: 'A user with this email already exists',
  },
  INVALID_CREDENTIALS: {
    code: 'USER_INVALID_CREDENTIALS',
    message: 'Invalid email or password',
  },
} as const;
```

### Approach 3: Error Classes

```typescript
// errors/user.errors.ts
export class UserNotFoundError extends NotFoundException {
  constructor(userId?: string) {
    super({
      code: 'USER_NOT_FOUND',
      message: userId ? `User ${userId} not found` : 'User not found',
    });
  }
}

export class EmailExistsError extends ConflictException {
  constructor(email: string) {
    super({
      code: 'USER_EMAIL_EXISTS',
      message: 'A user with this email already exists',
      field: 'email',
    });
  }
}
```

## Using Errors in Services

Regardless of approach, errors should be thrown with structured data.

#### Good - Consistent, No Magic Strings

```typescript
import { Injectable, NotFoundException, ConflictException } from '@nestjs/common';
import { UserError, UserErrorMessage } from './errors/user.errors';

@Injectable()
export class UserService {
  async findOne(id: string): Promise<User> {
    const user = await this.userRepository.findOne(id);

    if (!user) {
      throw new NotFoundException({
        code: UserError.NOT_FOUND,
        message: UserErrorMessage[UserError.NOT_FOUND],
      });
    }

    return user;
  }

  async create(dto: CreateUserRequestDto): Promise<User> {
    const existing = await this.userRepository.findByEmail(dto.email);

    if (existing) {
      throw new ConflictException({
        code: UserError.EMAIL_EXISTS,
        message: UserErrorMessage[UserError.EMAIL_EXISTS],
        field: 'email',
      });
    }

    return this.userRepository.create(dto);
  }

  async delete(id: string): Promise<void> {
    const user = await this.findOne(id);

    const hasActiveOrders = await this.orderRepository.hasActive(id);
    if (hasActiveOrders) {
      throw new BadRequestException({
        code: UserError.CANNOT_DELETE_ACTIVE,
        message: UserErrorMessage[UserError.CANNOT_DELETE_ACTIVE],
      });
    }

    await this.userRepository.softDelete(id);
  }
}
```

#### Bad - Magic Strings

```typescript
// Magic strings scattered throughout the code
async findOne(id: string): Promise<User> {
  const user = await this.userRepository.findOne(id);

  if (!user) {
    throw new NotFoundException('User not found');  // Magic string!
  }

  return user;
}

async create(dto: CreateUserRequestDto): Promise<User> {
  const existing = await this.userRepository.findByEmail(dto.email);

  if (existing) {
    throw new ConflictException('Email already exists');  // Magic string!
  }
  // ...
}

// Inconsistent messages for same error
async delete(id: string): Promise<void> {
  const user = await this.userRepository.findOne(id);
  if (!user) {
    throw new NotFoundException('Cannot find user');  // Different message!
  }
  // ...
}
```

## Error File Organization

```
feature/
├── errors/
│   ├── feature.errors.ts      # Error definitions for this feature
│   └── index.ts
└── feature.service.ts

# Or centralized:
src/
├── common/
│   └── errors/
│       ├── user.errors.ts
│       ├── order.errors.ts
│       ├── auth.errors.ts
│       └── index.ts
```

## Exception Filters

Create global exception filters to ensure consistent response format.

```typescript
// common/filters/http-exception.filter.ts
import {
  ExceptionFilter,
  Catch,
  ArgumentsHost,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';

interface ErrorResponse {
  statusCode: number;
  timestamp: string;
  path: string;
  code?: string;
  message: string;
  field?: string;
  errors?: { field: string; message: string }[];
}

@Catch(HttpException)
export class HttpExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(HttpExceptionFilter.name);

  catch(exception: HttpException, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();
    const status = exception.getStatus();
    const exceptionResponse = exception.getResponse();

    const errorResponse: ErrorResponse = {
      statusCode: status,
      timestamp: new Date().toISOString(),
      path: request.url,
      message: this.extractMessage(exceptionResponse),
    };

    // Add code if present
    if (typeof exceptionResponse === 'object' && 'code' in exceptionResponse) {
      errorResponse.code = (exceptionResponse as any).code;
    }

    // Add field if present
    if (typeof exceptionResponse === 'object' && 'field' in exceptionResponse) {
      errorResponse.field = (exceptionResponse as any).field;
    }

    // Handle validation errors (array of messages)
    if (typeof exceptionResponse === 'object' && 'message' in exceptionResponse) {
      const messages = (exceptionResponse as any).message;
      if (Array.isArray(messages)) {
        errorResponse.errors = messages.map((msg) => ({
          field: this.extractFieldFromMessage(msg),
          message: msg,
        }));
      }
    }

    // Log errors appropriately
    if (status >= 500) {
      this.logger.error(`${request.method} ${request.url}`, exception.stack);
    } else {
      this.logger.warn(`${request.method} ${request.url} - ${errorResponse.message}`);
    }

    response.status(status).json(errorResponse);
  }

  private extractMessage(response: string | object): string {
    if (typeof response === 'string') return response;
    if ('message' in response) {
      const msg = (response as any).message;
      return Array.isArray(msg) ? msg[0] : msg;
    }
    return 'An error occurred';
  }

  private extractFieldFromMessage(message: string): string {
    const match = message.match(/^(\w+)/);
    return match ? match[1] : 'unknown';
  }
}
```

## Global Exception Filter for Unexpected Errors

```typescript
// common/filters/all-exceptions.filter.ts
@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let message = 'Internal server error';
    let code = 'INTERNAL_ERROR';

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      const exceptionResponse = exception.getResponse();
      message = typeof exceptionResponse === 'string'
        ? exceptionResponse
        : (exceptionResponse as any).message || message;
      code = (exceptionResponse as any).code || code;
    }

    // Log with full stack trace for server errors
    if (status >= 500) {
      this.logger.error(
        `${request.method} ${request.url}`,
        exception instanceof Error ? exception.stack : String(exception),
      );
    }

    // Don't expose internal details in production
    const isProduction = process.env.NODE_ENV === 'production';

    response.status(status).json({
      statusCode: status,
      timestamp: new Date().toISOString(),
      path: request.url,
      code,
      message: isProduction && status >= 500 ? 'Internal server error' : message,
    });
  }
}
```

## Registering Exception Filters

```typescript
// main.ts
async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  app.useGlobalFilters(
    new AllExceptionsFilter(),
    new HttpExceptionFilter(),
  );

  await app.listen(3000);
}
```

## Validation Before Operations

Always validate entity existence before performing operations.

```typescript
@Injectable()
export class OrderService {
  async update(id: string, dto: UpdateOrderRequestDto): Promise<Order> {
    // Validate order exists
    const order = await this.orderRepository.findOne(id);
    if (!order) {
      throw new NotFoundException({
        code: OrderError.NOT_FOUND,
        message: OrderErrorMessage[OrderError.NOT_FOUND],
      });
    }

    // Validate business rules
    if (order.status === OrderStatus.COMPLETED) {
      throw new BadRequestException({
        code: OrderError.CANNOT_MODIFY_COMPLETED,
        message: OrderErrorMessage[OrderError.CANNOT_MODIFY_COMPLETED],
      });
    }

    return this.orderRepository.update(id, dto);
  }
}
```

## Error Response Format

Maintain consistent error response structure across the API:

```typescript
// Standard error response
{
  "statusCode": 404,
  "timestamp": "2024-01-15T10:30:00.000Z",
  "path": "/api/users/123",
  "code": "USER_NOT_FOUND",
  "message": "User not found"
}

// Error with field (for validation)
{
  "statusCode": 409,
  "timestamp": "2024-01-15T10:30:00.000Z",
  "path": "/api/users",
  "code": "USER_EMAIL_EXISTS",
  "message": "A user with this email already exists",
  "field": "email"
}

// Multiple validation errors
{
  "statusCode": 400,
  "timestamp": "2024-01-15T10:30:00.000Z",
  "path": "/api/users",
  "message": "Validation failed",
  "errors": [
    { "field": "email", "message": "email must be a valid email" },
    { "field": "password", "message": "password must be at least 8 characters" }
  ]
}
```

## Best Practices

- **Choose one approach and be consistent** - enums, constants, or error classes
- **Never use magic strings** - all error codes/messages in centralized files
- **Include error codes** - machine-readable codes for client handling
- **Use appropriate HTTP status codes** - 404 for not found, 409 for conflict, etc.
- **Validate before operations** - check entity existence before update/delete
- **Log appropriately** - error level for 5xx, warn level for 4xx
- **Hide internal details in production** - don't expose stack traces
- **Structure error responses consistently** - same format for all endpoints
- **Group errors by feature** - `user.errors.ts`, `order.errors.ts`

## Common Mistakes

- Magic strings for error messages scattered throughout the code
- Inconsistent error response formats
- Different messages for the same error in different places
- Exposing stack traces in production
- Not validating entity existence before operations
- Missing error codes (only returning messages)
- Catching errors without proper handling or re-throwing
- Using generic Error instead of specific NestJS exceptions

---

### Module organization patterns for NestJS including imports, exports, providers, and feature structure.
> Applies to: `**/*.module.ts`

# NestJS Module Structure Standards

How to organize NestJS modules with proper imports, exports, providers, and feature-based structure.

## Purpose

Modules organize related functionality and define boundaries. They:
- Encapsulate related components (controllers, services, repositories)
- Define clear dependency relationships
- Enable lazy loading and code splitting
- Support testing through isolation

## Module Organization

### Feature Module Structure

```
src/
├── users/
│   ├── users.module.ts           # Feature module
│   ├── users.controller.ts       # HTTP endpoints
│   ├── users.service.ts          # Business logic
│   ├── dto/
│   │   ├── create-user.dto.ts
│   │   ├── update-user.dto.ts
│   │   ├── query-users.dto.ts
│   │   └── index.ts
│   ├── entities/
│   │   ├── user.entity.ts
│   │   └── index.ts
│   ├── repositories/
│   │   ├── user.repository.ts
│   │   ├── prisma-user.repository.ts
│   │   └── index.ts
│   ├── errors/
│   │   ├── user-validation.error.ts
│   │   └── index.ts
│   └── index.ts                  # Public API barrel
├── common/
│   ├── common.module.ts          # Shared utilities
│   ├── filters/
│   ├── guards/
│   ├── interceptors/
│   ├── decorators/
│   └── pipes/
├── core/
│   └── core.module.ts            # Global providers
└── app.module.ts                 # Root module
```

## Patterns

### Feature Module

#### Good

```typescript
// users.module.ts
import { Module } from '@nestjs/common';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';
import { UserRepository } from './repositories/user.repository';
import { PrismaUserRepository } from './repositories/prisma-user.repository';
import { PrismaModule } from '../prisma/prisma.module';

@Module({
  imports: [PrismaModule],
  controllers: [UsersController],
  providers: [
    UsersService,
    {
      provide: UserRepository,
      useClass: PrismaUserRepository,
    },
  ],
  exports: [UsersService], // Export for use in other modules
})
export class UsersModule {}
```

#### Bad

```typescript
// Everything in one module
@Module({
  imports: [],
  controllers: [
    UsersController,
    OrdersController,
    ProductsController,
    AuthController,
  ],
  providers: [
    UsersService,
    OrdersService,
    ProductsService,
    AuthService,
    // All repositories...
  ],
})
export class AppModule {} // Monolithic module

// Missing exports - other modules can't use the service
@Module({
  providers: [UsersService],
  // exports: [] - Missing!
})
export class UsersModule {}
```

### Root App Module

#### Good

```typescript
// app.module.ts
import { Module, MiddlewareConsumer, NestModule } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { CoreModule } from './core/core.module';
import { UsersModule } from './users/users.module';
import { OrdersModule } from './orders/orders.module';
import { AuthModule } from './auth/auth.module';
import { PrismaModule } from './prisma/prisma.module';
import { LoggerMiddleware } from './common/middleware/logger.middleware';
import configuration from './config/configuration';

@Module({
  imports: [
    // Configuration first
    ConfigModule.forRoot({
      isGlobal: true,
      load: [configuration],
    }),
    // Core/infrastructure modules
    CoreModule,
    PrismaModule,
    // Feature modules
    AuthModule,
    UsersModule,
    OrdersModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer.apply(LoggerMiddleware).forRoutes('*');
  }
}
```

### Core Module (Global Providers)

#### Good

```typescript
// core.module.ts
import { Global, Module } from '@nestjs/common';
import { APP_FILTER, APP_GUARD, APP_INTERCEPTOR } from '@nestjs/core';
import { AllExceptionsFilter } from '../common/filters/all-exceptions.filter';
import { HttpExceptionFilter } from '../common/filters/http-exception.filter';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { LoggingInterceptor } from '../common/interceptors/logging.interceptor';
import { TransformInterceptor } from '../common/interceptors/transform.interceptor';

@Global()
@Module({
  providers: [
    // Global exception filters
    {
      provide: APP_FILTER,
      useClass: AllExceptionsFilter,
    },
    {
      provide: APP_FILTER,
      useClass: HttpExceptionFilter,
    },
    // Global interceptors
    {
      provide: APP_INTERCEPTOR,
      useClass: LoggingInterceptor,
    },
    {
      provide: APP_INTERCEPTOR,
      useClass: TransformInterceptor,
    },
  ],
})
export class CoreModule {}
```

#### Bad

```typescript
// Global decorator without careful consideration
@Global()
@Module({
  providers: [
    UsersService, // Should not be global
    OrdersService, // Should not be global
  ],
  exports: [UsersService, OrdersService],
})
export class SharedModule {} // Overusing @Global
```

### Shared/Common Module

#### Good

```typescript
// common.module.ts
import { Module } from '@nestjs/common';
import { EncryptionService } from './services/encryption.service';
import { PaginationService } from './services/pagination.service';
import { FileUploadService } from './services/file-upload.service';

@Module({
  providers: [
    EncryptionService,
    PaginationService,
    FileUploadService,
  ],
  exports: [
    EncryptionService,
    PaginationService,
    FileUploadService,
  ],
})
export class CommonModule {}

// Usage in feature module
@Module({
  imports: [CommonModule], // Import when needed
  // ...
})
export class UsersModule {}
```

### Database Module

#### Good

```typescript
// prisma.module.ts
import { Global, Module } from '@nestjs/common';
import { PrismaService } from './prisma.service';

@Global() // Available everywhere without importing
@Module({
  providers: [PrismaService],
  exports: [PrismaService],
})
export class PrismaModule {}
```

```typescript
// prisma.service.ts
import { Injectable, OnModuleInit, OnModuleDestroy, Logger } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(PrismaService.name);

  async onModuleInit() {
    await this.$connect();
    this.logger.log('Database connected');
  }

  async onModuleDestroy() {
    await this.$disconnect();
    this.logger.log('Database disconnected');
  }
}
```

### Auth Module with Guards

#### Good

```typescript
// auth.module.ts
import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { JwtStrategy } from './strategies/jwt.strategy';
import { LocalStrategy } from './strategies/local.strategy';
import { JwtAuthGuard } from './guards/jwt-auth.guard';
import { RolesGuard } from './guards/roles.guard';
import { UsersModule } from '../users/users.module';

@Module({
  imports: [
    UsersModule, // Import to use UsersService
    PassportModule.register({ defaultStrategy: 'jwt' }),
    JwtModule.registerAsync({
      imports: [ConfigModule],
      useFactory: async (configService: ConfigService) => ({
        secret: configService.get<string>('JWT_SECRET'),
        signOptions: {
          expiresIn: configService.get<string>('JWT_EXPIRATION', '1h'),
        },
      }),
      inject: [ConfigService],
    }),
  ],
  controllers: [AuthController],
  providers: [
    AuthService,
    JwtStrategy,
    LocalStrategy,
    JwtAuthGuard,
    RolesGuard,
  ],
  exports: [
    AuthService,
    JwtAuthGuard,
    RolesGuard,
  ],
})
export class AuthModule {}
```

### Dynamic Module

#### Good

```typescript
// cache.module.ts
import { DynamicModule, Module } from '@nestjs/common';
import { CacheService } from './cache.service';

export interface CacheModuleOptions {
  ttl: number;
  max: number;
  isGlobal?: boolean;
}

@Module({})
export class CacheModule {
  static register(options: CacheModuleOptions): DynamicModule {
    return {
      module: CacheModule,
      global: options.isGlobal ?? false,
      providers: [
        {
          provide: 'CACHE_OPTIONS',
          useValue: options,
        },
        CacheService,
      ],
      exports: [CacheService],
    };
  }

  static registerAsync(options: {
    useFactory: (...args: any[]) => Promise<CacheModuleOptions> | CacheModuleOptions;
    inject?: any[];
    isGlobal?: boolean;
  }): DynamicModule {
    return {
      module: CacheModule,
      global: options.isGlobal ?? false,
      providers: [
        {
          provide: 'CACHE_OPTIONS',
          useFactory: options.useFactory,
          inject: options.inject || [],
        },
        CacheService,
      ],
      exports: [CacheService],
    };
  }
}

// Usage
@Module({
  imports: [
    CacheModule.register({ ttl: 60, max: 100, isGlobal: true }),
    // or async
    CacheModule.registerAsync({
      useFactory: (config: ConfigService) => ({
        ttl: config.get('CACHE_TTL'),
        max: config.get('CACHE_MAX'),
      }),
      inject: [ConfigService],
    }),
  ],
})
export class AppModule {}
```

### Cross-Module Dependencies

#### Good

```typescript
// orders.module.ts
import { Module, forwardRef } from '@nestjs/common';
import { OrdersController } from './orders.controller';
import { OrdersService } from './orders.service';
import { UsersModule } from '../users/users.module';
import { ProductsModule } from '../products/products.module';
import { PaymentsModule } from '../payments/payments.module';

@Module({
  imports: [
    UsersModule, // Uses UsersService
    ProductsModule, // Uses ProductsService
    forwardRef(() => PaymentsModule), // Circular dependency resolution
  ],
  controllers: [OrdersController],
  providers: [OrdersService],
  exports: [OrdersService],
})
export class OrdersModule {}
```

### Barrel Exports (index.ts)

#### Good

```typescript
// users/index.ts - Public API of the module
export * from './users.module';
export * from './users.service';
export * from './dto';
export * from './entities';
// Don't export internal implementation details

// users/dto/index.ts
export * from './create-user.dto';
export * from './update-user.dto';
export * from './query-users.dto';
export * from './user-response.dto';

// users/entities/index.ts
export * from './user.entity';

// Usage in other modules
import { UsersModule, UsersService, CreateUserDto } from '../users';
```

### Lazy Loading (for large applications)

#### Good

```typescript
// app.module.ts with lazy loading
import { Module } from '@nestjs/common';
import { RouterModule } from '@nestjs/core';

@Module({
  imports: [
    // Eagerly loaded modules
    AuthModule,
    UsersModule,

    // Lazy loaded modules (loaded on demand)
    RouterModule.register([
      {
        path: 'admin',
        module: AdminModule,
        children: [
          { path: 'reports', module: ReportsModule },
          { path: 'settings', module: SettingsModule },
        ],
      },
    ]),
  ],
})
export class AppModule {}
```

## Best Practices

- One module per feature/domain (users, orders, products)
- Use barrel exports (index.ts) for clean imports
- Export only what other modules need
- Use `@Global()` sparingly (only for truly global services like database)
- Register filters, guards, interceptors in CoreModule
- Use `forwardRef()` to resolve circular dependencies
- Keep module files clean - just imports/exports/providers
- Use dynamic modules for configurable functionality
- Import modules in the order: config, infrastructure, features
- Document module dependencies in comments if complex

## Common Mistakes

- Creating one large monolithic module
- Overusing `@Global()` decorator
- Missing exports for services used by other modules
- Circular dependencies without `forwardRef()`
- Importing providers directly instead of modules
- Not using barrel exports (messy import paths)
- Mixing infrastructure and feature code in one module
- Not documenting complex module dependencies

---

### Repository pattern for NestJS with parameterized methods, soft deletes, and query organization.
> Applies to: `**/*.repository.ts`

# NestJS Repository Patterns

How to implement the repository pattern with parameterized methods, query organization, soft deletes, and proper abstraction.

## Purpose

Repositories abstract the data access layer from business logic. They:
- Encapsulate database queries and operations
- Provide a clean interface for services to interact with data
- Enable easy mocking for unit tests
- Support swapping data sources without changing service code

## Repository Structure

```
feature/
├── repositories/
│   ├── user.repository.ts          # Abstract repository (encouraged)
│   ├── user.repository.impl.ts     # Concrete implementation
│   └── index.ts                    # Barrel export
└── feature.module.ts
```

## Core Patterns (Apply Always)

### Parameterized Method Signatures

Use object parameters for flexible, readable method signatures.

#### Good

```typescript
// Abstract interface
export interface FindAllParams {
  skip?: number;
  take?: number;
  where?: Record<string, unknown>;
  orderBy?: Record<string, 'asc' | 'desc'>;
}

export interface FindOneParams {
  where: Record<string, unknown>;
  include?: Record<string, boolean>;
}

export abstract class UserRepository {
  abstract findAll(params: FindAllParams): Promise<{ data: User[]; count: number }>;
  abstract findOne(params: FindOneParams): Promise<User | null>;
  abstract findOneOrFail(params: FindOneParams): Promise<User>;
  abstract create(data: CreateUserInput): Promise<User>;
  abstract update(params: { id: string; data: UpdateUserInput }): Promise<User>;
  abstract delete(id: string): Promise<void>;
  abstract softDelete(id: string): Promise<User>;
}
```

#### Bad

```typescript
// Too many positional parameters
async findAll(skip: number, take: number, where: any, orderBy: any): Promise<User[]>

// Not returning count with data
async findAll(): Promise<User[]>  // Breaks pagination
```

### Always Return `{ data, count }` for List Operations

This enables proper pagination in the service/controller layer.

#### Good

```typescript
async findAll(params: FindAllParams): Promise<{ data: User[]; count: number }> {
  const [data, count] = await Promise.all([
    this.db.users.findMany(params),
    this.db.users.count({ where: params.where }),
  ]);

  return { data, count };
}
```

### Soft Delete Pattern (Encouraged)

Always prefer soft deletes to preserve data integrity and enable recovery.

#### Good

```typescript
export class UserRepository {
  private readonly baseWhere = { deletedAt: null };

  async findAll(params: FindAllParams): Promise<{ data: User[]; count: number }> {
    const where = { ...params.where, ...this.baseWhere };
    // Apply soft delete filter to all queries
  }

  async findOne(params: FindOneParams): Promise<User | null> {
    return this.db.users.findFirst({
      ...params,
      where: { ...params.where, ...this.baseWhere },
    });
  }

  async softDelete(id: string): Promise<User> {
    return this.db.users.update({
      where: { id },
      data: { deletedAt: new Date() },
    });
  }

  async restore(id: string): Promise<User> {
    return this.db.users.update({
      where: { id },
      data: { deletedAt: null },
    });
  }

  // Only for admin/cleanup purposes
  async hardDelete(id: string): Promise<void> {
    await this.db.users.delete({ where: { id } });
  }
}
```

#### Bad

```typescript
// Forgetting soft delete filter in some queries
async findAll() {
  return this.db.users.findMany(); // Returns deleted users!
}

async findOne(id: string) {
  return this.db.users.findFirst({
    where: { id, deletedAt: null }, // Correct here
  });
}

async search(query: string) {
  return this.db.users.findMany({
    where: { name: { contains: query } }, // Missing deletedAt filter!
  });
}
```

### Separating Complex Queries

When queries become complex, extract them into documented helper methods or objects.

#### Good

```typescript
export class UserRepository {
  /**
   * Search users with full-text search across multiple fields.
   * Applies soft delete filter and supports pagination.
   */
  async search({
    query,
    filters,
    pagination,
    sort,
  }: UserSearchParams): Promise<{ data: User[]; count: number }> {
    const where = this.buildSearchWhere(query, filters);
    const orderBy = this.buildOrderBy(sort);

    const [data, count] = await Promise.all([
      this.db.users.findMany({ where, orderBy, ...pagination }),
      this.db.users.count({ where }),
    ]);

    return { data, count };
  }

  /**
   * Builds WHERE clause for user search.
   * Combines text search, filters, and soft delete.
   */
  private buildSearchWhere(
    query?: string,
    filters?: UserSearchFilters,
  ): Record<string, unknown> {
    return {
      deletedAt: null,
      ...(query && {
        OR: [
          { name: { contains: query, mode: 'insensitive' } },
          { email: { contains: query, mode: 'insensitive' } },
        ],
      }),
      ...(filters?.role && { role: filters.role }),
      ...(filters?.status && { status: filters.status }),
      ...(filters?.createdAfter && { createdAt: { gte: filters.createdAfter } }),
    };
  }

  /**
   * Builds ORDER BY clause with defaults.
   */
  private buildOrderBy(
    sort?: { field: string; order: 'asc' | 'desc' },
  ): Record<string, 'asc' | 'desc'> {
    return sort ? { [sort.field]: sort.order } : { createdAt: 'desc' };
  }
}
```

#### Bad

```typescript
// Inline complex query - hard to read, test, and maintain
async search(query: string, role?: string, status?: string, after?: Date) {
  return this.db.users.findMany({
    where: {
      deletedAt: null,
      ...(query && {
        OR: [
          { name: { contains: query, mode: 'insensitive' } },
          { email: { contains: query, mode: 'insensitive' } },
          { department: { name: { contains: query, mode: 'insensitive' } } },
        ],
      }),
      ...(role && { role }),
      ...(status && { status }),
      ...(after && { createdAt: { gte: after } }),
    },
    orderBy: { createdAt: 'desc' },
  });
}
```

### Abstract Repository Pattern (Encouraged)

Using abstract classes makes swapping implementations easier and improves testability.

#### Good

```typescript
// user.repository.ts - Abstract interface
@Injectable()
export abstract class UserRepository {
  abstract findAll(params: FindAllParams): Promise<{ data: User[]; count: number }>;
  abstract findOne(params: FindOneParams): Promise<User | null>;
  abstract findOneOrFail(params: FindOneParams): Promise<User>;
  abstract create(data: CreateUserInput): Promise<User>;
  abstract update(params: { id: string; data: UpdateUserInput }): Promise<User>;
  abstract softDelete(id: string): Promise<User>;
}

// user.repository.impl.ts - Concrete implementation
@Injectable()
export class UserRepositoryImpl implements UserRepository {
  constructor(private readonly db: DatabaseService) {}

  async findAll(params: FindAllParams): Promise<{ data: User[]; count: number }> {
    // Implementation
  }

  async findOneOrFail(params: FindOneParams): Promise<User> {
    const user = await this.findOne(params);
    if (!user) {
      throw new NotFoundException({
        code: UserError.NOT_FOUND,
        message: 'User not found',
      });
    }
    return user;
  }

  // ... other methods
}

// user.module.ts - Wire abstract to concrete
@Module({
  providers: [
    UserService,
    {
      provide: UserRepository,
      useClass: UserRepositoryImpl,
    },
  ],
  exports: [UserRepository],
})
export class UserModule {}
```

### Transaction Support

Design methods to accept transaction clients for multi-record operations.

#### Good

```typescript
export class UserRepository {
  async createWithProfile(
    data: CreateUserInput,
    profileData: CreateProfileInput,
    transaction?: TransactionClient,
  ): Promise<User> {
    const client = transaction ?? this.db;

    return client.users.create({
      data: {
        ...data,
        profile: { create: profileData },
      },
      include: { profile: true },
    });
  }
}
```

---

## Prisma-Specific Patterns

**The following patterns apply only if your codebase uses Prisma ORM.**

### Reusable Select Objects

Define select objects with type safety for consistent field selection.

```typescript
import { Prisma } from '@prisma/client';

// Define reusable select objects
export const userBasicSelect = {
  id: true,
  email: true,
  name: true,
  createdAt: true,
} satisfies Prisma.UserSelect;

export const userWithProfileSelect = {
  ...userBasicSelect,
  profile: {
    select: {
      bio: true,
      avatarUrl: true,
    },
  },
} satisfies Prisma.UserSelect;

export const userWithOrdersSelect = {
  ...userBasicSelect,
  orders: {
    select: {
      id: true,
      status: true,
      total: true,
    },
    orderBy: { createdAt: 'desc' as const },
    take: 10,
  },
} satisfies Prisma.UserSelect;

// Usage in repository
@Injectable()
export class PrismaUserRepository implements UserRepository {
  async findOneWithProfile(id: string) {
    return this.prisma.user.findUnique({
      where: { id, deletedAt: null },
      select: userWithProfileSelect,
    });
  }
}
```

### Prisma Transaction Pattern

```typescript
@Injectable()
export class PrismaUserRepository implements UserRepository {
  constructor(private readonly prisma: PrismaService) {}

  async transferBalance({
    fromUserId,
    toUserId,
    amount,
  }: TransferParams): Promise<void> {
    await this.prisma.$transaction(async (tx) => {
      const fromUser = await tx.user.findUniqueOrThrow({
        where: { id: fromUserId },
      });

      if (fromUser.balance < amount) {
        throw new BadRequestException({
          code: UserError.INSUFFICIENT_BALANCE,
          message: 'Insufficient balance',
        });
      }

      await tx.user.update({
        where: { id: fromUserId },
        data: { balance: { decrement: amount } },
      });

      await tx.user.update({
        where: { id: toUserId },
        data: { balance: { increment: amount } },
      });
    });
  }
}
```

### Prisma Soft Delete Filter

```typescript
@Injectable()
export class PrismaUserRepository implements UserRepository {
  private readonly baseWhere: Prisma.UserWhereInput = {
    deletedAt: null,
  };

  async findAll(params: FindAllParams): Promise<{ data: User[]; count: number }> {
    const where: Prisma.UserWhereInput = {
      ...params.where,
      ...this.baseWhere,
    };

    const [data, count] = await Promise.all([
      this.prisma.user.findMany({
        skip: params.skip,
        take: params.take,
        where,
        orderBy: params.orderBy ?? { createdAt: 'desc' },
      }),
      this.prisma.user.count({ where }),
    ]);

    return { data, count };
  }
}
```

---

## Best Practices

- **Always return `{ data, count }`** for list operations to support pagination
- **Encourage soft delete** - use `deletedAt: null` filter consistently
- **Use abstract repository pattern** for better testability (encouraged, not required)
- **Parameterize methods** with object parameters for flexibility
- **Extract complex queries** into documented helper methods
- **Support transactions** by accepting optional transaction clients
- **Provide `findOneOrFail`** methods that throw `NotFoundException`
- **Keep repositories focused** on data access - no business logic
- **Document complex queries** with JSDoc comments explaining the logic

## Common Mistakes

- Forgetting soft delete filter in some queries (data leak)
- Not returning count with list data (breaks pagination)
- Inline complex queries without documentation
- Coupling services directly to ORM instead of abstract repository
- Not supporting transaction clients in repository methods
- Putting business logic in repositories instead of services
- Inconsistent error handling (sometimes throwing, sometimes returning null)
- Duplicating query logic instead of extracting helpers

---

### Service layer patterns for NestJS including method organization, validation, and error handling.
> Applies to: `**/*.service.ts`

# NestJS Service Patterns

How to implement robust service layer patterns with proper method organization, dependency injection, validation, and error handling.

## Purpose

Services contain the business logic of your application. They:
- Encapsulate business rules and domain logic
- Coordinate between repositories and external services
- Handle transactions and data consistency
- Validate business rules before operations

## Service File Organization

The key principle: **Keep services focused and atomic**.

```
feature/
├── feature.service.ts              # Main service (orchestration + simple methods)
├── create-feature.service.ts       # Complex operation as dedicated service
├── process-feature.service.ts      # Another complex operation
├── services/
│   └── index.ts                    # Barrel export for all services
└── feature.module.ts
```

**When to create a dedicated service file:**
- The operation is complex (>50 lines of logic)
- The operation has many steps that need orchestration
- The operation is reused across multiple entry points
- The operation has its own error handling requirements

**When to keep in the main service:**
- Simple CRUD operations
- Methods under 20 lines
- Single-purpose utility methods

## Patterns

### Basic Service with Dependency Injection

#### Good

```typescript
import { Injectable, Logger } from '@nestjs/common';
import { UserRepository } from './repositories/user.repository';
import { CreateUserRequestDto } from './dto/create-user-request.dto';
import { User } from './entities/user.entity';

@Injectable()
export class UserService {
  private readonly logger = new Logger(UserService.name);

  constructor(
    private readonly userRepository: UserRepository,
  ) {}

  async create(dto: CreateUserRequestDto): Promise<User> {
    this.logger.log(`Creating user with email: ${dto.email}`);
    return this.userRepository.create(dto);
  }

  async findOne(id: string): Promise<User> {
    return this.userRepository.findOne({ where: { id } });
  }
}
```

#### Bad

```typescript
// Direct repository instantiation - not testable
@Injectable()
export class UserService {
  private readonly userRepository = new UserRepository();
}

// Missing @Injectable decorator
export class UserService {
  constructor(private readonly userRepository: UserRepository) {}
}
```

### Object Parameters with Destructuring (RO-RO Pattern)

For methods with multiple parameters, use object parameters.

#### Good

```typescript
@Injectable()
export class UserService {
  async findAll({
    skip,
    take,
    where,
    orderBy,
  }: {
    skip?: number;
    take?: number;
    where?: UserWhereInput;
    orderBy?: UserOrderByInput;
  }): Promise<{ data: User[]; count: number }> {
    const [data, count] = await Promise.all([
      this.userRepository.findMany({ skip, take, where, orderBy }),
      this.userRepository.count({ where }),
    ]);

    return { data, count };
  }

  async update({
    id,
    data,
  }: {
    id: string;
    data: UpdateUserRequestDto;
  }): Promise<User> {
    return this.userRepository.update({ id, data });
  }
}
```

#### Bad

```typescript
// Too many positional parameters - hard to read
async findAll(
  skip: number,
  take: number,
  where: object,
  orderBy: object,
  include: object,
): Promise<User[]> {
  // Unclear which parameter is which when calling
}

// Returning only data without count for paginated results
async findAll(): Promise<User[]> {
  return this.userRepository.findMany();
}
```

### Splitting Long Methods into Atomic Functions

Long methods should be split into smaller, focused functions that are orchestrated by a main method.

#### Good

```typescript
@Injectable()
export class OrderService {
  async createOrder({
    userId,
    items,
  }: {
    userId: string;
    items: CreateOrderItemDto[];
  }): Promise<Order> {
    // Orchestration method - calls atomic functions
    await this.validateUser(userId);
    await this.validateInventory(items);

    const order = await this.initializeOrder(userId);
    await this.addOrderItems(order.id, items);
    await this.updateInventory(items);
    await this.notifyUser(userId, order);

    return this.getOrderWithDetails(order.id);
  }

  // Atomic functions - single responsibility
  private async validateUser(userId: string): Promise<void> {
    const user = await this.userService.findOne(userId);
    if (!user) {
      throw new NotFoundException({
        code: OrderError.USER_NOT_FOUND,
        message: 'User not found',
      });
    }
    if (!user.isActive) {
      throw new BadRequestException({
        code: OrderError.USER_INACTIVE,
        message: 'User account is inactive',
      });
    }
  }

  private async validateInventory(items: CreateOrderItemDto[]): Promise<void> {
    for (const item of items) {
      const product = await this.productRepository.findOne(item.productId);
      if (!product) {
        throw new NotFoundException({
          code: OrderError.PRODUCT_NOT_FOUND,
          message: `Product ${item.productId} not found`,
        });
      }
      if (product.stock < item.quantity) {
        throw new BadRequestException({
          code: OrderError.INSUFFICIENT_STOCK,
          message: `Insufficient stock for ${product.name}`,
        });
      }
    }
  }

  private async initializeOrder(userId: string): Promise<Order> {
    return this.orderRepository.create({
      userId,
      status: OrderStatus.PENDING,
      createdAt: new Date(),
    });
  }

  private async addOrderItems(orderId: string, items: CreateOrderItemDto[]): Promise<void> {
    await this.orderItemRepository.createMany(
      items.map((item) => ({
        orderId,
        productId: item.productId,
        quantity: item.quantity,
      })),
    );
  }

  private async updateInventory(items: CreateOrderItemDto[]): Promise<void> {
    for (const item of items) {
      await this.productRepository.decrementStock(item.productId, item.quantity);
    }
  }

  private async notifyUser(userId: string, order: Order): Promise<void> {
    await this.notificationService.sendOrderConfirmation({ userId, orderId: order.id });
  }

  private async getOrderWithDetails(orderId: string): Promise<Order> {
    return this.orderRepository.findOne({
      where: { id: orderId },
      include: { items: true },
    });
  }
}
```

#### Bad

```typescript
// Single monolithic method - hard to test, read, and maintain
async createOrder(userId: string, items: any[]): Promise<Order> {
  // 100+ lines of mixed validation, creation, updates, notifications
  const user = await this.userRepository.findOne(userId);
  if (!user) throw new NotFoundException();
  if (!user.isActive) throw new BadRequestException();

  for (const item of items) {
    const product = await this.productRepository.findOne(item.productId);
    if (!product) throw new NotFoundException();
    if (product.stock < item.quantity) throw new BadRequestException();
  }

  const order = await this.orderRepository.create({ userId, status: 'pending' });

  for (const item of items) {
    await this.orderItemRepository.create({ orderId: order.id, ...item });
  }

  for (const item of items) {
    await this.productRepository.update(item.productId, {
      stock: { decrement: item.quantity },
    });
  }

  await this.emailService.send({ to: user.email, subject: 'Order confirmed' });

  return order;
}
```

### Dedicated Service for Complex Operations

When an operation is very complex, create a dedicated service file.

#### Good

```typescript
// create-order.service.ts - Dedicated service for order creation
@Injectable()
export class CreateOrderService {
  constructor(
    private readonly userRepository: UserRepository,
    private readonly productRepository: ProductRepository,
    private readonly orderRepository: OrderRepository,
    private readonly notificationService: NotificationService,
    private readonly paymentService: PaymentService,
  ) {}

  async execute({
    userId,
    items,
    paymentMethod,
  }: CreateOrderInput): Promise<CreateOrderResult> {
    // All the complex logic for order creation
    const validatedUser = await this.validateAndGetUser(userId);
    const validatedItems = await this.validateAndGetProducts(items);
    const totals = this.calculateTotals(validatedItems);

    const order = await this.createOrderWithTransaction({
      user: validatedUser,
      items: validatedItems,
      totals,
    });

    await this.processPayment(order, paymentMethod);
    await this.sendNotifications(validatedUser, order);

    return { order, totals };
  }

  // ... all the atomic helper methods
}

// order.service.ts - Main service delegates to specialized services
@Injectable()
export class OrderService {
  constructor(
    private readonly createOrderService: CreateOrderService,
    private readonly orderRepository: OrderRepository,
  ) {}

  async create(dto: CreateOrderRequestDto): Promise<Order> {
    const result = await this.createOrderService.execute(dto);
    return result.order;
  }

  async findOne(id: string): Promise<Order> {
    return this.orderRepository.findOne({ where: { id } });
  }

  async findAll(query: OrderQueryDto): Promise<{ data: Order[]; count: number }> {
    return this.orderRepository.findAll(query);
  }
}
```

### Validation Before Operations

#### Good

```typescript
@Injectable()
export class UserService {
  async create(dto: CreateUserRequestDto): Promise<User> {
    // Check for existing email
    const existingUser = await this.userRepository.findByEmail(dto.email);
    if (existingUser) {
      throw new ConflictException({
        code: UserError.EMAIL_EXISTS,
        message: 'User with this email already exists',
      });
    }

    return this.userRepository.create(dto);
  }

  async update({ id, data }: { id: string; data: UpdateUserRequestDto }): Promise<User> {
    // Verify user exists
    const user = await this.userRepository.findOne({ where: { id } });
    if (!user) {
      throw new NotFoundException({
        code: UserError.NOT_FOUND,
        message: 'User not found',
      });
    }

    // Validate email uniqueness if changing email
    if (data.email && data.email !== user.email) {
      const existingUser = await this.userRepository.findByEmail(data.email);
      if (existingUser) {
        throw new ConflictException({
          code: UserError.EMAIL_EXISTS,
          message: 'Email already in use',
        });
      }
    }

    return this.userRepository.update({ id, data });
  }

  async delete(id: string): Promise<void> {
    const user = await this.userRepository.findOne({
      where: { id },
      include: { orders: true },
    });

    if (!user) {
      throw new NotFoundException({
        code: UserError.NOT_FOUND,
        message: 'User not found',
      });
    }

    // Business rule: cannot delete user with active orders
    const hasActiveOrders = user.orders.some(
      (order) => order.status !== OrderStatus.COMPLETED,
    );
    if (hasActiveOrders) {
      throw new BadRequestException({
        code: UserError.CANNOT_DELETE_ACTIVE,
        message: 'Cannot delete user with active orders',
      });
    }

    await this.userRepository.delete(id);
  }
}
```

### Service Composition

#### Good

```typescript
@Injectable()
export class OrderService {
  constructor(
    private readonly orderRepository: OrderRepository,
    private readonly userService: UserService,
    private readonly productService: ProductService,
    private readonly notificationService: NotificationService,
  ) {}

  async create({
    userId,
    items,
  }: {
    userId: string;
    items: CreateOrderItemDto[];
  }): Promise<Order> {
    // Delegate validation to specialized services
    const user = await this.userService.findOneOrFail(userId);

    // Delegate product validation
    for (const item of items) {
      await this.productService.validateStock({
        productId: item.productId,
        quantity: item.quantity,
      });
    }

    // Create order
    const order = await this.orderRepository.create({ userId, items });

    // Delegate notification
    await this.notificationService.sendOrderConfirmation({ user, order });

    return order;
  }
}
```

### Async Operations with Error Handling

#### Good

```typescript
@Injectable()
export class ImportService {
  async importUsers(file: Express.Multer.File): Promise<ImportResult> {
    const users = await this.parseFile(file);
    const results: ImportResult = {
      successful: [],
      failed: [],
    };

    // Process in batches to avoid memory issues
    const batches = this.chunk(users, 100);

    for (const batch of batches) {
      const batchResults = await Promise.allSettled(
        batch.map((userData) => this.createUser(userData)),
      );

      batchResults.forEach((result, index) => {
        if (result.status === 'fulfilled') {
          results.successful.push(result.value);
        } else {
          results.failed.push({
            data: batch[index],
            error: result.reason.message,
          });
        }
      });
    }

    return results;
  }

  private chunk<T>(array: T[], size: number): T[][] {
    return Array.from({ length: Math.ceil(array.length / size) }, (_, i) =>
      array.slice(i * size, i * size + size),
    );
  }
}
```

## Best Practices

- Use constructor injection for all dependencies
- Use the Logger from `@nestjs/common` for logging
- Use object parameters (RO-RO pattern) for methods with multiple parameters
- Return `{ data, count }` for paginated results
- **Split long methods into atomic functions** - each function does one thing
- **Create dedicated service files for complex operations** (>50 lines)
- Keep simple CRUD in the main feature.service.ts
- Validate business rules before performing operations
- Use transactions for operations that modify multiple records
- Delegate specialized tasks to other services (composition)
- Use specific NestJS exceptions with error codes
- Use `async/await` consistently
- Process large datasets in batches

## Common Mistakes

- Direct instantiation of dependencies instead of injection
- Missing `@Injectable()` decorator
- Monolithic methods that do too much (>50 lines)
- Not splitting complex operations into dedicated services
- Not validating entity existence before operations
- Putting too much logic in a single service (god service)
- Catching errors without proper handling or re-throwing
- Not logging important operations
- Using positional parameters instead of object parameters
- Returning raw data without count for paginated queries

---

### Integration test patterns for NestJS including database setup, cleanup, and test isolation.
> Applies to: `**/*.integration.spec.ts`

# NestJS Integration Testing Standards

How to write comprehensive integration tests with real database interactions, proper setup/cleanup, and test isolation.

## Purpose

Integration tests verify that multiple components work together correctly. They:
- Test real database interactions
- Verify API endpoints end-to-end
- Test transactions and data consistency
- Ensure proper error handling across layers

## Test File Organization

```
src/
├── users/
│   ├── users.service.ts
│   ├── users.service.spec.ts              # Unit tests
│   └── users.integration.spec.ts          # Integration tests
test/
├── setup/
│   ├── test-database.ts                   # Database utilities
│   └── test-app.ts                        # App bootstrapping
└── helpers/
    └── test-helpers.ts                    # Shared test utilities
```

## Test Structure

Follow the same grouping hierarchy as unit tests.

```typescript
// [Feature] -> [Endpoint] -> [Scenario] -> [Test Case]
describe('Users API (Integration)', () => {
  describe('POST /users', () => {
    describe('when request is valid', () => {
      it('should create user and return 201', async () => { });
      it('should hash the password before storing', async () => { });
    });

    describe('when email already exists', () => {
      it('should return 409 with EMAIL_EXISTS code', async () => { });
    });

    describe('when validation fails', () => {
      it('should return 400 with validation errors', async () => { });
    });
  });

  describe('GET /users/:id', () => {
    describe('when user exists', () => {
      it('should return user data with 200', async () => { });
    });

    describe('when user does not exist', () => {
      it('should return 404 with NOT_FOUND code', async () => { });
    });
  });
});
```

## Test Isolation

**Critical**: Tests must be isolated and not depend on each other.

### Use Unique Identifiers

```typescript
import { randomUUID } from 'crypto';

describe('Users API (Integration)', () => {
  const testId = randomUUID().slice(0, 8);  // Unique per test run

  // All test data includes testId for easy cleanup
  const testEmail = `user-${testId}@example.com`;

  afterAll(async () => {
    // Clean up only this test run's data
    await db.users.deleteMany({
      where: { email: { contains: testId } },
    });
  });
});
```

### Setup Per Test Group

```typescript
describe('GET /users/:id', () => {
  let testUser: User;

  beforeEach(async () => {
    // Create fresh data for each test in this group
    testUser = await db.users.create({
      data: {
        email: `get-test-${Date.now()}@example.com`,
        name: 'Test User',
      },
    });
  });

  afterEach(async () => {
    // Clean up after each test
    await db.users.delete({ where: { id: testUser.id } });
  });

  it('should return user by id', async () => {
    const response = await request(app.getHttpServer())
      .get(`/users/${testUser.id}`)
      .expect(200);

    expect(response.body.id).toBe(testUser.id);
  });
});
```

## Basic Integration Test Pattern

```typescript
import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import * as request from 'supertest';
import { AppModule } from '../app.module';
import { DatabaseService } from '../database/database.service';
import { randomUUID } from 'crypto';

describe('Users API (Integration)', () => {
  let app: INestApplication;
  let db: DatabaseService;
  const testId = randomUUID().slice(0, 8);

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
    await app.init();

    db = app.get<DatabaseService>(DatabaseService);
  });

  afterAll(async () => {
    // Clean up all test data
    await db.users.deleteMany({
      where: { email: { contains: testId } },
    });
    await app.close();
  });

  describe('POST /users', () => {
    describe('when request is valid', () => {
      it('should create user and return 201', async () => {
        // Arrange
        const createDto = {
          email: `create-${testId}@example.com`,
          name: 'Test User',
          password: 'password123',
        };

        // Act
        const response = await request(app.getHttpServer())
          .post('/users')
          .send(createDto)
          .expect(201);

        // Assert - Response
        expect(response.body).toMatchObject({
          email: createDto.email,
          name: createDto.name,
        });
        expect(response.body.id).toBeDefined();
        expect(response.body.password).toBeUndefined();  // Not exposed

        // Assert - Database
        const dbUser = await db.users.findUnique({
          where: { email: createDto.email },
        });
        expect(dbUser).toBeDefined();
        expect(dbUser?.name).toBe(createDto.name);
      });
    });

    describe('when email already exists', () => {
      it('should return 409 with EMAIL_EXISTS code', async () => {
        // Arrange - Create existing user
        const email = `duplicate-${testId}@example.com`;
        await db.users.create({
          data: { email, name: 'Existing', password: 'hash' },
        });

        // Act
        const response = await request(app.getHttpServer())
          .post('/users')
          .send({ email, name: 'New User', password: 'password123' })
          .expect(409);

        // Assert
        expect(response.body.code).toBe('USER_EMAIL_EXISTS');
      });
    });

    describe('when validation fails', () => {
      it('should return 400 with validation errors', async () => {
        // Act
        const response = await request(app.getHttpServer())
          .post('/users')
          .send({ email: 'invalid-email', name: '', password: '123' })
          .expect(400);

        // Assert
        expect(response.body.errors).toBeDefined();
        expect(response.body.errors.length).toBeGreaterThan(0);
      });
    });
  });

  describe('GET /users', () => {
    beforeEach(async () => {
      // Seed test data
      await db.users.createMany({
        data: [
          { email: `list-1-${testId}@example.com`, name: 'User 1' },
          { email: `list-2-${testId}@example.com`, name: 'User 2' },
          { email: `list-3-${testId}@example.com`, name: 'User 3' },
        ],
      });
    });

    afterEach(async () => {
      await db.users.deleteMany({
        where: { email: { contains: `list-${testId}` } },
      });
    });

    it('should return paginated users', async () => {
      // Act
      const response = await request(app.getHttpServer())
        .get('/users')
        .query({ page: 1, limit: 2 })
        .expect(200);

      // Assert
      expect(response.body.data).toHaveLength(2);
      expect(response.body.meta.total).toBeGreaterThanOrEqual(3);
    });
  });
});
```

## Testing with Authentication

```typescript
describe('Protected Routes (Integration)', () => {
  let app: INestApplication;
  let userToken: string;
  let adminToken: string;

  beforeAll(async () => {
    // ... app setup

    // Get tokens for authenticated requests
    const userResponse = await request(app.getHttpServer())
      .post('/auth/login')
      .send({ email: 'user@example.com', password: 'password' });
    userToken = userResponse.body.accessToken;

    const adminResponse = await request(app.getHttpServer())
      .post('/auth/login')
      .send({ email: 'admin@example.com', password: 'adminpass' });
    adminToken = adminResponse.body.accessToken;
  });

  describe('GET /users/profile', () => {
    describe('when authenticated', () => {
      it('should return user profile', async () => {
        const response = await request(app.getHttpServer())
          .get('/users/profile')
          .set('Authorization', `Bearer ${userToken}`)
          .expect(200);

        expect(response.body.email).toBeDefined();
      });
    });

    describe('when not authenticated', () => {
      it('should return 401', async () => {
        await request(app.getHttpServer())
          .get('/users/profile')
          .expect(401);
      });
    });

    describe('when token is invalid', () => {
      it('should return 401', async () => {
        await request(app.getHttpServer())
          .get('/users/profile')
          .set('Authorization', 'Bearer invalid-token')
          .expect(401);
      });
    });
  });

  describe('GET /admin/users', () => {
    describe('when user is admin', () => {
      it('should return all users', async () => {
        await request(app.getHttpServer())
          .get('/admin/users')
          .set('Authorization', `Bearer ${adminToken}`)
          .expect(200);
      });
    });

    describe('when user is not admin', () => {
      it('should return 403', async () => {
        await request(app.getHttpServer())
          .get('/admin/users')
          .set('Authorization', `Bearer ${userToken}`)
          .expect(403);
      });
    });
  });
});
```

## Testing Transactions

```typescript
describe('Order Creation (Integration)', () => {
  describe('POST /orders', () => {
    describe('when inventory is sufficient', () => {
      it('should create order and update inventory atomically', async () => {
        // Arrange
        const product = await db.products.create({
          data: { name: 'Test Product', price: 100, stock: 10 },
        });

        const orderData = {
          items: [{ productId: product.id, quantity: 3 }],
        };

        // Act
        const response = await request(app.getHttpServer())
          .post('/orders')
          .set('Authorization', `Bearer ${userToken}`)
          .send(orderData)
          .expect(201);

        // Assert - Order created
        expect(response.body.items).toHaveLength(1);

        // Assert - Inventory updated
        const updatedProduct = await db.products.findUnique({
          where: { id: product.id },
        });
        expect(updatedProduct?.stock).toBe(7);
      });
    });

    describe('when inventory is insufficient', () => {
      it('should return 400 and not modify inventory', async () => {
        // Arrange
        const product = await db.products.create({
          data: { name: 'Limited Product', price: 100, stock: 2 },
        });
        const initialStock = product.stock;

        // Act
        await request(app.getHttpServer())
          .post('/orders')
          .set('Authorization', `Bearer ${userToken}`)
          .send({ items: [{ productId: product.id, quantity: 10 }] })
          .expect(400);

        // Assert - Stock unchanged (transaction rolled back)
        const unchangedProduct = await db.products.findUnique({
          where: { id: product.id },
        });
        expect(unchangedProduct?.stock).toBe(initialStock);
      });
    });
  });
});
```

## Test Helpers

Create reusable helpers for common operations.

```typescript
// test/helpers/test-helpers.ts
export class TestHelpers {
  constructor(
    private app: INestApplication,
    private db: DatabaseService,
  ) {}

  async createUser(data: Partial<CreateUserInput> = {}): Promise<User> {
    return this.db.users.create({
      data: {
        email: `test-${Date.now()}@example.com`,
        name: 'Test User',
        password: 'hashed',
        ...data,
      },
    });
  }

  async getAuthToken(email: string, password: string): Promise<string> {
    const response = await request(this.app.getHttpServer())
      .post('/auth/login')
      .send({ email, password });
    return response.body.accessToken;
  }

  authenticatedRequest(token: string) {
    return {
      get: (url: string) =>
        request(this.app.getHttpServer())
          .get(url)
          .set('Authorization', `Bearer ${token}`),
      post: (url: string) =>
        request(this.app.getHttpServer())
          .post(url)
          .set('Authorization', `Bearer ${token}`),
      put: (url: string) =>
        request(this.app.getHttpServer())
          .put(url)
          .set('Authorization', `Bearer ${token}`),
      delete: (url: string) =>
        request(this.app.getHttpServer())
          .delete(url)
          .set('Authorization', `Bearer ${token}`),
    };
  }
}

// Usage
describe('Orders (Integration)', () => {
  let helpers: TestHelpers;

  beforeAll(async () => {
    helpers = new TestHelpers(app, db);
  });

  it('should create order', async () => {
    const user = await helpers.createUser();
    const token = await helpers.getAuthToken(user.email, 'password');
    const client = helpers.authenticatedRequest(token);

    const response = await client.post('/orders').send({ items: [] });
    expect(response.status).toBe(201);
  });
});
```

## Database Cleanup Strategies

### Strategy 1: Unique Identifiers (Recommended)

```typescript
const testId = randomUUID().slice(0, 8);
// All test data includes testId
// Cleanup: DELETE WHERE email CONTAINS testId
```

### Strategy 2: Transaction Rollback

```typescript
describe('Users API', () => {
  beforeEach(async () => {
    await db.$executeRaw`BEGIN`;
  });

  afterEach(async () => {
    await db.$executeRaw`ROLLBACK`;
  });
});
```

### Strategy 3: Truncate Tables

```typescript
afterAll(async () => {
  // Only for test database!
  await db.$executeRaw`TRUNCATE TABLE users CASCADE`;
});
```

## Best Practices

- **Unique identifiers** - Use UUID/timestamp to isolate test data
- **Clean up always** - Always clean up in `afterAll`/`afterEach`
- **Test isolation** - Tests must not depend on each other
- **Verify database state** - Assert both response AND database
- **Test both success and error** - Include 4xx response tests
- **Same grouping structure** - Class → Endpoint → Scenario → Test
- **Test authentication flows** - Include auth/no-auth/invalid-auth
- **Test transactions** - Verify rollback on errors
- **Use helpers** - Create reusable test utilities
- **Seed per group** - Use `beforeEach` for group-specific data

## Common Mistakes

- Tests depending on other tests' data
- Not cleaning up test data
- Missing unique identifiers (data collisions)
- Not verifying database state after operations
- Missing authentication tests
- Not testing validation errors
- Not testing transaction rollback
- Hardcoded data that conflicts between runs
- Setup in `beforeAll` when `beforeEach` is needed

---

### Unit test patterns for NestJS including mocking, structure, grouping, and assertions.
> Applies to: `**/*.spec.ts`

# NestJS Unit Testing Standards

How to write comprehensive unit tests following industry standards with proper structure, mocking, and assertions.

## Purpose

Unit tests verify individual components in isolation. They should:
- Test single units of code (services, controllers, utilities)
- Mock all external dependencies
- Be fast, deterministic, and independent
- Follow consistent structure across the codebase
- Focus on testing actual functionality and business logic

## Test File Organization

### Directory Structure

```
src/
├── users/
│   ├── users.service.ts
│   ├── users.service.spec.ts       # Tests next to source file
│   ├── users.controller.ts
│   └── users.controller.spec.ts
```

### Consistent Test Structure

**Critical**: Follow the same structure across ALL test files in the codebase.

```typescript
// [ClassName] -> [MethodName] -> [Test Cases]
describe('UserService', () => {
  // Setup block - same pattern in every test file
  let service: UserService;
  let mockRepository: jest.Mocked<UserRepository>;

  beforeEach(() => {
    jest.clearAllMocks();
    // Setup mocks and instantiate service
  });

  // Group by method
  describe('create', () => {
    // Group by scenario within method
    describe('when email is unique', () => {
      it('should create and return the user', async () => {
        // Test case
      });
    });

    describe('when email already exists', () => {
      it('should throw ConflictException', async () => {
        // Test case
      });
    });
  });

  describe('findOne', () => {
    describe('when user exists', () => {
      it('should return the user', async () => { });
    });

    describe('when user does not exist', () => {
      it('should throw NotFoundException', async () => { });
    });
  });
});
```

## Test Grouping Hierarchy

Follow this hierarchy for ALL test files:

```
describe('[ClassName]')           // Class being tested
  └── describe('[methodName]')    // Method being tested
       └── describe('[scenario]') // Specific scenario/condition
            └── it('[expected behavior]')  // Actual test case
```

#### Good

```typescript
describe('OrderService', () => {
  describe('create', () => {
    describe('when user is valid', () => {
      describe('and products are in stock', () => {
        it('should create the order', async () => { });
        it('should decrement product stock', async () => { });
        it('should send confirmation notification', async () => { });
      });

      describe('and products are out of stock', () => {
        it('should throw BadRequestException with INSUFFICIENT_STOCK code', async () => { });
        it('should not create any order', async () => { });
      });
    });

    describe('when user does not exist', () => {
      it('should throw NotFoundException with USER_NOT_FOUND code', async () => { });
    });
  });

  describe('cancel', () => {
    describe('when order is pending', () => {
      it('should update status to CANCELLED', async () => { });
      it('should restore product stock', async () => { });
    });

    describe('when order is already completed', () => {
      it('should throw BadRequestException', async () => { });
    });
  });
});
```

#### Bad

```typescript
// All tests in single describe - hard to navigate
describe('OrderService', () => {
  it('should create order', async () => { });
  it('should not create order if no stock', async () => { });
  it('should cancel order', async () => { });
  it('should not cancel completed order', async () => { });
  it('should find order', async () => { });
  // No logical grouping
});

// Inconsistent grouping
describe('OrderService', () => {
  describe('create', () => {
    it('works', async () => { });  // Vague name
  });

  it('cancels order', async () => { });  // Not grouped under method
});
```

## Arrange-Act-Assert Pattern

Every test should follow AAA with clear visual separation.

#### Good

```typescript
it('should create and return the user when email is unique', async () => {
  // Arrange
  const createDto: CreateUserRequestDto = {
    email: 'test@example.com',
    name: 'Test User',
    password: 'password123',
  };
  const expectedUser = { id: 'user-1', ...createDto };

  mockRepository.findByEmail.mockResolvedValue(null);
  mockRepository.create.mockResolvedValue(expectedUser);

  // Act
  const result = await service.create(createDto);

  // Assert
  expect(result).toEqual(expectedUser);
  expect(mockRepository.findByEmail).toHaveBeenCalledWith(createDto.email);
  expect(mockRepository.create).toHaveBeenCalledWith(createDto);
});
```

#### Bad

```typescript
it('should create user', async () => {
  mockRepository.findByEmail.mockResolvedValue(null);
  mockRepository.create.mockResolvedValue({ id: '1' });
  const result = await service.create({ email: 'test@test.com' });
  expect(result.id).toBe('1');
  // No clear separation, minimal assertions
});
```

## Mocking Patterns

### Standard Mock Setup

```typescript
describe('UserService', () => {
  let service: UserService;
  let mockUserRepository: jest.Mocked<UserRepository>;
  let mockNotificationService: jest.Mocked<NotificationService>;

  // Define mock objects outside beforeEach for reusability
  const createMockUserRepository = (): jest.Mocked<UserRepository> => ({
    findAll: jest.fn(),
    findOne: jest.fn(),
    findByEmail: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
    delete: jest.fn(),
  } as jest.Mocked<UserRepository>);

  const createMockNotificationService = (): jest.Mocked<NotificationService> => ({
    sendEmail: jest.fn(),
    sendPush: jest.fn(),
  } as jest.Mocked<NotificationService>);

  beforeEach(() => {
    jest.clearAllMocks();

    mockUserRepository = createMockUserRepository();
    mockNotificationService = createMockNotificationService();

    service = new UserService(mockUserRepository, mockNotificationService);
  });
});
```

### Using Jest Mock Extended (Alternative)

```typescript
import { mock, mockDeep, DeepMockProxy } from 'jest-mock-extended';

describe('UserService', () => {
  let service: UserService;
  let mockRepository: DeepMockProxy<UserRepository>;

  beforeEach(() => {
    mockRepository = mockDeep<UserRepository>();
    service = new UserService(mockRepository);
  });

  it('should find user by id', async () => {
    // Arrange
    const expectedUser = { id: '1', email: 'test@example.com' };
    mockRepository.findOne.mockResolvedValue(expectedUser);

    // Act
    const result = await service.findOne('1');

    // Assert
    expect(result).toEqual(expectedUser);
  });
});
```

### NestJS Testing Module (When Needed)

Use TestingModule when testing components with NestJS decorators or when DI is complex.

```typescript
import { Test, TestingModule } from '@nestjs/testing';

describe('UserService', () => {
  let service: UserService;
  let mockRepository: jest.Mocked<UserRepository>;

  beforeEach(async () => {
    mockRepository = {
      findAll: jest.fn(),
      findOne: jest.fn(),
      create: jest.fn(),
    } as jest.Mocked<UserRepository>;

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UserService,
        { provide: UserRepository, useValue: mockRepository },
      ],
    }).compile();

    service = module.get<UserService>(UserService);
  });
});
```

## Testing Error Cases

Always test both success and error paths with specific error codes.

```typescript
describe('UserService', () => {
  describe('create', () => {
    describe('when email already exists', () => {
      it('should throw ConflictException with EMAIL_EXISTS code', async () => {
        // Arrange
        const dto = { email: 'existing@example.com', name: 'Test' };
        mockRepository.findByEmail.mockResolvedValue({ id: '1', email: dto.email });

        // Act & Assert
        await expect(service.create(dto)).rejects.toThrow(ConflictException);

        // Verify error details
        try {
          await service.create(dto);
        } catch (error) {
          expect(error.response.code).toBe(UserError.EMAIL_EXISTS);
        }
      });
    });
  });

  describe('delete', () => {
    describe('when user has active orders', () => {
      it('should throw BadRequestException with CANNOT_DELETE_ACTIVE code', async () => {
        // Arrange
        const userWithOrders = {
          id: '1',
          orders: [{ id: 'order-1', status: 'PENDING' }],
        };
        mockRepository.findOne.mockResolvedValue(userWithOrders);

        // Act & Assert
        await expect(service.delete('1')).rejects.toThrow(BadRequestException);
      });
    });
  });
});
```

## Test Data Builders

Use builders for complex test data to keep tests readable.

```typescript
// test/builders/user.builder.ts
export class UserBuilder {
  private user: User = {
    id: 'default-id',
    email: 'default@example.com',
    name: 'Default User',
    status: 'ACTIVE',
    createdAt: new Date(),
  };

  withId(id: string): this {
    this.user.id = id;
    return this;
  }

  withEmail(email: string): this {
    this.user.email = email;
    return this;
  }

  asInactive(): this {
    this.user.status = 'INACTIVE';
    return this;
  }

  build(): User {
    return { ...this.user };
  }
}

// Usage in tests
describe('UserService', () => {
  it('should reject inactive users', async () => {
    // Arrange
    const inactiveUser = new UserBuilder()
      .withId('user-1')
      .asInactive()
      .build();

    mockRepository.findOne.mockResolvedValue(inactiveUser);

    // Act & Assert
    await expect(service.activate('user-1')).rejects.toThrow();
  });
});
```

## Verifying Mock Interactions

Always verify that mocks were called with correct arguments.

```typescript
it('should call repository with correct parameters', async () => {
  // Arrange
  const dto = { email: 'test@example.com', name: 'Test' };
  mockRepository.findByEmail.mockResolvedValue(null);
  mockRepository.create.mockResolvedValue({ id: '1', ...dto });

  // Act
  await service.create(dto);

  // Assert - Verify calls
  expect(mockRepository.findByEmail).toHaveBeenCalledTimes(1);
  expect(mockRepository.findByEmail).toHaveBeenCalledWith(dto.email);
  expect(mockRepository.create).toHaveBeenCalledWith(dto);
});

it('should NOT call create when email exists', async () => {
  // Arrange
  mockRepository.findByEmail.mockResolvedValue({ id: '1' });

  // Act
  try {
    await service.create({ email: 'existing@example.com' });
  } catch {}

  // Assert - Verify create was NOT called
  expect(mockRepository.create).not.toHaveBeenCalled();
});
```

## Best Practices

- **Consistent structure** - Same grouping pattern in ALL test files
- **Clear grouping** - Class → Method → Scenario → Test case
- **Descriptive names** - Test names should explain expected behavior
- **AAA pattern** - Clear Arrange/Act/Assert separation
- **One assertion focus** - Test one logical concept per test
- **Clear mocks** - Always `jest.clearAllMocks()` in `beforeEach`
- **Verify interactions** - Use `toHaveBeenCalledWith` to verify arguments
- **Test both paths** - Always test success AND error scenarios
- **Use builders** - For complex test data
- **Mock at boundaries** - Mock repositories and external services

## Common Mistakes

- Inconsistent test structure across files
- Not grouping tests by method/scenario
- Vague test names ("should work", "test create")
- Testing multiple behaviors in one test
- Not verifying mock call arguments
- Missing error case tests
- Not clearing mocks between tests
- Using real dependencies instead of mocks
- Forgetting to await async operations

---

### TypeScript guidelines, naming conventions, and NestJS architectural principles.
> Applies to: `src/modules/**/*.ts`

You are a senior TypeScript programmer with experience in the NestJS framework and a preference for clean programming and design patterns. Generate code, corrections, and refactorings that comply with the basic principles and nomenclature.

## TypeScript General Guidelines

### Basic Principles

- Use English for all code and documentation.
- Always declare the type of each variable and function (parameters and return value).
- Avoid using any.
- Create necessary types.
- Use JSDoc to document public classes and methods.
- Don't leave blank lines within a function.
- One export per file.

### Nomenclature

- Use PascalCase for classes.
- Use camelCase for variables, functions, and methods.
- Use kebab-case for file and directory names.
- Use UPPERCASE for environment variables.
- Avoid magic numbers and define constants.
- Start each function with a verb.
- Use verbs for boolean variables. Example: isLoading, hasError, canDelete, etc.
- Use complete words instead of abbreviations and correct spelling.
- Except for standard abbreviations like API, URL, etc.
- Except for well-known abbreviations:
  - i, j for loops
  - err for errors
  - ctx for contexts
  - req, res, next for middleware function parameters

### Functions

- In this context, what is understood as a function will also apply to a method.
- Write short functions with a single purpose. Less than 20 instructions.
- Name functions with a verb and something else.
- If it returns a boolean, use isX or hasX, canX, etc.
- If it doesn't return anything, use executeX or saveX, etc.
- Avoid nesting blocks by:
  - Early checks and returns.
  - Extraction to utility functions.
- Use higher-order functions (map, filter, reduce, etc.) to avoid function nesting.
- Use arrow functions for simple functions (less than 3 instructions).
- Use named functions for non-simple functions.
- Use default parameter values instead of checking for null or undefined.
- Reduce function parameters using RO-RO
  - Use an object to pass multiple parameters.
  - Use an object to return results.
  - Declare necessary types for input arguments and output.
- Use a single level of abstraction.

### Data

- Don't abuse primitive types and encapsulate data in composite types.
- Avoid data validations in functions and use classes with internal validation.
- Prefer immutability for data.
- Use readonly for data that doesn't change.
- Use as const for literals that don't change.

### Classes

- Follow SOLID principles.
- Prefer composition over inheritance.
- Declare interfaces to define contracts.
- Write small classes with a single purpose.
  - Less than 200 instructions.
  - Less than 10 public methods.
  - Less than 10 properties.

### Exceptions

- Use exceptions to handle errors you don't expect.
- If you catch an exception, it should be to:
  - Fix an expected problem.
  - Add context.
  - Otherwise, use a global handler.

### Testing

- Follow the Arrange-Act-Assert convention for tests.
- Name test variables clearly.
- Follow the convention: inputX, mockX, actualX, expectedX, etc.
- Write unit tests for each public function.
- Use test doubles to simulate dependencies.
  - Except for third-party dependencies that are not expensive to execute.
- Write acceptance tests for each module.
- Follow the Given-When-Then convention.

## Specific to NestJS

### Basic Principles

- Use modular architecture
- Encapsulate the API in modules.
  - One module per main domain/route.
  - One controller for its route.
  - And other controllers for secondary routes.
  - A models folder with data types.
  - DTOs validated with class-validator for inputs.
  - Declare simple types for outputs.
  - A services module with business logic and persistence.
  - Entities with MikroORM for data persistence.
  - One service per entity.
- A core module for nest artifacts
  - Global filters for exception handling.
  - Global middlewares for request management.
  - Guards for permission management.
  - Interceptors for request management.
- A shared module for services shared between modules.
  - Utilities
  - Shared business logic

### Testing

- Use the standard Jest framework for testing.
- Write tests for each controller and service.
- Write end to end tests for each api module.
- Add a admin/test method to each controller as a smoke test.

---

## React Rules

### React component architecture including file structure, naming conventions, composition patterns, and folder organization.
> Applies to: `**/*.tsx`

# React Component Architecture

How to structure React applications with feature-based organization, consistent naming, and composable component patterns.

## Purpose

A well-organized component architecture:
- Makes code easy to navigate and locate
- Keeps related code colocated (reduces cognitive overhead)
- Enables independent development of features
- Supports reusability through consistent patterns

## Folder Structure

Use a **feature-based** organization where code that changes together lives together:

```
src/
├── components/          # Shared, reusable UI components
│   ├── button/
│   │   ├── Button.tsx
│   │   ├── Button.test.tsx
│   │   └── index.ts
│   ├── card/
│   └── index.ts         # Barrel export
├── features/            # Feature-specific code
│   ├── auth/
│   │   ├── components/
│   │   ├── hooks/
│   │   ├── services/
│   │   ├── types.ts
│   │   └── index.ts
│   └── dashboard/
├── hooks/               # Shared custom hooks
├── services/            # API calls and external services
├── types/               # Shared TypeScript types
├── utils/               # Utility functions
└── App.tsx
```

**Rule of thumb**: if something is used by only one feature, keep it inside that feature folder. Promote to `components/` or `hooks/` when reused by two or more features.

## Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Component files | PascalCase | `UserProfile.tsx` |
| Non-component files | kebab-case | `use-auth.ts`, `api-client.ts` |
| Custom hooks | `use` prefix + camelCase | `useForm`, `useWindowSize` |
| Event handlers | `handle` prefix | `handleClick`, `handleSubmit` |
| Boolean props/state | `is/has/should/can` prefix | `isLoading`, `hasError` |
| Constants | UPPER_SNAKE_CASE | `MAX_RETRIES`, `API_URL` |

## Patterns

### Barrel Exports

Use `index.ts` files to simplify imports. Consumers import from the folder, not the file.

#### Good

```tsx
// components/user-profile/index.ts
export { UserProfile } from './UserProfile';
export type { UserProfileProps } from './UserProfile';

// Consuming code
import { UserProfile } from '@/components/user-profile';
```

#### Bad

```tsx
// Consumers forced to know internal file names
import { UserProfile } from '@/components/user-profile/UserProfile';
```

---

### Component Composition

Prefer composition over deeply nested prop passing. Pass components as children or use compound components for related UI elements.

#### Good

```tsx
// Compound component pattern
export const Card = ({ children }: { children: React.ReactNode }) => (
  <div className="card">{children}</div>
);

Card.Header = ({ children }: { children: React.ReactNode }) => (
  <div className="card-header">{children}</div>
);

Card.Body = ({ children }: { children: React.ReactNode }) => (
  <div className="card-body">{children}</div>
);

// Usage
<Card>
  <Card.Header>Title</Card.Header>
  <Card.Body>Content</Card.Body>
</Card>
```

#### Bad

```tsx
// Prop drilling for variations — hard to extend
<Card title="Title" body="Content" footerText="OK" showBorder hasIcon />
```

---

### Container / Presenter Pattern

Separate data-fetching logic from rendering. Containers handle state and side effects; presenters render UI.

#### Good

```tsx
// UserProfileContainer.tsx — logic only
export const UserProfileContainer = ({ userId }: { userId: string }) => {
  const { data: user, isLoading, error } = useUser(userId);

  if (isLoading) return <Spinner />;
  if (error) return <ErrorMessage error={error} />;
  if (!user) return null;

  return <UserProfile user={user} />;
};

// UserProfile.tsx — rendering only, no async logic
interface UserProfileProps {
  user: User;
}

export const UserProfile = ({ user }: UserProfileProps) => (
  <div>
    <h2>{user.name}</h2>
    <p>{user.email}</p>
  </div>
);
```

#### Bad

```tsx
// Component handles both fetching and rendering — harder to test UI in isolation
export const UserProfile = ({ userId }: { userId: string }) => {
  const [user, setUser] = useState<User | null>(null);

  useEffect(() => {
    fetch(`/api/users/${userId}`).then(r => r.json()).then(setUser);
  }, [userId]);

  return user ? <div>{user.name}</div> : <Spinner />;
};
```

---

### Named Exports

Always use named exports for components. Default exports make refactoring harder and break auto-import in IDEs.

#### Good

```tsx
// UserCard.tsx
export const UserCard = ({ name }: { name: string }) => <div>{name}</div>;
```

#### Bad

```tsx
// Default exports hide the component name from imports and break tree-shaking analysis
export default function ({ name }: { name: string }) {
  return <div>{name}</div>;
}
```

## Best Practices

- Keep component files under **300 lines**; extract logic to custom hooks when exceeded
- Maximum **3–4 levels** of folder nesting
- One component per file (avoid exporting multiple unrelated components from the same file)
- Colocate tests next to source files (`UserCard.tsx` → `UserCard.test.tsx`)
- Do not use array indexes as `key` props — use stable unique IDs
- Avoid `React.FC` without explicit props type (prefer plain function signature with typed props)

## Common Mistakes

- **Mega components**: components with 500+ lines mixing UI, logic, and data fetching
- **Premature extraction**: creating shared components before they are reused in 2+ places
- **Inconsistent naming**: mixing PascalCase and camelCase for component files
- **Missing index.ts**: forcing consumers to navigate internal file structure

---

### React hooks patterns including useState, useEffect, useReducer, and custom hook guidelines.
> Applies to: `**/*.tsx,**/*.ts`

# React Hooks Patterns

How to use React hooks correctly and write maintainable custom hooks following the Rules of Hooks.

## Purpose

Hooks are the primary mechanism for state, side effects, and reusable logic in React. Correct usage:
- Prevents subtle rendering bugs caused by hook order violations
- Keeps components focused on rendering, not logic
- Enables reuse of stateful logic without inheritance

## Rules of Hooks

Always enable `eslint-plugin-react-hooks` with these rules:
- `react-hooks/rules-of-hooks` (error)
- `react-hooks/exhaustive-deps` (warn)

The two hard rules:
1. **Only call hooks at the top level** — never inside loops, conditions, or nested functions
2. **Only call hooks from React function components or custom hooks** — never from plain JS functions

#### Good

```tsx
const UserForm = () => {
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');

  return <form>...</form>;
};
```

#### Bad

```tsx
const UserForm = ({ isAdmin }: { isAdmin: boolean }) => {
  // ❌ Conditional hook call — violates Rules of Hooks
  if (isAdmin) {
    const [adminLevel, setAdminLevel] = useState(0);
  }

  return <form>...</form>;
};
```

## Patterns

### useState

Initialize with meaningful defaults. For complex or related state, consider `useReducer` instead.

#### Good

```tsx
const [isLoading, setIsLoading] = useState(false);
const [error, setError] = useState<string | null>(null);
const [user, setUser] = useState<User | null>(null);

// Functional update when next state depends on previous
setCount(prev => prev + 1);
```

#### Bad

```tsx
// Derived state stored in useState — causes sync issues
const [fullName, setFullName] = useState(`${firstName} ${lastName}`);

// Direct mutation
user.name = 'new name'; // ❌
setUser(user);          // ❌
```

---

### useEffect

Each `useEffect` should have a **single concern**. Always declare all dependencies and clean up subscriptions.

#### Good

```tsx
// Separate effects for separate concerns
useEffect(() => {
  document.title = `${user.name} - Profile`;
}, [user.name]);

useEffect(() => {
  const subscription = eventBus.subscribe(userId, handleEvent);
  return () => subscription.unsubscribe(); // ✅ cleanup
}, [userId, handleEvent]);
```

#### Bad

```tsx
// ❌ Multiple unrelated concerns in one effect
useEffect(() => {
  document.title = user.name;
  fetchUserData();
  trackPageView();
  // No cleanup
}, []); // ❌ Missing dependencies
```

---

### useReducer

Prefer `useReducer` over `useState` when state has multiple related fields or when next state depends on complex logic.

#### Good

```tsx
interface State {
  status: 'idle' | 'loading' | 'success' | 'error';
  data: User | null;
  error: string | null;
}

type Action =
  | { type: 'FETCH_START' }
  | { type: 'FETCH_SUCCESS'; payload: User }
  | { type: 'FETCH_ERROR'; payload: string };

const reducer = (state: State, action: Action): State => {
  switch (action.type) {
    case 'FETCH_START':
      return { ...state, status: 'loading', error: null };
    case 'FETCH_SUCCESS':
      return { status: 'success', data: action.payload, error: null };
    case 'FETCH_ERROR':
      return { ...state, status: 'error', error: action.payload };
    default:
      return state;
  }
};

const [state, dispatch] = useReducer(reducer, { status: 'idle', data: null, error: null });
```

#### Bad

```tsx
// ❌ Four useState calls for related loading state — error-prone to keep in sync
const [isLoading, setIsLoading] = useState(false);
const [isSuccess, setIsSuccess] = useState(false);
const [isError, setIsError] = useState(false);
const [data, setData] = useState<User | null>(null);
```

---

### Custom Hooks

Extract reusable stateful logic into custom hooks. One hook = one concern.

#### Good

```tsx
// hooks/use-fetch.ts
interface UseFetchResult<T> {
  data: T | null;
  isLoading: boolean;
  error: string | null;
  refetch: () => void;
}

export const useFetch = <T,>(url: string): UseFetchResult<T> => {
  const [state, dispatch] = useReducer(fetchReducer<T>, initialState);

  const fetchData = useCallback(async () => {
    dispatch({ type: 'FETCH_START' });
    try {
      const response = await fetch(url);
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const data: T = await response.json();
      dispatch({ type: 'FETCH_SUCCESS', payload: data });
    } catch (err) {
      dispatch({ type: 'FETCH_ERROR', payload: (err as Error).message });
    }
  }, [url]);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  return { ...state, refetch: fetchData };
};

// Usage
const { data: user, isLoading, error } = useFetch<User>(`/api/users/${userId}`);
```

#### Bad

```tsx
// ❌ Logic duplicated in every component that fetches data
const UserProfile = ({ userId }: { userId: string }) => {
  const [user, setUser] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    setIsLoading(true);
    fetch(`/api/users/${userId}`)
      .then(r => r.json())
      .then(data => { setUser(data); setIsLoading(false); });
  }, [userId]);
  // ...
};
```

---

### useMemo and useCallback in Hooks

When a custom hook returns functions or computed values that will be used as dependencies or passed to memoized components, stabilize them.

#### Good

```tsx
export const useUserActions = (userId: string) => {
  const deleteUser = useCallback(async () => {
    await api.deleteUser(userId);
  }, [userId]);

  const updateUser = useCallback(async (data: Partial<User>) => {
    await api.updateUser(userId, data);
  }, [userId]);

  return { deleteUser, updateUser };
};
```

## Best Practices

- Name custom hooks with the `use` prefix — this is required for lint rules to work
- Return only the values the consumer needs (avoid returning the entire state object)
- Keep custom hooks under **150 lines**; split into smaller hooks if larger
- Do not call async functions directly in `useEffect` — define an inner async function and call it
- Use `AbortController` to cancel fetch requests on cleanup
- Avoid `// eslint-disable-next-line react-hooks/exhaustive-deps` — fix the root cause instead

## Common Hooks to Extract

| Hook | Responsibility |
|------|---------------|
| `useForm` | Form state, validation, submission |
| `useFetch` | Data fetching with loading/error states |
| `useDebounce` | Debounce a value |
| `useLocalStorage` | Persist state to localStorage |
| `usePrevious` | Track the previous value of a prop/state |
| `useWindowSize` | Responsive breakpoints |
| `useOnClickOutside` | Close dropdowns/modals on outside click |

---

### React performance optimization patterns including memoization, code splitting, and list virtualization.
> Applies to: `**/*.tsx`

# React Performance Optimization

How to optimize React application performance through memoization, code splitting, and rendering strategies.

## Purpose

Performance optimization should be **data-driven**, not speculative. Premature optimization:
- Adds complexity without measurable benefit
- Creates stale closure bugs when dependencies are wrong
- Makes code harder to maintain

**Profile first** using React DevTools Profiler, then optimize the specific bottleneck.

## Patterns

### React.memo

Prevent re-renders when a parent re-renders but the component's props have not changed. Use only for components with expensive renders or those that receive stable props but re-render too often.

#### Good

```tsx
interface UserRowProps {
  user: User;
  onDelete: (id: string) => void;
}

// Wrap only after profiling shows unnecessary re-renders
export const UserRow = React.memo(({ user, onDelete }: UserRowProps) => (
  <tr>
    <td>{user.name}</td>
    <td>{user.email}</td>
    <td>
      <button onClick={() => onDelete(user.id)}>Delete</button>
    </td>
  </tr>
));

UserRow.displayName = 'UserRow';
```

#### Bad

```tsx
// ❌ Memoizing trivially cheap components adds overhead without benefit
export const Label = React.memo(({ text }: { text: string }) => <span>{text}</span>);

// ❌ Custom comparator that ignores important props
export const UserRow = React.memo(UserRowComponent, () => true); // always skip re-render
```

---

### useCallback

Stabilize function references passed as props to memoized child components. Without `useCallback`, a new function reference is created on every render, causing `React.memo` to be ineffective.

#### Good

```tsx
const UserList = ({ users }: { users: User[] }) => {
  const handleDelete = useCallback(async (id: string) => {
    await api.deleteUser(id);
    // update state...
  }, []); // stable — no dependencies that change

  return (
    <ul>
      {users.map(user => (
        // UserRow is memoized — handleDelete must be stable for memo to work
        <UserRow key={user.id} user={user} onDelete={handleDelete} />
      ))}
    </ul>
  );
};
```

#### Bad

```tsx
const UserList = ({ users }: { users: User[] }) => {
  // ❌ New function reference on every render — React.memo on UserRow is useless
  const handleDelete = (id: string) => api.deleteUser(id);

  return (
    <ul>
      {users.map(user => (
        <UserRow key={user.id} user={user} onDelete={handleDelete} />
      ))}
    </ul>
  );
};
```

---

### useMemo

Memoize expensive computations so they only recalculate when their dependencies change.

#### Good

```tsx
const ProductList = ({ products, filters }: ProductListProps) => {
  // Expensive: filtering + sorting a large array
  const filteredProducts = useMemo(
    () =>
      products
        .filter(p => p.category === filters.category && p.price <= filters.maxPrice)
        .sort((a, b) => a.name.localeCompare(b.name)),
    [products, filters.category, filters.maxPrice],
  );

  return <ul>{filteredProducts.map(p => <ProductRow key={p.id} product={p} />)}</ul>;
};
```

#### Bad

```tsx
// ❌ Memoizing a trivial operation — overhead is greater than the computation
const greeting = useMemo(() => `Hello, ${name}!`, [name]);

// ❌ Missing dependency — stale values when products changes
const filteredProducts = useMemo(() => filterProducts(products), [filters]);
```

---

### Code Splitting with React.lazy

Split large bundles by route so the initial page load only downloads what is needed.

#### Good

```tsx
import { lazy, Suspense } from 'react';
import { Routes, Route } from 'react-router-dom';

// Each route is loaded only when first navigated to
const Dashboard = lazy(() => import('@/pages/Dashboard'));
const Settings = lazy(() => import('@/pages/Settings'));
const Reports = lazy(() => import('@/pages/Reports'));

export const AppRoutes = () => (
  <Suspense fallback={<PageSkeleton />}>
    <Routes>
      <Route path="/dashboard" element={<Dashboard />} />
      <Route path="/settings" element={<Settings />} />
      <Route path="/reports" element={<Reports />} />
    </Routes>
  </Suspense>
);
```

#### Bad

```tsx
// ❌ All pages imported at the top — entire app bundled into one chunk
import Dashboard from '@/pages/Dashboard';
import Settings from '@/pages/Settings';
import Reports from '@/pages/Reports';
```

---

### List Virtualization

For lists with hundreds or thousands of items, only render what is visible in the viewport using `react-window` or `react-virtual`.

#### Good

```tsx
import { FixedSizeList } from 'react-window';

interface VirtualUserListProps {
  users: User[];
}

export const VirtualUserList = ({ users }: VirtualUserListProps) => {
  const Row = useCallback(
    ({ index, style }: { index: number; style: React.CSSProperties }) => (
      <div style={style}>
        <UserRow user={users[index]} />
      </div>
    ),
    [users],
  );

  return (
    <FixedSizeList height={600} itemCount={users.length} itemSize={60} width="100%">
      {Row}
    </FixedSizeList>
  );
};
```

#### Bad

```tsx
// ❌ Rendering 10,000 DOM nodes — causes layout thrashing and slow scroll
const UserList = ({ users }: { users: User[] }) => (
  <ul>
    {users.map(user => <UserRow key={user.id} user={user} />)}
  </ul>
);
```

---

### Stable Keys

Always use stable, unique identifiers as `key` props. Index-based keys cause incorrect DOM reconciliation when the list is reordered or filtered.

#### Good

```tsx
{users.map(user => <UserRow key={user.id} user={user} />)}
```

#### Bad

```tsx
// ❌ Index as key — breaks when items are reordered/inserted/removed
{users.map((user, index) => <UserRow key={index} user={user} />)}

// ❌ Random key — forces remount on every render
{users.map(user => <UserRow key={Math.random()} user={user} />)}
```

## Anti-Patterns to Avoid

| Anti-pattern | Problem | Fix |
|-------------|---------|-----|
| Creating new objects in render | New reference every render | Move to `useMemo` or outside component |
| Inline style objects `style={{ color: 'red' }}` | New object reference on each render | Use CSS classes or `useMemo` |
| Inline arrow functions as event handlers | New reference breaks `React.memo` | Use `useCallback` |
| `useCallback` without memoized children | No benefit — only adds overhead | Remove `useCallback` |
| `useMemo` for cheap operations | Overhead exceeds savings | Remove `useMemo` |

## When to Optimize

Apply performance optimizations when profiling shows:
- A component re-renders more than expected in the React DevTools Profiler
- A computation takes >1ms (visible in the profiler flame chart)
- A list has >100 items and scroll performance degrades
- Route transitions are slow (large initial bundle)

## Best Practices

- Use **React DevTools Profiler** before adding any optimization
- Profile in production mode — development mode is intentionally slower
- Lazy-load routes by default in all new projects
- Virtualize any list that can grow beyond 100 items
- Keep `key` props stable and unique across the list
- Add `displayName` to components wrapped in `memo` or `forwardRef` for DevTools readability

---

### React state management patterns including Context API, Zustand, and TanStack Query for server state.
> Applies to: `**/*.tsx,**/*.ts`

# React State Management

How to choose and implement the right state management approach based on scope and data type.

## Purpose

State management decisions directly impact application performance and maintainability. The right choice depends on:
- **Scope**: local to a component vs. shared across the app
- **Data type**: UI state vs. server/async data
- **Update frequency**: rarely changed config vs. frequently updated counters

## Decision Guide

```
Is the state used by only one component?
  └─ YES → useState / useReducer (local state)

Is it UI state shared across a few components?
  └─ YES → Lift state up to nearest common ancestor

Is it global UI state (theme, auth, locale)?
  └─ YES → Context API + custom hook

Is it server data (fetched from an API)?
  └─ YES → TanStack Query (React Query)

Is it complex shared client state?
  └─ YES → Zustand
```

## Patterns

### Context API

Use Context for infrequently changing global state (theme, current user, locale). Do **not** use Context for high-frequency updates — it causes all consumers to re-render.

Create one context per concern; avoid a single mega-context.

#### Good

```tsx
// contexts/ThemeContext.tsx
import { createContext, useContext, useMemo, useState } from 'react';

type Theme = 'light' | 'dark';

interface ThemeContextValue {
  theme: Theme;
  toggleTheme: () => void;
}

const ThemeContext = createContext<ThemeContextValue | undefined>(undefined);

export const ThemeProvider = ({ children }: { children: React.ReactNode }) => {
  const [theme, setTheme] = useState<Theme>('light');

  // Memoize value to prevent unnecessary re-renders of all consumers
  const value = useMemo<ThemeContextValue>(
    () => ({ theme, toggleTheme: () => setTheme(t => t === 'light' ? 'dark' : 'light') }),
    [theme],
  );

  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
};

// Always export a typed hook — never let consumers call useContext directly
export const useTheme = (): ThemeContextValue => {
  const context = useContext(ThemeContext);
  if (!context) throw new Error('useTheme must be used within <ThemeProvider>');
  return context;
};
```

#### Bad

```tsx
// ❌ One mega context for everything — any update re-renders every consumer
const AppContext = createContext({
  user: null,
  theme: 'light',
  cart: [],
  notifications: [],
  // ...
});

// ❌ No invariant guard — silent undefined errors at runtime
export const useApp = () => useContext(AppContext);
```

---

### Zustand (Client State)

Use Zustand for shared client state that changes frequently or spans many components. Zustand avoids unnecessary re-renders by letting components subscribe to specific slices.

#### Good

```tsx
// stores/cart-store.ts
import { create } from 'zustand';

interface CartItem {
  id: string;
  name: string;
  quantity: number;
  price: number;
}

interface CartStore {
  items: CartItem[];
  addItem: (item: CartItem) => void;
  removeItem: (id: string) => void;
  clearCart: () => void;
  total: () => number;
}

export const useCartStore = create<CartStore>((set, get) => ({
  items: [],
  addItem: (item) =>
    set((state) => ({
      items: state.items.some(i => i.id === item.id)
        ? state.items.map(i => i.id === item.id ? { ...i, quantity: i.quantity + 1 } : i)
        : [...state.items, item],
    })),
  removeItem: (id) =>
    set((state) => ({ items: state.items.filter(i => i.id !== id) })),
  clearCart: () => set({ items: [] }),
  total: () => get().items.reduce((sum, item) => sum + item.price * item.quantity, 0),
}));

// Usage — subscribe to only what you need
const itemCount = useCartStore((state) => state.items.length);
const addItem = useCartStore((state) => state.addItem);
```

#### Bad

```tsx
// ❌ Subscribing to the entire store — component re-renders on every store change
const { items, addItem, removeItem, total } = useCartStore();
```

---

### TanStack Query (Server State)

Use TanStack Query for all server-fetched data. It handles caching, background refetching, pagination, and synchronization.

#### Good

```tsx
// hooks/use-user.ts
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';

export const useUser = (userId: string) =>
  useQuery({
    queryKey: ['users', userId],
    queryFn: () => api.fetchUser(userId),
    staleTime: 5 * 60 * 1000, // 5 minutes — don't refetch if data is fresh
  });

export const useUpdateUser = () => {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ id, data }: { id: string; data: Partial<User> }) =>
      api.updateUser(id, data),
    onSuccess: (updatedUser) => {
      // Invalidate and refetch after mutation
      queryClient.invalidateQueries({ queryKey: ['users', updatedUser.id] });
    },
  });
};

// Usage
const { data: user, isLoading, error } = useUser(userId);
const { mutate: updateUser } = useUpdateUser();
```

#### Bad

```tsx
// ❌ Manual fetch management — no caching, no background sync, no deduplication
const [user, setUser] = useState(null);
const [isLoading, setIsLoading] = useState(false);

useEffect(() => {
  setIsLoading(true);
  fetch(`/api/users/${userId}`)
    .then(r => r.json())
    .then(data => { setUser(data); setIsLoading(false); });
}, [userId]);
```

## Library Selection Guide

| Scenario | Recommended Solution |
|----------|---------------------|
| Local component state | `useState` / `useReducer` |
| Shared UI state (theme, locale, auth) | Context API |
| Server/async data | TanStack Query |
| Complex shared client state | Zustand |
| Large enterprise app with devtools | Redux Toolkit |

## Best Practices

- **Start local**: default to `useState` and only introduce a library when state genuinely needs to be shared
- Keep Context providers close to where they are needed — not always at the app root
- Split Zustand stores by domain (cart, auth, ui) rather than having one global store
- Always set `staleTime` in TanStack Query — the default of 0 causes excessive refetching
- Never store server data in Zustand or Context alongside TanStack Query — let TQ own the cache
- Avoid storing derived values in state — compute them during render or with `useMemo`

## Common Mistakes

- Using Context for frequently updated state (causes app-wide re-renders)
- Storing remote API data in `useState` instead of TanStack Query
- Subscribing to the full Zustand store (use selectors to subscribe to slices)
- Forgetting to memoize Context value with `useMemo` (causes all consumers to re-render on every parent render)

---

### React testing patterns using React Testing Library and Jest including component tests, hook tests, and mocking strategies.
> Applies to: `**/*.test.tsx,**/*.spec.tsx,**/*.test.ts`

# React Testing Standards

How to write maintainable React tests that validate behavior from the user's perspective using React Testing Library and Jest.

## Purpose

Tests should verify what the user experiences, not implementation details. This approach:
- Makes tests resilient to refactoring (internals can change without breaking tests)
- Catches real regressions in user-facing behavior
- Documents how components are expected to be used

## Test Structure

Follow the **Arrange-Act-Assert** (AAA) pattern consistently across all test files.

```
describe('ComponentName', () => {
  describe('methodName or scenario', () => {
    it('should <expected behavior> when <condition>', async () => {
      // Arrange — set up data and render
      // Act — perform user interaction
      // Assert — verify outcome
    });
  });
});
```

## Patterns

### Component Tests

#### Good

```tsx
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { UserCard } from './UserCard';

describe('UserCard', () => {
  describe('when rendered with user data', () => {
    it('should display the user name and email', () => {
      // Arrange
      render(<UserCard id="1" name="Alice" email="alice@example.com" />);

      // Assert
      expect(screen.getByText('Alice')).toBeInTheDocument();
      expect(screen.getByText('alice@example.com')).toBeInTheDocument();
    });
  });

  describe('when user selects the card', () => {
    it('should call onSelect with the user id', async () => {
      // Arrange
      const handleSelect = jest.fn();
      const user = userEvent.setup();
      render(<UserCard id="1" name="Alice" email="alice@example.com" onSelect={handleSelect} />);

      // Act
      await user.click(screen.getByRole('button', { name: /alice/i }));

      // Assert
      expect(handleSelect).toHaveBeenCalledWith('1');
      expect(handleSelect).toHaveBeenCalledTimes(1);
    });
  });

  describe('when avatarUrl is not provided', () => {
    it('should not render an image', () => {
      render(<UserCard id="1" name="Alice" email="alice@example.com" />);

      expect(screen.queryByRole('img')).not.toBeInTheDocument();
    });
  });
});
```

#### Bad

```tsx
// ❌ Testing implementation details — breaks on refactor
it('should set isSelected state to true when clicked', () => {
  const wrapper = shallow(<UserCard id="1" name="Alice" />);
  wrapper.instance().handleClick();
  expect(wrapper.state('isSelected')).toBe(true); // testing internal state
});

// ❌ Using fireEvent instead of userEvent — does not simulate real user behavior
fireEvent.click(button);

// ❌ Using getByTestId when semantic queries exist
screen.getByTestId('user-name'); // prefer getByText or getByRole
```

---

### Query Priority

Use queries in this order of preference (most semantic → least semantic):

```tsx
// 1. By role (preferred — reflects accessible UI)
screen.getByRole('button', { name: /submit/i });
screen.getByRole('heading', { name: /user profile/i });
screen.getByRole('textbox', { name: /email/i });

// 2. By label text (for form inputs)
screen.getByLabelText('Email address');

// 3. By placeholder text
screen.getByPlaceholderText('Enter your email');

// 4. By text content
screen.getByText('Submit');

// 5. By test ID (last resort — use only if no semantic query works)
screen.getByTestId('custom-widget');
```

---

### Async Testing

Always use `await` with `userEvent` interactions. Use `findBy` queries for elements that appear asynchronously.

#### Good

```tsx
it('should display user data after loading', async () => {
  // Arrange
  jest.mocked(api.fetchUser).mockResolvedValue({ id: '1', name: 'Alice' });
  render(<UserProfile userId="1" />);

  // Assert loading state
  expect(screen.getByText(/loading/i)).toBeInTheDocument();

  // Assert resolved state
  expect(await screen.findByText('Alice')).toBeInTheDocument();
  expect(screen.queryByText(/loading/i)).not.toBeInTheDocument();
});

it('should show error message when fetch fails', async () => {
  jest.mocked(api.fetchUser).mockRejectedValue(new Error('Not found'));
  render(<UserProfile userId="1" />);

  expect(await screen.findByText(/something went wrong/i)).toBeInTheDocument();
});
```

---

### Hook Testing

Use `renderHook` and `act` from `@testing-library/react` to test custom hooks.

#### Good

```tsx
import { renderHook, act } from '@testing-library/react';
import { useCounter } from './useCounter';

describe('useCounter', () => {
  it('should initialize with the given value', () => {
    const { result } = renderHook(() => useCounter(5));
    expect(result.current.count).toBe(5);
  });

  it('should increment the count', () => {
    const { result } = renderHook(() => useCounter(0));

    act(() => {
      result.current.increment();
    });

    expect(result.current.count).toBe(1);
  });

  it('should reset to the initial value', () => {
    const { result } = renderHook(() => useCounter(10));

    act(() => {
      result.current.increment();
      result.current.reset();
    });

    expect(result.current.count).toBe(10);
  });
});
```

---

### Mocking

Mock at the module level. Prefer `jest.mocked()` for type-safe access to mock functions.

#### Good

```tsx
// Mock API module
jest.mock('@/services/api', () => ({
  fetchUser: jest.fn(),
  updateUser: jest.fn(),
}));

import { fetchUser } from '@/services/api';

beforeEach(() => {
  jest.clearAllMocks();
});

it('should call fetchUser with the correct id', async () => {
  jest.mocked(fetchUser).mockResolvedValue({ id: '1', name: 'Alice' });

  render(<UserProfile userId="1" />);
  await screen.findByText('Alice');

  expect(fetchUser).toHaveBeenCalledWith('1');
});
```

#### Bad

```tsx
// ❌ Mocking implementation details
jest.spyOn(UserProfile.prototype, 'componentDidMount');

// ❌ Not clearing mocks — test pollution
// (missing beforeEach(() => jest.clearAllMocks()))
```

---

### jest-dom Matchers

Use `@testing-library/jest-dom` matchers for readable assertions:

```tsx
import '@testing-library/jest-dom';

expect(button).toBeInTheDocument();
expect(button).toBeDisabled();
expect(button).toBeEnabled();
expect(button).toBeVisible();
expect(input).toHaveValue('alice@example.com');
expect(element).toHaveClass('active');
expect(element).toHaveTextContent('Submit');
expect(element).toHaveAttribute('aria-expanded', 'true');
expect(element).toHaveFocus();
```

## Jest Configuration

```js
// jest.config.js
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'jsdom',
  setupFilesAfterFramework: ['<rootDir>/src/setupTests.ts'],
  moduleNameMapper: {
    '^@/(.*)$': '<rootDir>/src/$1',
  },
  collectCoverageFrom: [
    'src/**/*.{ts,tsx}',
    '!src/**/*.d.ts',
    '!src/index.tsx',
    '!src/**/*.stories.tsx',
  ],
};

// src/setupTests.ts
import '@testing-library/jest-dom';
global.fetch = jest.fn();
```

## Best Practices

- Use `userEvent` (not `fireEvent`) — it simulates full browser events including focus, keyboard, etc.
- Always `await` async interactions: `await user.click(button)`
- Use `findBy` for elements that appear after async operations; `getBy` for immediate elements
- Do not use `waitFor` for simple async queries — prefer `findBy`
- Wrap state updates in `act` when testing hooks directly
- Mock at the boundary (API layer) not at internal function level
- Run tests with `--coverage` in CI to catch untested paths

## What to Test

| Test | Example |
|------|---------|
| Renders correctly with props | Title, description, image shown |
| User interactions | Click, type, submit |
| Loading states | Spinner visible while fetching |
| Error states | Error message shown on failure |
| Conditional rendering | Element absent when prop not provided |
| Accessibility | Correct ARIA roles and labels |

## What NOT to Test

- CSS class names or styles (implementation detail)
- Internal component state (test behavior, not state)
- Third-party library behavior
- React lifecycle method calls

---

### TypeScript integration patterns for React including component typing, generics, and type utilities.
> Applies to: `**/*.tsx,**/*.ts`

# React TypeScript Integration

How to write type-safe React components, hooks, and utilities using TypeScript best practices.

## Purpose

Strong typing in React:
- Catches prop mismatches and missing required values at compile time
- Provides IDE autocomplete for component APIs
- Documents the contract between components without separate docs

## TypeScript Configuration

Enable strict mode in `tsconfig.json`:

```json
{
  "compilerOptions": {
    "strict": true,
    "noImplicitAny": true,
    "strictNullChecks": true,
    "noImplicitReturns": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "moduleResolution": "bundler",
    "jsx": "react-jsx",
    "baseUrl": ".",
    "paths": {
      "@/*": ["src/*"]
    }
  }
}
```

## Patterns

### Component Props

Define a dedicated interface for every component's props. Use `interface` over `type` for component props (better error messages, supports declaration merging).

#### Good

```tsx
interface UserCardProps {
  id: string;
  name: string;
  email: string;
  avatarUrl?: string;
  onSelect?: (id: string) => void;
}

export const UserCard = ({ id, name, email, avatarUrl, onSelect }: UserCardProps) => (
  <div onClick={() => onSelect?.(id)}>
    {avatarUrl && <img src={avatarUrl} alt={name} />}
    <h3>{name}</h3>
    <p>{email}</p>
  </div>
);
```

#### Bad

```tsx
// ❌ Inline object type — not reusable, no name for error messages
const UserCard = ({ id, name, email }: { id: any; name: any; email: any }) => (
  <div>{name}</div>
);
```

---

### Extending HTML Element Props

When building primitive UI components (Button, Input), extend the underlying HTML element's props to pass through native attributes.

#### Good

```tsx
interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'danger';
  size?: 'sm' | 'md' | 'lg';
  isLoading?: boolean;
}

export const Button = ({ variant = 'primary', size = 'md', isLoading, children, ...rest }: ButtonProps) => (
  <button
    className={`btn btn-${variant} btn-${size}`}
    disabled={isLoading || rest.disabled}
    {...rest}
  >
    {isLoading ? <Spinner /> : children}
  </button>
);
```

---

### forwardRef

Use `React.forwardRef` when the component wraps a DOM element that consumers may need to control directly (focus, scroll, etc.).

#### Good

```tsx
interface InputProps extends React.InputHTMLAttributes<HTMLInputElement> {
  label: string;
  error?: string;
}

export const Input = React.forwardRef<HTMLInputElement, InputProps>(
  ({ label, error, ...props }, ref) => (
    <div>
      <label htmlFor={props.id}>{label}</label>
      <input ref={ref} aria-invalid={!!error} {...props} />
      {error && <span className="error">{error}</span>}
    </div>
  ),
);

Input.displayName = 'Input'; // Required for devtools when using forwardRef
```

---

### Generic Components

Use generics for components that work with different data types (lists, selects, tables).

#### Good

```tsx
interface SelectProps<T> {
  options: T[];
  value: T | null;
  getOptionLabel: (option: T) => string;
  getOptionValue: (option: T) => string;
  onChange: (value: T | null) => void;
  placeholder?: string;
}

export const Select = <T,>({
  options,
  value,
  getOptionLabel,
  getOptionValue,
  onChange,
  placeholder,
}: SelectProps<T>) => (
  <select
    value={value ? getOptionValue(value) : ''}
    onChange={(e) => onChange(options.find(o => getOptionValue(o) === e.target.value) ?? null)}
  >
    {placeholder && <option value="">{placeholder}</option>}
    {options.map((option) => (
      <option key={getOptionValue(option)} value={getOptionValue(option)}>
        {getOptionLabel(option)}
      </option>
    ))}
  </select>
);

// Usage — TypeScript infers T as User
<Select<User>
  options={users}
  value={selectedUser}
  getOptionLabel={(u) => u.name}
  getOptionValue={(u) => u.id}
  onChange={setSelectedUser}
/>
```

---

### API Response Types

Define typed interfaces for all API responses in `src/types/`. Never use `any` for API data.

#### Good

```tsx
// types/api.ts
export interface ApiResponse<T> {
  data: T;
  meta: {
    total: number;
    page: number;
    pageSize: number;
  };
}

export interface User {
  id: string;
  name: string;
  email: string;
  role: 'admin' | 'member' | 'viewer';
  createdAt: string;
}

export type CreateUserDto = Omit<User, 'id' | 'createdAt'>;
export type UpdateUserDto = Partial<CreateUserDto>;

// services/user-service.ts
export const fetchUsers = async (): Promise<ApiResponse<User[]>> => {
  const response = await fetch('/api/users');
  return response.json() as Promise<ApiResponse<User[]>>;
};
```

#### Bad

```tsx
// ❌ any defeats the purpose of TypeScript
const fetchUsers = async (): Promise<any> => {
  const response = await fetch('/api/users');
  return response.json();
};
```

---

### Typing Hooks

Explicitly type the return value of custom hooks that return multiple values.

#### Good

```tsx
interface UseCounterReturn {
  count: number;
  increment: () => void;
  decrement: () => void;
  reset: () => void;
}

export const useCounter = (initialValue = 0): UseCounterReturn => {
  const [count, setCount] = useState(initialValue);

  return {
    count,
    increment: useCallback(() => setCount(c => c + 1), []),
    decrement: useCallback(() => setCount(c => c - 1), []),
    reset: useCallback(() => setCount(initialValue), [initialValue]),
  };
};
```

## React Type Utilities

| Utility | Use case |
|---------|----------|
| `React.ReactNode` | Component `children` prop type |
| `React.ReactElement` | A single React element (not null/string) |
| `React.CSSProperties` | Inline `style` prop objects |
| `React.ComponentProps<typeof C>` | Extract props from an existing component |
| `React.PropsWithChildren<Props>` | Add `children` to an existing props interface |
| `React.RefObject<T>` | Typed ref from `useRef` |
| `React.EventHandler<E>` | Generic event handler type |
| `React.ChangeEvent<HTMLInputElement>` | Input `onChange` event |

## Best Practices

- Never use `any` — use `unknown` if the type is genuinely unknown, then narrow
- Prefer `interface` over `type` for component props and object shapes
- Use `type` for union types, mapped types, and utility types
- Do not use `React.FC` as it adds an implicit `children` prop — type props explicitly
- Use TypeScript path aliases (`@/`) to avoid long relative import chains
- Export prop interfaces alongside components so consumers can extend them
- Use `as const` for string literal arrays to infer narrow literal types

## Common Mistakes

- Using `object` or `{}` instead of a specific interface
- Casting with `as` to silence type errors instead of fixing the root cause
- Not typing async function return values (TypeScript infers `Promise<any>`)
- Using `React.FC` without realizing it adds implicit `children: ReactNode`
- Forgetting `displayName` on components wrapped with `forwardRef` or `memo`

---
