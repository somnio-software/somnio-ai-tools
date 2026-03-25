import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import '../content/skill_bundle.dart';
import '../content/skill_registry.dart';
import '../utils/bundle_detector.dart';
import '../utils/command_helpers.dart';
import '../utils/package_resolver.dart';
import '../utils/registry_modifier.dart';
import '../utils/scaffold_generator.dart';

/// Add a new technology skill bundle to the repository.
///
/// Two modes (auto-detected):
/// - **Wizard**: When `skills/{tech}-*` doesn't exist, scaffolds the
///   folder structure and registers the bundles.
/// - **Auto-detect**: When `skills/{tech}-*` exists, scans for content,
///   validates it, and registers valid bundles.
class AddCommand extends Command<int> {
  AddCommand({required Logger logger}) : _logger = logger {
    argParser.addFlag(
      'force',
      abbr: 'f',
      help: 'Skip confirmation prompts.',
    );
  }

  final Logger _logger;

  /// Tracks short name suffixes claimed during this run so two
  /// bundles added in the same session don't collide.
  final _claimedSuffixes = <String>{};

  @override
  String get name => 'add';

  @override
  String get description =>
      'Add a new technology skill bundle to the repository.';

  @override
  String get invocation => 'somnio add <technology>';

  @override
  Future<int> run() async {
    // Parse technology name from positional argument
    var tech = argResults!.rest.firstOrNull;
    if (tech == null || tech.isEmpty) {
      _logger.err('Missing required argument: technology name.');
      _logger.info('');
      _logger.info('Usage: somnio add <technology>');
      _logger.info('');
      _logger.info('Examples:');
      _logger.info('  somnio add react');
      _logger.info('  somnio add angular');
      _logger.info('  somnio add django');
      return ExitCode.usage.code;
    }

    final force = argResults!['force'] as bool;

    // Auto-lowercase with notice
    final originalTech = tech;
    tech = tech.toLowerCase();
    if (tech != originalTech) {
      _logger.info('Using lowercase: $tech');
    }

    // Validate technology name
    if (!_validateTechName(tech)) {
      return ExitCode.usage.code;
    }

    // Check if technology is already registered
    if (_isTechRegistered(tech)) {
      _logger.err('Technology "$tech" already has registered bundles:');
      for (final skill in SkillRegistry.skills) {
        if (skill.id.startsWith('${tech}_')) {
          _logger.info('  - ${skill.name}: ${skill.displayName}');
        }
      }
      return ExitCode.usage.code;
    }

    // Resolve repo root
    final resolver = PackageResolver();
    final String repoRoot;
    try {
      repoRoot = await resolver.resolveRepoRoot();
    } catch (e) {
      _logger.err('$e');
      return ExitCode.software.code;
    }

    // Mode detection: wizard vs auto-detect
    final healthDir = Directory(p.join(repoRoot, 'skills', '$tech-health-audit'));
    final practicesDir =
        Directory(p.join(repoRoot, 'skills', '$tech-best-practices'));
    if (healthDir.existsSync() || practicesDir.existsSync()) {
      return _handleAutoDetectMode(tech, repoRoot, force);
    } else {
      return _handleWizardMode(tech, repoRoot, force);
    }
  }

  // -------------------------------------------------------------------------
  // Wizard Mode
  // -------------------------------------------------------------------------

  Future<int> _handleWizardMode(
    String tech,
    String repoRoot,
    bool force,
  ) async {
    final techTitle = CommandHelpers.titleCase(tech);

    _logger.info('');
    _logger.info(
      'No existing skills/$tech-* directories found. '
      'Starting wizard to create a new skill bundle.',
    );
    _logger.info('');

    // Step 1: Select skill types
    final typeChoices = [
      'Health Audit (comprehensive project analysis)',
      'Best Practices Check (micro-level code quality)',
    ];

    final List<String> selectedTypes;
    if (force) {
      selectedTypes = typeChoices;
    } else {
      selectedTypes = _logger.chooseAny(
        'Which skill types would you like to create?',
        choices: typeChoices,
        defaultValues: typeChoices,
      );
    }

    if (selectedTypes.isEmpty) {
      _logger.info('No skill types selected.');
      return ExitCode.success.code;
    }

    final createHealth = selectedTypes.contains(typeChoices[0]);
    final createPractices = selectedTypes.contains(typeChoices[1]);

    // Step 2: Generate short name suffixes
    final suffixes = <String, String>{};

    if (createHealth) {
      final suffix = _resolveShortSuffix(tech, 'h', force);
      if (suffix == null) return ExitCode.usage.code;
      suffixes['health'] = suffix;
    }

    if (createPractices) {
      final suffix = _resolveShortSuffix(tech, 'p', force);
      if (suffix == null) return ExitCode.usage.code;
      suffixes['practices'] = suffix;
    }

    // Step 3: Generate defaults and confirm (or edit)
    final displayNames = <String, String>{};
    final descriptions = <String, String>{};

    if (createHealth) {
      displayNames['health'] = '$techTitle Project Health Audit';
      descriptions['health'] =
          'Execute a comprehensive $techTitle Project Health Audit. '
          'Analyzes tech stack, architecture, testing, code quality, '
          'security, CI/CD, and documentation. Produces a detailed '
          'report with section scores and weighted overall score.';
    }

    if (createPractices) {
      displayNames['practices'] = '$techTitle Best Practices Check';
      descriptions['practices'] =
          'Execute a micro-level $techTitle code quality audit. '
          'Validates code against best practices for testing, '
          'architecture, and code implementation. Produces a '
          'detailed violations report with prioritized action plan.';
    }

    if (!force) {
      _logger.info('');
      _logger.info('Will create:');
      if (createHealth) {
        _logger.info(
          '  $tech-health-audit  ${displayNames['health']}',
        );
        _logger.info(
          '${lightGray.wrap('               ${descriptions['health']}')}',
        );
      }
      if (createPractices) {
        _logger.info(
          '  $tech-best-practices  '
          '${displayNames['practices']}',
        );
        _logger.info(
          '${lightGray.wrap('               ${descriptions['practices']}')}',
        );
      }
      _logger.info('');
      _logger.info('  Directory: skills/');
      _logger.info('');

      final answer = _logger
          .prompt(
            'Confirm (yes/edit/cancel)',
            defaultValue: 'yes',
          )
          .toLowerCase()
          .trim();

      if (answer == 'cancel' || answer == 'c' || answer == 'n' ||
          answer == 'no') {
        _logger.info('Cancelled.');
        return ExitCode.success.code;
      }

      if (answer == 'edit' || answer == 'e') {
        if (createHealth) {
          displayNames['health'] = _logger.prompt(
            'Display name for health audit',
            defaultValue: displayNames['health'],
          );
          descriptions['health'] = _logger.prompt(
            'Description for health audit',
            defaultValue: descriptions['health'],
          );
        }
        if (createPractices) {
          displayNames['practices'] = _logger.prompt(
            'Display name for best practices',
            defaultValue: displayNames['practices'],
          );
          descriptions['practices'] = _logger.prompt(
            'Description for best practices',
            defaultValue: descriptions['practices'],
          );
        }
      }
    }

    // Step 6: Scaffold directory structure
    final scaffoldProgress = _logger.progress('Scaffolding skills/$tech-*');
    final scaffold = ScaffoldGenerator(
      repoRoot: repoRoot,
      logger: _logger,
    );

    try {
      await scaffold.generateReadme(tech);

      if (createHealth) {
        await scaffold.generateHealthAudit(
          tech: tech,
          displayName: displayNames['health']!,
        );
      }

      if (createPractices) {
        await scaffold.generateBestPractices(
          tech: tech,
          displayName: displayNames['practices']!,
        );
      }

      scaffoldProgress.complete('Scaffolding complete');
    } catch (e) {
      scaffoldProgress.fail('Scaffolding failed');
      _logger.err('$e');

      // Attempt cleanup
      final healthCleanup =
          Directory(p.join(repoRoot, 'skills', '$tech-health-audit'));
      final practicesCleanup =
          Directory(p.join(repoRoot, 'skills', '$tech-best-practices'));
      final hasPartial =
          healthCleanup.existsSync() || practicesCleanup.existsSync();
      if (hasPartial) {
        final cleanup = force ||
            _logger.confirm(
              'Delete partially created files?',
              defaultValue: true,
            );
        if (cleanup) {
          if (healthCleanup.existsSync()) {
            healthCleanup.deleteSync(recursive: true);
          }
          if (practicesCleanup.existsSync()) {
            practicesCleanup.deleteSync(recursive: true);
          }
          _logger.info('Cleaned up partial scaffolding.');
        }
      }
      return ExitCode.ioError.code;
    }

    // Step 7: Build SkillBundle objects and register
    final bundles = <SkillBundle>[];

    if (createHealth) {
      bundles.add(SkillBundle(
        id: '${tech}_health',
        name: '$tech-health-audit',
        aliases: ['somnio-${suffixes['health']}', suffixes['health']!],
        displayName: displayNames['health']!,
        description: descriptions['health']!,
        planRelativePath: 'skills/$tech-health-audit/SKILL.md',
        rulesDirectory: 'skills/$tech-health-audit/references',
        templatePath: 'skills/$tech-health-audit/assets/report-template.txt',
      ));
    }

    if (createPractices) {
      bundles.add(SkillBundle(
        id: '${tech}_plan',
        name: '$tech-best-practices',
        aliases: ['somnio-${suffixes['practices']}', suffixes['practices']!],
        displayName: displayNames['practices']!,
        description: descriptions['practices']!,
        planRelativePath: 'skills/$tech-best-practices/SKILL.md',
        rulesDirectory: 'skills/$tech-best-practices/references',
        templatePath:
            'skills/$tech-best-practices/assets/report-template.txt',
      ));
    }

    return _registerBundles(bundles, repoRoot);
  }

  // -------------------------------------------------------------------------
  // Auto-detect Mode
  // -------------------------------------------------------------------------

  Future<int> _handleAutoDetectMode(
    String tech,
    String repoRoot,
    bool force,
  ) async {
    final techTitle = CommandHelpers.titleCase(tech);

    _logger.info('');
    _logger.info(
      'Found existing skills/$tech-* directories. '
      'Scanning for skill bundles...',
    );

    // Scan for bundles
    final detector = BundleDetector(
      repoRoot: repoRoot,
      logger: _logger,
    );
    final results = await detector.detectBundles(tech);

    if (results.isEmpty) {
      _logger.info('');
      _logger.warn(
        'No recognizable skill bundles found in skills/.',
      );
      _logger.info(
        'Expected directories matching:',
      );
      _logger.info(
        '  skills/$tech-health-audit/',
      );
      _logger.info(
        '  skills/$tech-best-practices/',
      );
      _logger.info('');

      if (!force) {
        final switchMode = _logger.confirm(
          'Would you like to scaffold new bundles instead?',
        );
        if (switchMode) {
          return _handleWizardMode(tech, repoRoot, force);
        }
      }

      return ExitCode.success.code;
    }

    // Print detection report
    detector.printReport(results);
    _logger.info('');

    // Filter registrable bundles
    final registrable = results.where((r) => r.isRegistrable).toList();

    if (registrable.isEmpty) {
      _logger.err(
        'No bundles are ready to register. '
        'Fix the issues above and try again.',
      );
      return ExitCode.software.code;
    }

    // Generate short names and build bundle data
    final bundleData = <({
      String id,
      String shortSuffix,
      String displayName,
      String description,
      BundleDetectionResult result,
    })>[];

    for (final result in registrable) {
      final suffix = result.bundleType == 'health_audit' ? 'h' : 'p';
      final shortSuffix = _resolveShortSuffix(tech, suffix, force);
      if (shortSuffix == null) return ExitCode.usage.code;

      final id = result.bundleType == 'health_audit'
          ? '${tech}_health'
          : '${tech}_plan';

      final displayName = result.bundleType == 'health_audit'
          ? '$techTitle Project Health Audit'
          : '$techTitle Best Practices Check';

      final description = result.bundleType == 'health_audit'
          ? 'Execute a comprehensive $techTitle Project Health '
              'Audit. Analyzes tech stack, architecture, testing, '
              'code quality, security, CI/CD, and documentation. '
              'Produces a detailed report with section scores and '
              'weighted overall score.'
          : 'Execute a micro-level $techTitle code quality audit. '
              'Validates code against best practices for testing, '
              'architecture, and code implementation. Produces a '
              'detailed violations report with prioritized action '
              'plan.';

      bundleData.add((
        id: id,
        shortSuffix: shortSuffix,
        displayName: displayName,
        description: description,
        result: result,
      ));
    }

    // Editable display names and descriptions
    final editableNames = {
      for (final d in bundleData) d.id: d.displayName,
    };
    final editableDescs = {
      for (final d in bundleData) d.id: d.description,
    };

    // Confirm with preview (or edit)
    if (!force) {
      _logger.info('');
      _logger.info('Will register:');
      for (final d in bundleData) {
        final bundleName = d.result.bundleType == 'health_audit'
            ? '$tech-health-audit'
            : '$tech-best-practices';
        _logger.info(
          '  $bundleName  ${editableNames[d.id]}',
        );
        _logger.info(
          '${lightGray.wrap('               ${editableDescs[d.id]}')}',
        );
      }
      _logger.info('');

      final answer = _logger
          .prompt(
            'Confirm (yes/edit/cancel)',
            defaultValue: 'yes',
          )
          .toLowerCase()
          .trim();

      if (answer == 'cancel' || answer == 'c' || answer == 'n' ||
          answer == 'no') {
        _logger.info('Cancelled.');
        return ExitCode.success.code;
      }

      if (answer == 'edit' || answer == 'e') {
        for (final d in bundleData) {
          editableNames[d.id] = _logger.prompt(
            'Display name',
            defaultValue: editableNames[d.id],
          );
          editableDescs[d.id] = _logger.prompt(
            'Description',
            defaultValue: editableDescs[d.id],
          );
        }
      }
    }

    // Build final SkillBundle objects
    final bundles = <SkillBundle>[];
    for (final d in bundleData) {
      final bundleName = d.result.bundleType == 'health_audit'
          ? '$tech-health-audit'
          : '$tech-best-practices';
      bundles.add(SkillBundle(
        id: d.id,
        name: bundleName,
        aliases: ['somnio-${d.shortSuffix}', d.shortSuffix],
        displayName: editableNames[d.id]!,
        description: editableDescs[d.id]!,
        planRelativePath: d.result.planFile!,
        rulesDirectory: d.result.rulesDirectory!,
        templatePath: d.result.templatePath,
      ));
    }

    return _registerBundles(bundles, repoRoot);
  }

  // -------------------------------------------------------------------------
  // Registry insertion
  // -------------------------------------------------------------------------

  Future<int> _registerBundles(
    List<SkillBundle> bundles,
    String repoRoot,
  ) async {
    final modifier = RegistryModifier(
      repoRoot: repoRoot,
      logger: _logger,
    );

    // Check for conflicts
    if (modifier.hasConflicts(bundles)) {
      return ExitCode.usage.code;
    }

    // Read original for rollback
    final registryPath = p.join(
      repoRoot,
      'cli',
      'lib',
      'src',
      'content',
      'skill_registry.dart',
    );
    final originalContent = File(registryPath).readAsStringSync();

    final registryProgress = _logger.progress(
      'Updating skill registry',
    );

    try {
      await modifier.addBundles(bundles);
      registryProgress.complete('Skill registry updated');
    } catch (e) {
      registryProgress.fail('Registry update failed');
      _logger.err('$e');

      // Rollback
      File(registryPath).writeAsStringSync(originalContent);
      _logger.info('Restored original registry file.');
      return ExitCode.software.code;
    }

    // Print summary
    _logger.info('');
    _logger.success(
      'Successfully added ${bundles.length} skill bundle(s)!',
    );
    _logger.info('');

    for (final bundle in bundles) {
      _logger.info('  ${bundle.name}: ${bundle.displayName}');
    }

    _logger.info('');
    _logger.info('Next steps:');
    _logger.info('  1. Fill in SKILL.md files with execution steps');
    _logger.info(
      '  2. Add reference .md files to references/ directories',
    );
    _logger.info('  3. Customize report templates in assets/');
    _logger.info('  4. Test: somnio claude --force');
    _logger.info('  5. Commit and open a PR');

    return ExitCode.success.code;
  }

  // -------------------------------------------------------------------------
  // Validation helpers
  // -------------------------------------------------------------------------

  bool _validateTechName(String tech) {
    if (tech.length < 2) {
      _logger.err(
        'Technology name must be at least 2 characters.',
      );
      return false;
    }

    final valid = RegExp(r'^[a-z][a-z0-9]+$');
    if (!valid.hasMatch(tech)) {
      _logger.err(
        'Technology name must be lowercase alphanumeric '
        '(a-z, 0-9) and start with a letter.',
      );
      return false;
    }

    return true;
  }

  bool _isTechRegistered(String tech) {
    return SkillRegistry.skills.any(
      (s) => s.id.startsWith('${tech}_'),
    );
  }

  /// Resolves a unique 2-char short name suffix.
  ///
  /// Always prompts the user for the short name (showing a
  /// suggestion as default). If the name is already taken, tells
  /// the user and asks again. Tracks claimed suffixes within the
  /// session so two bundles in the same run don't collide.
  ///
  /// With `--force`, auto-generates without prompting (tries
  /// `{tech[0]}{typeSuffix}`, then increments on conflict).
  String? _resolveShortSuffix(
    String tech,
    String typeSuffix,
    bool force,
  ) {
    final candidate = '${tech[0]}$typeSuffix';
    final typeLabel = typeSuffix == 'h' ? 'health audit' : 'best practices';

    if (force) {
      // Auto-resolve: try candidate, then increment
      if (_isShortNameAvailable(candidate)) {
        _claimedSuffixes.add(candidate);
        return candidate;
      }
      for (var i = 1; i <= 99; i++) {
        final alt = '${tech[0]}$i';
        if (_isShortNameAvailable(alt)) {
          _claimedSuffixes.add(alt);
          return alt;
        }
      }
      _logger.err(
        'Could not auto-generate a unique short name suffix.',
      );
      return null;
    }

    // Show existing names so the user knows what's taken
    final allTaken = [
      ...SkillRegistry.skills.map((s) => s.name),
      ..._claimedSuffixes.map((s) => 'somnio-$s'),
    ];
    _logger.info('');
    _logger.info('Existing commands: ${allTaken.join(', ')}');

    final defaultSuffix = _isShortNameAvailable(candidate) ? candidate : null;

    for (var attempts = 0; attempts < 5; attempts++) {
      final input = _logger.prompt(
        'Short name for $typeLabel (somnio-??)',
        defaultValue: defaultSuffix,
      );

      if (input.length != 2 || !RegExp(r'^[a-z0-9]{2}$').hasMatch(input)) {
        _logger.err(
          'Must be exactly 2 lowercase alphanumeric characters '
          '(a-z, 0-9).',
        );
        continue;
      }

      if (_isShortNameAvailable(input)) {
        _claimedSuffixes.add(input);
        return input;
      }

      _logger.err(
        "'somnio-$input' is already taken. "
        'Choose a different suffix.',
      );
    }

    _logger.err('Failed to resolve a unique short name.');
    return null;
  }

  bool _isShortNameAvailable(String suffix) {
    if (_claimedSuffixes.contains(suffix)) return false;
    final fullName = 'somnio-$suffix';
    return !SkillRegistry.skills.any(
      (s) =>
          s.name == fullName ||
          s.aliases.contains(fullName) ||
          s.aliases.contains(suffix),
    );
  }

}
