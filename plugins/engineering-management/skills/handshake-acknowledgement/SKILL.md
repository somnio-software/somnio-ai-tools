---
name: handshake-acknowledgement
description: |
  Generates the Somnio HandShake Step 3 - Acknowledgement PDF document from raw evaluation notes.
  Use this skill whenever an Engineering Manager (EM) wants to create, generate, or produce one or
  more HandShake Acknowledgement documents, career review PDFs, seniority evaluation documents, or
  anything related to the Somnio bi-annual performance review process.
  Trigger even if the user says things like: generar el documento del handshake, armar el PDF de la
  evaluacion, crear el acknowledgement para un dev, generar el informe del career path, procesar
  estas fichas, or similar.
  The skill handles both single and batch (multiple devs) generation: it reads all attached ficha
  files, pre-fills what it can infer, confirms all data with the EM in a single table, then
  generates one PDF per dev.
---

# HandShake Acknowledgement Generator

Generates the Somnio **HandShake - Step 3 Acknowledgement** PDF from raw EM notes.
Handles **single or batch** generation (1 to N devs in one run).

## Context

Somnio Software runs a bi-annual performance review program called **HandShake** (April and October/November). After conducting interviews with the PM, a dev from the team, and the Tech Lead, the EM synthesizes everything into the Acknowledgement document — a formal PDF delivered to the developer.

## Input

One or more ficha files (PDF, DOCX, or pasted text) per developer, containing:
- Notes from PM interview
- Notes from dev team member interview
- Notes from Tech Lead review
- EM synthesis / general feedback
- Optionally: previous Acknowledgement PDF (for comparison section)

Input is always **free-form** — Claude must interpret it intelligently.

## Output

One PDF per developer, matching the Somnio Acknowledgement template:
- Somnio logo top-right header, gradient background, transparent footer
- Header table: Somnier, Líder, Fecha, Rol del Somnier
- **Puntos abordados** (standard agenda — always the same)
- **Resumen del encuentro**: Seniority · Rendimiento actual · Comparación anterior (if applicable)
- **Objetivos acordados**: Oportunidad de mejora + Continuar trabajando en
- **Aclaración o comentarios generales** (optional)

---

## Batch Workflow (ALWAYS follow this order)

### Step 1 — Read all attached files

When the EM attaches one or more ficha files, read all of them before asking anything.
For each file, extract as much as possible:
- Developer name (Somnier)
- EM / Líder name
- Role
- Current seniority level
- Target level
- All feedback content

### Step 2 — Show confirmation table

Present a **single summary table** with one row per developer. Pre-fill every field Claude could infer. Mark fields Claude could NOT determine with `[?]`.

Example format:

```
Encontré X fichas. Antes de generar, confirmá o corregí los datos:

| # | Somnier | Líder | Fecha | Rol |
|---|---------|-------|-------|-----|
| 1 | John Doe | Jane Smith | [?] | Sr Flutter Developer |
| 2 | Bob Johnson | [?] | [?] | Sr Backend Engineer |

Completá los [?] y avisame si hay algo para corregir. Una vez confirmado, genero todos los PDFs.
```

**Date format rule**: Fecha must be `Dec 19, 2025` style (abbreviated English month, no leading zero, 4-digit year). Accept any format from the EM and normalise automatically.

**Do NOT generate any PDF until the EM explicitly confirms the table.**

### Step 3 — Generate all PDFs

Once the EM confirms (even partially, e.g. "el resto está bien"), generate all PDFs sequentially.
For each dev:
1. Build the content JSON from the ficha notes
2. Run the generation script
3. Report progress: "✅ 1/3 — John Doe.pdf generado"

Deliver all files at the end together.

### Step 4 — Deliver

Present all generated PDFs at once using `present_files`.
Name each file: `Handshake_Acknowledgement_Firstname_Lastname.pdf`

---

## Content Synthesis Guide

From the raw notes, synthesize per developer:

### Rendimiento actual
4–7 bullet points highlighting strengths and achievements. Extract from PM/dev/TL feedback. Reformulate cleanly — do not copy raw notes verbatim.

### Comparación reunión anterior
Only if a previous Acknowledgement PDF was provided. For each prior objective, assign:
- `Logrado` — clearly achieved
- `Logrado, pero hay que seguir trabajando` — partial
- `En progreso` — started but not there yet
- `Pendiente` — not yet addressed

If no previous eval: **omit this section entirely**.

### Oportunidad de mejora
3–6 specific, actionable improvement areas. Extract from TL/PM criticism. Frame positively and professionally.

### Continuar trabajando en
Grouped by category. For Flutter devs, typical categories:
- Conocimientos Técnicos
- Conocimientos Avanzados y Especialización
- Mejora Continua y Arquitectura
- Liderazgo y Comunicación
- Innovación y Uso de Inteligencia Artificial

Adapt categories to the actual role and tech stack.

---

## Running the Generation Script

```bash
python3 /path/to/handshake-acknowledgement/scripts/generate_pdf.py \
  --somnier "FULL NAME" \
  --lider "LEADER NAME" \
  --fecha "Dec 19, 2025" \
  --rol "Role Title" \
  --output /mnt/user-data/outputs/Handshake_Acknowledgement_Firstname_Lastname.pdf \
  --content /tmp/handshake_content_firstname.json
```

The script auto-normalises the date format. See `scripts/generate_pdf.py` for the full content JSON structure.

---

## Important Notes

- **Language**: Spanish throughout.
- **Tone**: Professional, constructive, empathetic — the document is read by the developer.
- **Seniority levels** at Somnio: Junior → Semi-Senior → Senior Medium → Senior Advance → Tech Lead
- **Puntos abordados** is always the same standard agenda — never change it.
- If a section has no content (no previous eval, no dev comments), omit it entirely.
- **Fonts**: Nunito 11pt for content, Plus Jakarta Sans 9pt for footer. If TTF files are not present in `assets/fonts/`, Liberation Sans is used as fallback. To install proper fonts, place TTF files there (see script docstring).
