---
name: prompt-enhancer
description: Take a basic user prompt or a tracker ticket summary and transform it into a production-ready prompt with role assignment, structured sections, emphasis keywords, and explicit success criteria. Use this for routine work where a clear, executable brief beats a SPARC spec — bug fixes, small CRUD additions, config tweaks. Invokable standalone via /enhance-prompt or programmatically by ticket-to-sparc Tier 3.
---

# Prompt Enhancer

You turn rough prompts into production-ready prompts. The enhanced output is structured, role-assigned, and immediately executable by another agent or developer.

## When this skill applies

- A user runs `/enhance-prompt <basic prompt>` from the command line.
- The `ticket-to-sparc` orchestrator routes a Tier-3 (single-ticket, routine) goal to you. Input is the tracker ticket's summary + description + acceptance criteria + parent epic.
- A user has a draft prompt and asks you to "make this prompt better" or similar.

## When this skill does NOT apply

- The work needs an architectural decision recorded → use `enhanced-adr`.
- The work needs a multi-phase implementation plan → use `sparc-orchestration`.
- The user wants to discuss the prompt rather than transform it. Don't enhance unless asked.

## Methodology

The full transformation rules live in [`command.md`](./command.md). At a high level the rules come from two sources:

**Cursor Blog principles**
- Clarity over complexity — write like you're talking to a busy intelligent reader
- Structured & composable — modular sections with clear headers
- Context window awareness — front-load what matters, drop redundancy
- Pixel-perfect formatting — clean, consistent, no extraneous whitespace

**Parahelp techniques**
- Role-based prompting — assign a clear identity ("You are an expert…")
- Structured formatting — markdown headers, XML-ish tags for special content
- Explicit thinking order — tell the model *how* to reason
- Emphasis keywords — IMPORTANT, CRITICAL, ALWAYS, NEVER, ⚠️
- No else branches — enumerate every valid path explicitly
- Evaluation-driven design — make the output measurable

## Workflow

1. Take the input prompt (a basic instruction, a tracker ticket summary, or anything in between).
2. Apply the 8-step enhancement process documented in [`command.md`](./command.md): analyze intent → add structure → assign role → specify behavior → add examples → emphasize → define success → remove ambiguity.
3. Produce the enhanced prompt with:
   - Role assignment at the top
   - Structured sections with markdown headers
   - Bold/caps on key points
   - Examples if they clarify intent
   - Success criteria if applicable
   - The exact "ASK ANY QUESTIONS YOU HAVE…" footer at the end
4. **Return ONLY the enhanced prompt.** No commentary, no meta-text, no "here is your enhanced prompt" preamble.

## Output target

When invoked standalone via `/enhance-prompt`: return the enhanced prompt in chat.

When invoked by `ticket-to-sparc` for Tier-3 dispatch: write the enhanced prompt to `docs/briefs/<ticket-id>-<slug>.md` with this frontmatter:

```yaml
---
tracker_id: <TICKET-KEY>
tracker_type: jira | linear | notion | other
tier: 3
created: YYYY-MM-DD
---
```

The body is the enhanced prompt itself, ending in the "ASK ANY QUESTIONS…" footer.

## Reference

The canonical command body — including the role definition, principles, techniques, enhancement process, output format rules, and the mandatory closing footer — lives in [`command.md`](./command.md).
