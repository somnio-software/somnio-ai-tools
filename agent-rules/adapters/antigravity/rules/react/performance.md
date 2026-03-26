# React Performance Optimization

How to optimize React application performance through memoization, code splitting, and rendering strategies.

## Purpose

Performance optimization should be **data-driven**, not speculative. Premature optimization:
- Adds complexity without measurable benefit
- Creates stale closure bugs when dependencies are wrong
- Makes code harder to maintain

**Profile first** using React DevTools Profiler, then optimize the specific bottleneck.

## Patterns

### React.memo

Prevent re-renders when a parent re-renders but the component's props have not changed. Use only for components with expensive renders or those that receive stable props but re-render too often.

#### Good

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

#### Bad

```tsx
// ❌ Memoizing trivially cheap components adds overhead without benefit
export const Label = React.memo(({ text }: { text: string }) => <span>{text}</span>);

// ❌ Custom comparator that ignores important props
export const UserRow = React.memo(UserRowComponent, () => true); // always skip re-render
```

---

### useCallback

Stabilize function references passed as props to memoized child components. Without `useCallback`, a new function reference is created on every render, causing `React.memo` to be ineffective.

#### Good

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

#### Bad

```tsx
const UserList = ({ users }: { users: User[] }) => {
  // ❌ New function reference on every render — React.memo on UserRow is useless
  const handleDelete = (id: string) => api.deleteUser(id);

  return (
    <ul>
      {users.map(user => (
        <UserRow key={user.id} user={user} onDelete={handleDelete} />
      ))}
    </ul>
  );
};
```

---

### useMemo

Memoize expensive computations so they only recalculate when their dependencies change.

#### Good

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

#### Bad

```tsx
// ❌ Memoizing a trivial operation — overhead is greater than the computation
const greeting = useMemo(() => `Hello, ${name}!`, [name]);

// ❌ Missing dependency — stale values when products changes
const filteredProducts = useMemo(() => filterProducts(products), [filters]);
```

---

### Code Splitting with React.lazy

Split large bundles by route so the initial page load only downloads what is needed.

#### Good

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

#### Bad

```tsx
// ❌ All pages imported at the top — entire app bundled into one chunk
import Dashboard from '@/pages/Dashboard';
import Settings from '@/pages/Settings';
import Reports from '@/pages/Reports';
```

---

### List Virtualization

For lists with hundreds or thousands of items, only render what is visible in the viewport using `react-window` or `react-virtual`.

#### Good

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

#### Bad

```tsx
// ❌ Rendering 10,000 DOM nodes — causes layout thrashing and slow scroll
const UserList = ({ users }: { users: User[] }) => (
  <ul>
    {users.map(user => <UserRow key={user.id} user={user} />)}
  </ul>
);
```

---

### Stable Keys

Always use stable, unique identifiers as `key` props. Index-based keys cause incorrect DOM reconciliation when the list is reordered or filtered.

#### Good

```tsx
{users.map(user => <UserRow key={user.id} user={user} />)}
```

#### Bad

```tsx
// ❌ Index as key — breaks when items are reordered/inserted/removed
{users.map((user, index) => <UserRow key={index} user={user} />)}

// ❌ Random key — forces remount on every render
{users.map(user => <UserRow key={Math.random()} user={user} />)}
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

## Best Practices

- Use **React DevTools Profiler** before adding any optimization
- Profile in production mode — development mode is intentionally slower
- Lazy-load routes by default in all new projects
- Virtualize any list that can grow beyond 100 items
- Keep `key` props stable and unique across the list
- Add `displayName` to components wrapped in `memo` or `forwardRef` for DevTools readability
