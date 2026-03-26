# React Testing Quality Analysis

> Analyze testing code quality, naming conventions, and best practices (RTL queries, assertions, hooks testing) based on somnio-software standards.

---

Goal: Analyze the quality, structure, and best practices of React
test files.

STANDARDS SOURCE (local):
- `agent-rules/rules/react/testing.md`

To resolve the absolute path: find the directory containing
`skills/react-best-practices/SKILL.md`, go up two levels to reach
the somnio-ai-tools repository root, then read the file above.

INSTRUCTIONS:
1. USE the `Read` tool to read the local standards file listed above.
2. Proceed with the analysis below using strict adherence to those rules.

ANALYSIS TARGETS:
1.  **Test Naming Conventions**:
    *   Check for verbose, descriptive names (e.g., 'should render
        submit button when form is valid' vs 'works').
    *   Ensure names explain the "what" and expected outcome.
    *   Verify `describe` blocks group tests logically
        (by component/feature/behavior).

2.  **RTL Query Priority**:
    *   Enforce query priority: getByRole > getByLabelText >
        getByPlaceholderText > getByText > getByTestId.
    *   Flag overuse of `getByTestId` when semantic queries exist.
    *   Check that `screen` is used (not destructured from `render`).
    *   Verify accessible queries are preferred.

3.  **Assertion Quality**:
    *   Check for specific jest-dom matchers (e.g., `toBeInTheDocument`,
        `toHaveValue`, `toBeDisabled`).
    *   Verify EVERY test has at least one assertion (`expect`).
    *   Flag tests with no assertions (pass-through tests).
    *   Check for proper async handling (`findBy` queries, `waitFor`).

4.  **Test Structure & Atomicity**:
    *   **Arrange-Act-Assert**: Check that tests follow AAA pattern
        with clear separation.
    *   **Single Purpose**: Check that tests verify one behavior per
        test case.
    *   **Grouping**: Verify usage of `describe()` to organize tests
        (e.g., by component state or user interaction).
    *   **Setup/Teardown**: Ensure `beforeEach` for test setup and
        mocks cleared between tests.

5.  **Async Testing**:
    *   Check `findBy*` queries used for async elements (not `waitFor`
        wrapping `getBy`).
    *   Verify `userEvent` is preferred over `fireEvent` for user
        interactions.
    *   Ensure `await userEvent.setup()` pattern is used correctly.
    *   Flag improper `act()` wrapping of async operations.

6.  **Custom Hook Testing**:
    *   Check `renderHook` used to test custom hooks in isolation.
    *   Verify hooks are NOT tested through component UI when direct
        testing is possible.
    *   Ensure `act()` wraps state updates in hook tests.

7.  **Mocking Patterns**:
    *   Check for `jest.mocked()` usage for TypeScript-safe mocking.
    *   Verify module mocks defined at module level, not inside tests.
    *   Ensure `jest.clearAllMocks()` or `jest.resetAllMocks()` in
        `beforeEach`.
    *   Flag manual mock objects that don't match actual interfaces.

OUTPUT FORMAT:
*   **Overview**: Total test files analyzed, quality score (1-10).
*   **Violations**: List specific file paths and lines violating the
    above rules.
    *   Format: `[File](path) : [Line] - [Issue Description]`
*   **Compliance**: Highlight good examples found in the codebase.
*   **Recommendations**: Specific refactoring suggestions for violations.
