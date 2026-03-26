---
description: 
globs: **/*_test.dart, **/test/**/*.dart
alwaysApply: false
---
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
