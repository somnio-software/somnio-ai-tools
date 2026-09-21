---
description: "Dart documentation — Effective Dart Documentation guide; /// doc comments over block comments, single-sentence summary in its own paragraph, third-person verbs for side-effecting functions, noun phrases for properties, \"Whether\" for booleans, square-bracket references, prose for parameters/returns/exceptions, doc comments before annotations, markdown restraint. Applies to all .dart files."
paths:
  - "**/*.dart"
---

## Rules

Every rule below is taken from the official Effective Dart **Documentation** guide.
Source: https://dart.dev/effective-dart/documentation

Generate and check the rendered output with `dart doc` before publishing a package.

### Comments

#### DO format comments like sentences

Capitalise the first word unless it is a case-sensitive identifier, and end with a period.

```dart
// Good
// Not if anything comes before it.
if (_chunks.isNotEmpty) return false;

// Bad
// not if anything comes before it
if (_chunks.isNotEmpty) return false;
```

#### DON'T use block comments for documentation

Use `//` for inline explanation and `///` for documentation. Reserve `/* ... */` for temporarily commenting out a block of code.

```dart
// Good
void greet(String name) {
  // Assume we have a valid name.
  print('Hi, $name!');
}

// Bad
void greet(String name) {
  /* Assume we have a valid name. */
  print('Hi, $name!');
}
```

### Doc comments

#### DO use /// doc comments to document members and types

`///` is the documentation syntax `dart doc` understands. `/** ... */` is legacy.

```dart
// Good
/// The number of characters in this chunk when unsplit.
int get length => ...

// Bad
/**
 * The number of characters in this chunk when unsplit.
 */
int get length => ...
```

#### PREFER writing doc comments for public APIs

Document every public class, constructor, method, getter/setter, top-level function, and top-level variable. You do not have to document every single one exhaustively, but anything a consumer will call should say what it does.

#### CONSIDER writing a library-level doc comment

A doc comment on the `library` directive is the front page of the library: what it is for, the most important types, and a short usage example.

```dart
/// A really great test library.
library;
```

#### CONSIDER writing doc comments for private APIs

Private members still have readers — the next maintainer, and you in six months.

#### DO start doc comments with a single-sentence summary

The first sentence is its own complete, user-centric description. It is what shows in search results and member lists.

```dart
// Good
/// Deletes the file at [path] from the file system.
void delete(String path) { ... }

// Bad
/// Depending on the state of the file system and the user's permissions,
/// certain operations may or may not be possible. If there is no file at
/// [path] or it can't be accessed, this function throws either [IOError]
/// or [PermissionError]...
void delete(String path) { ... }
```

#### DO separate the first sentence of a doc comment into its own paragraph

Add a blank `///` line after the summary. This is what splits the summary from the detail in generated docs.

```dart
// Good
/// Deletes the file at [path].
///
/// Throws an [IOError] if the file could not be found. Throws a
/// [PermissionError] if the file is present but could not be deleted.
void delete(String path) { ... }
```

#### AVOID redundancy with the surrounding context

The class name, the member name, the parameter types, and the return type are all already visible in the generated docs. Do not restate them.

```dart
// Good
class RadioButtonWidget {
  /// Sets the tooltip to [lines], which should have been word wrapped using
  /// the current font.
  void setTooltip(List<String> lines) { ... }
}

// Bad
class RadioButtonWidget {
  /// Sets the tooltip for this radio button widget to the list of strings in
  /// [lines].
  void setTooltip(List<String> lines) { ... }
}
```

#### Phrasing rules for the summary sentence

The guide is prescriptive about the grammatical shape of the first sentence. Follow the table:

| Declaration | Summary shape | Example |
|---|---|---|
| Function/method whose purpose is a **side effect** | Third-person imperative verb phrase | `/// Connects to the server and fetches the manifest.` |
| Function/method whose purpose is **returning a value** | Noun phrase or non-imperative verb phrase | `/// The number of active connections.` |
| Non-boolean variable or property | Noun phrase | `/// The current day of the week, where zero is Sunday.` |
| Boolean variable or property | "Whether" + noun or gerund phrase | `/// Whether the modal is currently displayed to the user.` |
| Library or type | Noun phrase | `/// A chunk of non-breaking output text terminated by a hard or soft newline.` |

Relevant rules: *PREFER starting comments of a function or method with third-person verbs if its main purpose is a side effect* · *PREFER a noun phrase or non-imperative verb phrase for a function or method if returning a value is its primary purpose* · *PREFER starting a non-boolean variable or property comment with a noun phrase* · *PREFER starting a boolean variable or property comment with "Whether" followed by a noun or gerund phrase* · *PREFER starting library or type comments with noun phrases*.

```dart
// Good
/// Starts the stopwatch if it isn't already running.
void start() { ... }

/// The lexeme for this token.
String get lexeme => ...

/// Whether this chunk is a block that can be further split.
bool get isBlock => ...

// Bad
/// Start the stopwatch.       <- imperative, not third person
void start() { ... }

/// Returns the lexeme.        <- redundant "Returns"
String get lexeme => ...

/// Is this chunk a block?     <- question form
bool get isBlock => ...
```

#### DON'T write documentation for both the getter and setter of a property

A property is one concept. Document the getter; leave the setter undocumented, or vice versa if the setter is the more interesting half.

#### CONSIDER including code samples in doc comments

A short example is worth several paragraphs of prose.

```dart
/// Returns the lesser of two numbers.
///
/// ```dart
/// min(5, 3) == 3
/// ```
num min(num a, num b) => ...
```

#### DO use square brackets in doc comments to refer to in-scope identifiers

`dart doc` turns `[identifier]` into a link. Use `[new Foo]` / `[Foo.named]` for constructors and `[Foo.bar]` to reach outside the current scope.

```dart
/// Throws a [StateError] if [Iterable.isEmpty] is true for [items].
/// Returns a new [Response] built from [request].
```

#### DO use prose to explain parameters, return values, and exceptions

Dart has no `@param`/`@returns` tags. Write sentences that reference the parameters with square brackets.

```dart
// Good
/// Defines a flag with the given [name] and [abbreviation].
///
/// The flag is [negatable] if it can be preceded by `no-`. Returns the new
/// flag. Throws an [ArgumentError] if a flag named [name] already exists.
Flag addFlag(String name, String abbreviation, {bool negatable = false}) { ... }
```

#### DO put doc comments before metadata annotations

```dart
// Good
/// A button that can be flipped on and off.
@Component(selector: 'toggle')
class ToggleComponent {}

// Bad
@Component(selector: 'toggle')
/// A button that can be flipped on and off.
class ToggleComponent {}
```

### Markdown

#### AVOID using markdown excessively

#### AVOID using HTML for formatting

#### PREFER backtick fences for code blocks

Use markdown for what it is good at — code spans, code fences, links, the occasional list. Do not build tables of contents, nested emphasis, or raw HTML into doc comments.

````dart
// Good
/// This is a paragraph of regular text.
///
/// ```dart
/// this.code(willBe, highlighted);
/// ```

// Bad
/// <p>This uses <strong>HTML</strong>.</p>
///
///     this.code(isIndented, notFenced);
````

### Writing

#### PREFER brevity

Clear and precise, then short.

#### AVOID abbreviations and acronyms unless they are obvious

Spell out "identifier", not "ident"; "regular expression" is fine as "regex", "database management system" is not fine as "DBMS".

#### PREFER using "this" instead of "the" to refer to a member's instance

```dart
// Good
/// Returns the index of [element] in this list.
int indexOf(T element) { ... }

// Bad
/// Returns the index of [element] in the list.
int indexOf(T element) { ... }
```
