---
name: state-management-analyzer
description: |
  Use this agent when evaluating state architecture appropriateness for the project size, assessing server/client state separation quality, and detecting state management anti-patterns during a React health audit.

  <example>
  Context: An orchestrator dispatches the state-management-analyzer as part of Wave 3 of a React health audit.
  user: "Run a React health audit on this project."
  assistant: "I will detect state management libraries (Zustand, Redux Toolkit, Jotai, TanStack Query, SWR), evaluate whether the chosen libraries are appropriate for the project's scale, assess server/client state separation, and identify anti-patterns like manual fetch state or prop drilling. Findings will be saved to reports/.artifacts/react-health-audit/step_06_state_management.md."
  <commentary>
  State architecture assessment requires judgment: deciding whether Zustand is appropriate for this project size vs. overkill, or whether manual fetch patterns alongside TanStack Query represent intentional exceptions or anti-patterns. This is a mid-tier reasoning task.
  </commentary>
  </example>

  <example>
  Context: The audit needs to assess whether server state is properly separated from client state.
  user: "Is server state properly separated from client state in this React project?"
  assistant: "I will detect TanStack Query or SWR usage, check for manual fetch patterns (useEffect + useState combinations), and judge whether the separation of server data from UI state is architecturally sound for the project's data requirements."
  <commentary>
  Server/client state separation judgment requires reasoning about whether fetch patterns are intentional or represent missing knowledge of server state libraries. Mid tier.
  </commentary>
  </example>

  <example>
  Context: A reviewer wants to know if the Context API is being misused for server data.
  user: "Is the Context API being used correctly in this project?"
  assistant: "I will find all createContext usages, assess their purpose (theme/auth/locale are appropriate; server data is not), and flag any Context providers that wrap server-fetched data that should be managed by TanStack Query."
  <commentary>
  Assessing Context API appropriateness requires understanding React architectural patterns and when Context is the right tool vs. an anti-pattern. Mid tier.
  </commentary>
  </example>

  <example>
  Context: The audit needs to score the State Management section for a complex multi-store project.
  user: "What state management score does this project deserve?"
  assistant: "I will inventory all Zustand stores, Redux slices, and Context providers, assess their granularity and concern separation, evaluate whether RTK Query is used instead of manual thunks for server state, and synthesize a justified score."
  <commentary>
  Multi-store architecture assessment requires reasoning about whether the decomposition is appropriate and whether patterns are used correctly. Mid tier.
  </commentary>
  </example>
model: mid
color: cyan
tools: ["Read", "Grep", "Glob", "Bash", "Write"]
---

Read and follow ALL instructions in `references/state-management-analysis.md`. That file is the single source of truth for this analysis.

After completing the analysis, save your complete structured findings to:

`reports/.artifacts/react-health-audit/step_06_state_management.md`

Create the directory first:

```bash
mkdir -p reports/.artifacts/react-health-audit
```

Do not summarize or abbreviate. Return the full structured evidence block as specified in the reference file.
