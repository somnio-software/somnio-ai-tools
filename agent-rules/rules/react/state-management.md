---
description: React state management patterns including Context API, Zustand, and TanStack Query for server state.
globs: **/*.tsx,**/*.ts
alwaysApply: false
---

# React State Management

How to choose and implement the right state management approach based on scope and data type.

## Purpose

State management decisions directly impact application performance and maintainability. The right choice depends on:
- **Scope**: local to a component vs. shared across the app
- **Data type**: UI state vs. server/async data
- **Update frequency**: rarely changed config vs. frequently updated counters

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

#### Good

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

#### Bad

```tsx
// ❌ One mega context for everything — any update re-renders every consumer
const AppContext = createContext({
  user: null,
  theme: 'light',
  cart: [],
  notifications: [],
  // ...
});

// ❌ No invariant guard — silent undefined errors at runtime
export const useApp = () => useContext(AppContext);
```

---

### Zustand (Client State)

Use Zustand for shared client state that changes frequently or spans many components. Zustand avoids unnecessary re-renders by letting components subscribe to specific slices.

#### Good

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

#### Bad

```tsx
// ❌ Subscribing to the entire store — component re-renders on every store change
const { items, addItem, removeItem, total } = useCartStore();
```

---

### TanStack Query (Server State)

Use TanStack Query for all server-fetched data. It handles caching, background refetching, pagination, and synchronization.

#### Good

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

#### Bad

```tsx
// ❌ Manual fetch management — no caching, no background sync, no deduplication
const [user, setUser] = useState(null);
const [isLoading, setIsLoading] = useState(false);

useEffect(() => {
  setIsLoading(true);
  fetch(`/api/users/${userId}`)
    .then(r => r.json())
    .then(data => { setUser(data); setIsLoading(false); });
}, [userId]);
```

## Library Selection Guide

| Scenario | Recommended Solution |
|----------|---------------------|
| Local component state | `useState` / `useReducer` |
| Shared UI state (theme, locale, auth) | Context API |
| Server/async data | TanStack Query |
| Complex shared client state | Zustand |
| Large enterprise app with devtools | Redux Toolkit |

## Best Practices

- **Start local**: default to `useState` and only introduce a library when state genuinely needs to be shared
- Keep Context providers close to where they are needed — not always at the app root
- Split Zustand stores by domain (cart, auth, ui) rather than having one global store
- Always set `staleTime` in TanStack Query — the default of 0 causes excessive refetching
- Never store server data in Zustand or Context alongside TanStack Query — let TQ own the cache
- Avoid storing derived values in state — compute them during render or with `useMemo`

## Common Mistakes

- Using Context for frequently updated state (causes app-wide re-renders)
- Storing remote API data in `useState` instead of TanStack Query
- Subscribing to the full Zustand store (use selectors to subscribe to slices)
- Forgetting to memoize Context value with `useMemo` (causes all consumers to re-render on every parent render)
