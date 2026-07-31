# Angular Best Practices Format Enforcer

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
    *   Code refs: `` `UserProfileComponent` ``
    *   File paths: `` `src/app/features/auth/login-form.component.ts:42` ``

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
    - Example: "src/app/features/auth/login-form.component.ts:42 - Untyped @Input()"

## EXAMPLE OUTPUT FORMAT

TESTING QUALITY
Description: Analysis of Angular TestBed usage and test structure.
Score: 78 (Fair)

Key Findings:
- 80% of components have associated .spec.ts files
- TestBed used with mocked dependencies in most specs
- Some specs import the whole AppModule instead of a minimal test module
- HttpClientTestingModule used for HTTP-facing services

Evidence:
- "src/app/features/auth/login-form.component.spec.ts:15" - Good AAA pattern usage
- "src/app/features/auth/auth.service.spec.ts:42" - Missing httpMock.verify()

Risks:
- 3 spec files have no assertions
- Some async tests lack fakeAsync/tick and rely on real timers

Recommendations:
1. Replace full-AppModule imports with minimal TestBed configurations
2. Add assertions to flagged spec files
3. Use fakeAsync/tick (or waitForAsync) for async control

---

ENFORCE THIS MARKDOWN FORMAT FOR ALL ANALYSIS OUTPUTS.
