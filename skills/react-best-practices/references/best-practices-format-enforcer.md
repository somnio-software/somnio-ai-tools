# React Best Practices Format Enforcer

> Enforce Markdown report format for all analysis outputs. Ensures consistent, readable reports suitable for documentation.

---

## FORMAT REQUIREMENTS

**CRITICAL**: All analysis outputs MUST follow these rules:

1.  **USE MARKDOWN FORMATTING**:
    *   `#` for main title, `##` for sections, `###` for subsections
    *   `**bold**` for scores, labels, and key terms
    *   Backticks for file paths and code references
    *   `- ` for bullet points

2.  **MARKDOWN STRUCTURE**:
    *   Section headers: `## N. Section Name`
    *   Sub-headers: `### Key Findings`, `### Violations`, etc.
    *   Code refs: `` `ComponentName` ``
    *   File paths: `` `src/features/auth/LoginForm.tsx:42` ``

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

ENFORCE THIS MARKDOWN FORMAT FOR ALL ANALYSIS OUTPUTS.
