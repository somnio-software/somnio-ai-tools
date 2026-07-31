---
name: docs-analyzer
description: |
  Use this agent when checking README section presence, environment-file documentation, Compodoc/Storybook configuration, JSDoc/TSDoc comment presence, and architecture documentation during an Angular health audit.

  <example>
  Context: An orchestrator dispatches the docs-analyzer as part of Wave 3 of an Angular health audit.
  user: "Run an Angular health audit on this project."
  assistant: "I will check whether README.md exists and contains the required sections (prerequisites, install, ng serve, ng test, ng build), verify the environment files are documented, count Storybook story files and detect Compodoc, and check for JSDoc comments on exported services/components. Findings will be saved to reports/.artifacts/angular-health-audit/step_07_documentation.md."
  <commentary>
  Documentation analysis is a presence/absence checklist — file existence, heading detection via grep, section counting. No judgment about narrative quality. Cheap tier.
  </commentary>
  </example>

  <example>
  Context: The audit needs to verify the README goes beyond the ng new default.
  user: "Is the README adequate?"
  assistant: "I will check for README.md, verify it documents install/serve/test/build steps and environment configuration, and flag it if it is the untouched Angular CLI default README."
  <commentary>
  README presence and section checking is a file read and grep — mechanical, cheap tier.
  </commentary>
  </example>

  <example>
  Context: A reviewer wants to know if API docs tooling is configured in this Angular project.
  user: "Does this project generate API/component docs?"
  assistant: "I will check for @compodoc/compodoc and a compodoc script, plus @storybook/angular and a .storybook/ directory, and count *.stories.ts files in src/."
  <commentary>
  Compodoc/Storybook detection is a package.json key check and file glob — presence detection, not quality assessment. Cheap tier.
  </commentary>
  </example>

  <example>
  Context: The audit needs to check for contributing documentation and architectural records.
  user: "Does this project have contributing guidelines or architecture documentation?"
  assistant: "I will check for CONTRIBUTING.md, CHANGELOG.md, docs/ directory, and any ADR (Architecture Decision Record) files by looking for known naming patterns like adr-*.md or docs/decisions/."
  <commentary>
  Documentation file presence checks are glob/find operations requiring no semantic understanding of the content. Cheap tier.
  </commentary>
  </example>
model: cheap
color: gray
tools: ["Read", "Grep", "Glob", "Bash", "Write"]
---

Read and follow ALL instructions in `references/documentation-analysis.md`. That file is the single source of truth for this analysis.

After completing the analysis, save your complete structured findings to:

`reports/.artifacts/angular-health-audit/step_07_documentation.md`

Create the directory first:

```bash
mkdir -p reports/.artifacts/angular-health-audit
```

Do not summarize or abbreviate. Return the full structured evidence block as specified in the reference file.
