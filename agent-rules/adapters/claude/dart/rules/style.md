---
description: "Dart style — Effective Dart Style guide; identifier casing (UpperCamelCase / lowerCamelCase / lowercase_with_underscores), acronyms, wildcards for unused params, import & export ordering (dart: → package: → relative, sorted), dart format as the single formatting authority, 80-column preference, curly braces on all flow control. Applies to all .dart files."
paths:
  - "**/*.dart"
---

## Rules

Every rule below is taken from the official Effective Dart **Style** guide.
Source: https://dart.dev/effective-dart/style

Effective Dart uses five directive strengths — **DO** (almost always), **DON'T** (almost never), **PREFER** (usually, exceptions exist), **AVOID** (rarely justified), **CONSIDER** (depends on the case). Treat DO/DON'T as non-negotiable in review; PREFER/AVOID need a stated reason to break; CONSIDER is a judgement call.

Two themes govern the whole guide: **be consistent** (arguments about casing and formatting are subjective, consistency is objectively useful) and **be brief** (pick the most concise phrasing — economical code, not dense code).

### Identifiers

Dart has exactly three identifier flavours. Pick by the kind of declaration, never by personal taste.

| Flavour | Used for |
|---|---|
| `UpperCamelCase` | Classes, enums, typedefs, extensions, type parameters, enum values |
| `lowercase_with_underscores` | Packages, directories, source files, import prefixes |
| `lowerCamelCase` | Everything else: members, top-level definitions, variables, parameters, constants |

#### DO name types using UpperCamelCase

Classes, enum types, typedefs, and type parameters capitalise the first letter of each word, including the first, and use no separators.

```dart
// Good
class SlyStrategy {}
typedef Predicate<T> = bool Function(T value);
enum ConnectionState { connecting, connected, disconnected }

// Bad
class sly_strategy {}
typedef predicate<T> = bool Function(T value);
```

#### DO name extensions using UpperCamelCase

```dart
// Good
extension MyFancyList<T> on List<T> { /* ... */ }
extension SmartIterable<T> on Iterable<T> { /* ... */ }

// Bad
extension my_fancy_list<T> on List<T> { /* ... */ }
```

#### DO name packages, directories, and source files using lowercase_with_underscores

```
// Good
my_package/
  lib/
    file_system.dart
    slider_menu.dart

// Bad
myPackage/
  lib/
    SliderMenu.dart
    file-system.dart
```

#### DO name import prefixes using lowercase_with_underscores

```dart
// Good
import 'dart:math' as math;
import 'package:angular_components/angular_components.dart' as angular_components;

// Bad
import 'dart:math' as Math;
import 'package:angular_components/angular_components.dart' as angularComponents;
```

#### DO name other identifiers using lowerCamelCase

Class members, top-level definitions, variables, parameters, and named parameters capitalise every word *except* the first.

```dart
// Good
var count = 3;
HttpRequest httpRequest;
void align(bool clearItems) {}

// Bad
var Count = 3;
void Align(bool clear_items) {}
```

#### PREFER using lowerCamelCase for constant names

This includes enum values, `const` variables, and `static const` fields. `SCREAMING_CAPS` is legacy style — do not introduce it in new code.

```dart
// Good
const pi = 3.14;
const defaultTimeout = 1000;
final urlScheme = RegExp('^([a-z]+):');

class Dice {
  static final numberGenerator = Random();
}

// Bad
const PI = 3.14;
const DEFAULT_TIMEOUT = 1000;
```

#### DO capitalize acronyms and abbreviations longer than two letters like words

Capitalised acronyms are hard to read and ambiguous when stacked (`HTTPSFTP`). Two-letter *abbreviations* like `ID` and `Mr.` are capitalised, but two-letter *acronyms* like `IO` are still capitalised as acronyms.

```dart
// Good
class HttpConnection {}
class DBIOPort {}
class TvVcr {}
class MrRogers {}
var httpRequest = ...;
var uiHandler = ...;
var userId = ...;
Id id;

// Bad
class HTTPConnection {}
class DbIoPort {}
var hTTPRequest = ...;
var uIHandler = ...;
var userID = ...;
ID iD;
```

#### PREFER using wildcards for unused callback parameters

A parameter you do not use is named `_`. Multiple unused parameters can all be named `_` (in Dart 3.7+ wildcards are non-binding).

```dart
// Good
futureOfVoid.then((_) {
  print('Operation complete.');
});

// Bad
futureOfVoid.then((unusedValue) {
  print('Operation complete.');
});
```

#### DON'T use a leading underscore for identifiers that aren't private

A leading underscore means "library-private" in Dart. Local variables, parameters, and function parameters are already local — an underscore there adds confusion, not privacy.

```dart
// Good
void process(String value) {
  var buffer = StringBuffer();
}

// Bad
void process(String _value) {
  var _buffer = StringBuffer();
}
```

#### DON'T use prefix letters

Hungarian notation and similar prefixes exist to compensate for weak type systems. Dart's static types and tooling make them noise.

```dart
// Good
defaultTimeout

// Bad
kDefaultTimeout
```

#### DON'T explicitly name libraries

Omit the `library` directive's name. An unnamed `library` directive is still fine when you need to attach a library-level doc comment or annotation.

```dart
// Good
/// A really great test library.
@TestOn('browser')
library;

// Bad
library my_library;
```

### Ordering

Keep the prologue of every file in a fixed shape so diffs stay small and merges stay clean.

#### DO place dart: imports before other imports

#### DO place package: imports before relative imports

#### DO specify exports in a separate section after all imports

#### DO sort sections alphabetically

```dart
// Good
import 'dart:async';
import 'dart:collection';
import 'dart:html';

import 'package:bar/bar.dart';
import 'package:foo/foo.dart';

import 'a_relative_file.dart';
import 'util.dart';

export 'src/error.dart';

// Bad
import 'package:foo/foo.dart';
import 'dart:async';
export 'src/error.dart';
import 'util.dart';
```

### Formatting

#### DO format your code using dart format

`dart format` is the authority on whitespace. Formatting is not a review topic: if the formatter did it, it is correct.

```bash
dart format .              # format the whole project
dart format --output=none --set-exit-if-changed .   # CI gate
dart fix --apply           # apply automated lint fixes
dart analyze              # static analysis — must pass clean
```

Wire `dart format --set-exit-if-changed` and `dart analyze` into CI. Both must fail the build.

#### CONSIDER changing your code to make it more formatter-friendly

When the formatter produces something awkward, the usual cause is code that is doing too much on one line. Extract a local variable or a helper function instead of fighting the output.

#### PREFER lines 80 characters or fewer

Long lines usually signal a problem the formatter cannot fix. URLs in comments, long string literals, and generated code are legitimate exceptions.

#### DO use curly braces for all flow control statements

The one exception: an `if` with no `else` whose entire body fits on the same line.

```dart
// Good
if (isWeekDay) {
  print('Bike to work!');
} else {
  print('Go dancing or read a book!');
}

// Good — single-line if with no else
if (arg == null) return defaultValue;

// Bad
if (overflowChars != other.overflowChars)
  return overflowChars < other.overflowChars;
```

### Analyzer configuration

Enable a lint ruleset so these rules are machine-enforced rather than review-enforced.

```yaml
# analysis_options.yaml
include: package:lints/recommended.yaml   # or package:very_good_analysis/analysis_options.yaml

analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
  errors:
    todo: ignore
```

Source: https://dart.dev/tools/analysis · https://pub.dev/packages/lints
