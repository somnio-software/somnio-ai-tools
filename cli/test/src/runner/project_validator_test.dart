import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:somnio/src/runner/project_validator.dart';
import 'package:test/test.dart';

void main() {
  late ProjectValidator validator;
  late Directory tmpDir;

  setUp(() {
    validator = ProjectValidator();
    tmpDir = Directory.systemTemp.createTempSync('somnio_pv_');
    addTearDown(() => tmpDir.deleteSync(recursive: true));
  });

  void writeFile(String name, String content) {
    File(p.join(tmpDir.path, name)).writeAsStringSync(content);
  }

  // ---------------------------------------------------------------------------
  // validate() dispatch
  // ---------------------------------------------------------------------------
  group('validate dispatch', () {
    test('flutter dispatches to _validateFlutter (success)', () {
      writeFile('pubspec.yaml', 'name: app');
      expect(validator.validate('flutter', tmpDir.path), isNull);
    });

    test('flutter dispatches to _validateFlutter (failure)', () {
      final error = validator.validate('flutter', tmpDir.path);
      expect(error, isNotNull);
      expect(error, contains('pubspec.yaml'));
      expect(error, contains('Flutter project root'));
    });

    test('nestjs dispatches to _validateNestjs (success)', () {
      writeFile('package.json', '{"dependencies":{"@nestjs/core":"^10"}}');
      expect(validator.validate('nestjs', tmpDir.path), isNull);
    });

    test('security always returns null (framework-agnostic)', () {
      expect(validator.validate('security', tmpDir.path), isNull);
    });

    test('default dispatches to _validateGeneric', () {
      writeFile('go.mod', 'module example');
      expect(validator.validate('go', tmpDir.path), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // _validateNestjs branches
  // ---------------------------------------------------------------------------
  group('_validateNestjs', () {
    test('returns error when package.json missing', () {
      final error = validator.validate('nestjs', tmpDir.path);
      expect(error, isNotNull);
      expect(error, contains('No package.json found'));
    });

    test('returns error when @nestjs/core dependency absent', () {
      writeFile('package.json', '{"dependencies":{"express":"^4"}}');
      final error = validator.validate('nestjs', tmpDir.path);
      expect(error, isNotNull);
      expect(error, contains('@nestjs/core'));
      expect(error, contains('does not appear to be a NestJS project'));
    });

    test('returns null when @nestjs/core present', () {
      writeFile('package.json', '{"dependencies":{"@nestjs/core":"^10"}}');
      expect(validator.validate('nestjs', tmpDir.path), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // _validateGeneric branches
  // ---------------------------------------------------------------------------
  group('_validateGeneric', () {
    test('known marker present → null', () {
      writeFile('Cargo.toml', '[package]');
      expect(validator.validate('rust', tmpDir.path), isNull);
    });

    test('known marker absent → error mentions marker and tech', () {
      final error = validator.validate('rust', tmpDir.path);
      expect(error, isNotNull);
      expect(error, contains('Cargo.toml'));
      expect(error, contains('rust project root'));
    });

    test('python marker (pyproject.toml) present → null', () {
      writeFile('pyproject.toml', '[tool.poetry]');
      expect(validator.validate('python', tmpDir.path), isNull);
    });

    test('package.json-based tech (react) present → null', () {
      writeFile('package.json', '{}');
      expect(validator.validate('react', tmpDir.path), isNull);
    });

    test('unknown technology → null (skips validation)', () {
      expect(validator.validate('somethingelse', tmpDir.path), isNull);
    });
  });
}
