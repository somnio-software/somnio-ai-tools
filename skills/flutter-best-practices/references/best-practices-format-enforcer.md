# Flutter Best Practices Report Format Enforcer

> Enforce consistent report format structure for the Flutter Best Practices Check report based on the template in assets/report-template.md.

---

When generating the final report, you MUST follow this exact structure
and format based on the template in
assets/report-template.md:

----------------------------------------------------------------------
MANDATORY REPORT STRUCTURE
----------------------------------------------------------------------

1. EXECUTIVE SUMMARY
2. SECTION 1. TESTING BEST PRACTICES
3. SECTION 2. ARCHITECTURE COMPLIANCE
4. SECTION 3. CODE STANDARDS & MODELS
5. PRIORITIZED ACTION PLAN

----------------------------------------------------------------------
FORMATTING RULES (STRICT)
----------------------------------------------------------------------
1. USE MARKDOWN SYNTAX: Use proper Markdown formatting.
   - `#` for main title, `##` for sections, `###` for subsections
   - `**bold**` for scores, labels, and key terms
   - Backticks for file paths and code references
2. SCORES: Must be integers 0-10.
3. LABELS: Strong (9-10), Fair (7-8), Weak (0-6).
4. LISTS: Use "- " for bullet points.
5. SEPARATORS: Use `---` between sections.

----------------------------------------------------------------------
VALIDATION CHECKLIST
----------------------------------------------------------------------
Before finalizing:
✓ All 3 main sections are present.
✓ Markdown formatting is used consistently.
✓ Scores are clearly visible.
✓ Violations list specific files with backtick paths.

Reference `assets/report-template.md` for the full
Markdown layout.
