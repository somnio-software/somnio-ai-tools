import 'package:path/path.dart' as p;

/// Directory name Python uses for compiled bytecode caches.
const String pythonCacheDirName = '__pycache__';

/// File extensions of compiled Python bytecode (`.pyc`, `.pyo`).
const Set<String> pythonBytecodeExtensions = {'.pyc', '.pyo'};

/// Exact file names of OS metadata files that must never be installed.
const Set<String> ignoredBundleFileNames = {'.DS_Store'};

/// Whether [relativePath] (relative to a skill bundle directory) is an
/// artifact that must never be read or installed: Python bytecode caches
/// (`__pycache__/`, `*.pyc`, `*.pyo`) or macOS `.DS_Store` files.
///
/// Local checkouts accumulate these (gitignored) over time; they are binary,
/// so reading them as UTF-8 text fails.
bool isIgnoredBundleFile(String relativePath) {
  if (ignoredBundleFileNames.contains(p.basename(relativePath))) {
    return true;
  }
  if (pythonBytecodeExtensions.contains(p.extension(relativePath))) {
    return true;
  }
  return p.split(relativePath).contains(pythonCacheDirName);
}
