# React Hooks Patterns Analysis

> Analyze hooks usage for Rules of Hooks compliance, custom hook design, and effect management best practices.

---

Goal: Analyze the React codebase for correct hooks usage, custom hook
extraction patterns, and effect dependency management.

STANDARDS SOURCE (local):
- `agent-rules/rules/react/hooks-patterns.md`

To resolve the absolute path: find the directory containing
`skills/react-best-practices/SKILL.md`, go up two levels to reach
the somnio-ai-tools repository root, then read the file above.

INSTRUCTIONS:
1. USE the `Read` tool to read the local standards file listed above.
2. Proceed with the analysis below using strict adherence to those rules.

ANALYSIS TARGETS:
1.  **Rules of Hooks Compliance**:
    *   **CRITICAL**: Check for hooks called conditionally (inside if,
        loops, nested functions).
    *   **CRITICAL**: Check for hooks called inside non-React functions
        (regular functions, event handlers).
    *   Verify `eslint-plugin-react-hooks` is configured in ESLint.
    *   Flag any `// eslint-disable-next-line react-hooks/rules-of-hooks`
        comments.

2.  **Custom Hook Extraction**:
    *   Check for stateful logic repeated across 2+ components that
        should be extracted into a custom hook.
    *   Verify all custom hooks start with `use` prefix.
    *   Check custom hooks are placed in `hooks/` directory or
        colocated with feature.
    *   Verify hooks do one thing (single responsibility).

3.  **useEffect Patterns**:
    *   **CRITICAL**: Check for missing dependency arrays (infinite loops).
    *   Check for stale closure issues (missing dependencies).
    *   Verify cleanup functions returned for subscriptions, timers,
        and event listeners.
    *   Flag useEffect used for derived state (should use useMemo).
    *   Flag useEffect used for event handler setup that could be
        direct handlers.

4.  **useCallback and useMemo Stability**:
    *   Check `useCallback` wraps functions passed as props to
        memoized child components.
    *   Verify `useMemo` wraps expensive computations (not trivial
        operations).
    *   Flag missing dependency arrays in useCallback/useMemo.
    *   Flag over-use of useCallback/useMemo without evidence of
        performance need.

5.  **State Management Hooks**:
    *   Check for `useState` with objects that should use `useReducer`
        (complex state transitions).
    *   Verify `useReducer` is used for state with multiple sub-values
        or complex logic.
    *   Check for `useState` updater form when new state depends on
        previous state.
    *   Flag direct mutation of state objects.

6.  **Common Custom Hooks**:
    *   Check for patterns that should be extracted:
        - Form state → `useForm`
        - Data fetching → `useFetch` or TanStack Query
        - Debounce → `useDebounce`
        - Local storage → `useLocalStorage`
        - Event listeners → `useEventListener`
        - Media queries → `useMediaQuery`
    *   Verify extracted hooks are reusable and not tightly coupled
        to specific components.

OUTPUT FORMAT:
*   **Hooks Score**: (1-10) based on compliance and patterns.
*   **Violations**:
    *   `[Rules Violation]` [file:line]: Conditional hook call.
    *   `[Effect Issue]` [file:line]: Missing cleanup or stale closure.
    *   `[Stability Issue]` [file:line]: Unstabilized callback causing
        re-renders.
    *   `[Extraction Opportunity]` [file:line]: Logic should be a
        custom hook.
*   **Recommendations**: Specific refactoring advice per violation.
