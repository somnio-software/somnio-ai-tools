# NestJS Testing Quality Analysis

> Analyze testing code quality, naming conventions, and best practices (assertions, mocks, structure) based on somnio-software standards.

---

Goal: Analyze the quality, structure, and best practices of NestJS
test files.

STANDARDS SOURCE (local):
- `agent-rules/rules/nestjs/testing-unit.md`
- `agent-rules/rules/nestjs/testing-integration.md`

To resolve the absolute path: find the directory containing
`skills/nestjs-best-practices/SKILL.md`, go up two levels to reach
the somnio-ai-tools repository root, then read the files above.

INSTRUCTIONS:
1. USE the `Read` tool to read the local standards files listed above.
2. Proceed with the analysis below using strict adherence to those rules.

ANALYSIS TARGETS:
1.  **Test Naming Conventions**:
    *   Check for verbose, descriptive names (e.g., 'should return
        user when found' vs 'works').
    *   Ensure names explain the "what" and expected outcome.
     *   Verify `describe` blocks group tests logically
       (by method/feature).

2.  **Assertion Quality**:
    *   Check for specific matchers (e.g., `toHaveBeenCalledWith`
        instead of just `toHaveBeenCalled`).
    *   Verify EVERY test has at least one assertion (`expect`).
    *   Flag tests with no assertions (pass-through tests).
    *   Check for proper async handling (`await expect(...).rejects`).

3.  **Test Structure & Atomicity**:
    *   **Arrange-Act-Assert**: Check that tests follow AAA pattern
        with clear separation.
    *   **Single Purpose**: Check that tests verify one concept per
        test case.
    *   **Grouping**: Verify usage of `describe()` to organize tests
        (e.g., by method or service).
    *   **Setup/Teardown**: Ensure `beforeEach` is used for test setup
        and mocks are cleared between tests.

4.  **Unit Test Specifics**:
     *   Verify all dependencies are mocked using `jest.fn()` or mock
       objects.
    *   Check for `@nestjs/testing` TestingModule usage.
    *   Ensure services/controllers are properly instantiated.
    *   Verify mock implementations match interface contracts.

5.  **Integration Test Specifics (*.integration.spec.ts)**:
    *   Check for proper database setup and teardown.
    *   Verify test data isolation with unique identifiers.
    *   Ensure `afterAll` cleanup of test data.
    *   Check for `supertest` usage for HTTP testing.

6.  **Mocking Patterns**:
    *   Check for mock object definition outside `beforeEach`.
    *   Verify `jest.clearAllMocks()` in `beforeEach`.
    *   Ensure mock return values are set appropriately.

OUTPUT FORMAT:
*   **Overview**: Total tests analyzed, quality score (1-10).
* **Violations**: List specific file paths and lines violating the
  above rules.
    *   Format: `[File](path) : [Line] - [Issue Description]`
*   **Compliance**: Highlight good examples found in the codebase.
*   **Recommendations**: Specific refactoring suggestions for violations.
