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
