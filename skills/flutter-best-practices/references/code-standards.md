# Flutter Code Standards & Best Practices Analysis

> Analyze model structure, JSON serialization, errors, and general Flutter styling against specific standards.

---

Goal: Analyze the Flutter codebase for specific code standards, model
best practices, and error handling.

STANDARDS SOURCE:
- https://raw.githubusercontent.com/somnio-software/cursor-rules/main/.cursor/rules/flutter/dart-model-from-json.mdc
- https://raw.githubusercontent.com/somnio-software/cursor-rules/main/.cursor/rules/flutter/flutter-ai-rules.mdc

INSTRUCTIONS:
 1.  **SCOPE**: You must analyze **ALL** Dart files for code standards
     violations.
 2.  **DISCOVERY**: Execute `echo "Dart files to analyze: $(find . \
     -type f -name "*.dart" -not -path "*/.*" -not -name "*.g.dart" \
     -not -name "*.freezed.dart" 2>/dev/null | wc -l)"` to count source
     files. Then use `glob_file_search` with pattern `**/*.dart` to find
     all Dart files for analysis (excluding generated files).
 3.  **STANDARDS**: USE the `read_url_content` tool to fetch the latest
     standards from the URLs above.
 4.  **EFFICIENCY**: When iterating through files, read 3-5 files per
     response using parallel tool calls. Do NOT read one file per
     response — this causes massive context accumulation. Group files
     by directory when possible.
 5.  **ANALYSIS**: Iterate through **EACH** file found using
     glob_file_search in step 2:
    a. Read the file content.
    b. Analyze strictly against the standards.

ANALYSIS TARGETS:
1.  **JSON Model Best Practices**:
    *   **Attributes**: Check for `required` on non-nullable fields.
    *   **Annotations**: Verify usage of `@JsonSerializable()`.
    *   **Immutability**: Ensure models extend `Equatable` and fields
        are `final`.
    *   **Props**: Verify `props` getter implementation for Equatable.
    *   **Copy**: Check for `copyWith` method implementation.
    *   **Serialization**: Check for `fromJson` and `toJson` methods.

2.  **Code Generosity & Conciseness**:
    *   Flag verbose boilerplate that could be simplified.
    *   Check for clear, descriptive variable/function names (avoid
        abbreviations).
    *   Enforce "Widgets in separate files" for large widget trees.

3.  **Error Handling**:
    *   Flag empty `catch` blocks (silent failures).
    *   Check for `print()` statements (suggest `logging` package).
    *   Verify errors are rethrown or handled with UI feedback.

4.  **Formatting & Layout**:
    *   Line length awareness (soft check).
    *   Suggest specific type definitions over `var` where type logic
        is complex.

OUTPUT FORMAT:
*   **Standards Score**: (1-10) based on code quality.
*   **Violations**:
    *   `[Model Violation]` [file:line]: Missing Equatable, mutable
        fields, etc.
    *   `[Style Issue]` [file:line]: Naming, boilerplate.
    *   `[Error Handling]` [file:line]: Silent catch, print usage.
*   **Recommendations**: Specific fixes for each violation type.
