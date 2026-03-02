import 'dart:io';

import 'package:mason_logger/mason_logger.dart';

import '../agents/agent_config.dart';
import '../agents/agent_registry.dart';
import 'platform_utils.dart';

/// Result of checking a CLI's availability.
class CliCheck {
  const CliCheck({
    required this.agent,
    required this.installed,
    this.path,
  });

  final AgentConfig agent;
  final bool installed;
  final String? path;
}

/// Handles detection and installation of AI CLI tools.
///
/// All CLI definitions come from [AgentRegistry] — adding a new agent
/// there automatically makes it detectable and installable here.
class CliInstaller {
  CliInstaller({required Logger logger}) : _logger = logger;

  final Logger _logger;

  /// Detect all executable CLI agents.
  Future<List<CliCheck>> detectAll() async {
    final results = <CliCheck>[];
    for (final agent in AgentRegistry.executableAgents) {
      if (agent.binary == null) continue;
      final path = await PlatformUtils.whichBinary(agent.binary!);
      results.add(CliCheck(
        agent: agent,
        installed: path != null,
        path: path,
      ));
    }
    return results;
  }

  /// Check if npm is available on the system.
  Future<bool> isNpmAvailable() async {
    try {
      final result = await Process.run('npm', ['--version']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Attempt to install a CLI via npm.
  ///
  /// Returns true if installation succeeded.
  Future<bool> installViaNpm(AgentConfig agent) async {
    if (agent.npmPackage == null) return false;

    final progress = _logger.progress(
      'Installing ${agent.displayName} via npm',
    );

    try {
      final result = await Process.run(
        'npm',
        ['install', '-g', agent.npmPackage!],
        runInShell: true,
      );

      if (result.exitCode == 0) {
        progress.complete('${agent.displayName} installed');
        return true;
      } else {
        progress.fail('${agent.displayName} installation failed');
        final stderr = (result.stderr as String).trim();
        if (stderr.isNotEmpty) {
          _logger.warn(stderr);
        }
        return false;
      }
    } catch (e) {
      progress.fail('${agent.displayName} installation failed: $e');
      return false;
    }
  }

  /// Show manual installation instructions for a CLI.
  void showManualInstructions(AgentConfig agent) {
    _logger.info('');
    _logger.info('  ${agent.displayName}:');
    if (agent.installInstructions != null) {
      _logger.info(agent.installInstructions!);
    } else {
      if (agent.npmPackage != null) {
        _logger.info('  npm install -g ${agent.npmPackage}');
      }
      if (agent.installUrl != null) {
        _logger.info('  Or visit: ${agent.installUrl}');
      }
    }
  }
}
