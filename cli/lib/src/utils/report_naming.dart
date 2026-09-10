/// Pure, testable helpers that build the canonical report file name shared by
/// every audit skill: `YYYY-MM-DD-<project-slug>-<report-type>.md`.
///
/// The date comes first so `ls reports/` sorts chronologically on its own, and
/// the project slug makes reports from different projects distinguishable once
/// they are collected into a shared folder.
///
/// Everything is kebab-case, including the separators between segments: the
/// report type is a skill name (`security-audit`, `nestjs-health-audit`), which
/// is already kebab-case across the repo, and the ISO date already uses
/// hyphens. Mixing in underscores would mean two rules to remember for one
/// file name.
///
/// Deliberately kept outside `run_command.dart` (which carries
/// `// coverage:ignore-file`) so this logic is covered by tests — the same
/// reason `rule_names.dart` lives on its own.
library;

/// Fallback slug used when [projectSlug] receives input that slugifies to
/// nothing (an empty string, or only separators and symbols).
const String kFallbackProjectSlug = 'project';

/// Converts an arbitrary project identifier into a kebab-case slug safe for a
/// file name.
///
/// Lowercases, turns spaces, underscores, dots and slashes into hyphens, drops
/// everything that is not `[a-z0-9-]`, then collapses runs of hyphens and
/// trims them from both ends.
///
/// Examples:
/// - `Hoopis_Backend` -> `hoopis-backend`
/// - `@hoopis/backend` -> `hoopis-backend`
/// - `Example Project` -> `example-project`
/// - `---` -> `project` ([kFallbackProjectSlug])
String projectSlug(String raw) {
  final slug = raw
      .toLowerCase()
      .replaceAll(RegExp(r'[\s_./\\]+'), '-')
      .replaceAll(RegExp('[^a-z0-9-]'), '')
      .replaceAll(RegExp('-+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.isEmpty ? kFallbackProjectSlug : slug;
}

/// Formats [date] as `YYYY-MM-DD` using its local calendar fields.
String isoDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year.toString().padLeft(4, '0')}-$month-$day';
}

/// Builds the canonical report file name.
///
/// [reportType] is the skill name as registered in `SkillRegistry`
/// (`SkillBundle.name`), which is already the kebab-case report type:
/// `security-audit`, `nestjs-health-audit`, `flutter-best-practices`.
///
/// [project] is slugified via [projectSlug], so callers can pass a raw
/// directory name or manifest name without pre-processing it.
///
/// Example: `2026-09-14-hoopis-backend-security-audit.md`.
String reportFileName({
  required DateTime date,
  required String project,
  required String reportType,
  String extension = 'md',
}) =>
    '${isoDate(date)}-${projectSlug(project)}-$reportType.$extension';
