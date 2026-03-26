# React TypeScript Standards Analysis

> Analyze TypeScript strictness, component prop typing, React utility type usage, and type safety patterns.

---

Goal: Analyze the React codebase for TypeScript strict mode compliance,
correct component typing patterns, and React-specific type usage.

STANDARDS SOURCE (local):
- `agent-rules/rules/react/typescript.md`

To resolve the absolute path: find the directory containing
`skills/react-best-practices/SKILL.md`, go up two levels to reach
the somnio-ai-tools repository root, then read the file above.

INSTRUCTIONS:
1. USE the `Read` tool to read the local standards file listed above.
2. Proceed with the analysis below using strict adherence to those rules.

ANALYSIS TARGETS:
1.  **TypeScript Configuration**:
    *   Check `tsconfig.json` has `"strict": true`.
    *   Verify `"noImplicitAny": true` (covered by strict).
    *   Check `"strictNullChecks": true` (covered by strict).
    *   Verify path aliases are configured (`@/components`, etc.).
    *   Flag `skipLibCheck: false` unless justified.

2.  **Component Props Typing**:
    *   Check component props defined with `interface` (not inline
        type literals for complex props).
    *   Verify props interfaces use `ComponentNameProps` naming.
    *   Check HTML element extension:
        `interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement>`
    *   Verify `forwardRef` components are correctly typed with
        `React.forwardRef<RefType, PropsType>`.
    *   Check `displayName` is set on `forwardRef` components.

3.  **No `any` Usage**:
    *   **CRITICAL**: Flag all occurrences of `any` type.
    *   Check for `unknown` used correctly with type narrowing.
    *   Verify API response types are defined (never use `any` for
        fetch responses).
    *   Flag `as any` type assertions.
    *   Check for implicit `any` from untyped function parameters.

4.  **Generic Components**:
    *   Check for components that should be generic but use `any`
        or overly broad types.
    *   Verify generic type parameters have meaningful constraint
        (`<T extends object>` not just `<T>`).
    *   Check reusable list/table/select components are generic.

5.  **React Utility Types**:
    *   Check correct usage of `React.ReactNode` vs `React.ReactElement`
        for children props.
    *   Verify `React.FC` is NOT used (prefer explicit return types).
    *   Check `React.CSSProperties` used for style props.
    *   Verify `React.ChangeEvent<HTMLInputElement>` used for event
        handlers.
    *   Check `React.Dispatch<React.SetStateAction<T>>` for setState
        props.

6.  **Interface vs Type Rules**:
    *   Check `interface` used for object shapes that can be extended.
    *   Check `type` used for unions, intersections, and mapped types.
    *   Verify no mixing (using `type` for component props that need
        extension).

OUTPUT FORMAT:
*   **TypeScript Score**: (1-10) based on strict compliance.
*   **Violations**:
    *   `[Any Usage]` [file:line]: Explicit `any` type found.
    *   `[Props Issue]` [file:line]: Missing interface for component
        props.
    *   `[Utility Type]` [file:line]: React.FC used, should be
        explicit return type.
    *   `[Config Issue]` [tsconfig.json]: Missing strict option.
*   **Recommendations**: Specific typing improvements per violation.
