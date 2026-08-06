# .NET Testing Quality Analysis

> Analyze xUnit test code quality, naming conventions, and best practices (assertions, mocks, structure, async correctness) based on somnio-software standards.

---

Goal: Analyze the quality, structure, and best practices of ASP.NET Core
Web API test files (unit and integration) written with xUnit.

STANDARDS SOURCE (local-first, then live):
- local: `agent-rules/rules/dotnet/testing-unit.md`
  raw:   https://raw.githubusercontent.com/somnio-software/somnio-ai-tools/main/agent-rules/rules/dotnet/testing-unit.md
- local: `agent-rules/rules/dotnet/testing-integration.md`
  raw:   https://raw.githubusercontent.com/somnio-software/somnio-ai-tools/main/agent-rules/rules/dotnet/testing-integration.md

RESOLUTION ORDER (per rule, never assume the file is on disk):
1. If `agent-rules/` exists in the repo, USE the `Read` tool on the local path above.
2. If `agent-rules/` is absent (standalone install), USE the `WebFetch` tool on the matching raw URL.

INSTRUCTIONS:
1. Resolve EACH rule above via the order in RESOLUTION ORDER.
2. Proceed with the analysis below using strict adherence to those rules.
3. This is a MICRO-level audit: judge individual test files and test
   methods, not test-project infrastructure or CI configuration.

ANALYSIS TARGETS:

1.  **Test Naming Conventions** (`testing-unit.md`):
    *   Verify every `[Fact]`/`[Theory]` follows
        `MethodName_Scenario_ExpectedBehavior`.
    *   Flag vague names (`Test1`, `Should_Work`, `GetUser_Works`) that
        don't state the scenario or expected outcome.
    *   Verify `[Theory]`/`[InlineData]`/`[MemberData]`/`[ClassData]` is
        used instead of near-duplicate `[Fact]` methods that only differ
        by input values.
    *   Check that test classes are named `<SubjectUnderTest>Tests` and
        grouped one class per subject.

2.  **Arrange-Act-Assert Structure**:
    *   Verify each test body has a visible AAA shape, ideally separated
        by blank lines between phases.
    *   Flag interleaved arrange/act/assert (setup, invocation, and
        assertions mixed together with no clear separation).
    *   Flag multiple unrelated behaviors asserted in a single test
        instead of split into separate `[Fact]`s.

3.  **Assertion Quality (FluentAssertions)**:
    *   Flag raw `Assert.Equal`/`Assert.True`/`Assert.False`/
        `Assert.Null` where FluentAssertions (`Should().Be(...)`,
        `Should().BeEquivalentTo(...)`, `Should().ThrowAsync<T>()`) would
        give richer failure diagnostics, especially on object graphs.
    *   Verify every test has at least one assertion; flag pass-through
        tests with no `Should()`/`Assert` call.
    *   Verify exception-path tests assert the specific exception type
        (and message/condition where relevant), not a generic
        `Exception`/`Should().ThrowAsync<Exception>()`.
    *   Check async assertions use `await act.Should().ThrowAsync<T>()`,
        never a synchronous `Assert.Throws` wrapped around a
        `Task`-returning call (it will not observe the exception).

4.  **Mock Setup Quality (Moq / NSubstitute)**:
    *   Verify only true external dependencies are mocked (repositories,
        HTTP/gRPC clients, message publishers, clocks, `ILogger<T>` when
        its calls are asserted).
    *   **CRITICAL**: Flag mocking the class under test (SUT) — this
        defeats the point of the test.
    *   Flag mocking plain DTOs/value objects instead of constructing
        real instances.
    *   Flag mocking pure, dependency-free collaborators (e.g. a stateless
        calculator) that could just be used directly.
    *   Verify mock return values/behaviors are configured with
        `Setup`/`Returns` (Moq) or `Returns`/`Arg.Any<T>()`
        (NSubstitute) matching the interface contract, not left to
        return unconfigured defaults where the test depends on a
        specific value.
    *   Check `MockBehavior.Strict` (or explicit `VerifyNoOtherCalls()`)
        is used where an unexpected call on a collaborator would itself
        indicate a bug (e.g. a payment gateway that must not be touched
        on a validation failure); loose mocks are acceptable for
        incidental dependencies.

5.  **Test Isolation**:
    *   **CRITICAL**: Flag shared mutable `static` fields referenced by
        more than one test — they create execution-order dependencies
        and break parallel test runs.
    *   Flag `IClassFixture<T>`/`ICollectionFixture<T>` used to share
        *mutable domain state* between tests instead of genuinely
        expensive, read-only setup (e.g. a database schema, a
        `WebApplicationFactory`).
    *   Verify instance-level test state is created fresh (constructor or
        `beforeEach`-equivalent instance field initializer) so tests are
        safe to run in any order.

6.  **Async Test Correctness**:
    *   **CRITICAL**: Flag `.Result` or `.Wait()` called on a `Task`
        inside a test — both can deadlock and bury the real exception in
        an `AggregateException`.
    *   Flag an `async Task` test method whose body never `await`s
        anything meaningful, or a non-async test method that should be
        `async Task` because it exercises async production code.
    *   Verify `[Fact]`/`[Theory]` methods that return `Task` are not
        declared `async void` (exceptions in `async void` are not
        observed by the test runner).

7.  **Integration Test Specifics (`testing-integration.md`,
    typically `*IntegrationTests.cs` / `*ApiTests.cs`)**:
    *   Verify `WebApplicationFactory<TEntryPoint>` (or a custom
        subclass) drives the test through the real HTTP pipeline
        (routing, filters, model binding, middleware) rather than the
        test re-implementing controller logic by calling
        service/repository methods directly.
    *   Flag integration tests that replace the real DI-registered
        dependencies with unit-test-style mocks for the very component
        under test, rather than only swapping true externals (e.g. an
        external payment provider) via `WithWebHostBuilder`/
        `ConfigureTestServices`.
    *   Verify test data isolation: unique identifiers per test run, no
        assumptions about pre-existing rows, and cleanup
        (`IAsyncLifetime.DisposeAsync`, `IClassFixture` teardown, or a
        transaction rollback) so tests can run repeatedly and in
        parallel.
    *   Verify `HttpClient` calls use `CreateClient()` from the factory
        and assert on `HttpResponseMessage` status code and deserialized
        body, not on internal service state.

8.  **Over-Asserting on Implementation Details (anti-pattern)**:
    *   Flag tests that verify exact mock call counts/order
        (`Times.Once`, `Received(1)`, `VerifyNoOtherCalls()`) on
        collaborators whose invocation is incidental rather than part of
        the contract being tested — this breaks on valid refactors that
        don't change observable behavior.
    *   Distinguish this from legitimate call verification where the
        interaction itself is the behavior under test (e.g. "an order
        confirmation email must be sent").

OUTPUT FORMAT:

Produce a list of violation records, one per finding:

*   **File**: relative file path
*   **Line**: best-effort line number (or line range) of the offending
    code
*   **Standard Violated**: exact filename — `testing-unit.md` or
    `testing-integration.md`
*   **Severity**: `Critical` | `Major` | `Minor`
    *   `Critical`: mocking the SUT, `.Result`/`.Wait()` deadlock risk,
        shared mutable static state causing order-dependent failures,
        integration tests that bypass the real HTTP pipeline entirely
    *   `Major`: vague test names, missing/weak assertions, wrong mock
        scope (mocking DTOs or pure collaborators), missing test data
        isolation in integration tests, `async void` test methods
    *   `Minor`: raw `Assert.*` instead of FluentAssertions where a
        richer diff would help, minor AAA separation issues,
        over-verification of incidental mock calls
*   **Suggested Fix**: one line, concrete and actionable

Example:

```
- File: tests/Orders/OrderServiceTests.cs
  Line: 42
  Standard Violated: testing-unit.md
  Severity: Critical
  Suggested Fix: Stop mocking OrderService (the SUT); mock only IOrderRepository/IPaymentGateway and construct the real OrderService.
```

After the violation list, include:
*   **Compliance**: notable examples of tests that already follow the
    standards well (naming, AAA, mocking discipline).
*   **Recommendations**: concrete refactoring suggestions grouped by
    theme (naming, assertions, mocking, isolation, async, integration).

SCORING GUIDANCE:

Score this dimension 0-100 based on the density and severity of
violations relative to the number of test files analyzed:

*   **Strong (85-100)**: Consistent `MethodName_Scenario_ExpectedBehavior`
    naming, clear AAA structure, FluentAssertions used throughout, mocks
    limited to true externals, no shared mutable state, all async tests
    correctly awaited, integration tests exercise the real pipeline via
    `WebApplicationFactory`. At most a few Minor findings.
*   **Fair (70-84)**: Core practices mostly followed but with recurring
    gaps — some raw `Assert.*` usage, occasional vague test names, a few
    over-specified mock verifications, or integration tests with weak
    data isolation. No Critical findings.
*   **Weak (0-69)**: One or more Critical findings (SUT mocked,
    `.Result`/`.Wait()` in tests, shared static state, integration tests
    that bypass the HTTP pipeline), or Major findings pervasive across
    most test files.
