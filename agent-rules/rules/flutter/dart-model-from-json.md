---
description: 
globs: 
alwaysApply: false
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
