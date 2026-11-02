import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:somnio/src/content/skill_registry.dart';
import 'package:somnio/src/runner/nextjs_redirect.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmpDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('somnio_nextjs_');
  });

  tearDown(() => tmpDir.deleteSync(recursive: true));

  void writePackageJson(String content) {
    File(p.join(tmpDir.path, 'package.json')).writeAsStringSync(content);
  }

  group('dependsOnNext', () {
    test('is true for a next dependency', () {
      expect(dependsOnNext('{"dependencies":{"next": "^16"}}'), isTrue);
    });

    test('is false for next-auth alone', () {
      expect(dependsOnNext('{"dependencies":{"next-auth":"^5"}}'), isFalse);
    });

    test('is false for @next scoped packages alone', () {
      expect(
        dependsOnNext('{"devDependencies":{"@next/eslint-plugin-next":"^16"}}'),
        isFalse,
      );
    });
  });

  group('nextjsRedirectFor', () {
    for (final (from, to) in [
      ('react_health', 'nextjs_health'),
      ('react_plan', 'nextjs_plan'),
      ('security_audit', 'nextjs_security_audit'),
    ]) {
      test('sends $from to $to in a Next.js project', () {
        writePackageJson('{"dependencies":{"next":"^16","react":"^19"}}');

        expect(nextjsRedirectFor(from, tmpDir.path), to);
      });
    }

    test('keeps a React audit in a React project without next', () {
      writePackageJson('{"dependencies":{"react":"^19"}}');

      expect(nextjsRedirectFor('react_health', tmpDir.path), isNull);
    });

    test('keeps the audit when there is no package.json', () {
      expect(nextjsRedirectFor('security_audit', tmpDir.path), isNull);
    });

    test('never redirects an audit without a Next.js counterpart', () {
      writePackageJson('{"dependencies":{"next":"^16"}}');

      expect(nextjsRedirectFor('nestjs_health', tmpDir.path), isNull);
    });
  });

  group('nextjsCounterparts', () {
    test('maps registered bundles to registered bundles', () {
      for (final entry in nextjsCounterparts.entries) {
        expect(SkillRegistry.findById(entry.key), isNotNull, reason: entry.key);
        expect(
          SkillRegistry.findById(entry.value),
          isNotNull,
          reason: entry.value,
        );
      }
    });
  });
}
