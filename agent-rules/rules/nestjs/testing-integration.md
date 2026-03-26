---
description: Integration test patterns for NestJS including database setup, cleanup, and test isolation.
globs: **/*.integration.spec.ts
alwaysApply: false
---

# NestJS Integration Testing Standards

How to write comprehensive integration tests with real database interactions, proper setup/cleanup, and test isolation.

## Purpose

Integration tests verify that multiple components work together correctly. They:
- Test real database interactions
- Verify API endpoints end-to-end
- Test transactions and data consistency
- Ensure proper error handling across layers

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

## Best Practices

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

## Common Mistakes

- Tests depending on other tests' data
- Not cleaning up test data
- Missing unique identifiers (data collisions)
- Not verifying database state after operations
- Missing authentication tests
- Not testing validation errors
- Not testing transaction rollback
- Hardcoded data that conflicts between runs
- Setup in `beforeAll` when `beforeEach` is needed
