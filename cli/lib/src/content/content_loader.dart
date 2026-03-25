import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'skill_bundle.dart';

/// Parsed rule data from a YAML cursor rule file or Markdown reference file.
class ParsedRule {
  const ParsedRule({
    required this.name,
    required this.description,
    required this.match,
    required this.prompt,
    required this.fileName,
  });

  final String name;
  final String description;
  final String match;
  final String prompt;

  /// Original file name without extension (e.g., 'tool-installer').
  final String fileName;
}

/// Loads and parses content from the skills/ directory.
class ContentLoader {
  const ContentLoader(this.repoRoot);

  /// Absolute path to the somnio-ai-tools repo root.
  final String repoRoot;

  /// Reads the SKILL.md file for a skill bundle.
  ///
  /// Strips YAML frontmatter (between --- delimiters) and
  /// HTML comment UUID line if present.
  String loadPlan(SkillBundle bundle) {
    final planPath = p.join(repoRoot, bundle.planRelativePath);
    final file = File(planPath);
    if (!file.existsSync()) {
      throw FileSystemException(
        'Plan file not found',
        planPath,
      );
    }
    var content = file.readAsStringSync();

    // Strip YAML frontmatter (between --- delimiters)
    if (content.startsWith('---')) {
      final endIndex = content.indexOf('---', 3);
      if (endIndex != -1) {
        content = content.substring(endIndex + 3);
      }
    }

    // Strip HTML comment UUID line if present (first line)
    if (content.trimLeft().startsWith('<!--')) {
      final trimmed = content.trimLeft();
      final newlineIndex = trimmed.indexOf('\n');
      if (newlineIndex != -1) {
        content = trimmed.substring(newlineIndex + 1);
      }
    }

    return content.trimLeft();
  }

  /// Parses all reference files from the references/ directory of a bundle.
  ///
  /// Supports both Markdown (.md) reference files and legacy YAML (.yaml)
  /// rule files. Skips the `assets/` subdirectory.
  List<ParsedRule> loadRules(SkillBundle bundle) {
    final rulesDir = Directory(p.join(repoRoot, bundle.rulesDirectory));
    if (!rulesDir.existsSync()) {
      throw FileSystemException(
        'References directory not found',
        rulesDir.path,
      );
    }

    final rules = <ParsedRule>[];
    final files = rulesDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.yaml') || f.path.endsWith('.md'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    for (final file in files) {
      ParsedRule? parsed;
      if (file.path.endsWith('.yaml')) {
        parsed = _parseYamlRule(file);
      } else if (file.path.endsWith('.md')) {
        parsed = _parseMdReference(file);
      }
      if (parsed != null) rules.add(parsed);
    }

    return rules;
  }

  /// Loads the template file for a skill bundle, if it exists.
  String? loadTemplate(SkillBundle bundle) {
    if (bundle.templatePath == null) return null;
    final file = File(p.join(repoRoot, bundle.templatePath!));
    if (!file.existsSync()) return null;
    return file.readAsStringSync();
  }

  /// Loads the Antigravity workflow file for a skill bundle, if it exists.
  String? loadWorkflow(SkillBundle bundle) {
    if (bundle.workflowPath == null) return null;
    final file = File(p.join(repoRoot, bundle.workflowPath!));
    if (!file.existsSync()) return null;
    return file.readAsStringSync();
  }

  /// Lists all files in the references directory including assets subdirectory.
  ///
  /// Returns paths relative to the references directory.
  List<String> listAllRuleFiles(SkillBundle bundle) {
    final rulesDir = Directory(p.join(repoRoot, bundle.rulesDirectory));
    if (!rulesDir.existsSync()) return [];

    final files = <String>[];
    for (final entity in rulesDir.listSync(recursive: true)) {
      if (entity is File) {
        files.add(p.relative(entity.path, from: rulesDir.path));
      }
    }
    files.sort();
    return files;
  }

  /// Returns the absolute path of a file within the references directory.
  String rulesFilePath(SkillBundle bundle, String relativePath) {
    return p.join(repoRoot, bundle.rulesDirectory, relativePath);
  }

  /// Parses a legacy YAML rule file.
  ParsedRule? _parseYamlRule(File file) {
    try {
      final content = file.readAsStringSync();
      final doc = loadYaml(content) as YamlMap;
      final rules = doc['rules'] as YamlList;
      if (rules.isEmpty) return null;

      final rule = rules.first as YamlMap;
      final name = rule['name'] as String;
      final description = (rule['description'] as String).trim();
      final match = rule['match'] as String;
      final prompt = (rule['prompt'] as String).trimRight();

      final fileName = p.basenameWithoutExtension(file.path);

      return ParsedRule(
        name: name,
        description: description,
        match: match,
        prompt: prompt,
        fileName: fileName,
      );
    } catch (e) {
      // Skip files that can't be parsed
      return null;
    }
  }

  /// Parses a Markdown reference file into a [ParsedRule].
  ///
  /// Expected format:
  /// ```
  /// # Rule Name
  ///
  /// > Description text
  ///
  /// **File pattern**: `*`
  ///
  /// ---
  ///
  /// Prompt content...
  /// ```
  ParsedRule? _parseMdReference(File file) {
    try {
      final content = file.readAsStringSync();
      final lines = content.split('\n');

      // Extract name from # heading
      var name = '';
      var description = '';
      var match = '*';
      var promptStart = 0;

      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (name.isEmpty && line.startsWith('# ')) {
          name = line.substring(2).trim();
        } else if (description.isEmpty && line.startsWith('> ')) {
          description = line.substring(2).trim();
        } else if (line.startsWith('**File pattern**: ')) {
          final patternMatch = RegExp(r'`([^`]+)`').firstMatch(line);
          if (patternMatch != null) {
            match = patternMatch.group(1)!;
          }
        } else if (line.trim() == '---' && name.isNotEmpty) {
          promptStart = i + 1;
          // Skip blank line after ---
          if (promptStart < lines.length &&
              lines[promptStart].trim().isEmpty) {
            promptStart++;
          }
          break;
        }
      }

      if (name.isEmpty || promptStart == 0) return null;

      final prompt = lines.sublist(promptStart).join('\n').trimRight();
      final fileName = p.basenameWithoutExtension(file.path);

      return ParsedRule(
        name: name,
        description: description,
        match: match,
        prompt: prompt,
        fileName: fileName,
      );
    } catch (e) {
      return null;
    }
  }
}
