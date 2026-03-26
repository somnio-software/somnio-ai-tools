# Claude Code

Claude Code carga automáticamente el archivo `CLAUDE.md` desde la raíz del proyecto al iniciar una sesión.

## Setup

Copia `CLAUDE.md` a la raíz de tu proyecto:

```bash
cp adapters/claude/CLAUDE.md your-project/CLAUDE.md
```

Si tu proyecto ya tiene un `CLAUDE.md`, mergea el contenido relevante (solo las secciones de NestJS o Flutter según el stack).

## Comportamiento

- **Automático**: Claude Code lee `CLAUDE.md` al inicio de cada sesión — las reglas se aplican en todos los prompts.
- **Selectivo**: Podés incluir solo las secciones que aplican a tu proyecto (ej: solo NestJS si no usás Flutter).
- **Por directorio**: También podés crear `CLAUDE.md` en subdirectorios para aplicar reglas más específicas (ej: `src/modules/CLAUDE.md` solo para el backend).

## Estructura del archivo generado

```
CLAUDE.md
├── NestJS Rules (9 reglas inline con todos sus ejemplos)
└── Flutter Rules (5 reglas inline con todos sus ejemplos)
```

## Actualizar

```bash
npm run generate:claude
```
