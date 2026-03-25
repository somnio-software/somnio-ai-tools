# NestJS Best Practices Format Enforcer

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
    *   Code references: Use quotes ("function_name")
    *   File paths: Use quotes ("/src/users/users.service.ts:42")

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
    - Always use: "path/to/file.ts:line_number"
    - Example: "src/users/users.service.ts:42 - Missing validation"

## EXAMPLE OUTPUT FORMAT

TESTING QUALITY
Description: Analysis of unit and integration test quality.
Score: 78 (Fair)

Key Findings:
- 85% of services have unit tests
- Integration tests use proper cleanup patterns
- Some tests missing assertions
- Mock setup is consistent across files

Evidence:
- "src/users/users.service.spec.ts:15" - Good AAA pattern usage
- "src/orders/orders.service.spec.ts:42" - Missing assertion

Risks:
- 3 test files have no assertions (false positives)
- Integration tests may leave orphan data

Recommendations:
1. Add assertions to flagged test files
2. Implement afterAll cleanup in integration tests
3. Add test coverage reporting to CI pipeline

---

ENFORCE THIS FORMAT FOR ALL ANALYSIS OUTPUTS.
