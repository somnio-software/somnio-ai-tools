# Python Best Practices Report Generator

> Consolidate all analysis findings into a comprehensive best practices report using the standard template format.

---

## REPORT GENERATION INSTRUCTIONS

1.  **GATHER ALL ANALYSIS OUTPUTS**:
    Collect findings from all analysis rules:
    - Typing Analysis
    - Code Style Analysis
    - Function Design Analysis
    - Data Validation Analysis
    - Error Handling Analysis
    - Module Structure Analysis
    - Testing Quality Analysis

2.  **COMPUTE OVERALL SCORE**:
    Calculate weighted average:
    - Typing: 15%
    - Code Style: 10%
    - Function Design: 15%
    - Data Validation: 15%
    - Error Handling: 15%
    - Module Structure: 10%
    - Testing Quality: 20%

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
   - Typing: XX/100 (Label)
   - Code Style: XX/100 (Label)
   - Function Design: XX/100 (Label)
   - Data Validation: XX/100 (Label)
   - Error Handling: XX/100 (Label)
   - Module Structure: XX/100 (Label)
   - Testing Quality: XX/100 (Label)

3. TYPING
   - Type Annotation Coverage
   - Use of `typing` / `collections.abc` constructs
   - mypy / pyright compliance
   - Generic and Protocol usage
   - Violations and Recommendations

4. CODE STYLE
   - PEP 8 Compliance
   - Naming Conventions
   - Docstring Presence and Quality
   - Import Organization
   - Violations and Recommendations

5. FUNCTION DESIGN
   - Single Responsibility
   - Argument Count and Defaults
   - Return Type Consistency
   - Side-Effect Isolation
   - Violations and Recommendations

6. DATA VALIDATION
   - Input Validation Coverage (Pydantic / dataclasses / manual)
   - Schema Enforcement
   - Boundary and Edge-Case Handling
   - Security Patterns
   - Violations and Recommendations

7. ERROR HANDLING
   - Exception Hierarchy Usage
   - Bare `except` / Over-broad Catches
   - Logging Practices
   - Context Manager Usage
   - Violations and Recommendations

8. MODULE STRUCTURE
   - Package Layout (`__init__.py`, subpackage depth)
   - Circular Import Risks
   - Cohesion and Coupling
   - Dependency Management (`pyproject.toml` / `requirements.txt`)
   - Violations and Recommendations

9. TESTING QUALITY
   - Unit Test Coverage
   - Integration and End-to-End Test Patterns
   - Assertion Quality
   - Fixture and Mock Usage
   - Violations and Recommendations

10. PRIORITIZED RECOMMENDATIONS
    ### 🔴 Critical
    - Must-fix items (security, data exposure, broken functionality)

    ### 🟠 High Priority
    - Architecture violations, missing validations

    ### 🟡 Medium Priority
    - Code standards, documentation gaps

    ### 🟢 Low Priority
    - Style issues, minor improvements

11. EVIDENCE INDEX
    - Test files: `test_*.py` / `*_test.py`
    - Module/Service files: `*.py`
    - Model files (Pydantic models, dataclasses, ORM models)
    - Package init files: `__init__.py`

## OUTPUT REQUIREMENTS

- Use Markdown format (# headers, **bold**, `backtick` file paths)
- Include all file references with line numbers
- Provide specific, actionable recommendations
- Include code examples where helpful
- Score each section 0-100 with label
- List violations with severity level
