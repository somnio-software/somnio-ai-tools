---
description: Dart API design — Effective Dart Design guide; naming that reads like a sentence, to___()/as___() conventions, private-by-default declarations, class modifiers (final/base/interface/sealed), getters vs setters, final fields, type annotation rules & inference, no bare dynamic, Future<void> for value-less async, parameter design (no positional booleans, inclusive-start/exclusive-end ranges), == and hashCode together. Applies to all .dart files.
globs: **/*.dart
alwaysApply: false
---

## Best Practices

Every rule below is taken from the official Effective Dart **Design** guide — the consistency and usability of a library's public API.
Source: https://dart.dev/effective-dart/design

Design rules apply hardest at the public API surface of a package or module. Inside private implementation, use judgement.

### Names

#### DO use terms consistently

One concept, one word, everywhere. If it is `pageCount` in one class, it is not `numPages` in the next.

#### AVOID abbreviations

Unless the abbreviation is more common than the full word (`id`, `http`, `async`), spell it out.

```dart
// Good
pageCount, buildRectangles, IOStream, HttpRequest

// Bad
pgCnt, buildRects, InputOutputStream, HypertextTransferProtocolRequest
```

#### PREFER putting the most descriptive noun last

The last word is what the reader remembers.

```dart
// Good
pageCount             // a count
ConversionSink        // a sink
InputStream           // a stream

// Bad
numPages              // not a "pages"
ChunkedConversionSink // not a "conversion sink"
```

#### CONSIDER making the code read like a sentence

```dart
// Good
if (errors.isEmpty) ...
subscription.cancel();
monsters.where((monster) => monster.hasClaws);

// Bad
if (errors.empty) ...
subscription.cancelled = true;
monsters.filter((monster) => monster.clawCount > 0);
```

#### Naming shape by declaration kind

| Declaration | Shape | Example |
|---|---|---|
| Non-boolean property or variable | Noun phrase | `list.length`, `context.lineWidth` |
| Boolean property or variable | Non-imperative verb phrase, positive form | `isEmpty`, `hasElements`, `canClose` |
| Named boolean parameter | Often the verb can be omitted | `Isolate.spawn(entryPoint, message, paused: false)` |
| Function/method whose purpose is a side effect | Imperative verb phrase | `list.add(element)`, `queue.removeFirst()` |
| Function/method whose purpose is returning a value | Noun phrase or non-imperative verb phrase | `list.elementAt(3)`, `string.endsWith('!')` |
| Copies state into a new object | `to___()` | `list.toSet()`, `duration.toString()` |
| Returns a different *view* backed by the original | `as___()` | `list.asMap()`, `bytes.asUint8List()` |

Relevant rules: *PREFER a noun phrase for a non-boolean property or variable* · *PREFER a non-imperative verb phrase for a boolean property or variable* · *CONSIDER omitting the verb for a named boolean parameter* · *PREFER the "positive" name for a boolean property or variable* · *PREFER an imperative verb phrase for a function or method whose main purpose is a side effect* · *PREFER a noun phrase or non-imperative verb phrase for a function or method if returning a value is its primary purpose* · *CONSIDER an imperative verb phrase for a function or method if you want to draw attention to the work it performs* · *PREFER naming a method `to___()` if it copies the object's state to a new object* · *PREFER naming a method `as___()` if it returns a different representation backed by the original object*.

Prefer the positive form: `isEnabled`, not `isDisabled`; `isEmpty`, not `isNotEmpty` as the primary definition.

#### AVOID starting a function or method name with get

A getter should be a getter. If it has to be a method (it is expensive, it has side effects, it can fail), name it for what it does.

```dart
// Good
int get length => ...
Future<Manifest> fetchManifest() => ...

// Bad
int getLength() => ...
Future<Manifest> getManifest() => ...
```

#### AVOID describing the parameters in the function's or method's name

The signature already shows the parameters.

```dart
// Good
list.add(element);
map.remove(key);

// Bad
list.addElement(element);
map.removeKey(key);
```

#### DO follow existing mnemonic conventions when naming type parameters

`E` for element, `K`/`V` for key/value, `R` for return type, `T`/`S`/`U`/`V` for a generic single type.

```dart
// Good
class Cache<T> {}
class IterableBase<E> {}
class MapEntry<K, V> {}
```

### Libraries

#### PREFER making declarations private

Private by default. A declaration is public only when a consumer outside the library needs it — the public surface is what you are committing to maintain.

#### CONSIDER declaring multiple classes in the same library

Dart privacy is per-library, not per-class. Classes that need access to each other's internals belong in one file; one-class-per-file is not a Dart convention.

### Classes and mixins

#### AVOID defining a one-member abstract class when a simple function will do

Dart has first-class functions. A `Predicate` interface with a single `call` method is a function type in disguise.

```dart
// Good
typedef Predicate<E> = bool Function(E element);

// Bad
abstract class Predicate<E> {
  bool test(E element);
}
```

#### AVOID defining a class that contains only static members

Dart supports top-level functions and variables. A class used only as a namespace is Java habit.

```dart
// Good — top level, in a library
const defaultTimeout = Duration(seconds: 30);
int parseInt(String source) => ...

// Bad
class Utils {
  static const defaultTimeout = Duration(seconds: 30);
  static int parseInt(String source) => ...
}
```

#### AVOID extending a class that isn't intended to be subclassed

#### DO use class modifiers to control if your class can be extended

#### AVOID implementing a class that isn't intended to be an interface

#### DO use class modifiers to control if your class can be an interface

Be explicit about the contract you are offering. Dart 3's class modifiers make it a compile-time guarantee rather than a doc comment.

| Modifier | Meaning |
|---|---|
| *(none)* | Can be constructed, extended, and implemented |
| `final` | Cannot be extended or implemented outside its library — safe to add members later |
| `base` | Can be extended but not implemented — every subtype inherits the implementation |
| `interface` | Can be implemented but not extended outside its library |
| `sealed` | Cannot be extended or implemented outside its library, and subtypes are known — enables exhaustive `switch` |
| `abstract` | Cannot be constructed directly |

```dart
// Good — the intent is explicit and enforced
final class HttpClient { ... }              // closed for subtyping
interface class Codec { ... }               // implement, don't extend
sealed class Result<T> {}                   // exhaustive switch over subtypes
final class Ok<T> extends Result<T> { ... }
final class Err<T> extends Result<T> { ... }

// Bad
class HttpClient { ... }                    // silently a public superclass
```

Source: https://dart.dev/language/class-modifiers

#### PREFER defining a pure mixin or pure class to a mixin class

If a type is meant to be mixed in, declare it `mixin`. If it is meant to be constructed, declare it `class`. `mixin class` exists for migration, not for new code.

### Constructors

#### CONSIDER making your constructor const if the class supports it

A `const` constructor lets callers create canonicalised compile-time constants. Note that adding one is a commitment — removing it later is a breaking change.

```dart
// Good
class Point {
  const Point(this.x, this.y);
  final double x;
  final double y;
}
```

### Members

#### PREFER making fields and top-level variables final

Immutable state is easier to reason about, safe to share, and enables `const`. Use `var` only for state that genuinely changes.

#### DO use getters for operations that conceptually access properties

#### DO use setters for operations that conceptually change properties

A getter should have no user-visible side effects, should be fast, should not throw, and should return the same value if called twice. If any of those fail, make it a method.

#### DON'T define a setter without a corresponding getter

An asymmetric property is confusing. Use a method instead.

```dart
// Good
void setTimeout(Duration value) { ... }

// Bad
set timeout(Duration value) { ... }   // no matching getter
```

#### AVOID using runtime type tests to fake overloading

Dart has no overloading. A method that branches on `is` to accept several unrelated types is hard to document and to type. Provide separate named constructors or methods.

```dart
// Good
void addAll(Iterable<int> values) { ... }
void add(int value) { ... }

// Bad
void add(Object valueOrValues) {
  if (valueOrValues is int) { ... } else if (valueOrValues is Iterable) { ... }
}
```

#### AVOID public late final fields without initializers

A public `late final` without an initialiser exposes a field that throws if read too early and can be assigned exactly once from outside your control. Use a private `late final` with a public getter, or a nullable field.

#### AVOID returning nullable Future, Stream, and collection types

A `null` future, stream, or collection forces every caller to write a null check for a case that an empty value already covers.

```dart
// Good
Future<List<Order>> fetchOrders() async => [];     // empty, never null
Stream<Event> get events => const Stream.empty();

// Bad
Future<List<Order>>? fetchOrders() => null;
List<Order>? get orders => null;
```

#### AVOID returning this from methods just to enable a fluent interface

Cascades (`..`) already give you chaining, for every API, without the method having to opt in.

```dart
// Good
var buffer = StringBuffer()
  ..write('one')
  ..write('two');

// Bad
class Builder {
  Builder write(String s) { ...; return this; }
}
```

### Types

Dart infers types aggressively. The rules below are about when an explicit annotation *adds* information and when it is noise.

#### DO type annotate variables without initializers

```dart
// Good
List<AstNode> parameters;

// Bad
var parameters;   // inferred as dynamic
```

#### DO type annotate fields and top-level variables if the type isn't obvious

If the initialiser is a literal or a constructor call, inference is obvious and the annotation is redundant. If it is a function call whose return type you have to look up, annotate.

```dart
// Good
final Completer<String> completer = _createCompleter();
final items = <String>[];     // obvious

// Bad
final completer = _createCompleter();   // reader must go look
```

#### DON'T redundantly type annotate initialized local variables

```dart
// Good
var names = <String>[];

// Bad
List<String> names = <String>[];
```

#### DO annotate return types on function declarations

#### DO annotate parameter types on function declarations

```dart
// Good
String capitalize(String name) => ...

// Bad
capitalize(name) => ...
```

#### DON'T annotate inferred parameter types on function expressions

#### DON'T type annotate initializing formals

```dart
// Good
names.forEach((name) => print(name));
class Point { Point(this.x, this.y); double x, y; }

// Bad
names.forEach((String name) => print(name));
class Point { Point(double this.x, double this.y); double x, y; }
```

#### DO write type arguments on generic invocations that aren't inferred

#### DON'T write type arguments on generic invocations that are inferred

#### AVOID writing incomplete generic types

```dart
// Good
var completer = Completer<String>();     // nothing to infer from
var items = <String>['a', 'b'];
List<int> ints = [];                     // inferred from the annotation

// Bad
var completer = Completer();             // Completer<dynamic>
List<List> nested = [];                  // List<List<dynamic>>
```

#### DO annotate with dynamic instead of letting inference fail

When you genuinely want an untyped value, say so. Silence is ambiguous.

```dart
// Good
dynamic mergeJson(dynamic original, dynamic changes) => ...

// Bad
mergeJson(original, changes) => ...
```

#### AVOID using dynamic unless you want to disable static checking

`dynamic` turns off the type checker for every operation on that value. Prefer `Object?` when you mean "any value" and intend to test or cast it.

```dart
// Good
void log(Object? message) => print(message.toString());

// Bad
void log(dynamic message) => print(message.toString());
```

#### PREFER signatures in function type annotations

#### PREFER inline function types over typedefs

#### PREFER using function type syntax for parameters

#### DON'T use the legacy typedef syntax

```dart
// Good
void handle(void Function(Event) callback) { ... }
typedef Comparison<T> = int Function(T a, T b);

// Bad
void handle(Function callback) { ... }        // no signature
typedef int Comparison<T>(T a, T b);          // legacy syntax
```

#### DON'T specify a return type for a setter

```dart
// Good
set foo(Foo value) { ... }

// Bad
void set foo(Foo value) { ... }
```

#### DO use Future<void> as the return type of asynchronous members that do not produce values

#### AVOID using FutureOr<T> as a return type

`FutureOr<T>` in a return position forces every caller to handle both cases. Accept `FutureOr<T>` as a *parameter* (be liberal in what you accept), return a plain `Future<T>` (be strict in what you produce).

```dart
// Good
Future<void> flush() async { ... }
Future<int> compute(FutureOr<int> input) async => await input;

// Bad
Future flush() async { ... }                  // Future<dynamic>
FutureOr<int> compute(int input) => input;    // caller must branch
```

### Parameters

#### AVOID positional boolean parameters

A bare `true` at a call site is unreadable. Use a named parameter, or an enum when there are more than two states.

```dart
// Good
Task(sync: true);
listBox.setScrollPosition(ScrollPosition.top, animate: false);

// Bad
Task(true);
listBox.setScrollPosition(ScrollPosition.top, false);
```

#### AVOID optional positional parameters if the user may want to omit earlier parameters

Positional optionals can only be omitted from the right. If any middle one is skippable, use named parameters.

```dart
// Good
DateTime({int year, int month, int day, int hour});

// Bad
DateTime([int year, int month, int day, int hour]);   // can't skip month
```

#### AVOID mandatory parameters that accept a special "no argument" value

If `null` or `-1` means "not provided", the parameter should be optional.

```dart
// Good
String substring(int start, [int? end]);

// Bad
String substring(int start, int? end);   // callers must pass null
```

#### DO use inclusive start and exclusive end parameters to accept a range

Matches every range API in the core libraries, makes `end - start` the length, and makes empty ranges expressible.

```dart
// Good
List<E> sublist(int start, [int? end]);         // [start, end)
String substring(int start, [int? end]);
```

### Equality

#### DO override hashCode if you override ==

Objects that are `==` must have the same `hashCode`, or they break every `Set` and `Map`. Always change the two together.

```dart
// Good
class Point {
  const Point(this.x, this.y);
  final double x;
  final double y;

  @override
  bool operator ==(Object other) =>
      other is Point && x == other.x && y == other.y;

  @override
  int get hashCode => Object.hash(x, y);
}
```

Prefer `Object.hash(...)` / `Object.hashAll(...)` from `dart:core` over hand-rolled bit math. For value types with many fields, `package:equatable` or a `freezed`-generated class removes the boilerplate entirely.

#### DO make your == operator obey the mathematical rules of equality

Reflexive (`a == a`), symmetric (`a == b` implies `b == a`), transitive, and stable over time.

#### AVOID defining custom equality for mutable classes

If a field that participates in `==` changes while the object sits in a `Set` or is used as a `Map` key, the collection is silently corrupted. Custom equality belongs on immutable value types.

#### DON'T make the parameter to == nullable

The signature is `bool operator ==(Object other)`. `other` is never `null` — the language handles that before dispatching.

```dart
// Good
@override
bool operator ==(Object other) => other is Point && ...;

// Bad
@override
bool operator ==(Object? other) => other is Point && ...;
```
