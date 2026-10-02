---
description: Dart usage — Effective Dart Usage guide; library & part directives, null safety (no explicit null init, type promotion, late), string interpolation & adjacency, collection literals / isEmpty / whereType / no cast(), tear-offs, var vs final, concise constructors & initializing formals, error handling (on clauses, rethrow, Error vs Exception), asynchrony (async/await over raw futures, no pointless async, stream transforms, no Completer). Applies to all .dart files.
globs: **/*.dart
alwaysApply: false
---

## Best Practices

Every rule below is taken from the official Effective Dart **Usage** guide — how to use the language's features in statements and expressions.
Source: https://dart.dev/effective-dart/usage

### Libraries

#### DO use strings in part of directives

Name the parent library by its URI, not by a library name.

```dart
// Good — in my_library/src/utils.dart
part of '../my_library.dart';

// Bad
part of my_library;
```

#### DON'T import libraries that are inside the src directory of another package

`lib/src/` is private to its package. Only import a package's public `lib/` entrypoints; anything under `src/` can change without a breaking version bump.

```dart
// Good
import 'package:http/http.dart';

// Bad
import 'package:http/src/base_client.dart';
```

#### DON'T allow an import path to reach into or out of lib

Never use a relative path that climbs past `lib/`. Use a `package:` import to cross that boundary.

```dart
// Good — from lib/api/client.dart
import 'package:my_package/models/user.dart';

// Bad
import '../../lib/models/user.dart';
```

#### PREFER relative import paths

Within `lib/`, relative imports are shorter and survive a package rename.

```dart
// Good — in lib/api/client.dart
import '../models/user.dart';

// Bad — same package, unnecessarily absolute
import 'package:my_package/models/user.dart';
```

### Null

#### DON'T explicitly initialize variables to null

In sound null safety, an uninitialised nullable variable is already `null`.

```dart
// Good
Item? bestItem;

// Bad
Item? bestItem = null;
```

#### DON'T use an explicit default value of null

```dart
// Good
void error([String? message]) { ... }

// Bad
void error([String? message = null]) { ... }
```

#### DON'T use true or false in equality operations

```dart
// Good
if (nonNullableBool) { ... }
if (!nonNullableBool) { ... }
if (nullableBool ?? false) { ... }

// Bad
if (nonNullableBool == true) { ... }
if (nonNullableBool != false) { ... }
```

#### AVOID late variables if you need to check whether they are initialized

There is no way to ask a `late` variable whether it has been assigned, and reading it early throws. If you need that question answered, use a nullable field.

```dart
// Good
Subscription? _subscription;
bool get isListening => _subscription != null;

// Bad
late Subscription _subscription;  // no way to test initialization
```

#### CONSIDER type promotion or null-check patterns for using nullable types

Prefer promotion over `!`. Reserve `!` for cases where the non-nullness is genuinely guaranteed and unprovable to the analyzer.

```dart
// Good — promotion via local
final response = _response;
if (response != null) {
  print(response.body);      // promoted to non-nullable
}

// Good — null-check pattern (Dart 3)
if (_response case final response?) {
  print(response.body);
}

// Bad
print(_response!.body);
```

Note that a *field* does not promote — copy it into a local first, as above.

### Strings

#### DO use adjacent strings to concatenate string literals

```dart
// Good
raiseAlarm(
  'ERROR: Parts of the spaceship are on fire. Other '
  'parts are overrun by martians. Unclear which are which.',
);

// Bad
raiseAlarm(
  'ERROR: Parts of the spaceship are on fire. Other ' +
      'parts are overrun by martians. Unclear which are which.',
);
```

#### PREFER using interpolation to compose strings and values

```dart
// Good
'Hello, $name! You are ${year - birth} years old.';

// Bad
'Hello, ' + name + '! You are ' + (year - birth).toString() + ' years old.';
```

#### AVOID using curly braces in interpolation when not needed

```dart
// Good
'Hi, $name!';
'You have ${items.length} items.';   // braces needed: it's an expression
'Wear your wildest ${decade}s outfit.';  // braces needed: `s` would be part of the name

// Bad
'Hi, ${name}!';
```

### Collections

#### DO use collection literals when possible

Includes `if` and `for` inside literals and the spread operator.

```dart
// Good
var points = <Point>[];
var addresses = <String, Address>{};
var counts = <int>{};
var items = [
  ...defaults,
  if (isAdmin) adminItem,
  for (final id in ids) lookup(id),
];

// Bad
var points = List<Point>();
var addresses = Map<String, Address>();
```

#### DON'T use .length to see if a collection is empty

`length` can be O(n) on a lazy `Iterable`. `isEmpty` / `isNotEmpty` say what you mean.

```dart
// Good
if (lunchBox.isEmpty) return 'so hungry...';
if (words.isNotEmpty) return words.join(' ');

// Bad
if (lunchBox.length == 0) return 'so hungry...';
if (!words.isEmpty) return words.join(' ');
```

#### AVOID using Iterable.forEach() with a function literal

A `for-in` loop reads better and supports `break`, `continue`, and `await`.

```dart
// Good
for (final person in people) {
  print(person.name);
}

// Good — tear-off is fine
people.forEach(print);

// Bad
people.forEach((person) {
  print(person.name);
});
```

#### DON'T use List.from() unless you intend to change the type of the result

`toList()` preserves the element type; `List.from()` erases it to the inferred one.

```dart
// Good
var copy = iterable.toList();               // keeps List<int>
var ints = List<int>.from(numericIterable); // intentional downcast

// Bad
var copy = List.from(iterable);             // becomes List<dynamic>
```

#### DO use whereType() to filter a collection by type

```dart
// Good
var ints = objects.whereType<int>();

// Bad
var ints = objects.where((e) => e is int).cast<int>();
```

#### DON'T use cast() when a nearby operation will do

#### AVOID using cast()

`cast()` wraps the collection in a checked view, so every element access pays a runtime test and failures surface far from their cause. Create the collection with the right type instead.

```dart
// Good
var stringIds = <String>[for (final id in ids) id.toString()];

// Bad
var stringIds = ids.cast<String>();
```

### Functions

#### DO use a function declaration to bind a function to a name

```dart
// Good
void main() {
  void localFunction() { ... }
}

// Bad
void main() {
  var localFunction = () { ... };
}
```

#### DON'T create a lambda when a tear-off will do

```dart
// Good
names.forEach(print);
charCodes.map(String.fromCharCode);

// Bad
names.forEach((name) => print(name));
charCodes.map((code) => String.fromCharCode(code));
```

### Variables

#### DO follow a consistent rule for var and final on local variables

Pick one convention per project and apply it everywhere. The two common ones: `final` for locals that are never reassigned, or `var` for all locals. Either is acceptable — mixing them arbitrarily within a codebase is not. Type annotations on locals are optional when the initialiser makes the type obvious.

#### AVOID storing what you can calculate

Caching a derived value introduces a synchronisation bug waiting to happen. Compute it in a getter unless profiling proves the cost matters.

```dart
// Good
class Circle {
  Circle(this.radius);
  final double radius;
  double get area => pi * radius * radius;
}

// Bad
class Circle {
  Circle(this.radius) : area = pi * radius * radius;
  double radius;
  double area;   // stale as soon as radius changes
}
```

### Members

#### DON'T wrap a field in a getter and setter unnecessarily

Dart fields are already virtual — you can replace a field with a getter/setter pair later without breaking callers. Write the field.

```dart
// Good
class Box {
  var contents;
}

// Bad
class Box {
  var _contents;
  get contents => _contents;
  set contents(value) => _contents = value;
}
```

#### PREFER using a final field to make a read-only property

```dart
// Good
class Box {
  Box(this.contents);
  final Object contents;
}

// Bad
class Box {
  Box(this._contents);
  Object _contents;
  Object get contents => _contents;
}
```

#### CONSIDER using => for simple members

Use arrow syntax only when the body fits on one line. A `=>` that wraps across lines is harder to read than a block body.

```dart
// Good
double get area => (right - left) * (bottom - top);
bool isReady(int time) => minTime == null || minTime <= time;

// Bad — too long for one line
String capitalize(String name) => name.substring(0, 1).toUpperCase() + name.substring(1).toLowerCase();
```

#### DON'T use this. except to redirect to a named constructor or to avoid shadowing

```dart
// Good
class Box {
  Box(this.value);                            // initializing formal
  Box.empty() : this(const Object());         // redirect to a named constructor
  Object value;

  void update(Object value) {
    this.value = value;         // parameter shadows the field — this. is required
  }
}

// Bad
class Box {
  Object? value;
  void clear() {
    this.value = null;          // nothing is shadowed — this. is noise
  }
}
```

#### DO initialize fields at their declaration when possible

Avoids repeating the default in every constructor and lets the field be `final`.

```dart
// Good
class Folder {
  final String name;
  final List<Document> contents = [];
  Folder(this.name);
}

// Bad
class Folder {
  final String name;
  final List<Document> contents;
  Folder(this.name) : contents = [];
}
```

### Constructors

#### DO use initializing formals when possible

```dart
// Good
class Point {
  Point(this.x, this.y);
  double x, y;
}

// Bad
class Point {
  Point(double x, double y) {
    this.x = x;
    this.y = y;
  }
  double x, y;
}
```

#### DON'T use late when a constructor initializer list will do

#### DO use ; instead of {} for empty constructor bodies

```dart
// Good
class Point {
  Point(this.x, this.y);
  double x, y;
}

// Bad
class Point {
  Point(this.x, this.y) {}
  double x, y;
}
```

#### PREFER using concise constructor syntax

Initializing formals, super parameters, and initializer lists over assignments in a body.

```dart
// Good
class Child extends Parent {
  Child({required super.id, required this.name});
  final String name;
}

// Bad
class Child extends Parent {
  Child({required String id, required String name}) : super(id: id) {
    this.name = name;
  }
  late final String name;
}
```

#### DON'T use new

`new` is optional and adds nothing.

```dart
// Good
var widget = Widget();

// Bad
var widget = new Widget();
```

#### DON'T use const redundantly

Inside a context that is already constant — a const collection literal, a const constructor's arguments, a `const` variable initialiser, or a metadata annotation — `const` is implied.

```dart
// Good
const primaryColors = [
  Color('red', [255, 0, 0]),
  Color('green', [0, 255, 0]),
];

// Bad
const primaryColors = const [
  const Color('red', const [255, 0, 0]),
  const Color('green', const [0, 255, 0]),
];
```

### Error handling

Dart distinguishes **`Error`** (a programmatic bug — the caller used the API wrong) from **`Exception`** (a runtime condition the caller is expected to handle). The distinction drives the rules below.

#### AVOID catches without on clauses

A bare `catch` swallows everything, including `Error`s that indicate bugs.

```dart
// Good
try {
  somethingRisky();
} on FormatException catch (e) {
  handleFormatError(e);
}

// Bad
try {
  somethingRisky();
} catch (e) {
  // swallows StateError, TypeError, OutOfMemoryError, ...
}
```

#### DON'T discard errors from catches without on clauses

If you genuinely must catch everything (a top-level isolate guard, a request handler boundary), log it and rethrow or convert it. Never leave the block empty.

```dart
// Good
try {
  somethingRisky();
} catch (e, stackTrace) {
  log.severe('Unexpected failure', e, stackTrace);
  rethrow;
}

// Bad
try {
  somethingRisky();
} catch (e) {}
```

#### DO throw objects that implement Error only for programmatic errors

Throw `ArgumentError`, `StateError`, `RangeError`, or `UnsupportedError` when the *caller* made a mistake. Throw an `Exception` subtype for conditions the caller is meant to recover from.

```dart
// Good
void setAge(int age) {
  if (age < 0) throw ArgumentError.value(age, 'age', 'must not be negative');
  _age = age;
}

class PaymentDeclinedException implements Exception {
  const PaymentDeclinedException(this.reason);
  final String reason;
}
```

#### DON'T explicitly catch Error or types that implement it

An `Error` means the program is in a broken state. Fix the bug; do not catch it.

```dart
// Bad
try {
  parse(input);
} on TypeError {
  // hides a real bug
}
```

#### DO use rethrow to rethrow a caught exception

`rethrow` preserves the original stack trace; `throw e` resets it.

```dart
// Good
try {
  somethingRisky();
} on Exception catch (e) {
  if (!canHandle(e)) rethrow;
  handle(e);
}

// Bad
try {
  somethingRisky();
} on Exception catch (e) {
  if (!canHandle(e)) throw e;   // stack trace lost
  handle(e);
}
```

### Asynchrony

#### PREFER async/await over using raw futures

`async`/`await` gives you ordinary control flow, `try`/`catch`, and readable stack traces.

```dart
// Good
Future<int> countActivePlayers(String teamName) async {
  try {
    final team = await downloadTeam(teamName);
    if (team == null) return 0;
    final players = await team.roster;
    return players.where((p) => p.isActive).length;
  } on DownloadException catch (e, st) {
    log.error(e, st);
    return 0;
  }
}

// Bad
Future<int> countActivePlayers(String teamName) {
  return downloadTeam(teamName).then((team) {
    if (team == null) return Future.value(0);
    return team.roster.then((players) =>
        players.where((p) => p.isActive).length);
  }).catchError((e) => 0);
}
```

#### DON'T use async when it has no useful effect

If the body has no `await`, drop `async` — it only adds an extra microtask hop.

```dart
// Good
Future<int> fastOne() => Future.value(1);

// Bad
Future<int> fastOne() async => 1;
```

Keep `async` when you need it to convert a synchronous throw into a returned error future, or to keep a consistent async contract for subclass overrides.

#### CONSIDER using higher-order methods to transform a stream

```dart
// Good
var transformed = original.map(transformElement).where(isInteresting);

// Bad — manual controller plumbing
var controller = StreamController<Foo>();
original.listen((e) {
  final t = transformElement(e);
  if (isInteresting(t)) controller.add(t);
});
```

#### AVOID using Completer directly

`Completer` is a low-level primitive. Almost every case is better served by an `async` function or an existing `Future` combinator.

```dart
// Good
Future<bool> fileContainsBear(String path) async {
  final contents = await File(path).readAsString();
  return contents.contains('bear');
}

// Bad
Future<bool> fileContainsBear(String path) {
  final completer = Completer<bool>();
  File(path).readAsString().then((contents) {
    completer.complete(contents.contains('bear'));
  });
  return completer.future;
}
```

`Completer` is still the right tool when adapting a callback-based API that you do not control.

#### DO test for Future<T> when disambiguating a FutureOr<T> whose type argument could be Object

```dart
// Good
Future<T> logValue<T>(FutureOr<T> value) async {
  if (value is Future<T>) {
    final result = await value;
    print(result);
    return result;
  }
  print(value);
  return value;
}

// Bad
Future<T> logValue<T>(FutureOr<T> value) async {
  if (value is T) {          // a Future<Object> is also an Object
    print(value);
    return value;
  }
  ...
}
```

#### Never leave a future unawaited by accident

Use `await`, return it, or mark the fire-and-forget case explicitly with `unawaited()` from `dart:async` so the intent is readable and the `unawaited_futures` lint stays clean.

```dart
// Good
unawaited(analytics.track('checkout_started'));
await repository.save(order);

// Bad
analytics.track('checkout_started');   // silently dropped, errors vanish
repository.save(order);
```
