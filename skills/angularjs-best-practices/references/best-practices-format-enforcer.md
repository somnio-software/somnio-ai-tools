# AngularJS Best Practices Format Enforcer

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
    *   Code refs: `` `OrderListController` ``
    *   File paths: `` `app/orders/order-list.component.js:42` ``

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
    - Always use: "path/to/file.js:line_number"
    - Example: "app/orders/order-list.component.js:42 - Unsafe DI annotation"

## EXAMPLE OUTPUT FORMAT

TESTING QUALITY
Description: Analysis of Karma/Jasmine + angular-mocks usage and spec structure.
Score: 78 (Fair)

Key Findings:
- 80% of controllers/services have associated specs
- `module()` / `inject()` bootstrap used in most specs
- Some specs assert before `$httpBackend.flush()`
- Directives tested via `$compile` and rendered DOM

Evidence:
- "app/orders/order-list.component.spec.js:15" - Good AAA pattern usage
- "app/orders/order.service.spec.js:42" - Missing `$httpBackend.flush()`

Risks:
- 3 spec files have no assertions
- Some async specs never flush pending `$http`

Recommendations:
1. Add `$httpBackend.flush()` before assertions in async specs
2. Add assertions to flagged spec files
3. Verify no outstanding expectations in `afterEach`

---

ENFORCE THIS MARKDOWN FORMAT FOR ALL ANALYSIS OUTPUTS.
