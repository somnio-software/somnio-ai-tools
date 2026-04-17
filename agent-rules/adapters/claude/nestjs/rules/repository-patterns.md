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
