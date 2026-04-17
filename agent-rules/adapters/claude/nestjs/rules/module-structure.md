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
