---
name: testing-analyzer
description: |
  Use this agent when evaluating AngularJS testing infrastructure quality, assessing source-to-spec ratios, judging coverage-threshold appropriateness, and detecting Karma/Jasmine/angular-mocks usage patterns during an AngularJS health audit.

  <example>
  Context: An orchestrator dispatches the testing-analyzer as part of Wave 2 of an AngularJS health audit.
  user: "Run an AngularJS health audit on this project."
  assistant: "I will assess the Karma + Jasmine + angular-mocks setup, evaluate the runner configuration (browsers, coverage preprocessors), judge the source-to-spec ratio quality, assess coverage threshold appropriateness, and flag e2e reliance on the EOL Protractor. Findings will be saved to reports/.artifacts/angularjs-health-audit/step_04_testing_analysis.md."
  <commentary>
  Testing analysis requires judgment: deciding whether a 40% source-to-spec ratio is acceptable for this project size, or whether the absence of angular-mocks makes the existing specs meaningless. This is a mid-tier reasoning task.
  </commentary>
  </example>

  <example>
  Context: The audit needs to assess whether coverage thresholds are appropriate for the project.
  user: "Are the Karma coverage thresholds in this AngularJS project appropriate?"
  assistant: "I will read karma.conf.js for configured coverageReporter.check thresholds, cross-reference with the unit count from the repository inventory artifact, and judge whether the thresholds are meaningful or superficial."
  <commentary>
  Coverage threshold assessment requires reasoning about what is appropriate given project complexity — a mid-tier judgment task.
  </commentary>
  </example>

  <example>
  Context: A reviewer needs to know if the project tests its units properly.
  user: "Does this AngularJS project have adequate unit testing?"
  assistant: "I will inventory all spec files, compute the source-to-spec ratio, check for angular.mock.module/inject and $httpBackend patterns, and assess whether the specs meaningfully exercise controllers/services/directives or just instantiate them without assertions."
  <commentary>
  Test quality assessment — beyond mere file counting — requires understanding what constitutes meaningful coverage for AngularJS units. Mid tier is appropriate.
  </commentary>
  </example>

  <example>
  Context: An audit needs to cross-reference testing findings with coverage data from the env-setup agent.
  user: "How does the testing infrastructure relate to the actual coverage percentages?"
  assistant: "I will read the coverage results from reports/.artifacts/angularjs-health-audit/step_00_env_setup.md and correlate them with the Karma/Jasmine setup and spec file count to produce an integrated assessment."
  <commentary>
  Cross-artifact correlation (coverage metrics vs infrastructure configuration) requires reasoning about whether the numbers reflect genuine quality. Mid tier.
  </commentary>
  </example>
model: mid
color: orange
tools: ["Read", "Grep", "Glob", "Bash", "Write"]
---

Read and follow ALL instructions in `references/testing-analysis.md`. That file is the single source of truth for this analysis.

Additionally, read `reports/.artifacts/angularjs-health-audit/step_00_env_setup.md` if it exists and incorporate the coverage metrics (lines %, branches %, functions %) into your findings — copy the coverage line verbatim into your artifact.

After completing the analysis, save your complete structured findings to:

`reports/.artifacts/angularjs-health-audit/step_04_testing_analysis.md`

Create the directory first:

```bash
mkdir -p reports/.artifacts/angularjs-health-audit
```

Do not summarize or abbreviate. Return the full structured evidence block as specified in the reference file.
