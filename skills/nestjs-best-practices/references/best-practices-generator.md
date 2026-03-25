# NestJS Best Practices Report Generator

> Consolidate all analysis findings into a comprehensive best practices report using the standard template format.

---

## REPORT GENERATION INSTRUCTIONS

1.  **GATHER ALL ANALYSIS OUTPUTS**:
    Collect findings from all analysis rules:
    - Testing Quality Analysis
    - Architecture Compliance Analysis
    - Code Standards Analysis
    - DTO Validation Analysis
    - Error Handling Analysis

2.  **COMPUTE OVERALL SCORE**:
    Calculate weighted average:
    - Testing Quality: 20%
    - Architecture Compliance: 25%
    - Code Standards: 20%
    - DTO Validation: 15%
    - Error Handling: 20%

3.  **PRIORITIZE FINDINGS**:
    Rank all violations by:
    - Critical: Security issues, data exposure, broken functionality
    - High: Architecture violations, missing validations
    - Medium: Code standards, documentation gaps
    - Low: Style issues, minor improvements

4.  **GENERATE REPORT USING TEMPLATE**:
    Use the template at:
     "assets/report-template.txt"

## REPORT SECTIONS

1. EXECUTIVE SUMMARY
   - Overall Score with label (Strong/Fair/Weak)
   - Top 3 Strengths
   - Top 3 Critical Issues
   - Immediate Action Items

2. SCORE BREAKDOWN
   - Testing Quality: XX/100 (Label)
   - Architecture Compliance: XX/100 (Label)
   - Code Standards: XX/100 (Label)
   - DTO Validation: XX/100 (Label)
   - Error Handling: XX/100 (Label)

3. TESTING QUALITY
   - Unit Test Coverage
   - Integration Test Patterns
   - Assertion Quality
   - Mock Usage
   - Violations and Recommendations

4. ARCHITECTURE COMPLIANCE
   - Layer Separation
   - Dependency Injection
   - Module Organization
   - Repository Pattern
   - Violations and Recommendations

5. CODE STANDARDS
   - TypeScript Compliance
   - Naming Conventions
   - Function Design
   - NestJS Patterns
   - Violations and Recommendations

6. DTO VALIDATION
   - Validation Coverage
   - Swagger Documentation
   - Transformation Patterns
   - Security Patterns
   - Violations and Recommendations

7. ERROR HANDLING
   - Exception Usage
   - Error Enums/Maps
   - Exception Filters
   - Logging Practices
   - Violations and Recommendations

8. PRIORITIZED RECOMMENDATIONS
   - Critical (Must Fix)
   - High Priority
   - Medium Priority
   - Low Priority (Nice to Have)

9. EVIDENCE INDEX
   - All file references organized by category

## OUTPUT REQUIREMENTS

- Use PLAIN TEXT format only (no markdown)
- Include all file references with line numbers
- Provide specific, actionable recommendations
- Include code examples where helpful
- Score each section 0-100 with label
- List violations with severity level
