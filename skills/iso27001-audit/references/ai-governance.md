# Category J - AI Governance Evidence (A.5.1, A.8.29; note ISO/IEC 42001)

> Gather in-repo evidence for an AI use policy, data-for-training controls, and output oversight where the project uses AI/LLM components. Framework-agnostic, read-only. ISO/IEC 27001 covers AI use via the general policy (A.5.1) and secure-development/testing (A.8.29); ISO/IEC 42001 is the dedicated AI-management-system extension - note it as the maturity target, but score against 27001.

---

Goal: Determine whether AI/LLM usage in the project is governed. Record Status
+ Owner/lane per control. If the project uses NO AI components, mark this
category Not Applicable and score it neutrally per `references/scoring.md`
(do not penalize a non-AI project).

PROJECT DETECTION (execute first):
- Read `reports/.artifacts/step_01_iso27001_project_detection.md`.

AI FOOTPRINT DETECTION (execute first - decide applicability):
```bash
grep -rniE "openai|anthropic|claude|gpt-|azure openai|bedrock|vertex ai|gemini|huggingface|hugging face|langchain|llama|mistral|cohere|ollama|llm|embedding|completion|chat.?completion|prompt|rag|vector ?(db|store)|pinecone|weaviate|pgvector" . --include=*.ts --include=*.js --include=*.py --include=*.go --include=*.env.example --include=package.json --include=requirements.txt --include=pyproject.toml 2>/dev/null | grep -vE "node_modules|dist|test" | head -30 || echo "AI_FOOTPRINT=none - no AI/LLM usage detected; mark Category J Not Applicable"
```

If no AI footprint is detected, record AI_FOOTPRINT=none, mark all controls
Not Applicable (Owner/lane CLIENT or N/A), and skip the checks below.

CONTROL EVIDENCE (only if AI footprint detected):

A.5.1 AI use policy (ORGANIZATIONAL) - acceptable-use / AI governance policy:
```bash
find . -maxdepth 5 \( -iname "*ai*polic*" -o -iname "*ai*governance*" -o -iname "*ai*use*" -o -iname "*llm*polic*" -o -iname "*responsible*ai*" -o -iname "*acceptable*use*" \) -not -path "*/node_modules/*" 2>/dev/null | head -15 || echo "No AI-use / AI-governance policy artifact found"
```

Data-for-training controls (PLATFORM-AUDITABLE where enforced) - whether
customer/PII data is sent to models, opt-out of training, data-retention
settings on the provider:
```bash
grep -rniE "training|opt.?out|do_?not_?train|data.?retention|zero.?retention|no.?log|redact|pii.*(strip|scrub|filter)|anonymiz|data ?processing" . --include=*.ts --include=*.js --include=*.py 2>/dev/null | grep -vE "node_modules|dist|test" | head -20 || echo "No data-for-training control evidence found"
```

Output oversight / guardrails (PLATFORM-AUDITABLE) - content filtering,
human-in-the-loop, output validation, prompt-injection defense, rate limits:
```bash
grep -rniE "guardrail|moderation|content.?filter|human.?in.?the.?loop|hitl|output.?validation|prompt.?injection|jailbreak|safety|toxicity|hallucination|schema.*validate|structured.?output" . --include=*.ts --include=*.js --include=*.py 2>/dev/null | grep -vE "node_modules|dist|test" | head -20 || echo "No AI output-oversight/guardrail evidence found"
```

A.8.29 Security testing of AI components (PLATFORM-AUDITABLE) - evals, red-team
tests, prompt tests:
```bash
grep -rniE "eval|red.?team|prompt.?test|llm.?test|adversarial" . --include=*.ts --include=*.js --include=*.py 2>/dev/null | grep -vE "node_modules|dist" | head -15 || echo "No AI security/eval testing evidence found"
```

STANDARDS NOTE (include in artifact, not as a gap):
- ISO/IEC 27001 governs AI use through the general information-security policy
  (A.5.1) and secure development/testing (A.8.25-A.8.29). The dedicated
  AI-management-system standard is ISO/IEC 42001 - recommend it as the
  maturity target for organizations with significant AI usage, but score this
  category against ISO 27001 controls only.

READ-ONLY + SECRET SAFETY: read only; redact API keys / secret VALUES as
`[REDACTED]`.

ARTIFACT SAVE (mandatory):
Save output to: reports/.artifacts/step_11_iso27001_ai_governance.md
Run before finishing: mkdir -p reports/.artifacts

Output format:
- AI_FOOTPRINT: detected / none (and the evidence)
- If none: mark Category J Not Applicable (do not penalize)
- If detected: Category J control table: control | Annex A ref | Status |
  Owner/lane | evidence (path) or "No evidence found" | gap + satisfying
  artifact; plus the ISO/IEC 42001 maturity note
- Summary: count of Met / Partial / Gap / Organizational / Not Applicable
