# Antigravity

Antigravity lee reglas desde una carpeta `.antigravity/` en la raíz del proyecto, usando archivos `.md` estándar.

## Setup

Copia la carpeta `rules/` de este adapter al directorio `.antigravity/` de tu proyecto:

```bash
cp -r adapters/antigravity/rules/ .antigravity/
```

Estructura resultante en tu proyecto:

```
your-project/
└── .antigravity/
    ├── nestjs/
    │   ├── dto-validation.md
    │   ├── service-patterns.md
    │   └── ...
    └── flutter/
        ├── architecture.md
        └── ...
```

## Reglas disponibles

### NestJS (`nestjs/`)

| Archivo | Propósito |
|---|---|
| `dto-validation.md` | DTOs con class-validator, class-transformer y Swagger |
| `service-patterns.md` | Capa de servicio: patrón RO-RO, transacciones, validación |
| `controller-patterns.md` | Controllers: guards, Swagger docs, formateo de respuestas |
| `repository-patterns.md` | Repository pattern: queries parametrizadas, soft deletes |
| `testing-unit.md` | Tests unitarios: mocking, estructura, Arrange-Act-Assert |
| `testing-integration.md` | Tests de integración: base de datos real, aislamiento |
| `error-handling.md` | Exception filters, error enums, respuestas consistentes |
| `module-structure.md` | Organización de módulos, DI, barrel exports |
| `typescript.md` | Guías de TypeScript, convenciones de naming |

### Flutter (`flutter/`)

| Archivo | Propósito |
|---|---|
| `architecture.md` | Arquitectura en capas: Data, Repository, BLoC, Presentation |
| `best-practices.md` | Best practices generales: SOLID, estado, navegación, theming |
| `bloc-test.md` | Estructura y patrones de tests para BLoC |
| `testing.md` | Best practices de testing: mocking, matchers, agrupación |
| `dart-model-from-json.md` | Generación de modelos JSON con json_serializable y equatable |

## Actualizar

Cuando se modifiquen las reglas en `rules/`, regenerar este adapter:

```bash
npm run generate:antigravity
```
