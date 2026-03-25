# Flutter Testing Quality Analysis

> Analyze testing code quality, naming conventions, and best practices (assertions, mocks, structure) based on somnio-software standards.

---

Goal: Analyze the quality, structure, and best practices of Flutter
test files.

STANDARDS SOURCE:
- https://raw.githubusercontent.com/somnio-software/cursor-rules/main/.cursor/rules/flutter/flutter-testing.mdc
- https://raw.githubusercontent.com/somnio-software/cursor-rules/main/.cursor/rules/flutter/bloc-test.mdc

INSTRUCTIONS:
1.  **SCOPE**: You must analyze **ALL** test files in the project.
 2.  **DISCOVERY**: Execute `echo "Test files to analyze: $(find . \
     -type f -name "*_test.dart" -not -path "*/.*" 2>/dev/null | \
     wc -l)"` to count test files. Then use `glob_file_search` with
     pattern `**/*_test.dart` to find all test files for analysis.
 3.  **STANDARDS**: USE the `read_url_content` tool to fetch the latest
     standards from the URLs above.
 4.  **EFFICIENCY**: When iterating through files, read 3-5 files per
     response using parallel tool calls. Do NOT read one file per
     response — this causes massive context accumulation. Group files
     by directory when possible.
 5.  **ANALYSIS**: Iterate through **EACH** file found using
     glob_file_search in step 2:
    a. Read the file content.
    b. Analyze strictly against the standards.
    c. Accumulate findings.

ANALYSIS TARGETS:
1.  **Test Naming Conventions**:
    *   Check for verbose, descriptive names (e.g., 'renders
        $WidgetName when state is X' vs 'renders').
    *   Ensure names explain the "what" and "when".

2.  **Assertion Quality**:
    *   Check for specific matchers (e.g., `expect(list,
        contains(item))` instead of `expect(list.contains(item),
        true)`).
    *   Verify EVERY test has at least one assertion (`expect` or
        `verify`).
    *   Flag tests with no assertions (pass-through tests).

3.  **Test Structure & Atomicity**:
    *   **Single Purpose**: Check that tests verify one concept per
        test case.
    *   **Grouping**: Verify usage of `group()` to organize tests
        (e.g., by method or widget).
    *   **Setup/Teardown**: Ensure `setUp` and `tearDown` are used
        within groups, not globally if possible.
    *   **Mocking**: Check for usage of private mocks (e.g., `class
        _MockRepo extends Mock...`) to avoid namespace pollution.

4.  **Bloc Testing Specifics (if bloc_test imported)**:
    *   Verify Structure: `group('BlocName')` -> `group('EventName')`
        -> `blocTest`.
    *   Check for `build` function usage.
    *   Ensure `act` and `expect` are present.
    *   Verify repository interactions are verified if dependencies
        exist.

5.  **Widget Testing Specifics**:
    *   Check for `find.byType()` usage over `find.byKey()` where
        appropriate (less brittle).
    *   Verify `pump()` or `pumpAndSettle()` usage patterns.

OUTPUT FORMAT:
*   **Overview**: Total tests analyzed, quality score (1-10).
* **Violations**: List specific file paths and lines violating the
  above rules.
    *   Format: `[File](path) : [Line] - [Issue Description]`
*   **Compliance**: Highlight good examples found in the codebase.
*   **Recommendations**: Specific refactoring suggestions for violations.
