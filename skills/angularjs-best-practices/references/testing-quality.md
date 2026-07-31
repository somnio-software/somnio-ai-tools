# AngularJS Testing Quality Analysis

> Analyze testing code quality, naming conventions, and best practices (Karma/Jasmine specs, angular-mocks, $httpBackend, assertions) based on somnio-software standards.

---

Goal: Analyze the quality, structure, and best practices of AngularJS
spec files (Karma/Jasmine + angular-mocks).

STANDARDS SOURCE (local-first, then live):
- local: `agent-rules/rules/angularjs/testing.md`
  raw:   https://raw.githubusercontent.com/somnio-software/somnio-ai-tools/main/agent-rules/rules/angularjs/testing.md

RESOLUTION ORDER (per rule, never assume the file is on disk):
1. If `agent-rules/` exists in the repo, USE the `Read` tool on the local path above.
2. If `agent-rules/` is absent (standalone install), USE the `WebFetch` tool on the matching raw URL.

INSTRUCTIONS:
1. Resolve EACH rule above via the order in RESOLUTION ORDER.
2. Proceed with the analysis below using strict adherence to those rules.

ANALYSIS TARGETS:
1.  **Spec Naming Conventions**:
    *   Check for verbose, descriptive names (e.g., 'should render
        submit button when form is valid' vs 'works').
    *   Ensure names explain the "what" and expected outcome.
    *   Verify `describe` blocks group specs logically
        (by controller/service/directive/behavior).

2.  **angular-mocks Bootstrap**:
    *   Enforce use of `angular.mock.module` / `module('app')` to load the
        module under test and `inject()` to resolve dependencies.
    *   Controllers instantiated via `$controller('Name', { $scope, deps })`;
        directives compiled via `$compile(element)($scope)` + `$scope.$digest()`.
    *   Flag specs that instantiate controllers/services with `new` or by
        reaching into internals instead of the injector.
    *   Verify a single module bootstrap per `describe` (not per `it`).

3.  **Assertion Quality**:
    *   Check for specific Jasmine matchers (e.g., `toBe`, `toEqual`,
        `toHaveBeenCalledWith`, `toBeDefined`).
    *   Verify EVERY spec has at least one assertion (`expect`).
    *   Flag specs with no assertions (pass-through specs).
    *   Check for proper async handling (`$httpBackend.flush()`,
        `$scope.$digest()`, `$timeout.flush()`, promise resolution).

4.  **Spec Structure & Atomicity**:
    *   **Arrange-Act-Assert**: Check that specs follow AAA pattern
        with clear separation.
    *   **Single Purpose**: Check that specs verify one behavior per
        `it` case.
    *   **Grouping**: Verify usage of `describe()` to organize specs
        (e.g., by controller state or user interaction).
    *   **Setup/Teardown**: Ensure `beforeEach` for module/injector setup
        and `afterEach` for `$httpBackend.verifyNoOutstandingExpectation()` /
        `verifyNoOutstandingRequest()`.

5.  **Async & HTTP Testing**:
    *   Check `$httpBackend.when`/`.expect` used to mock `$http`, followed by
        `$httpBackend.flush()` (not real network).
    *   Verify `$scope.$digest()` / `$rootScope.$apply()` used to resolve
        watches and promises deterministically.
    *   Ensure `$timeout.flush()` / `$interval.flush()` drain pending async.
    *   Flag specs that assert before flushing (never-resolving promises).

6.  **Directive & Component Testing**:
    *   Check directives/components tested through `$compile` + rendered DOM,
        or via the component controller (`$componentController`).
    *   Verify isolate-scope bindings are asserted on the compiled element,
        not on stubbed internals.
    *   Ensure `$scope.$digest()` runs after binding changes.

7.  **Mocking Patterns**:
    *   Check for `$provide.value` / `$provide.factory` / Jasmine spies
        (`jasmine.createSpy`, `spyOn`) to replace collaborators.
    *   Verify module mocks defined in `beforeEach`, not inside `it`.
    *   Ensure spies are reset between specs (`beforeEach` re-creates them).
    *   Flag manual mock objects that don't match the real service interface.

OUTPUT FORMAT:
*   **Overview**: Total spec files analyzed, quality score (1-10).
*   **Violations**: List specific file paths and lines violating the
    above rules.
    *   Format: `[File](path) : [Line] - [Issue Description]`
*   **Compliance**: Highlight good examples found in the codebase.
*   **Recommendations**: Specific refactoring suggestions for violations.
