---
description: Service layer patterns for NestJS including method organization, validation, and error handling.
globs: **/*.service.ts
alwaysApply: false
---

# NestJS Service Patterns

How to implement robust service layer patterns with proper method organization, dependency injection, validation, and error handling.

## Purpose

Services contain the business logic of your application. They:
- Encapsulate business rules and domain logic
- Coordinate between repositories and external services
- Handle transactions and data consistency
- Validate business rules before operations

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

#### Good

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

#### Bad

```typescript
// Direct repository instantiation - not testable
@Injectable()
export class UserService {
  private readonly userRepository = new UserRepository();
}

// Missing @Injectable decorator
export class UserService {
  constructor(private readonly userRepository: UserRepository) {}
}
```

### Object Parameters with Destructuring (RO-RO Pattern)

For methods with multiple parameters, use object parameters.

#### Good

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

#### Bad

```typescript
// Too many positional parameters - hard to read
async findAll(
  skip: number,
  take: number,
  where: object,
  orderBy: object,
  include: object,
): Promise<User[]> {
  // Unclear which parameter is which when calling
}

// Returning only data without count for paginated results
async findAll(): Promise<User[]> {
  return this.userRepository.findMany();
}
```

### Splitting Long Methods into Atomic Functions

Long methods should be split into smaller, focused functions that are orchestrated by a main method.

#### Good

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

#### Bad

```typescript
// Single monolithic method - hard to test, read, and maintain
async createOrder(userId: string, items: any[]): Promise<Order> {
  // 100+ lines of mixed validation, creation, updates, notifications
  const user = await this.userRepository.findOne(userId);
  if (!user) throw new NotFoundException();
  if (!user.isActive) throw new BadRequestException();

  for (const item of items) {
    const product = await this.productRepository.findOne(item.productId);
    if (!product) throw new NotFoundException();
    if (product.stock < item.quantity) throw new BadRequestException();
  }

  const order = await this.orderRepository.create({ userId, status: 'pending' });

  for (const item of items) {
    await this.orderItemRepository.create({ orderId: order.id, ...item });
  }

  for (const item of items) {
    await this.productRepository.update(item.productId, {
      stock: { decrement: item.quantity },
    });
  }

  await this.emailService.send({ to: user.email, subject: 'Order confirmed' });

  return order;
}
```

### Dedicated Service for Complex Operations

When an operation is very complex, create a dedicated service file.

#### Good

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

#### Good

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

#### Good

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

#### Good

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

## Best Practices

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

## Common Mistakes

- Direct instantiation of dependencies instead of injection
- Missing `@Injectable()` decorator
- Monolithic methods that do too much (>50 lines)
- Not splitting complex operations into dedicated services
- Not validating entity existence before operations
- Putting too much logic in a single service (god service)
- Catching errors without proper handling or re-throwing
- Not logging important operations
- Using positional parameters instead of object parameters
- Returning raw data without count for paginated queries
