---
description: Controller patterns for NestJS including decorators, meaningful documentation, and guards.
globs: **/*.controller.ts
alwaysApply: false
---

# NestJS Controller Patterns

How to implement clean, well-documented controllers with proper decorators, guards, and meaningful Swagger documentation.

## Purpose

Controllers handle incoming HTTP requests and return responses. They should:
- Define routes and HTTP methods
- Apply guards and interceptors
- Validate input via DTOs
- Document API with meaningful Swagger decorators (not just restating the endpoint)
- Delegate business logic to services

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

#### Good

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

#### Bad

```typescript
// Documentation that adds no value - just restates the endpoint
@Get()
@ApiOperation({ summary: 'Get all users' })  // Obvious from GET /users
@ApiResponse({ status: 200, description: 'Success' })  // Not helpful
async findAll() { ... }

@Post()
@ApiOperation({ summary: 'Create user' })  // Obvious from POST /users
async create(@Body() dto: any) { ... }  // Using 'any' instead of typed DTO

@Get(':id')
@ApiOperation({ summary: 'Get user by ID' })  // Obvious, no value added
async findOne(@Param() params) { ... }  // Untyped params
```

### Guards and Authorization

#### Good

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

#### Bad

```typescript
// Checking authorization in controller instead of guards
@Get('admin/all')
async findAllAdmin(@CurrentUser() user: User) {
  if (user.role !== 'admin') {
    throw new ForbiddenException();  // Use guards instead
  }
  return this.userService.findAll();
}

// Missing auth documentation
@UseGuards(JwtAuthGuard)
@Get('profile')
async getProfile() {  // Missing @ApiBearerAuth
  // ...
}
```

### Response Formatting with Response DTOs

#### Good

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

#### Good

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

#### Good

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

#### Good

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

## Best Practices

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

## Common Mistakes

- Writing documentation that just restates the endpoint name
- Missing meaningful descriptions for complex operations
- Business logic in controllers instead of services
- Using `any` type for request bodies or parameters
- Missing `@Param` type annotations
- Not setting proper HTTP status codes
- Authorization logic in controllers instead of guards
- Missing authentication documentation (`@ApiBearerAuth`)
- Inconsistent response formats across endpoints
