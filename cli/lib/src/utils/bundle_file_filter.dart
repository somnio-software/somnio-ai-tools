import 'package:path/path.dart' as p;

/// Directory name Python uses for compiled bytecode caches.
const String pythonCacheDirName = '__pycache__';

/// File extensions of compiled Python bytecode (`.pyc`, `.pyo`).
const Set<String> pythonBytecodeExtensions = {'.pyc', '.pyo'};

/// Whether [relativePath] (relative to a skill bundle directory) is a Python
/// bytecode cache artifact that must never be read or installed.
///
/// Local checkouts accumulate these (gitignored) after running a skill's
/// Python tests; they are binary, so reading them as UTF-8 text fails.
bool isPythonBytecodeCache(String relativePath) {
  if (pythonBytecodeExtensions.contains(p.extension(relativePath))) {
    return true;
  }
  return p.split(relativePath).contains(pythonCacheDirName);
}
