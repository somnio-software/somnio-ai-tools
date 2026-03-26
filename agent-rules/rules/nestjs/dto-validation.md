---
description: DTO structure with clear request/response naming, validation, transformation, and meaningful Swagger documentation.
globs: **/*.dto.ts
alwaysApply: false
---

# NestJS DTO Validation Standards

How to create robust, well-documented DTOs with clear naming conventions, proper validation, and meaningful documentation.

## Purpose

DTOs (Data Transfer Objects) define the shape of data exchanged between client and server. Proper DTOs ensure:
- Type safety at runtime through validation
- Automatic API documentation via Swagger
- Clean data transformation between layers
- Clear separation between request and response data

## DTO Naming Conventions

**Critical**: DTOs must clearly indicate whether they are for requests or responses.

| Type | Naming Pattern | File Pattern |
|------|----------------|--------------|
| Create Request | `CreateUserRequestDto` | `create-user-request.dto.ts` |
| Update Request | `UpdateUserRequestDto` | `update-user-request.dto.ts` |
| Query Parameters | `UserQueryDto` | `user-query.dto.ts` |
| Response | `UserResponseDto` | `user-response.dto.ts` |
| Detail Response | `UserDetailResponseDto` | `user-response.dto.ts` |
| List Response | `UserListResponseDto` | `user-response.dto.ts` |

## DTO Directory Structure

```
feature/
├── dto/
│   ├── user-request.dto.ts         # Create/Update request DTOs
│   ├── user-response.dto.ts        # Response DTOs (can have multiple)
│   ├── user-query.dto.ts           # Query parameters
│   └── index.ts                    # Barrel export
│
│   # For complex modules with many DTOs:
│   ├── request/
│   │   ├── create-user-request.dto.ts
│   │   ├── update-user-request.dto.ts
│   │   └── index.ts
│   ├── response/
│   │   ├── user-response.dto.ts
│   │   ├── user-detail-response.dto.ts
│   │   └── index.ts
│   └── index.ts
```

## Patterns

### Request DTO with Validation

#### Good

```typescript
// create-user-request.dto.ts
import { IsNotEmpty, IsString, IsEmail, MinLength, IsOptional, IsEnum } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateUserRequestDto {
  @ApiProperty({
    description: 'User email address for authentication and notifications',
    example: 'john.doe@company.com',
    format: 'email',
  })
  @IsNotEmpty()
  @IsEmail()
  readonly email: string;

  @ApiProperty({
    description: 'Secure password meeting complexity requirements',
    minLength: 8,
  })
  @IsNotEmpty()
  @IsString()
  @MinLength(8)
  readonly password: string;

  @ApiProperty({
    description: 'User display name shown in the interface',
    example: 'John Doe',
  })
  @IsNotEmpty()
  @IsString()
  readonly name: string;

  @ApiPropertyOptional({
    description: 'User role determining access permissions',
    enum: UserRole,
    default: UserRole.USER,
  })
  @IsOptional()
  @IsEnum(UserRole)
  readonly role?: UserRole = UserRole.USER;
}
```

#### Bad

```typescript
// No clear naming - is this request or response?
export class CreateUserDto {
  email: string;  // Missing validation
  password: string;  // Missing validation
  name: string;  // Missing validation
}

// Documentation that adds no value
export class CreateUserRequestDto {
  @ApiProperty({ description: 'Email' })  // Just restates the field name
  @IsEmail()
  email: string;

  @ApiProperty({ description: 'Password' })  // No useful information
  password: string;
}
```

### Response DTO with Transformation

Response DTOs control what data is exposed to clients.

#### Good

```typescript
// user-response.dto.ts
import { Expose, Exclude, Type } from 'class-transformer';
import { ApiProperty, ApiPropertyOptional, ApiHideProperty } from '@nestjs/swagger';

// Base response - essential fields only
@Exclude()  // Exclude all by default, explicitly expose fields
export class UserResponseDto {
  @Expose()
  @ApiProperty({ format: 'uuid' })
  readonly id: string;

  @Expose()
  @ApiProperty({ example: 'john.doe@company.com' })
  readonly email: string;

  @Expose()
  @ApiProperty({ example: 'John Doe' })
  readonly name: string;

  @Expose()
  @ApiProperty()
  @Type(() => Date)
  readonly createdAt: Date;

  // These fields are automatically excluded due to @Exclude() on class
  @ApiHideProperty()
  readonly password: string;

  @ApiHideProperty()
  readonly tenantId: string;
}

// Extended response with additional relations
export class UserDetailResponseDto extends UserResponseDto {
  @Expose()
  @ApiPropertyOptional()
  readonly dateOfBirth?: Date;

  @Expose()
  @ApiPropertyOptional({ type: [DepartmentResponseDto] })
  @Type(() => DepartmentResponseDto)
  readonly departments?: DepartmentResponseDto[];

  @Expose()
  @ApiPropertyOptional({ type: AddressResponseDto })
  @Type(() => AddressResponseDto)
  readonly address?: AddressResponseDto;
}

// Minimal response for lists and references
export class UserMinimalResponseDto {
  @Expose()
  @ApiProperty({ format: 'uuid' })
  readonly id: string;

  @Expose()
  @ApiProperty()
  readonly name: string;
}
```

#### Bad

```typescript
// Exposing sensitive data
export class UserResponseDto {
  id: string;
  email: string;
  password: string;  // Never expose passwords!
  hash: string;  // Never expose hashes!
  tenantId: string;  // Internal system field
}

// No transformation control
export class UserResponse {
  // Returns everything from database without filtering
}
```

### When to Use @ApiProperty vs @ApiPropertyOptional

| Decorator | Use When | Validation |
|-----------|----------|------------|
| `@ApiProperty()` | Field is required in the request/response | Pair with `@IsNotEmpty()` |
| `@ApiPropertyOptional()` | Field is optional | Pair with `@IsOptional()` |

#### Good

```typescript
export class CreateUserRequestDto {
  // Required field - must be provided
  @ApiProperty({ description: 'User email for authentication' })
  @IsNotEmpty()
  @IsEmail()
  readonly email: string;

  // Optional field - can be omitted
  @ApiPropertyOptional({
    description: 'Department assignment on creation',
    format: 'uuid',
  })
  @IsOptional()
  @IsUUID(4)
  readonly departmentId?: string;

  // Optional with default value
  @ApiPropertyOptional({
    description: 'User active status',
    default: true,
  })
  @IsOptional()
  @IsBoolean()
  readonly isActive?: boolean = true;
}
```

### Extending DTOs Instead of Duplicating

Use inheritance and utility types to avoid code duplication.

#### Good

```typescript
// Base create DTO
export class CreateAddressRequestDto {
  @ApiProperty()
  @IsString()
  readonly address: string;

  @ApiProperty()
  @IsString()
  readonly city: string;

  @ApiProperty()
  @IsString()
  readonly state: string;

  @ApiProperty()
  @IsString()
  readonly postalCode: string;
}

// Update DTO - all fields optional, inherits validation
export class UpdateAddressRequestDto extends PartialType(CreateAddressRequestDto) {
  @ApiPropertyOptional({ description: 'Address ID for updates' })
  @IsOptional()
  @IsString()
  readonly id?: string;
}

// Omit specific fields
export class UpdateProfileRequestDto extends PartialType(
  OmitType(CreateUserRequestDto, ['email', 'password'] as const),
) {}

// Pick specific fields
export class ChangeEmailRequestDto extends PickType(
  CreateUserRequestDto,
  ['email'] as const,
) {}
```

```typescript
// Response DTO inheritance
export class UserResponseDto {
  @Expose()
  @ApiProperty({ format: 'uuid' })
  readonly id: string;

  @Expose()
  @ApiProperty()
  readonly name: string;
}

// Extend for more details
export class UserDetailResponseDto extends UserResponseDto {
  @Expose()
  @ApiPropertyOptional({ type: [RoleResponseDto] })
  @Type(() => RoleResponseDto)
  readonly roles?: RoleResponseDto[];
}

// Extend for list views
export class UserListResponseDto extends UserResponseDto {
  @Expose()
  @ApiProperty()
  readonly departmentName: string;
}
```

#### Bad

```typescript
// Duplicating validation logic across DTOs
export class CreateUserRequestDto {
  @IsEmail() email: string;
  @IsString() @MinLength(8) password: string;
  @IsString() name: string;
}

export class UpdateUserRequestDto {
  // Duplicating everything with @IsOptional added
  @IsOptional() @IsEmail() email?: string;
  @IsOptional() @IsString() @MinLength(8) password?: string;
  @IsOptional() @IsString() name?: string;
}
```

### Nested Objects with Validation

#### Good

```typescript
export class AddressRequestDto {
  @ApiProperty()
  @IsNotEmpty()
  @IsString()
  readonly street: string;

  @ApiProperty()
  @IsNotEmpty()
  @IsString()
  readonly city: string;
}

export class CreateCompanyRequestDto {
  @ApiProperty()
  @IsNotEmpty()
  @IsString()
  readonly name: string;

  // Single nested object
  @ApiProperty({ type: AddressRequestDto })
  @ValidateNested()  // No { each: true } needed for single objects
  @Type(() => AddressRequestDto)
  readonly address: AddressRequestDto;

  // Array of nested objects
  @ApiProperty({ type: [AddressRequestDto] })
  @IsArray()
  @ValidateNested({ each: true })  // Note: { each: true } for arrays
  @Type(() => AddressRequestDto)
  readonly branches: AddressRequestDto[];
}
```

### Enum Documentation

#### Good

```typescript
export enum UserRole {
  ADMIN = 'admin',
  USER = 'user',
  GUEST = 'guest',
}

export class CreateUserRequestDto {
  @ApiProperty({
    enum: UserRole,
    enumName: 'UserRole',  // Generates named enum in Swagger
    description: 'User role determining access level',
    example: UserRole.USER,
  })
  @IsEnum(UserRole)
  readonly role: UserRole;
}
```

### Custom Validation with Meaningful Messages

#### Good

```typescript
export class CreateUserRequestDto {
  @ApiProperty({ description: 'User email for authentication' })
  @IsEmail({}, { message: 'Please provide a valid email address' })
  readonly email: string;

  @ApiProperty({ description: 'Password meeting security requirements' })
  @IsString({ message: 'Password must be a string' })
  @MinLength(8, { message: 'Password must be at least 8 characters' })
  @Matches(/^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)/, {
    message: 'Password must contain uppercase, lowercase, and number',
  })
  readonly password: string;
}
```

## Best Practices

- **Clear Naming**: Always suffix with `RequestDto` or `ResponseDto`
- **File Organization**: Group related DTOs, separate request/response for complex modules
- **Validation First**: Every request DTO field should have validation decorators
- **Meaningful Documentation**: `@ApiProperty` descriptions should add value, not restate field names
- **Use `readonly`**: All DTO properties should be immutable
- **Extend, Don't Duplicate**: Use `PartialType`, `OmitType`, `PickType` and class inheritance
- **Response Security**: Use `@Exclude()` on class and `@Expose()` on safe fields
- **Hide Internal Fields**: Use `@ApiHideProperty()` for fields not in Swagger
- **Nested Validation**: Always pair `@ValidateNested()` with `@Type()`
- **Array Validation**: Use `{ each: true }` option for array validation
- **Default Values**: Document defaults in `@ApiPropertyOptional`

## Common Mistakes

- Unclear naming (using `UserDto` instead of `UserRequestDto` or `UserResponseDto`)
- Documentation that just restates the field name
- Missing `@Type()` decorator on nested objects
- Missing `{ each: true }` for array validation
- Missing `@IsOptional()` on optional fields
- Exposing sensitive data in response DTOs
- Duplicating validation logic instead of using `PartialType`
- Using `any` type in DTOs
- Not using `readonly` (allows mutation of DTO properties)
