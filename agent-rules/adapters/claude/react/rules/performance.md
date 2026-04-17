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
