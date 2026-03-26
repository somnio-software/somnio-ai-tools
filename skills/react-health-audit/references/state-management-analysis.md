# React State Management Analysis

> Analyze state management approach, library choices, server/client state separation, and Context API structure.

---

Goal: Analyze the React project's state management approach to
evaluate library selection, state scope decisions, and overall
state architecture quality.

ANALYSIS TARGETS:

1. **State Management Library Detection**:
   - Check `package.json` dependencies for:
     * `zustand` — lightweight client state
     * `@reduxjs/toolkit` + `react-redux` — Redux Toolkit
     * `jotai` — atomic state
     * `recoil` — atomic state
     * `@tanstack/react-query` — server state
     * `swr` — server state
     * `react-query` (v3, old) — server state
   - Note if ONLY `useState`/`useContext` is used (may be appropriate
     for small projects)

2. **Context API Usage**:
   - Find all Context definitions:
     `grep -r "createContext" src/ --include="*.tsx" --include="*.ts"
     -l | wc -l`
   - Check for appropriate use cases (theme, auth, locale)
   - Flag Context used for server data (should be TanStack Query)
   - Check for monolithic context (single context for many concerns)

3. **Zustand Usage** (if present):
   - Find store files:
     `find src/ -name "*.store.ts" -o -name "store.ts"
     -o -name "*Store.ts" | head -20`
   - Check for slice-based organization
   - Verify selectors are used for subscriptions
   - Note if devtools middleware is configured

4. **Redux Toolkit Usage** (if present):
   - Find slice files:
     `find src/ -name "*Slice.ts" -o -name "*.slice.ts" | wc -l`
   - Check for `createSlice` and `createAsyncThunk` patterns
   - Verify RTK Query is used instead of manual async thunks where
     server state is involved
   - Note if plain Redux is used (not RTK) — recommend migration

5. **TanStack Query / SWR Usage** (if present):
   - Find query hook usage:
     `grep -r "useQuery\|useMutation\|useInfiniteQuery" src/
     --include="*.tsx" --include="*.ts" | wc -l`
   - Check `QueryClient` configuration (staleTime, cacheTime/gcTime)
   - Verify query keys follow consistent pattern
   - Flag manual fetch state (useEffect + useState) alongside TanStack
     Query (inconsistency)

6. **Anti-Pattern Detection**:
   - Count `useEffect` + `useState` pairs for data fetching:
     `grep -r "useEffect" src/ --include="*.tsx" | wc -l` combined
     with `grep -r "setLoading\|setError\|setData" src/ | wc -l`
   - Check for prop drilling (props passed through 3+ component levels)
   - Note if global state stores simple local state (over-engineering)

OUTPUT FORMAT:

Provide structured analysis:
- Client state approach: [useState-only/Context/Zustand/Redux/Jotai]
- Server state approach: [TanStack Query/SWR/Manual/None]
- Context providers count: [XX]
- Zustand/Redux store files: [XX]
- TanStack Query hooks usage: [XX calls]
- Manual data fetch patterns detected: [XX]
- Context structure: [Appropriate/Monolithic/Missing]
- Anti-patterns found: [list]
- Risks identified
- Recommendations

SCORING GUIDANCE:

Strong (85-100):
- Clear separation of server state (TanStack Query) and client state
- Appropriate library for project size
- Context used only for global UI state
- No manual fetch state patterns

Fair (70-84):
- Some server state via TanStack Query but inconsistent
- Context used for some server state
- Minor anti-patterns detected

Weak (0-69):
- All state in global store including server data
- Manual fetch patterns throughout
- Prop drilling issues
- No server state library despite complex data needs
