# .NET Best Practices Report Generator

> Consolidate all analysis findings into a comprehensive best practices report using the standard template format.

---

## REPORT GENERATION INSTRUCTIONS

1.  **GATHER ALL ANALYSIS OUTPUTS**:
    Collect findings from all analysis rules:
    - Testing Quality Analysis
    - Architecture Compliance Analysis
    - SOLID Compliance and Cyclomatic Complexity Analysis
    - Code Standards Analysis
    - DTO Validation Analysis
    - Error Handling Analysis

2.  **COMPUTE OVERALL SCORE**:
    Calculate weighted average:
    - Testing Quality: 18%
    - Architecture Compliance: 20%
    - SOLID Compliance: 20%
    - Code Standards: 14%
    - DTO Validation: 12%
    - Error Handling: 16%

3.  **PRIORITIZE FINDINGS**:
    Rank all violations by:
    - Critical: Security issues, data exposure, broken functionality
    - High: Architecture violations, missing validations
    - Medium: Code standards, documentation gaps
    - Low: Style issues, minor improvements

4.  **GENERATE REPORT USING TEMPLATE**:
    Use the template at:
     "assets/report-template.md"

## REPORT SECTIONS

1. EXECUTIVE SUMMARY
   - Overall Score with label (Strong/Fair/Weak)
   - Top 3 Strengths
   - Top 3 Critical Issues
   - Immediate Action Items

2. SCORE BREAKDOWN
   - Testing Quality: XX/100 (Label)
   - Architecture Compliance: XX/100 (Label)
   - SOLID Compliance: XX/100 (Label)
   - Code Standards: XX/100 (Label)
   - DTO Validation: XX/100 (Label)
   - Error Handling: XX/100 (Label)

3. TESTING QUALITY
   - Unit Test Coverage (xUnit)
   - Integration Test Patterns (WebApplicationFactory/Testcontainers)
   - Assertion Quality (FluentAssertions)
   - Mock Usage (Moq/NSubstitute)
   - Violations and Recommendations

4. ARCHITECTURE COMPLIANCE
   - Layer Separation (Domain/Application/Infrastructure/Api)
   - Dependency Injection Lifetimes
   - Module/DI Registration Organization
   - Repository Pattern
   - Violations and Recommendations

5. SOLID COMPLIANCE
   - SRP (God-object constructors, oversized methods)
   - OCP (type-switch chains carrying business logic)
   - LSP (overrides throwing NotImplementedException)
   - ISP (fat interfaces, partially-unimplemented implementations)
   - DIP (`new ConcreteClass()` bypassing an existing abstraction)
   - Cyclomatic Complexity (CA1502) and Class Coupling (CA1506) — forced-analyzer measurement
   - Violations and Recommendations

6. CODE STANDARDS
   - C# / Nullable Reference Types Compliance
   - Naming Conventions
   - Records vs Classes, Pattern Matching
   - Controller Thinness
   - Violations and Recommendations

7. DTO VALIDATION
   - Validation Coverage (Data Annotations / FluentValidation)
   - Create/Update/Response DTO Separation
   - Sensitive Field Exclusion
   - Entity-to-DTO Mapping
   - Violations and Recommendations

8. ERROR HANDLING
   - Exception Usage
   - Centralized Handling (`IExceptionHandler`/middleware)
   - `ProblemDetails` Consistency
   - Logging Practices
   - Violations and Recommendations

9. PRIORITIZED RECOMMENDATIONS
   - Critical (Must Fix)
   - High Priority
   - Medium Priority
   - Low Priority (Nice to Have)

10. EVIDENCE INDEX
    - All file references organized by category

## OUTPUT REQUIREMENTS

- Use Markdown format (# headers, **bold**, `backtick` file paths)
- Include all file references with line numbers
- Provide specific, actionable recommendations
- Include code examples where helpful
- Score each section 0-100 with label
- List violations with severity level
