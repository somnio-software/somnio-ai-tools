---
description: Consistent error handling patterns for NestJS - avoid magic strings, use structured approaches.
globs:
  - "**/*exception*.ts"
  - "**/*error*.ts"
  - "**/*filter*.ts"
alwaysApply: false
---

# NestJS Error Handling Standards

How to implement consistent, maintainable error handling across your NestJS application.

## Purpose

Proper error handling ensures:
- Consistent error response format across the entire API
- Clear, actionable error messages for clients
- No magic strings scattered throughout the codebase
- Easy debugging and error tracking
- Security by not exposing internal details

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

## Best Practices

- **Choose one approach and be consistent** - enums, constants, or error classes
- **Never use magic strings** - all error codes/messages in centralized files
- **Include error codes** - machine-readable codes for client handling
- **Use appropriate HTTP status codes** - 404 for not found, 409 for conflict, etc.
- **Validate before operations** - check entity existence before update/delete
- **Log appropriately** - error level for 5xx, warn level for 4xx
- **Hide internal details in production** - don't expose stack traces
- **Structure error responses consistently** - same format for all endpoints
- **Group errors by feature** - `user.errors.ts`, `order.errors.ts`

## Common Mistakes

- Magic strings for error messages scattered throughout the code
- Inconsistent error response formats
- Different messages for the same error in different places
- Exposing stack traces in production
- Not validating entity existence before operations
- Missing error codes (only returning messages)
- Catching errors without proper handling or re-throwing
- Using generic Error instead of specific NestJS exceptions
