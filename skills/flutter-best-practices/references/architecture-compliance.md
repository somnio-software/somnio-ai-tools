# Flutter Architecture Compliance Analysis

> Analyze codebase for adherence to Layered Architecture, dependency rules, and separation of concerns.

---

Goal: Analyze the Flutter codebase for strict adherence to Layered
Architecture and Separation of Concerns.

STANDARDS SOURCE:
- https://raw.githubusercontent.com/somnio-software/cursor-rules/main/.cursor/rules/flutter/flutter-architecture.mdc
- https://raw.githubusercontent.com/somnio-software/cursor-rules/main/.cursor/rules/flutter/flutter-ai-rules.mdc

INSTRUCTIONS:
 1.  **SCOPE**: You must analyze **ALL** Dart files in the project to
     insure architecture compliance.
 2.  **DISCOVERY**: Execute `echo "Dart files to analyze: $(find . \
     -type f -name "*.dart" -not -path "*/.*" -not -name "*.g.dart" \
     -not -name "*.freezed.dart" 2>/dev/null | wc -l)"` to count source
     files. Then use `glob_file_search` with pattern `**/*.dart` to find
     all Dart files for analysis (excluding generated files).
 3.  **STANDARDS**: USE the `read_url_content` tool to fetch the latest
     standards from the URLs above.
 4.  **EFFICIENCY**: When iterating through files, read 3-5 files per
     response using parallel tool calls. Do NOT read one file per
     response — this causes massive context accumulation. Group files
     by directory when possible.
 5.  **ANALYSIS**: Iterate through **EACH** file found using
     glob_file_search in step 2:
    a. Read and analyze for layer boundary violations.

LAYER DEFINITIONS:
1.  **Presentation Layer**: Widgets, Pages, Screens.
2.  **Business Logic Layer**: BLoCs, Cubits, ViewModels, UseCases.
3.  **Repository Layer**: Repositories (Data aggregation/composition).
4.  **Data Layer**: DataProviders, API Clients, DTOs.

ANALYSIS TARGETS:
1.  **Layer Boundary Violations**:
    *   **CRITICAL**: BLoC/Cubit MUST NOT access `ApiClient`, `http`,
        or `Dio` directly. They MUST use a Repository.
    *   **CRITICAL**: Widgets SHOULD NOT contain complex logic or
        direct data fetching. They should dispatch events/call methods
        on BLoC/Cubit.
    *   **CRITICAL**: Repositories SHOULD NOT return DTOs to the
        Business Layer (unless DTO is the domain model, but domain
        models preferred).

2.  **Dependency Injection**:
    *   Check for proper dependency injection (e.g., passing
        Repositories to BLoCs).
    *   Flag rigid dependencies (e.g., `final repo =
        UserRepository();` inside a BLoC instead of constructor
        injection).

3.  **Repository Pattern**:
    *   Verify Repositories abstract the data sources.
    *   Check for "One Repo, One Responsibility" principle.

4.  **Composition over Inheritance**:
    *   Flag excessive class inheritance (extends) where composition
        (mixins/properties) would be better.

OUTPUT FORMAT:
*   **Architecture Score**: (1-10) based on layer separation.
*   **Violations**:
    *   `[Layer Violation]` [file:line]: Description of the leak
        (e.g., "BLoC accessing Dio directly").
    *   `[DI Issue]` [file:line]: Hardcoded dependency.
    *   `[Logic in UI]` [file:line]: Complex logic in Widget build method.
* **Recommendations**: Specific refactoring advice for correcting layer
violations.
