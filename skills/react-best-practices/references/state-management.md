# React State Management Analysis

> Analyze state management patterns for correct tool selection, Context API structure, Zustand slices, and TanStack Query usage.

---

Goal: Analyze the React codebase for appropriate state management
decisions, correct library usage, and state scope correctness.

STANDARDS SOURCE (local-first, then live):
- local: `agent-rules/rules/react/state-management.md`
  raw:   https://raw.githubusercontent.com/somnio-software/somnio-ai-tools/main/agent-rules/rules/react/state-management.md

RESOLUTION ORDER (per rule, never assume the file is on disk):
1. If `agent-rules/` exists in the repo, USE the `Read` tool on the local path above.
2. If `agent-rules/` is absent (standalone install), USE the `WebFetch` tool on the matching raw URL.

INSTRUCTIONS:
1. Resolve EACH rule above via the order in RESOLUTION ORDER.
2. Proceed with the analysis below using strict adherence to those rules.

ANALYSIS TARGETS:
1.  **State Scope Decisions**:
    *   Check for component-local state that is unnecessarily in global
        store (over-sharing).
    *   Check for deeply drilled props that should be in Context or
        Zustand (under-sharing).
    *   Verify the decision tree: local useState → Context API →
        TanStack Query → Zustand is followed.
    *   Flag server-fetched data stored in Zustand/Redux instead of
        TanStack Query.

2.  **Context API Usage**:
    *   Check Context is used for global UI state: theme, auth,
        locale, feature flags.
    *   Verify Context is NOT used for server-fetched data
        (use TanStack Query instead).
    *   Check for Context value memoization with `useMemo` to prevent
        unnecessary re-renders.
    *   Flag monolithic Context that should be split by domain.
    *   Verify consumer hooks (`useTheme`, `useAuth`) are exported
        instead of raw `useContext`.

3.  **Zustand Patterns**:
    *   Check Zustand is used for complex client-side state shared
        across many components.
    *   Verify slice-based store organization (not a single flat store
        for everything).
    *   Check selectors are used to subscribe to specific slices
        (avoid full store subscriptions).
    *   Flag Zustand used for server/async state (should be TanStack
        Query).
    *   Verify `immer` middleware for nested state updates where used.

4.  **TanStack Query Usage**:
    *   Check `useQuery` is used for all server-fetched data.
    *   Verify `useMutation` is used for server mutations with
        cache invalidation.
    *   Check query keys follow consistent naming convention.
    *   Flag manual fetch state (loading/error/data booleans) that
        should be TanStack Query.
    *   Verify `staleTime` and `cacheTime` are configured appropriately.

5.  **Anti-Pattern Detection**:
    *   Flag `useEffect` + `useState` for data fetching (use TanStack
        Query).
    *   Flag prop drilling more than 2-3 levels (suggest Context or
        composition).
    *   Flag Redux Toolkit usage where Zustand would be simpler.
    *   Check for unnecessary re-renders from Context value changes.

OUTPUT FORMAT:
*   **State Management Score**: (1-10) based on scope decisions.
*   **Violations**:
    *   `[Scope Issue]` [file:line]: Server state in Zustand/Context.
    *   `[Context Issue]` [file:line]: Monolithic Context structure.
    *   `[Fetch Pattern]` [file:line]: Manual fetch instead of TanStack
        Query.
    *   `[Drill Issue]` [file:line]: Prop drilling beyond 3 levels.
*   **Recommendations**: Specific refactoring advice per violation.
