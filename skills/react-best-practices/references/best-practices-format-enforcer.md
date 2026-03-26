# React Best Practices Format Enforcer

> Enforce plain-text report format for all analysis outputs. Ensures consistent, copy-paste friendly reports suitable for documentation.

---

## FORMAT REQUIREMENTS

**CRITICAL**: All analysis outputs MUST follow these rules:

1.  **NO MARKDOWN SYNTAX**:
    *   NO hash symbols for headers (# ## ###)
    *   NO asterisks for bold (**text**)
    *   NO code fences (``` blocks)
    *   NO bullet points with asterisks (* item)

2.  **USE PLAIN TEXT FORMATTING**:
    *   Headers: ALL CAPS or Title Case followed by colon
    *   Sub-headers: Indented with numbers (1. 2. 3.)
    *   Lists: Indented with dashes (- item)
    *   Code references: Use quotes ("ComponentName")
    *   File paths: Use quotes ("/src/features/auth/LoginForm.tsx:42")

3.  **SECTION STRUCTURE**:
    Each section must include:
    - Section Name (ALL CAPS)
    - Description (one-sentence summary)
    - Score (0-100 integer)
    - Key Findings (3-7 bullet points with dashes)
    - Evidence (file paths and references in quotes)
    - Risks (identified issues)
    - Recommendations (prioritized actions)

4.  **SCORING LABELS**:
    - Strong: 85-100
    - Fair: 70-84
    - Weak: 0-69

5.  **FILE REFERENCES FORMAT**:
    - Always use: "path/to/file.tsx:line_number"
    - Example: "src/features/auth/LoginForm.tsx:42 - Missing prop interface"

## EXAMPLE OUTPUT FORMAT

TESTING QUALITY
Description: Analysis of React Testing Library usage and test structure.
Score: 78 (Fair)

Key Findings:
- 80% of components have associated test files
- RTL semantic queries used in most test files
- Some tests use getByTestId where getByRole would apply
- Custom hooks tested via renderHook

Evidence:
- "src/features/auth/LoginForm.test.tsx:15" - Good AAA pattern usage
- "src/components/Button.test.tsx:42" - getByTestId overuse

Risks:
- 3 test files have no assertions
- Some async tests missing findBy queries

Recommendations:
1. Replace getByTestId with getByRole where applicable
2. Add assertions to flagged test files
3. Use userEvent instead of fireEvent for user interactions

---

ENFORCE THIS FORMAT FOR ALL ANALYSIS OUTPUTS.
