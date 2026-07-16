import '../runner/step_executor.dart' show defaultStepTimeout;

/// Thrown when `--step-timeout` is present but not a valid value.
class StepTimeoutParseException implements Exception {
  const StepTimeoutParseException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Parses the `--step-timeout` flag value (whole minutes) into a [Duration].
///
/// Returns [defaultStepTimeout] when [raw] is `null` (flag absent) — the
/// default behavior is unchanged. Throws [StepTimeoutParseException] when
/// [raw] is present but not a positive integer, so a bad value never
/// silently falls back to the default.
Duration parseStepTimeoutMinutes(String? raw) {
  if (raw == null) return defaultStepTimeout;

  final minutes = int.tryParse(raw);
  if (minutes == null || minutes <= 0) {
    throw StepTimeoutParseException(
      'Invalid --step-timeout: "$raw". '
      'Must be a positive whole number of minutes.',
    );
  }
  return Duration(minutes: minutes);
}
