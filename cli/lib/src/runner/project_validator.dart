import 'dart:io';

import 'package:path/path.dart' as p;

import 'nextjs_redirect.dart';

/// Validates the current working directory is the correct project type
/// before running a health audit.
///
/// Known technologies have specific validation rules. Unknown technologies
/// (added via `somnio add`) are validated with a generic check based on
/// common project file conventions.
class ProjectValidator {
  /// Known technology prefix → project marker file.
  ///
  /// For technologies requiring additional checks beyond file existence,
  /// use the specific validate methods.
  static const _projectMarkers = {
    'flutter': 'pubspec.yaml',
    'dart': 'pubspec.yaml',
    'nestjs': 'package.json',
    'nextjs': 'package.json',
    'react': 'package.json',
    'angular': 'package.json',
    'vue': 'package.json',
    'node': 'package.json',
    'go': 'go.mod',
    'rust': 'Cargo.toml',
    'python': 'pyproject.toml',
    'ruby': 'Gemfile',
    'swift': 'Package.swift',
    'kotlin': 'build.gradle.kts',
    'java': 'pom.xml',
  };

  /// Validates the CWD for the given technology prefix.
  ///
  /// Returns `null` on success, error message on failure.
  String? validate(String techPrefix, String cwd) {
    // Dispatch to specific validators for known technologies
    switch (techPrefix) {
      case 'flutter':
        return _validateFlutter(cwd);
      case 'nestjs':
        return _validateNestjs(cwd);
      case 'nextjs':
      case 'nextjs_security':
        return _validateNextjs(cwd);
      case 'security':
        return null; // Framework-agnostic, works on any project
      default:
        return _validateGeneric(techPrefix, cwd);
    }
  }

  String? _validateFlutter(String cwd) {
    final pubspec = File(p.join(cwd, 'pubspec.yaml'));
    if (!pubspec.existsSync()) {
      return 'No pubspec.yaml found in current directory.\n'
          'Please run this command from a Flutter project root.';
    }
    return null;
  }

  String? _validateNestjs(String cwd) {
    final packageJson = File(p.join(cwd, 'package.json'));
    if (!packageJson.existsSync()) {
      return 'No package.json found in current directory.\n'
          'Please run this command from a NestJS project root.';
    }
    final content = packageJson.readAsStringSync();
    if (!content.contains('@nestjs/core')) {
      return 'package.json does not contain @nestjs/core dependency.\n'
          'This does not appear to be a NestJS project.';
    }
    return null;
  }

  String? _validateNextjs(String cwd) {
    final packageJson = File(p.join(cwd, 'package.json'));
    if (!packageJson.existsSync()) {
      return 'No package.json found in current directory.\n'
          'Please run this command from a Next.js project root.';
    }
    final content = packageJson.readAsStringSync();
    if (!dependsOnNext(content)) {
      return 'package.json does not contain the next dependency.\n'
          'This does not appear to be a Next.js project.';
    }
    return null;
  }

  /// Generic validation for technologies added via `somnio add`.
  ///
  /// Checks for the project marker file associated with the tech prefix.
  /// If no known marker exists, returns `null` (skips validation).
  String? _validateGeneric(String techPrefix, String cwd) {
    final marker = _projectMarkers[techPrefix];
    if (marker == null) {
      // Unknown technology — no validation possible, allow to proceed
      return null;
    }
    final file = File(p.join(cwd, marker));
    if (!file.existsSync()) {
      return 'No $marker found in current directory.\n'
          'Please run this command from a $techPrefix project root.';
    }
    return null;
  }
}
