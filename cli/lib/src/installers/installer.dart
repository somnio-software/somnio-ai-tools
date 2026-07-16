import 'package:mason_logger/mason_logger.dart';

import '../content/content_loader.dart';
import '../content/skill_bundle.dart';

/// Result of an installation operation.
class InstallResult {
  const InstallResult({
    required this.skillCount,
    required this.ruleCount,
    required this.targetDirectory,
    this.skippedCount = 0,
    this.failedCount = 0,
  });

  final int skillCount;
  final int ruleCount;
  final String targetDirectory;

  /// Number of bundles skipped (e.g., missing workflow files).
  ///
  /// A skip is a normal outcome, not an error — see [failedCount].
  final int skippedCount;

  /// Number of bundles that threw while installing.
  ///
  /// Callers map a non-zero count to a non-zero process exit code so CI can
  /// tell a broken install from a clean one.
  final int failedCount;
}

/// How many workflow skills were written, and how many threw.
typedef WorkflowInstallCounts = ({int installed, int failed});

/// Abstract base class for agent-specific installers.
abstract class Installer {
  const Installer({required this.logger, required this.loader});

  final Logger logger;
  final ContentLoader loader;

  /// Installs all skill bundles to the agent's global directory.
  ///
  /// Existing somnio-owned files are always overwritten; installs are
  /// idempotent and never prompt.
  Future<InstallResult> install({required List<SkillBundle> bundles});

  /// Checks if skills are already installed.
  bool isInstalled();

  /// Returns the count of installed items.
  int installedCount();
}
