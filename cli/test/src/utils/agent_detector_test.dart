import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:somnio/src/agents/agent_registry.dart';
import 'package:somnio/src/utils/agent_detector.dart';
import 'package:test/test.dart';

void main() {
  late Directory temp;
  late String home;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('agent_detector_test_');
    home = temp.path;
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  /// Links `<home>/<agentDir>/<name>` to skills.sh's canonical copy with a
  /// relative target, the way `npx skills add -g` does.
  String linkToCanonical(String agentDir, String name) {
    Directory(p.join(home, '.agents', 'skills', name))
        .createSync(recursive: true);
    final link = p.join(home, agentDir, name);
    Directory(p.dirname(link)).createSync(recursive: true);
    Link(link).createSync(
      p.relative(
        p.join(home, '.agents', 'skills', name),
        from: p.dirname(link),
      ),
    );
    return link;
  }

  group('AgentDetector', () {
    group('hasContent', () {
      late String dir;

      setUp(() => dir = p.join(home, '.augment', 'skills'));

      test('is false for a missing directory', () {
        expect(AgentDetector.hasContent(dir, home: home), isFalse);
      });

      test('is false for an empty directory', () {
        Directory(dir).createSync(recursive: true);

        expect(AgentDetector.hasContent(dir, home: home), isFalse);
      });

      test('ignores .DS_Store', () {
        Directory(dir).createSync(recursive: true);
        File(p.join(dir, '.DS_Store')).writeAsStringSync('x');

        expect(AgentDetector.hasContent(dir, home: home), isFalse);
      });

      test('ignores relative links into ~/.agents/skills', () {
        linkToCanonical('.augment/skills', 'fha');
        linkToCanonical('.augment/skills', 'ship');

        expect(AgentDetector.hasContent(dir, home: home), isFalse);
      });

      test('ignores absolute links into ~/.agents/skills', () {
        Directory(dir).createSync(recursive: true);
        Link(p.join(dir, 'fha'))
            .createSync(p.join(home, '.agents', 'skills', 'fha'));

        expect(AgentDetector.hasContent(dir, home: home), isFalse);
      });

      test('ignores links into a symlinked ~/.agents/skills', () {
        final store = Directory(p.join(home, 'store', 'skills', 'fha'))
          ..createSync(recursive: true);
        Directory(p.join(home, '.agents')).createSync();
        Link(p.join(home, '.agents', 'skills'))
            .createSync(p.dirname(store.path));
        Directory(dir).createSync(recursive: true);
        Link(p.join(dir, 'fha')).createSync(store.path);

        expect(AgentDetector.hasContent(dir, home: home), isFalse);
      });

      test('ignores links from a symlinked agent folder', () {
        Directory(p.join(home, '.agents', 'skills', 'fha'))
            .createSync(recursive: true);
        final real = Directory(p.join(home, 'dotfiles', 'augment', 'skills'))
          ..createSync(recursive: true);
        Link(p.join(home, '.augment'))
            .createSync(p.join(home, 'dotfiles', 'augment'));
        // skills.sh computes the target from the real parent path.
        Link(p.join(real.path, 'fha'))
            .createSync('../../../.agents/skills/fha');

        expect(AgentDetector.hasContent(dir, home: home), isFalse);
      });

      test('counts a link pointing anywhere else', () {
        final elsewhere = Directory(p.join(home, 'my-skills', 'fha'))
          ..createSync(recursive: true);
        Directory(dir).createSync(recursive: true);
        Link(p.join(dir, 'fha')).createSync(elsewhere.path);

        expect(AgentDetector.hasContent(dir, home: home), isTrue);
      });

      test('counts a real skill directory next to skills.sh links', () {
        linkToCanonical('.augment/skills', 'fha');
        Directory(p.join(dir, 'some-skill')).createSync();

        expect(AgentDetector.hasContent(dir, home: home), isTrue);
      });

      test(
        'is false when the directory cannot be listed',
        () {
          Directory(p.join(dir, 'x')).createSync(recursive: true);
          Process.runSync('chmod', ['000', dir]);
          addTearDown(() => Process.runSync('chmod', ['755', dir]));

          expect(AgentDetector.hasContent(dir, home: home), isFalse);
        },
        testOn: 'posix',
      );
    });

    // Mirrors `somnio setup`: detection runs before the skills.sh cleanup,
    // while `npx skills add -g --all` links still fill the agent folders.
    group('detect, before the skills.sh cleanup', () {
      final augment = AgentRegistry.findById('auggie')!;

      Future<bool> augmentDetected() async {
        final detector = AgentDetector(
          homeDirectory: home,
          whichBinary: (_) async => null,
        );
        return (await detector.detect())[augment]!.installed;
      }

      test('does not detect an agent whose folder only has skills.sh links',
          () async {
        linkToCanonical('.augment/skills', 'fha');

        expect(await augmentDetected(), isFalse);
      });

      test('detects an agent whose folder has a real skill', () async {
        Directory(p.join(home, '.augment', 'skills', 'mine'))
            .createSync(recursive: true);

        expect(await augmentDetected(), isTrue);
      });

      test('detects Codex skills under CODEX_HOME', () async {
        final codex = AgentRegistry.findById('codex')!;
        final codexHome = p.join(home, 'custom-codex');
        Directory(p.join(codexHome, 'skills', 'mine'))
            .createSync(recursive: true);

        final detector = AgentDetector(
          homeDirectory: home,
          environment: {'CODEX_HOME': codexHome},
          whichBinary: (_) async => null,
        );
        final info = (await detector.detect())[codex]!;

        expect(info.path, p.join(codexHome, 'skills'));
      });

      group('Antigravity', () {
        final antigravity = AgentRegistry.findById('antigravity')!;

        Future<String?> detectedPath() async {
          final detector = AgentDetector(
            homeDirectory: home,
            whichBinary: (_) async => null,
          );
          return (await detector.detect())[antigravity]!.path;
        }

        test('is detected by its skills folder', () async {
          Directory(p.join(home, '.gemini', 'config', 'skills', 'mine'))
              .createSync(recursive: true);

          expect(
            await detectedPath(),
            p.join(home, '.gemini', 'config', 'skills'),
          );
        });

        test('is still detected by its pre-skills folder', () async {
          Directory(p.join(home, '.gemini', 'antigravity', 'brain'))
              .createSync(recursive: true);

          expect(await detectedPath(), p.join(home, '.gemini', 'antigravity'));
        });
      });

      test('detects an agent whose binary is on PATH', () async {
        final detector = AgentDetector(
          homeDirectory: home,
          whichBinary: (binary) async =>
              binary == augment.binary ? '/bin/$binary' : null,
        );

        final info = (await detector.detect())[augment]!;

        expect(info.path, '/bin/${augment.binary}');
      });
    });
  });
}
