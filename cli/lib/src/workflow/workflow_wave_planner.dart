import 'workflow_context.dart';

/// A group of steps that can execute concurrently.
class Wave {
  const Wave(this.stepIndices);

  /// 0-based indices of steps in this wave.
  final List<int> stepIndices;

  int get length => stepIndices.length;
}

/// Groups workflow steps into concurrent waves using topological levels.
///
/// Steps with no dependencies form wave 0. Steps whose dependencies are all
/// in earlier waves form the next wave, and so on.
///
/// Uses a level-by-level Kahn's algorithm, so wave assignment does not depend
/// on declaration order: a step may declare `needs` on a later-declared step.
/// Invalid graphs (out-of-range deps, self-deps, cycles) throw rather than
/// silently producing an ordering that drops the constraint.
class WavePlanner {
  const WavePlanner();

  /// Plans execution waves from the given step entries.
  ///
  /// Returns a list of [Wave]s in execution order. Steps within each wave
  /// are independent and can run in parallel.
  ///
  /// Throws [FormatException] if a step declares an out-of-range or self
  /// dependency, or if the dependency graph contains a cycle.
  List<Wave> plan(List<WorkflowStepEntry> steps) {
    if (steps.isEmpty) return const [];

    final n = steps.length;
    _validate(steps);

    // Build the dependency graph. `needs` is de-duplicated so a repeated dep
    // does not inflate the indegree past the number of edges we can remove.
    final indegree = List<int>.filled(n, 0);
    final dependents = List.generate(n, (_) => <int>[]);
    for (var i = 0; i < n; i++) {
      for (final dep in steps[i].needs.toSet()) {
        indegree[i]++;
        dependents[dep].add(i);
      }
    }

    // Kahn's algorithm, one wave per level.
    var current = [for (var i = 0; i < n; i++) if (indegree[i] == 0) i];
    final waves = <Wave>[];
    var placed = 0;
    while (current.isNotEmpty) {
      waves.add(Wave(current));
      placed += current.length;

      final next = <int>[];
      for (final i in current) {
        for (final d in dependents[i]) {
          if (--indegree[d] == 0) next.add(d);
        }
      }
      // Keep steps within a wave in declaration order for stable output.
      next.sort();
      current = next;
    }

    if (placed < n) {
      final stuck = [
        for (var i = 0; i < n; i++)
          if (indegree[i] > 0) '${i + 1} (${steps[i].file})',
      ];
      throw FormatException(
        'Dependency cycle detected among steps: ${stuck.join(', ')}',
      );
    }

    return waves;
  }

  /// Rejects dependencies that cannot be satisfied. Messages use 1-based
  /// step numbers to match the `needs` format written in context.md.
  void _validate(List<WorkflowStepEntry> steps) {
    for (var i = 0; i < steps.length; i++) {
      for (final dep in steps[i].needs) {
        if (dep < 0 || dep >= steps.length) {
          throw FormatException(
            'Step ${i + 1} (${steps[i].file}) declares needs: ${dep + 1}, '
            'but the workflow only has ${steps.length} steps',
          );
        }
        if (dep == i) {
          throw FormatException(
            'Step ${i + 1} (${steps[i].file}) depends on itself',
          );
        }
      }
    }
  }
}
