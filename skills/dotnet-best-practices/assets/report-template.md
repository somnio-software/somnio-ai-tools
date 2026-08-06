# .NET Best Practices Audit Report

**Project:** [PROJECT_NAME]
**Date:** [AUDIT_DATE]
**Auditor:** AI-Assisted Analysis

---

## 1. Executive Summary

**Overall Score:** [XX]/100 ([Strong/Fair/Weak])

**Description:**
[One paragraph summary of the codebase quality and key findings]

**Top Strengths:**
- [Strength 1]
- [Strength 2]
- [Strength 3]

**Critical Issues:**
- [Critical Issue 1]
- [Critical Issue 2]
- [Critical Issue 3]

**Immediate Action Items:**
1. [Most urgent action]
2. [Second priority action]
3. [Third priority action]

---

## 2. Score Breakdown

| Section | Score | Label |
|---------|-------|-------|
| Testing Quality | [XX]/100 | [Label] |
| Architecture Compliance | [XX]/100 | [Label] |
| SOLID Compliance | [XX]/100 | [Label] |
| Code Standards | [XX]/100 | [Label] |
| DTO Validation | [XX]/100 | [Label] |
| Error Handling | [XX]/100 | [Label] |
| **Weighted Overall** | **[XX]/100** | **[Label]** |

> **Scoring:** Strong (85–100) · Fair (70–84) · Weak (0–69)

---

## 3. Testing Quality

**Score:** [XX]/100 ([Label])

**Description:**
[Summary of testing quality findings]

**Unit Test Analysis:**
- Total test files: [XX]
- Services with unit tests: [XX]%
- Test framework: [xUnit/NUnit/MSTest]

**Integration Test Analysis:**
- Integration test files: [XX]
- `WebApplicationFactory` usage: [Present/Missing]
- Database reset strategy: [Testcontainers + Respawn/InMemory/None]

### Key Findings
- [Finding 1]
- [Finding 2]
- [Finding 3]
- [Finding 4]

### Violations
- `[path/to/FileTests.cs:XX]` — [Issue description]
- `[path/to/FileTests.cs:XX]` — [Issue description]

### Recommendations
1. [Recommendation 1]
2. [Recommendation 2]
3. [Recommendation 3]

---

## 4. Architecture Compliance

**Score:** [XX]/100 ([Label])

**Description:**
[Summary of architecture compliance findings]

**Layer Separation:**
- Controller/Endpoint → Service: [Compliant/Violations Found]
- Service → Repository/DbContext: [Compliant/Violations Found]
- Domain independence: [Compliant/Violations Found]

**Dependency Injection:**
- Constructor injection: [XX]% compliance
- Correct lifetime usage (Scoped/Transient/Singleton): [Compliant/Captive Dependencies Found]

**Module Organization:**
- DI registration extension methods: [XX]
- `Program.cs` size: [XX lines]
- Circular project references: [None/Found]

### Key Findings
- [Finding 1]
- [Finding 2]
- [Finding 3]

### Violations
- `[path/to/File.cs:XX]` — [Layer Violation]: [Description]
- `[path/to/File.cs:XX]` — [DI Issue]: [Description]

### Recommendations
1. [Recommendation 1]
2. [Recommendation 2]
3. [Recommendation 3]

---

## 5. SOLID Compliance

**Score:** [XX]/100 ([Label])

**Description:**
[Summary of SOLID compliance and real cyclomatic complexity findings]

**SOLID Violations:**
- SRP (god-object constructors, oversized methods): [XX] occurrences
- OCP (type-switch chains carrying business logic): [XX] occurrences
- LSP (overrides throwing NotImplementedException): [XX] occurrences
- ISP (fat interfaces, partial implementations): [XX] occurrences
- DIP (`new ConcreteClass()` bypassing an existing abstraction): [XX] occurrences

**Cyclomatic Complexity (forced-analyzer measurement, no files modified):**
- CA1502 (excessive complexity) hits: [XX] (methods: [list])
- CA1506 (excessive class coupling) hits: [XX] (classes: [list])

### Key Findings
- [Finding 1]
- [Finding 2]
- [Finding 3]

### Violations
- `[path/to/File.cs:XX]` — [SOLID Principle]: [Description]
- `[path/to/File.cs:XX]` — [SOLID Principle]: [Description]

### Recommendations
1. [Recommendation 1]
2. [Recommendation 2]
3. [Recommendation 3]

---

## 6. Code Standards

**Score:** [XX]/100 ([Label])

**Description:**
[Summary of code standards findings]

**C# / Nullable Compliance:**
- Nullable reference types: [Enabled/Disabled]
- Null-forgiving (`!`) usage: [XX] occurrences
- Proper typing (`var` vs explicit, no unnecessary `object`): [XX]% compliant

**Naming Conventions:**
- Type/method naming (PascalCase): [XX]% compliant
- Local/parameter naming (camelCase): [XX]% compliant
- Private field naming (`_camelCase`): [XX]% compliant

**Code Design:**
- Average method length: [XX] lines
- Records used for immutable DTOs/value objects: [XX]%
- `async void` violations: [XX]

### Key Findings
- [Finding 1]
- [Finding 2]
- [Finding 3]

### Violations
- `[path/to/File.cs:XX]` — [Type Issue]: [Description]
- `[path/to/File.cs:XX]` — [Naming Issue]: [Description]

### Recommendations
1. [Recommendation 1]
2. [Recommendation 2]
3. [Recommendation 3]

---

## 7. DTO Validation

**Score:** [XX]/100 ([Label])

**Description:**
[Summary of DTO validation findings]

**Validation Coverage:**
- DTOs with validation (Data Annotations/FluentValidation): [XX]%
- Nested object validation coverage: [XX]%
- Optional field handling: [Good/Needs Improvement]

**DTO Organization:**
- Create/Update/Response separation: [Yes/Partial/No]
- Sensitive fields excluded from response DTOs: [Yes/No]
- Entity-to-DTO mapping approach: [Manual/AutoMapper/Mapster]

### Key Findings
- [Finding 1]
- [Finding 2]
- [Finding 3]

### Violations
- `[path/to/Dto.cs:XX]` — [Validation Issue]: [Description]
- `[path/to/Dto.cs:XX]` — [Mapping Issue]: [Description]

### Recommendations
1. [Recommendation 1]
2. [Recommendation 2]
3. [Recommendation 3]

---

## 8. Error Handling

**Score:** [XX]/100 ([Label])

**Description:**
[Summary of error handling findings]

**Exception Usage:**
- Domain-specific exceptions: [XX]% of error cases
- Centralized error definitions: [Yes/No]
- Validation before mutating operations: [XX]% coverage

**Error Infrastructure:**
- `IExceptionHandler`/global middleware: [Present/Missing]
- `ProblemDetails` response shape: [Consistent/Inconsistent]

**Logging:**
- `ILogger<T>` usage: [XX]% of services
- Log-and-rethrow duplication found: [Yes/No]

### Key Findings
- [Finding 1]
- [Finding 2]
- [Finding 3]

### Violations
- `[path/to/File.cs:XX]` — [Exception Issue]: [Description]
- `[path/to/File.cs:XX]` — [Logging Issue]: [Description]

### Recommendations
1. [Recommendation 1]
2. [Recommendation 2]
3. [Recommendation 3]

---

## 9. Prioritized Recommendations

### 🔴 Critical (Must Fix Immediately)
1. [Critical recommendation with file reference]
2. [Critical recommendation with file reference]

### 🟠 High Priority
1. [High priority recommendation]
2. [High priority recommendation]
3. [High priority recommendation]

### 🟡 Medium Priority
1. [Medium priority recommendation]
2. [Medium priority recommendation]
3. [Medium priority recommendation]

### 🟢 Low Priority (Nice to Have)
1. [Low priority recommendation]
2. [Low priority recommendation]

---

## 10. Evidence Index

**Testing Files Analyzed:**
- `[path/to/FileTests.cs]`
- `[path/to/FileTests.cs]`

**Service Files Analyzed:**
- `[path/to/FileService.cs]`
- `[path/to/FileService.cs]`

**Controller/Endpoint Files Analyzed:**
- `[path/to/FileController.cs]`
- `[path/to/FileController.cs]`

**DTO Files Analyzed:**
- `[path/to/FileDto.cs]`
- `[path/to/FileDto.cs]`

**DI/Module Files Analyzed:**
- `[path/to/ServiceCollectionExtensions.cs]`
- `[path/to/Program.cs]`

---

## Report Metadata

| Field | Value |
|-------|-------|
| Generated by | [Plugin Name] v[Plugin Version] |
| Skill | dotnet-best-practices |
| Date | [YYYY-MM-DD] |
| Somnio AI Tools | https://github.com/somnio-software/somnio-ai-tools |
