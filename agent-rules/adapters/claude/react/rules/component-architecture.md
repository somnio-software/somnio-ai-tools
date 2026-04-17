### React component architecture including file structure, naming conventions, composition patterns, and folder organization.
> Applies to: `**/*.tsx`
# React Component Architecture

How to structure React applications with feature-based organization, consistent naming, and composable component patterns.

## Folder Structure

Use a **feature-based** organization where code that changes together lives together:

```
src/
├── components/          # Shared, reusable UI components
│   ├── button/
│   │   ├── Button.tsx
│   │   ├── Button.test.tsx
│   │   └── index.ts
│   ├── card/
│   └── index.ts         # Barrel export
├── features/            # Feature-specific code
│   ├── auth/
│   │   ├── components/
│   │   ├── hooks/
│   │   ├── services/
│   │   ├── types.ts
│   │   └── index.ts
│   └── dashboard/
├── hooks/               # Shared custom hooks
├── services/            # API calls and external services
├── types/               # Shared TypeScript types
├── utils/               # Utility functions
└── App.tsx
```

**Rule of thumb**: if something is used by only one feature, keep it inside that feature folder. Promote to `components/` or `hooks/` when reused by two or more features.

## Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Component files | PascalCase | `UserProfile.tsx` |
| Non-component files | kebab-case | `use-auth.ts`, `api-client.ts` |
| Custom hooks | `use` prefix + camelCase | `useForm`, `useWindowSize` |
| Event handlers | `handle` prefix | `handleClick`, `handleSubmit` |
| Boolean props/state | `is/has/should/can` prefix | `isLoading`, `hasError` |
| Constants | UPPER_SNAKE_CASE | `MAX_RETRIES`, `API_URL` |

## Patterns

### Barrel Exports

Use `index.ts` files to simplify imports. Consumers import from the folder, not the file.

```tsx
// components/user-profile/index.ts
export { UserProfile } from './UserProfile';
export type { UserProfileProps } from './UserProfile';

// Consuming code
import { UserProfile } from '@/components/user-profile';
```

---

### Component Composition

Prefer composition over deeply nested prop passing. Pass components as children or use compound components for related UI elements.

```tsx
// Compound component pattern
export const Card = ({ children }: { children: React.ReactNode }) => (
  <div className="card">{children}</div>
);

Card.Header = ({ children }: { children: React.ReactNode }) => (
  <div className="card-header">{children}</div>
);

Card.Body = ({ children }: { children: React.ReactNode }) => (
  <div className="card-body">{children}</div>
);

// Usage
<Card>
  <Card.Header>Title</Card.Header>
  <Card.Body>Content</Card.Body>
</Card>
```

---

### Container / Presenter Pattern

Separate data-fetching logic from rendering. Containers handle state and side effects; presenters render UI.

```tsx
// UserProfileContainer.tsx — logic only
export const UserProfileContainer = ({ userId }: { userId: string }) => {
  const { data: user, isLoading, error } = useUser(userId);

  if (isLoading) return <Spinner />;
  if (error) return <ErrorMessage error={error} />;
  if (!user) return null;

  return <UserProfile user={user} />;
};

// UserProfile.tsx — rendering only, no async logic
interface UserProfileProps {
  user: User;
}

export const UserProfile = ({ user }: UserProfileProps) => (
  <div>
    <h2>{user.name}</h2>
    <p>{user.email}</p>
  </div>
);
```

---

### Named Exports

Always use named exports for components. Default exports make refactoring harder and break auto-import in IDEs.

```tsx
// UserCard.tsx
export const UserCard = ({ name }: { name: string }) => <div>{name}</div>;
```

## Rules

- Keep component files under **300 lines**; extract logic to custom hooks when exceeded
- Maximum **3–4 levels** of folder nesting
- One component per file (avoid exporting multiple unrelated components from the same file)
- Colocate tests next to source files (`UserCard.tsx` → `UserCard.test.tsx`)
- Do not use array indexes as `key` props — use stable unique IDs
- Avoid `React.FC` without explicit props type (prefer plain function signature with typed props)

- Avoid **Mega components**: components with 500+ lines mixing UI, logic, and data fetching
- Avoid **Premature extraction**: creating shared components before they are reused in 2+ places
- Avoid **Inconsistent naming**: mixing PascalCase and camelCase for component files
- Avoid **Missing index.ts**: forcing consumers to navigate internal file structure
