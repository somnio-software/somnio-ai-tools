# React Performance Analysis

> Analyze memoization usage, code splitting, list rendering, and identify performance anti-patterns.

---

Goal: Analyze the React codebase for performance optimization patterns,
identify premature or missing memoization, and detect common
performance anti-patterns.

STANDARDS SOURCE (local):
- `agent-rules/rules/react/performance.md`

To resolve the absolute path: find the directory containing
`skills/react-best-practices/SKILL.md`, go up two levels to reach
the somnio-ai-tools repository root, then read the file above.

INSTRUCTIONS:
1. USE the `Read` tool to read the local standards file listed above.
2. Proceed with the analysis below using strict adherence to those rules.

ANALYSIS TARGETS:
1.  **React.memo Usage**:
    *   Check `React.memo` is used with profiling evidence, not
        speculatively on all components.
    *   Verify memoized components receive stable props (otherwise
        memo is ineffective).
    *   Flag `React.memo` on components that always receive new
        object/array props without stabilization.
    *   Check for `React.memo` with custom comparison functions
        that have incorrect logic.

2.  **useCallback and useMemo**:
    *   Check `useCallback` wraps functions passed to memoized
        child components.
    *   Verify `useMemo` is used for expensive computations
        (filtering large arrays, complex transforms).
    *   Flag `useMemo` on trivial operations (string formatting,
        simple math).
    *   Check dependency arrays are correct in both hooks.
    *   Flag missing `useCallback` on event handlers passed to
        memoized children.

3.  **Code Splitting**:
    *   Check `React.lazy` is used for route-level components.
    *   Verify `Suspense` boundaries are placed appropriately with
        meaningful fallback UI.
    *   Check that heavy third-party libraries are lazy-loaded where
        possible.
    *   Flag large component trees loaded eagerly that could be split.

4.  **List Rendering**:
    *   **CRITICAL**: Check for array index used as `key` in lists
        where items can reorder or filter.
    *   Verify stable, unique keys are used (IDs from data).
    *   Check for long lists (100+ items) without virtualization
        (`react-window` or `react-virtual`).
    *   Flag in-render array operations that should be memoized
        (`.filter`, `.sort`, `.map` chains).

5.  **Re-render Anti-Patterns**:
    *   Flag inline object/array creation in JSX props
        (e.g., `style={{ color: 'red' }}` in hot paths).
    *   Flag inline function creation in JSX props without
        `useCallback`.
    *   Check for Context values not memoized causing tree-wide
        re-renders.
    *   Flag state updates triggering full component tree re-renders.

OUTPUT FORMAT:
*   **Performance Score**: (1-10) based on pattern compliance.
*   **Violations**:
    *   `[Memo Issue]` [file:line]: Ineffective React.memo usage.
    *   `[Key Issue]` [file:line]: Array index used as key.
    *   `[Split Opportunity]` [file:line]: Large component that
        should be lazy-loaded.
    *   `[Render Issue]` [file:line]: Inline object causing
        unnecessary re-renders.
*   **Recommendations**: Specific optimization suggestions per violation.
