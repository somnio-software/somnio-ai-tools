---
name: state-management-analyzer
description: |
  Use this agent when evaluating AngularJS data-flow architecture — service/factory layering, $http/$resource centralization and interceptors, $rootScope misuse, binding discipline, and digest-cycle hygiene — during an AngularJS health audit. Feeds the State Management section.

  <example>
  Context: An orchestrator dispatches the state-management-analyzer as part of Wave 3 of an AngularJS health audit.
  user: "Run an AngularJS health audit on this project."
  assistant: "I will detect service/factory layering, evaluate whether $http/$resource access is centralized with interceptors or scattered through fat controllers, assess $rootScope usage (a handful of global events vs a global data bus), judge binding discipline (one-way/`::` vs pervasive two-way), and inventory $watch registrations. Findings will be saved to reports/.artifacts/angularjs-health-audit/step_06_state_management.md."
  <commentary>
  Data-flow assessment requires judgment: deciding whether $rootScope use is a legitimate event channel or an anti-pattern data store, or whether direct $http in a controller is intentional or missing a service layer. This is a mid-tier reasoning task.
  </commentary>
  </example>

  <example>
  Context: The audit needs to assess whether server access is properly layered.
  user: "Is server data access properly layered in this AngularJS project?"
  assistant: "I will detect $http/$resource calls, check whether they are centralized in data services with $httpProvider.interceptors, and judge whether controllers delegate to services or call the backend directly."
  <commentary>
  Layering judgment requires reasoning about whether HTTP access belongs where it is found — a mid-tier task.
  </commentary>
  </example>

  <example>
  Context: A reviewer wants to know if $rootScope is being misused.
  user: "Is $rootScope being used correctly in this project?"
  assistant: "I will grep all $rootScope usages, distinguish legitimate $on/$broadcast event use from misuse as a global data store or cross-controller bus, and flag heavy data storage on $rootScope."
  <commentary>
  Assessing $rootScope appropriateness requires understanding AngularJS data-flow patterns and when $rootScope is the right tool vs an anti-pattern. Mid tier.
  </commentary>
  </example>

  <example>
  Context: The audit needs to score digest-cycle hygiene for a watch-heavy project.
  user: "Does this project have digest-cycle performance problems?"
  assistant: "I will count $watch/$watchCollection registrations, flag deep watches ($watch(..., true)), check for manual $apply/$timeout forcing, and verify $destroy cleanup of watches and listeners, then synthesize a justified score."
  <commentary>
  Digest-hygiene assessment requires reasoning about whether the watch load and cleanup are appropriate. Mid tier.
  </commentary>
  </example>
model: mid
color: cyan
tools: ["Read", "Grep", "Glob", "Bash", "Write"]
---

Read and follow ALL instructions in `references/state-management-analysis.md`. That file is the single source of truth for this analysis.

After completing the analysis, save your complete structured findings to:

`reports/.artifacts/angularjs-health-audit/step_06_state_management.md`

Create the directory first:

```bash
mkdir -p reports/.artifacts/angularjs-health-audit
```

Do not summarize or abbreviate. Return the full structured evidence block as specified in the reference file.
