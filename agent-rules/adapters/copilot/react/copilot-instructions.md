# Somnio Coding Standards — GitHub Copilot (React)

Follow these standards in all code suggestions.

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

---

### React hooks patterns including useState, useEffect, useReducer, and custom hook guidelines.
> Applies to: `**/*.tsx,**/*.ts`

# React Hooks Patterns

How to use React hooks correctly and write maintainable custom hooks following the Rules of Hooks.

## Rules of Hooks

Always enable `eslint-plugin-react-hooks` with these rules:
- `react-hooks/rules-of-hooks` (error)
- `react-hooks/exhaustive-deps` (warn)

The two hard rules:
1. **Only call hooks at the top level** — never inside loops, conditions, or nested functions
2. **Only call hooks from React function components or custom hooks** — never from plain JS functions

```tsx
const UserForm = () => {
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');

  return <form>...</form>;
};
```

## Patterns

### useState

Initialize with meaningful defaults. For complex or related state, consider `useReducer` instead.

```tsx
const [isLoading, setIsLoading] = useState(false);
const [error, setError] = useState<string | null>(null);
const [user, setUser] = useState<User | null>(null);

// Functional update when next state depends on previous
setCount(prev => prev + 1);
```

---

### useEffect

Each `useEffect` should have a **single concern**. Always declare all dependencies and clean up subscriptions.

```tsx
// Separate effects for separate concerns
useEffect(() => {
  document.title = `${user.name} - Profile`;
}, [user.name]);

useEffect(() => {
  const subscription = eventBus.subscribe(userId, handleEvent);
  return () => subscription.unsubscribe(); // ✅ cleanup
}, [userId, handleEvent]);
```

---

### useReducer

Prefer `useReducer` over `useState` when state has multiple related fields or when next state depends on complex logic.

```tsx
interface State {
  status: 'idle' | 'loading' | 'success' | 'error';
  data: User | null;
  error: string | null;
}

type Action =
  | { type: 'FETCH_START' }
  | { type: 'FETCH_SUCCESS'; payload: User }
  | { type: 'FETCH_ERROR'; payload: string };

const reducer = (state: State, action: Action): State => {
  switch (action.type) {
    case 'FETCH_START':
      return { ...state, status: 'loading', error: null };
    case 'FETCH_SUCCESS':
      return { status: 'success', data: action.payload, error: null };
    case 'FETCH_ERROR':
      return { ...state, status: 'error', error: action.payload };
    default:
      return state;
  }
};

const [state, dispatch] = useReducer(reducer, { status: 'idle', data: null, error: null });
```

---

### Custom Hooks

Extract reusable stateful logic into custom hooks. One hook = one concern.

```tsx
// hooks/use-fetch.ts
interface UseFetchResult<T> {
  data: T | null;
  isLoading: boolean;
  error: string | null;
  refetch: () => void;
}

export const useFetch = <T,>(url: string): UseFetchResult<T> => {
  const [state, dispatch] = useReducer(fetchReducer<T>, initialState);

  const fetchData = useCallback(async () => {
    dispatch({ type: 'FETCH_START' });
    try {
      const response = await fetch(url);
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const data: T = await response.json();
      dispatch({ type: 'FETCH_SUCCESS', payload: data });
    } catch (err) {
      dispatch({ type: 'FETCH_ERROR', payload: (err as Error).message });
    }
  }, [url]);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  return { ...state, refetch: fetchData };
};

// Usage
const { data: user, isLoading, error } = useFetch<User>(`/api/users/${userId}`);
```

---

### useMemo and useCallback in Hooks

When a custom hook returns functions or computed values that will be used as dependencies or passed to memoized components, stabilize them.

```tsx
export const useUserActions = (userId: string) => {
  const deleteUser = useCallback(async () => {
    await api.deleteUser(userId);
  }, [userId]);

  const updateUser = useCallback(async (data: Partial<User>) => {
    await api.updateUser(userId, data);
  }, [userId]);

  return { deleteUser, updateUser };
};
```

## Common Hooks to Extract

| Hook | Responsibility |
|------|---------------|
| `useForm` | Form state, validation, submission |
| `useFetch` | Data fetching with loading/error states |
| `useDebounce` | Debounce a value |
| `useLocalStorage` | Persist state to localStorage |
| `usePrevious` | Track the previous value of a prop/state |
| `useWindowSize` | Responsive breakpoints |
| `useOnClickOutside` | Close dropdowns/modals on outside click |

## Rules

- Name custom hooks with the `use` prefix — this is required for lint rules to work
- Return only the values the consumer needs (avoid returning the entire state object)
- Keep custom hooks under **150 lines**; split into smaller hooks if larger
- Do not call async functions directly in `useEffect` — define an inner async function and call it
- Use `AbortController` to cancel fetch requests on cleanup
- Avoid `// eslint-disable-next-line react-hooks/exhaustive-deps` — fix the root cause instead

---

### React performance optimization patterns including memoization, code splitting, and list virtualization.
> Applies to: `**/*.tsx`

# React Performance Optimization

How to optimize React application performance through memoization, code splitting, and rendering strategies.

## Patterns

### React.memo

Prevent re-renders when a parent re-renders but the component's props have not changed. Use only for components with expensive renders or those that receive stable props but re-render too often.

```tsx
interface UserRowProps {
  user: User;
  onDelete: (id: string) => void;
}

// Wrap only after profiling shows unnecessary re-renders
export const UserRow = React.memo(({ user, onDelete }: UserRowProps) => (
  <tr>
    <td>{user.name}</td>
    <td>{user.email}</td>
    <td>
      <button onClick={() => onDelete(user.id)}>Delete</button>
    </td>
  </tr>
));

UserRow.displayName = 'UserRow';
```

---

### useCallback

Stabilize function references passed as props to memoized child components. Without `useCallback`, a new function reference is created on every render, causing `React.memo` to be ineffective.

```tsx
const UserList = ({ users }: { users: User[] }) => {
  const handleDelete = useCallback(async (id: string) => {
    await api.deleteUser(id);
    // update state...
  }, []); // stable — no dependencies that change

  return (
    <ul>
      {users.map(user => (
        // UserRow is memoized — handleDelete must be stable for memo to work
        <UserRow key={user.id} user={user} onDelete={handleDelete} />
      ))}
    </ul>
  );
};
```

---

### useMemo

Memoize expensive computations so they only recalculate when their dependencies change.

```tsx
const ProductList = ({ products, filters }: ProductListProps) => {
  // Expensive: filtering + sorting a large array
  const filteredProducts = useMemo(
    () =>
      products
        .filter(p => p.category === filters.category && p.price <= filters.maxPrice)
        .sort((a, b) => a.name.localeCompare(b.name)),
    [products, filters.category, filters.maxPrice],
  );

  return <ul>{filteredProducts.map(p => <ProductRow key={p.id} product={p} />)}</ul>;
};
```

---

### Code Splitting with React.lazy

Split large bundles by route so the initial page load only downloads what is needed.

```tsx
import { lazy, Suspense } from 'react';
import { Routes, Route } from 'react-router-dom';

// Each route is loaded only when first navigated to
const Dashboard = lazy(() => import('@/pages/Dashboard'));
const Settings = lazy(() => import('@/pages/Settings'));
const Reports = lazy(() => import('@/pages/Reports'));

export const AppRoutes = () => (
  <Suspense fallback={<PageSkeleton />}>
    <Routes>
      <Route path="/dashboard" element={<Dashboard />} />
      <Route path="/settings" element={<Settings />} />
      <Route path="/reports" element={<Reports />} />
    </Routes>
  </Suspense>
);
```

---

### List Virtualization

For lists with hundreds or thousands of items, only render what is visible in the viewport using `react-window` or `react-virtual`.

```tsx
import { FixedSizeList } from 'react-window';

interface VirtualUserListProps {
  users: User[];
}

export const VirtualUserList = ({ users }: VirtualUserListProps) => {
  const Row = useCallback(
    ({ index, style }: { index: number; style: React.CSSProperties }) => (
      <div style={style}>
        <UserRow user={users[index]} />
      </div>
    ),
    [users],
  );

  return (
    <FixedSizeList height={600} itemCount={users.length} itemSize={60} width="100%">
      {Row}
    </FixedSizeList>
  );
};
```

---

### Stable Keys

Always use stable, unique identifiers as `key` props. Index-based keys cause incorrect DOM reconciliation when the list is reordered or filtered.

```tsx
{users.map(user => <UserRow key={user.id} user={user} />)}
```

## Anti-Patterns to Avoid

| Anti-pattern | Problem | Fix |
|-------------|---------|-----|
| Creating new objects in render | New reference every render | Move to `useMemo` or outside component |
| Inline style objects `style={{ color: 'red' }}` | New object reference on each render | Use CSS classes or `useMemo` |
| Inline arrow functions as event handlers | New reference breaks `React.memo` | Use `useCallback` |
| `useCallback` without memoized children | No benefit — only adds overhead | Remove `useCallback` |
| `useMemo` for cheap operations | Overhead exceeds savings | Remove `useMemo` |

## When to Optimize

Apply performance optimizations when profiling shows:
- A component re-renders more than expected in the React DevTools Profiler
- A computation takes >1ms (visible in the profiler flame chart)
- A list has >100 items and scroll performance degrades
- Route transitions are slow (large initial bundle)

## Rules

- Use **React DevTools Profiler** before adding any optimization
- Profile in production mode — development mode is intentionally slower
- Lazy-load routes by default in all new projects
- Virtualize any list that can grow beyond 100 items
- Keep `key` props stable and unique across the list
- Add `displayName` to components wrapped in `memo` or `forwardRef` for DevTools readability

---

### React state management patterns including Context API, Zustand, and TanStack Query for server state.
> Applies to: `**/*.tsx,**/*.ts`

# React State Management

How to choose and implement the right state management approach based on scope and data type.

## Decision Guide

```
Is the state used by only one component?
  └─ YES → useState / useReducer (local state)

Is it UI state shared across a few components?
  └─ YES → Lift state up to nearest common ancestor

Is it global UI state (theme, auth, locale)?
  └─ YES → Context API + custom hook

Is it server data (fetched from an API)?
  └─ YES → TanStack Query (React Query)

Is it complex shared client state?
  └─ YES → Zustand
```

## Patterns

### Context API

Use Context for infrequently changing global state (theme, current user, locale). Do **not** use Context for high-frequency updates — it causes all consumers to re-render.

Create one context per concern; avoid a single mega-context.

```tsx
// contexts/ThemeContext.tsx
import { createContext, useContext, useMemo, useState } from 'react';

type Theme = 'light' | 'dark';

interface ThemeContextValue {
  theme: Theme;
  toggleTheme: () => void;
}

const ThemeContext = createContext<ThemeContextValue | undefined>(undefined);

export const ThemeProvider = ({ children }: { children: React.ReactNode }) => {
  const [theme, setTheme] = useState<Theme>('light');

  // Memoize value to prevent unnecessary re-renders of all consumers
  const value = useMemo<ThemeContextValue>(
    () => ({ theme, toggleTheme: () => setTheme(t => t === 'light' ? 'dark' : 'light') }),
    [theme],
  );

  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
};

// Always export a typed hook — never let consumers call useContext directly
export const useTheme = (): ThemeContextValue => {
  const context = useContext(ThemeContext);
  if (!context) throw new Error('useTheme must be used within <ThemeProvider>');
  return context;
};
```

---

### Zustand (Client State)

Use Zustand for shared client state that changes frequently or spans many components. Zustand avoids unnecessary re-renders by letting components subscribe to specific slices.

```tsx
// stores/cart-store.ts
import { create } from 'zustand';

interface CartItem {
  id: string;
  name: string;
  quantity: number;
  price: number;
}

interface CartStore {
  items: CartItem[];
  addItem: (item: CartItem) => void;
  removeItem: (id: string) => void;
  clearCart: () => void;
  total: () => number;
}

export const useCartStore = create<CartStore>((set, get) => ({
  items: [],
  addItem: (item) =>
    set((state) => ({
      items: state.items.some(i => i.id === item.id)
        ? state.items.map(i => i.id === item.id ? { ...i, quantity: i.quantity + 1 } : i)
        : [...state.items, item],
    })),
  removeItem: (id) =>
    set((state) => ({ items: state.items.filter(i => i.id !== id) })),
  clearCart: () => set({ items: [] }),
  total: () => get().items.reduce((sum, item) => sum + item.price * item.quantity, 0),
}));

// Usage — subscribe to only what you need
const itemCount = useCartStore((state) => state.items.length);
const addItem = useCartStore((state) => state.addItem);
```

---

### TanStack Query (Server State)

Use TanStack Query for all server-fetched data. It handles caching, background refetching, pagination, and synchronization.

```tsx
// hooks/use-user.ts
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';

export const useUser = (userId: string) =>
  useQuery({
    queryKey: ['users', userId],
    queryFn: () => api.fetchUser(userId),
    staleTime: 5 * 60 * 1000, // 5 minutes — don't refetch if data is fresh
  });

export const useUpdateUser = () => {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ id, data }: { id: string; data: Partial<User> }) =>
      api.updateUser(id, data),
    onSuccess: (updatedUser) => {
      // Invalidate and refetch after mutation
      queryClient.invalidateQueries({ queryKey: ['users', updatedUser.id] });
    },
  });
};

// Usage
const { data: user, isLoading, error } = useUser(userId);
const { mutate: updateUser } = useUpdateUser();
```

## Library Selection Guide

| Scenario | Recommended Solution |
|----------|---------------------|
| Local component state | `useState` / `useReducer` |
| Shared UI state (theme, locale, auth) | Context API |
| Server/async data | TanStack Query |
| Complex shared client state | Zustand |
| Large enterprise app with devtools | Redux Toolkit |

## Rules

- **Start local**: default to `useState` and only introduce a library when state genuinely needs to be shared
- Keep Context providers close to where they are needed — not always at the app root
- Split Zustand stores by domain (cart, auth, ui) rather than having one global store
- Always set `staleTime` in TanStack Query — the default of 0 causes excessive refetching
- Never store server data in Zustand or Context alongside TanStack Query — let TQ own the cache
- Avoid storing derived values in state — compute them during render or with `useMemo`

- Avoid using Context for frequently updated state (causes app-wide re-renders)
- Avoid storing remote API data in `useState` instead of TanStack Query
- Avoid subscribing to the full Zustand store (use selectors to subscribe to slices)
- Avoid forgetting to memoize Context value with `useMemo` (causes all consumers to re-render on every parent render)

---

### React testing patterns using React Testing Library and Jest including component tests, hook tests, and mocking strategies.
> Applies to: `**/*.test.tsx,**/*.spec.tsx,**/*.test.ts`

# React Testing Standards

How to write maintainable React tests that validate behavior from the user's perspective using React Testing Library and Jest.

## Test Structure

Follow the **Arrange-Act-Assert** (AAA) pattern consistently across all test files.

```
describe('ComponentName', () => {
  describe('methodName or scenario', () => {
    it('should <expected behavior> when <condition>', async () => {
      // Arrange — set up data and render
      // Act — perform user interaction
      // Assert — verify outcome
    });
  });
});
```

## Patterns

### Component Tests

```tsx
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { UserCard } from './UserCard';

describe('UserCard', () => {
  describe('when rendered with user data', () => {
    it('should display the user name and email', () => {
      // Arrange
      render(<UserCard id="1" name="Alice" email="alice@example.com" />);

      // Assert
      expect(screen.getByText('Alice')).toBeInTheDocument();
      expect(screen.getByText('alice@example.com')).toBeInTheDocument();
    });
  });

  describe('when user selects the card', () => {
    it('should call onSelect with the user id', async () => {
      // Arrange
      const handleSelect = jest.fn();
      const user = userEvent.setup();
      render(<UserCard id="1" name="Alice" email="alice@example.com" onSelect={handleSelect} />);

      // Act
      await user.click(screen.getByRole('button', { name: /alice/i }));

      // Assert
      expect(handleSelect).toHaveBeenCalledWith('1');
      expect(handleSelect).toHaveBeenCalledTimes(1);
    });
  });

  describe('when avatarUrl is not provided', () => {
    it('should not render an image', () => {
      render(<UserCard id="1" name="Alice" email="alice@example.com" />);

      expect(screen.queryByRole('img')).not.toBeInTheDocument();
    });
  });
});
```

---

### Query Priority

Use queries in this order of preference (most semantic → least semantic):

```tsx
// 1. By role (preferred — reflects accessible UI)
screen.getByRole('button', { name: /submit/i });
screen.getByRole('heading', { name: /user profile/i });
screen.getByRole('textbox', { name: /email/i });

// 2. By label text (for form inputs)
screen.getByLabelText('Email address');

// 3. By placeholder text
screen.getByPlaceholderText('Enter your email');

// 4. By text content
screen.getByText('Submit');

// 5. By test ID (last resort — use only if no semantic query works)
screen.getByTestId('custom-widget');
```

---

### Async Testing

Always use `await` with `userEvent` interactions. Use `findBy` queries for elements that appear asynchronously.

```tsx
it('should display user data after loading', async () => {
  // Arrange
  jest.mocked(api.fetchUser).mockResolvedValue({ id: '1', name: 'Alice' });
  render(<UserProfile userId="1" />);

  // Assert loading state
  expect(screen.getByText(/loading/i)).toBeInTheDocument();

  // Assert resolved state
  expect(await screen.findByText('Alice')).toBeInTheDocument();
  expect(screen.queryByText(/loading/i)).not.toBeInTheDocument();
});

it('should show error message when fetch fails', async () => {
  jest.mocked(api.fetchUser).mockRejectedValue(new Error('Not found'));
  render(<UserProfile userId="1" />);

  expect(await screen.findByText(/something went wrong/i)).toBeInTheDocument();
});
```

---

### Hook Testing

Use `renderHook` and `act` from `@testing-library/react` to test custom hooks.

```tsx
import { renderHook, act } from '@testing-library/react';
import { useCounter } from './useCounter';

describe('useCounter', () => {
  it('should initialize with the given value', () => {
    const { result } = renderHook(() => useCounter(5));
    expect(result.current.count).toBe(5);
  });

  it('should increment the count', () => {
    const { result } = renderHook(() => useCounter(0));

    act(() => {
      result.current.increment();
    });

    expect(result.current.count).toBe(1);
  });

  it('should reset to the initial value', () => {
    const { result } = renderHook(() => useCounter(10));

    act(() => {
      result.current.increment();
      result.current.reset();
    });

    expect(result.current.count).toBe(10);
  });
});
```

---

### Mocking

Mock at the module level. Prefer `jest.mocked()` for type-safe access to mock functions.

```tsx
// Mock API module
jest.mock('@/services/api', () => ({
  fetchUser: jest.fn(),
  updateUser: jest.fn(),
}));

import { fetchUser } from '@/services/api';

beforeEach(() => {
  jest.clearAllMocks();
});

it('should call fetchUser with the correct id', async () => {
  jest.mocked(fetchUser).mockResolvedValue({ id: '1', name: 'Alice' });

  render(<UserProfile userId="1" />);
  await screen.findByText('Alice');

  expect(fetchUser).toHaveBeenCalledWith('1');
});
```

---

### jest-dom Matchers

Use `@testing-library/jest-dom` matchers for readable assertions:

```tsx
import '@testing-library/jest-dom';

expect(button).toBeInTheDocument();
expect(button).toBeDisabled();
expect(button).toBeEnabled();
expect(button).toBeVisible();
expect(input).toHaveValue('alice@example.com');
expect(element).toHaveClass('active');
expect(element).toHaveTextContent('Submit');
expect(element).toHaveAttribute('aria-expanded', 'true');
expect(element).toHaveFocus();
```

## Jest Configuration

```js
// jest.config.js
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'jsdom',
  setupFilesAfterFramework: ['<rootDir>/src/setupTests.ts'],
  moduleNameMapper: {
    '^@/(.*)$': '<rootDir>/src/$1',
  },
  collectCoverageFrom: [
    'src/**/*.{ts,tsx}',
    '!src/**/*.d.ts',
    '!src/index.tsx',
    '!src/**/*.stories.tsx',
  ],
};

// src/setupTests.ts
import '@testing-library/jest-dom';
global.fetch = jest.fn();
```

## What to Test

| Test | Example |
|------|---------|
| Renders correctly with props | Title, description, image shown |
| User interactions | Click, type, submit |
| Loading states | Spinner visible while fetching |
| Error states | Error message shown on failure |
| Conditional rendering | Element absent when prop not provided |
| Accessibility | Correct ARIA roles and labels |

## What NOT to Test

- CSS class names or styles (implementation detail)
- Internal component state (test behavior, not state)
- Third-party library behavior
- React lifecycle method calls

## Rules

- Use `userEvent` (not `fireEvent`) — it simulates full browser events including focus, keyboard, etc.
- Always `await` async interactions: `await user.click(button)`
- Use `findBy` for elements that appear after async operations; `getBy` for immediate elements
- Do not use `waitFor` for simple async queries — prefer `findBy`
- Wrap state updates in `act` when testing hooks directly
- Mock at the boundary (API layer) not at internal function level
- Run tests with `--coverage` in CI to catch untested paths

---

### TypeScript integration patterns for React including component typing, generics, and type utilities.
> Applies to: `**/*.tsx,**/*.ts`

# React TypeScript Integration

How to write type-safe React components, hooks, and utilities using TypeScript best practices.

## TypeScript Configuration

Enable strict mode in `tsconfig.json`:

```json
{
  "compilerOptions": {
    "strict": true,
    "noImplicitAny": true,
    "strictNullChecks": true,
    "noImplicitReturns": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "moduleResolution": "bundler",
    "jsx": "react-jsx",
    "baseUrl": ".",
    "paths": {
      "@/*": ["src/*"]
    }
  }
}
```

## Patterns

### Component Props

Define a dedicated interface for every component's props. Use `interface` over `type` for component props (better error messages, supports declaration merging).

```tsx
interface UserCardProps {
  id: string;
  name: string;
  email: string;
  avatarUrl?: string;
  onSelect?: (id: string) => void;
}

export const UserCard = ({ id, name, email, avatarUrl, onSelect }: UserCardProps) => (
  <div onClick={() => onSelect?.(id)}>
    {avatarUrl && <img src={avatarUrl} alt={name} />}
    <h3>{name}</h3>
    <p>{email}</p>
  </div>
);
```

---

### Extending HTML Element Props

When building primitive UI components (Button, Input), extend the underlying HTML element's props to pass through native attributes.

```tsx
interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'danger';
  size?: 'sm' | 'md' | 'lg';
  isLoading?: boolean;
}

export const Button = ({ variant = 'primary', size = 'md', isLoading, children, ...rest }: ButtonProps) => (
  <button
    className={`btn btn-${variant} btn-${size}`}
    disabled={isLoading || rest.disabled}
    {...rest}
  >
    {isLoading ? <Spinner /> : children}
  </button>
);
```

---

### forwardRef

Use `React.forwardRef` when the component wraps a DOM element that consumers may need to control directly (focus, scroll, etc.).

```tsx
interface InputProps extends React.InputHTMLAttributes<HTMLInputElement> {
  label: string;
  error?: string;
}

export const Input = React.forwardRef<HTMLInputElement, InputProps>(
  ({ label, error, ...props }, ref) => (
    <div>
      <label htmlFor={props.id}>{label}</label>
      <input ref={ref} aria-invalid={!!error} {...props} />
      {error && <span className="error">{error}</span>}
    </div>
  ),
);

Input.displayName = 'Input'; // Required for devtools when using forwardRef
```

---

### Generic Components

Use generics for components that work with different data types (lists, selects, tables).

```tsx
interface SelectProps<T> {
  options: T[];
  value: T | null;
  getOptionLabel: (option: T) => string;
  getOptionValue: (option: T) => string;
  onChange: (value: T | null) => void;
  placeholder?: string;
}

export const Select = <T,>({
  options,
  value,
  getOptionLabel,
  getOptionValue,
  onChange,
  placeholder,
}: SelectProps<T>) => (
  <select
    value={value ? getOptionValue(value) : ''}
    onChange={(e) => onChange(options.find(o => getOptionValue(o) === e.target.value) ?? null)}
  >
    {placeholder && <option value="">{placeholder}</option>}
    {options.map((option) => (
      <option key={getOptionValue(option)} value={getOptionValue(option)}>
        {getOptionLabel(option)}
      </option>
    ))}
  </select>
);

// Usage — TypeScript infers T as User
<Select<User>
  options={users}
  value={selectedUser}
  getOptionLabel={(u) => u.name}
  getOptionValue={(u) => u.id}
  onChange={setSelectedUser}
/>
```

---

### API Response Types

Define typed interfaces for all API responses in `src/types/`. Never use `any` for API data.

```tsx
// types/api.ts
export interface ApiResponse<T> {
  data: T;
  meta: {
    total: number;
    page: number;
    pageSize: number;
  };
}

export interface User {
  id: string;
  name: string;
  email: string;
  role: 'admin' | 'member' | 'viewer';
  createdAt: string;
}

export type CreateUserDto = Omit<User, 'id' | 'createdAt'>;
export type UpdateUserDto = Partial<CreateUserDto>;

// services/user-service.ts
export const fetchUsers = async (): Promise<ApiResponse<User[]>> => {
  const response = await fetch('/api/users');
  return response.json() as Promise<ApiResponse<User[]>>;
};
```

---

### Typing Hooks

Explicitly type the return value of custom hooks that return multiple values.

```tsx
interface UseCounterReturn {
  count: number;
  increment: () => void;
  decrement: () => void;
  reset: () => void;
}

export const useCounter = (initialValue = 0): UseCounterReturn => {
  const [count, setCount] = useState(initialValue);

  return {
    count,
    increment: useCallback(() => setCount(c => c + 1), []),
    decrement: useCallback(() => setCount(c => c - 1), []),
    reset: useCallback(() => setCount(initialValue), [initialValue]),
  };
};
```

## React Type Utilities

| Utility | Use case |
|---------|----------|
| `React.ReactNode` | Component `children` prop type |
| `React.ReactElement` | A single React element (not null/string) |
| `React.CSSProperties` | Inline `style` prop objects |
| `React.ComponentProps<typeof C>` | Extract props from an existing component |
| `React.PropsWithChildren<Props>` | Add `children` to an existing props interface |
| `React.RefObject<T>` | Typed ref from `useRef` |
| `React.EventHandler<E>` | Generic event handler type |
| `React.ChangeEvent<HTMLInputElement>` | Input `onChange` event |

## Rules

- Never use `any` — use `unknown` if the type is genuinely unknown, then narrow
- Prefer `interface` over `type` for component props and object shapes
- Use `type` for union types, mapped types, and utility types
- Do not use `React.FC` as it adds an implicit `children` prop — type props explicitly
- Use TypeScript path aliases (`@/`) to avoid long relative import chains
- Export prop interfaces alongside components so consumers can extend them
- Use `as const` for string literal arrays to infer narrow literal types

- Avoid using `object` or `{}` instead of a specific interface
- Avoid casting with `as` to silence type errors instead of fixing the root cause
- Avoid not typing async function return values (TypeScript infers `Promise<any>`)
- Avoid using `React.FC` without realizing it adds implicit `children: ReactNode`
- Avoid forgetting `displayName` on components wrapped with `forwardRef` or `memo`

---
