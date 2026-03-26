---
description: General architecture guidelines when using Flutter.
alwaysApply: false
---

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