# Cursor

Cursor carga reglas desde `.cursor/rules/` en la raíz del proyecto. Cada archivo `.mdc` tiene metadatos YAML que controlan cuándo se aplica la regla.

## Setup

Copia la carpeta `rules/` de este adapter al directorio `.cursor/rules/` de tu proyecto:

```bash
cp -r adapters/cursor/rules/ your-project/.cursor/rules/
```

Estructura resultante:

```
your-project/
└── .cursor/
    └── rules/
        ├── nestjs/
        │   ├── nestjs-dto-validation.mdc
        │   ├── nestjs-service-patterns.mdc
        │   └── ...
        └── flutter/
            ├── flutter-architecture.mdc
            └── ...
```

## Comportamiento

- **Auto-apply por glob**: Cada regla tiene un patrón de glob en su frontmatter. Cursor la aplica automáticamente cuando editás un archivo que coincide (ej: `nestjs-service-patterns` se activa al editar `*.service.ts`).
- **Referencia manual**: Podés referenciar una regla explícitamente en el chat con `@nombre-de-regla` (ej: `@nestjs-dto-validation`).
- **`alwaysApply: true`**: Las reglas con este flag se aplican en todos los archivos del proyecto sin importar el glob.

## Reglas disponibles

### NestJS

| Regla | Glob | Referencia |
|---|---|---|
| `nestjs-dto-validation` | `**/*.dto.ts` | `@nestjs-dto-validation` |
| `nestjs-service-patterns` | `**/*.service.ts` | `@nestjs-service-patterns` |
| `nestjs-controller-patterns` | `**/*.controller.ts` | `@nestjs-controller-patterns` |
| `nestjs-repository-patterns` | `**/*.repository.ts` | `@nestjs-repository-patterns` |
| `nestjs-testing-unit` | `**/*.spec.ts` | `@nestjs-testing-unit` |
| `nestjs-testing-integration` | `**/*.integration.spec.ts` | `@nestjs-testing-integration` |
| `nestjs-error-handling` | `**/*exception*.ts`, etc. | `@nestjs-error-handling` |
| `nestjs-module-structure` | `**/*.module.ts` | `@nestjs-module-structure` |
| `nestjs-typescript` | `src/modules/**/*.ts` | `@nestjs-typescript` |

### Flutter

| Regla | Glob | Referencia |
|---|---|---|
| `flutter-architecture` | `**/*.dart` | `@flutter-architecture` |
| `flutter-best-practices` | `**/*.dart` | `@flutter-best-practices` |
| `flutter-bloc-test` | `**/*bloc_test.dart` | `@flutter-bloc-test` |
| `flutter-dart-model-from-json` | `**/*.dart` | `@flutter-dart-model-from-json` |
| `flutter-testing` | `**/*_test.dart` | `@flutter-testing` |

## Actualizar

```bash
cd agent-rules && python3 scripts/generate.py --only cursor
```
