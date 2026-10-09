# .NET Best Practices Format Enforcer

> Enforce Markdown report format for all analysis outputs. Ensures consistent, readable reports suitable for documentation.

---

## FORMAT REQUIREMENTS

**CRITICAL**: All analysis outputs MUST follow these rules:

1.  **USE MARKDOWN FORMATTING**:
    *   `#` for main title, `##` for sections, `###` for subsections
    *   `**bold**` for field labels and key terms. Bold the field label only; never bold the numeric value after `**Score:**`.
    *   Backticks for file paths and code references
    *   `- ` for bullet points

2.  **MARKDOWN STRUCTURE**:
    *   Section headers: `## N. Section Name`
    *   Sub-headers: `### Key Findings`, `### Violations`, etc.
    *   Code refs: `` `path/to/File.cs:42` ``
    *   File paths: `` `src/Orders/OrdersService.cs:42` ``

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
    - Always use: "path/to/File.cs:line_number"
    - Example: "src/Orders/OrdersService.cs:42 - Missing validation"

6.  **CLOSE WITH SCORING METHODOLOGY**:
    *   The report MUST close with an unnumbered `## Appendix: Scoring Methodology` block,
        placed between `## 10. Evidence Index` and `## Report Metadata`
    *   Its `| Section | Weight |` rows MUST match this skill's own `## 2. Score Breakdown`
        row labels, in the same order, and MUST sum to 100%

7.  **WEIGHTS APPEAR ONLY IN THE APPENDIX**:
    *   Weights are shown ONLY in the `## Appendix: Scoring Methodology` block and in
        `references/best-practices-generator.md`
    *   NEVER add a Weight column to the `## 2. Score Breakdown` table

## EXAMPLE OUTPUT FORMAT

TESTING QUALITY
Description: Analysis of unit and integration test quality.
Score: 78 (Fair)

Key Findings:
- 85% of services have unit tests
- Integration tests use WebApplicationFactory correctly
- Some tests missing FluentAssertions-style assertions

Evidence:
- "tests/Orders.UnitTests/OrderServiceTests.cs:15" - Good AAA pattern usage
- "tests/Orders.UnitTests/OrderServiceTests.cs:42" - Missing assertion

Risks:
- 3 test files have no assertions (false positives)
- Integration tests may leave orphan data between runs

Recommendations:
1. Add assertions to flagged test files
2. Implement Respawn-based cleanup in integration tests
3. Add coverage reporting to CI pipeline

---

ENFORCE THIS MARKDOWN FORMAT FOR ALL ANALYSIS OUTPUTS.
