# ISO 27001 Readiness Scoring

> Compute a 0-100 readiness score for each of the 11 control categories (A-K), weight the overall score toward PLATFORM-AUDITABLE controls, compute the weighted overall readiness score, and map it to a readiness band. You MUST compute all scores BEFORE any report content is written. A report without computed scores is INVALID.

---

Goal: Turn the per-category control-evidence artifacts into 11 category scores
and one weighted overall readiness score with a band.

ARTIFACT INTEGRATION:
Read every step artifact in this run's artifacts directory (under
`reports/.artifacts/`), matching by step-number prefix:
- step_01_* project detection (project type, structure)
- step_02_* Category A Governance & program
- step_03_* Category B Human resources security
- step_04_* Category C Identity & access management
- step_05_* Category D Data protection & confidentiality
- step_06_* Category E Secure development & change management
- step_07_* Category F Infrastructure & network security
- step_08_* Category G Vulnerability management & assurance
- step_09_* Category H Incident management, BCP/DR
- step_10_* Category I Vendor / third-party management
- step_11_* Category J AI governance
- step_12_* Category K Evidence / ISMS artifacts (+ clauses 4-10)

If an expected step_NN_* artifact is absent, assign that category score 0 and
note "Score: 0/100 (Not Ready) - Insufficient data from [missing artifact]".
Never omit a category.

CATEGORY WEIGHTS (sum = 1.00; readiness weighted toward platform-auditable
categories):
- A. Governance & program: 0.08
- B. Human resources security: 0.05
- C. Identity & access management: 0.13
- D. Data protection & confidentiality: 0.13
- E. Secure development & change management: 0.14
- F. Infrastructure & network security: 0.12
- G. Vulnerability management & assurance: 0.11
- H. Incident management, BCP/DR: 0.08
- I. Vendor / third-party management: 0.06
- J. AI governance: 0.04
- K. Evidence / ISMS artifacts: 0.06

PER-CONTROL CREDIT (within a category):
Each in-scope control contributes (lane_weight * status_credit).

Lane weight (readiness weighted toward platform-auditable controls):
- PLATFORM-AUDITABLE control: lane_weight = 2
- ORGANIZATIONAL control: lane_weight = 1
- CLIENT-lane control: EXCLUDED (lane_weight = 0) - listed, never penalized
- Not Applicable control: EXCLUDED (lane_weight = 0)

Status credit:
- Met: 1.0
- Partial: 0.5
- Gap: 0.0
- Organizational-present (artifact EXISTS): 1.0
- Organizational-absent (artifact MISSING): 0.0 (treat as a gap)

CATEGORY SCORE FORMULA:
category_score = round( 100 * ( sum over in-scope controls of
                 lane_weight_i * status_credit_i )
                 / ( sum over in-scope controls of lane_weight_i ) )

- Clamp each category_score to 0-100.
- If a category has NO in-scope controls (all CLIENT / Not Applicable - e.g.
  Category J when AI_FOOTPRINT=none), mark the category "Not Applicable",
  EXCLUDE it from the overall, and redistribute its weight proportionally
  across the remaining included categories (renormalize the remaining weights
  so they still sum to 1.00). Record the exclusion explicitly.

OVERALL SCORE FORMULA:
Using only INCLUDED categories with (renormalized if needed) weights:
overall = round( sum over included categories of category_score_c * weight_c )

Clamp overall to 0-100.

READINESS BAND (map from overall AND from each category_score):
- 0-40  = Not Ready
- 41-70 = Partially Ready
- 71-85 = Largely Ready
- 86-100 = Certification-Ready

MANDATORY SCORING COMPUTATION (execute before writing the report):

Step A - For each category, from its artifact, tally the in-scope controls and
their Status + Owner/lane. Exclude CLIENT-lane and Not Applicable controls.

Step B - Compute each category_score with the formula above. Show the
computation trace (in-scope control count, sum of lane_weight*status_credit,
denominator, result).

Step C - Determine which categories are Not Applicable (no in-scope controls);
renormalize weights across included categories if any are excluded.

Step D - Compute the overall score with the weighted formula.

Step E - Determine the band for the overall score and for each category_score.

Step F - Verify all 11 category scores (or "Not Applicable") plus the overall
score are computed before proceeding. Also verify that EVERY mapped Annex A
reference across the artifacts carries a Status and an Owner/lane; if any is
missing, mark it Gap / unknown-lane and note it.

SCORE COMPARISON (before generating):
If `reports/.history/last_iso27001_scores.json` exists, read it and extract the
previous "overall" score and "timestamp". After computing the new overall,
compute the change (current - previous) and record it for the Executive
Summary: "Previous: [N]/100, Change: [+/-M] ([improving|declining|unchanged])".

ARTIFACT SAVE (mandatory):
Save the scoring output to:
reports/.artifacts/step_13_iso27001_scoring.md
Run before finishing: mkdir -p reports/.artifacts

Output format (in artifact):
- Per-category score table: Category (A-K) | name | weight (and renormalized
  weight if applicable) | in-scope control count | category_score/100 | band |
  computation trace
- Excluded categories (Not Applicable) with reason
- Overall readiness score /100 + band
- Status roll-up across all categories: total Met / Partial / Gap /
  Organizational-present / Organizational-absent / Not Applicable
- Owner/lane roll-up: PLATFORM-AUDITABLE / ORGANIZATIONAL / CLIENT counts
- Score comparison vs previous run (if history exists)
