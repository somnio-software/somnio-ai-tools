// coverage:ignore-file
import 'dart:io';

import 'package:somnio/src/cli_runner.dart';

Future<void> main(List<String> args) async {
  await _flushThenExit(await SomnioCliRunner().run(args));
}

Future<void> _flushThenExit(int status) async {
  await Future.wait<void>([stdout.close(), stderr.close()]);
  exit(status);
}