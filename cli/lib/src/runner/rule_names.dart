/// Pure, testable constants and helpers for matching rule names against the
/// hyphenated names the plan parser actually produces (`report-generator`,
/// `report-format-enforcer`, `tool-installer`, ...) and for mapping a rule
/// name to the underscore-prefixed artifact key that [PreflightRunner]
/// writes.
///
/// Deliberately kept outside `run_command.dart` (which carries
/// `// coverage:ignore-file`) so this logic is covered by tests — a prior
/// bug had these comparisons silently never match because the rule names
/// use hyphens while the checks used underscores.
library;

/// The rule name the plan parser emits for the report-generator step.
const String kReportGeneratorRuleName = 'report-generator';

/// The rule name of the format-enforcement step that runs immediately after
/// the report generator.
const String kReportFormatEnforcerRuleName = 'report-format-enforcer';

/// Maps a tech prefix and a hyphenated rule name to the underscore-joined
/// artifact key that [PreflightRunner] writes into
/// `PreflightResult.artifacts`.
///
/// Example: `preflightKey('flutter', 'tool-installer')` ==
/// `'flutter_tool_installer'`.
String preflightKey(String techPrefix, String ruleName) =>
    '${techPrefix}_${ruleName.replaceAll('-', '_')}';

/// The rule name the plan parser emits for the best-practices generator
/// step used by the `*_plan` bundles.
const String kBestPracticesGeneratorRuleName = 'best-practices-generator';

/// The format-enforcement rule that pairs with the best-practices generator.
const String kBestPracticesFormatEnforcerRuleName =
    'best-practices-format-enforcer';

/// Whether [ruleName] is a terminal generator step that must be dispatched
/// to `StepExecutor.executeReportGenerator` (reads the template and all
/// artifacts, then writes `RunConfig.reportPath`).
bool isReportGeneratorRule(String ruleName) =>
    ruleName == kReportGeneratorRuleName ||
    ruleName == kBestPracticesGeneratorRuleName;

/// The format-enforcer rule that pairs with [generatorRuleName], or `null`
/// when the step is not a generator.
String? formatEnforcerRuleFor(String generatorRuleName) =>
    switch (generatorRuleName) {
      kReportGeneratorRuleName => kReportFormatEnforcerRuleName,
      kBestPracticesGeneratorRuleName =>
        kBestPracticesFormatEnforcerRuleName,
      _ => null,
    };
