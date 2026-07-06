---
name: dart-model-from-json
description: >-
  Generates Dart models from a JSON structure using json_annotation and equatable.
  Use this skill when the user provides a JSON object and wants the corresponding
  Dart model classes generated, or asks things like "generate a Dart model for
  this JSON", "create a model from this response", "dart model from json".
  Always use this skill when the user provides JSON and needs Dart model output.
---

# Dart Model from JSON

Generates **Dart model classes** from a JSON structure using `json_annotation` and `equatable`.

---

## Input

The user provides a JSON object — either as a code block or pasted inline. If no JSON is provided, ask for it before proceeding.

---

## Requirements

- Use `json_annotation` for JSON serialization
- Use `equatable` for value equality
- Include `copyWith` method
- Include `fromJson` and `toJson` methods
- Include `props` getter for equatable
- No `@immutable` decorator
- No documentation comments
- No `@JsonKey` annotations unless explicitly requested

---

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

---

## Field Type Mapping

| JSON type | Dart type |
|-----------|-----------|
| `string` | `String` |
| `number` (integer) | `int` |
| `number` (decimal) | `double` |
| `boolean` | `bool` |
| `null` or absent | nullable type (e.g., `String?`) |
| `array` of primitives | `List<Type>` |
| `array` of objects | `List<ClassName>` |
| `object` | separate class |

---

## Naming Conventions

- **Class names**: PascalCase
- **Field names**: camelCase
- **Required fields**: non-nullable with `required` keyword
- **Optional fields**: nullable with `?`

---

## Nested Object Rules

### When to create separate classes

- Always create a class for objects with multiple properties
- Always create a class for array items that are objects
- Use `List<String>`, `List<int>`, etc. for primitive arrays — no class needed

### Class name inference

| Context | Class name |
|---------|-----------|
| `address` field (object) | `Address` |
| `profile.preferences` (nested object) | `Preferences` |
| `orders[]` (array of objects) | `Order` |
| `orders[].items[]` (nested array) | `OrderItem` |

If context is unclear, ask the user for the desired class name.

---

## Output Format

Output each class as a separate code block labeled with the suggested filename:

**`user.dart`**
```dart
// ... User class
```

**`address.dart`**
```dart
// ... Address class
```

List all required classes in dependency order (leaf classes first, root last).

---

## Example

**Input JSON:**
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
    "zipCode": "10001"
  }
}
```

**Output:**

**`address.dart`**
```dart
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'address.g.dart';

@JsonSerializable()
class Address extends Equatable {
  Address({
    required this.street,
    required this.city,
    required this.zipCode,
  });

  final String street;
  final String city;
  final String zipCode;

  Address copyWith({
    String? street,
    String? city,
    String? zipCode,
  }) {
    return Address(
      street: street ?? this.street,
      city: city ?? this.city,
      zipCode: zipCode ?? this.zipCode,
    );
  }

  static Address fromJson(Map<String, dynamic> json) => _$AddressFromJson(json);
  Map<String, dynamic> toJson() => _$AddressToJson(this);

  @override
  List<Object?> get props => [street, city, zipCode];
}
```

**`user.dart`**
```dart
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

import 'address.dart';

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
  });

  final String id;
  final String name;
  final int age;
  final bool isActive;
  final List<String> tags;
  final Address address;

  User copyWith({
    String? id,
    String? name,
    int? age,
    bool? isActive,
    List<String>? tags,
    Address? address,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      age: age ?? this.age,
      isActive: isActive ?? this.isActive,
      tags: tags ?? this.tags,
      address: address ?? this.address,
    );
  }

  static User fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);

  @override
  List<Object?> get props => [id, name, age, isActive, tags, address];
}
```
