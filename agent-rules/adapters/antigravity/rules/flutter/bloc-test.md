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
