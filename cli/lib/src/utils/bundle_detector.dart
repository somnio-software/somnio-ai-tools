import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Result of detecting a single skill bundle in a technology directory.
class BundleDetectionResult {
  const BundleDetectionResult({
    required this.bundleType,
    required this.subdirectory,
    this.planFile,
    this.rulesDirectory,
    this.ruleCount = 0,
    this.validRuleCount = 0,
    this.templatePath,
    this.errors = const [],
  });

  /// Bundle type: 'health_audit' or 'best_practices'.
  final String bundleType;

  /// Name of the subdirectory (e.g., 'react-health-audit').
  final String subdirectory;

  /// Path to the plan file, relative to repo root, or null if not found.
  final String? planFile;

  /// Path to the references directory, relative to repo root, or null.
  final String? rulesDirectory;

  /// Total number of reference files found in references/.
  final int ruleCount;

  /// Number of reference files that are valid.
  final int validRuleCount;

  /// Path to the template file, relative to repo root, or null.
  final String? templatePath;

  /// Validation errors found during detection.
  final List<String> errors;

  /// Whether this bundle has enough content to be registered.
  bool get isRegistrable => planFile != null && validRuleCount > 0;
}

/// Scans the skills/ directory for skill bundles matching a technology
/// and validates their content.
class BundleDetector {
  BundleDetector({required this.repoRoot, required Logger logger})
      : _logger = logger;

  final String repoRoot;
  final Logger _logger;

  /// Scans skills/ for directories matching {tech}-*.
  Future<List<BundleDetectionResult>> detectBundles(String tech) async {
    final skillsDir = Directory(p.join(repoRoot, 'skills'));
    if (!skillsDir.existsSync()) return [];

    final results = <BundleDetectionResult>[];

    final subdirs = skillsDir
        .listSync()
        .whereType<Directory>()
        .where((d) => p.basename(d.path).startsWith('$tech-'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    for (final subdir in subdirs) {
      final dirName = p.basename(subdir.path);
      final bundleType = _classifyBundleType(dirName);
      if (bundleType == null) continue;

      results.add(await _detectBundle(tech, dirName, bundleType));
    }

    return results;
  }

  /// Classifies a subdirectory name into a bundle type.
  String? _classifyBundleType(String dirName) {
    if (dirName.endsWith('-health-audit') ||
        dirName.contains('health-audit')) {
      return 'health_audit';
    }
    if (dirName.endsWith('-best-practices') ||
        dirName.contains('best-practices')) {
      return 'best_practices';
    }
    return null;
  }

  /// Detects a single bundle from a subdirectory.
  Future<BundleDetectionResult> _detectBundle(
    String tech,
    String subdirectory,
    String bundleType,
  ) async {
    final baseDir = p.join(repoRoot, 'skills', subdirectory);
    final errors = <String>[];

    // Detect SKILL.md plan file
    final planFile = _findPlanFile(baseDir, bundleType);
    if (planFile == null) {
      errors.add('No SKILL.md file found in bundle directory');
    }

    // Detect references/ directory
    final refsDir = p.join(baseDir, 'references');
    String? refsRelPath;
    var ruleCount = 0;
    var validRuleCount = 0;

    if (Directory(refsDir).existsSync()) {
      refsRelPath = p.relative(refsDir, from: repoRoot);
      final ruleValidation = await _validateReferences(refsDir);
      ruleCount = ruleValidation.total;
      validRuleCount = ruleValidation.valid;

      if (ruleCount == 0) {
        errors.add('No reference files found in references/');
      } else if (validRuleCount < ruleCount) {
        final invalid = ruleCount - validRuleCount;
        errors.add('$invalid/$ruleCount reference files failed validation');
      }
    } else {
      errors.add('references/ directory not found');
    }

    // Detect template
    final templatePath = _findTemplate(baseDir, tech, bundleType);

    return BundleDetectionResult(
      bundleType: bundleType,
      subdirectory: subdirectory,
      planFile: planFile != null
          ? p.relative(planFile, from: repoRoot)
          : null,
      rulesDirectory: refsRelPath,
      ruleCount: ruleCount,
      validRuleCount: validRuleCount,
      templatePath: templatePath != null
          ? p.relative(templatePath, from: repoRoot)
          : null,
      errors: errors,
    );
  }

  /// Finds a SKILL.md file in the bundle directory.
  String? _findPlanFile(String baseDir, String bundleType) {
    final skillFile = File(p.join(baseDir, 'SKILL.md'));
    if (skillFile.existsSync()) return skillFile.path;
    return null;
  }

  /// Validates reference files (.md and .yaml) and returns counts.
  Future<_RuleValidation> _validateReferences(String refsDir) async {
    final dir = Directory(refsDir);
    final refFiles = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.md') || f.path.endsWith('.yaml'))
        .toList();

    var valid = 0;
    for (final file in refFiles) {
      if (await _isValidReference(file)) {
        valid++;
      } else {
        _logger.detail(
          '  Invalid reference: ${p.basename(file.path)}',
        );
      }
    }

    return _RuleValidation(total: refFiles.length, valid: valid);
  }

  /// Checks if a reference file has valid content.
  ///
  /// For .md files: checks for a heading (# ...) as minimal structure.
  /// For .yaml files: checks for the legacy YAML rule structure.
  Future<bool> _isValidReference(File file) async {
    try {
      final content = file.readAsStringSync();
      if (content.trim().isEmpty) return false;

      if (file.path.endsWith('.md')) {
        // Markdown reference: must have at least a heading
        return content.contains(RegExp(r'^#\s+.+', multiLine: true));
      }

      if (file.path.endsWith('.yaml')) {
        // Legacy YAML rule format
        final doc = loadYaml(content);
        if (doc is! YamlMap) return false;
        if (!doc.containsKey('rules')) return false;

        final rules = doc['rules'];
        if (rules is! YamlList || rules.isEmpty) return false;

        final rule = rules.first;
        if (rule is! YamlMap) return false;

        for (final field in ['name', 'description', 'match', 'prompt']) {
          if (!rule.containsKey(field)) return false;
          final value = rule[field];
          if (value is! String || value.isEmpty) return false;
        }
        return true;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  /// Finds a report template file in assets/.
  String? _findTemplate(
    String baseDir,
    String tech,
    String bundleType,
  ) {
    final assetsDir = p.join(baseDir, 'assets');
    if (!Directory(assetsDir).existsSync()) return null;

    final templates = Directory(assetsDir)
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.txt'))
        .toList();

    if (templates.isEmpty) return null;
    return templates.first.path;
  }

  /// Prints a detection report for the given results.
  void printReport(List<BundleDetectionResult> results) {
    for (final result in results) {
      final typeLabel = result.bundleType == 'health_audit'
          ? 'Health Audit'
          : 'Best Practices';
      _logger.info('');
      _logger.info('  $typeLabel (${result.subdirectory}):');

      // Plan file
      if (result.planFile != null) {
        _logger.info(
          '    ${lightGreen.wrap('[x]')} SKILL.md: found',
        );
      } else {
        _logger.info(
          '    ${lightRed.wrap('[ ]')} SKILL.md: not found',
        );
      }

      // References
      if (result.rulesDirectory != null && result.ruleCount > 0) {
        final validLabel = result.validRuleCount == result.ruleCount
            ? '${result.ruleCount} references'
            : '${result.validRuleCount}/${result.ruleCount} valid';
        _logger.info(
          '    ${lightGreen.wrap('[x]')} References: '
          'references/ ($validLabel)',
        );
      } else {
        _logger.info(
          '    ${lightRed.wrap('[ ]')} References: '
          'no reference files found',
        );
      }

      // Template
      if (result.templatePath != null) {
        _logger.info(
          '    ${lightGreen.wrap('[x]')} Template: '
          '${p.basename(result.templatePath!)}',
        );
      } else {
        _logger.info(
          '    ${lightYellow.wrap('[-]')} Template: not found '
          '(optional)',
        );
      }

      // Status
      if (result.isRegistrable) {
        _logger.info(
          '    Status: ${lightGreen.wrap('Ready to register')}',
        );
      } else {
        _logger.info(
          '    Status: ${lightRed.wrap('Cannot register')} '
          '- missing required components',
        );
        for (final error in result.errors) {
          _logger.info('      - $error');
        }
      }
    }
  }
}

class _RuleValidation {
  const _RuleValidation({required this.total, required this.valid});
  final int total;
  final int valid;
}
