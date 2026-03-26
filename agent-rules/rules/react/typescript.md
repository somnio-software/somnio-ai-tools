---
description: TypeScript integration patterns for React including component typing, generics, and type utilities.
globs: **/*.tsx,**/*.ts
alwaysApply: false
---

# React TypeScript Integration

How to write type-safe React components, hooks, and utilities using TypeScript best practices.

## Purpose

Strong typing in React:
- Catches prop mismatches and missing required values at compile time
- Provides IDE autocomplete for component APIs
- Documents the contract between components without separate docs

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

#### Good

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

#### Bad

```tsx
// ❌ Inline object type — not reusable, no name for error messages
const UserCard = ({ id, name, email }: { id: any; name: any; email: any }) => (
  <div>{name}</div>
);
```

---

### Extending HTML Element Props

When building primitive UI components (Button, Input), extend the underlying HTML element's props to pass through native attributes.

#### Good

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

#### Good

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

#### Good

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

#### Good

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

#### Bad

```tsx
// ❌ any defeats the purpose of TypeScript
const fetchUsers = async (): Promise<any> => {
  const response = await fetch('/api/users');
  return response.json();
};
```

---

### Typing Hooks

Explicitly type the return value of custom hooks that return multiple values.

#### Good

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

## Best Practices

- Never use `any` — use `unknown` if the type is genuinely unknown, then narrow
- Prefer `interface` over `type` for component props and object shapes
- Use `type` for union types, mapped types, and utility types
- Do not use `React.FC` as it adds an implicit `children` prop — type props explicitly
- Use TypeScript path aliases (`@/`) to avoid long relative import chains
- Export prop interfaces alongside components so consumers can extend them
- Use `as const` for string literal arrays to infer narrow literal types

## Common Mistakes

- Using `object` or `{}` instead of a specific interface
- Casting with `as` to silence type errors instead of fixing the root cause
- Not typing async function return values (TypeScript infers `Promise<any>`)
- Using `React.FC` without realizing it adds implicit `children: ReactNode`
- Forgetting `displayName` on components wrapped with `forwardRef` or `memo`
