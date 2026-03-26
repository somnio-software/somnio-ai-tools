# OpenAI Codex / ChatGPT

Codex y ChatGPT no tienen un archivo de configuración estándar en el proyecto. Las reglas se inyectan como **system prompt** al crear un proyecto o al iniciar una conversación.

## Setup

Copia el contenido de `system-prompt.md` y pegalo como system prompt:

- **ChatGPT Projects**: Settings → Customize ChatGPT → Instructions
- **API / Codex**: campo `system` en el primer mensaje de la conversación
- **Cursor con modelo GPT**: instrucciones del proyecto en Cursor settings

```bash
cat adapters/codex/system-prompt.md
```

## Formato del archivo

El `system-prompt.md` es una versión **condensada** de las reglas: contiene toda la prosa y las instrucciones, pero sin los bloques de código de ejemplo. Esto reduce el uso de tokens en el contexto del sistema.

Si necesitás los ejemplos de código incluidos, usá el archivo de Claude Code (`adapters/claude/CLAUDE.md`) como system prompt en su lugar.

## Actualizar

```bash
cd agent-rules && python3 scripts/generate.py --only codex
```
