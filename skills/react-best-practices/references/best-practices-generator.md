# React Best Practices Report Generator

> Consolidate all analysis findings into a comprehensive best practices report using the standard template format.

---

## REPORT GENERATION INSTRUCTIONS

1.  **GATHER ALL ANALYSIS OUTPUTS**:
    Collect findings from all analysis rules:
    - Testing Quality Analysis
    - Component Architecture Analysis
    - Hooks Patterns Analysis
    - State Management Analysis
    - Performance Analysis
    - TypeScript Standards Analysis

2.  **COMPUTE OVERALL SCORE**:
    Calculate weighted average:
    - Testing Quality: 20%
    - Component Architecture: 25%
    - Hooks Patterns: 15%
    - State Management: 15%
    - Performance: 15%
    - TypeScript Standards: 10%

3.  **PRIORITIZE FINDINGS**:
    Rank all violations by:
    - Critical: Rules of Hooks violations, missing type safety, broken
      accessibility in tests
    - High: Architecture violations, server state in client store,
      missing async patterns
    - Medium: Code standards, memoization gaps, documentation
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
   - Component Architecture: XX/100 (Label)
   - Hooks Patterns: XX/100 (Label)
   - State Management: XX/100 (Label)
   - Performance: XX/100 (Label)
   - TypeScript Standards: XX/100 (Label)

3. TESTING QUALITY
   - RTL Query Usage
   - Async Testing Patterns
   - Custom Hook Testing
   - Assertion Quality
   - Violations and Recommendations

4. COMPONENT ARCHITECTURE
   - Folder Structure
   - Component Size
   - Composition Patterns
   - Export Conventions
   - Violations and Recommendations

5. HOOKS PATTERNS
   - Rules of Hooks Compliance
   - Custom Hook Design
   - Effect Management
   - Stability Patterns
   - Violations and Recommendations

6. STATE MANAGEMENT
   - State Scope Decisions
   - Context API Structure
   - Zustand/TanStack Query Usage
   - Anti-Pattern Detection
   - Violations and Recommendations

7. PERFORMANCE
   - Memoization Coverage
   - Code Splitting
   - List Rendering Keys
   - Re-render Anti-Patterns
   - Violations and Recommendations

8. TYPESCRIPT STANDARDS
   - Configuration
   - Component Typing
   - No Any Coverage
   - React Utility Types
   - Violations and Recommendations

9. PRIORITIZED RECOMMENDATIONS
   - Critical (Must Fix)
   - High Priority
   - Medium Priority
   - Low Priority (Nice to Have)

10. EVIDENCE INDEX
    - All file references organized by category

## OUTPUT REQUIREMENTS

- Use PLAIN TEXT format only (no markdown)
- Include all file references with line numbers
- Provide specific, actionable recommendations
- Include code examples where helpful
- Score each section 0-100 with label
- List violations with severity level
