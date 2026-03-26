# NestJS Code Standards & Best Practices Analysis

> Analyze TypeScript code quality, NestJS patterns, naming conventions, and general coding standards.

---

Goal: Analyze the NestJS codebase for specific code standards and
TypeScript best practices.

STANDARDS SOURCE (local):
- `agent-rules/rules/nestjs/typescript.md`

To resolve the absolute path: find the directory containing
`skills/nestjs-best-practices/SKILL.md`, go up two levels to reach
the somnio-ai-tools repository root, then read the file above.

INSTRUCTIONS:
1. USE the `Read` tool to read the local standards file listed above.
2. Proceed with the analysis below using strict adherence to those rules.

ANALYSIS TARGETS:
1.  **TypeScript Best Practices**:
    *   **Type Declarations**: Check for proper type annotations on all
        function parameters and return types.
    *   **No Any**: Flag usage of `any` type. Suggest proper types.
    *   **Readonly**: Check for `readonly` usage on immutable properties.
    *   **Strict Null Checks**: Verify proper null/undefined handling.

2.  **Naming Conventions**:
    *   **PascalCase**: Classes, interfaces, types, enums.
    *   **camelCase**: Variables, functions, methods, properties.
    *   **kebab-case**: File and directory names.
    *   **UPPERCASE**: Environment variables and constants.
     *   **Verbs**: Functions should start with verbs
       (get, create, update).
     *   **Boolean Prefix**: Boolean variables should use
       is/has/can/should.

3.  **Function Guidelines**:
    *   **Single Purpose**: Functions should be short (<20 lines ideally).
    *   **RO-RO Pattern**: Object parameters for multiple arguments.
    *   **Early Returns**: Avoid deep nesting with early returns.
    *   **Arrow Functions**: Use for simple callbacks (<3 lines).

4.  **NestJS Specifics**:
    *   **Decorators**: Proper usage of @Injectable, @Controller, etc.
    *   **DTOs**: Validate DTO structure with class-validator.
    *   **Services**: One service per entity/domain.
    *   **Modules**: Proper import/export structure.

5.  **Code Organization**:
    *   **One Export Per File**: Check for single export per file.
    *   **Barrel Files**: Verify index.ts for clean imports.
    *   **No Blank Lines in Functions**: Check for clean function bodies.

OUTPUT FORMAT:
*   **Standards Score**: (1-10) based on code quality.
*   **Violations**:
    *   `[Type Issue]` [file:line]: Missing type or using `any`.
    *   `[Naming Issue]` [file:line]: Incorrect naming convention.
    *   `[Function Issue]` [file:line]: Too long, too many params, etc.
    *   `[NestJS Issue]` [file:line]: Missing decorator, bad pattern.
*   **Recommendations**: Specific fixes for each violation type.
