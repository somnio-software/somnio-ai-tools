# GitHub Copilot

GitHub Copilot lee instrucciones personalizadas desde `.github/copilot-instructions.md` en la raíz del repositorio.

## Setup

Copia el archivo al directorio `.github/` de tu proyecto:

```bash
mkdir -p your-project/.github
cp adapters/copilot/copilot-instructions.md your-project/.github/copilot-instructions.md
```

## Comportamiento

- **Automático en VS Code**: Copilot aplica las instrucciones en todos los completions y chats del repositorio sin configuración adicional.
- **GitHub.com**: Las instrucciones también se aplican en Copilot Chat dentro de github.com cuando se trabaja en ese repositorio.
- **Selectivo**: Podés eliminar las secciones de NestJS o Flutter si tu proyecto solo usa uno de los dos stacks.

## Actualizar

```bash
npm run generate:copilot
```
