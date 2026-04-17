# Somnio Coding Standards — GitHub Copilot (Nestjs)

Follow these standards in all code suggestions.

### Controller patterns for NestJS including decorators, meaningful documentation, and guards.
> Applies to: `**/*.controller.ts`

# NestJS Controller Patterns

How to implement clean, well-documented controllers with proper decorators, guards, and meaningful Swagger documentation.

## Controller Structure

```
feature/
├── feature.controller.ts      # Main controller
├── feature.service.ts         # Business logic
├── dto/
│   ├── create-feature-request.dto.ts
│   ├── update-feature-request.dto.ts
│   ├── feature-query.dto.ts
│   └── feature-response.dto.ts
└── entities/
    └── feature.entity.ts
```

## Patterns

### Meaningful Swagger Documentation

The purpose of Swagger documentation is to generate useful API docs. Documentation should **add value**, not just restate the obvious.

```typescript
@ApiTags('users')
@Controller('users')
export class UserController {
  @Post()
  @ApiOperation({
    summary: 'Register a new user account',
    description: 'Creates a new user with email verification. Returns the created user without sensitive data. Sends a verification email to the provided address.',
  })
  @ApiResponse({
    status: 201,
    description: 'User account created successfully. Verification email sent.',
    type: UserResponseDto,
  })
  @ApiResponse({
    status: 409,
    description: 'Email already registered in the system',
  })
  async create(@Body() dto: CreateUserRequestDto): Promise<UserResponseDto> {
    return this.userService.create(dto);
  }

  @Get()
  @ApiOperation({
    summary: 'Search and filter users with pagination',
    description: 'Retrieves users matching the provided filters. Supports pagination, sorting, and full-text search on name and email fields.',
  })
  @ApiResponse({
    status: 200,
    description: 'Paginated list of users matching the filters',
  })
  async findAll(@Query() query: UserQueryDto) {
    return this.userService.findAll(query);
  }

  @Get(':id')
  @ApiOperation({
    summary: 'Get user profile with related data',
    description: 'Retrieves complete user profile including department assignments, roles, and contact information.',
  })
  @ApiParam({
    name: 'id',
    description: 'Unique user identifier (UUID v4)',
    format: 'uuid',
  })
  async findOne(@Param('id') id: string): Promise<UserResponseDto> {
    return this.userService.findOne(id);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({
    summary: 'Deactivate user account',
    description: 'Soft-deletes the user account. User data is retained but account becomes inaccessible. Can be restored by admin within 30 days.',
  })
  async remove(@Param('id') id: string): Promise<void> {
    await this.userService.remove(id);
  }
}
```

### Guards and Authorization

```typescript
import { Controller, Get, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiUnauthorizedResponse, ApiForbiddenResponse } from '@nestjs/swagger';

@ApiTags('users')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('users')
export class UserController {
  @Get('profile')
  @ApiOperation({
    summary: 'Get authenticated user profile',
    description: 'Returns the complete profile of the currently authenticated user based on the JWT token.',
  })
  @ApiUnauthorizedResponse({ description: 'Invalid or expired authentication token' })
  async getProfile(@CurrentUser() user: User): Promise<UserResponseDto> {
    return this.userService.findOne(user.id);
  }

  @Get('admin/dashboard')
  @Roles(Role.ADMIN)
  @ApiOperation({
    summary: 'Get admin dashboard data',
    description: 'Retrieves aggregated statistics and recent activity. Requires ADMIN role.',
  })
  @ApiForbiddenResponse({ description: 'User does not have ADMIN role' })
  async getAdminDashboard() {
    return this.userService.getDashboardStats();
  }
}
```

### Response Formatting with Response DTOs

```typescript
@Controller('users')
export class UserController {
  @Get()
  @ApiOkResponse({
    description: 'Paginated list with metadata',
    schema: {
      properties: {
        data: { type: 'array', items: { $ref: '#/components/schemas/UserResponseDto' } },
        meta: {
          type: 'object',
          properties: {
            total: { type: 'number', description: 'Total matching records' },
            page: { type: 'number', description: 'Current page number' },
            limit: { type: 'number', description: 'Records per page' },
            totalPages: { type: 'number', description: 'Total available pages' },
          },
        },
      },
    },
  })
  async findAll(@Query() query: UserQueryDto): Promise<PaginatedResponse<UserResponseDto>> {
    const { data, count } = await this.userService.findAll({
      skip: (query.page - 1) * query.limit,
      take: query.limit,
    });

    return {
      data,
      meta: {
        total: count,
        page: query.page,
        limit: query.limit,
        totalPages: Math.ceil(count / query.limit),
      },
    };
  }
}
```

### File Upload Handling

```typescript
@Controller('users')
export class UserController {
  @Post(':id/avatar')
  @UseInterceptors(FileInterceptor('file'))
  @ApiConsumes('multipart/form-data')
  @ApiOperation({
    summary: 'Upload user avatar image',
    description: 'Replaces the current avatar with the uploaded image. Supports JPG, PNG, and GIF formats up to 5MB.',
  })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        file: {
          type: 'string',
          format: 'binary',
          description: 'Image file (JPG, PNG, or GIF)',
        },
      },
    },
  })
  async uploadAvatar(
    @Param('id') id: string,
    @UploadedFile(
      new ParseFilePipe({
        validators: [
          new MaxFileSizeValidator({ maxSize: 5 * 1024 * 1024 }),
          new FileTypeValidator({ fileType: /(jpg|jpeg|png|gif)$/ }),
        ],
      }),
    )
    file: Express.Multer.File,
  ) {
    return this.userService.updateAvatar({ id, file });
  }
}
```

### StreamableFile Response

```typescript
@Controller('reports')
export class ReportsController {
  @Get(':id/export')
  @ApiOperation({
    summary: 'Export report as PDF',
    description: 'Generates and downloads a PDF version of the report. Report must be in completed status.',
  })
  @ApiProduces('application/pdf')
  @ApiResponse({
    status: 200,
    description: 'PDF file download',
    content: { 'application/pdf': {} },
  })
  async exportPdf(
    @Param('id') id: string,
    @Res({ passthrough: true }) res: Response,
  ): Promise<StreamableFile> {
    const pdfStream = await this.reportsService.generatePdf(id);

    res.set({
      'Content-Type': 'application/pdf',
      'Content-Disposition': `attachment; filename="report-${id}.pdf"`,
    });

    return new StreamableFile(pdfStream);
  }
}
```

### Nested Routes

```typescript
@ApiTags('user-orders')
@Controller('users/:userId')
export class UserOrdersController {
  @Get('orders')
  @ApiOperation({
    summary: 'Get order history for a specific user',
    description: 'Retrieves all orders placed by the user, including order items and payment status.',
  })
  @ApiParam({
    name: 'userId',
    description: 'User identifier',
    format: 'uuid',
  })
  async findUserOrders(
    @Param('userId') userId: string,
    @Query() query: OrderQueryDto,
  ) {
    return this.orderService.findByUser({ userId, ...query });
  }
}
```

## Rules

- Use `@ApiTags` to group related endpoints logically
- Write `@ApiOperation` summaries that explain **what** and **why**, not just restate the endpoint
- Add `description` for complex operations explaining behavior, side effects, and requirements
- Document all possible response codes with meaningful descriptions
- Use `@ApiBearerAuth` when endpoints require authentication
- Apply guards at controller or method level as appropriate
- Use typed Request DTOs and Response DTOs (never `any`)
- Return consistent response formats (especially for pagination)
- Use `@HttpCode` to set non-default status codes
- Document `@ApiParam` with format and description
- Keep controllers thin - delegate logic to services

- Avoid writing documentation that just restates the endpoint name
- Avoid missing meaningful descriptions for complex operations
- Avoid business logic in controllers instead of services
- Avoid using `any` type for request bodies or parameters
- Avoid missing `@Param` type annotations
- Avoid not setting proper HTTP status codes
- Avoid authorization logic in controllers instead of guards
- Avoid missing authentication documentation (`@ApiBearerAuth`)
- Avoid inconsistent response formats across endpoints

---

### DTO structure with clear request/response naming, validation, transformation, and meaningful Swagger documentation.
> Applies to: `**/*.dto.ts`

# NestJS DTO Validation Standards

How to create robust, well-documented DTOs with clear naming conventions, proper validation, and meaningful documentation.

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

### Response DTO with Transformation

Response DTOs control what data is exposed to clients.

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

### When to Use @ApiProperty vs @ApiPropertyOptional

| Decorator | Use When | Validation |
|-----------|----------|------------|
| `@ApiProperty()` | Field is required in the request/response | Pair with `@IsNotEmpty()` |
| `@ApiPropertyOptional()` | Field is optional | Pair with `@IsOptional()` |

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

### Nested Objects with Validation

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

## Rules

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

- Avoid unclear naming (using `UserDto` instead of `UserRequestDto` or `UserResponseDto`)
- Avoid documentation that just restates the field name
- Avoid missing `@Type()` decorator on nested objects
- Avoid missing `{ each: true }` for array validation
- Avoid missing `@IsOptional()` on optional fields
- Avoid exposing sensitive data in response DTOs
- Avoid duplicating validation logic instead of using `PartialType`
- Avoid using `any` type in DTOs
- Avoid not using `readonly` (allows mutation of DTO properties)

---

### Consistent error handling patterns for NestJS - avoid magic strings, use structured approaches.

# NestJS Error Handling Standards

How to implement consistent, maintainable error handling across your NestJS application.

## Core Principle: Consistency Over Specific Approach

The most important aspect of error handling is **consistency**. Choose an approach and apply it uniformly across the entire codebase. Whether you use error enums, error codes, or error constants - the key is that all developers follow the same pattern.

**Never use magic strings** - errors should always be defined in a centralized location.

## Error Handling Approaches

Choose one approach and stick with it across the entire codebase.

### Approach 1: Error Enums (Recommended for Type Safety)

```typescript
// errors/user.errors.ts
export enum UserError {
  NOT_FOUND = 'USER_NOT_FOUND',
  EMAIL_EXISTS = 'USER_EMAIL_EXISTS',
  INVALID_CREDENTIALS = 'USER_INVALID_CREDENTIALS',
  ACCOUNT_DISABLED = 'USER_ACCOUNT_DISABLED',
  CANNOT_DELETE_ACTIVE = 'USER_CANNOT_DELETE_ACTIVE',
}

// Optional: Message map for user-friendly messages
export const UserErrorMessage: Record<UserError, string> = {
  [UserError.NOT_FOUND]: 'User not found',
  [UserError.EMAIL_EXISTS]: 'A user with this email already exists',
  [UserError.INVALID_CREDENTIALS]: 'Invalid email or password',
  [UserError.ACCOUNT_DISABLED]: 'This account has been disabled',
  [UserError.CANNOT_DELETE_ACTIVE]: 'Cannot delete user with active orders',
};
```

### Approach 2: Error Constants

```typescript
// errors/user.errors.ts
export const USER_ERRORS = {
  NOT_FOUND: {
    code: 'USER_NOT_FOUND',
    message: 'User not found',
  },
  EMAIL_EXISTS: {
    code: 'USER_EMAIL_EXISTS',
    message: 'A user with this email already exists',
  },
  INVALID_CREDENTIALS: {
    code: 'USER_INVALID_CREDENTIALS',
    message: 'Invalid email or password',
  },
} as const;
```

### Approach 3: Error Classes

```typescript
// errors/user.errors.ts
export class UserNotFoundError extends NotFoundException {
  constructor(userId?: string) {
    super({
      code: 'USER_NOT_FOUND',
      message: userId ? `User ${userId} not found` : 'User not found',
    });
  }
}

export class EmailExistsError extends ConflictException {
  constructor(email: string) {
    super({
      code: 'USER_EMAIL_EXISTS',
      message: 'A user with this email already exists',
      field: 'email',
    });
  }
}
```

## Using Errors in Services

Regardless of approach, errors should be thrown with structured data.

#### Good - Consistent, No Magic Strings

```typescript
import { Injectable, NotFoundException, ConflictException } from '@nestjs/common';
import { UserError, UserErrorMessage } from './errors/user.errors';

@Injectable()
export class UserService {
  async findOne(id: string): Promise<User> {
    const user = await this.userRepository.findOne(id);

    if (!user) {
      throw new NotFoundException({
        code: UserError.NOT_FOUND,
        message: UserErrorMessage[UserError.NOT_FOUND],
      });
    }

    return user;
  }

  async create(dto: CreateUserRequestDto): Promise<User> {
    const existing = await this.userRepository.findByEmail(dto.email);

    if (existing) {
      throw new ConflictException({
        code: UserError.EMAIL_EXISTS,
        message: UserErrorMessage[UserError.EMAIL_EXISTS],
        field: 'email',
      });
    }

    return this.userRepository.create(dto);
  }

  async delete(id: string): Promise<void> {
    const user = await this.findOne(id);

    const hasActiveOrders = await this.orderRepository.hasActive(id);
    if (hasActiveOrders) {
      throw new BadRequestException({
        code: UserError.CANNOT_DELETE_ACTIVE,
        message: UserErrorMessage[UserError.CANNOT_DELETE_ACTIVE],
      });
    }

    await this.userRepository.softDelete(id);
  }
}
```

#### Bad - Magic Strings

```typescript
// Magic strings scattered throughout the code
async findOne(id: string): Promise<User> {
  const user = await this.userRepository.findOne(id);

  if (!user) {
    throw new NotFoundException('User not found');  // Magic string!
  }

  return user;
}

async create(dto: CreateUserRequestDto): Promise<User> {
  const existing = await this.userRepository.findByEmail(dto.email);

  if (existing) {
    throw new ConflictException('Email already exists');  // Magic string!
  }
  // ...
}

// Inconsistent messages for same error
async delete(id: string): Promise<void> {
  const user = await this.userRepository.findOne(id);
  if (!user) {
    throw new NotFoundException('Cannot find user');  // Different message!
  }
  // ...
}
```

## Error File Organization

```
feature/
├── errors/
│   ├── feature.errors.ts      # Error definitions for this feature
│   └── index.ts
└── feature.service.ts

# Or centralized:
src/
├── common/
│   └── errors/
│       ├── user.errors.ts
│       ├── order.errors.ts
│       ├── auth.errors.ts
│       └── index.ts
```

## Exception Filters

Create global exception filters to ensure consistent response format.

```typescript
// common/filters/http-exception.filter.ts
import {
  ExceptionFilter,
  Catch,
  ArgumentsHost,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';

interface ErrorResponse {
  statusCode: number;
  timestamp: string;
  path: string;
  code?: string;
  message: string;
  field?: string;
  errors?: { field: string; message: string }[];
}

@Catch(HttpException)
export class HttpExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(HttpExceptionFilter.name);

  catch(exception: HttpException, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();
    const status = exception.getStatus();
    const exceptionResponse = exception.getResponse();

    const errorResponse: ErrorResponse = {
      statusCode: status,
      timestamp: new Date().toISOString(),
      path: request.url,
      message: this.extractMessage(exceptionResponse),
    };

    // Add code if present
    if (typeof exceptionResponse === 'object' && 'code' in exceptionResponse) {
      errorResponse.code = (exceptionResponse as any).code;
    }

    // Add field if present
    if (typeof exceptionResponse === 'object' && 'field' in exceptionResponse) {
      errorResponse.field = (exceptionResponse as any).field;
    }

    // Handle validation errors (array of messages)
    if (typeof exceptionResponse === 'object' && 'message' in exceptionResponse) {
      const messages = (exceptionResponse as any).message;
      if (Array.isArray(messages)) {
        errorResponse.errors = messages.map((msg) => ({
          field: this.extractFieldFromMessage(msg),
          message: msg,
        }));
      }
    }

    // Log errors appropriately
    if (status >= 500) {
      this.logger.error(`${request.method} ${request.url}`, exception.stack);
    } else {
      this.logger.warn(`${request.method} ${request.url} - ${errorResponse.message}`);
    }

    response.status(status).json(errorResponse);
  }

  private extractMessage(response: string | object): string {
    if (typeof response === 'string') return response;
    if ('message' in response) {
      const msg = (response as any).message;
      return Array.isArray(msg) ? msg[0] : msg;
    }
    return 'An error occurred';
  }

  private extractFieldFromMessage(message: string): string {
    const match = message.match(/^(\w+)/);
    return match ? match[1] : 'unknown';
  }
}
```

## Global Exception Filter for Unexpected Errors

```typescript
// common/filters/all-exceptions.filter.ts
@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let message = 'Internal server error';
    let code = 'INTERNAL_ERROR';

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      const exceptionResponse = exception.getResponse();
      message = typeof exceptionResponse === 'string'
        ? exceptionResponse
        : (exceptionResponse as any).message || message;
      code = (exceptionResponse as any).code || code;
    }

    // Log with full stack trace for server errors
    if (status >= 500) {
      this.logger.error(
        `${request.method} ${request.url}`,
        exception instanceof Error ? exception.stack : String(exception),
      );
    }

    // Don't expose internal details in production
    const isProduction = process.env.NODE_ENV === 'production';

    response.status(status).json({
      statusCode: status,
      timestamp: new Date().toISOString(),
      path: request.url,
      code,
      message: isProduction && status >= 500 ? 'Internal server error' : message,
    });
  }
}
```

## Registering Exception Filters

```typescript
// main.ts
async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  app.useGlobalFilters(
    new AllExceptionsFilter(),
    new HttpExceptionFilter(),
  );

  await app.listen(3000);
}
```

## Validation Before Operations

Always validate entity existence before performing operations.

```typescript
@Injectable()
export class OrderService {
  async update(id: string, dto: UpdateOrderRequestDto): Promise<Order> {
    // Validate order exists
    const order = await this.orderRepository.findOne(id);
    if (!order) {
      throw new NotFoundException({
        code: OrderError.NOT_FOUND,
        message: OrderErrorMessage[OrderError.NOT_FOUND],
      });
    }

    // Validate business rules
    if (order.status === OrderStatus.COMPLETED) {
      throw new BadRequestException({
        code: OrderError.CANNOT_MODIFY_COMPLETED,
        message: OrderErrorMessage[OrderError.CANNOT_MODIFY_COMPLETED],
      });
    }

    return this.orderRepository.update(id, dto);
  }
}
```

## Error Response Format

Maintain consistent error response structure across the API:

```typescript
// Standard error response
{
  "statusCode": 404,
  "timestamp": "2024-01-15T10:30:00.000Z",
  "path": "/api/users/123",
  "code": "USER_NOT_FOUND",
  "message": "User not found"
}

// Error with field (for validation)
{
  "statusCode": 409,
  "timestamp": "2024-01-15T10:30:00.000Z",
  "path": "/api/users",
  "code": "USER_EMAIL_EXISTS",
  "message": "A user with this email already exists",
  "field": "email"
}

// Multiple validation errors
{
  "statusCode": 400,
  "timestamp": "2024-01-15T10:30:00.000Z",
  "path": "/api/users",
  "message": "Validation failed",
  "errors": [
    { "field": "email", "message": "email must be a valid email" },
    { "field": "password", "message": "password must be at least 8 characters" }
  ]
}
```

## Rules

- **Choose one approach and be consistent** - enums, constants, or error classes
- **Never use magic strings** - all error codes/messages in centralized files
- **Include error codes** - machine-readable codes for client handling
- **Use appropriate HTTP status codes** - 404 for not found, 409 for conflict, etc.
- **Validate before operations** - check entity existence before update/delete
- **Log appropriately** - error level for 5xx, warn level for 4xx
- **Hide internal details in production** - don't expose stack traces
- **Structure error responses consistently** - same format for all endpoints
- **Group errors by feature** - `user.errors.ts`, `order.errors.ts`

- Avoid magic strings for error messages scattered throughout the code
- Avoid inconsistent error response formats
- Avoid different messages for the same error in different places
- Avoid exposing stack traces in production
- Avoid not validating entity existence before operations
- Avoid missing error codes (only returning messages)
- Avoid catching errors without proper handling or re-throwing
- Avoid using generic Error instead of specific NestJS exceptions

---

### Module organization patterns for NestJS including imports, exports, providers, and feature structure.
> Applies to: `**/*.module.ts`

# NestJS Module Structure Standards

How to organize NestJS modules with proper imports, exports, providers, and feature-based structure.

## Module Organization

### Feature Module Structure

```
src/
├── users/
│   ├── users.module.ts           # Feature module
│   ├── users.controller.ts       # HTTP endpoints
│   ├── users.service.ts          # Business logic
│   ├── dto/
│   │   ├── create-user.dto.ts
│   │   ├── update-user.dto.ts
│   │   ├── query-users.dto.ts
│   │   └── index.ts
│   ├── entities/
│   │   ├── user.entity.ts
│   │   └── index.ts
│   ├── repositories/
│   │   ├── user.repository.ts
│   │   ├── prisma-user.repository.ts
│   │   └── index.ts
│   ├── errors/
│   │   ├── user-validation.error.ts
│   │   └── index.ts
│   └── index.ts                  # Public API barrel
├── common/
│   ├── common.module.ts          # Shared utilities
│   ├── filters/
│   ├── guards/
│   ├── interceptors/
│   ├── decorators/
│   └── pipes/
├── core/
│   └── core.module.ts            # Global providers
└── app.module.ts                 # Root module
```

## Patterns

### Feature Module

```typescript
// users.module.ts
import { Module } from '@nestjs/common';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';
import { UserRepository } from './repositories/user.repository';
import { PrismaUserRepository } from './repositories/prisma-user.repository';
import { PrismaModule } from '../prisma/prisma.module';

@Module({
  imports: [PrismaModule],
  controllers: [UsersController],
  providers: [
    UsersService,
    {
      provide: UserRepository,
      useClass: PrismaUserRepository,
    },
  ],
  exports: [UsersService], // Export for use in other modules
})
export class UsersModule {}
```

### Root App Module

```typescript
// app.module.ts
import { Module, MiddlewareConsumer, NestModule } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { CoreModule } from './core/core.module';
import { UsersModule } from './users/users.module';
import { OrdersModule } from './orders/orders.module';
import { AuthModule } from './auth/auth.module';
import { PrismaModule } from './prisma/prisma.module';
import { LoggerMiddleware } from './common/middleware/logger.middleware';
import configuration from './config/configuration';

@Module({
  imports: [
    // Configuration first
    ConfigModule.forRoot({
      isGlobal: true,
      load: [configuration],
    }),
    // Core/infrastructure modules
    CoreModule,
    PrismaModule,
    // Feature modules
    AuthModule,
    UsersModule,
    OrdersModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer.apply(LoggerMiddleware).forRoutes('*');
  }
}
```

### Core Module (Global Providers)

```typescript
// core.module.ts
import { Global, Module } from '@nestjs/common';
import { APP_FILTER, APP_GUARD, APP_INTERCEPTOR } from '@nestjs/core';
import { AllExceptionsFilter } from '../common/filters/all-exceptions.filter';
import { HttpExceptionFilter } from '../common/filters/http-exception.filter';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { LoggingInterceptor } from '../common/interceptors/logging.interceptor';
import { TransformInterceptor } from '../common/interceptors/transform.interceptor';

@Global()
@Module({
  providers: [
    // Global exception filters
    {
      provide: APP_FILTER,
      useClass: AllExceptionsFilter,
    },
    {
      provide: APP_FILTER,
      useClass: HttpExceptionFilter,
    },
    // Global interceptors
    {
      provide: APP_INTERCEPTOR,
      useClass: LoggingInterceptor,
    },
    {
      provide: APP_INTERCEPTOR,
      useClass: TransformInterceptor,
    },
  ],
})
export class CoreModule {}
```

### Shared/Common Module

```typescript
// common.module.ts
import { Module } from '@nestjs/common';
import { EncryptionService } from './services/encryption.service';
import { PaginationService } from './services/pagination.service';
import { FileUploadService } from './services/file-upload.service';

@Module({
  providers: [
    EncryptionService,
    PaginationService,
    FileUploadService,
  ],
  exports: [
    EncryptionService,
    PaginationService,
    FileUploadService,
  ],
})
export class CommonModule {}

// Usage in feature module
@Module({
  imports: [CommonModule], // Import when needed
  // ...
})
export class UsersModule {}
```

### Database Module

```typescript
// prisma.module.ts
import { Global, Module } from '@nestjs/common';
import { PrismaService } from './prisma.service';

@Global() // Available everywhere without importing
@Module({
  providers: [PrismaService],
  exports: [PrismaService],
})
export class PrismaModule {}
```

```typescript
// prisma.service.ts
import { Injectable, OnModuleInit, OnModuleDestroy, Logger } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(PrismaService.name);

  async onModuleInit() {
    await this.$connect();
    this.logger.log('Database connected');
  }

  async onModuleDestroy() {
    await this.$disconnect();
    this.logger.log('Database disconnected');
  }
}
```

### Auth Module with Guards

```typescript
// auth.module.ts
import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { JwtStrategy } from './strategies/jwt.strategy';
import { LocalStrategy } from './strategies/local.strategy';
import { JwtAuthGuard } from './guards/jwt-auth.guard';
import { RolesGuard } from './guards/roles.guard';
import { UsersModule } from '../users/users.module';

@Module({
  imports: [
    UsersModule, // Import to use UsersService
    PassportModule.register({ defaultStrategy: 'jwt' }),
    JwtModule.registerAsync({
      imports: [ConfigModule],
      useFactory: async (configService: ConfigService) => ({
        secret: configService.get<string>('JWT_SECRET'),
        signOptions: {
          expiresIn: configService.get<string>('JWT_EXPIRATION', '1h'),
        },
      }),
      inject: [ConfigService],
    }),
  ],
  controllers: [AuthController],
  providers: [
    AuthService,
    JwtStrategy,
    LocalStrategy,
    JwtAuthGuard,
    RolesGuard,
  ],
  exports: [
    AuthService,
    JwtAuthGuard,
    RolesGuard,
  ],
})
export class AuthModule {}
```

### Dynamic Module

```typescript
// cache.module.ts
import { DynamicModule, Module } from '@nestjs/common';
import { CacheService } from './cache.service';

export interface CacheModuleOptions {
  ttl: number;
  max: number;
  isGlobal?: boolean;
}

@Module({})
export class CacheModule {
  static register(options: CacheModuleOptions): DynamicModule {
    return {
      module: CacheModule,
      global: options.isGlobal ?? false,
      providers: [
        {
          provide: 'CACHE_OPTIONS',
          useValue: options,
        },
        CacheService,
      ],
      exports: [CacheService],
    };
  }

  static registerAsync(options: {
    useFactory: (...args: any[]) => Promise<CacheModuleOptions> | CacheModuleOptions;
    inject?: any[];
    isGlobal?: boolean;
  }): DynamicModule {
    return {
      module: CacheModule,
      global: options.isGlobal ?? false,
      providers: [
        {
          provide: 'CACHE_OPTIONS',
          useFactory: options.useFactory,
          inject: options.inject || [],
        },
        CacheService,
      ],
      exports: [CacheService],
    };
  }
}

// Usage
@Module({
  imports: [
    CacheModule.register({ ttl: 60, max: 100, isGlobal: true }),
    // or async
    CacheModule.registerAsync({
      useFactory: (config: ConfigService) => ({
        ttl: config.get('CACHE_TTL'),
        max: config.get('CACHE_MAX'),
      }),
      inject: [ConfigService],
    }),
  ],
})
export class AppModule {}
```

### Cross-Module Dependencies

```typescript
// orders.module.ts
import { Module, forwardRef } from '@nestjs/common';
import { OrdersController } from './orders.controller';
import { OrdersService } from './orders.service';
import { UsersModule } from '../users/users.module';
import { ProductsModule } from '../products/products.module';
import { PaymentsModule } from '../payments/payments.module';

@Module({
  imports: [
    UsersModule, // Uses UsersService
    ProductsModule, // Uses ProductsService
    forwardRef(() => PaymentsModule), // Circular dependency resolution
  ],
  controllers: [OrdersController],
  providers: [OrdersService],
  exports: [OrdersService],
})
export class OrdersModule {}
```

### Barrel Exports (index.ts)

```typescript
// users/index.ts - Public API of the module
export * from './users.module';
export * from './users.service';
export * from './dto';
export * from './entities';
// Don't export internal implementation details

// users/dto/index.ts
export * from './create-user.dto';
export * from './update-user.dto';
export * from './query-users.dto';
export * from './user-response.dto';

// users/entities/index.ts
export * from './user.entity';

// Usage in other modules
import { UsersModule, UsersService, CreateUserDto } from '../users';
```

### Lazy Loading (for large applications)

```typescript
// app.module.ts with lazy loading
import { Module } from '@nestjs/common';
import { RouterModule } from '@nestjs/core';

@Module({
  imports: [
    // Eagerly loaded modules
    AuthModule,
    UsersModule,

    // Lazy loaded modules (loaded on demand)
    RouterModule.register([
      {
        path: 'admin',
        module: AdminModule,
        children: [
          { path: 'reports', module: ReportsModule },
          { path: 'settings', module: SettingsModule },
        ],
      },
    ]),
  ],
})
export class AppModule {}
```

## Rules

- One module per feature/domain (users, orders, products)
- Use barrel exports (index.ts) for clean imports
- Export only what other modules need
- Use `@Global()` sparingly (only for truly global services like database)
- Register filters, guards, interceptors in CoreModule
- Use `forwardRef()` to resolve circular dependencies
- Keep module files clean - just imports/exports/providers
- Use dynamic modules for configurable functionality
- Import modules in the order: config, infrastructure, features
- Document module dependencies in comments if complex

- Avoid creating one large monolithic module
- Avoid overusing `@Global()` decorator
- Avoid missing exports for services used by other modules
- Avoid circular dependencies without `forwardRef()`
- Avoid importing providers directly instead of modules
- Avoid not using barrel exports (messy import paths)
- Avoid mixing infrastructure and feature code in one module
- Avoid not documenting complex module dependencies

---

### Repository pattern for NestJS with parameterized methods, soft deletes, and query organization.
> Applies to: `**/*.repository.ts`

# NestJS Repository Patterns

How to implement the repository pattern with parameterized methods, query organization, soft deletes, and proper abstraction.

## Repository Structure

```
feature/
├── repositories/
│   ├── user.repository.ts          # Abstract repository (encouraged)
│   ├── user.repository.impl.ts     # Concrete implementation
│   └── index.ts                    # Barrel export
└── feature.module.ts
```

## Core Patterns (Apply Always)

### Parameterized Method Signatures

Use object parameters for flexible, readable method signatures.

```typescript
// Abstract interface
export interface FindAllParams {
  skip?: number;
  take?: number;
  where?: Record<string, unknown>;
  orderBy?: Record<string, 'asc' | 'desc'>;
}

export interface FindOneParams {
  where: Record<string, unknown>;
  include?: Record<string, boolean>;
}

export abstract class UserRepository {
  abstract findAll(params: FindAllParams): Promise<{ data: User[]; count: number }>;
  abstract findOne(params: FindOneParams): Promise<User | null>;
  abstract findOneOrFail(params: FindOneParams): Promise<User>;
  abstract create(data: CreateUserInput): Promise<User>;
  abstract update(params: { id: string; data: UpdateUserInput }): Promise<User>;
  abstract delete(id: string): Promise<void>;
  abstract softDelete(id: string): Promise<User>;
}
```

### Always Return `{ data, count }` for List Operations

This enables proper pagination in the service/controller layer.

```typescript
async findAll(params: FindAllParams): Promise<{ data: User[]; count: number }> {
  const [data, count] = await Promise.all([
    this.db.users.findMany(params),
    this.db.users.count({ where: params.where }),
  ]);

  return { data, count };
}
```

### Soft Delete Pattern (Encouraged)

Always prefer soft deletes to preserve data integrity and enable recovery.

```typescript
export class UserRepository {
  private readonly baseWhere = { deletedAt: null };

  async findAll(params: FindAllParams): Promise<{ data: User[]; count: number }> {
    const where = { ...params.where, ...this.baseWhere };
    // Apply soft delete filter to all queries
  }

  async findOne(params: FindOneParams): Promise<User | null> {
    return this.db.users.findFirst({
      ...params,
      where: { ...params.where, ...this.baseWhere },
    });
  }

  async softDelete(id: string): Promise<User> {
    return this.db.users.update({
      where: { id },
      data: { deletedAt: new Date() },
    });
  }

  async restore(id: string): Promise<User> {
    return this.db.users.update({
      where: { id },
      data: { deletedAt: null },
    });
  }

  // Only for admin/cleanup purposes
  async hardDelete(id: string): Promise<void> {
    await this.db.users.delete({ where: { id } });
  }
}
```

### Separating Complex Queries

When queries become complex, extract them into documented helper methods or objects.

```typescript
export class UserRepository {
  /**
   * Search users with full-text search across multiple fields.
   * Applies soft delete filter and supports pagination.
   */
  async search({
    query,
    filters,
    pagination,
    sort,
  }: UserSearchParams): Promise<{ data: User[]; count: number }> {
    const where = this.buildSearchWhere(query, filters);
    const orderBy = this.buildOrderBy(sort);

    const [data, count] = await Promise.all([
      this.db.users.findMany({ where, orderBy, ...pagination }),
      this.db.users.count({ where }),
    ]);

    return { data, count };
  }

  /**
   * Builds WHERE clause for user search.
   * Combines text search, filters, and soft delete.
   */
  private buildSearchWhere(
    query?: string,
    filters?: UserSearchFilters,
  ): Record<string, unknown> {
    return {
      deletedAt: null,
      ...(query && {
        OR: [
          { name: { contains: query, mode: 'insensitive' } },
          { email: { contains: query, mode: 'insensitive' } },
        ],
      }),
      ...(filters?.role && { role: filters.role }),
      ...(filters?.status && { status: filters.status }),
      ...(filters?.createdAfter && { createdAt: { gte: filters.createdAfter } }),
    };
  }

  /**
   * Builds ORDER BY clause with defaults.
   */
  private buildOrderBy(
    sort?: { field: string; order: 'asc' | 'desc' },
  ): Record<string, 'asc' | 'desc'> {
    return sort ? { [sort.field]: sort.order } : { createdAt: 'desc' };
  }
}
```

### Abstract Repository Pattern (Encouraged)

Using abstract classes makes swapping implementations easier and improves testability.

```typescript
// user.repository.ts - Abstract interface
@Injectable()
export abstract class UserRepository {
  abstract findAll(params: FindAllParams): Promise<{ data: User[]; count: number }>;
  abstract findOne(params: FindOneParams): Promise<User | null>;
  abstract findOneOrFail(params: FindOneParams): Promise<User>;
  abstract create(data: CreateUserInput): Promise<User>;
  abstract update(params: { id: string; data: UpdateUserInput }): Promise<User>;
  abstract softDelete(id: string): Promise<User>;
}

// user.repository.impl.ts - Concrete implementation
@Injectable()
export class UserRepositoryImpl implements UserRepository {
  constructor(private readonly db: DatabaseService) {}

  async findAll(params: FindAllParams): Promise<{ data: User[]; count: number }> {
    // Implementation
  }

  async findOneOrFail(params: FindOneParams): Promise<User> {
    const user = await this.findOne(params);
    if (!user) {
      throw new NotFoundException({
        code: UserError.NOT_FOUND,
        message: 'User not found',
      });
    }
    return user;
  }

  // ... other methods
}

// user.module.ts - Wire abstract to concrete
@Module({
  providers: [
    UserService,
    {
      provide: UserRepository,
      useClass: UserRepositoryImpl,
    },
  ],
  exports: [UserRepository],
})
export class UserModule {}
```

### Transaction Support

Design methods to accept transaction clients for multi-record operations.

```typescript
export class UserRepository {
  async createWithProfile(
    data: CreateUserInput,
    profileData: CreateProfileInput,
    transaction?: TransactionClient,
  ): Promise<User> {
    const client = transaction ?? this.db;

    return client.users.create({
      data: {
        ...data,
        profile: { create: profileData },
      },
      include: { profile: true },
    });
  }
}
```

---

## Prisma-Specific Patterns

**The following patterns apply only if your codebase uses Prisma ORM.**

### Reusable Select Objects

Define select objects with type safety for consistent field selection.

```typescript
import { Prisma } from '@prisma/client';

// Define reusable select objects
export const userBasicSelect = {
  id: true,
  email: true,
  name: true,
  createdAt: true,
} satisfies Prisma.UserSelect;

export const userWithProfileSelect = {
  ...userBasicSelect,
  profile: {
    select: {
      bio: true,
      avatarUrl: true,
    },
  },
} satisfies Prisma.UserSelect;

export const userWithOrdersSelect = {
  ...userBasicSelect,
  orders: {
    select: {
      id: true,
      status: true,
      total: true,
    },
    orderBy: { createdAt: 'desc' as const },
    take: 10,
  },
} satisfies Prisma.UserSelect;

// Usage in repository
@Injectable()
export class PrismaUserRepository implements UserRepository {
  async findOneWithProfile(id: string) {
    return this.prisma.user.findUnique({
      where: { id, deletedAt: null },
      select: userWithProfileSelect,
    });
  }
}
```

### Prisma Transaction Pattern

```typescript
@Injectable()
export class PrismaUserRepository implements UserRepository {
  constructor(private readonly prisma: PrismaService) {}

  async transferBalance({
    fromUserId,
    toUserId,
    amount,
  }: TransferParams): Promise<void> {
    await this.prisma.$transaction(async (tx) => {
      const fromUser = await tx.user.findUniqueOrThrow({
        where: { id: fromUserId },
      });

      if (fromUser.balance < amount) {
        throw new BadRequestException({
          code: UserError.INSUFFICIENT_BALANCE,
          message: 'Insufficient balance',
        });
      }

      await tx.user.update({
        where: { id: fromUserId },
        data: { balance: { decrement: amount } },
      });

      await tx.user.update({
        where: { id: toUserId },
        data: { balance: { increment: amount } },
      });
    });
  }
}
```

### Prisma Soft Delete Filter

```typescript
@Injectable()
export class PrismaUserRepository implements UserRepository {
  private readonly baseWhere: Prisma.UserWhereInput = {
    deletedAt: null,
  };

  async findAll(params: FindAllParams): Promise<{ data: User[]; count: number }> {
    const where: Prisma.UserWhereInput = {
      ...params.where,
      ...this.baseWhere,
    };

    const [data, count] = await Promise.all([
      this.prisma.user.findMany({
        skip: params.skip,
        take: params.take,
        where,
        orderBy: params.orderBy ?? { createdAt: 'desc' },
      }),
      this.prisma.user.count({ where }),
    ]);

    return { data, count };
  }
}
```

---

## Rules

- **Always return `{ data, count }`** for list operations to support pagination
- **Encourage soft delete** - use `deletedAt: null` filter consistently
- **Use abstract repository pattern** for better testability (encouraged, not required)
- **Parameterize methods** with object parameters for flexibility
- **Extract complex queries** into documented helper methods
- **Support transactions** by accepting optional transaction clients
- **Provide `findOneOrFail`** methods that throw `NotFoundException`
- **Keep repositories focused** on data access - no business logic
- **Document complex queries** with JSDoc comments explaining the logic

- Avoid forgetting soft delete filter in some queries (data leak)
- Avoid not returning count with list data (breaks pagination)
- Avoid inline complex queries without documentation
- Avoid coupling services directly to ORM instead of abstract repository
- Avoid not supporting transaction clients in repository methods
- Avoid putting business logic in repositories instead of services
- Avoid inconsistent error handling (sometimes throwing, sometimes returning null)
- Avoid duplicating query logic instead of extracting helpers

---

### Service layer patterns for NestJS including method organization, validation, and error handling.
> Applies to: `**/*.service.ts`

# NestJS Service Patterns

How to implement robust service layer patterns with proper method organization, dependency injection, validation, and error handling.

## Service File Organization

The key principle: **Keep services focused and atomic**.

```
feature/
├── feature.service.ts              # Main service (orchestration + simple methods)
├── create-feature.service.ts       # Complex operation as dedicated service
├── process-feature.service.ts      # Another complex operation
├── services/
│   └── index.ts                    # Barrel export for all services
└── feature.module.ts
```

**When to create a dedicated service file:**
- The operation is complex (>50 lines of logic)
- The operation has many steps that need orchestration
- The operation is reused across multiple entry points
- The operation has its own error handling requirements

**When to keep in the main service:**
- Simple CRUD operations
- Methods under 20 lines
- Single-purpose utility methods

## Patterns

### Basic Service with Dependency Injection

```typescript
import { Injectable, Logger } from '@nestjs/common';
import { UserRepository } from './repositories/user.repository';
import { CreateUserRequestDto } from './dto/create-user-request.dto';
import { User } from './entities/user.entity';

@Injectable()
export class UserService {
  private readonly logger = new Logger(UserService.name);

  constructor(
    private readonly userRepository: UserRepository,
  ) {}

  async create(dto: CreateUserRequestDto): Promise<User> {
    this.logger.log(`Creating user with email: ${dto.email}`);
    return this.userRepository.create(dto);
  }

  async findOne(id: string): Promise<User> {
    return this.userRepository.findOne({ where: { id } });
  }
}
```

### Object Parameters with Destructuring (RO-RO Pattern)

For methods with multiple parameters, use object parameters.

```typescript
@Injectable()
export class UserService {
  async findAll({
    skip,
    take,
    where,
    orderBy,
  }: {
    skip?: number;
    take?: number;
    where?: UserWhereInput;
    orderBy?: UserOrderByInput;
  }): Promise<{ data: User[]; count: number }> {
    const [data, count] = await Promise.all([
      this.userRepository.findMany({ skip, take, where, orderBy }),
      this.userRepository.count({ where }),
    ]);

    return { data, count };
  }

  async update({
    id,
    data,
  }: {
    id: string;
    data: UpdateUserRequestDto;
  }): Promise<User> {
    return this.userRepository.update({ id, data });
  }
}
```

### Splitting Long Methods into Atomic Functions

Long methods should be split into smaller, focused functions that are orchestrated by a main method.

```typescript
@Injectable()
export class OrderService {
  async createOrder({
    userId,
    items,
  }: {
    userId: string;
    items: CreateOrderItemDto[];
  }): Promise<Order> {
    // Orchestration method - calls atomic functions
    await this.validateUser(userId);
    await this.validateInventory(items);

    const order = await this.initializeOrder(userId);
    await this.addOrderItems(order.id, items);
    await this.updateInventory(items);
    await this.notifyUser(userId, order);

    return this.getOrderWithDetails(order.id);
  }

  // Atomic functions - single responsibility
  private async validateUser(userId: string): Promise<void> {
    const user = await this.userService.findOne(userId);
    if (!user) {
      throw new NotFoundException({
        code: OrderError.USER_NOT_FOUND,
        message: 'User not found',
      });
    }
    if (!user.isActive) {
      throw new BadRequestException({
        code: OrderError.USER_INACTIVE,
        message: 'User account is inactive',
      });
    }
  }

  private async validateInventory(items: CreateOrderItemDto[]): Promise<void> {
    for (const item of items) {
      const product = await this.productRepository.findOne(item.productId);
      if (!product) {
        throw new NotFoundException({
          code: OrderError.PRODUCT_NOT_FOUND,
          message: `Product ${item.productId} not found`,
        });
      }
      if (product.stock < item.quantity) {
        throw new BadRequestException({
          code: OrderError.INSUFFICIENT_STOCK,
          message: `Insufficient stock for ${product.name}`,
        });
      }
    }
  }

  private async initializeOrder(userId: string): Promise<Order> {
    return this.orderRepository.create({
      userId,
      status: OrderStatus.PENDING,
      createdAt: new Date(),
    });
  }

  private async addOrderItems(orderId: string, items: CreateOrderItemDto[]): Promise<void> {
    await this.orderItemRepository.createMany(
      items.map((item) => ({
        orderId,
        productId: item.productId,
        quantity: item.quantity,
      })),
    );
  }

  private async updateInventory(items: CreateOrderItemDto[]): Promise<void> {
    for (const item of items) {
      await this.productRepository.decrementStock(item.productId, item.quantity);
    }
  }

  private async notifyUser(userId: string, order: Order): Promise<void> {
    await this.notificationService.sendOrderConfirmation({ userId, orderId: order.id });
  }

  private async getOrderWithDetails(orderId: string): Promise<Order> {
    return this.orderRepository.findOne({
      where: { id: orderId },
      include: { items: true },
    });
  }
}
```

### Dedicated Service for Complex Operations

When an operation is very complex, create a dedicated service file.

```typescript
// create-order.service.ts - Dedicated service for order creation
@Injectable()
export class CreateOrderService {
  constructor(
    private readonly userRepository: UserRepository,
    private readonly productRepository: ProductRepository,
    private readonly orderRepository: OrderRepository,
    private readonly notificationService: NotificationService,
    private readonly paymentService: PaymentService,
  ) {}

  async execute({
    userId,
    items,
    paymentMethod,
  }: CreateOrderInput): Promise<CreateOrderResult> {
    // All the complex logic for order creation
    const validatedUser = await this.validateAndGetUser(userId);
    const validatedItems = await this.validateAndGetProducts(items);
    const totals = this.calculateTotals(validatedItems);

    const order = await this.createOrderWithTransaction({
      user: validatedUser,
      items: validatedItems,
      totals,
    });

    await this.processPayment(order, paymentMethod);
    await this.sendNotifications(validatedUser, order);

    return { order, totals };
  }

  // ... all the atomic helper methods
}

// order.service.ts - Main service delegates to specialized services
@Injectable()
export class OrderService {
  constructor(
    private readonly createOrderService: CreateOrderService,
    private readonly orderRepository: OrderRepository,
  ) {}

  async create(dto: CreateOrderRequestDto): Promise<Order> {
    const result = await this.createOrderService.execute(dto);
    return result.order;
  }

  async findOne(id: string): Promise<Order> {
    return this.orderRepository.findOne({ where: { id } });
  }

  async findAll(query: OrderQueryDto): Promise<{ data: Order[]; count: number }> {
    return this.orderRepository.findAll(query);
  }
}
```

### Validation Before Operations

```typescript
@Injectable()
export class UserService {
  async create(dto: CreateUserRequestDto): Promise<User> {
    // Check for existing email
    const existingUser = await this.userRepository.findByEmail(dto.email);
    if (existingUser) {
      throw new ConflictException({
        code: UserError.EMAIL_EXISTS,
        message: 'User with this email already exists',
      });
    }

    return this.userRepository.create(dto);
  }

  async update({ id, data }: { id: string; data: UpdateUserRequestDto }): Promise<User> {
    // Verify user exists
    const user = await this.userRepository.findOne({ where: { id } });
    if (!user) {
      throw new NotFoundException({
        code: UserError.NOT_FOUND,
        message: 'User not found',
      });
    }

    // Validate email uniqueness if changing email
    if (data.email && data.email !== user.email) {
      const existingUser = await this.userRepository.findByEmail(data.email);
      if (existingUser) {
        throw new ConflictException({
          code: UserError.EMAIL_EXISTS,
          message: 'Email already in use',
        });
      }
    }

    return this.userRepository.update({ id, data });
  }

  async delete(id: string): Promise<void> {
    const user = await this.userRepository.findOne({
      where: { id },
      include: { orders: true },
    });

    if (!user) {
      throw new NotFoundException({
        code: UserError.NOT_FOUND,
        message: 'User not found',
      });
    }

    // Business rule: cannot delete user with active orders
    const hasActiveOrders = user.orders.some(
      (order) => order.status !== OrderStatus.COMPLETED,
    );
    if (hasActiveOrders) {
      throw new BadRequestException({
        code: UserError.CANNOT_DELETE_ACTIVE,
        message: 'Cannot delete user with active orders',
      });
    }

    await this.userRepository.delete(id);
  }
}
```

### Service Composition

```typescript
@Injectable()
export class OrderService {
  constructor(
    private readonly orderRepository: OrderRepository,
    private readonly userService: UserService,
    private readonly productService: ProductService,
    private readonly notificationService: NotificationService,
  ) {}

  async create({
    userId,
    items,
  }: {
    userId: string;
    items: CreateOrderItemDto[];
  }): Promise<Order> {
    // Delegate validation to specialized services
    const user = await this.userService.findOneOrFail(userId);

    // Delegate product validation
    for (const item of items) {
      await this.productService.validateStock({
        productId: item.productId,
        quantity: item.quantity,
      });
    }

    // Create order
    const order = await this.orderRepository.create({ userId, items });

    // Delegate notification
    await this.notificationService.sendOrderConfirmation({ user, order });

    return order;
  }
}
```

### Async Operations with Error Handling

```typescript
@Injectable()
export class ImportService {
  async importUsers(file: Express.Multer.File): Promise<ImportResult> {
    const users = await this.parseFile(file);
    const results: ImportResult = {
      successful: [],
      failed: [],
    };

    // Process in batches to avoid memory issues
    const batches = this.chunk(users, 100);

    for (const batch of batches) {
      const batchResults = await Promise.allSettled(
        batch.map((userData) => this.createUser(userData)),
      );

      batchResults.forEach((result, index) => {
        if (result.status === 'fulfilled') {
          results.successful.push(result.value);
        } else {
          results.failed.push({
            data: batch[index],
            error: result.reason.message,
          });
        }
      });
    }

    return results;
  }

  private chunk<T>(array: T[], size: number): T[][] {
    return Array.from({ length: Math.ceil(array.length / size) }, (_, i) =>
      array.slice(i * size, i * size + size),
    );
  }
}
```

## Rules

- Use constructor injection for all dependencies
- Use the Logger from `@nestjs/common` for logging
- Use object parameters (RO-RO pattern) for methods with multiple parameters
- Return `{ data, count }` for paginated results
- **Split long methods into atomic functions** - each function does one thing
- **Create dedicated service files for complex operations** (>50 lines)
- Keep simple CRUD in the main feature.service.ts
- Validate business rules before performing operations
- Use transactions for operations that modify multiple records
- Delegate specialized tasks to other services (composition)
- Use specific NestJS exceptions with error codes
- Use `async/await` consistently
- Process large datasets in batches

- Avoid direct instantiation of dependencies instead of injection
- Avoid missing `@Injectable()` decorator
- Avoid monolithic methods that do too much (>50 lines)
- Avoid not splitting complex operations into dedicated services
- Avoid not validating entity existence before operations
- Avoid putting too much logic in a single service (god service)
- Avoid catching errors without proper handling or re-throwing
- Avoid not logging important operations
- Avoid using positional parameters instead of object parameters
- Avoid returning raw data without count for paginated queries

---

### Integration test patterns for NestJS including database setup, cleanup, and test isolation.
> Applies to: `**/*.integration.spec.ts`

# NestJS Integration Testing Standards

How to write comprehensive integration tests with real database interactions, proper setup/cleanup, and test isolation.

## Test File Organization

```
src/
├── users/
│   ├── users.service.ts
│   ├── users.service.spec.ts              # Unit tests
│   └── users.integration.spec.ts          # Integration tests
test/
├── setup/
│   ├── test-database.ts                   # Database utilities
│   └── test-app.ts                        # App bootstrapping
└── helpers/
    └── test-helpers.ts                    # Shared test utilities
```

## Test Structure

Follow the same grouping hierarchy as unit tests.

```typescript
// [Feature] -> [Endpoint] -> [Scenario] -> [Test Case]
describe('Users API (Integration)', () => {
  describe('POST /users', () => {
    describe('when request is valid', () => {
      it('should create user and return 201', async () => { });
      it('should hash the password before storing', async () => { });
    });

    describe('when email already exists', () => {
      it('should return 409 with EMAIL_EXISTS code', async () => { });
    });

    describe('when validation fails', () => {
      it('should return 400 with validation errors', async () => { });
    });
  });

  describe('GET /users/:id', () => {
    describe('when user exists', () => {
      it('should return user data with 200', async () => { });
    });

    describe('when user does not exist', () => {
      it('should return 404 with NOT_FOUND code', async () => { });
    });
  });
});
```

## Test Isolation

**Critical**: Tests must be isolated and not depend on each other.

### Use Unique Identifiers

```typescript
import { randomUUID } from 'crypto';

describe('Users API (Integration)', () => {
  const testId = randomUUID().slice(0, 8);  // Unique per test run

  // All test data includes testId for easy cleanup
  const testEmail = `user-${testId}@example.com`;

  afterAll(async () => {
    // Clean up only this test run's data
    await db.users.deleteMany({
      where: { email: { contains: testId } },
    });
  });
});
```

### Setup Per Test Group

```typescript
describe('GET /users/:id', () => {
  let testUser: User;

  beforeEach(async () => {
    // Create fresh data for each test in this group
    testUser = await db.users.create({
      data: {
        email: `get-test-${Date.now()}@example.com`,
        name: 'Test User',
      },
    });
  });

  afterEach(async () => {
    // Clean up after each test
    await db.users.delete({ where: { id: testUser.id } });
  });

  it('should return user by id', async () => {
    const response = await request(app.getHttpServer())
      .get(`/users/${testUser.id}`)
      .expect(200);

    expect(response.body.id).toBe(testUser.id);
  });
});
```

## Basic Integration Test Pattern

```typescript
import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import * as request from 'supertest';
import { AppModule } from '../app.module';
import { DatabaseService } from '../database/database.service';
import { randomUUID } from 'crypto';

describe('Users API (Integration)', () => {
  let app: INestApplication;
  let db: DatabaseService;
  const testId = randomUUID().slice(0, 8);

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
    await app.init();

    db = app.get<DatabaseService>(DatabaseService);
  });

  afterAll(async () => {
    // Clean up all test data
    await db.users.deleteMany({
      where: { email: { contains: testId } },
    });
    await app.close();
  });

  describe('POST /users', () => {
    describe('when request is valid', () => {
      it('should create user and return 201', async () => {
        // Arrange
        const createDto = {
          email: `create-${testId}@example.com`,
          name: 'Test User',
          password: 'password123',
        };

        // Act
        const response = await request(app.getHttpServer())
          .post('/users')
          .send(createDto)
          .expect(201);

        // Assert - Response
        expect(response.body).toMatchObject({
          email: createDto.email,
          name: createDto.name,
        });
        expect(response.body.id).toBeDefined();
        expect(response.body.password).toBeUndefined();  // Not exposed

        // Assert - Database
        const dbUser = await db.users.findUnique({
          where: { email: createDto.email },
        });
        expect(dbUser).toBeDefined();
        expect(dbUser?.name).toBe(createDto.name);
      });
    });

    describe('when email already exists', () => {
      it('should return 409 with EMAIL_EXISTS code', async () => {
        // Arrange - Create existing user
        const email = `duplicate-${testId}@example.com`;
        await db.users.create({
          data: { email, name: 'Existing', password: 'hash' },
        });

        // Act
        const response = await request(app.getHttpServer())
          .post('/users')
          .send({ email, name: 'New User', password: 'password123' })
          .expect(409);

        // Assert
        expect(response.body.code).toBe('USER_EMAIL_EXISTS');
      });
    });

    describe('when validation fails', () => {
      it('should return 400 with validation errors', async () => {
        // Act
        const response = await request(app.getHttpServer())
          .post('/users')
          .send({ email: 'invalid-email', name: '', password: '123' })
          .expect(400);

        // Assert
        expect(response.body.errors).toBeDefined();
        expect(response.body.errors.length).toBeGreaterThan(0);
      });
    });
  });

  describe('GET /users', () => {
    beforeEach(async () => {
      // Seed test data
      await db.users.createMany({
        data: [
          { email: `list-1-${testId}@example.com`, name: 'User 1' },
          { email: `list-2-${testId}@example.com`, name: 'User 2' },
          { email: `list-3-${testId}@example.com`, name: 'User 3' },
        ],
      });
    });

    afterEach(async () => {
      await db.users.deleteMany({
        where: { email: { contains: `list-${testId}` } },
      });
    });

    it('should return paginated users', async () => {
      // Act
      const response = await request(app.getHttpServer())
        .get('/users')
        .query({ page: 1, limit: 2 })
        .expect(200);

      // Assert
      expect(response.body.data).toHaveLength(2);
      expect(response.body.meta.total).toBeGreaterThanOrEqual(3);
    });
  });
});
```

## Testing with Authentication

```typescript
describe('Protected Routes (Integration)', () => {
  let app: INestApplication;
  let userToken: string;
  let adminToken: string;

  beforeAll(async () => {
    // ... app setup

    // Get tokens for authenticated requests
    const userResponse = await request(app.getHttpServer())
      .post('/auth/login')
      .send({ email: 'user@example.com', password: 'password' });
    userToken = userResponse.body.accessToken;

    const adminResponse = await request(app.getHttpServer())
      .post('/auth/login')
      .send({ email: 'admin@example.com', password: 'adminpass' });
    adminToken = adminResponse.body.accessToken;
  });

  describe('GET /users/profile', () => {
    describe('when authenticated', () => {
      it('should return user profile', async () => {
        const response = await request(app.getHttpServer())
          .get('/users/profile')
          .set('Authorization', `Bearer ${userToken}`)
          .expect(200);

        expect(response.body.email).toBeDefined();
      });
    });

    describe('when not authenticated', () => {
      it('should return 401', async () => {
        await request(app.getHttpServer())
          .get('/users/profile')
          .expect(401);
      });
    });

    describe('when token is invalid', () => {
      it('should return 401', async () => {
        await request(app.getHttpServer())
          .get('/users/profile')
          .set('Authorization', 'Bearer invalid-token')
          .expect(401);
      });
    });
  });

  describe('GET /admin/users', () => {
    describe('when user is admin', () => {
      it('should return all users', async () => {
        await request(app.getHttpServer())
          .get('/admin/users')
          .set('Authorization', `Bearer ${adminToken}`)
          .expect(200);
      });
    });

    describe('when user is not admin', () => {
      it('should return 403', async () => {
        await request(app.getHttpServer())
          .get('/admin/users')
          .set('Authorization', `Bearer ${userToken}`)
          .expect(403);
      });
    });
  });
});
```

## Testing Transactions

```typescript
describe('Order Creation (Integration)', () => {
  describe('POST /orders', () => {
    describe('when inventory is sufficient', () => {
      it('should create order and update inventory atomically', async () => {
        // Arrange
        const product = await db.products.create({
          data: { name: 'Test Product', price: 100, stock: 10 },
        });

        const orderData = {
          items: [{ productId: product.id, quantity: 3 }],
        };

        // Act
        const response = await request(app.getHttpServer())
          .post('/orders')
          .set('Authorization', `Bearer ${userToken}`)
          .send(orderData)
          .expect(201);

        // Assert - Order created
        expect(response.body.items).toHaveLength(1);

        // Assert - Inventory updated
        const updatedProduct = await db.products.findUnique({
          where: { id: product.id },
        });
        expect(updatedProduct?.stock).toBe(7);
      });
    });

    describe('when inventory is insufficient', () => {
      it('should return 400 and not modify inventory', async () => {
        // Arrange
        const product = await db.products.create({
          data: { name: 'Limited Product', price: 100, stock: 2 },
        });
        const initialStock = product.stock;

        // Act
        await request(app.getHttpServer())
          .post('/orders')
          .set('Authorization', `Bearer ${userToken}`)
          .send({ items: [{ productId: product.id, quantity: 10 }] })
          .expect(400);

        // Assert - Stock unchanged (transaction rolled back)
        const unchangedProduct = await db.products.findUnique({
          where: { id: product.id },
        });
        expect(unchangedProduct?.stock).toBe(initialStock);
      });
    });
  });
});
```

## Test Helpers

Create reusable helpers for common operations.

```typescript
// test/helpers/test-helpers.ts
export class TestHelpers {
  constructor(
    private app: INestApplication,
    private db: DatabaseService,
  ) {}

  async createUser(data: Partial<CreateUserInput> = {}): Promise<User> {
    return this.db.users.create({
      data: {
        email: `test-${Date.now()}@example.com`,
        name: 'Test User',
        password: 'hashed',
        ...data,
      },
    });
  }

  async getAuthToken(email: string, password: string): Promise<string> {
    const response = await request(this.app.getHttpServer())
      .post('/auth/login')
      .send({ email, password });
    return response.body.accessToken;
  }

  authenticatedRequest(token: string) {
    return {
      get: (url: string) =>
        request(this.app.getHttpServer())
          .get(url)
          .set('Authorization', `Bearer ${token}`),
      post: (url: string) =>
        request(this.app.getHttpServer())
          .post(url)
          .set('Authorization', `Bearer ${token}`),
      put: (url: string) =>
        request(this.app.getHttpServer())
          .put(url)
          .set('Authorization', `Bearer ${token}`),
      delete: (url: string) =>
        request(this.app.getHttpServer())
          .delete(url)
          .set('Authorization', `Bearer ${token}`),
    };
  }
}

// Usage
describe('Orders (Integration)', () => {
  let helpers: TestHelpers;

  beforeAll(async () => {
    helpers = new TestHelpers(app, db);
  });

  it('should create order', async () => {
    const user = await helpers.createUser();
    const token = await helpers.getAuthToken(user.email, 'password');
    const client = helpers.authenticatedRequest(token);

    const response = await client.post('/orders').send({ items: [] });
    expect(response.status).toBe(201);
  });
});
```

## Database Cleanup Strategies

### Strategy 1: Unique Identifiers (Recommended)

```typescript
const testId = randomUUID().slice(0, 8);
// All test data includes testId
// Cleanup: DELETE WHERE email CONTAINS testId
```

### Strategy 2: Transaction Rollback

```typescript
describe('Users API', () => {
  beforeEach(async () => {
    await db.$executeRaw`BEGIN`;
  });

  afterEach(async () => {
    await db.$executeRaw`ROLLBACK`;
  });
});
```

### Strategy 3: Truncate Tables

```typescript
afterAll(async () => {
  // Only for test database!
  await db.$executeRaw`TRUNCATE TABLE users CASCADE`;
});
```

## Rules

- **Unique identifiers** - Use UUID/timestamp to isolate test data
- **Clean up always** - Always clean up in `afterAll`/`afterEach`
- **Test isolation** - Tests must not depend on each other
- **Verify database state** - Assert both response AND database
- **Test both success and error** - Include 4xx response tests
- **Same grouping structure** - Class → Endpoint → Scenario → Test
- **Test authentication flows** - Include auth/no-auth/invalid-auth
- **Test transactions** - Verify rollback on errors
- **Use helpers** - Create reusable test utilities
- **Seed per group** - Use `beforeEach` for group-specific data

- Avoid tests depending on other tests' data
- Avoid not cleaning up test data
- Avoid missing unique identifiers (data collisions)
- Avoid not verifying database state after operations
- Avoid missing authentication tests
- Avoid not testing validation errors
- Avoid not testing transaction rollback
- Avoid hardcoded data that conflicts between runs
- Avoid setup in `beforeAll` when `beforeEach` is needed

---

### Unit test patterns for NestJS including mocking, structure, grouping, and assertions.
> Applies to: `**/*.spec.ts`

# NestJS Unit Testing Standards

How to write comprehensive unit tests following industry standards with proper structure, mocking, and assertions.

## Test File Organization

### Directory Structure

```
src/
├── users/
│   ├── users.service.ts
│   ├── users.service.spec.ts       # Tests next to source file
│   ├── users.controller.ts
│   └── users.controller.spec.ts
```

### Consistent Test Structure

**Critical**: Follow the same structure across ALL test files in the codebase.

```typescript
// [ClassName] -> [MethodName] -> [Test Cases]
describe('UserService', () => {
  // Setup block - same pattern in every test file
  let service: UserService;
  let mockRepository: jest.Mocked<UserRepository>;

  beforeEach(() => {
    jest.clearAllMocks();
    // Setup mocks and instantiate service
  });

  // Group by method
  describe('create', () => {
    // Group by scenario within method
    describe('when email is unique', () => {
      it('should create and return the user', async () => {
        // Test case
      });
    });

    describe('when email already exists', () => {
      it('should throw ConflictException', async () => {
        // Test case
      });
    });
  });

  describe('findOne', () => {
    describe('when user exists', () => {
      it('should return the user', async () => { });
    });

    describe('when user does not exist', () => {
      it('should throw NotFoundException', async () => { });
    });
  });
});
```

## Test Grouping Hierarchy

Follow this hierarchy for ALL test files:

```
describe('[ClassName]')           // Class being tested
  └── describe('[methodName]')    // Method being tested
       └── describe('[scenario]') // Specific scenario/condition
            └── it('[expected behavior]')  // Actual test case
```

```typescript
describe('OrderService', () => {
  describe('create', () => {
    describe('when user is valid', () => {
      describe('and products are in stock', () => {
        it('should create the order', async () => { });
        it('should decrement product stock', async () => { });
        it('should send confirmation notification', async () => { });
      });

      describe('and products are out of stock', () => {
        it('should throw BadRequestException with INSUFFICIENT_STOCK code', async () => { });
        it('should not create any order', async () => { });
      });
    });

    describe('when user does not exist', () => {
      it('should throw NotFoundException with USER_NOT_FOUND code', async () => { });
    });
  });

  describe('cancel', () => {
    describe('when order is pending', () => {
      it('should update status to CANCELLED', async () => { });
      it('should restore product stock', async () => { });
    });

    describe('when order is already completed', () => {
      it('should throw BadRequestException', async () => { });
    });
  });
});
```

## Arrange-Act-Assert Pattern

Every test should follow AAA with clear visual separation.

```typescript
it('should create and return the user when email is unique', async () => {
  // Arrange
  const createDto: CreateUserRequestDto = {
    email: 'test@example.com',
    name: 'Test User',
    password: 'password123',
  };
  const expectedUser = { id: 'user-1', ...createDto };

  mockRepository.findByEmail.mockResolvedValue(null);
  mockRepository.create.mockResolvedValue(expectedUser);

  // Act
  const result = await service.create(createDto);

  // Assert
  expect(result).toEqual(expectedUser);
  expect(mockRepository.findByEmail).toHaveBeenCalledWith(createDto.email);
  expect(mockRepository.create).toHaveBeenCalledWith(createDto);
});
```

## Mocking Patterns

### Standard Mock Setup

```typescript
describe('UserService', () => {
  let service: UserService;
  let mockUserRepository: jest.Mocked<UserRepository>;
  let mockNotificationService: jest.Mocked<NotificationService>;

  // Define mock objects outside beforeEach for reusability
  const createMockUserRepository = (): jest.Mocked<UserRepository> => ({
    findAll: jest.fn(),
    findOne: jest.fn(),
    findByEmail: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
    delete: jest.fn(),
  } as jest.Mocked<UserRepository>);

  const createMockNotificationService = (): jest.Mocked<NotificationService> => ({
    sendEmail: jest.fn(),
    sendPush: jest.fn(),
  } as jest.Mocked<NotificationService>);

  beforeEach(() => {
    jest.clearAllMocks();

    mockUserRepository = createMockUserRepository();
    mockNotificationService = createMockNotificationService();

    service = new UserService(mockUserRepository, mockNotificationService);
  });
});
```

### Using Jest Mock Extended (Alternative)

```typescript
import { mock, mockDeep, DeepMockProxy } from 'jest-mock-extended';

describe('UserService', () => {
  let service: UserService;
  let mockRepository: DeepMockProxy<UserRepository>;

  beforeEach(() => {
    mockRepository = mockDeep<UserRepository>();
    service = new UserService(mockRepository);
  });

  it('should find user by id', async () => {
    // Arrange
    const expectedUser = { id: '1', email: 'test@example.com' };
    mockRepository.findOne.mockResolvedValue(expectedUser);

    // Act
    const result = await service.findOne('1');

    // Assert
    expect(result).toEqual(expectedUser);
  });
});
```

### NestJS Testing Module (When Needed)

Use TestingModule when testing components with NestJS decorators or when DI is complex.

```typescript
import { Test, TestingModule } from '@nestjs/testing';

describe('UserService', () => {
  let service: UserService;
  let mockRepository: jest.Mocked<UserRepository>;

  beforeEach(async () => {
    mockRepository = {
      findAll: jest.fn(),
      findOne: jest.fn(),
      create: jest.fn(),
    } as jest.Mocked<UserRepository>;

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UserService,
        { provide: UserRepository, useValue: mockRepository },
      ],
    }).compile();

    service = module.get<UserService>(UserService);
  });
});
```

## Testing Error Cases

Always test both success and error paths with specific error codes.

```typescript
describe('UserService', () => {
  describe('create', () => {
    describe('when email already exists', () => {
      it('should throw ConflictException with EMAIL_EXISTS code', async () => {
        // Arrange
        const dto = { email: 'existing@example.com', name: 'Test' };
        mockRepository.findByEmail.mockResolvedValue({ id: '1', email: dto.email });

        // Act & Assert
        await expect(service.create(dto)).rejects.toThrow(ConflictException);

        // Verify error details
        try {
          await service.create(dto);
        } catch (error) {
          expect(error.response.code).toBe(UserError.EMAIL_EXISTS);
        }
      });
    });
  });

  describe('delete', () => {
    describe('when user has active orders', () => {
      it('should throw BadRequestException with CANNOT_DELETE_ACTIVE code', async () => {
        // Arrange
        const userWithOrders = {
          id: '1',
          orders: [{ id: 'order-1', status: 'PENDING' }],
        };
        mockRepository.findOne.mockResolvedValue(userWithOrders);

        // Act & Assert
        await expect(service.delete('1')).rejects.toThrow(BadRequestException);
      });
    });
  });
});
```

## Test Data Builders

Use builders for complex test data to keep tests readable.

```typescript
// test/builders/user.builder.ts
export class UserBuilder {
  private user: User = {
    id: 'default-id',
    email: 'default@example.com',
    name: 'Default User',
    status: 'ACTIVE',
    createdAt: new Date(),
  };

  withId(id: string): this {
    this.user.id = id;
    return this;
  }

  withEmail(email: string): this {
    this.user.email = email;
    return this;
  }

  asInactive(): this {
    this.user.status = 'INACTIVE';
    return this;
  }

  build(): User {
    return { ...this.user };
  }
}

// Usage in tests
describe('UserService', () => {
  it('should reject inactive users', async () => {
    // Arrange
    const inactiveUser = new UserBuilder()
      .withId('user-1')
      .asInactive()
      .build();

    mockRepository.findOne.mockResolvedValue(inactiveUser);

    // Act & Assert
    await expect(service.activate('user-1')).rejects.toThrow();
  });
});
```

## Verifying Mock Interactions

Always verify that mocks were called with correct arguments.

```typescript
it('should call repository with correct parameters', async () => {
  // Arrange
  const dto = { email: 'test@example.com', name: 'Test' };
  mockRepository.findByEmail.mockResolvedValue(null);
  mockRepository.create.mockResolvedValue({ id: '1', ...dto });

  // Act
  await service.create(dto);

  // Assert - Verify calls
  expect(mockRepository.findByEmail).toHaveBeenCalledTimes(1);
  expect(mockRepository.findByEmail).toHaveBeenCalledWith(dto.email);
  expect(mockRepository.create).toHaveBeenCalledWith(dto);
});

it('should NOT call create when email exists', async () => {
  // Arrange
  mockRepository.findByEmail.mockResolvedValue({ id: '1' });

  // Act
  try {
    await service.create({ email: 'existing@example.com' });
  } catch {}

  // Assert - Verify create was NOT called
  expect(mockRepository.create).not.toHaveBeenCalled();
});
```

## Rules

- **Consistent structure** - Same grouping pattern in ALL test files
- **Clear grouping** - Class → Method → Scenario → Test case
- **Descriptive names** - Test names should explain expected behavior
- **AAA pattern** - Clear Arrange/Act/Assert separation
- **One assertion focus** - Test one logical concept per test
- **Clear mocks** - Always `jest.clearAllMocks()` in `beforeEach`
- **Verify interactions** - Use `toHaveBeenCalledWith` to verify arguments
- **Test both paths** - Always test success AND error scenarios
- **Use builders** - For complex test data
- **Mock at boundaries** - Mock repositories and external services

- Avoid inconsistent test structure across files
- Avoid not grouping tests by method/scenario
- Avoid vague test names ("should work", "test create")
- Avoid testing multiple behaviors in one test
- Avoid not verifying mock call arguments
- Avoid missing error case tests
- Avoid not clearing mocks between tests
- Avoid using real dependencies instead of mocks
- Avoid forgetting to await async operations

---

### TypeScript guidelines, naming conventions, and NestJS architectural principles.
> Applies to: `src/modules/**/*.ts`

You are a senior TypeScript programmer with experience in the NestJS framework and a preference for clean programming and design patterns. Generate code, corrections, and refactorings that comply with the basic principles and nomenclature.

## TypeScript General Guidelines

### Basic Principles

- Use English for all code and documentation.
- Always declare the type of each variable and function (parameters and return value).
- Avoid using any.
- Create necessary types.
- Use JSDoc to document public classes and methods.
- Don't leave blank lines within a function.
- One export per file.

### Nomenclature

- Use PascalCase for classes.
- Use camelCase for variables, functions, and methods.
- Use kebab-case for file and directory names.
- Use UPPERCASE for environment variables.
- Avoid magic numbers and define constants.
- Start each function with a verb.
- Use verbs for boolean variables. Example: isLoading, hasError, canDelete, etc.
- Use complete words instead of abbreviations and correct spelling.
- Except for standard abbreviations like API, URL, etc.
- Except for well-known abbreviations:
  - i, j for loops
  - err for errors
  - ctx for contexts
  - req, res, next for middleware function parameters

### Functions

- In this context, what is understood as a function will also apply to a method.
- Write short functions with a single purpose. Less than 20 instructions.
- Name functions with a verb and something else.
- If it returns a boolean, use isX or hasX, canX, etc.
- If it doesn't return anything, use executeX or saveX, etc.
- Avoid nesting blocks by:
  - Early checks and returns.
  - Extraction to utility functions.
- Use higher-order functions (map, filter, reduce, etc.) to avoid function nesting.
- Use arrow functions for simple functions (less than 3 instructions).
- Use named functions for non-simple functions.
- Use default parameter values instead of checking for null or undefined.
- Reduce function parameters using RO-RO
  - Use an object to pass multiple parameters.
  - Use an object to return results.
  - Declare necessary types for input arguments and output.
- Use a single level of abstraction.

### Data

- Don't abuse primitive types and encapsulate data in composite types.
- Avoid data validations in functions and use classes with internal validation.
- Prefer immutability for data.
- Use readonly for data that doesn't change.
- Use as const for literals that don't change.

### Classes

- Follow SOLID principles.
- Prefer composition over inheritance.
- Declare interfaces to define contracts.
- Write small classes with a single purpose.
  - Less than 200 instructions.
  - Less than 10 public methods.
  - Less than 10 properties.

### Exceptions

- Use exceptions to handle errors you don't expect.
- If you catch an exception, it should be to:
  - Fix an expected problem.
  - Add context.
  - Otherwise, use a global handler.

### Testing

- Follow the Arrange-Act-Assert convention for tests.
- Name test variables clearly.
- Follow the convention: inputX, mockX, actualX, expectedX, etc.
- Write unit tests for each public function.
- Use test doubles to simulate dependencies.
  - Except for third-party dependencies that are not expensive to execute.
- Write acceptance tests for each module.
- Follow the Given-When-Then convention.

## Specific to NestJS

### Basic Principles

- Use modular architecture
- Encapsulate the API in modules.
  - One module per main domain/route.
  - One controller for its route.
  - And other controllers for secondary routes.
  - A models folder with data types.
  - DTOs validated with class-validator for inputs.
  - Declare simple types for outputs.
  - A services module with business logic and persistence.
  - Entities with MikroORM for data persistence.
  - One service per entity.
- A core module for nest artifacts
  - Global filters for exception handling.
  - Global middlewares for request management.
  - Guards for permission management.
  - Interceptors for request management.
- A shared module for services shared between modules.
  - Utilities
  - Shared business logic

### Testing

- Use the standard Jest framework for testing.
- Write tests for each controller and service.
- Write end to end tests for each api module.
- Add a admin/test method to each controller as a smoke test.

---
