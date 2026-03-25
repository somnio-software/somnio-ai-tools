# Flutter Best Practices Report Format Enforcer

> Enforce consistent report format structure for the Flutter Best Practices Check report based on the template in assets/report-template.txt.

---

When generating the final report, you MUST follow this exact structure
and format based on the template in
assets/report-template.txt:

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
1. NO MARKDOWN SYNTAX: Use plain text only. No # headers, no **bold**,
   no ```code```.
2. SCORES: Must be integers 0-10.
3. LABELS: Strong (9-10), Fair (7-8), Weak (0-6).
4. LISTS: Use "- " for bullet points.
5. SEPARATORS: Use dashed lines (-----) between sections.

----------------------------------------------------------------------
VALIDATION CHECKLIST
----------------------------------------------------------------------
Before finalizing:
✓ All 3 main sections are present.
✓ No markdown formatting is used.
✓ Scores are clearly visible.
✓ Violations list specific files.

Reference `assets/report-template.txt` for the full
text layout.
