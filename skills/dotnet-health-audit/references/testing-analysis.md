# .NET Health Audit Testing Analysis

> Find and classify test projects, identify the test framework, assertion/mocking libraries, and test quality signals for ASP.NET Core Web API projects.

---

Goal: Find and classify all test projects, identify the testing framework stack in use, and
assess test count, naming conventions, and coverage to produce a Testing health score.

EFFICIENCY REQUIREMENTS:
- Target: ≤ 8 total tool calls for this entire analysis
- List all `*.csproj` files and `[Fact]`/`[Theory]` occurrences via batched grep instead of
  opening test files individually
- Read 3-5 `.csproj` files per tool call using parallel reads
- Reuse the Code Coverage % already measured by the test-coverage step (passed in from Step 0)
  instead of re-running coverage collection

1. TEST PROJECT DETECTION:
   - Find `*.csproj` files under projects named `*.Tests`, `*.UnitTests`, `*.IntegrationTests`,
     or containing `*Test*` in the project or folder name
   - Confirm each is a real test project by checking for a `PackageReference` to
     `Microsoft.NET.Test.Sdk` in the `.csproj`
   - Note the project's target framework (`<TargetFramework>net8.0</TargetFramework>`) and
     whether it references the main API project (`<ProjectReference Include="..\..\src\...\*.csproj" />`)

2. TEST FRAMEWORK DETECTION:
   - xUnit: `PackageReference` to `xunit` and `xunit.runner.visualstudio` (the modern .NET default
     and most common choice for ASP.NET Core projects)
   - NUnit: `PackageReference` to `NUnit` and `NUnit3TestAdapter`
   - MSTest: `PackageReference` to `MSTest.TestFramework` and `MSTest.TestAdapter`
   - Identify which framework(s) are used; flag mixed frameworks across test projects as an
     inconsistency

3. TEST CLASSIFICATION (Unit vs Integration):
   - Unit tests: mock-heavy, fast, isolated — look for `Moq` or `NSubstitute` package references
     and test classes that construct the system under test directly with mocked dependencies
   - Integration tests: look for
     * `Microsoft.AspNetCore.Mvc.Testing` and `WebApplicationFactory<TEntryPoint>` usage
       (in-process API testing against the real DI container/pipeline)
     * `Testcontainers` / `Testcontainers.PostgreSql` / `Testcontainers.MsSql` package references
       (ephemeral real database instances)
     * `Microsoft.EntityFrameworkCore.InMemory` or SQLite in-memory provider usage (lighter-weight
       DB substitute, note as a middle ground between unit and full integration)
   - Classify each test project as primarily Unit, Integration, or Mixed based on the above signals

4. ASSERTION LIBRARY:
   - Check for `FluentAssertions` package reference and its usage style (`result.Should().Be(...)`)
   - Absent FluentAssertions, note reliance on raw framework assertions (`Assert.Equal`,
     `Assert.True` for xUnit; `Assert.That` for NUnit/MSTest)
   - Flag inconsistent assertion style if some test projects use FluentAssertions and others don't

5. MOCKING LIBRARY:
   - Check for `Moq` package reference (most common in the .NET ecosystem)
   - Check for `NSubstitute` package reference (alternative with a more fluent syntax)
   - Flag if both are present across the codebase — signals inconsistency, pick one
   - Note if no mocking library is present in unit test projects that clearly need it (constructor
     dependencies not otherwise fakeable)

6. TEST COUNT / RATIO:
   - Grep for `[Fact]` and `[Theory]` attributes (xUnit) or `[Test]`/`[TestCase]` (NUnit) or
     `[TestMethod]` (MSTest) across all test projects to get an approximate total test count
   - Compute the ratio of test files (`*Tests.cs`/`*Test.cs`) to source files (`.cs` files in the
     main API project(s), excluding generated code and `Migrations/`)
   - A ratio well below 1 test file per 2-3 source files may indicate thin coverage — cross-check
     against the actual Code Coverage % rather than judging on file ratio alone

7. COVERAGE INTEGRATION:
   - Pull the Code Coverage % already measured by the test-coverage step (Step 0 output) — do not
     re-collect coverage in this step
   - The Testing section score MUST incorporate this coverage number alongside the structural
     signals above (framework consistency, assertion/mocking hygiene, naming) — a well-organized
     test suite with low coverage should not score Strong

8. NAMING CONVENTIONS:
   - Spot-check a sample of test method names via grep for the
     `MethodName_Scenario_ExpectedBehavior` pattern (e.g.
     `CreateUser_WithDuplicateEmail_ReturnsConflict`)
   - Note deviations: generic names (`Test1`, `ItWorks`), or names missing the scenario/expected
     segments
   - Report compliance as an approximate percentage from the sample, not an exhaustive scan

OUTPUT FORMAT:

Provide structured analysis:
- Test frameworks detected: [xUnit/NUnit/MSTest] (per project if mixed)
- Unit test project(s) found: [list with project paths]
- Integration test project(s) found: [list with project paths]
- Assertion library: [FluentAssertions/raw Assert/Mixed]
- Mocking library: [Moq/NSubstitute/Both/None]
- Approximate test count: [Number] ([Fact]/[Theory]/[Test]/[TestMethod] combined)
- Test-file-to-source-file ratio: [X:X]
- Naming convention compliance: [XX]% (sample size: [N])
- Code Coverage: [XX]% (pulled from test-coverage step)
- Risks identified
- Recommendations

SCORING GUIDANCE:

Strong (85-100):
- xUnit (or a single consistent framework) used throughout, with FluentAssertions and a single
  consistent mocking library
- Clear separation of unit tests (mock-heavy) and integration tests
  (`WebApplicationFactory`/Testcontainers)
- Code Coverage ≥ 80% and naming convention compliance high in the sampled set
- Test count scales reasonably with source file count

Fair (70-84):
- A test framework is used consistently but assertion or mocking libraries are inconsistent
  across projects
- Unit and integration tests exist but the boundary is blurred (e.g. integration-style tests
  living in a "Unit" project)
- Code Coverage in the 50-79% range
- Some naming convention deviations in the sampled set

Weak (0-69):
- No dedicated test project found, or test project exists but references no test framework
  correctly
- Only one test type present (unit-only with no integration coverage of API endpoints, or
  vice versa)
- Code Coverage below 50%, or coverage data unavailable/not integrated in CI
- Mixed frameworks/mocking libraries across the codebase with no naming convention discipline
