# Windsurf

Windsurf lee reglas desde el archivo `.windsurfrules` en la raíz del proyecto.

## Setup

Copia el archivo a la raíz de tu proyecto:

```bash
cp adapters/windsurf/.windsurfrules your-project/.windsurfrules
```

## Comportamiento

- **Automático**: Windsurf carga `.windsurfrules` al abrir el proyecto y aplica las instrucciones en todos los completions y chats.
- **Selectivo**: Podés eliminar las secciones de NestJS o Flutter si tu proyecto solo usa uno de los dos stacks.

## Actualizar

```bash
cd agent-rules && python3 scripts/generate.py --only windsurf
```
