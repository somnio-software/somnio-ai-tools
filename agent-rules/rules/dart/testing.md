---
description: Dart testing with package:test — test/ mirroring lib/, group/test naming, Arrange-Act-Assert, one behaviour per test, matchers over raw booleans, setUp/tearDown, mocktail for doubles, async testing (expectLater, emitsInOrder, fakeAsync, throwsA), no logic in tests, coverage as a signal not a goal. Applies to Dart test files.
globs: **/*_test.dart, test/**/*.dart
alwaysApply: false
---

## Best Practices

Conventions for testing pure Dart packages (CLIs, servers, shared packages) with `package:test`. Flutter widget and bloc tests are covered by the `flutter` rules — this file assumes no Flutter dependency.
Source: https://dart.dev/tools/testing · https://pub.dev/packages/test · https://pub.dev/packages/mocktail

```bash
dart test                         # run everything
dart test test/parser_test.dart   # one file
dart test --coverage=coverage     # with coverage
dart test -n 'parses empty input' # by name
```

### Test file organisation

`test/` mirrors `lib/` one-to-one, and every test file ends in `_test.dart` — the runner only discovers files with that suffix.

```
// Good
lib/src/parser.dart          ->  test/src/parser_test.dart
lib/src/models/user.dart     ->  test/src/models/user_test.dart

// Bad
lib/src/parser.dart          ->  test/parser_tests.dart   (not discovered)
lib/src/models/user.dart     ->  test/user_test.dart      (flat structure)
```

Shared fixtures and builders live in `test/helpers/`, not in a `_test.dart` file.

### Structure: group and test

Use `group` for the unit under test and a nested `group` per method. Test descriptions complete the sentence started by their groups and describe behaviour, not implementation.

```dart
// Good
void main() {
  group('UserRepository', () {
    group('findByEmail', () {
      test('returns the user when the email exists', () { ... });
      test('returns null when no user matches', () { ... });
      test('throws a NetworkException when the request fails', () { ... });
    });
  });
}

// Bad
void main() {
  test('test1', () { ... });
  test('findByEmail works', () { ... });
  test('should return a user', () { ... });   // "should" adds nothing
}
```

### Arrange-Act-Assert, one behaviour per test

Every test has three visible phases and asserts exactly one behaviour. A test that needs "and" in its description is two tests.

```dart
// Good
test('returns null when no user matches', () async {
  // Arrange
  when(() => client.get(any())).thenAnswer((_) async => emptyResponse);
  final repository = UserRepository(client);

  // Act
  final result = await repository.findByEmail('nobody@example.com');

  // Assert
  expect(result, isNull);
});

// Bad — two behaviours, opaque failure
test('findByEmail', () async {
  expect(await repository.findByEmail('a@b.com'), isNotNull);
  expect(await repository.findByEmail('nope@b.com'), isNull);
});
```

### Use matchers, not raw booleans

A matcher failure tells you what was expected and what was received. `expect(x == y, isTrue)` tells you `false is not true`.

```dart
// Good
expect(list, isEmpty);
expect(list, hasLength(3));
expect(list, contains('a'));
expect(list, containsAllInOrder(['a', 'b']));
expect(user.name, equals('Ada'));
expect(value, isA<Failure>());
expect(number, closeTo(3.14, 0.01));

// Bad
expect(list.isEmpty, isTrue);
expect(list.length == 3, true);
expect(user.name == 'Ada', isTrue);
```

### setUp / tearDown

`setUp` runs before each test, giving every test a fresh instance. Never share mutable state across tests via top-level variables assigned once — order-dependent tests fail in confusing ways.

```dart
// Good
void main() {
  late MockHttpClient client;
  late UserRepository repository;

  setUp(() {
    client = MockHttpClient();
    repository = UserRepository(client);
  });

  tearDown(() => repository.dispose());
}

// Bad
void main() {
  final repository = UserRepository(MockHttpClient());  // shared across all tests
}
```

Use `setUpAll` / `tearDownAll` only for genuinely expensive, immutable setup.

### Test doubles with mocktail

`mocktail` needs no code generation and no `@GenerateMocks`. Register fallback values for any non-primitive type used with `any()`.

```dart
// Good
class MockHttpClient extends Mock implements HttpClient {}

void main() {
  setUpAll(() => registerFallbackValue(Uri.parse('https://example.com')));

  test('sends the request to the orders endpoint', () async {
    when(() => client.get(any())).thenAnswer((_) async => okResponse);

    await repository.fetchOrders();

    verify(() => client.get(Uri.parse('https://api.example.com/orders')))
        .called(1);
  });
}
```

Mock at the boundary you own — repositories, clients, data sources. Do not mock value objects, and do not mock the class under test.

### Asynchronous tests

Always `await` or return the future. An un-awaited expectation passes vacuously.

```dart
// Good
test('throws a NetworkException when the request fails', () async {
  when(() => client.get(any())).thenThrow(const SocketException('boom'));

  await expectLater(
    repository.fetchOrders(),
    throwsA(isA<NetworkException>()),
  );
});

test('emits loading then loaded', () {
  expect(
    controller.stream,
    emitsInOrder([isA<Loading>(), isA<Loaded>()]),
  );
  controller.load();
});

// Bad
test('throws', () {
  expect(repository.fetchOrders(), throwsA(isA<NetworkException>()));  // not awaited
});
```

For code that depends on timers or `Future.delayed`, use `package:fake_async` instead of real delays — `await Future.delayed(...)` in a test makes the suite slow and flaky.

### Don't put logic in tests

No `if`, no loops that build expectations, no computing the expected value with the same code being tested. Write the expected value literally. Use `test`'s own parametrisation instead of a `for` loop when the same assertion applies to several inputs.

```dart
// Good
for (final (input, expected) in [('1', 1), ('42', 42), ('-7', -7)]) {
  test('parses "$input" as $expected', () {
    expect(parseInt(input), expected);
  });
}

// Bad
test('parses ints', () {
  for (final input in inputs) {
    expect(parseInt(input), int.parse(input));   // same code under test
  }
});
```

### Test annotations

Use the runner's own annotations rather than commenting tests out.

```dart
@TestOn('vm')                       // file-level: VM only
library;

test('slow integration path', () { ... }, timeout: const Timeout(Duration(minutes: 2)));
test('pending fix for #431', () { ... }, skip: 'blocked on upstream bug #431');
test('flaky on CI', () { ... }, tags: ['flaky']);
```

Every `skip` carries a reason. A skipped test with no explanation is dead code.

### Coverage is a signal, not a goal

Set a `fail_under` gate in CI so coverage cannot silently regress, but read the report for *what* is untested — error branches, edge cases, and boundary conditions are where bugs live. 100% line coverage with no assertion on failure paths is worse than 70% with them.

```bash
dart test --coverage=coverage
dart pub global run coverage:format_coverage \
  --lcov --in=coverage --out=coverage/lcov.info --report-on=lib
```
