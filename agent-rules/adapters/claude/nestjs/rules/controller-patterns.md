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
