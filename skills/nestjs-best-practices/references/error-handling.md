# NestJS Error Handling Analysis

> Analyze error handling patterns, exception filters, validation errors, and error response consistency.

---

Goal: Analyze error handling patterns for consistency and best practices.

STANDARDS SOURCE (local):
- `agent-rules/rules/nestjs/error-handling.md`

To resolve the absolute path: find the directory containing
`skills/nestjs-best-practices/SKILL.md`, go up two levels to reach
the somnio-ai-tools repository root, then read the file above.

INSTRUCTIONS:
1. USE the `Read` tool to read the local standards file listed above.
2. Proceed with the analysis below using strict adherence to those rules.

ANALYSIS TARGETS:
1.  **Exception Usage**:
    *   **Specific Exceptions**: Check for proper NestJS exceptions
        (NotFoundException, ConflictException, BadRequestException, etc.)
        instead of generic Error.
    *   **Exception Content**: Verify exceptions include error codes
        and meaningful messages.
    *   **Validation Before Operations**: Check that existence is
        validated before update/delete operations.

2.  **Error Enums & Maps**:
    *   **Error Enums**: Check for centralized error code enums
        (e.g., UserValidationError).
    *   **Error Messages**: Verify error message maps for consistent
        user-facing messages.
    *   **Error Codes**: Check that error responses include machine-
        readable codes.

3.  **Exception Filters**:
     *   **Global Filters**: Check for global exception filter
       registration.
    *   **Prisma Error Handling**: Verify Prisma-specific errors are
        properly handled.
    *   **Error Response Format**: Check for consistent error response
        structure (statusCode, code, message, timestamp).

4.  **Error Logging**:
    *   **Logger Usage**: Check for @nestjs/common Logger usage.
    *   **Stack Traces**: Verify stack traces are logged but not
        exposed to clients.
    *   **Error Severity**: Check for appropriate log levels
        (error vs warn vs log).

5.  **Security Concerns**:
    *   **Production Safety**: Verify internal error details are hidden
        in production.
    *   **No Stack Exposure**: Check that stack traces are not returned
        in responses.
     *   **Sensitive Data**: Ensure errors don't leak sensitive
       information.

6.  **Service Layer Patterns**:
    *   **findOneOrFail Pattern**: Check for existence validation
        with proper exceptions.
    *   **Try-Catch Usage**: Verify try-catch blocks re-throw or
        properly handle errors.
    *   **Error Context**: Check that errors include helpful context
        (IDs, field names).

OUTPUT FORMAT:
*   **Error Handling Score**: (1-10) based on consistency and coverage.
*   **Violations**:
    *   `[Exception Issue]` [file:line]: Incorrect exception type or
        missing error code.
    *   `[Logging Issue]` [file:line]: Missing error logging or
        improper level.
    *   `[Security Issue]` [file:line]: Stack trace or internal
        details exposed.
    *   `[Pattern Issue]` [file:line]: Missing validation before
        operation or silent catch.
*   **Recommendations**: Specific fixes for each violation type.
