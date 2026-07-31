# Angular Best Practices Report Generator

> Consolidate all analysis findings into a comprehensive best practices report using the standard template format.

---

## REPORT GENERATION INSTRUCTIONS

1.  **GATHER ALL ANALYSIS OUTPUTS**:
    Collect findings from all analysis rules:
    - Testing Quality Analysis
    - Component Architecture Analysis
    - Lifecycle & DI Patterns Analysis
    - Services & State Management Analysis
    - Change Detection & Performance Analysis
    - TypeScript Standards Analysis

2.  **COMPUTE OVERALL SCORE**:
    Calculate weighted average:
    - Testing Quality: 20%
    - Component Architecture: 25%
    - Lifecycle & DI Patterns: 15%
    - Services & State Management: 15%
    - Change Detection & Performance: 15%
    - TypeScript Standards: 10%

3.  **PRIORITIZE FINDINGS**:
    Rank all violations by:
    - Critical: unmanaged subscriptions (memory leaks), missing type safety,
      HttpClient in components, `*ngFor` without `trackBy`
    - High: architecture violations, business logic in components/templates,
      missing OnPush on hot components, missing async handling in tests
    - Medium: code standards, template method calls, documentation gaps
    - Low: style issues, minor improvements

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
   - Component Architecture: XX/100 (Label)
   - Lifecycle & DI Patterns: XX/100 (Label)
   - Services & State Management: XX/100 (Label)
   - Change Detection & Performance: XX/100 (Label)
   - TypeScript Standards: XX/100 (Label)

3. TESTING QUALITY
   - TestBed Configuration & Isolation
   - Async Testing Patterns
   - HTTP & Dependency Mocking
   - Assertion Quality
   - Violations and Recommendations

4. COMPONENT ARCHITECTURE
   - Folder / Module Structure
   - Component Size
   - Smart/Dumb Composition Patterns
   - Declaration & Export Conventions
   - Violations and Recommendations

5. LIFECYCLE & DI PATTERNS
   - Lifecycle Interface Compliance
   - Subscription Cleanup
   - Dependency Injection Patterns
   - Reusable Logic Extraction
   - Violations and Recommendations

6. SERVICES & STATE MANAGEMENT
   - State Scope Decisions
   - HttpClient Centralization & Interceptors
   - RxJS / Signals Discipline
   - Store Library / Anti-Pattern Detection
   - Violations and Recommendations

7. CHANGE DETECTION & PERFORMANCE
   - OnPush Adoption
   - Template Evaluation Cost
   - List Rendering (trackBy / virtual scroll)
   - Lazy Loading & Bundle Budgets
   - Violations and Recommendations

8. TYPESCRIPT STANDARDS
   - Configuration (strict / strictTemplates)
   - Component I/O Typing
   - No Any Coverage
   - Typed Forms & Angular Type Utilities
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
