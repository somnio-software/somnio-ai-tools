/// Pure, testable helpers that build the canonical report file name shared by
/// every audit skill: `YYYY-MM-DD-<project-slug>-<report-type>.md`.
///
/// The project segment is the git repository name (see `repo_name.dart`), so
/// the same repo yields the same name whatever its checkout directory is
/// called, from a linked worktree, or from a monorepo subdirectory.
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

/// Extracts the repository name from a git remote URL.
///
/// Handles the scp-like SSH form (`git@github.com:org/repo.git`), URL forms
/// (`https://`, `ssh://`, `git://`, `file://`) and plain paths, with or without
/// a trailing `.git` or `/`. Returns `null` when no name can be extracted.
///
/// Examples:
/// - `git@github.com:somnio/hoopis-backend.git` -> `hoopis-backend`
/// - `https://github.com/somnio/hoopis-backend` -> `hoopis-backend`
String? repoNameFromRemoteUrl(String url) {
  final trimmed = url.trim().replaceAll(RegExp(r'[/\\]+$'), '');
  final lastSegment = trimmed.split(RegExp(r'[/\\:]')).last;
  final name = lastSegment.endsWith('.git')
      ? lastSegment.substring(0, lastSegment.length - 4)
      : lastSegment;
  return name.isEmpty ? null : name;
}

/// Extracts the repository name from the output of
/// `git rev-parse --path-format=absolute --git-common-dir`.
///
/// The common dir is shared by every worktree, so this yields the main
/// checkout's name even from a linked worktree: `/src/hoopis-backend/.git`
/// -> `hoopis-backend`. A bare repository (`/srv/hoopis-backend.git`) loses
/// its `.git` suffix. Returns `null` when no name can be extracted.
String? repoNameFromGitCommonDir(String commonDir) {
  final segments = commonDir
      .trim()
      .split(RegExp(r'[/\\]+'))
      .where((s) => s.isNotEmpty)
      .toList();
  if (segments.isEmpty) return null;
  final last = segments.last;
  if (last == '.git') {
    return segments.length > 1 ? segments[segments.length - 2] : null;
  }
  final name =
      last.endsWith('.git') ? last.substring(0, last.length - 4) : last;
  return name.isEmpty ? null : name;
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
