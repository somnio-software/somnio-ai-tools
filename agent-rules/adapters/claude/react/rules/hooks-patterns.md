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
