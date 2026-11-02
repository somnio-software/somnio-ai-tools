import 'dart:io';

import 'package:path/path.dart' as p;

/// Matches a `"next"` key in a package.json, so `next-auth` or `@next/font`
/// alone do not make a project a Next.js project.
final _nextDependency = RegExp(r'"next"\s*:');

/// Whether [packageJsonContent] declares the `next` package.
bool dependsOnNext(String packageJsonContent) =>
    _nextDependency.hasMatch(packageJsonContent);

/// Whether the `package.json` in [cwd] declares the `next` package.
bool isNextjsProject(String cwd) {
  final packageJson = File(p.join(cwd, 'package.json'));
  return packageJson.existsSync() &&
      dependsOnNext(packageJson.readAsStringSync());
}

/// The React and generic audits that run their Next.js counterpart when the
/// project depends on `next`, keyed by bundle id.
///
/// People run the audit they know (`rh`, `rp`, `sa`); a Next.js project gets
/// the Next.js version, which has its own steps (live advisory lookup,
/// package-manager hardening, Server Actions) and its own report.
const nextjsCounterparts = {
  'react_health': 'nextjs_health',
  'react_plan': 'nextjs_plan',
  'security_audit': 'nextjs_security_audit',
};

/// The id of the Next.js bundle that replaces [bundleId] in [cwd], or `null`
/// when [bundleId] has no counterpart or [cwd] is not a Next.js project.
String? nextjsRedirectFor(String bundleId, String cwd) {
  final target = nextjsCounterparts[bundleId];
  if (target == null || !isNextjsProject(cwd)) return null;
  return target;
}
