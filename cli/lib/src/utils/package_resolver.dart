import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

/// Resolves the technology-tools repo root at runtime.
///
/// When installed via `dart pub global activate --source git`, the repo is
/// cached in `~/.pub-cache/git/`. This resolver finds the repo root
/// so the CLI can access `skills/`.
class PackageResolver {
  /// Resolves the technology-tools repo root directory.
  ///
  /// The CLI package lives at `<repo-root>/cli/`, so we navigate up
  /// one level from the package root.
  Future<String> resolveRepoRoot() async {
    // Strategy 1: Isolate.resolvePackageUri
    try {
      final packageUri = Uri.parse('package:somnio/somnio.dart');
      final resolved = await Isolate.resolvePackageUri(packageUri);
      if (resolved != null) {
        // resolved = file:///<repo-root>/cli/lib/somnio.dart
        // Go up: lib/ -> cli/ -> technology-tools/
        final repoRoot = resolved.resolve('../../').toFilePath();
        if (_validateRepoRoot(repoRoot)) return p.normalize(repoRoot);
      }
    } catch (_) {}

    // Strategy 2: SOMNIO_ROOT environment variable
    final envRoot = Platform.environment['SOMNIO_ROOT'];
    if (envRoot != null && _validateRepoRoot(envRoot)) {
      return p.normalize(envRoot);
    }

    // Strategy 3: Walk up from the resolved executable
    final execDir = File(Platform.resolvedExecutable).parent.path;
    for (var dir = execDir;
        dir != p.dirname(dir);
        dir = p.dirname(dir)) {
      if (_validateRepoRoot(dir)) return p.normalize(dir);
    }

    // Strategy 4: Walk up from current working directory
    for (var dir = Directory.current.path;
        dir != p.dirname(dir);
        dir = p.dirname(dir)) {
      if (_validateRepoRoot(dir)) return p.normalize(dir);
    }

    throw StateError(
      'Cannot find technology-tools repo root.\n'
      'The skills/ directory was not found at the expected location.\n\n'
      'Solutions:\n'
      '  1. Set SOMNIO_ROOT environment variable:\n'
      '     export SOMNIO_ROOT=/path/to/technology-tools\n\n'
      '  2. Reinstall the CLI:\n'
      '     dart pub global activate --source git <repo-url> --git-path cli',
    );
  }

  bool _validateRepoRoot(String path) {
    return Directory(p.join(path, 'skills')).existsSync();
  }
}
