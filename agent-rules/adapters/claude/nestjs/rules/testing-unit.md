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
