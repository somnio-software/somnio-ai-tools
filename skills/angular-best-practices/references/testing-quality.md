# Angular Testing Quality Analysis

> Analyze testing code quality, naming conventions, and best practices (TestBed, Karma/Jasmine or Jest, HttpClientTestingModule, async testing) based on somnio-software standards.

---

Goal: Analyze the quality, structure, and best practices of modern
Angular test files (`*.spec.ts`).

STANDARDS SOURCE (local-first, then live):
- local: `agent-rules/rules/angular/testing.md`
  raw:   https://raw.githubusercontent.com/somnio-software/somnio-ai-tools/main/agent-rules/rules/angular/testing.md

RESOLUTION ORDER (per rule, never assume the file is on disk):
1. If `agent-rules/` exists in the repo, USE the `Read` tool on the local path above.
2. If `agent-rules/` is absent (standalone install), USE the `WebFetch` tool on the matching raw URL.

INSTRUCTIONS:
1. Resolve EACH rule above via the order in RESOLUTION ORDER.
2. Proceed with the analysis below using strict adherence to those rules.

ANALYSIS TARGETS:
1.  **Test Naming Conventions**:
    *   Check for verbose, descriptive `it(...)` names (e.g. 'should render
        the submit button when the form is valid' vs 'works').
    *   Ensure names explain the "what" and expected outcome.
    *   Verify `describe` blocks group tests logically
        (by component/service/behavior).

2.  **TestBed Configuration & Isolation**:
    *   Verify `TestBed.configureTestingModule` declares/imports only what
        the unit under test needs; flag importing the whole `AppModule`.
    *   Check dependencies are mocked/stubbed (spy services, stub
        components) rather than pulling real implementations.
    *   Verify `ComponentFixture` is used and `fixture.detectChanges()` is
        called before asserting rendered output.
    *   For services, prefer testing the class directly or via a minimal
        TestBed with providers; flag over-heavy setups.

3.  **Assertion Quality**:
    *   Check for specific Jasmine/Jest matchers (`toBe`, `toEqual`,
        `toHaveBeenCalledWith`, `toBeTruthy`) with meaningful expectations.
    *   Verify EVERY test has at least one assertion (`expect`).
    *   Flag tests with no assertions (pass-through tests).
    *   Check DOM assertions query via `DebugElement`/`By.css` or component
        harnesses rather than brittle nativeElement string matching.

4.  **Test Structure & Atomicity**:
    *   **Arrange-Act-Assert**: Check tests follow AAA with clear
        separation.
    *   **Single Purpose**: Check each test verifies one behavior.
    *   **Grouping**: Verify `describe()` organizes tests (e.g. by state or
        interaction).
    *   **Setup/Teardown**: Ensure `beforeEach` builds the TestBed and
        spies are reset between tests.

5.  **Async Testing**:
    *   Check async control uses `fakeAsync` + `tick()`/`flush()` or
        `waitForAsync`, not arbitrary real timeouts.
    *   Verify `fixture.whenStable()` is awaited where needed.
    *   Flag missing `flush`/`tick` that leaves timers/microtasks pending.
    *   Flag `done()` callbacks where `fakeAsync`/async-await is clearer.

6.  **HTTP & Dependency Mocking**:
    *   Check `HttpClientTestingModule` + `HttpTestingController` are used
        to mock HTTP; verify `httpMock.verify()` in `afterEach`.
    *   Verify router/store/other Angular deps use their testing modules
        (`RouterTestingModule`, `provideMockStore`, etc.).
    *   Ensure spies are created with `jasmine.createSpyObj` / `jest.fn()`
        and configured per test, not globally mutated.
    *   Flag manual mock objects that do not match the real interface.

OUTPUT FORMAT:
*   **Overview**: Total spec files analyzed, quality score (1-10).
*   **Violations**: List specific file paths and lines violating the
    above rules.
    *   Format: `[File](path) : [Line] - [Issue Description]`
*   **Compliance**: Highlight good examples found in the codebase.
*   **Recommendations**: Specific refactoring suggestions for violations.
